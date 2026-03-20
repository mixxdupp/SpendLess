// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpendLess",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SpendLess",
            targets: ["SpendLess"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "SpendLess",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ]
        )
    ]
)
