import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var isAnimating = false
    
    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    ConfettiPiece(particle: particle)
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
            }
        }
        .allowsHitTesting(false)
    }
    
    private func createParticles(in size: CGSize) {
        for _ in 0..<50 {
            let particle = ConfettiParticle(
                x: CGFloat.random(in: 0...size.width),
                y: -20,
                color: colors.randomElement() ?? .blue,
                size: CGFloat.random(in: 6...12),
                rotation: Double.random(in: 0...360),
                xVelocity: CGFloat.random(in: -3...3),
                yVelocity: CGFloat.random(in: 2...6),
                rotationSpeed: Double.random(in: -10...10)
            )
            particles.append(particle)
        }
        
        // Animate particles
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            var allOffscreen = true
            
            for i in particles.indices {
                particles[i].y += particles[i].yVelocity
                particles[i].x += particles[i].xVelocity
                particles[i].rotation += particles[i].rotationSpeed
                particles[i].yVelocity += 0.1 // Gravity
                
                if particles[i].y < size.height + 50 {
                    allOffscreen = false
                }
            }
            
            if allOffscreen {
                timer.invalidate()
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let size: CGFloat
    var rotation: Double
    let xVelocity: CGFloat
    var yVelocity: CGFloat
    let rotationSpeed: Double
}

struct ConfettiPiece: View {
    let particle: ConfettiParticle
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size * 0.6)
            .rotationEffect(.degrees(particle.rotation))
            .position(x: particle.x, y: particle.y)
    }
}

// MARK: - Confetti Trigger Modifier
struct ConfettiModifier: ViewModifier {
    @Binding var isShowing: Bool
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if isShowing {
                ConfettiView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            isShowing = false
                        }
                    }
            }
        }
    }
}

extension View {
    func confetti(isShowing: Binding<Bool>) -> some View {
        modifier(ConfettiModifier(isShowing: isShowing))
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ConfettiView()
    }
}
