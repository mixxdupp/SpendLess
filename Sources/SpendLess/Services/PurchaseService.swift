import Foundation
import StoreKit

// Type alias to avoid conflict with app's Product model
typealias StoreProduct = StoreKit.Product

@MainActor
class PurchaseService: ObservableObject {
    static let shared = PurchaseService()
    
    @Published var products: [StoreProduct] = []
    @Published var purchasedProductIDs: Set<String> = []
    
    private let productIDs = [
        "com.spendless.unlock",
        "com.spendless.titan.lifetime",
        "com.spendless.titan.monthly",
        "com.spendless.titan.annual"
    ]
    
    private var updates: Task<Void, Never>?
    
    private init() {
        updates = observeTransactionUpdates()
    }
    
    deinit {
        updates?.cancel()
    }
    
    func loadProducts() async {
        do {
            products = try await StoreProduct.products(for: productIDs)
            await updatePurchasedProducts()
        } catch {
            print("Failed to load products: \(error)")
        }
    }
    
    func purchase(_ product: StoreProduct) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updatePurchasedProducts()
            return transaction
            
        case .userCancelled, .pending:
            return nil
            
        @unknown default:
            return nil
        }
    }
    
    func restorePurchases() async {
        for await result in Transaction.currentEntitlements {
            guard case .verified(_) = result else { continue }
            await updatePurchasedProducts()
        }
    }
    
    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            
            if transaction.revocationDate == nil {
                purchased.insert(transaction.productID)
            }
        }
        
        purchasedProductIDs = purchased
        
        // Update user subscription tier based on purchases
        if purchased.contains("com.spendless.titan.monthly") ||
           purchased.contains("com.spendless.titan.annual") {
            try? await AuthService.shared.updateSubscriptionTier(.premiumSubscription)
        } else if purchased.contains("com.spendless.unlock") || 
                  purchased.contains("com.spendless.titan.lifetime") {
            try? await AuthService.shared.updateSubscriptionTier(.paidOnetime)
        }
    }
    
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await updatePurchasedProducts()
            }
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    var hasUnlocked: Bool {
        !purchasedProductIDs.isEmpty
    }
    
    var hasPremium: Bool {
        purchasedProductIDs.contains("com.spendless.titan.monthly") ||
        purchasedProductIDs.contains("com.spendless.titan.annual")
    }
}

enum PurchaseError: LocalizedError {
    case failedVerification
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Purchase verification failed"
        }
    }
}
