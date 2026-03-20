import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var purchaseService: PurchaseService
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var affordabilityCalculator = AffordabilityCalculator.shared
    @ObservedObject var currencyService = CurrencyService.shared // Fix: Observe currency changes
    
    @State private var showPaywall = false
    @State private var showSignOutConfirmation = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Titan Upgrade Banner (Visible if not Premium)
                if authService.currentUser?.subscriptionTier != .premiumSubscription || authService.isDemoMode {
                    Section {
                        Button {
                            showPaywall = true
                        } label: {
                            TitanCardView()
                                .frame(height: 200)

                        }
                        .listRowInsets(EdgeInsets()) // Remove default padding
                        .listRowBackground(Color.clear)
                    }
                }

                // Appearance section
                Section {
                    Picker("Theme", selection: $themeManager.selectedTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                }

                // Subscription section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Plan")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Text(tierName)
                                .font(.headline)
                        }
                        
                        Spacer()
                        
                        if authService.currentUser?.subscriptionTier == .free {
                            Button("Upgrade") {
                                showPaywall = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    
                    if let limit = authService.currentUser?.subscriptionTier.productLimit {
                        HStack {
                            Text("Product Limit")
                            Spacer()
                            Text("\(limit)")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            Text("Product Limit")
                            Spacer()
                            Text("Unlimited")
                                .foregroundStyle(.green)
                        }
                    }
                } header: {
                    Text("Subscription")
                }
                
                // Account section
                Section {
                    if let email = authService.currentUser?.id.uuidString {
                        HStack {
                            Text("Account ID")
                            Spacer()
                            Text(email.prefix(8) + "...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        Text("Sign Out")
                    }
                } header: {
                    Text("Account")
                }
                
                // Currency section
                Section {
                    Picker("Preferred Currency", selection: Binding(
                        get: { CurrencyService.shared.preferredCurrency },
                        set: { CurrencyService.shared.preferredCurrency = $0 }
                    )) {
                        ForEach(SupportedCurrency.allCases) { currency in
                            HStack {
                                Text(currency.symbol)
                                Text(currency.name)
                            }
                            .tag(currency)
                        }
                    }
                    
                    if let lastUpdated = CurrencyService.shared.lastUpdated {
                        HStack {
                            Text("Rates Updated")
                            Spacer()
                            Text(lastUpdated, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Currency")
                } footer: {
                    Text("Prices will be converted automatically")
                }
                
                // Impulse Control Section (Premium Card Style)
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.orange.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Image(systemName: "brain.head.profile")
                                    .foregroundStyle(.orange)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Affordability Mode")
                                    .font(.headline)
                                Text("Visualize cost in working days")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $affordabilityCalculator.isEnabled)
                                .labelsHidden()
                                .onChange(of: affordabilityCalculator.isEnabled) { _, _ in
                                    HapticManager.shared.softImpact()
                                }
                        }
                        
                        if affordabilityCalculator.isEnabled {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Monthly Income")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                
                                HStack {
                                    Text(affordabilityCalculator.incomeCurrency)
                                        .font(.system(.body, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .onTapGesture {
                                            // Cycle currencies? Or just show it's static for now or specific picker needed. 
                                            // Simple tap feedback
                                            HapticManager.shared.softImpact()
                                        }
                                    
                                    TextField("0.00", text: Binding(
                                        get: {
                                            affordabilityCalculator.monthlyIncome == 0 ? "" : String(format: "%.0f", affordabilityCalculator.monthlyIncome)
                                        },
                                        set: { newValue in
                                            affordabilityCalculator.monthlyIncome = Double(newValue) ?? 0
                                        }
                                    ))
                                    .keyboardType(.numberPad)
                                    .font(.system(.title3, design: .rounded).bold())
                                    
                                    Picker("", selection: $affordabilityCalculator.incomeCurrency) {
                                        ForEach(SupportedCurrency.allCases) { currency in
                                            Text(currency.rawValue).tag(currency.rawValue)
                                        }
                                    }
                                    .labelsHidden()
                                    .accentColor(.secondary)
                                }
                                .padding(12)
                                .background(Color(.tertiarySystemFill))
                                .cornerRadius(12)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Work Days / Week")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(.secondary)
                                    
                                    TextField("5.0", value: $affordabilityCalculator.workDaysPerWeek, format: .number)
                                        .keyboardType(.decimalPad)
                                        .font(.system(.body, design: .rounded).bold())
                                }
                                .padding(12)
                                .background(Color(.tertiarySystemFill))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Mindset")
                } footer: {
                    if affordabilityCalculator.isEnabled {
                        Text("We'll translate every price tag into hours of your life.")
                            .foregroundStyle(.secondary)
                    }
                }
                
                /*
                // Sync Section
                Section {
                    NavigationLink {
                        SyncExtensionView()
                    } label: {
                        Label("Sync with Chrome Extension", systemImage: "arrow.triangle.2.circlepath")
                    }
                } header: {
                    Text("Integrations")
                }
                */
                
                // About section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(Config.appVersion) (\(Config.buildNumber))")
                            .foregroundStyle(.secondary)
                    }
                    
                    Button("Privacy Policy") {
                        showPrivacyPolicy = true
                    }
                    Button("Terms of Service") {
                        showTermsOfService = true
                    }
                } header: {
                    Text("About")
                }
            }
            .padding(.bottom, 60) // Extra padding for floating tab bar
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Sign Out", role: .destructive) {
                    Task {
                        try? await authService.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showTermsOfService) {
                TermsOfServiceView()
            }
        }
    }
    
    private var tierName: String {
        switch authService.currentUser?.subscriptionTier {
        case .free:
            return "Free"
        case .paidOnetime:
            return "Unlock"
        case .premiumSubscription:
            return "Premium"
        case .none:
            return "Unknown"
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthService.shared)
        .environmentObject(PurchaseService.shared)
}

