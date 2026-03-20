import Foundation

enum SubscriptionTier: String, Codable {
    case free = "FREE"
    case paidOnetime = "PAID_ONETIME"
    case premiumSubscription = "PREMIUM_SUBSCRIPTION"
    
    var productLimit: Int? {
        switch self {
        case .free: return 1
        case .paidOnetime: return 10
        case .premiumSubscription: return nil // unlimited
        }
    }
    
    var priceCheckInterval: TimeInterval {
        switch self {
        case .free: return .infinity // manual only
        case .paidOnetime: return 86400 // 24 hours
        case .premiumSubscription: return 3600 // 1 hour
        }
    }
    
    var historyDays: Int {
        switch self {
        case .free: return 7
        case .paidOnetime: return 30
        case .premiumSubscription: return 90
        }
    }
    
    var hasPushAlerts: Bool {
        self != .free
    }
    
    var hasBrowserExtension: Bool {
        self != .free
    }
}

struct User: Codable, Identifiable {
    let id: UUID
    var subscriptionTier: SubscriptionTier
    var subscriptionExpiresAt: Date?
    let createdAt: Date
    
    var isSubscriptionActive: Bool {
        guard let expiresAt = subscriptionExpiresAt else {
            return subscriptionTier == .paidOnetime
        }
        return expiresAt > Date()
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case subscriptionTier = "subscription_tier"
        case subscriptionExpiresAt = "subscription_expires_at"
        case createdAt = "created_at"
    }
}
