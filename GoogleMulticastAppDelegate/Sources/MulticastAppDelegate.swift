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

import UIKit

@objc
public protocol MulticastAppDelegateProtocol: NSObjectProtocol {
  typealias Delegate = UIApplicationDelegate

  func addInterceptor(_ interceptor: Delegate)
  func removeInterceptor(_ interceptor: Delegate)
}

@objc
open class MulticastAppDelegate: NSObject, MulticastAppDelegateProtocol.Delegate {
  public var appDelegate: MulticastAppDelegateProtocol.Delegate?
  private var interceptors: [MulticastAppDelegateProtocol.Delegate] = []
  private var allInterceptors: [MulticastAppDelegateProtocol.Delegate] {
    guard let appDelegate = appDelegate else {
      return interceptors
    }

    var allInterceptors = [appDelegate]
    allInterceptors.append(contentsOf: interceptors)
    return allInterceptors
  }

  public override init() {
    super.init()
  }

  public init(appDelegate: MulticastAppDelegateProtocol.Delegate) {
    super.init()
    self.appDelegate = appDelegate
  }

  @objc
  public func addInterceptor(_ interceptor: Delegate) {
    interceptors.append(interceptor)
  }

  @objc
  public func removeInterceptor(_ interceptor: Delegate) {
    interceptors = interceptors.filter { $0 !== interceptor }
  }

  // Forward all unknown messages to the original app delegate.
  public override func responds(to aSelector: Selector!) -> Bool {
    if type(of: self).instancesRespond(to: aSelector) {
      return true
    }

    return appDelegate?.responds(to: aSelector) ?? false
  }

  open override func forwardingTarget(for aSelector: Selector!) -> Any? {
    return appDelegate
  }
}

extension MulticastAppDelegate: MulticastAppDelegateProtocol {

  public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    var result = false

    for interceptor in allInterceptors {
      result = result || interceptor.application?(application, didFinishLaunchingWithOptions: launchOptions) ?? false
    }

    return result
  }

  public func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    var result = false

    for interceptor in allInterceptors {
      result = result || interceptor.application?(app, open: url, options: options) ?? false
    }

    return result
  }

  public func application(_ application: UIApplication, didReceiveRemoteNotification notification: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    for interceptor in allInterceptors {
      // TODO: Make sure completionHandler is called once.
      interceptor.application?(application, didReceiveRemoteNotification: notification, fetchCompletionHandler:completionHandler)
    }
  }

}
