import SwiftUI
import Supabase
import Combine

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isDemoMode = false
    @Published var isTabBarHidden = false
    
    private let supabase: SupabaseClient
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Supabase credentials (from centralized Config)
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
        
        Task {
            await checkAuthStatus()
        }
    }
    
    func enableDemoMode() async {
        let demoUser = User(
            id: UUID(),
            subscriptionTier: .paidOnetime, // Premium features for demo
            subscriptionExpiresAt: nil,
            createdAt: Date()
        )
        isDemoMode = true
        currentUser = demoUser
        isAuthenticated = true
    }
    
    func checkAuthStatus() async {
        do {
            let session = try await supabase.auth.session
            isAuthenticated = true
            await fetchUser(userId: session.user.id)
        } catch {
            isAuthenticated = false
            currentUser = nil
        }
    }
    
    func signUp(email: String, password: String) async throws {
        let response = try await supabase.auth.signUp(
            email: email,
            password: password
        )
        
        // response.user is non-optional in latest Supabase SDK
        let userId = response.user.id
        
        // User record is created by Database Trigger (on_auth_user_created)
        // No manual insert needed here.
        
        if response.session != nil {
             await fetchUser(userId: userId)
             isAuthenticated = true
        } else {
            // Email confirmation required
            // We don't set isAuthenticated = true yet
            print("Check your email for confirmation link")
        }
    }
    
    func signIn(email: String, password: String) async throws {
        let session = try await supabase.auth.signIn(
            email: email,
            password: password
        )
        
        await fetchUser(userId: session.user.id)
        isAuthenticated = true
    }
    
    func signOut() async throws {
        if isDemoMode {
            isDemoMode = false
            isAuthenticated = false
            currentUser = nil
            return
        }
        try await supabase.auth.signOut()
        isAuthenticated = false
        currentUser = nil
    }
    
    private func fetchUser(userId: UUID) async {
        do {
            let user: User = try await supabase
                .from("users")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            currentUser = user
        } catch {
            print("Failed to fetch user: \(error)")
        }
    }
    
    func updateSubscriptionTier(_ tier: SubscriptionTier, expiresAt: Date? = nil) async throws {
        guard let userId = currentUser?.id else {
            throw AuthError.notAuthenticated
        }
        
        struct SubscriptionUpdate: Encodable {
            let subscription_tier: String
            let subscription_expires_at: String?
        }
        
        let update = SubscriptionUpdate(
            subscription_tier: tier.rawValue,
            subscription_expires_at: expiresAt?.ISO8601Format()
        )
        
        try await supabase
            .from("users")
            .update(update)
            .eq("id", value: userId.uuidString)
            .execute()
        
        currentUser?.subscriptionTier = tier
        currentUser?.subscriptionExpiresAt = expiresAt
    }
    
    func handleUrl(_ url: URL) async throws {
        // Handle Supabase OAuth/Magic Link callback
        try await supabase.auth.session(from: url)
        await checkAuthStatus()
    }
}

enum AuthError: LocalizedError {
    case signUpFailed
    case signInFailed
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .signUpFailed: return "Failed to create account"
        case .signInFailed: return "Invalid email or password"
        case .notAuthenticated: return "You must be signed in"
        }
    }
}

@MainActor
class AffordabilityCalculator: ObservableObject {
    static let shared = AffordabilityCalculator()
    
    @AppStorage("affordability_enabled") var isEnabled = false
    @AppStorage("affordability_monthly_income") var monthlyIncome: Double = 0
    @AppStorage("affordability_work_days_per_week") var workDaysPerWeek: Double = 5.0
    @AppStorage("affordability_income_currency") var incomeCurrency: String = "USD"
    
    // Average weeks in a month
    private let weeksPerMonth = 4.33
    
    var dailyIncome: Double {
        guard workDaysPerWeek > 0 else { return 0 }
        let monthlyWorkDays = workDaysPerWeek * weeksPerMonth
        return monthlyIncome / monthlyWorkDays
    }
    
