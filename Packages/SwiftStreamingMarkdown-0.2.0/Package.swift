// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Vendored: the parent project (StudyPulse) vendors all transitive dependencies
// in `StudyPulse/Packages/Vendored/` to avoid network round-trips. The package
// declares each dependency as a local path so the build can run completely
// offline. The vendored packages live one level up from this Package.swift.
let vendoredRoot = "../Vendored"

let package = Package(
  name: "SwiftStreamingMarkdown",
  defaultLocalization: "en",
  platforms: [.macOS(.v13), .iOS(.v16)],
  products: [
    .library(
      name: "SwiftStreamingMarkdown",
      targets: ["SwiftStreamingMarkdown"])
  ],
  dependencies: [
    // Equatable dropped: the upstream `@Equatable` macro is only used to add
    // an `Equatable` conformance to three view structs (MarkdownView,
    // StreamedMarkdownView, DocumentView) for SwiftUI render-skipping. We
    // patched those three structs to drop the macro, so the package no
    // longer needs the third-party `Equatable` package.
    .package(path: "\(vendoredRoot)/swift-markdown"),
    .package(path: "\(vendoredRoot)/highlightswift"),
    .package(path: "\(vendoredRoot)/iosMath")
  ],
  targets: [
    .target(
      name: "SwiftStreamingMarkdown",
      dependencies: [
        .product(name: "Markdown", package: "swift-markdown"),
        .product(name: "HighlightSwift", package: "highlightswift"),
        .product(name: "iosMath", package: "iosMath")
      ],
      path: "Sources/MarkdownText",
      resources: [
        .process("Resources")
      ]
    ),
    .testTarget(
      name: "SwiftStreamingMarkdownTests",
      dependencies: [
        "SwiftStreamingMarkdown"
      ],
      path: "Tests/MarkdownTextTests")
  ]
)
