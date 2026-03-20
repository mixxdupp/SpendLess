import SwiftUI

public enum DesignSystem {
    public enum Colors {
        public static let background = Color.black
        public static let secondaryBackground = Color(red: 0.11, green: 0.11, blue: 0.12) // #1C1C1E
        public static let tertiaryBackground = Color(red: 0.17, green: 0.17, blue: 0.18) // #2C2C2E
        

        
        public static let textPrimary = Color.white
        public static let textSecondary = Color(white: 0.6)
        public static let textTertiary = Color(white: 0.4)
        
        public static let profit = Color(red: 0.06, green: 0.73, blue: 0.51) // #10B981 Emerald
        public static let destructive = Color.red // Warnings/Deletes should remain Red
        public static let success = profit
        public static let warning = Color.orange
        
        public static let accent = profit
        public static let accentGradient = LinearGradient(
            colors: [profit, Color(red: 0.2, green: 0.8, blue: 0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    public enum Typography {
        public static func largeTitle(_ text: String) -> Text {
            Text(text).font(.system(size: 34, weight: .bold))
        }
        
        public static func title(_ text: String) -> Text {
            Text(text).font(.system(size: 28, weight: .bold))
        }
        
        public static func headline(_ text: String) -> Text {
            Text(text).font(.headline)
        }
        
        public static func body(_ text: String) -> Text {
            Text(text).font(.body)
        }
        
        public static func caption(_ text: String) -> Text {
            Text(text).font(.caption)
        }
    }
    
    struct PrimaryButton: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Colors.accentGradient)
                .cornerRadius(12)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.3), value: configuration.isPressed)
        }
    }
    
    struct SecondaryButton: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.headline)
                .foregroundColor(Colors.accent)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Colors.secondaryBackground)
                .cornerRadius(12)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
        }
    }
}

