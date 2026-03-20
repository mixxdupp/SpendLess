import SwiftUI
import Charts

struct ProductDetailView: View {
    @State var product: Product
    var onUpdate: ((Product) -> Void)?
    @Environment(\.dismiss) private var dismiss
    
    @State private var priceHistory: [PriceHistory] = []
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var showDeleteConfirmation = false
    @State private var showAddToWishlist = false
    @State private var showDemotivation = false
    
    @ObservedObject private var currencyService = CurrencyService.shared // Fix: Observe currency changes
    
    // UI Constants
    private let headerHeight: CGFloat = 300
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    // Immersive Parallax Header
                    parallaxHeader
                    
                    // Content Body
                    VStack(alignment: .leading, spacing: 24) {
                        // Title & Price Section
                        titleSection
                        
                        // Impulse Blocker Status (Glassmorphism)
                        if product.isInCooldown {
                            cooldownBanner
                        }
                        
                        // Affordability Check (Glassmorphism)
                        if AffordabilityCalculator.shared.isEnabled {
                            demotivationBanner
                        }
                        
                        // Action Buttons in Scroll
                        VStack(spacing: 12) {
                            if product.isBought {
                                boughtStatusBanner
                            } else {
                                HStack(spacing: 12) {
                                    consultAIButton
                                    boughtButton
                                    resistButton
                                }
                            }
                            viewOnStoreButton
                        }
                        .padding(.vertical, 8)
                        
                        // Price History Chart
                        if !priceHistory.isEmpty {
                            priceChartSection
                        }
                        
                        // Bottom spacer for floating bar
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .background(
                        Rectangle()
                            .fill(Color(.systemBackground))
                            .roundedCorner(40, corners: [.topLeft, .topRight])
                            .shadow(color: .black.opacity(0.1), radius: 20, y: -10)
                    )
                    .offset(y: -50) // Overlap the header
                }
            }
            .edgesIgnoringSafeArea(.top)
            
            // Floating Action Bar (Sticky Footer) - REMOVED
            // actionButtons 
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar) // Fix overlap by hiding tab bar
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    HapticManager.shared.softImpact()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticManager.shared.selection()
                    showAddToWishlist = true
                } label: {
                    Image(systemName: "heart.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
            }
        }
        .sheet(isPresented: $showAddToWishlist) {
            AddToWishlistSheet(product: product)
        }
        .fullScreenCover(isPresented: $showDemotivation) {
            let price = product.currentPrice ?? Decimal(0)
            let priceDouble = NSDecimalNumber(decimal: price).doubleValue
            let calculator = AffordabilityCalculator.shared
            let dailyIncome = calculator.dailyIncome(in: product.currency)
            let daysToEarn = dailyIncome > 0 ? priceDouble / dailyIncome : nil
            let percentOfIncome = calculator.monthlyIncome > 0 ? (priceDouble / calculator.monthlyIncome) * 100 : nil
            
            DemotivationOverlay(
                productTitle: product.title ?? "Unknown Product",
                productPrice: priceDouble,
                productImageUrl: product.imageUrl,
                daysToEarn: daysToEarn,
                percentOfIncome: percentOfIncome,
                currency: product.currency,
                onBuyConfirmed: {
                    // Logic to mark as bought
                    Task {
                        try? await APIClient.shared.markAsBought(id: product.id)
                        isRefreshing = true
                        product.isBought = true
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        dismiss()
                    }
                }
            )
        }
        .confirmationDialog("Delete Product", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await deleteProduct()
                }
            }
        }
        .task {
            await loadPriceHistory()
        }
        .onAppear {
            withAnimation {
                AuthService.shared.isTabBarHidden = true
            }
        }
        .onDisappear {
            withAnimation {
                AuthService.shared.isTabBarHidden = false
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    // MARK: - Components
    
    private var parallaxHeader: some View {
        GeometryReader { proxy in
            let minY = proxy.frame(in: .global).minY
            let height = headerHeight + (minY > 0 ? minY : 0)
            
            ZStack {
                // Background Glow (Mesh)
                HeroBackgroundView()
                    .blur(radius: 40)
                    .opacity(0.6)
                
                // Blurred Background Reflection
                AsyncImage(url: product.imageUrl.flatMap(URL.init)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: proxy.size.width, height: height)
                            .blur(radius: 80)
                            .overlay(Color.black.opacity(0.3)) // Dim it slightly
                    }
                }
                
                // Foreground: Crisp image (Floating)
                AsyncImage(url: product.imageUrl.flatMap(URL.init)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 280, maxHeight: 240)
                            // Remove white box if possible or just make it float nicely
                            .shadow(color: .black.opacity(0.2), radius: 30, y: 15)
                            .scaleEffect(minY < 0 ? 1.0 - (abs(minY) / 1000) : 1.0 + (minY / 1000))
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    case .failure:
                        Image(systemName: "photo")
                            .font(.system(size: 80))
                            .foregroundStyle(.white.opacity(0.5))
                    @unknown default:
                        EmptyView()
                    }
                }
                .offset(y: minY > 0 ? -minY * 0.3 : 0) // Parallax effect
            }
            .offset(y: minY > 0 ? -minY : 0)
        }
        .frame(height: headerHeight)
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Source Pill
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.caption2)
                Text(storeName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.blue.opacity(0.1))
            .foregroundStyle(Color.blue)
            .clipShape(Capsule())
            
            Text(product.title ?? "Product")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .lineLimit(3)
            
            if let price = product.currentPrice {
                PriceDisplayView(
                    price: price,
                    currency: product.currency,
                    font: .largeTitle,
                    weight: .heavy,
                    color: Color.accentColor
                )
            }
        }
    }
    
    private var cooldownBanner: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 48, height: 48)
                Image(systemName: "hourglass")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Impulse Shield Active")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(product.daysUntilCooldownEnds) days remaining")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    

    
    private var demotivationBanner: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.red)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Think Twice")
                    .font(.headline)
                    .foregroundStyle(Color.red)
                if let price = product.currentPrice {
                    Text(AffordabilityCalculator.shared.getDemotivationMessage(price: price, currency: product.currency))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(DesignSystem.Colors.destructive.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var boughtButton: some View {
        Button {
            HapticManager.shared.notification(type: .error)
            Task {
                // 1. Optimistic UI Update (Instant)
                await MainActor.run {
                    product.isBought = true
                    onUpdate?(product) // Update parent list immediately
                    HapticManager.shared.notification(type: .success)
                }
                
                // 2. Slight delay for animation/haptic feel before dismissing
                try? await Task.sleep(nanoseconds: 300_000_000)
                await MainActor.run { dismiss() }
                
                // 3. Sync with Backend (Background)
                do {
                    try await APIClient.shared.markAsBought(id: product.id)
                } catch {
                    print("Backend sync failed: \(error)")
                    // In a real app, we might want to revert the UI state here or show a toast
                }
            }
        } label: {
            HStack {
                Text("I Bought This")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(DesignSystem.Colors.destructive)
            .clipShape(Capsule())
            .shadow(color: DesignSystem.Colors.destructive.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(BouncyButtonStyle())
    }
    
    private var resistButton: some View {
        Button {
            HapticManager.shared.notification(type: .success)
            dismiss()
        } label: {
            Text("Resist")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(DesignSystem.Colors.profit)
                .clipShape(Capsule())
                .shadow(color: DesignSystem.Colors.profit.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(BouncyButtonStyle())
    }
    

    
    private var consultAIButton: some View {
        Button {
            HapticManager.shared.impact(style: .medium)
            showDemotivation = true
        } label: {
            Image(systemName: "brain.head.profile")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.destructive)
                .frame(width: 50, height: 50) // Matches other buttons height
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())
        }
        .buttonStyle(BouncyButtonStyle())
    }
    
    private var boughtStatusBanner: some View {
        HStack {
            Image(systemName: "cart.fill.badge.minus")
            Text("Bought on \(product.lastCheckedAt?.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()) ?? Date().formatted(.dateTime.day(.twoDigits).month(.twoDigits).year()))")
        }
        .font(.headline)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(DesignSystem.Colors.destructive)
        .cornerRadius(16)
        .onTapGesture {
            HapticManager.shared.notification(type: .error)
        }
    }
    
    private var viewOnStoreButton: some View {
        Button {
            if let url = URL(string: product.url) {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack {
                Text("View on Store")
                    .font(.headline)
                Image(systemName: "arrow.up.right")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.blue)
            .clipShape(Capsule())
            .shadow(color: Color.blue.opacity(0.4), radius: 10, y: 5)
        }
        .buttonStyle(BouncyButtonStyle())
        // .padding(.horizontal, 24) // Already padded by parent VStack
    }
    
    @State private var selectedDate: Date?
    @State private var selectedPrice: Decimal?
    
    private var priceChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Price History")
                    .font(.headline)
                
                Spacer()
                
                if let price = selectedPrice {
                    Text(formattedPrice(price))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            
            Chart(priceHistory) { item in
                LineMark(
                    x: .value("Date", item.recordedAt),
                    y: .value("Price", NSDecimalNumber(decimal: item.price).doubleValue)
                )
                .foregroundStyle(Color.accentColor)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                .symbol {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
                
                AreaMark(
                    x: .value("Date", item.recordedAt),
                    y: .value("Price", NSDecimalNumber(decimal: item.price).doubleValue)
                )
                .foregroundStyle(LinearGradient(colors: [Color.accentColor.opacity(0.2), .clear], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.catmullRom)
                
                if let selectedDate {
                    RuleMark(x: .value("Date", selectedDate))
                        .foregroundStyle(Color.gray.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                }
            }
            .frame(height: 220)
            .chartYAxis { AxisMarks(position: .leading) }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) {
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    let origin = geometry[plotFrame].origin
                                    let location = CGPoint(
                                        x: value.location.x - origin.x,
                                        y: value.location.y - origin.y
                                    )
                                    if let date: Date = proxy.value(atX: location.x) {
                                        if let closest = priceHistory.min(by: { abs($0.recordedAt.timeIntervalSince(date)) < abs($1.recordedAt.timeIntervalSince(date)) }) {
                                            selectedDate = closest.recordedAt
                                            selectedPrice = closest.price
                                            let generator = UISelectionFeedbackGenerator()
                                            generator.selectionChanged()
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    selectedDate = nil
                                    selectedPrice = nil
                                }
                        )
                }
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    
    // ActionButtons removed as they are moved to main scroll view
            


    
    // MARK: - Helpers
    private var priceFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }
    
    private func formattedPrice(_ price: Decimal) -> String {
        // Fix: Convert price to preferred currency before displaying in Chart/Header
        let targetCurrency = CurrencyService.shared.preferredCurrency
        let converted = CurrencyService.shared.convert(price, from: product.currency, to: targetCurrency)
        return CurrencyService.shared.formatPrice(converted, currency: targetCurrency)
    }
    
    private var storeName: String {
        guard let url = URL(string: product.url),
              let host = url.host else {
            return product.store ?? "Unknown Store"
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }
    
    private func loadPriceHistory() async {
        isLoading = true
        defer { isLoading = false }
        do {
            priceHistory = try await APIClient.shared.fetchPriceHistory(productId: product.id)
        } catch {
            print("Failed to load price history: \(error)")
        }
    }
    
    private func refreshPrice() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            try await APIClient.shared.manualRefresh(productId: product.id)
            try await Task.sleep(nanoseconds: 2_000_000_000)
            product = try await APIClient.shared.fetchProduct(id: product.id)
            await loadPriceHistory()
        } catch {
            print("Failed to refresh price: \(error)")
        }
    }
    
    private func deleteProduct() async {
        do {
            try await APIClient.shared.deleteProduct(id: product.id)
            HapticManager.shared.notification(type: .success)
            await MainActor.run { dismiss() }
        } catch {
            print("Failed to delete product: \(error)")
            HapticManager.shared.notification(type: .error)
        }
    }
}

#Preview {
    NavigationStack {
        ProductDetailView(product: .preview)
    }
}

struct AddToWishlistSheet: View {
    let product: Product
    @Environment(\.dismiss) private var dismiss
    @State private var wishlists: [Wishlist] = []
    @State private var isLoading = false
    @State private var newListName = ""
    @State private var isCreating = false
    
    var body: some View {
        NavigationStack {
            List {
                if isCreating {
                    Section {
                        TextField("New List Name", text: $newListName)
                        Button("Create & Add") {
                            Task { await createAndAdd() }
                        }
                        .disabled(newListName.isEmpty)
                    }
                } else {
                    Button(action: { withAnimation { isCreating = true } }) {
                        Label("Create New Wishlist", systemImage: "plus")
                    }
                }
                
                Section("Your Wishlists") {
                    if wishlists.isEmpty && !isLoading {
                        Text("No wishlists yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(wishlists) { list in
                            Button {
                                Task { await add(to: list) }
                            } label: {
                                HStack {
                                    Image(systemName: list.icon)
                                        .foregroundStyle(Color.accentColor)
                                    Text(list.name)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Wishlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
            .task {
                await fetchWishlists()
            }
        }
    }
    
    private func fetchWishlists() async {
        isLoading = true
        wishlists = (try? await APIClient.shared.fetchWishlists()) ?? []
        isLoading = false
    }
    
    private func add(to wishlist: Wishlist) async {
        do {
            try await APIClient.shared.addToWishlist(productId: product.id, wishlistId: wishlist.id)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            dismiss()
        } catch {
            print("Failed to add to wishlist: \(error)")
        }
    }
    
    private func createAndAdd() async {
        do {
            let newList = try await APIClient.shared.createWishlist(name: newListName, icon: "heart.fill")
            try await APIClient.shared.addToWishlist(productId: product.id, wishlistId: newList.id)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            dismiss()
        } catch {
            print("Failed to create/add: \(error)")
        }
    }
}

// MARK: - Helpers
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension View {
    func roundedCorner(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
