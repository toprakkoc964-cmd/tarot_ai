import Flutter
import FirebaseCore
import FirebaseMessaging
import OSLog
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let deviceInfoChannelName = "tarot_ai/device_info"
  private let cameraLogger = Logger(subsystem: "com.tarotai", category: "camera")

  private func cameraNSLog(_ message: String) {
    NSLog("[camera] \(message)")
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    cameraLogger.info("AppDelegate didFinishLaunching")
    cameraNSLog("AppDelegate didFinishLaunching")
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
      cameraLogger.info("Firebase configured")
      cameraNSLog("Firebase configured")
    }

    application.registerForRemoteNotifications()
    cameraLogger.info("Remote notification registration requested")
    cameraNSLog("Remote notification registration requested")

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    cameraLogger.info("Implicit Flutter engine initialized")
    cameraNSLog("Implicit Flutter engine initialized")
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()
    registerDeviceInfoChannel(binaryMessenger: messenger)
    PalmVisionPlugin.register(with: messenger)
  }

  private func registerDeviceInfoChannel(binaryMessenger: FlutterBinaryMessenger) {
    cameraLogger.info("Registering device_info channel")
    cameraNSLog("Registering device_info channel")
    let channel = FlutterMethodChannel(
      name: deviceInfoChannelName,
      binaryMessenger: binaryMessenger
    )
    let logger = cameraLogger
    channel.setMethodCallHandler { call, result in
      logger.info("device_info method=\(call.method, privacy: .public)")
      NSLog("[camera] device_info method=\(call.method)")
      switch call.method {
      case "isIosSimulator":
        #if targetEnvironment(simulator)
          result(true)
        #else
          result(false)
        #endif
      default:
        logger.error("device_info method not implemented: \(call.method, privacy: .public)")
        NSLog("[camera] device_info method not implemented: \(call.method)")
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
