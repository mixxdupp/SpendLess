import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var purchaseService: PurchaseService
    @EnvironmentObject var authService: AuthService
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedProduct: StoreKit.Product?
    @State private var showConfetti = false
    
    // UI Animations
    @State private var appear = false
    
    var body: some View {
        ZStack {
            // Background
            HeroBackgroundView(style: .titan)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    // Header Section
                    VStack(spacing: 20) {
                        TitanCardView()
                            .scaleEffect(appear ? 1 : 0.8)
                            .opacity(appear ? 1 : 0)
                            .shadow(color: .black.opacity(0.4), radius: 30, y: 15)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: appear)
                        
                        VStack(spacing: 8) {
                            Text("Upgrade to Titan")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                            
                            Text("Join the top 1% of savers who reclaimed\nover **$1.2M** this month.")
                                .font(.callout)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .offset(y: appear ? 0 : 20)
                        .opacity(appear ? 1 : 0)
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: appear)
                    }
                    .padding(.top, 40)
                    
                    // Features Comparison
                    VStack(spacing: 0) {
                        featureRow(icon: "bag.fill", title: "Product Limit", free: "5 Items", titan: "Unlimited")
                        Divider().overlay(Color.white.opacity(0.1))
                        featureRow(icon: "arrow.clockwise", title: "Price Refresh", free: "Manual", titan: "Hourly")
                        Divider().overlay(Color.white.opacity(0.1))
                        featureRow(icon: "chart.bar.xaxis", title: "History", free: "7 Days", titan: "Lifetime")
                        Divider().overlay(Color.white.opacity(0.1))
                        featureRow(icon: "brain.head.profile", title: "AI Analysis", free: "-", titan: "Deep Dive")
                        /*
                        Divider().overlay(Color.white.opacity(0.1))
                        featureRow(icon: "laptopcomputer", title: "Extension", free: "-", titan: "Sync Mode")
                        */
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )
                    .padding(.horizontal)
                    .offset(y: appear ? 0 : 20)
                    .opacity(appear ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.4), value: appear)
                    
                    // Pricing Section
                    VStack(spacing: 16) {
                        if isLoading { // Use local state, PurchaseService doesn't expose loading
                            ProgressView()
                                .tint(.white)
                                .frame(height: 100)
                        } else {
                            // Annual Plan (Best Value)
                            if let annual = purchaseService.products.first(where: { $0.id.contains("annual") }) {
                                planCard(product: annual, isBestValue: true)
                            }
                            
                            // Monthly Plan
                            if let monthly = purchaseService.products.first(where: { $0.id.contains("monthly") }) {
                                planCard(product: monthly)
                            }
                            
                            // Lifetime (Unlock)
                            if let unlock = purchaseService.products.first(where: { $0.id.contains("unlock") || $0.id.contains("lifetime") }) {
                                planCard(product: unlock, labelOverride: "Lifetime Unlock")
                            }
                        }
                    }
                    .padding(.horizontal)
                    .offset(y: appear ? 0 : 20)
                    .opacity(appear ? 1 : 0)
                    .animation(.easeOut(duration: 0.5).delay(0.6), value: appear)
                    
                    // Footer
                    VStack(spacing: 16) {
                        Button {
                            Task { await restorePurchases() }
                        } label: {
                            Text("Restore Purchases")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.5))
                                .underline()
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        Text("Terms of Service & Privacy Policy")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.3))
                            .padding(.bottom, 40)
                    }
                }
            }
            
            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .task {
            await purchaseService.loadProducts()
            withAnimation { appear = true }
        }
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private func featureRow(icon: String, title: String, free: String, titan: String) -> some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 20)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.9))
            }
            
            Spacer()
            
            HStack(spacing: 24) {
                Text(free)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
                    .strikethrough(free == "-" ? false : true)
                
                Text(titan)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.yellow)
                    .shadow(color: .orange.opacity(0.5), radius: 8)
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private func planCard(product: StoreKit.Product, isBestValue: Bool = false, labelOverride: String? = nil) -> some View {
        Button {
            Task { await purchase(product) }
        } label: {
            HStack(spacing: 16) {
                // Radio Circle (Visual Selection)
                Circle()
                    .strokeBorder(isBestValue ? Color(red: 0.8, green: 0.7, blue: 0.5) : Color.white.opacity(0.3), lineWidth: 2)
                    .background(Circle().fill(isBestValue ? Color(red: 0.8, green: 0.7, blue: 0.5) : Color.clear))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.black)
                            .opacity(isBestValue ? 1 : 0)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(labelOverride ?? product.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        
                        if isBestValue {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(red: 0.8, green: 0.7, blue: 0.5))
                                .clipShape(Capsule())
                        }
                    }
                    
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 0) {
                    Text(product.displayPrice)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                    
                    if let subscription = product.subscription {
                         Text(subscription.subscriptionPeriod.unit == .year ? "/ year" : "/ month")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    } else {
                        Text("one-time")
                           .font(.caption2)
                           .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(white: 0.15).opacity(0.8)) // Dark Grey Glass
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        isBestValue ? Color(red: 0.8, green: 0.7, blue: 0.5) : Color.white.opacity(0.1),
                        lineWidth: isBestValue ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(BouncyButtonStyle())
    }
    
    // MARK: - Actions
    
    private func purchase(_ product: StoreKit.Product) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            if let _ = try await purchaseService.purchase(product) {
                HapticManager.shared.notification(type: .success)
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.shared.notification(type: .error)
        }
    }
    
    private func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        await purchaseService.restorePurchases()
    }
}

#Preview {
    PaywallView()
        .environmentObject(PurchaseService.shared)
        .environmentObject(AuthService.shared)
}
