import Foundation

/// Centralized configuration for the SpendLess app
/// All environment-specific values should be defined here
enum Config {
    
    // MARK: - Backend API
    static let backendBaseURL = Secrets.backendBaseURL
    
    // MARK: - Supabase (credentials loaded from gitignored Secrets.swift)
    static let supabaseURL = Secrets.supabaseURL
    static let supabaseAnonKey = Secrets.supabaseAnonKey
    
    // MARK: - Legal URLs
    static let privacyPolicyURL = URL(string: "https://stopimpulsebuying.com/privacy")!
    static let termsOfServiceURL = URL(string: "https://stopimpulsebuying.com/terms")!
    static let supportEmail = "support@stopimpulsebuying.com"
    
    // MARK: - App Info
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    // MARK: - Timeouts
    static let networkTimeout: TimeInterval = 30
    static let aiRequestTimeout: TimeInterval = 60
    
    // MARK: - Limits
    static let maxProductsFreeTier = 3
    static let maxProductsPremium = 100
    static let maxHTMLSizeForAI = 15000
}
