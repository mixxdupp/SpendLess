import Foundation
import Supabase
import Combine
import SwiftUI

class APIClient {
    static let shared = APIClient()
    
    private let supabase: SupabaseClient
    
    // Demo Mode Data
    private var demoProducts: [Product] = [
        Product(
            id: UUID(),
            userId: UUID(),
            url: "https://amazon.com/demo-product",
            title: "Sony WH-1000XM5 Wireless Headphones",
            imageUrl: "https://m.media-amazon.com/images/I/51SKmu2G9FL._AC_SL1000_.jpg",
            currentPrice: 348.00,
            currency: "USD",
            store: "Amazon",
            alertEnabled: true,
            alertThreshold: 300,
            cooldownDays: 7,
            createdAt: Date(),
            lastCheckedAt: Date(),
            priceHistory: PriceHistory.previews
        )
    ]
    
    private init() {
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
    }
    
    // MARK: - Products
    
    func fetchProducts() async throws -> [Product] {
        if await AuthService.shared.isDemoMode {
            return demoProducts
        }
        
        guard let userId = await AuthService.shared.currentUser?.id else {
            throw APIError.notAuthenticated
        }
        
        let products: [Product] = try await supabase
            .from("products")
            .select("*, price_history(*)") // Join price history
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return products
    }
    
    func fetchProduct(id: UUID) async throws -> Product {
        if await AuthService.shared.isDemoMode {
            if let product = demoProducts.first(where: { $0.id == id }) {
                return product
            }
            throw APIError.productNotFound
        }
        
        let product: Product = try await supabase
            .from("products")
            .select("*, price_history(*)")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
            .value
        
        return product
    }
    
    func addProduct(url: String, title: String? = nil, price: Decimal? = nil, imageUrl: String? = nil, currency: String = "USD", cooldownDays: Int = 7) async throws -> Product {
        if await AuthService.shared.isDemoMode {
            let newProduct = Product(
                id: UUID(),
                userId: UUID(),
                url: url,
                title: title ?? "Demo Product For \(url.prefix(20))...",
                imageUrl: imageUrl,
                currentPrice: price ?? Decimal(Double.random(in: 10...100)),
                currency: currency,
                store: "Demo Store",
                alertEnabled: true,
                alertThreshold: nil,
                cooldownDays: cooldownDays,
                createdAt: Date(),
                lastCheckedAt: Date()
            )
            demoProducts.insert(newProduct, at: 0)
            return newProduct
        }
        
        guard let userId = await AuthService.shared.currentUser?.id else {
            throw APIError.notAuthenticated
        }
        
        // Check tier limits
        let currentProducts = try await fetchProducts()
        if let limit = await AuthService.shared.currentUser?.subscriptionTier.productLimit,
           currentProducts.count >= limit {
            throw APIError.productLimitReached
        }
        
        let newProduct = Product(
            id: UUID(),
            userId: userId,
            url: url,
            title: title,
            imageUrl: imageUrl,
            currentPrice: price,
            currency: currency,
            store: nil,
            alertEnabled: true,
            alertThreshold: nil,
            cooldownDays: cooldownDays,
            createdAt: Date(),
            lastCheckedAt: nil
        )
        
        let inserted: Product = try await supabase
            .from("products")
            .insert(newProduct)
            .select()
            .single()
            .execute()
            .value
        
        // Only trigger scrape if no manual data provided
        if title == nil || price == nil {
            try await triggerScrape(productId: inserted.id)
        }
        
        return inserted
    }
    