    // Get daily income converted to the target currency
    func dailyIncome(in targetCurrency: String) -> Double {
        let income = dailyIncome
        // If income currency matches target, return as is
        if incomeCurrency == targetCurrency {
            return income
        }
        
        // Convert Income -> Target
        // We can use CurrencyService to convert. Since AffordabilityCalculator is inside AuthService, 
        // we can access CurrencyService.shared (it's a singleton and MainActor).
        // However, we are in a synchronous property/func. 
        // CurrencyService.convert is non-async.
        
        // We have `CurrencyService.shared.convert`.
        // We need to cast our Double income to Decimal for the service.
        let converted = CurrencyService.shared.convert(Decimal(income), from: incomeCurrency, to: SupportedCurrency(rawValue: targetCurrency))
        return NSDecimalNumber(decimal: converted).doubleValue
    }
    
    var hourlyIncome: Double {
        return dailyIncome / 8.0
    }
    
    func daysToEarn(price: Decimal, currency: String = "USD") -> String {
        // Convert daily income to the product's currency so we compare same units
        let dailyIncomeInProductCurrency = dailyIncome(in: currency)
        
        guard dailyIncomeInProductCurrency > 0 else { return "N/A" }
        let priceDouble = NSDecimalNumber(decimal: price).doubleValue
        
        let days = priceDouble / dailyIncomeInProductCurrency
        
        if days < 0.1 {
            return "< 0.1 Days"
        } else {
            return String(format: "%.1f Days", days)
        }
    }
    
    func percentageOfIncome(price: Decimal) -> String {
        guard monthlyIncome > 0 else { return "N/A" }
        let priceDouble = NSDecimalNumber(decimal: price).doubleValue
        
        let percentage = (priceDouble / monthlyIncome) * 100
        
        if percentage < 0.1 {
            return "< 0.1%"
        } else {
            return String(format: "%.1f%%", percentage)
        }
    }
    
    func getDemotivationMessage(price: Decimal, currency: String = "USD") -> String {
        guard monthlyIncome > 0, dailyIncome > 0 else { return "" }
         
        // Convert price to income currency for accurate comparison
        let convertedPrice = CurrencyService.shared.convert(price, from: currency, to: SupportedCurrency(rawValue: incomeCurrency))
        let priceDouble = NSDecimalNumber(decimal: convertedPrice).doubleValue
        
        let days = priceDouble / dailyIncome
        let percentage = (priceDouble / monthlyIncome) * 100
        
        if percentage > 100 {
            return "CRITICAL: This costs MORE than your entire monthly salary! You cannot afford this."
        } else if percentage > 50 {
            return "WARNING: This is over half your monthly salary. Is it really necessary?"
        } else if percentage > 20 {
            return "This purchase requires \(String(format: "%.1f", days)) days of hard labor."
        } else if percentage > 10 {
            return "That's 10% of your month gone in one click."
        } else if percentage > 5 {
            return "Is this worth working \(String(format: "%.1f", days)) days for?"
        } else {
            return "Think twice. Every penny counts toward your freedom."
        }
    }
}

import CoreHaptics

class HapticManager {
    static let shared = HapticManager()
    
    private var engine: CHHapticEngine?
    
    private init() {
        prepareHaptics()
    }
    
    func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("Haptic engine failed to start: \(error.localizedDescription)")
        }
    }
    
    func softImpact() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func rigidImpact() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    // Custom "Thud" pattern for adding items
    func successThud() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        var events = [CHHapticEvent]()
        
        // Sharp tap
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        events.append(event)
        
        // Followed by a rumble
        let rumbleIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
        let rumbleSharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
        let rumble = CHHapticEvent(eventType: .hapticContinuous, parameters: [rumbleIntensity, rumbleSharpness], relativeTime: 0.1, duration: 0.2)
        events.append(rumble)
        
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play haptic pattern: \(error)")
        }
    }
}
