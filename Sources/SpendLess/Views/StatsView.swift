import SwiftUI
import Charts

struct StatsView: View {
    @State private var totalSaved: Decimal = 0
    @State private var productCount = 0
    @State private var streakDays = 0
    @State private var isLoading = false
    @State private var showConfetti = false
    @State private var previousSaved: Decimal = 0
    @Environment(\.colorScheme) var colorScheme
    
    // Mock Data for Charts (Real app would fetch this)
    @State private var monthlySavings: [MonthlySaving] = [
        .init(month: "Jan", amount: 120),
        .init(month: "Feb", amount: 450),
        .init(month: "Mar", amount: 300),
        .init(month: "Apr", amount: 890)
    ]
    
    @AppStorage("savingsGoal") private var savingsGoal: Double = 1000
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive Background based on colorScheme
                Group {
                    if colorScheme == .dark {
                        Color(red: 0.01, green: 0.12, blue: 0.05)
                    } else {
                        Color(red: 0.93, green: 0.99, blue: 0.96)
                    }
                }
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header (No Card - Just Big Text)
                        headerSection
                        
                        // 1. Time Reclaimed (Philosophical ROI)
                        TimeReclaimedView(totalSaved: NSDecimalNumber(decimal: totalSaved).doubleValue)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                        
                        // 2. Wealth Projection (Localized S&P / Nifty)
                        WealthProjectionView(
                            currentSaved: NSDecimalNumber(decimal: totalSaved).doubleValue,
                            currency: CurrencyService.shared.preferredCurrency
                        )
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                        
                        // 3. Impulse Score (Gamification)
                        ImpulseScoreView(score: calculateImpulseScore())
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    }
                    .padding(24)
                    .padding(.bottom, 100)
                }
            }
            // Removed .environment(\.colorScheme, .dark) to allow Light Mode
            .navigationTitle("Savings Hub")
            // Removed .toolbarColorScheme(.dark)
            .task {
                await loadStats()
            }
            .refreshable {
                await loadStats()
            }
            .confetti(isShowing: $showConfetti)
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Total Saved")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary) // Adaptive
                .textCase(.uppercase)
                .tracking(2)
            
            Text(CurrencyService.shared.formatPrice(totalSaved))
                .font(.system(size: 64, weight: .semibold, design: .rounded)) // Massive, cleaner weight
                .foregroundStyle(totalSaved < 0 ? DesignSystem.Colors.destructive : DesignSystem.Colors.profit) // Red if negative, Green if positive
                .contentTransition(.numericText())
                .shadow(color: (totalSaved < 0 ? DesignSystem.Colors.destructive : DesignSystem.Colors.profit).opacity(0.3), radius: 20, x: 0, y: 10) // Glow effect
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
        .onTapGesture {
            HapticManager.shared.softImpact()
            showConfetti.toggle()
        }
    }
    
    // MARK: - Generic Card Modifier
    // Helper to style cards adaptively
    private func cardStyle() -> some View {
        self
            .background(.regularMaterial) // Material adapts to Light/Dark
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Streak Card (Unused but kept for ref)
    // ... (omitted if unused in body, but let's keep consistent styles for used views)
    
    // MARK: - Share Button
    private var shareButton: some View {
        ShareLink(
            item: "I saved \(CurrencyService.shared.formatPrice(totalSaved)) by NOT buying useless stuff! 🌿 #SpendLess",
            preview: SharePreview("My Savings", image: Image(systemName: "leaf.fill"))
        ) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share Progress")
            }
            .font(.headline)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(colors: [Color.emerald, Color.profitMint], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(Capsule())
            .shadow(color: Color.emerald.opacity(0.4), radius: 10, y: 5)
        }
        .buttonStyle(BouncyButtonStyle())
    }
    
    // MARK: - Achievement Grid (Unused in body)
    
    private func calculateImpulseScore() -> Int {
        let base = 500
        let streakBonus = streakDays * 10
        let itemBonus = productCount * 5
        return min(1000, base + streakBonus + itemBonus)
    }
    
    private func loadStats() async {
        isLoading = true
        defer { isLoading = false }
        
        previousSaved = totalSaved
        
        do {
            let products = try await APIClient.shared.fetchProducts()
            let preferredCurrency = CurrencyService.shared.preferredCurrency
            let newTotal = products.reduce(Decimal(0)) { partialResult, product in
                guard let price = product.currentPrice else { return partialResult }
                let converted = CurrencyService.shared.convert(price, from: product.currency, to: preferredCurrency)
                return partialResult + (product.isBought ? -converted : converted)
            }
            
            withAnimation(.spring(response: 0.6)) {
                totalSaved = newTotal
                productCount = products.count
            }
            
            if let firstProduct = products.last {
                let daysSinceStart = Calendar.current.dateComponents([.day], from: firstProduct.createdAt, to: Date()).day ?? 0
                streakDays = max(0, daysSinceStart)
            }
            
            if newTotal > previousSaved && previousSaved > 0 {
                showConfetti = true
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } catch {
            print("Failed to load stats: \(error)")
        }
    }
}

