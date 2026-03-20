import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var animation
    
    let tabs: [(image: String, title: String)] = [
        ("list.bullet", "Tracked"),
        ("heart", "Wishlist"),
        ("chart.bar.fill", "Saved"),
        ("bell.fill", "Alerts"),
        ("gear", "Settings")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button {
                    withAnimation(.snappy(duration: 0.3)) {
                        selectedTab = index
                    }
                    let generator = UISelectionFeedbackGenerator()
                    generator.selectionChanged()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tabs[index].image)
                            .font(.system(size: 20))
                            .symbolVariant(selectedTab == index ? .fill : .none)
                            .scaleEffect(selectedTab == index ? 1.05 : 1.0)
                        
                        Text(tabs[index].title)
                            .font(.caption2)
                            .fontWeight(selectedTab == index ? .semibold : .regular)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selectedTab == index ? Color.white : Color(white: 0.5)) // Always white/gray
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .padding(.bottom, 4)
        .background {
            Capsule()
                .fill(Color(white: 0.1)) // Dark background always
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 0) // Lifted slightly by padding in main views
    }
}

#Preview {
    CustomTabBar(selectedTab: .constant(0))
}
