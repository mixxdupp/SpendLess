import Foundation
import Vision
import UIKit
import AVFoundation

struct ProductMetadata: Equatable {
    var title: String?
    var price: Decimal?
    var currency: String?
    var imageUrl: String?
}

class MetadataFetcher {
    static let shared = MetadataFetcher()
    
    private let session: URLSession
    private let backendBaseURL = "https://price-tracker-api.stopimpulsebuying.workers.dev"
    
    private init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        ]
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }
    
    func fetchMetadata(for urlString: String) async throws -> ProductMetadata {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await session.data(from: url)
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        var metadata = parseHtml(html)
        print("📦 [MetadataFetcher] After parseHtml - imageUrl: \(metadata.imageUrl ?? "nil")")
        
        // Use Gemini AI if price or image is missing
        if metadata.price == nil || metadata.imageUrl == nil {
            print("📦 [MetadataFetcher] Calling Gemini for missing data...")
            if let aiResult = try? await extractWithGemini(html: html, title: metadata.title) {
                print("📦 [MetadataFetcher] Gemini result - imageUrl: \(aiResult.imageUrl ?? "nil")")
                if metadata.price == nil && aiResult.price != nil { 
                    metadata.price = aiResult.price 
                    metadata.currency = aiResult.currency
                }
                if metadata.title == nil { metadata.title = aiResult.title }
                if metadata.imageUrl == nil { metadata.imageUrl = aiResult.imageUrl }
            }
        }
        
        // Final fallback: Search for product image using Gemini with Google Search grounding
        if metadata.imageUrl == nil, let title = metadata.title {
            print("📦 [MetadataFetcher] Calling Google Search grounding for image...")
            metadata.imageUrl = try? await searchProductImage(title: title)
            print("📦 [MetadataFetcher] Google Search result - imageUrl: \(metadata.imageUrl ?? "nil")")
        }
        
        // Ultimate fallback: Generate placeholder image from product title
        if metadata.imageUrl == nil, let title = metadata.title {
            let seed = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "product"
            metadata.imageUrl = "https://api.dicebear.com/7.x/shapes/png?seed=\(seed)&size=400"
            print("📦 [MetadataFetcher] Using placeholder image")
        }
        
        print("📦 [MetadataFetcher] Final imageUrl: \(metadata.imageUrl ?? "nil")")
        return metadata
    }
    
    // Search for product image by scraping Google Images directly
    private func searchProductImage(title: String) async throws -> String? {
        // Encode search query for URL
        guard let encodedQuery = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchUrl = URL(string: "https://www.google.com/search?q=\(encodedQuery)&tbm=isch") else {
            return nil
        }
        
        var request = URLRequest(url: searchUrl)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else { return nil }
        
        print("📦 [Google Images] Fetched \(html.count) chars")
        
        // Pattern to find image URLs in Google Images results
        // Google Images embeds image URLs in various JSON-like structures
        let patterns = [
            // Direct image URLs in data attributes
            #"\"ou\":\"(https?://[^\"]+\.(?:jpg|jpeg|png|webp)[^\"]*)\""#,
            // Image URLs in imgres links
            #"imgurl=(https?://[^&\"]+)"#,
            // High-res image URLs
            #"\[\"(https?://[^\"]+\.(?:jpg|jpeg|png|webp))\",\d+,\d+\]"#,
            // Image source URLs
            #"\"(https?://[^\"]+images[^\"]+\.(?:jpg|jpeg|png|webp)[^\"]*)\""#,
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(html.startIndex..., in: html)
                if let match = regex.firstMatch(in: html, range: range),
                   let urlRange = Range(match.range(at: 1), in: html) {
                    var imageUrl = String(html[urlRange])
                    // Decode URL-encoded characters
                    imageUrl = imageUrl.removingPercentEncoding ?? imageUrl
                    // Skip Google's own URLs and thumbnails
                    if !imageUrl.contains("google.com") && !imageUrl.contains("gstatic.com") && imageUrl.count > 50 {
                        print("📦 [Google Images] Found: \(imageUrl.prefix(100))...")
                        return imageUrl
                    }
                }
            }
        }
        
        print("📦 [Google Images] No image found in patterns")
        return nil
    }
    
    // MARK: - Smart Search (Barcode/Text -> URL)
    
    func findProductDetails(fromQuery query: String) async throws -> ProductMetadata {
        print("📦 [MetadataFetcher] Reverse searching query: \(query)")
        
        // 1. Google the query (Barcode or Text)
        guard let searchUrl = await searchProductUrl(query: query) else {
            throw URLError(.badURL)
        }
        
        print("📦 [MetadataFetcher] Found match URL: \(searchUrl)")
        
        // 2. Fetch metadata from that URL
        var metadata = try await fetchMetadata(for: searchUrl)
        
        // 3. Fallback: If title is bad, use the query as title (better than nothing)
        if metadata.title == nil {
            metadata.title = query.capitalized
        }
        
        return metadata
    }
    
    private func findFirstResultUrl(query: String) -> String? {
        // Placeholder synchronization for sync context not needed as we use async flow now
        return nil
    }
    
    // Async version of the search
    func searchProductUrl(query: String) async -> String? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://www.google.com/search?q=\(encoded)"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let html = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        // Pattern for standard result anchors
        // We look for Amazon, Target, Walmart links specifically to avoid blogspam
        let domains = ["amazon", "walmart", "target", "bestbuy", "apple"]
        
        // Simple regex to find hrefs
        let linkPattern = "href=\"(https?://[^\"]+)\""
        if let regex = try? NSRegularExpression(pattern: linkPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: html) {
                    let link = String(html[range])
                    
                    // Filter: Must be a valid product url, not Google/Hidden
                    if !link.contains("google") && domains.contains(where: { link.contains($0) }) {
                        // Clean the URL (sometimes google wraps it)
                        if let range = link.range(of: "&amp;") {
                            return String(link[..<range.lowerBound])
                        }
                        return link
                    }
                }
            }
        }
        
        return nil
    }
    private func parseHtml(_ html: String) -> ProductMetadata {
        var metadata = ProductMetadata()
        
        // 1. JSON-LD (Priority)
        if let jsonLd = extractJsonLd(from: html) {
            metadata.title = jsonLd.title
            metadata.price = jsonLd.price
            metadata.currency = jsonLd.currency
            metadata.imageUrl = jsonLd.imageUrl
        }
        
        // 2. Open Graph Fallbacks
        if metadata.title == nil {
            metadata.title = extractMetaTag(html, property: "og:title")
        }
        if metadata.imageUrl == nil {
            metadata.imageUrl = extractMetaTag(html, property: "og:image")
        }
        if metadata.price == nil {
            if let priceStr = extractMetaTag(html, property: "product:price:amount") ?? extractMetaTag(html, property: "og:price:amount") {
                metadata.price = Decimal(string: priceStr)
            }
            if let currencyStr = extractMetaTag(html, property: "product:price:currency") ?? extractMetaTag(html, property: "og:price:currency") {
                metadata.currency = currencyStr
            }
        }
        
        // 3. Title Tag Fallback
        if metadata.title == nil {
            let titlePattern = "<title[^>]*>([^<]+)</title>"
            if let regex = try? NSRegularExpression(pattern: titlePattern, options: .caseInsensitive) {
                let range = NSRange(html.startIndex..., in: html)
                if let match = regex.firstMatch(in: html, range: range),
                   let titleRange = Range(match.range(at: 1), in: html) {
                    metadata.title = String(html[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        // 4. Heuristic Price Extraction (prioritize INR for Indian sites)
        if metadata.price == nil {
            let (price, currency) = extractHeuristicPrice(from: html)
            metadata.price = price
            metadata.currency = currency
        }
        
        // 5. Heuristic Image Extraction (for Amazon and other sites)
        if metadata.imageUrl == nil {
            metadata.imageUrl = extractHeuristicImage(from: html)
        }
        
        // 6. Clean up title
        if let title = metadata.title {
            metadata.title = cleanTitle(title)
        }
        
        return metadata
    }
    
    // Extract image URL using patterns common to e-commerce sites
    private func extractHeuristicImage(from html: String) -> String? {
        // Amazon-specific patterns (high priority)
        let patterns = [
            // Amazon main image data attribute
            #"data-old-hires=\"([^\"]+)\""#,
            // Amazon landing image
            #"id=\"landingImage\"[^>]*src=\"([^\"]+)\""#,
            // Amazon image block data
            #"\"hiRes\":\"([^\"]+)\""#,
            #"\"large\":\"([^\"]+)\""#,
            // Generic product image patterns
            #"property=\"og:image\"[^>]*content=\"([^\"]+)\""#,
            #"content=\"([^\"]+)\"[^>]*property=\"og:image\""#,
            // Twitter card image
            #"name=\"twitter:image\"[^>]*content=\"([^\"]+)\""#,
            // itemprop image
            #"itemprop=\"image\"[^>]*content=\"([^\"]+)\""#,
            #"itemprop=\"image\"[^>]*src=\"([^\"]+)\""#,
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(html.startIndex..., in: html)
                if let match = regex.firstMatch(in: html, range: range),
                   let urlRange = Range(match.range(at: 1), in: html) {
                    let url = String(html[urlRange])
                    // Validate it's a proper image URL
                    if url.hasPrefix("http") && (url.contains(".jpg") || url.contains(".png") || url.contains(".webp") || url.contains("images")) {
                        return url
                    }
                }
            }
        }
        
        return nil
    }
    
    // Clean product title by removing site names, junk, and decoding HTML
    private func cleanTitle(_ title: String) -> String {
        var cleaned = title
        
        // Decode HTML entities
        cleaned = cleaned
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        
        // Remove site prefixes like "Amazon.in: Buy " or "Amazon.com: "
        let prefixPatterns = [
            "Amazon\\.\\w+:\\s*Buy\\s*",
            "Amazon\\.\\w+:\\s*",
            "Flipkart\\.com:\\s*",
            "Buy\\s+"
        ]
        for pattern in prefixPatterns {
            if let regex = try? NSRegularExpression(pattern: "^" + pattern, options: .caseInsensitive) {
                let range = NSRange(cleaned.startIndex..., in: cleaned)
                cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: "")
            }
        }
        
        // Remove everything after common separators (site name, reviews, etc.)
        let separators = [" | ", " - Amazon", " : Amazon", " – ", " — ", " | GIGABYTE", " Reviews", " Online at Low Prices"]
        for sep in separators {
            if let range = cleaned.range(of: sep, options: .caseInsensitive) {
                cleaned = String(cleaned[..<range.lowerBound])
            }
        }
        
        // Trim whitespace only, no length limit
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    private func extractHeuristicPrice(from html: String) -> (Decimal?, String?) {
        // Ordered patterns: INR first (Indian users), then USD, EUR, GBP
        let patterns: [(pattern: String, currency: String)] = [
            // INR: ₹54,151.89 or INR 54,151.89 or Rs. 54,151
            (#"(?:₹|INR|Rs\.?)\s*(\d{1,3}(?:,\d{2,3})*(?:\.\d{1,2})?)"#, "INR"),
            // USD: $299.99
            (#"\$\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)"#, "USD"),
            // EUR: €299.99
            (#"€\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)"#, "EUR"),
            // GBP: £299.99
            (#"£\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)"#, "GBP"),
            // Generic price class
            (#"\"price\"\s*:\s*\"?(\d+\.?\d*)"#, "USD"),
        ]
        
        for (pattern, currency) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(html.startIndex..., in: html)
                if let match = regex.firstMatch(in: html, range: range),
                   let priceRange = Range(match.range(at: 1), in: html) {
                    let priceStr = String(html[priceRange]).replacingOccurrences(of: ",", with: "")
                    if let price = Decimal(string: priceStr), price > 0 {
                        return (price, currency)
                    }
                }
            }
        }
        
        return (nil, nil)
    }
    
    private func extractMetaTag(_ html: String, property: String) -> String? {
        let pattern = "<meta[^>]*property=[\"']\(property)[\"'][^>]*content=[\"']([^\"']+)[\"']"
        if let range = html.range(of: pattern, options: [.regularExpression, .caseInsensitive]),
           let match = html[range].description.components(separatedBy: "content=\"").last?.components(separatedBy: "\"").first {
            return match
        }
        return nil
    }
    
    private func extractJsonLd(from html: String) -> ProductMetadata? {
        let pattern = "<script[^>]*type=[\"']application/ld\\+json[\"'][^>]*>([\\s\\S]*?)</script>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        
        for match in matches {
            guard let jsonRange = Range(match.range(at: 1), in: html) else { continue }
            let jsonString = String(html[jsonRange])
            
            if let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                if let type = json["@type"] as? String, type.contains("Product") {
                    return parseProductJson(json)
                }
                
                if let graph = json["@graph"] as? [[String: Any]] {
                    for item in graph {
                        if let type = item["@type"] as? String, type.contains("Product") {
                            return parseProductJson(item)
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private func parseProductJson(_ json: [String: Any]) -> ProductMetadata {
        var meta = ProductMetadata()
        meta.title = json["name"] as? String
        
        if let image = json["image"] {
            if let imgStr = image as? String {
                meta.imageUrl = imgStr
            } else if let imgArr = image as? [String], let first = imgArr.first {
                meta.imageUrl = first
            } else if let imgObj = image as? [String: Any], let url = imgObj["url"] as? String {
                meta.imageUrl = url
            }
        }
        
        if let offers = json["offers"] {
            func extractPriceAndCurrency(_ obj: [String: Any]) -> (Decimal?, String?) {
                var price: Decimal? = nil
                var currency: String? = nil
                
                if let p = obj["price"] {
                    price = Decimal(string: "\(p)")
                }
                if let c = obj["priceCurrency"] as? String {
                    currency = c
                }
                return (price, currency)
            }

            if let offerObj = offers as? [String: Any] {
                let (p, c) = extractPriceAndCurrency(offerObj)
                meta.price = p
                meta.currency = c
            } else if let offerArr = offers as? [[String: Any]], let first = offerArr.first {
                let (p, c) = extractPriceAndCurrency(first)
                meta.price = p
                meta.currency = c
            }
        }
        
        return meta
    }
    
    // MARK: - Backend AI Extraction (No API keys in client)
    private func extractWithGemini(html: String, title: String?) async throws -> ProductMetadata {
        let truncatedHtml = String(html.prefix(15000))
        
        guard let url = URL(string: "\(backendBaseURL)/extract-metadata") else {
            return ProductMetadata()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer anonymous", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        
        let body: [String: Any] = [
            "html": truncatedHtml,
            "title": title ?? ""
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("📦 [MetadataFetcher] Backend extraction failed")
            return ProductMetadata()
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            var result = ProductMetadata()
            result.title = json["title"] as? String
            if let price = json["price"] {
                result.price = Decimal(string: "\(price)")
            }
            result.currency = json["currency"] as? String
            result.imageUrl = json["imageUrl"] as? String
            return result
        }
        
        return ProductMetadata()
    }
}


/// Service responsible for scanning images/frames for barcodes and text
class ProductScannerService: NSObject {
    static let shared = ProductScannerService()
    
    // MARK: - Combined Analysis
    
    enum ScanResult {
        case barcode(String)
        case text(String)
        case nothing
    }
    
    /// Analyzes an image for Barcodes (Priority) or Text (Fallback)
    func analyze(image: UIImage) async -> ScanResult {
        guard let cgImage = image.cgImage else { return .nothing }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
        
        // 1. Barcode Request
        return await withCheckedContinuation { continuation in
            let barcodeRequest = VNDetectBarcodesRequest { request, error in
                if let results = request.results as? [VNBarcodeObservation],
                   let first = results.first,
                   let payload = first.payloadStringValue {
                    continuation.resume(returning: .barcode(payload))
                    return
                }
                
                // If no barcode, try Text
                let textRequest = VNRecognizeTextRequest { request, error in
                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        continuation.resume(returning: .nothing)
                        return
                    }
                    
                    let recognizedStrings = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    
                    if recognizedStrings.isEmpty {
                        continuation.resume(returning: .nothing)
                    } else {
                        // Join text and find potential product names
                        print("📦 [Scanner] Found text: \(recognizedStrings)")
                        let fullText = recognizedStrings.joined(separator: " ")
                        continuation.resume(returning: .text(fullText))
                    }
                }
                textRequest.recognitionLevel = .accurate
                
                try? requestHandler.perform([textRequest])
            }
            
            try? requestHandler.perform([barcodeRequest])
        }
    }
    
    // MARK: - Processing
    
    func processScanResult(_ result: ScanResult) async throws -> ProductMetadata? {
        switch result {
        case .barcode(let code):
            print("📦 [Scanner] Processing Barcode: \(code)")
            // Search Google specifically for UPC/EAN
            return try await MetadataFetcher.shared.findProductDetails(fromQuery: code)
            
        case .text(let rawText):
            print("📦 [Scanner] Processing Text: \(rawText.prefix(50))...")
            
            // Heuristic: Clean up text to find "Brand + Model"
            // For now, we just pass the messy text to Google Search or Gemini
            // If the text is too long, we might want to ask Gemini to clean it first?
            // "MetadataFetcher.extractWithGemini" already does this if we pass it as "html" (hacky but works) 
            // OR we just google the first 5 words.
            
            let query = rawText.components(separatedBy: .newlines)
                .joined(separator: " ")
                .split(separator: " ")
                .prefix(10) // Take first 10 words to avoid scanning the whole terms of service
                .joined(separator: " ")
            
            return try await MetadataFetcher.shared.findProductDetails(fromQuery: query)
            
        case .nothing:
            return nil
        }
    }
}
