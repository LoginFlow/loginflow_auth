// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "loginflow_auth",
    platforms: [
        .iOS("15.0"),
        .macOS("12.0"),
    ],
    products: [
        .library(name: "loginflow-auth", targets: ["loginflow_auth"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "loginflow_auth",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
