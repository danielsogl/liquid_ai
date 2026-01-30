// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "liquid_ai",
    platforms: [
        .iOS("15.0"),
        .macOS("12.0")
    ],
    products: [
        .library(name: "liquid-ai", targets: ["liquid_ai"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "liquid_ai",
            dependencies: [
                "LeapSDK",
                "LeapModelDownloader",
                "LeapSDKSupport"
            ]
        ),
        // LEAP SDK binary targets
        .binaryTarget(
            name: "LeapSDK",
            url: "https://github.com/Liquid4All/leap-ios/releases/download/v0.9.2/LeapSDK.xcframework.zip",
            checksum: "3bf5a8eb8829affed674cdf425ae896be38a50059e004e4a8ea45527df7c8b3a"
        ),
        .binaryTarget(
            name: "LeapModelDownloader",
            url: "https://github.com/Liquid4All/leap-ios/releases/download/v0.9.2/LeapModelDownloader.xcframework.zip",
            checksum: "a07f848db246535cd09441f73c00dbc36770c60574657c78b189345a2ece70d2"
        ),
        .binaryTarget(
            name: "InferenceEngine",
            url: "https://github.com/Liquid4All/leap-ios/releases/download/v0.9.2/inference_engine.xcframework.zip",
            checksum: "75da375f5ca934038b348005d4b064256197b47659bb6e3225ad6e5a114457a1"
        ),
        .binaryTarget(
            name: "InferenceEngineExecutorchBackend",
            url: "https://github.com/Liquid4All/leap-ios/releases/download/v0.9.2/inference_engine_executorch_backend.xcframework.zip",
            checksum: "895a1d3cb82fa95bd6c91c63d3b8dde346de2a708b3ec75ce36bbb957553233a"
        ),
        .binaryTarget(
            name: "InferenceEngineLlamaCppBackend",
            url: "https://github.com/Liquid4All/leap-ios/releases/download/v0.9.2/inference_engine_llamacpp_backend.xcframework.zip",
            checksum: "ffdc5e6e14c9571125260f08839cc719184b4ad8a535010a795750982118145e"
        ),
        .target(
            name: "LeapSDKSupport",
            dependencies: [
                "InferenceEngine",
                "InferenceEngineExecutorchBackend",
                "InferenceEngineLlamaCppBackend"
            ],
            path: "Sources/LeapSDKSupport"
        )
    ]
)
