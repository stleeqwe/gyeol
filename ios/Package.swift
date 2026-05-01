// swift-tools-version: 5.9
// 결 (Gyeol) — Swift Package
// Xcode iOS 앱 타겟에서 import. 단독 SPM 빌드 시 iOS 17+ Simulator 필요.

import PackageDescription

let package = Package(
    name: "Gyeol",
    defaultLocalization: "ko",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GyeolDomain", targets: ["GyeolDomain"]),
        .library(name: "GyeolCore", targets: ["GyeolCore"]),
        .library(name: "GyeolUI", targets: ["GyeolUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.20.0")
    ],
    targets: [
        .target(
            name: "GyeolDomain",
            path: "Gyeol",
            exclude: [
                "App",
                "Components",
                "Resources",
                "Services",
                "ViewModels",
                "Views"
            ],
            sources: [
                "Models"
            ]
        ),
        .target(
            name: "GyeolCore",
            dependencies: [
                "GyeolDomain",
                .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "Gyeol",
            exclude: [
                "App",
                "Components",
                "Models",
                "Resources",
                "Views"
            ],
            sources: [
                "Services",
                "ViewModels"
            ]
        ),
        .target(
            name: "GyeolUI",
            dependencies: ["GyeolCore", "GyeolDomain"],
            path: "Gyeol",
            exclude: [
                "App",
                "Models",
                "Resources",
                "Services",
                "ViewModels"
            ],
            sources: [
                "Components",
                "Views"
            ]
        ),
        .testTarget(
            name: "GyeolTests",
            dependencies: ["GyeolDomain"],
            path: "GyeolTests"
        )
    ]
)
