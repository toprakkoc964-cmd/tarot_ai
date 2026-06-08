import Flutter
import Foundation

final class PalmVisionDetector: NSObject {
  private static var channel: FlutterMethodChannel?
  private static var detector: PalmVisionDetector?

  static func register(with binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "palmistry/vision",
      binaryMessenger: binaryMessenger
    )
    let detector = PalmVisionDetector()
    channel.setMethodCallHandler(detector.handle)
    Self.channel = channel
    Self.detector = detector
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "detect" else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard var payload = call.arguments as? [String: Any] else {
      result(
        VisionPalmAnalyzer.noHandResponse(
          labels: ["vision_error"],
          lastError: "Invalid payload: missing frameBytes/width/height/bytesPerRow",
          debug: [
            "methodChannelSuccess": false,
            "cgImageCreated": false,
            "visionRequestSucceeded": false,
            "sourceChannel": "palmistry/vision",
          ]
        )
      )
      return
    }

    if payload["bytes"] == nil, let frameBytes = payload["frameBytes"] {
      payload["bytes"] = frameBytes
    }

    VisionPalmAnalyzer.shared.analyze(payload: payload) { response in
      var mapped = response
      mapped["source"] = "apple_vision"
      result(mapped)
    }
  }
}
