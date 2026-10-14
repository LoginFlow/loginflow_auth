// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "loginflow_auth_google",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "loginflow-auth-google", targets: ["loginflow_auth_google"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS", "7.1.0"..<"10.0.0"),
    ],
    targets: [
        .target(
            name: "loginflow_auth_google",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
            ]
        )
    ]
)
