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
  platforms: [.iOS(.v10), .macOS(.v10_12), .tvOS(.v10), .watchOS(.v6)],
  products: [
    .library(
      name: "GULAppDelegateSwizzler",
      targets: ["GoogleUtilities_AppDelegateSwizzler"]
    ),
    .library(
      name: "GULEnvironment",
      targets: ["GoogleUtilities_Environment"]
    ),
    .library(
      name: "GULLogger",
      targets: ["GoogleUtilities_Logger"]
    ),
    .library(
      name: "GULISASwizzler",
      targets: ["GoogleUtilities_ISASwizzler"]
    ),
    .library(
      name: "GULMethodSwizzler",
      targets: ["GoogleUtilities_MethodSwizzler"]
    ),
    .library(
      name: "GULNetwork",
      targets: ["GoogleUtilities_Network"]
    ),
    .library(
      name: "GULNSData",
      targets: ["GoogleUtilities_NSData"]
    ),
    .library(
      name: "GULReachability",
      targets: ["GoogleUtilities_Reachability"]
    ),
    .library(
      name: "GULSwizzlerTestHelpers",
      targets: ["GoogleUtilities_SwizzlerTestHelpers"]
    ),
    .library(
      name: "GULUserDefaults",
      targets: ["GoogleUtilities_UserDefaults"]
    ),
  ],
  dependencies: [
    .package(name: "Promises", url: "https://github.com/google/promises.git", "1.2.8" ..< "1.3.0"),
    .package(
      name: "OCMock",
      url: "https://github.com/firebase/ocmock.git",
      .revision("7291762d3551c5c7e31c49cce40a0e391a52e889")
    ),
  ],
  // TODO: Restructure directory structure to simplify the excludes here.
  targets: [
    .target(
      name: "GoogleUtilities_AppDelegateSwizzler",
      dependencies: ["GoogleUtilities_Environment",
                     "GoogleUtilities_Logger",
                     "GoogleUtilities_Network"],
      path: "GoogleUtilities",
      exclude: [
        "README.md",
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
        "SceneDelegateSwizzler/",
        "Common/*.h",
      ],
      publicHeadersPath: "AppDelegateSwizzler/Public",
      cSettings: [
        .headerSearchPath("../"),
      ]
    ),
    .target(
      name: "GoogleUtilities_Environment",
      dependencies: [.product(name: "FBLPromises", package: "Promises")],
      path: "GoogleUtilities/Environment",
      exclude: ["third_party/LICENSE"],
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),

    .target(
      name: "GoogleUtilities_Logger",
      dependencies: ["GoogleUtilities_Environment"],
      path: "GoogleUtilities/Logger",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),

    .target(
      name: "GoogleUtilities_ISASwizzler",
      dependencies: ["GoogleUtilities_Logger"],
      path: "GoogleUtilities/ISASwizzler",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),

    .target(
      name: "GoogleUtilities_MethodSwizzler",
      dependencies: ["GoogleUtilities_Logger"],
      path: "GoogleUtilities/MethodSwizzler",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .target(
      name: "GoogleUtilities_Network",
      dependencies: ["GoogleUtilities_Logger",
                     "GoogleUtilities_NSData",
                     "GoogleUtilities_Reachability"],
      path: "GoogleUtilities/Network",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../.."),
      ]
    ),
    .target(
      name: "GoogleUtilities_NSData",
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
      name: "GoogleUtilities_Reachability",
      dependencies: ["GoogleUtilities_Logger"],
      path: "GoogleUtilities/Reachability",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .target(
      name: "GoogleUtilities_UserDefaults",
      dependencies: ["GoogleUtilities_Logger"],
      path: "GoogleUtilities/UserDefaults",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .target(
      name: "GoogleUtilities_SwizzlerTestHelpers",
      dependencies: ["GoogleUtilities_MethodSwizzler"],
      path: "GoogleUtilities/SwizzlerTestHelpers",
      publicHeadersPath: "Public",
      cSettings: [
        .headerSearchPath("../../"),
      ]
    ),
    .testTarget(
      name: "swift-test",
      dependencies: [
        "GoogleUtilities_AppDelegateSwizzler",
        "GoogleUtilities_Environment",
        "GoogleUtilities_ISASwizzler",
        "GoogleUtilities_Logger",
        "GoogleUtilities_MethodSwizzler",
        "GoogleUtilities_Network",
        "GoogleUtilities_NSData",
        "GoogleUtilities_Reachability",
        "GoogleUtilities_UserDefaults",
      ],
      path: "SwiftPMTests/swift-test"
    ),
    .testTarget(
      name: "objc-import-test",
      dependencies: [
        "GoogleUtilities_AppDelegateSwizzler",
        "GoogleUtilities_Environment",
        "GoogleUtilities_ISASwizzler",
        "GoogleUtilities_Logger",
        "GoogleUtilities_MethodSwizzler",
        "GoogleUtilities_Network",
        "GoogleUtilities_NSData",
        "GoogleUtilities_Reachability",
        "GoogleUtilities_UserDefaults",
      ],
      path: "SwiftPMTests/objc-import-test"
    ),
    // TODO: - need to port Network/third_party/GTMHTTPServer.m to ARC.
    .testTarget(
      name: "UtilitiesUnit",
      dependencies: [
        "OCMock",
        "GoogleUtilities_AppDelegateSwizzler",
        "GoogleUtilities_Environment",
        "GoogleUtilities_ISASwizzler",
        "GoogleUtilities_Logger",
        "GoogleUtilities_MethodSwizzler",
        "GoogleUtilities_Network",
        "GoogleUtilities_NSData",
        "GoogleUtilities_Reachability",
        "GoogleUtilities_UserDefaults",
        "GoogleUtilities_SwizzlerTestHelpers",
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
