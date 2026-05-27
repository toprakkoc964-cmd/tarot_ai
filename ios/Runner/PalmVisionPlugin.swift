import Flutter
import Foundation

final class PalmVisionPlugin: NSObject {
  private static var channel: FlutterMethodChannel?
  private static var plugin: PalmVisionPlugin?

  static func register(with binaryMessenger: FlutterBinaryMessenger) {
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
    guard call.method == "analyzePalmFrame" else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard let payload = call.arguments as? [String: Any] else {
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

    VisionPalmAnalyzer.shared.analyze(payload: payload) { response in
      result(response)
    }
  }
}
