// swift-tools-version:4.1
import PackageDescription

let package = Package(
  name: "AlpineLang",
  products: [
    .executable(name: "alpine", targets: ["alpine"]),
  ],
  dependencies: [],
  targets: [
    .target(name: "alpine", dependencies: ["AST", "Parser", "Sema"]),
    .target(name: "AST", dependencies: ["Utils"]),
    .target(name: "Parser", dependencies: ["AST"]),
    .target(name: "Sema", dependencies: ["AST", "Parser", "Utils"]),
    .target(name: "Utils", dependencies: []),
  ]
)
