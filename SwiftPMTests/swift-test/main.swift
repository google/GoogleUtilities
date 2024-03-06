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

import Foundation
import GoogleUtilities_AppDelegateSwizzler
import GoogleUtilities_Environment
import GoogleUtilities_Logger
import GoogleUtilities_MethodSwizzler
import GoogleUtilities_Network
import GoogleUtilities_NSData
import GoogleUtilities_Reachability
import GoogleUtilities_UserDefaults

import XCTest

class importTest: XCTestCase {
  func testImports() throws {
    XCTAssertFalse(GULAppEnvironmentUtil.isAppStoreReceiptSandbox())
    XCTAssertFalse(GULAppEnvironmentUtil.isFromAppStore())
    #if targetEnvironment(simulator)
      XCTAssertTrue(GULAppEnvironmentUtil.isSimulator())
      // Device model should return the host's build architecture (x86_64 or arm64) for iOS, tvOS
      // watchOS, and visionOS simulators.
      XCTAssertEqual(GULAppEnvironmentUtil.deviceModel(), buildArchitecture())
    #else
      XCTAssertFalse(GULAppEnvironmentUtil.isSimulator())
      // Device model should return the appropriate hardware model (e.g., "iPhone12,3" or
      // "MacBookPro18,2") on real devices.
      XCTAssertNotEqual(GULAppEnvironmentUtil.deviceModel(), buildArchitecture())
    #endif
    XCTAssertFalse(GULAppEnvironmentUtil.isAppExtension())

    print("System version? Answer: \(GULAppEnvironmentUtil.systemVersion())")
  }

  func buildArchitecture() -> String {
    #if arch(arm64)
      return "arm64"
    #elseif arch(x86_64)
      return "x86_64"
    #else
      throw TestError(errorDescription: "Unexpected build architecture.")
    #endif
  }

  struct TestError: Error {
    var errorDescription: String?
  }
}
