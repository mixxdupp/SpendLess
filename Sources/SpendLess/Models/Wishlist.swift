import Foundation

struct Wishlist: Identifiable, Codable, Hashable {
    let id: UUID
    let userId: UUID
    var name: String
    var icon: String // SF Symbol name
    let createdAt: Date
    
    // UI Helpers
    static var preview: Wishlist {
        Wishlist(
            id: UUID(),
            userId: UUID(),
            name: "Gaming Setup",
            icon: "gamecontroller.fill",
            createdAt: Date()
        )
    }
}

struct WishlistItem: Identifiable, Codable {
    let id: UUID
    let wishlistId: UUID
    let productId: UUID
    let addedAt: Date
    
    // Optional expanded product data (when fetching with join)
    var product: Product?
}
