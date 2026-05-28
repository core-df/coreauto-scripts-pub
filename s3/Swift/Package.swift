// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CoreautoS3",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "CoreautoS3", targets: ["S3"]),
    ],
    dependencies: [
        .package(url: "https://github.com/soto-project/soto.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "S3",
            dependencies: [
                .product(name: "SotoS3", package: "soto"),
                .product(name: "SotoCore", package: "soto"),
            ]
        ),
    ]
)
