import Foundation

struct Product: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var url: String
    var title: String?
    var imageUrl: String?
    var currentPrice: Decimal?
    var currency: String
    var store: String? // amazon, walmart, bestbuy, target
    var alertEnabled: Bool
    var alertThreshold: Decimal? // alert if price drops below this
    var cooldownDays: Int // impulse blocker: wait X days before alerts
    var isBought: Bool = false // Negative savings flag
    let createdAt: Date
    var lastCheckedAt: Date?
    
    // Joined Data (Optional)
    var priceHistory: [PriceHistory]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case url
        case title
        case imageUrl = "image_url"
        case currentPrice = "current_price"
        case currency
        case store
        case alertEnabled = "alert_enabled"
        case alertThreshold = "alert_threshold"
        case cooldownDays = "cooldown_days"
        case isBought = "is_bought"
        case createdAt = "created_at"
        case lastCheckedAt = "last_checked_at"
        case priceHistory = "price_history"
    }
    
    var cooldownEndsAt: Date {
        Calendar.current.date(byAdding: .day, value: cooldownDays, to: createdAt) ?? createdAt
    }
    
    var isInCooldown: Bool {
        Date() < cooldownEndsAt
    }
    
    var daysUntilCooldownEnds: Int {
        guard isInCooldown else { return 0 }
        return Calendar.current.dateComponents([.day], from: Date(), to: cooldownEndsAt).day ?? 0
    }
    
    // Price Helpers
    enum PriceTrend {
        case up, down, neutral
    }
    
    var priceTrend: PriceTrend {
        guard let history = priceHistory, history.count >= 2 else { return .neutral }
        // Sort history by date descending
        let sorted = history.sorted { $0.recordedAt > $1.recordedAt }
        guard let latest = sorted.first, let previous = sorted.dropFirst().first else { return .neutral }
        
        if latest.price < previous.price { return .down }
        if latest.price > previous.price { return .up }
        return .neutral
    }
    
    var priceChangeAmount: Decimal {
        guard let history = priceHistory, history.count >= 2 else { return 0 }
        let sorted = history.sorted { $0.recordedAt > $1.recordedAt }
        guard let latest = sorted.first, let previous = sorted.dropFirst().first else { return 0 }
        return latest.price - previous.price
    }
    
    // Explicit encoding to enforce snake_case
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(url, forKey: .url)
        try container.encode(title, forKey: .title)
        try container.encode(imageUrl, forKey: .imageUrl)
        try container.encode(currentPrice, forKey: .currentPrice)
        try container.encode(currency, forKey: .currency)
        try container.encode(store, forKey: .store)
        try container.encode(alertEnabled, forKey: .alertEnabled)
        try container.encode(alertThreshold, forKey: .alertThreshold)
        try container.encode(cooldownDays, forKey: .cooldownDays)
        try container.encode(isBought, forKey: .isBought)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastCheckedAt, forKey: .lastCheckedAt)
        // We usually don't encode joined data back, but no harm
        try container.encodeIfPresent(priceHistory, forKey: .priceHistory)
    }
    
    // Explicit decoding to enforce snake_case
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        url = try container.decode(String.self, forKey: .url)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        currentPrice = try container.decodeIfPresent(Decimal.self, forKey: .currentPrice)
        currency = try container.decode(String.self, forKey: .currency)
        store = try container.decodeIfPresent(String.self, forKey: .store)
        alertEnabled = try container.decode(Bool.self, forKey: .alertEnabled)
        alertThreshold = try container.decodeIfPresent(Decimal.self, forKey: .alertThreshold)
        cooldownDays = try container.decode(Int.self, forKey: .cooldownDays)
        isBought = try container.decodeIfPresent(Bool.self, forKey: .isBought) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastCheckedAt = try container.decodeIfPresent(Date.self, forKey: .lastCheckedAt)
        priceHistory = try container.decodeIfPresent([PriceHistory].self, forKey: .priceHistory)
    }
    
    // Manual init for app usage
    init(id: UUID, userId: UUID, url: String, title: String?, imageUrl: String?, currentPrice: Decimal?, currency: String, store: String?, alertEnabled: Bool, alertThreshold: Decimal?, cooldownDays: Int, createdAt: Date, lastCheckedAt: Date?, priceHistory: [PriceHistory]? = nil) {
        self.id = id
        self.userId = userId
        self.url = url
        self.title = title
        self.imageUrl = imageUrl
        self.currentPrice = currentPrice
        self.currency = currency
        self.store = store
        self.alertEnabled = alertEnabled
        self.alertThreshold = alertThreshold
        self.cooldownDays = cooldownDays
        self.isBought = false
        self.createdAt = createdAt
        self.lastCheckedAt = lastCheckedAt
        self.priceHistory = priceHistory
    }
}

extension Product {
    static var preview: Product {
        Product(
            id: UUID(),
            userId: UUID(),
            url: "https://www.amazon.com/dp/B0CHWRXH8B",
            title: "Apple AirPods Pro (2nd Generation)",
            imageUrl: "https://m.media-amazon.com/images/I/61SUj2aKoEL._AC_SL1500_.jpg",
            currentPrice: 249.99,
            currency: "USD",
            store: "amazon",
            alertEnabled: true,
            alertThreshold: 199.99,
            cooldownDays: 7,
            createdAt: Date().addingTimeInterval(-86400 * 3),
            lastCheckedAt: Date(),
            priceHistory: PriceHistory.previews
        )
    }
}


