// Copyright 2022 Google LLC
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

import SwiftUI
import UIKit

import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import GoogleUtilities
import GoogleMulticastAppDelegate
import nanopb


class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  
//  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
//
//  }
//
//  func application(_ application: UIApplication,
//      didReceiveRemoteNotification notification: [AnyHashable : Any],
//      fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
//    // This notification is not auth related, developer should handle it.
//  }
//
//  // For iOS 9+
//  func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
//
//    // URL not auth related, developer should handle it.
//    return true
//  }

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication
                     .LaunchOptionsKey: Any]? = nil) -> Bool {
    FirebaseApp.configure()
    
    // Request permissions for push notifications
    let center = UNUserNotificationCenter.current()
    center.delegate = self
    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if error != nil {
        print("Failed requesting notification permission: ", error ?? "")
      }
    }
    application.registerForRemoteNotifications()

    PhoneAuthProvider.provider()
      .verifyPhoneNumber("+16505551234", uiDelegate: nil) { verificationID, error in
          if let error = error {
            print(error)
            return
          }
          // Sign in using the verificationID and the code sent to the user
          // ...
        UserDefaults.standard.set(verificationID, forKey: "authVerificationID")
        let verificationID = UserDefaults.standard.string(forKey: "authVerificationID")
        self.signin(verificationID: verificationID ?? "")
      }
    
    return true
  }
  
  func signin(verificationID: String) {
    
    let credential = PhoneAuthProvider.provider().credential(
      withVerificationID: verificationID,
      verificationCode: "654321"
    )
    Auth.auth().signIn(with: credential) { authResult, error in
        if let error = error {
          print(error.localizedDescription)
          return
        }
    }
  }
}
@main
struct SwiftUISampleApp: App {
  @UIApplicationDelegateAdaptor(GULMulticastAppDelegate.self) var delegate
  
  init() {
    self.delegate.appDelegate = AppDelegate()
  }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