// MARK: - Extensions for Colors
fileprivate extension Color {
    static let emerald = Color(red: 0.0, green: 0.6, blue: 0.3)
    static let profitMint = Color(red: 0.2, green: 0.9, blue: 0.7)
}

// MARK: - Helper Views in StatsView

struct GoalProgressCard: View {
    let current: Double
    let target: Double
    
    private var progress: Double {
        if target <= 0 { return 0 }
        return min(current / target, 1.0)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("MONTHLY GOAL")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .tracking(1)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.emerald)
            }
            .padding(.horizontal, 4)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 12)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.emerald, Color.profitMint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * progress), height: 12)
                        .shadow(color: Color.emerald.opacity(0.5), radius: 8, y: 0)
                        .animation(.spring, value: progress)
                }
            }
            .frame(height: 12)
            
            HStack {
                Text(CurrencyService.shared.formatPrice(Decimal(current)))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(CurrencyService.shared.formatPrice(Decimal(target)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
    }
}

struct SavingsChartCard: View {
    let data: [MonthlySaving]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("SAVINGS TREND")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .tracking(1)
            
            Chart(data) { item in
                BarMark(
                    x: .value("Month", item.month),
                    y: .value("Amount", item.amount)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.emerald, Color.profitMint],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(4)
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic) { _ in
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.1))
                    AxisValueLabel().foregroundStyle(Color.secondary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel().foregroundStyle(Color.secondary)
                }
            }
        }
        .padding(24)
    }
}

struct AchievementBadge: View {
    let icon: String
    let title: String
    let isUnlocked: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.emerald.opacity(0.2) : Color.primary.opacity(0.05))
                    .frame(width: 60, height: 60)
                    .overlay(Circle().stroke(isUnlocked ? Color.emerald.opacity(0.5) : Color.clear, lineWidth: 1))
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isUnlocked ? Color.emerald : .secondary.opacity(0.3))
                    .shadow(color: isUnlocked ? Color.emerald.opacity(0.6) : .clear, radius: 8)
            }
            
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isUnlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .opacity(isUnlocked ? 1 : 0.5)
        .padding(.vertical, 8)
    }
}

struct MonthlySaving: Identifiable {
    let id = UUID()
    let month: String
    let amount: Double
}

#Preview {
    StatsView()
        .environmentObject(AuthService.shared)
}

// MARK: - Titan Tier Modules

struct TimeReclaimedView: View {
    let totalSaved: Double
    @AppStorage("monthlyIncome") private var monthlyIncome: Double = 50000
    @AppStorage("workDaysPerWeek") private var workDays: Double = 5
    