extension View {
    func faangCardStyle() -> some View {
        self
            .background(DesignSystem.Colors.secondaryBackground)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

public enum HeroBackgroundStyle {
    case profit // Green/Mint/Forest
    case spent // Red/Orange/Pink
    case cool // Mint/Cyan/Blue
    case titan // Gold/Dark Slate
}

public struct HeroBackgroundView: View {
    public var style: HeroBackgroundStyle
    @State private var animate = false
    
    public init(style: HeroBackgroundStyle = .profit) {
        self.style = style
    }
    
    // Profit Colors (Dark Mode)
    private let profitColorsDark: [Color] = [
        Color(red: 0.0, green: 0.5, blue: 0.3), // Emerald
        Color(red: 0.1, green: 0.7, blue: 0.5), // Mint
        Color(red: 0.0, green: 0.3, blue: 0.1), // Dark Forest
        Color(red: 0.2, green: 0.8, blue: 0.4)  // Bright Green
    ]
    
    // Profit Colors (Light Mode)
    private let profitColorsLight: [Color] = [
        Color(red: 0.6, green: 0.9, blue: 0.8), // Soft Mint
        Color(red: 0.8, green: 1.0, blue: 0.9), // Pale Green
        Color(red: 0.4, green: 0.8, blue: 0.7), // Teal Mint
        Color(red: 0.7, green: 0.9, blue: 0.8)  // Light Sage
    ]
    
    // Spent Colors (Dark Mode)
    private let spentColorsDark: [Color] = [
        Color(red: 0.6, green: 0.1, blue: 0.1), // Dark Red
        Color(red: 0.8, green: 0.2, blue: 0.2), // Bright Red
        Color(red: 0.4, green: 0.0, blue: 0.0), // Deep Red
        Color(red: 0.9, green: 0.3, blue: 0.3)  // Soft Red
    ]
    
    // Spent Colors (Light Mode)
    private let spentColorsLight: [Color] = [
        Color(red: 1.0, green: 0.8, blue: 0.8), // Very Pale Red
        Color(red: 0.9, green: 0.6, blue: 0.6), // Soft Red
        Color(red: 1.0, green: 0.9, blue: 0.9), // White Red
        Color(red: 0.8, green: 0.4, blue: 0.4)  // Accent Red
    ]
    
    // Cool Colors (Blue Spectrum)
    private let coolColors: [Color] = [
        Color(red: 0.2, green: 0.8, blue: 0.6), // Mint
        Color(red: 0.1, green: 0.7, blue: 0.8), // Cyan
        Color(red: 0.0, green: 0.5, blue: 1.0), // Blue
        Color(red: 0.3, green: 0.9, blue: 0.7)  // Bright Green
    ]
    
    // Titan Colors (Natural/Black Titanium & Gold Spectrum)
    private let titanColors: [Color] = [
        Color(red: 0.3, green: 0.3, blue: 0.32), // Natural Titanium
        Color(red: 0.1, green: 0.1, blue: 0.1),  // Space Black
        Color(red: 0.8, green: 0.7, blue: 0.5), // Muted Gold (Accent)
        Color(red: 0.15, green: 0.15, blue: 0.16) // Graphite
    ]
    
    private var activeColors: [Color] {
        switch style {
        case .profit:
            return colorScheme == .dark ? profitColorsDark : profitColorsLight
        case .spent:
            return colorScheme == .dark ? spentColorsDark : spentColorsLight
        case .cool: return coolColors
        case .titan: return titanColors
        }
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    public var body: some View {
        ZStack {
            // Background Base
            if style == .profit {
                if colorScheme == .dark {
                    Color(red: 0.01, green: 0.12, blue: 0.05).ignoresSafeArea() // Very Dark Green Base
                } else {
                    Color(red: 0.95, green: 1.0, blue: 0.97).ignoresSafeArea() // Very Light Mint Base
                }
            } else if style == .spent {
                if colorScheme == .dark {
                    Color(red: 0.2, green: 0.0, blue: 0.0).ignoresSafeArea() // Dark Red Base
                } else {
                    Color(red: 1.0, green: 0.95, blue: 0.95).ignoresSafeArea() // Light Pink Base
                }
            } else if style == .cool {
                if colorScheme == .dark {
                    Color(red: 0.05, green: 0.05, blue: 0.1).ignoresSafeArea() // Dark Blue/Black Base
                } else {
                    Color(red: 0.96, green: 0.98, blue: 1.0).ignoresSafeArea() // Very Light Blue/White Base
                }
            } else if style == .titan {
                if colorScheme == .dark {
                    Color(red: 0.1, green: 0.1, blue: 0.12).ignoresSafeArea() // Dark Slate Base
                } else {
                    Color(red: 0.95, green: 0.95, blue: 0.97).ignoresSafeArea() // Light Gray Base
                }
            } else {
                Color(.systemBackground).ignoresSafeArea()
            }
            
            // Animated Gradient Orbs
            GeometryReader { proxy in
                ZStack {
                    // Orb 1
                    Circle()
                        .fill(activeColors[0].opacity(0.6))
                        .frame(width: 300, height: 300)
                        .blur(radius: 80)
                        .offset(x: animate ? -50 : 50, y: animate ? -40 : 40)
                    
                    // Orb 2
                    Circle()
                        .fill(activeColors[1].opacity(0.5))
                        .frame(width: 350, height: 350)
                        .blur(radius: 90)
                        .offset(x: animate ? 60 : -60, y: animate ? 30 : -30)
                    
                    // Orb 3
                    Circle()
                        .fill(activeColors[2].opacity(0.5))
                        .frame(width: 280, height: 280)
                        .blur(radius: 70)
                        .offset(x: animate ? -30 : 30, y: animate ? 60 : -60)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 7.0).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
}

// MARK: - Shared Button Styles

public struct BouncyButtonStyle: ButtonStyle {
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticManager.shared.softImpact()
                }
            }
    }
}
