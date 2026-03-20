import SwiftUI

@main
struct SpendLessApp: App {
    @StateObject private var authService = AuthService.shared
    @StateObject private var purchaseService = PurchaseService.shared
    @StateObject private var themeManager = ThemeManager.shared
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var isSplashActive = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if !isSplashActive {
                    SplashView(isActive: $isSplashActive)
                        .environmentObject(themeManager)
                } else if !hasSeenOnboarding {
                    OnboardingView()
                        .environmentObject(themeManager)
                } else if authService.isAuthenticated {
                    let _ = print("📱 [App] Rendering MainTabView")
                    MainTabView()
                        .environmentObject(authService)
                        .environmentObject(purchaseService)
                        .environmentObject(themeManager)
                } else {
                    let _ = print("📱 [App] Rendering AuthView")
                    AuthView()
                        .environmentObject(authService)
                        .environmentObject(themeManager)
                }
            }
            .preferredColorScheme(themeManager.selectedTheme.colorScheme)
        }
    }
}
