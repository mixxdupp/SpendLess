import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    
    private let pages: [(icon: String, title: String, subtitle: String, color: Color)] = [
        (
            icon: "cart.badge.clock",
            title: "Track Items You Want",
            subtitle: "Found something you love? Add it here instead of buying immediately.",
            color: .blue
        ),
        (
            icon: "bell.badge",
            title: "Get Price Drop Alerts",
            subtitle: "We'll notify you when prices drop so you never miss a deal.",
            color: .green
        ),
        (
            icon: "clock.badge.checkmark",
            title: "Beat Impulse Buying",
            subtitle: "The cooldown period helps you decide if you really need it.",
            color: .orange
        )
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [pages[currentPage].color.opacity(0.15), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .foregroundStyle(.secondary)
                    .padding()
                }
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPageView(
                            icon: pages[index].icon,
                            title: pages[index].title,
                            subtitle: pages[index].subtitle,
                            color: pages[index].color
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Custom page indicators
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? pages[currentPage].color : Color.gray.opacity(0.3))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.vertical, 24)
                
                // Action button
                Button {
                    if currentPage == pages.count - 1 {
                        completeOnboarding()
                    } else {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                } label: {
                    Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(pages[currentPage].color)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .animation(.easeInOut, value: currentPage)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
    
    private func completeOnboarding() {
        withAnimation {
            hasSeenOnboarding = true
        }
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

struct OnboardingPageView: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon with animated breathing effect
            PhaseAnimator([false, true]) { isBreathing in
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.3), color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(isBreathing ? 1.05 : 1.0)
                        .opacity(isBreathing ? 1.0 : 0.8)
                    
                    Image(systemName: icon)
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(color)
                        .scaleEffect(isBreathing ? 1.1 : 1.0)
                        .rotationEffect(.degrees(isBreathing ? 5 : -5))
                }
            } animation: { isBreathing in
                .easeInOut(duration: 2.5).repeatForever(autoreverses: true)
            }
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .transition(.push(from: .bottom))
                
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .transition(.opacity)
            }
            
            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}