// MARK: - TitanCardView (Embedded)
struct TitanCardView: View {
    @State private var rotation: CGSize = .zero
    
    var body: some View {
        ZStack {
            // 1. Card Base (Matte Black Titanium)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(white: 0.15), location: 0),
                            .init(color: Color(white: 0.05), location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                // Subtle Gold border/glow
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.8, green: 0.7, blue: 0.5).opacity(0.5), // Muted Gold
                                    Color.white.opacity(0.1),
                                    Color(red: 0.8, green: 0.7, blue: 0.5).opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)

            // 2. Content
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .top) {
                    Image(systemName: "crown.fill")
                        .font(.title3)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.9, green: 0.8, blue: 0.6), Color(red: 0.7, green: 0.6, blue: 0.4)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color(red: 0.9, green: 0.8, blue: 0.6).opacity(0.3), radius: 5)
                    
                    Spacer()
                    
                    Text("SPENDLESS")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.bottom, 36)
                
                // Main Title
                Text("TITAN")
                    .font(.system(size: 32, weight: .semibold, design: .default)) // Clean SF Pro
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color(white: 0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                Text("MEMBERSHIP")
                    .font(.system(size: 11, weight: .medium, design: .default))
                    .tracking(6)
                    .foregroundStyle(Color(red: 0.8, green: 0.7, blue: 0.5)) // Gold text
                    .padding(.top, 6)

                Spacer()
                
                // Footer
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("One-Time Purchase")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("Lifetime Access")
                             .font(.system(size: 12, weight: .semibold))
                             .foregroundStyle(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    // Premium Button
                    HStack(spacing: 4) {
                       Text("UPGRADE")
                           .font(.system(size: 11, weight: .bold))
                       Image(systemName: "arrow.up.right")
                           .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.9, green: 0.8, blue: 0.6), Color(red: 0.8, green: 0.7, blue: 0.5)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .shadow(color: Color(red: 0.9, green: 0.8, blue: 0.6).opacity(0.3), radius: 5, x: 0, y: 2)
                }
            }
            .padding(24)
            
            // 3. Subtle Glare
             LinearGradient(
                colors: [.white.opacity(0.1), .clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .mask(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .rotation3DEffect(
            .degrees(rotation.width / 10),
            axis: (x: 0, y: 1, z: 0)
        )
        .rotation3DEffect(
            .degrees(-rotation.height / 10),
            axis: (x: 1, y: 0, z: 0)
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    withAnimation(.easeOut(duration: 0.1)) {
                        rotation = value.translation
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        rotation = .zero
                    }
                }
        )
    }
}


