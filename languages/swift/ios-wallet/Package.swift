// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EthereumWalletSDK",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "EthereumWalletSDK",
            targets: ["EthereumWalletSDK"]),
    ],
    dependencies: [
        .package(url: "https://github.com/web3swift-team/web3swift.git", from: "3.1.0"),
        .package(url: "https://github.com/attaswift/BigInt.git", from: "5.3.0")
    ],
    targets: [
        .target(
            name: "EthereumWalletSDK",
            dependencies: [
                "web3swift",
                "BigInt"
            ]),
        .testTarget(
            name: "EthereumWalletSDKTests",
            dependencies: ["EthereumWalletSDK"]),
    ]
)
