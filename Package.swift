// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "QRSnap",
    platforms: [.macOS("15.2")],
    targets: [.executableTarget(name: "QRSnap", path: "Sources/QRSnap")]
)
