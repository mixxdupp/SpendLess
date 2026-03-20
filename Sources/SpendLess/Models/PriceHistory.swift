import Foundation

struct PriceHistory: Codable, Identifiable {
    let id: UUID
    let productId: UUID
    let price: Decimal
    let recordedAt: Date
}

extension PriceHistory {
    static var previews: [PriceHistory] {
        let productId = UUID()
        let now = Date()
        return [
            PriceHistory(id: UUID(), productId: productId, price: 249.99, recordedAt: now.addingTimeInterval(-86400 * 30)),
            PriceHistory(id: UUID(), productId: productId, price: 239.99, recordedAt: now.addingTimeInterval(-86400 * 25)),
            PriceHistory(id: UUID(), productId: productId, price: 229.99, recordedAt: now.addingTimeInterval(-86400 * 20)),
            PriceHistory(id: UUID(), productId: productId, price: 249.99, recordedAt: now.addingTimeInterval(-86400 * 15)),
            PriceHistory(id: UUID(), productId: productId, price: 219.99, recordedAt: now.addingTimeInterval(-86400 * 10)),
            PriceHistory(id: UUID(), productId: productId, price: 249.99, recordedAt: now.addingTimeInterval(-86400 * 5)),
            PriceHistory(id: UUID(), productId: productId, price: 199.99, recordedAt: now)
        ]
    }
}
