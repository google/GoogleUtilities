// swift-tools-version:5.3
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
  platforms: [.iOS(.v9), .macOS(.v10_12), .tvOS(.v10), .watchOS(.v6)],
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
      name: "GULISASwizzler",
      targets: ["GoogleUtilities-ISASwizzler"]
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
    .package(name: "Promises", url: "https://github.com/google/promises.git", "1.2.8" ..< "3.0.0"),
    .package(
      name: "OCMock",
      url: "https://github.com/erikdoe/ocmock.git",
      .revision("c5eeaa6dde7c308a5ce48ae4d4530462dd3a1110")
    ),
  ],
  // TODO: Restructure directory structure to simplify the excludes here.
  targets: [
    .target(
      name: "GoogleUtilities-AppDelegateSwizzler",
      dependencies: ["GoogleUtilities-Environment",
                     "GoogleUtilities-Logger",
                     "GoogleUtilities-Network"],
      path: "GoogleUtilities",
      exclude: [
        "AppDelegateSwizzler/README.md",
        "Environment/",
        "Network/",
        "ISASwizzler/",
        "Logger/",
        "MethodSwizzler/",
        "NSData+zlib/",
        "Reachability",
        "SwizzlerTestHelpers/",
        "Tests",
        "UserDefaults/",
      ],
      sources: [
        "AppDelegateSwizzler/",
        "Common/",
      ],
      publicHeadersPath: "AppDelegateSwizzler/Public",
      cSettings: [
        .headerSearchPath("../"),
      ]
    ),
    .target(
      name: "GoogleUtilities-Environment",
      dependencies: [.product(name: "FBLPromises", package: "Promises")],
      path: "GoogleUtilities/Environment",
      exclude: ["third_party/LICENSE"],
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),

    .target(
      name: "GoogleUtilities-Logger",
      dependencies: ["GoogleUtilities-Environment"],
      path: "GoogleUtilities/Logger",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),

    .target(
      name: "GoogleUtilities-ISASwizzler",
      dependencies: ["GoogleUtilities-Logger"],
      path: "GoogleUtilities/ISASwizzler",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),

    .target(
      name: "GoogleUtilities-MethodSwizzler",
      dependencies: ["GoogleUtilities-Logger"],
      path: "GoogleUtilities/MethodSwizzler",
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
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../.."),
      ]
    ),
    .target(
      name: "GoogleUtilities-NSData",
      path: "GoogleUtilities/NSData+zlib",
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
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .target(
      name: "GoogleUtilities-UserDefaults",
      dependencies: ["GoogleUtilities-Logger"],
      path: "GoogleUtilities/UserDefaults",
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
        "GoogleUtilities-ISASwizzler",
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
        "GoogleUtilities-ISASwizzler",
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
        "OCMock",
        "GoogleUtilities-AppDelegateSwizzler",
        "GoogleUtilities-Environment",
        "GoogleUtilities-ISASwizzler",
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
