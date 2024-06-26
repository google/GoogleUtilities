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
    #else
      XCTAssertFalse(GULAppEnvironmentUtil.isSimulator())
    #endif
    XCTAssertFalse(GULAppEnvironmentUtil.isAppExtension())

    #if os(macOS) || targetEnvironment(macCatalyst)
      // Device model should now return the appropriate hardware model on macOS.
      XCTAssertNotEqual(GULAppEnvironmentUtil.deviceModel(), "x86_64")
    #else
      // Device model should show up as x86_64 for iOS, tvOS, and watchOS
      // simulators.
      let device = GULAppEnvironmentUtil.deviceModel()
      XCTAssertTrue(device == "x86_64" || device == "arm64")
    #endif

    print("System version? Answer: \(GULAppEnvironmentUtil.systemVersion())")
  }
}
