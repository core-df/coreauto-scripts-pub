// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CoreautoFiles",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "CoreautoFiles", targets: ["Files"]),
    ],
    targets: [
        .target(name: "Files"),
    ]
)
