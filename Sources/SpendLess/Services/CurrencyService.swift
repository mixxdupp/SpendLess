import Foundation

// MARK: - Currency Model
enum SupportedCurrency: String, CaseIterable, Identifiable {
    case USD, INR, EUR, GBP, JPY, AUD, CAD
    
    var id: String { rawValue }
    
    var symbol: String {
        switch self {
        case .USD: return "$"
        case .INR: return "₹"
        case .EUR: return "€"
        case .GBP: return "£"
        case .JPY: return "¥"
        case .AUD: return "A$"
        case .CAD: return "C$"
        }
    }
    
    var name: String {
        switch self {
        case .USD: return "US Dollar"
        case .INR: return "Indian Rupee"
        case .EUR: return "Euro"
        case .GBP: return "British Pound"
        case .JPY: return "Japanese Yen"
        case .AUD: return "Australian Dollar"
        case .CAD: return "Canadian Dollar"
        }
    }
}

// MARK: - Currency Service
@MainActor
class CurrencyService: ObservableObject {
    static let shared = CurrencyService()
    
    @Published var preferredCurrency: SupportedCurrency {
        didSet {
            UserDefaults.standard.set(preferredCurrency.rawValue, forKey: "preferredCurrency")
        }
    }
    
    @Published var exchangeRates: [String: Double] = [:]
    @Published var lastUpdated: Date?
    
    private let cacheKey = "exchangeRatesCache"
    private let cacheTimeKey = "exchangeRatesCacheTime"
    
    private init() {
        // Load saved preference
        if let saved = UserDefaults.standard.string(forKey: "preferredCurrency"),
           let currency = SupportedCurrency(rawValue: saved) {
            self.preferredCurrency = currency
        } else {
            // Default based on locale
            let locale = Locale.current
            if locale.currency?.identifier == "INR" {
                self.preferredCurrency = .INR
            } else {
                self.preferredCurrency = .USD
            }
        }
        
        // Load cached rates
        loadCachedRates()
        
        // Fetch fresh rates if needed
        Task {
            await refreshRatesIfNeeded()
        }
    }
    
    // MARK: - Public API
    
    func convert(_ amount: Decimal, from sourceCurrency: String, to targetCurrency: SupportedCurrency? = nil) -> Decimal {
        let target = targetCurrency ?? preferredCurrency
        
        // Same currency, no conversion needed
        if sourceCurrency.uppercased() == target.rawValue {
            return amount
        }
        
        // Get rates (all rates are relative to USD)
        guard let sourceRate = getRate(for: sourceCurrency),
              let targetRate = getRate(for: target.rawValue) else {
            return amount // Return original if conversion not possible
        }
        
        // Convert: source -> USD -> target
        let amountInUSD = Double(truncating: amount as NSNumber) / sourceRate
        let convertedAmount = amountInUSD * targetRate
        
        return Decimal(convertedAmount)
    }
    
    func formatPrice(_ amount: Decimal, currency: SupportedCurrency? = nil) -> String {
        let curr = currency ?? preferredCurrency
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = curr.rawValue
        formatter.currencySymbol = curr.symbol
        
        return formatter.string(from: amount as NSNumber) ?? "\(curr.symbol)\(amount)"
    }
    
    func refreshRatesIfNeeded() async {
        // Check if cache is older than 24 hours
        if let lastUpdate = lastUpdated,
           Date().timeIntervalSince(lastUpdate) < 86400 {
            return // Cache is still valid
        }
        
        await fetchExchangeRates()
    }
    
    // MARK: - Private
    
    private func getRate(for currency: String) -> Double? {
        let code = currency.uppercased()
        if code == "USD" { return 1.0 }
        return exchangeRates[code]
    }
    
    private func fetchExchangeRates() async {
        // Using free exchangerate.host API (no key required)
        guard let url = URL(string: "https://api.exchangerate.host/latest?base=USD") else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rates = json["rates"] as? [String: Double] {
                
                self.exchangeRates = rates
                self.lastUpdated = Date()
                
                // Cache the rates
                UserDefaults.standard.set(rates, forKey: cacheKey)
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cacheTimeKey)
            }
        } catch {
            print("Failed to fetch exchange rates: \(error)")
            // Use fallback rates if fetch fails
            useFallbackRates()
        }
    }
    
    private func loadCachedRates() {
        if let cached = UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: Double] {
            self.exchangeRates = cached
        }
        
        let cacheTime = UserDefaults.standard.double(forKey: cacheTimeKey)
        if cacheTime > 0 {
            self.lastUpdated = Date(timeIntervalSince1970: cacheTime)
        }
        
        // Use fallback if no cache
        if exchangeRates.isEmpty {
            useFallbackRates()
        }
    }
    
    private func useFallbackRates() {
        // Approximate rates as of Feb 2026 (hardcoded fallback)
        exchangeRates = [
            "INR": 83.0,
            "EUR": 0.92,
            "GBP": 0.79,
            "JPY": 149.0,
            "AUD": 1.53,
            "CAD": 1.35
        ]
    }
}
