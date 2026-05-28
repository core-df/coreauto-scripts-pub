// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CoreautoTransform",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "CoreautoTransform", targets: ["Transform"]),
    ],
    targets: [
        .target(name: "Transform"),
    ]
)
