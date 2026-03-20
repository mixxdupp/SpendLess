import SwiftUI
import Charts

struct ProductCardView: View {
    let product: Product
    
    var body: some View {
        HStack(spacing: 16) {
            // Product Image (Square thumbnail style)
            ZStack {
                AsyncImage(url: product.imageUrl.flatMap(URL.init)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else if phase.error != nil {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    } else {
                        Rectangle()
                            .fill(Color(.secondarySystemFill))
                    }
                }
            }
            .frame(width: 80, height: 80)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator), lineWidth: 0.5))
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(storeName)
                    .font(.caption2)
                    .foregroundStyle(product.isBought ? .white.opacity(0.8) : .secondary)
                    .textCase(.uppercase)
                
                Text(product.title ?? "Loading...")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundStyle(product.isBought ? .white : .primary)
                
                Spacer(minLength: 0)
                
                // Price & Status
                HStack {
                    if let price = product.currentPrice {
                        PriceDisplayView(
                            price: price,
                            currency: product.currency,
                            font: .callout,
                            weight: .semibold,
                            color: priceColor
                        )
                    }
                    
                    Spacer()
                    
                    if product.isInCooldown {
                        HStack(spacing: 2) {
                            Image(systemName: "hourglass")
                            Text("\(product.daysUntilCooldownEnds)d")
                        }
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(12)
        .background(product.isBought ? DesignSystem.Colors.destructive : Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // Subtle shadow, native feel
        .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
    }
    
    private var priceColor: Color {
        if product.isBought { return .white } // White text on Red background
        switch product.priceTrend {
        case .down: return .green
        case .up: return .red
        case .neutral: return .primary
        }
    }
    
    private var storeName: String {
        guard let url = URL(string: product.url),
              let host = url.host else {
            return product.store ?? ""
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }

}

// MARK: - Cooldown Progress Ring
struct CooldownRingView: View {
    let progress: Double // 0.0 to 1.0
    let daysLeft: Int
    
    var body: some View {
        ZStack {
            // Background
            Circle()
                .stroke(Color.orange.opacity(0.2), lineWidth: 4)
                .frame(width: 36, height: 36)
            
            // Progress
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [.orange, .yellow, .orange],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 36, height: 36)
            
            // Days
            Text("\(daysLeft)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
        }
    }
}

// MARK: - Product Extension for Cooldown Progress
extension Product {
    var cooldownProgress: Double {
        guard isInCooldown else { return 1.0 }
        let totalDays = Double(cooldownDays)
        let daysElapsed = totalDays - Double(daysUntilCooldownEnds)
        return max(0, min(1, daysElapsed / totalDays))
    }
}

// MARK: - Price Display View (Merged)
struct PriceDisplayView: View {
    let price: Decimal
    let currency: String
    var font: Font = .body
    var weight: Font.Weight = .regular
    var color: Color = .primary
    
    @ObservedObject private var calculator = AffordabilityCalculator.shared
    @ObservedObject private var currencyService = CurrencyService.shared // Fix: Update when currency changes
    
    private var targetCurrency: SupportedCurrency {
        currencyService.preferredCurrency
    }
    
    private var convertedPrice: Decimal {
        CurrencyService.shared.convert(price, from: currency, to: targetCurrency)
    }
    
    private var formattedPrice: String {
        CurrencyService.shared.formatPrice(convertedPrice, currency: targetCurrency)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Always show the formatted price (Converted)
            Text(formattedPrice)
                .font(font)
                .fontWeight(weight)
                .foregroundStyle(color)
            
            // If calculator enabled, show "Days to Earn" below it
            if calculator.isEnabled {
                HStack(spacing: 4) {
                    Image(systemName: "briefcase.fill")
                        .font(.caption2)
                    // Pass the CONVERTED price and the TARGET currency to calculations
                    Text(calculator.daysToEarn(price: convertedPrice, currency: targetCurrency.rawValue))
                        .font(.caption)
                        .fontWeight(.medium)
                        .contentTransition(.numericText())
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }
}

#Preview {
    ProductCardView(product: .preview)
        .frame(width: 180)
        .padding()
}


