import SwiftUI

struct SplashView: View {
    @Binding var isActive: Bool
    @State private var size = 0.8
    @State private var opacity = 0.5
    @State private var textOpacity = 0.0
    
    var body: some View {
        ZStack {
            // 1. The Emerald Stage (Matching AuthView)
            ZStack {
                Color.black
                
                // The Spotlight
                RadialGradient(
                    colors: [Color.emerald0.opacity(0.15), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 700
                )
                .opacity(0.5)
            }
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 2. Animated Logo (The Neon Cart)
                PrismaticCartLogo()
                    .scaleEffect(size)
                    .opacity(opacity)
                
                // 3. Animated Text
                VStack(spacing: 8) {
                    Text("SpendLess")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .tracking(0.5) // Matching AuthView
                        .shadow(color: Color.emerald0.opacity(0.3), radius: 10)
                    
                    Text("Master your money.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(textOpacity)
                .offset(y: textOpacity == 0 ? 20 : 0)
            }
        }
        .onAppear {
            // Sequence: Icon Grows -> Text Fades In -> App Launches
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                self.size = 1.0
                self.opacity = 1.0
            }
            
            withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
                self.textOpacity = 1.0
            }
            
            // Seamless transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    self.isActive = true
                }
            }
        }
    }
}

// Jewel Colors (Duplicated for Preview/Safety if not shared)
fileprivate extension Color {
    static let emerald0 = Color(red: 0.2, green: 0.9, blue: 0.5)
}

#Preview {
    // Mock PrismaticCartLogo for preview if not visible (it should be visible in module)
    SplashView(isActive: .constant(false))
}
