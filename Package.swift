// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import PackageDescription

let package = Package(
  name: "GoogleUtilities",
  platforms: [.iOS(.v12), .macOS(.v10_15), .tvOS(.v13), .watchOS(.v7)],
  products: [
    .library(
      name: "GULAppDelegateSwizzler",
      targets: ["GoogleUtilities-AppDelegateSwizzler"]
    ),
    .library(
      name: "GULEnvironment",
      targets: ["GoogleUtilities-Environment"]
    ),
    .library(
      name: "GULLogger",
      targets: ["GoogleUtilities-Logger"]
    ),
    .library(
      name: "GULMethodSwizzler",
      targets: ["GoogleUtilities-MethodSwizzler"]
    ),
    .library(
      name: "GULNetwork",
      targets: ["GoogleUtilities-Network"]
    ),
    .library(
      name: "GULNSData",
      targets: ["GoogleUtilities-NSData"]
    ),
    .library(
      name: "GULReachability",
      targets: ["GoogleUtilities-Reachability"]
    ),
    .library(
      name: "GULSwizzlerTestHelpers",
      targets: ["GoogleUtilities-SwizzlerTestHelpers"]
    ),
    .library(
      name: "GULUserDefaults",
      targets: ["GoogleUtilities-UserDefaults"]
    ),
  ],
  dependencies: [
    // TODO: restore OCMock when https://github.com/erikdoe/ocmock/pull/537
    // gets merged to fix Xcode 15.3 builds.
    .package(
      url: "https://github.com/paulb777/ocmock.git",
      revision: "173955e93e6ee6999a10729ab67e4b4efdd1db6d"
    ),
  ],
  targets: [
    .target(
      name: "GoogleUtilities-AppDelegateSwizzler",
      dependencies: ["GoogleUtilities-Environment",
                     "GoogleUtilities-Logger",
                     "GoogleUtilities-Network"],
      path: "GoogleUtilities/AppDelegateSwizzler",
      exclude: ["README.md"],
      resources: [.process("Resources/PrivacyInfo.xcprivacy")],
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .target(
      name: "GoogleUtilities-Environment",
      dependencies: [
        "third-party-IsAppEncrypted",
      ],
      path: "GoogleUtilities/Environment",
      resources: [.process("Resources/PrivacyInfo.xcprivacy")],
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),

    .target(
      name: "third-party-IsAppEncrypted",
      path: "third_party/IsAppEncrypted",
      exclude: ["LICENSE"],
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),

    .target(
      name: "GoogleUtilities-Logger",
      dependencies: ["GoogleUtilities-Environment"],
      path: "GoogleUtilities/Logger",
      resources: [.process("Resources/PrivacyInfo.xcprivacy")],
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),

    .target(
      name: "GoogleUtilities-MethodSwizzler",
      dependencies: ["GoogleUtilities-Logger"],
      path: "GoogleUtilities/MethodSwizzler",
      resources: [.process("Resources/PrivacyInfo.xcprivacy")],
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .target(
      name: "GoogleUtilities-Network",
      dependencies: ["GoogleUtilities-Logger",
                     "GoogleUtilities-NSData",
                     "GoogleUtilities-Reachability"],
      path: "GoogleUtilities/Network",
      resources: [.process("Resources/PrivacyInfo.xcprivacy")],
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../.."),
      ]
    ),
    .target(
      name: "GoogleUtilities-NSData",
      dependencies: [],
      path: "GoogleUtilities/NSData+zlib",
      resources: [.process("Resources/PrivacyInfo.xcprivacy")],
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../.."),
      ],
      linkerSettings: [
        .linkedLibrary("z"),
      ]
    ),
    .target(
      name: "GoogleUtilities-Reachability",
      dependencies: ["GoogleUtilities-Logger"],
      path: "GoogleUtilities/Reachability",
      resources: [.process("Resources/PrivacyInfo.xcprivacy")],
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .target(
      name: "GoogleUtilities-UserDefaults",
      dependencies: ["GoogleUtilities-Logger"],
      path: "GoogleUtilities/UserDefaults",
      resources: [.process("Resources/PrivacyInfo.xcprivacy")],
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .target(
      name: "GoogleUtilities-SwizzlerTestHelpers",
      dependencies: ["GoogleUtilities-MethodSwizzler"],
      path: "GoogleUtilities/SwizzlerTestHelpers",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .testTarget(
      name: "swift-test",
      dependencies: [
        "GoogleUtilities-AppDelegateSwizzler",
        "GoogleUtilities-Environment",
        "GoogleUtilities-Logger",
        "GoogleUtilities-MethodSwizzler",
        "GoogleUtilities-Network",
        "GoogleUtilities-NSData",
        "GoogleUtilities-Reachability",
        "GoogleUtilities-UserDefaults",
      ],
      path: "SwiftPMTests/swift-test"
    ),
    .testTarget(
      name: "objc-import-test",
      dependencies: [
        "GoogleUtilities-AppDelegateSwizzler",
        "GoogleUtilities-Environment",
        "GoogleUtilities-Logger",
        "GoogleUtilities-MethodSwizzler",
        "GoogleUtilities-Network",
        "GoogleUtilities-NSData",
        "GoogleUtilities-Reachability",
        "GoogleUtilities-UserDefaults",
      ],
      path: "SwiftPMTests/objc-import-test"
    ),
    // TODO: - need to port Network/third_party/GTMHTTPServer.m to ARC.
    .testTarget(
      name: "UtilitiesUnit",
      dependencies: [
        .product(name: "OCMock", package: "OCMock"),
        "GoogleUtilities-AppDelegateSwizzler",
        "GoogleUtilities-Environment",
        "GoogleUtilities-Logger",
        "GoogleUtilities-MethodSwizzler",
        "GoogleUtilities-Network",
        "GoogleUtilities-NSData",
        "GoogleUtilities-Reachability",
        "GoogleUtilities-UserDefaults",
        "GoogleUtilities-SwizzlerTestHelpers",
      ],
      path: "GoogleUtilities/Tests/Unit",
      exclude: [
        "Network/third_party/LICENSE",
        "Network/GULNetworkTest.m", // Requires GTMHTTPServer.m
        "Network/third_party/GTMHTTPServer.m", // Requires disabling ARC
      ],
      cSettings: [
        .headerSearchPath("../../.."),
      ]
    ),
  ],
  cLanguageStandard: .c99,
  cxxLanguageStandard: CXXLanguageStandard.gnucxx14
)
