// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BLE_Mac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "BLEControlApp", targets: ["BLEControlApp"])
    ],
    targets: [
        .executableTarget(
            name: "BLEControlApp",
            path: "Sources/BLEControlApp"
        )
    ]
)