    func deleteProduct(id: UUID) async throws {
        if await AuthService.shared.isDemoMode {
            demoProducts.removeAll { $0.id == id }
            return
        }
        
        try await supabase
            .from("products")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    func updateProduct(_ product: Product) async throws {
        if await AuthService.shared.isDemoMode {
            if let index = demoProducts.firstIndex(where: { $0.id == product.id }) {
                demoProducts[index] = product
            }
            return
        }
        
        try await supabase
            .from("products")
            .update(product)
            .eq("id", value: product.id.uuidString)
            .execute()
    }
    
    func markAsBought(id: UUID) async throws {
        if await AuthService.shared.isDemoMode {
            if let index = demoProducts.firstIndex(where: { $0.id == id }) {
                demoProducts[index].isBought = true
            }
            return
        }
        
        // Update local optimism? No, handled by refresh.
        // Just update DB
        try await supabase
            .from("products")
            .update(["is_bought": true])
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    // MARK: - Price History
    
    func fetchPriceHistory(productId: UUID, days: Int = 30) async throws -> [PriceHistory] {
        if await AuthService.shared.isDemoMode {
            // Mock history
            return (0..<days).map { day in
                PriceHistory(
                    id: UUID(),
                    productId: productId,
                    price: Decimal(Double.random(in: 50...150)),
                    recordedAt: Calendar.current.date(byAdding: .day, value: -day, to: Date())!
                )
            }
        }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let history: [PriceHistory] = try await supabase
            .from("price_history")
            .select()
            .eq("product_id", value: productId.uuidString)
            .gte("recorded_at", value: cutoffDate.ISO8601Format())
            .order("recorded_at", ascending: true)
            .execute()
            .value
        
        return history
    }
    
     // MARK: - Scraping & Refresh
    
    func refreshAllMonitorings() async throws {
        let products = try await fetchProducts()
        
        // Trigger scrapes in parallel
        await withTaskGroup(of: Void.self) { group in
            for product in products {
                // Skip bought items to freeze price and save API credits
                if !product.isBought {
                    group.addTask {
                        try? await self.triggerScrape(productId: product.id)
                    }
                }
            }
        }
        
        // Wait a small delay to allow some scrapes to complete (Vibe UX)
        try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
    }
    
    private func triggerScrape(productId: UUID) async throws {
        // Call Cloudflare Worker to scrape product
        let url = URL(string: "https://price-tracker-api.stopimpulsebuying.workers.dev/scrape")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Auth Token
        let session = try await supabase.auth.session
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        
        let body: [String: String] = ["product_id": productId.uuidString]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("Scrape trigger failed for \(productId)")
            return
        }
        
        print("Scrape triggered successfully for \(productId)")
    }
    
    func manualRefresh(productId: UUID) async throws {
        try await triggerScrape(productId: productId)
        // Wait slightly for UX
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
    }
    
    // MARK: - Statistics
    
    func calculateMoneySaved() async throws -> Decimal {
        let products = try await fetchProducts()
        var totalSaved: Decimal = 0
        
        for product in products {
            if let price = product.currentPrice {
                if product.isBought {
                    // Bought items subtract from savings (Negative Savings)
                    totalSaved -= price
                } else {
                    // Tracking/Resisted items add to savings (Positive Savings)
                    totalSaved += price
                }
            }
        }
        
        return totalSaved
    }

    // MARK: - Notifications
    
    func fetchNotifications() async throws -> [SIBNotification] {
        if await AuthService.shared.isDemoMode {
            return [
                SIBNotification(
                    id: UUID(),
                    userId: UUID(),
                    productId: demoProducts.first?.id,
                    title: "Price Drop Alert! 📉",
                    body: "Sony WH-1000XM5 is now $299. Cooldown over!",
                    isRead: false,
                    createdAt: Date()
                )
            ]
        }
        
        guard await AuthService.shared.currentUser != nil else {
            throw APIError.notAuthenticated
        }
        
        // Use custom backend endpoint since we added it to workers
        let url = URL(string: "https://price-tracker-api.stopimpulsebuying.workers.dev/notifications")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Get JWT from Supabase session
        let session = try await supabase.auth.session
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.networkError
        }
        
        struct Response: Decodable {
            let notifications: [SIBNotification]
        }
        
        let result = try JSONDecoder.customDateDecoder.decode(Response.self, from: data)
        return result.notifications
    }
    
    func markNotificationRead(id: UUID) async throws {
        if await AuthService.shared.isDemoMode { return }
        
        let url = URL(string: "https://price-tracker-api.stopimpulsebuying.workers.dev/notifications/\(id.uuidString)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        
        let session = try await supabase.auth.session
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.networkError
        }
    }
    
    // MARK: - Wishlists
    
    func fetchWishlists() async throws -> [Wishlist] {
        if await AuthService.shared.isDemoMode {
            return [
                Wishlist(id: UUID(), userId: UUID(), name: "Dream Setup", icon: "display", createdAt: Date()),
                Wishlist(id: UUID(), userId: UUID(), name: "Travel Gear", icon: "airplane", createdAt: Date())
            ]
        }
        
        guard let userId = await AuthService.shared.currentUser?.id else {
            throw APIError.notAuthenticated
        }
        
        let wishlists: [Wishlist] = try await supabase
            .from("wishlists")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return wishlists
    }
    
