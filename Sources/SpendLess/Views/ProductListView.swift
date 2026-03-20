import SwiftUI

struct ProductListView: View {
    @EnvironmentObject var authService: AuthService
    @State private var products: [Product] = []
    @State private var isLoading = true
    @State private var hasLoadedOnce = false
    @State private var showAddProduct = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading && !hasLoadedOnce {
                    // Skeleton loading - show on initial load
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(0..<4, id: \.self) { _ in
                                ProductCardSkeleton()
                            }
                        }
                        .padding()
                    }
                } else if products.isEmpty && hasLoadedOnce {
                    // Only show empty state after initial load completes
                    EmptyStateView(
                        icon: "cart.badge.plus",
                        title: "No Tracked Items",
                        subtitle: "Add products to start tracking prices.",
                        actionTitle: "Add Item",
                        action: { showAddProduct = true }
                    )
                } else {
                    productGrid
                }
            }
            .navigationTitle("Summary")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddProduct = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showAddProduct) {
                AddProductView { newProduct in
                    withAnimation(.snappy) {
                        products.insert(newProduct, at: 0)
                    }
                }
            }
            .task {
                try? await APIClient.shared.refreshAllMonitorings()
                await loadProducts()
            }
            .onAppear {
                Task { await loadProducts() }
            }
            .refreshable {
                try? await APIClient.shared.refreshAllMonitorings()
                await loadProducts()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                Task {
                    try? await APIClient.shared.refreshAllMonitorings()
                    await loadProducts()
                }
            }
        }
    }
    
    @Namespace private var namespace
    
    private var totalSavedAmount: Decimal {
        products.reduce(Decimal(0)) { partialResult, product in
            guard let price = product.currentPrice else { return partialResult }
            let converted = CurrencyService.shared.convert(price, from: product.currency, to: CurrencyService.shared.preferredCurrency)
            return partialResult + (product.isBought ? -converted : converted)
        }
    }
    
    private var formattedTotalSaved: String {
        CurrencyService.shared.formatPrice(totalSavedAmount, currency: CurrencyService.shared.preferredCurrency)
    }
    
    private var productGrid: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Apple Wallet/Health Style Summary Card with Animated Background
                ZStack(alignment: .leading) {
                    HeroBackgroundView(style: totalSavedAmount >= 0 ? .profit : .spent)
                        // Removed .environment(\.colorScheme, .dark) to allow Light Mode
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TOTAL SAVED")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary) // Adaptive
                        
                        Text(formattedTotalSaved)
                            .font(.system(size: 38, weight: .bold)) // Standard SF Pro
                            .foregroundStyle(.primary) // Adaptive per user request
                            .contentTransition(.numericText())
                        
                        Text(totalSavedAmount >= 0 ? "Avoided Impulse Purchases" : "Impulse Purchases")
                            .font(.subheadline)
                            .foregroundStyle(.secondary) // Adaptive
                    }
                    .padding(20)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial) // Adaptive frosted glass
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                .padding(.horizontal)
                .onTapGesture {
                    HapticManager.shared.softImpact()
                }
                
                // Tracked Items Section
                let trackedProducts = products.filter { !$0.isBought }
                if !trackedProducts.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Tracked Items")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        LazyVStack(spacing: 16) {
                            ForEach(trackedProducts) { product in
                                productRow(for: product)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Bought Items Section
                let boughtProducts = products.filter { $0.isBought }
                if !boughtProducts.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Bought Items")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(DesignSystem.Colors.destructive)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        
                        LazyVStack(spacing: 16) {
                            ForEach(boughtProducts) { product in
                                productRow(for: product)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.top)
            .padding(.bottom, 100) // Space for floating tab bar
        }
    }
    
    // Extracted row for reuse
    private func productRow(for product: Product) -> some View {
        NavigationLink {
            if #available(iOS 18.0, *) {
                ProductDetailView(product: product) { updatedProduct in
                    if let index = products.firstIndex(where: { $0.id == updatedProduct.id }) {
                        products[index] = updatedProduct
                    }
                }
                .navigationTransition(.zoom(sourceID: product.id, in: namespace))
            } else {
                ProductDetailView(product: product) { updatedProduct in
                    if let index = products.firstIndex(where: { $0.id == updatedProduct.id }) {
                        products[index] = updatedProduct
                    }
                }
            }
        } label: {
            if #available(iOS 18.0, *) {
                ProductCardView(product: product)
                    .matchedTransitionSource(id: product.id, in: namespace)
            } else {
                ProductCardView(product: product)
            }
        }
        .buttonStyle(BouncyButtonStyle())
        .contextMenu {
            Button(role: .destructive) {
                Task {
                    // Optimistic Delete
                    if let index = products.firstIndex(where: { $0.id == product.id }) {
                        products.remove(at: index)
                    }
                    
                    do {
                        try await APIClient.shared.deleteProduct(id: product.id)
                        HapticManager.shared.notification(type: .success)
                    } catch {
                        print("Error deleting product: \(error)")
                        HapticManager.shared.notification(type: .error)
                        // Revert strict reload if needed, but for now just log
                        await loadProducts() // Reload to restore state if failed
                    }
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func loadProducts() async {
        isLoading = true
        defer { 
            isLoading = false
            hasLoadedOnce = true
        }
        
        do {
            products = try await APIClient.shared.fetchProducts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
    
    #Preview {
    ProductListView()
        .environmentObject(AuthService.shared)
    }