    private var hourlyRate: Double {
        let workHoursPerMonth = (workDays * 8) * 4.33
        return max(monthlyIncome / workHoursPerMonth, 1.0)
    }
    
    private var hoursReclaimed: Double {
        totalSaved / hourlyRate
    }
    
    private var isDebt: Bool {
        totalSaved < 0
    }
    
    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.1), lineWidth: 8)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .trim(from: 0, to: isDebt ? 1.0 : 0.75) // Full circle for debt looks ominous
                    .stroke(
                        LinearGradient(
                            colors: isDebt ? [DesignSystem.Colors.destructive, Color.orange] : [Color.emerald, Color.profitMint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text("\(Int(hoursReclaimed))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(isDebt ? DesignSystem.Colors.destructive : .primary)
                    Text("HRS")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(isDebt ? "TIME LOST" : "TIME RECLAIMED")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .tracking(1)
                
                Text(isDebt ? "Life spent working." : "You bought back life.")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(isDebt ? "\(abs(Int(hoursReclaimed))) hours of labor required to pay this off." : "\(Int(hoursReclaimed)) hours of labor you don't have to do.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(24)
        .onTapGesture {
            HapticManager.shared.softImpact()
        }
    }
}

struct WealthProjectionView: View {
    let currentSaved: Double
    let currency: SupportedCurrency
    
    private var annualReturnRate: Double {
        switch currency {
        case .INR: return 0.12
        case .USD: return 0.10
        default: return 0.07
        }
    }
    
    private var marketName: String {
        switch currency {
        case .INR: return "Nifty 50"
        case .USD: return "S&P 500"
        default: return "Global Market"
    }
    }
    
    private var projectionData: [ProjectionPoint] {
        var points: [ProjectionPoint] = []
        let years = 10
        for year in 0...years {
            let amount = currentSaved * pow(1.0 + annualReturnRate, Double(year))
            points.append(ProjectionPoint(year: 2026 + year, amount: amount))
        }
        return points
    }
    
    private var projectedValue: Double {
        projectionData.last?.amount ?? currentSaved
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("COMPOUND CLARITY")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    
                    Text("Potential in 2036")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 0) {
                    Text(CurrencyService.shared.formatPrice(Decimal(projectedValue)))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.profitMint)
                    
                    Text("via \(marketName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Chart(projectionData) { point in
                LineMark(
                    x: .value("Year", String(point.year)),
                    y: .value("Value", point.amount)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.emerald, Color.profitMint],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                )
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                
                AreaMark(
                    x: .value("Year", String(point.year)),
                    y: .value("Value", point.amount)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.emerald.opacity(0.3), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(height: 150)
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.1))
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    if let year = value.as(String.self), (Int(year) ?? 0) % 2 == 0 {
                        AxisValueLabel().foregroundStyle(Color.secondary)
                    }
                }
            }
        }
        .padding(24)
    }
}

struct ProjectionPoint: Identifiable {
    let id = UUID()
    let year: Int
    let amount: Double
}

struct ImpulseScoreView: View {
    let score: Int // 0 to 1000
    
    private var tier: String {
        switch score {
        case 900...1000: return "DIAMOND HANDS"
        case 750..<900: return "IRON WILL"
        case 500..<750: return "DISCIPLINED"
        default: return "TRAINING"
        }
    }
    
    private var color: Color {
        switch score {
        case 900...1000: return .profitMint
        case 750..<900: return .emerald
        case 500..<750: return .yellow
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("WILLPOWER SCORE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()
                Text(tier)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(color.opacity(0.2))
                    .clipShape(Capsule())
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.1))
                        .frame(height: 16)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.emerald, Color.profitMint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * (Double(score) / 1000.0)), height: 16)
                        .shadow(color: Color.emerald.opacity(0.5), radius: 8)
                }
            }
            .frame(height: 16)
            
            HStack {
                Text("0")
                Spacer()
                Text("\(score)")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundStyle(.primary)
                Spacer()
                Text("1000")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}
