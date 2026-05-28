// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CoreautoNotify",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "CoreautoNotify", targets: ["Notify"]),
    ],
    targets: [
        .target(name: "Notify"),
    ]
)
