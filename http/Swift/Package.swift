// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CoreautoHttp",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "CoreautoHttp", targets: ["Http"]),
    ],
    targets: [
        .target(name: "Http"),
    ]
)
