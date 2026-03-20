import SwiftUI

/// Full-screen overlay that displays AI-generated demotivation advice
struct DemotivationOverlay: View {
    let productTitle: String
    let productPrice: Double
    let productImageUrl: String?
    let daysToEarn: Double?
    let percentOfIncome: Double?
    let currency: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var message: String = ""
    @State private var displayedMessage: String = ""
    @State private var isLoading = true
    @State private var error: String?
    @State private var animationTimer: Timer?
    
    var body: some View {
        ZStack {
            // OLED Black background
            Color.black.ignoresSafeArea()
            
            // Subtle red warning glow at top
            RadialGradient(
                colors: [DesignSystem.Colors.destructive.opacity(0.15), Color.clear],
                center: .top,
                startRadius: 0,
                endRadius: 400
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignSystem.Colors.destructive, Color.orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .symbolEffect(.pulse, options: .repeating)
                    
                    Text("The Rationalist")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(DesignSystem.Colors.destructive) // Red Title
                    
                    Text("Your Anti-Salesman AI")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                // Product info card
                HStack(spacing: 12) {
                    if let imageUrl = productImageUrl,
                       let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(productTitle)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        
                        Text("\(currency)\(productPrice, specifier: "%.2f")")
                            .font(.headline)
                            .foregroundStyle(.red)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                // AI Message
                ScrollView {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .red))
                                .scaleEffect(1.2)
                            
                            Text("Analyzing your impulse...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)
                    } else if let error = error {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundStyle(.orange)
                            
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            Text(displayedMessage)
                                .font(.body)
                                .foregroundStyle(DesignSystem.Colors.destructive) // Red Body Text
                                .lineSpacing(6)
                                .padding(.horizontal)
                                .padding(.top, 8)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    Button {
                        HapticManager.shared.notification(type: .success)
                        dismiss()
                    } label: {
                        Text("I'll Pass on This")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(DesignSystem.Colors.profit)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    
                    Button {
                        HapticManager.shared.notification(type: .warning)
                        showConfirmation = true
                    } label: {
                        Text("Buy Anyway")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(DesignSystem.Colors.destructive)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .alert("Are you sure?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Yes, I Bought It", role: .destructive) {
                onBuyConfirmed?()
                dismiss()
            }
        } message: {
            Text("This will subtract from your Total Savings. Think about the compound interest!")
        }
        .task {
            await loadDemotivation()
        }
        .onDisappear {
            animationTimer?.invalidate()
        }
    }
    
    @State private var showConfirmation = false
    var onBuyConfirmed: (() -> Void)? = nil
    
    private func loadDemotivation() async {
        isLoading = true
        error = nil
        
        message = await RationalityService.shared.demotivate(
            title: productTitle,
            price: productPrice,
            imageUrl: productImageUrl,
            daysToEarn: daysToEarn,
            percentOfIncome: percentOfIncome,
            currency: currency
        )
        
        isLoading = false
        
        // Typewriter animation
        await startTypewriterAnimation()
    }
    
    @MainActor
    private func startTypewriterAnimation() async {
        displayedMessage = ""
        let characters = Array(message)
        
        for (index, char) in characters.enumerated() {
            displayedMessage.append(char)
            
            // Variable speed for natural feel
            let delay: UInt64 = char == " " ? 10_000_000 : 20_000_000 // 10ms or 20ms
            try? await Task.sleep(nanoseconds: delay)
            
            // Haptic every 20 characters
            if index % 20 == 0 {
                HapticManager.shared.impact(style: .light)
            }
        }
    }
}

#Preview {
    DemotivationOverlay(
        productTitle: "Sony WH-1000XM5 Wireless Headphones",
        productPrice: 349.99,
        productImageUrl: nil,
        daysToEarn: 2.5,
        percentOfIncome: 8.5,
        currency: "$"
    )
}
