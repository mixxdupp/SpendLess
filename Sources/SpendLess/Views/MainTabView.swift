import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @State private var selectedTab = 0
    
    // Hide native tab bar
    init() {
        UITabBar.appearance().isHidden = true
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            // Content
            TabView(selection: $selectedTab) {
                ProductListView()
                    .tag(0)
                
                WishlistListView()
                    .tag(1)
                
                StatsView()
                    .tag(2)
                
                AlertsView()
                    .tag(3)
                
                SettingsView()
                    .tag(4)
            }
            // Safely ignore safe area for tab bar overlap
            .safeAreaInset(edge: .bottom) {
                if !authService.isTabBarHidden {
                    Color.clear.frame(height: 80)
                }
            }
            
            // Custom Tab Bar
            if !authService.isTabBarHidden {
                CustomTabBar(selectedTab: $selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .environment(\.colorScheme, .dark) // FORCE Dark Mode for Tab Bar to prevent "Black Text" in Light Mode
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: authService.isTabBarHidden)
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Wishlist Views (Inlined)

// MARK: - Wishlist Views (Inlined)

struct WishlistListView: View {
    @State private var wishlists: [Wishlist] = []
    @State private var showingCreateSheet = false
    @State private var isLoading = false
    @State private var newListName = ""
    @State private var selectedIcon = "heart.fill"
    
    let icons = ["heart.fill", "star.fill", "gift.fill", "cart.fill", "gamecontroller.fill", "house.fill", "headphones", "book.fill", "bag.fill"]
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive Background
                Group {
                    if colorScheme == .dark {
                        Color(red: 0.05, green: 0.05, blue: 0.05) // Dark Gray/Black
                    } else {
                        Color(red: 0.96, green: 0.96, blue: 0.98) // Light Gray (System Grouped)
                    }
                }
                .ignoresSafeArea()
                
                ScrollView {
                    if isLoading && wishlists.isEmpty {
                        ProgressView()
                    } else if wishlists.isEmpty {
                        ContentUnavailableView(
                            "No Wishlists",
                            systemImage: "heart.slash",
                            description: Text("Create a wishlist to save items for later.")
                        )
                        .padding(.top, 50)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                            ForEach(wishlists) { list in
                                NavigationLink(destination: WishlistDetailView(wishlist: list)) {
                                    WishlistCard(wishlist: list)
                                }
                                .buttonStyle(BouncyButtonStyle())
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task {
                                            do {
                                                try await APIClient.shared.deleteWishlist(id: list.id)
                                                await fetchWishlists() // Refresh
                                                HapticManager.shared.notification(type: .success)
                                            } catch {
                                                print("Error deleting wishlist: \(error)")
                                                HapticManager.shared.notification(type: .error)
                                            }
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Wishlists")
            .toolbar {
                Button {
                    HapticManager.shared.softImpact()
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .task {
                await fetchWishlists()
            }
            .refreshable {
                await fetchWishlists()
            }
            .sheet(isPresented: $showingCreateSheet) {
                createListSheet
            }
        }
    }
    
    private var createListSheet: some View {
        NavigationStack {
            Form {
                Section("List Details") {
                    TextField("List Name (e.g. Dream Setup)", text: $newListName)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(icons, id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color.accentColor : Color(.secondarySystemBackground))
                                    .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                    .clipShape(Circle())
                                    .onTapGesture {
                                        HapticManager.shared.selection()
                                        withAnimation { selectedIcon = icon }
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("New Wishlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingCreateSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        HapticManager.shared.notification(type: .success)
                        Task {
                            await createWishlist()
                        }
                    }
                    .disabled(newListName.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // ... fetch and create methods remain same ...
    private func fetchWishlists() async {
        isLoading = true
        wishlists = (try? await APIClient.shared.fetchWishlists()) ?? []
        isLoading = false
    }
    
    private func createWishlist() async {
        do {
            let newList = try await APIClient.shared.createWishlist(name: newListName, icon: selectedIcon)
            withAnimation {
                wishlists.insert(newList, at: 0)
            }
            showingCreateSheet = false
            newListName = ""
        } catch {
            print("Failed to create wishlist: \(error)")
        }
    }
}

struct WishlistCard: View {
    let wishlist: Wishlist
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: wishlist.icon)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(wishlist.name)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                Text(wishlist.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 6, y: 3)
    }
}

struct WishlistDetailView: View {
    let wishlist: Wishlist
    @State private var products: [Product] = []
    @State private var isLoading = false
    
    @State private var showingAddSheet = false
    @State private var showingEditSheet = false
    @State private var currentName: String
    
    init(wishlist: Wishlist) {
        self.wishlist = wishlist
        _currentName = State(initialValue: wishlist.name)
    }
    
    // Computed property for Total Value
    private var formattedTotalValue: String {
        let preferredCurrency = CurrencyService.shared.preferredCurrency
        let total = products.reduce(Decimal(0)) { partialResult, product in
            guard let price = product.currentPrice else { return partialResult }
            let converted = CurrencyService.shared.convert(price, from: product.currency, to: preferredCurrency)
            return partialResult + converted
        }
        return CurrencyService.shared.formatPrice(total, currency: preferredCurrency)
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Adaptive Background
            Group {
                if colorScheme == .dark {
                    Color(red: 0.05, green: 0.05, blue: 0.05) // Dark Gray/Black
                } else {
                    Color(red: 0.96, green: 0.96, blue: 0.98) // Light Gray (System Grouped)
                }
            }
            .ignoresSafeArea()
            
            ScrollView {
                // Header with Total Value (2026 Style)
                if !products.isEmpty {
                    VStack(spacing: 8) {
                        Text("Total Value")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.top, 20)
                        
                        Text(formattedTotalValue)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
                }

                if isLoading && products.isEmpty {
                    ProgressView().padding(.top, 50)
                } else if products.isEmpty {
                    ContentUnavailableView(
                        "Empty List",
                        systemImage: "bag",
                        description: Text("Add items from the product details page or import existing tracked products.")
                    )
                    .padding(.top, 50)
                    
                    Button("Import Tracked Products") {
                        showingAddSheet = true
                    }
                    .padding()
                } else {
                    // List of items
                    LazyVStack(spacing: 16) {
                        ForEach(products) { product in
                            ProductCardView(product: product)
                                .frame(maxWidth: .infinity) // FORCE full width
                                .contextMenu {
                                    Button(role: .destructive) {
                                        Task {
                                            await deleteItem(product)
                                        }
                                    } label: {
                                        Label("Remove from Wishlist", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding()
                    .padding(.bottom, 100) // Space for floating tab bar
                }
            }
        }
        .navigationTitle(currentName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    
                    Menu {
                        Button {
                            showingEditSheet = true
                        } label: {
                            Label("Edit List", systemImage: "pencil")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTrackedProductSheet(wishlist: wishlist, onAdd: {
                Task { await fetchItems() }
            })
        }
        .sheet(isPresented: $showingEditSheet) {
            EditWishlistSheet(wishlist: wishlist, currentName: $currentName)
        }
        .task {
            await fetchItems()
        }
    }
    
    private func fetchItems() async {
        isLoading = true
        products = (try? await APIClient.shared.fetchWishlistItems(wishlistId: wishlist.id)) ?? []
        isLoading = false
    }
    
    private func deleteItem(_ product: Product) async {
        do {
            try await APIClient.shared.removeFromWishlist(productId: product.id, wishlistId: wishlist.id)
            if let index = products.firstIndex(where: { $0.id == product.id }) {
                withAnimation {
                    products.remove(at: index)
                }
            }
            HapticManager.shared.notification(type: .success)
        } catch {
            print("Error removing item: \(error)")
            HapticManager.shared.notification(type: .error)
        }
    }
}

struct AddTrackedProductSheet: View {
    let wishlist: Wishlist
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var trackedProducts: [Product] = []
    @State private var selectedIds: Set<UUID> = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            List {
                if trackedProducts.isEmpty && !isLoading {
                    Text("No tracked products found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(trackedProducts) { product in
                        HStack {
                            AsyncImage(url: product.imageUrl.flatMap(URL.init)) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Color.gray.opacity(0.1)
                                }
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            VStack(alignment: .leading) {
                                Text(product.title ?? "Product")
                                    .font(.subheadline)
                                    .lineLimit(1)
                                if let price = product.currentPrice {
                                    Text("\(product.currency) \(price)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: selectedIds.contains(product.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedIds.contains(product.id) ? Color.accentColor : .secondary)
                                .font(.title3)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedIds.contains(product.id) {
                                selectedIds.remove(product.id)
                            } else {
                                selectedIds.insert(product.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Existing Products")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(selectedIds.isEmpty ? "" : "(\(selectedIds.count))")") {
                        Task { await addSelected() }
                    }
                    .disabled(selectedIds.isEmpty)
                }
            }
            .task {
                await fetchTracked()
            }
        }
    }
    
    private func fetchTracked() async {
        isLoading = true
        trackedProducts = (try? await APIClient.shared.fetchProducts()) ?? []
        isLoading = false
    }
    
    private func addSelected() async {
        for productId in selectedIds {
            try? await APIClient.shared.addToWishlist(productId: productId, wishlistId: wishlist.id)
        }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        onAdd()
        dismiss()
    }
}

// MARK: - Alerts View (Redesigned)
struct AlertsView: View {
    @StateObject private var manager = NotificationManager.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var appear = false
    
    var body: some View {
        ZStack {
            // Adaptive Background based on colorScheme
            Group {
                if colorScheme == .dark {
                    Color(red: 0.05, green: 0.05, blue: 0.08)
                } else {
                    Color(red: 0.94, green: 0.97, blue: 1.0)
                }
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Adaptive Header
                ZStack(alignment: .bottomLeading) {
                    // Glass Morphism Header
                    Rectangle()
                        .fill(.regularMaterial)
                        .ignoresSafeArea()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Updates")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary) // Adaptive
                        
                        Text("Price drops & restocks")
                            .font(.callout)
                            .foregroundStyle(.secondary) // Adaptive
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .frame(height: 120)
                .zIndex(1)
                
                // Content
                List {
                    if manager.notifications.isEmpty {
                       emptyState
                           .listRowSeparator(.hidden)
                           .listRowBackground(Color.clear)
                    } else {
                        ForEach(Array(manager.notifications.enumerated()), id: \.element.id) { index, notification in
                            AlertCard(notification: notification)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            // Delete logic would go here
                                            HapticManager.shared.notification(type: .warning)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    
                                    Button {
                                        manager.markAsRead(notification)
                                        HapticManager.shared.softImpact()
                                    } label: {
                                        Label("Read", systemImage: "envelope.open")
                                    }
                                    .tint(.blue)
                                }
                                .onTapGesture {
                                    handleTap(on: notification)
                                }
                                // Staggered Entry Animation
                                .offset(y: appear ? 0 : 50)
                                .opacity(appear ? 1 : 0)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.7)
                                    .delay(Double(index) * 0.05),
                                    value: appear
                                )
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.bottom, 100, for: .scrollContent) // Tab bar spacer
            }
        }
        // Removed .environment(\.colorScheme, .dark)
        .onAppear {
            withAnimation { appear = true }
            manager.fetchNotifications()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
                .symbolEffect(.pulse)
            
            Text("All Caught Up")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            
            Text("We'll scour the web for price drops\nand notify you here.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
        .opacity(appear ? 1 : 0)
        .animation(.easeIn.delay(0.2), value: appear)
    }
    
    private func handleTap(on notification: SIBNotification) {
        HapticManager.shared.selection()
        manager.markAsRead(notification)
        // Deep link logic could go here
    }
}

struct AlertCard: View {
    let notification: SIBNotification
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon / Status
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
            .overlay(
                // Unread Indicator glow
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .offset(x: 18, y: -18)
                    .opacity(notification.isRead ? 0 : 1)
                    .shadow(color: .red.opacity(0.5), radius: 4)
            )
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(notification.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary) // Adaptive
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(notification.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.secondary) // Adaptive
                }
                
                Text(notification.body)
                    .font(.caption)
                    .foregroundStyle(.secondary) // Adaptive
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(.regularMaterial) // Adaptive frosted glass
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(
            color: Color.black.opacity(0.05),
            radius: 10,
            x: 0,
            y: 4
        )
    }
}

struct EditWishlistSheet: View {
    let wishlist: Wishlist
    @Binding var currentName: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var icon: String = ""
    
    let icons = ["heart.fill", "star.fill", "gift.fill", "cart.fill", "gamecontroller.fill", "house.fill", "headphones", "book.fill", "bag.fill"]
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Wishlist Name", text: $name)
                
                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(icons, id: \.self) { iconName in
                            Image(systemName: iconName)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(icon == iconName ? Color.accentColor.opacity(0.1) : Color.clear)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(icon == iconName ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
                                .onTapGesture {
                                    icon = iconName
                                    HapticManager.shared.selection()
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Edit Wishlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            _ = try? await APIClient.shared.updateWishlist(id: wishlist.id, name: name, icon: icon)
                            currentName = name
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                name = wishlist.name
                icon = wishlist.icon
            }
        }
        .presentationDetents([.medium])
    }
}


