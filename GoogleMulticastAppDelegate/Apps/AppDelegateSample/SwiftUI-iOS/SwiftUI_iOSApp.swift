//
//  SwiftUI_iOSApp.swift
//  SwiftUI-iOS
//
//  Created by Maksym Malyhin on 2021-02-22.
//

import SwiftUI
import GoogleMulticastAppDelegate

@objc
class AppDelegate: NSObject, MulticastAppDelegateProtocol.Delegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    return true
  }
}

@main
struct SwiftUI_iOSApp: App {
  // Set `MulticastAppDelegate` as an App Delegate.
    @UIApplicationDelegateAdaptor(MulticastAppDelegate.self) var delegate

    init() {
      // Register the app's own App Delegate as an interceptor.
      self.delegate.appDelegate = AppDelegate()
    }


    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
