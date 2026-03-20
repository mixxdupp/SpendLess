import Foundation

/// Service that calls the Anti-Salesman AI to generate demotivation messages
actor RationalityService {
    static let shared = RationalityService()
    
    private let baseURL = "https://price-tracker-api.stopimpulsebuying.workers.dev"
    
    struct ChatMessage: Codable, Hashable, Identifiable {
        var id = UUID()
        let role: String // "user" or "model"
        let text: String
        
        enum CodingKeys: String, CodingKey {
            case role, text
        }
    }
    
    struct DemotivationRequest: Encodable {
        let title: String
        let price: Double
        let imageUrl: String?
        let daysToEarn: Double?
        let percentOfIncome: Double?
        let currency: String
        let messages: [ChatMessage]?
    }
    
    struct DemotivationResponse: Decodable {
        let message: String?
        let error: String?
    }
    
    /// Consult the AI with conversation history
    func consult(
        title: String,
        price: Double,
        imageUrl: String? = nil,
        daysToEarn: Double? = nil,
        percentOfIncome: Double? = nil,
        currency: String = "$",
        messages: [ChatMessage] = []
    ) async -> String {
        do {
            guard let url = URL(string: "\(baseURL)/demotivate") else {
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer anonymous", forHTTPHeaderField: "Authorization")
            
            let payload = DemotivationRequest(
                title: title,
                price: price,
                imageUrl: imageUrl,
                daysToEarn: daysToEarn,
                percentOfIncome: percentOfIncome,
                currency: currency,
                messages: messages
            )
            
            request.httpBody = try JSONEncoder().encode(payload)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            
            guard httpResponse.statusCode == 200 else {
                let decoded = try? JSONDecoder().decode(DemotivationResponse.self, from: data)
                throw NSError(
                    domain: "RationalityService",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: decoded?.error ?? "AI service error"]
                )
            }
            
            let result = try JSONDecoder().decode(DemotivationResponse.self, from: data)
            
            guard let message = result.message else {
                throw NSError(
                    domain: "RationalityService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "No response from AI"]
                )
            }
            
            return message
        } catch {
            // Offline Fallback for Demo/Rate Limits (Updated Persona: Smart Rationalist)
            // If dragging on interaction, provide conversational fallbacks
            if !messages.isEmpty {
                let conversationalFallbacks = [
                    "Silence is free. This product is not.",
                    "If you have to convince an AI, you are already losing.",
                    "You are rationalizing. Stop.",
                    "Is that truly a need, or just a want described with sophisticated vocabulary?",
                    "The marketing worked. That is unfortunate.",
                    "Do not mistake spending for action.",
                    "Every dollar spent here is a dollar not compounding elsewhere.",
                    "You came here to stop. So stop.",
                    "Wait 30 days. If you still want it, come back. You won't.",
                    "This adds complexity, not value.",
                    "It is just a thing. It will not change your life.",
                    "Resist the dopamine hit.",
                    "You are the product's target demographic. Prove them wrong.",
                    "Minimize your footprint, maximize your freedom.",
                    "Consumption is the default. Discipline is the exception."
                ]
                return conversationalFallbacks.randomElement() ?? "Take a breath. Do you really need this?"
            }
            
            // Initial interaction fallback (Category-Aware Customization)
            let category = detectProductCategory(title: title)
            let fallback = getPersuasiveFallback(for: category, title: title, price: price, currency: currency)
            return fallback
        }
    }
    
    // MARK: - Category Detection
    
    private func detectProductCategory(title: String) -> ProductCategory {
        let lowercased = title.lowercased()
        
        // Food & Consumables
        if lowercased.contains("ghee") || lowercased.contains("oil") || lowercased.contains("food") ||
           lowercased.contains("snack") || lowercased.contains("chocolate") || lowercased.contains("coffee") ||
           lowercased.contains("tea") || lowercased.contains("protein") || lowercased.contains("supplement") ||
           lowercased.contains("vitamin") || lowercased.contains("organic") || lowercased.contains("honey") {
            return .food
        }
        
        // Electronics & Gadgets
        if lowercased.contains("keyboard") || lowercased.contains("mouse") || lowercased.contains("headphone") ||
           lowercased.contains("earbuds") || lowercased.contains("speaker") || lowercased.contains("monitor") ||
           lowercased.contains("laptop") || lowercased.contains("phone") || lowercased.contains("tablet") ||
           lowercased.contains("watch") || lowercased.contains("camera") || lowercased.contains("gaming") ||
           lowercased.contains("usb") || lowercased.contains("charger") || lowercased.contains("cable") {
            return .electronics
        }
        
        // Fashion & Apparel
        if lowercased.contains("shirt") || lowercased.contains("shoes") || lowercased.contains("jacket") ||
           lowercased.contains("dress") || lowercased.contains("jeans") || lowercased.contains("sneaker") ||
           lowercased.contains("bag") || lowercased.contains("wallet") || lowercased.contains("watch") ||
           lowercased.contains("sunglasses") || lowercased.contains("jewelry") || lowercased.contains("accessory") {
            return .fashion
        }
        
        // Home & Lifestyle
        if lowercased.contains("furniture") || lowercased.contains("decor") || lowercased.contains("lamp") ||
           lowercased.contains("mattress") || lowercased.contains("pillow") || lowercased.contains("kitchen") ||
           lowercased.contains("appliance") || lowercased.contains("cleaning") || lowercased.contains("organizer") {
            return .home
        }
        
        return .general
    }
    
    private enum ProductCategory {
        case food, electronics, fashion, home, general
    }
    
    private func getPersuasiveFallback(for category: ProductCategory, title: String, price: Double, currency: String) -> String {
        let priceStr = "\(currency)\(String(format: "%.0f", price))"
        
        switch category {
        case .food:
            let foodFallbacks = [
                "\(title) is a consumable—once you eat it, it's gone. That \(priceStr) vanishes with it. Is this truly the best use of your grocery budget, or are you paying a premium for branding?",
                
                "Premium food products like \(title) often cost 3-4x more than equally nutritious alternatives. The taste difference fades after the first bite, but the price difference compounds over time.",
                
                "You've been eating fine without \(title). This is lifestyle inflation disguised as 'treating yourself.' Your regular alternatives work just as well—and cost far less.",
                
                "That \(priceStr) for \(title) is a recurring expense if you get hooked. Calculate the yearly cost. Is this category of spending aligned with your financial goals?",
                
                "Food marketing is designed to make you feel like premium = necessary. \(title) at \(priceStr) is a want, not a nutritional need. Your body doesn't know the difference."
            ]
            return foodFallbacks.randomElement() ?? "Do you really need this?"
            
        case .electronics:
            let techFallbacks = [
                "\(title) will be outdated within 18 months. That \(priceStr) depreciates faster than almost any other purchase you could make. Is chasing specs really worth it?",
                
                "The tech upgrade cycle is a trap. \(title) at \(priceStr) solves a problem your current setup already handles. You're paying for marginal improvements and marketing.",
                
                "Electronics like \(title) are designed to be replaced. That \(priceStr) is essentially a rental fee for temporary satisfaction. Your current gear works fine.",
                
                "Ask yourself: what specific task can't you do without \(title)? If you hesitate, you're buying for the dopamine of 'new,' not actual utility. That \(priceStr) is the cost of that dopamine.",
                
                "Tech purchases feel urgent but age poorly. In 2 years, \(title) will be worth a fraction of \(priceStr). Meanwhile, that money in an index fund keeps growing."
            ]
            return techFallbacks.randomElement() ?? "Do you really need this?"
            
        case .fashion:
            let fashionFallbacks = [
                "\(title) will be out of style faster than you think. Fashion is designed to make last season feel inadequate. That \(priceStr) buys temporary relevance, not lasting value.",
                
                "How many similar items do you already own? \(title) at \(priceStr) is likely joining a crowded closet. The novelty wears off; the clutter remains.",
                
                "The fashion industry profits from making you feel incomplete. \(title) won't change how you feel about yourself—it'll just lighten your wallet by \(priceStr).",
                
                "Cost per wear is the real metric. If \(title) costs \(priceStr) and you wear it 5 times, that's real money per use. Is it worth that math?",
                
                "You've survived every event in your life without \(title). This is want dressed up as need. That \(priceStr) could fund experiences, not fabric."
            ]
            return fashionFallbacks.randomElement() ?? "Do you really need this?"
            
        case .home:
            let homeFallbacks = [
                "\(title) promises to improve your living space, but most home purchases end up unused or forgotten. That \(priceStr) often buys clutter, not comfort.",
                
                "Home products like \(title) solve problems you might not actually have. Before spending \(priceStr), ask: is my current setup genuinely inadequate, or just not Instagram-perfect?",
                
                "The urge to 'upgrade' your home is often just restlessness. \(title) at \(priceStr) won't make you more content—it'll just require maintenance and space.",
                
                "Every item you bring home demands attention. \(title) isn't just \(priceStr)—it's cleaning, organizing, and eventually disposing. Simplicity is free.",
                
                "Your home worked fine yesterday without \(title). This is lifestyle inflation. That \(priceStr) builds wealth if invested, not if spent on decor."
            ]
            return homeFallbacks.randomElement() ?? "Do you really need this?"
            
        case .general:
            let generalFallbacks = [
                "\(title) at \(priceStr) is competing against your future financial freedom. Every purchase is a trade-off. Is this specific item worth what you're giving up?",
                
                "You've gone your entire life without \(title). The urge to buy is temporary; the money spent is permanent. Wait 30 days—if you still want it, reconsider then.",
                
                "That \(priceStr) represents hours of your life traded for wages. Is \(title) worth those hours, or would you rather have that time back as savings?",
                
                "Consider the true cost: \(priceStr) now, or \(priceStr) × 10 in retirement if invested. \(title) is asking you to choose present comfort over future freedom.",
                
                "Ask yourself honestly: are you buying \(title) because you need it, or because buying feels good? The dopamine fades; the \(priceStr) is gone forever."
            ]
            return generalFallbacks.randomElement() ?? "Do you really need this?"
        }
    }
    
    // Legacy wrapper
    func demotivate(
        title: String,
        price: Double,
        imageUrl: String? = nil,
        daysToEarn: Double? = nil,
        percentOfIncome: Double? = nil,
        currency: String = "$"
    ) async -> String {
        return await consult(title: title, price: price, imageUrl: imageUrl, daysToEarn: daysToEarn, percentOfIncome: percentOfIncome, currency: currency, messages: [])
    }
}