    func createWishlist(name: String, icon: String) async throws -> Wishlist {
        if await AuthService.shared.isDemoMode {
            return Wishlist(id: UUID(), userId: UUID(), name: name, icon: icon, createdAt: Date())
        }
        
        guard let userId = await AuthService.shared.currentUser?.id else {
            throw APIError.notAuthenticated
        }
        
        let newWishlist = Wishlist(
            id: UUID(),
            userId: userId,
            name: name,
            icon: icon,
            createdAt: Date()
        )
        
        let inserted: Wishlist = try await supabase
            .from("wishlists")
            .insert(newWishlist)
            .select()
            .single()
            .execute()
            .value
        
        return inserted
    }
    
    func fetchWishlistItems(wishlistId: UUID) async throws -> [Product] {
        if await AuthService.shared.isDemoMode {
            return demoProducts
        }
        
        // Fetch items joined with products
        let items: [WishlistItemWithProduct] = try await supabase
            .from("wishlist_items")
            .select("*, product:products(*)")
            .eq("wishlist_id", value: wishlistId.uuidString)
            .execute()
            .value
        
        // Map to standard Product array
        return items.compactMap { $0.product }
    }
    
    func addToWishlist(productId: UUID, wishlistId: UUID) async throws {
        if await AuthService.shared.isDemoMode { return }
        
        let newItem = WishlistItem(
            id: UUID(),
            wishlistId: wishlistId,
            productId: productId,
            addedAt: Date()
        )
        
        try await supabase
            .from("wishlist_items")
            .insert(newItem)
            .execute()
    }
    
    func removeFromWishlist(productId: UUID, wishlistId: UUID) async throws {
        if await AuthService.shared.isDemoMode { return }
        
        try await supabase
            .from("wishlist_items")
            .delete()
            .eq("wishlist_id", value: wishlistId.uuidString)
            .eq("product_id", value: productId.uuidString)
            .execute()
    }
    
    func deleteWishlist(id: UUID) async throws {
        if await AuthService.shared.isDemoMode { return }
        
        try await supabase
            .from("wishlists")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    func updateWishlist(id: UUID, name: String, icon: String) async throws {
        if await AuthService.shared.isDemoMode { return }
        
        struct UpdatePayload: Encodable {
            let name: String
            let icon: String
        }
        
        let payload = UpdatePayload(name: name, icon: icon)
        
        try await supabase
            .from("wishlists")
            .update(payload)
            .eq("id", value: id.uuidString)
            .execute()
    }
}

// Helper for decoding joined data
private struct WishlistItemWithProduct: Decodable {
    let id: UUID
    let wishlistId: UUID
    let productId: UUID
    let addedAt: Date
    let product: Product?
    
    enum CodingKeys: String, CodingKey {
        case id, wishlistId = "wishlist_id", productId = "product_id", addedAt = "added_at", product
    }
}

enum APIError: LocalizedError {
    case notAuthenticated
    case productLimitReached
    case networkError
    case productNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in"
        case .productLimitReached:
            return "Product limit reached. Upgrade to track more."
        case .networkError:
            return "Network error. Please try again."
        case .productNotFound:
            return "Product not found"
        }
    }
}

extension JSONDecoder {
    static var customDateDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

// MARK: - Inlined Models & Managers

struct SIBNotification: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let productId: UUID?
    let title: String
    let body: String
    var isRead: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case productId = "product_id"
        case title
        case body
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

@MainActor
class NotificationManager: ObservableObject {
    @Published var notifications: [SIBNotification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading = false
    
    static let shared = NotificationManager()
    private var timer: AnyCancellable?
    
    private init() {
        startPolling()
    }
    
    func startPolling() {
        fetchNotifications()
        timer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchNotifications()
            }
    }
    
    func fetchNotifications() {
        Task {
            isLoading = true
            do {
                let fetched = try await APIClient.shared.fetchNotifications()
                self.notifications = fetched
                self.unreadCount = fetched.filter { !$0.isRead }.count
            } catch {
                print("Failed to fetch notifications: \(error)")
            }
            isLoading = false
        }
    }
    
    func markAsRead(_ notification: SIBNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            var updated = notifications[index]
            updated.isRead = true
            notifications[index] = updated
            unreadCount = notifications.filter { !$0.isRead }.count
        }
        
        Task {
            try? await APIClient.shared.markNotificationRead(id: notification.id)
        }
    }
}
