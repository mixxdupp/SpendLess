import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case dark
    case light
    case system
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .system: return "System"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var selectedTheme: AppTheme {
        willSet {
            objectWillChange.send()
            print("🎨 [Theme] Changing from \(selectedTheme) to \(newValue)")
        }
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: "appTheme")
            UserDefaults.standard.synchronize()
            print("🎨 [Theme] Saved: \(selectedTheme.rawValue)")
        }
    }
    
    private init() {
        let savedTheme = UserDefaults.standard.string(forKey: "appTheme") ?? "system"
        self.selectedTheme = AppTheme(rawValue: savedTheme) ?? .system
        print("🎨 [Theme] Loaded: \(selectedTheme.rawValue)")
    }
}
