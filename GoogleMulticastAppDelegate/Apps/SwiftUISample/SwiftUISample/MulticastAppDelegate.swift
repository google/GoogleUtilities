//
//  MulticastAppDelegate.swift
//  SwiftUISample
//
//  Created by Charlotte Liang on 1/20/22.
//

// limitations under the License.
import UIKit

private typealias Application = UIApplication
private typealias ApplicationDelegate = UIApplicationDelegate

@objc(GULMulticastAppDelegateProtocol)
public protocol MulticastAppDelegateProtocol: NSObjectProtocol {
  typealias Delegate = UIApplicationDelegate

  func addInterceptor(_ interceptor: Delegate)
  func removeInterceptor(_ interceptor: Delegate)
}

@objc(GULMulticastAppDelegate)
open class MulticastAppDelegate: NSObject, MulticastAppDelegateProtocol {
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

  override public init() {
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
  override public func responds(to aSelector: Selector!) -> Bool {
    if type(of: self).instancesRespond(to: aSelector) {
      return true
    }

    return appDelegate?.responds(to: aSelector) ?? false
  }

  override open func forwardingTarget(for aSelector: Selector) -> Any? {
    return appDelegate
  }
}

// MARK: - Multicast App Delegate detection
extension MulticastAppDelegate {
  /// Returns an instance of app delegate if it conforms to `MulticastAppDelegateProtocol`
  @objc
  public class func installedMulticastDelegate() -> MulticastAppDelegateProtocol? {
    guard let appDelegate = Application.shared.delegate else {
      return nil
    }

    if let multicastDelegate = appDelegate as? MulticastAppDelegateProtocol {
      return multicastDelegate
    }

    // SwiftUI `UIApplicationDelegateAdaptor` doesn't allow easily check if the actual app delegate confirms to a protocol. But any method call is eventually forwarded to the original app delegate instance, so it can be used as a type-safe workaround.
    if appDelegate.responds(to: #selector(gulMulticastDelegate)) {
      return appDelegate.perform(#selector(gulMulticastDelegate))
        .takeRetainedValue() as? MulticastAppDelegateProtocol
    }

    return nil
  }

  /// The method is used to test if calls to `Application.shared.delegate` are forwarded to a `MulticastAppDelegate` subclass.
  @objc
  public func gulMulticastDelegate() -> MulticastAppDelegateProtocol {
    return self
  }
}

extension MulticastAppDelegate: MulticastAppDelegateProtocol.Delegate {
  // MARK: - Open URL
  public func application(_ app: UIApplication, open url: URL,
                          options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    var result = false

    for interceptor in allInterceptors {
      result = result || interceptor.application?(app, open: url, options: options) ?? false
    }

    return result
  }

  // MARK: - APNS methods
  public func application(_ application: UIApplication,
                          didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    for interceptor in allInterceptors {
      interceptor.application?(
        application,
        didRegisterForRemoteNotificationsWithDeviceToken: deviceToken
      )
    }
  }

  public func application(_ application: UIApplication,
                          didFailToRegisterForRemoteNotificationsWithError error: Error) {
    for interceptor in allInterceptors {
      interceptor.application?(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }
  }

  public func application(_ application: UIApplication,
                          didReceiveRemoteNotification notification: [AnyHashable: Any],
                          fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult)
                            -> Void) {
    for interceptor in allInterceptors {
      // TODO: Make sure completionHandler is called once.
      interceptor.application?(
        application,
        didReceiveRemoteNotification: notification,
        fetchCompletionHandler: completionHandler
      )
    }
  }
}

extension MulticastAppDelegate {}
