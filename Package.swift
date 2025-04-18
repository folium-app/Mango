// swift-tools-version: 5.10.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Mango",
    platforms: [
        .iOS(.v15),
        .tvOS(.v15)
    ],
    products: [
        .library(name: "Mango", targets: [
            "Mango"
        ]),
        .library(name: "MangoC", targets: [
            "MangoC"
        ]),
        .library(name: "MangoObjC", targets: [
            "MangoObjC"
        ])
    ],
    targets: [
        .target(name: "Mango", dependencies: [
            "MangoObjC"
        ]),
        .target(name: "MangoC", publicHeadersPath: "include"),
        .target(name: "MangoObjC", dependencies: [
            "MangoC"
        ], publicHeadersPath: "include")
    ],
    cLanguageStandard: .c2x,
    cxxLanguageStandard: .cxx2b
)
