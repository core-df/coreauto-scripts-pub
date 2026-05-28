// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Cawbs",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "Cawbs", targets: ["Cawbs"]),
    ],
    targets: [
        .target(name: "Cawbs"),
    ]
)
