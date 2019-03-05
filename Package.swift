// swift-tools-version:4.2
import PackageDescription

let package = Package(
  name: "AlpineLang",
  products: [
    .executable(name: "alpine", targets: ["alpine"]),
    .library(name: "AlpineLib", targets: ["AlpineLib"]),
  ],
  dependencies: [
    .package(url: "https://github.com/kyouko-taiga/ArgParse.git", from: "1.1.0"),
  ],
  targets: [
    .target(name: "alpine", dependencies: ["AlpineLib", "ArgParse"]),
    .target(name: "AlpineLib", dependencies: ["AST", "Interpreter", "Parser", "Sema"]),
    .target(name: "AST", dependencies: ["Utils"]),
    .target(name: "Interpreter", dependencies: ["AST", "Parser", "Sema"]),
    .target(name: "Parser", dependencies: ["AST"]),
    .target(name: "Sema", dependencies: ["AST", "Parser", "Utils"]),
    .target(name: "Utils", dependencies: []),
  ]
)
