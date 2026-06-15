import Flutter
import Foundation
import OSLog

final class PalmVisionPlugin: NSObject {
  private static var channel: FlutterMethodChannel?
  private static var plugin: PalmVisionPlugin?
  private static let logger = Logger(subsystem: "com.tarotai", category: "camera")

  private static func cameraNSLog(_ message: String) {
    NSLog("[camera] \(message)")
  }

  static func register(with binaryMessenger: FlutterBinaryMessenger) {
    logger.info("PalmVisionPlugin register")
    cameraNSLog("PalmVisionPlugin register")
    let channel = FlutterMethodChannel(
      name: "tarot_ai/palm_vision",
      binaryMessenger: binaryMessenger
    )
    let plugin = PalmVisionPlugin()
    channel.setMethodCallHandler(plugin.handle)
    Self.channel = channel
    Self.plugin = plugin
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    Self.logger.info("PalmVisionPlugin method=\(call.method, privacy: .public)")
    Self.cameraNSLog("PalmVisionPlugin method=\(call.method)")
    guard call.method == "analyzePalmFrame" else {
      Self.logger.error("PalmVisionPlugin method not implemented: \(call.method, privacy: .public)")
      Self.cameraNSLog("PalmVisionPlugin method not implemented: \(call.method)")
      result(FlutterMethodNotImplemented)
      return
    }

    guard let payload = call.arguments as? [String: Any] else {
      Self.logger.error("PalmVisionPlugin invalid payload")
      Self.cameraNSLog("PalmVisionPlugin invalid payload")
      result(
        VisionPalmAnalyzer.noHandResponse(
          labels: ["vision_error"],
          lastError: "Invalid payload: missing bytes/width/height/bytesPerRow",
          debug: [
            "methodChannelSuccess": false,
            "cgImageCreated": false,
            "visionRequestSucceeded": false,
          ]
        )
      )
      return
    }

    let width = payload["width"] as? Int ?? -1
    let height = payload["height"] as? Int ?? -1
    let bytesPerRow = payload["bytesPerRow"] as? Int ?? -1
    let sensorOrientation = payload["sensorOrientation"] as? Int ?? -1
    Self.logger.info(
      "PalmVisionPlugin analyze start width=\(width, privacy: .public) height=\(height, privacy: .public) bytesPerRow=\(bytesPerRow, privacy: .public) sensor=\(sensorOrientation, privacy: .public)"
    )
    Self.cameraNSLog(
      "PalmVisionPlugin analyze start width=\(width) height=\(height) bytesPerRow=\(bytesPerRow) sensor=\(sensorOrientation)"
    )
    VisionPalmAnalyzer.shared.analyze(payload: payload) { response in
      let handDetected = response["handDetected"] as? Bool ?? false
      let validPalm = response["validPalm"] as? Bool ?? false
      let scanState = response["scanState"] as? String ?? "unknown"
      Self.logger.info(
        "PalmVisionPlugin analyze done hand=\(handDetected, privacy: .public) validPalm=\(validPalm, privacy: .public) scanState=\(scanState, privacy: .public)"
      )
      Self.cameraNSLog(
        "PalmVisionPlugin analyze done hand=\(handDetected) validPalm=\(validPalm) scanState=\(scanState)"
      )
      result(response)
    }
  }
}
