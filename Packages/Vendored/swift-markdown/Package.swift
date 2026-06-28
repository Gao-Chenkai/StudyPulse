// swift-tools-version:6.2
/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

// Patched vendored copy: the `swift-cmark` package is provided locally
// under `../swift-cmark` and the optional `swift-docc-plugin` is removed
// (it is only used for generating documentation, not for building the
// library). The build can run fully offline as a result.
import PackageDescription

let package = Package(
    name: "swift-markdown",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(
            name: "Markdown",
            targets: ["Markdown"]),
    ],
    dependencies: [
        .package(path: "../swift-cmark"),
    ],
    targets: [
        .target(
            name: "Markdown",
            dependencies: [
                "CAtomic",
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
            ],
            exclude: [
                "CMakeLists.txt"
            ],
            swiftSettings: [.unsafeFlags(["-Xcc", "-DCMARK_GFM_STATIC_DEFINE"], .when(platforms: [.windows]))]
        ),
        .testTarget(
            name: "MarkdownTests",
            dependencies: ["Markdown"],
            resources: [.process("Visitors/Everything.md")]),
        .target(name: "CAtomic"),
    ],
    swiftLanguageModes: [.v5]
)

