import SwiftUI

// MARK: - Shimmer Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.4),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (phase * geometry.size.width * 2))
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Shapes
struct SkeletonView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .shimmer()
    }
}

// MARK: - Product Card Skeleton
struct ProductCardSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            // Image placeholder
            SkeletonView()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 8) {
                // Title
                SkeletonView()
                    .frame(height: 16)
                    .frame(maxWidth: .infinity)
                
                // Subtitle
                SkeletonView()
                    .frame(width: 120, height: 12)
                
                // Price
                SkeletonView()
                    .frame(width: 80, height: 20)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Product Detail Skeleton
struct ProductDetailSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            // Image
            SkeletonView()
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // Title
            SkeletonView()
                .frame(height: 24)
            
            // Price
            SkeletonView()
                .frame(width: 100, height: 32)
            
            Spacer()
        }
        .padding()
    }
}

#Preview("Product Card Skeleton") {
    VStack(spacing: 12) {
        ProductCardSkeleton()
        ProductCardSkeleton()
        ProductCardSkeleton()
    }
    .padding()
}

#Preview("Product Detail Skeleton") {
    ProductDetailSkeleton()
}
