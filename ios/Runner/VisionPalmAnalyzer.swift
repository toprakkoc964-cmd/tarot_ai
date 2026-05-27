import CoreGraphics
import Flutter
import Foundation
import ImageIO
import Vision

final class VisionPalmAnalyzer {
  static let shared = VisionPalmAnalyzer()

  private let queue = DispatchQueue(label: "tarot_ai.palm_vision.queue", qos: .userInitiated)
  private let stateLock = NSLock()
  private var isProcessing = false

  @available(iOS 14.0, *)
  private lazy var handPoseRequest: VNDetectHumanHandPoseRequest = {
    let request = VNDetectHumanHandPoseRequest()
    request.maximumHandCount = 1
    return request
  }()

  private init() {}

  func analyze(payload: [String: Any], completion: @escaping ([String: Any]) -> Void) {
    guard #available(iOS 14.0, *) else {
      completion(
        Self.noHandResponse(
          labels: ["vision_unavailable"],
          lastError: "Vision hand pose requires iOS 14.0 or newer"
        )
      )
      return
    }

    stateLock.lock()
    if isProcessing {
      stateLock.unlock()
      completion(
        Self.noHandResponse(
          labels: ["vision_busy"],
          lastError: "Vision analyzer is already processing a frame"
        )
      )
      return
    }
    isProcessing = true
    stateLock.unlock()

    queue.async { [weak self] in
      guard let self else {
        DispatchQueue.main.async {
          completion(Self.noHandResponse(lastError: "Vision analyzer released"))
        }
        return
      }

      let response: [String: Any] = autoreleasepool {
        self.performAnalysis(payload: payload)
      }

      self.stateLock.lock()
      self.isProcessing = false
      self.stateLock.unlock()

      DispatchQueue.main.async {
        completion(response)
      }
    }
  }

  static func noHandResponse(
    labels: [String] = ["vision_error"],
    lastError: String?,
    debug: [String: Any?] = [:]
  ) -> [String: Any] {
    var debugMap: [String: Any] = [
      "methodChannelSuccess": false,
      "lastError": lastError ?? NSNull(),
    ]
    debug.forEach { debugMap[$0.key] = $0.value ?? NSNull() }

    return [
      "source": "Vision",
      "state": "noHand",
      "confidence": 0.0,
      "labels": labels,
      "debug": debugMap,
    ]
  }

  @available(iOS 14.0, *)
  private func performAnalysis(payload: [String: Any]) -> [String: Any] {
    let totalStartedAt = CFAbsoluteTimeGetCurrent()
    let frameResult = makeFrame(from: payload)
    guard let frame = frameResult.frame else {
      return Self.noHandResponse(
        labels: ["vision_error"],
        lastError: frameResult.error ?? "Invalid camera frame payload",
        debug: mergeDebug(
          frameResult.debug,
          [
            "methodChannelSuccess": false,
            "cgImageCreated": false,
            "visionRequestSucceeded": false,
          ]
        )
      )
    }

    let conversionStartedAt = CFAbsoluteTimeGetCurrent()
    guard let cgImage = makeCGImage(from: frame) else {
      return Self.noHandResponse(
        labels: ["vision_error"],
        lastError: "CGImage conversion failed",
        debug: mergeDebug(
          frameResult.debug,
          [
            "methodChannelSuccess": false,
            "cgImageCreated": false,
            "visionRequestSucceeded": false,
            "convertMs": elapsedMilliseconds(since: conversionStartedAt),
            "visionMs": 0,
            "nativeTotalMs": elapsedMilliseconds(since: totalStartedAt),
          ]
        )
      )
    }
    let convertMs = elapsedMilliseconds(since: conversionStartedAt)

    do {
      let visionStartedAt = CFAbsoluteTimeGetCurrent()
      var orientation = cgOrientation(
        sensorOrientation: frame.sensorOrientation,
        isFrontCamera: frame.isFrontCamera
      )
      var observations = try performHandPoseRequest(
        cgImage: cgImage,
        orientation: orientation
      )
      var orientationFallbackUsed = false
      var attemptedOrientations = [orientationName(orientation)]

      if observations.isEmpty && frame.debugMode {
        for candidate in debugOrientationCandidates(excluding: orientation) {
          attemptedOrientations.append(orientationName(candidate))
          let candidateObservations = try performHandPoseRequest(
            cgImage: cgImage,
            orientation: candidate
          )
          if !candidateObservations.isEmpty {
            orientation = candidate
            observations = candidateObservations
            orientationFallbackUsed = true
            break
          }
        }
      }
      let visionMs = elapsedMilliseconds(since: visionStartedAt)

      let requestDebug = mergeDebug(
        frameResult.debug,
        [
          "methodChannelSuccess": true,
          "cgImageCreated": true,
          "visionRequestSucceeded": true,
          "observationCount": observations.count,
          "sensorOrientation": frame.sensorOrientation,
          "isFrontCamera": frame.isFrontCamera,
          "visionOrientation": orientationName(orientation),
          "orientationFallbackUsed": orientationFallbackUsed,
          "attemptedOrientations": attemptedOrientations.joined(separator: ","),
          "convertMs": convertMs,
          "visionMs": visionMs,
          "nativeTotalMs": elapsedMilliseconds(since: totalStartedAt),
        ]
      )

      guard let observation = observations.first else {
        return Self.noHandResponse(
          labels: ["vision_no_observation"],
          lastError: nil,
          debug: mergeDebug(
            requestDebug,
            [
            "reliablePointCount": 0,
            "fingertipCount": 0,
            "averageConfidence": 0.0,
            "openPalmScore": 0.0,
            "spreadScore": 0.0,
            "palmStructureScore": 0.0,
            "palmAreaScore": 0.0,
            "extendedFingerCount": 0,
            "nonThumbFingertipCount": 0,
            "thumbStructureCount": 0,
            "thumbStructureScore": 0.0,
            "fullPalmGate": false,
            ]
          )
        )
      }

      let points = try observation.recognizedPoints(.all)
      return classify(
        points: points,
        observationCount: observations.count,
        inheritedDebug: requestDebug,
        debugMode: frame.debugMode
      )
    } catch {
      return Self.noHandResponse(
        labels: ["vision_error"],
        lastError: error.localizedDescription,
        debug: mergeDebug(
          frameResult.debug,
          [
            "methodChannelSuccess": false,
            "cgImageCreated": true,
            "visionRequestSucceeded": false,
            "convertMs": convertMs,
            "visionMs": 0,
            "nativeTotalMs": elapsedMilliseconds(since: totalStartedAt),
          ]
        )
      )
    }
  }

  private func makeFrame(from payload: [String: Any]) -> PalmFrameBuildResult {
    let data: Data?
    if let typedData = payload["bytes"] as? FlutterStandardTypedData {
      data = typedData.data
    } else {
      data = payload["bytes"] as? Data
    }

    let width = payload["width"] as? Int
    let height = payload["height"] as? Int
    let bytesPerRow = payload["bytesPerRow"] as? Int
    let formatGroup = payload["formatGroup"] as? String
    let bytesPerPixel = payload["bytesPerPixel"] as? Int
    let sensorOrientation = payload["sensorOrientation"] as? Int ?? 0
    let isFrontCamera = payload["isFrontCamera"] as? Bool ?? false
    let debugMode = payload["debugMode"] as? Bool ?? false
    let expectedMinByteCount = (height ?? 0) * (bytesPerRow ?? 0)
    let debug: [String: Any?] = [
      "byteCount": data?.count ?? 0,
      "expectedMinByteCount": expectedMinByteCount,
      "width": width ?? 0,
      "height": height ?? 0,
      "bytesPerRow": bytesPerRow ?? 0,
      "bytesPerPixel": bytesPerPixel ?? NSNull(),
      "formatGroup": formatGroup ?? "missing",
      "sensorOrientation": sensorOrientation,
      "isFrontCamera": isFrontCamera,
      "debugMode": debugMode,
    ]

    guard
      let bytes = data,
      let width,
      let height,
      let bytesPerRow,
      let formatGroup
    else {
      return PalmFrameBuildResult(
        frame: nil,
        error: "Invalid payload: missing bytes/width/height/bytesPerRow",
        debug: debug
      )
    }

    guard width > 0, height > 0, bytesPerRow > 0 else {
      return PalmFrameBuildResult(
        frame: nil,
        error: "Invalid frame dimensions",
        debug: debug
      )
    }
    guard formatGroup == "bgra8888" else {
      return PalmFrameBuildResult(
        frame: nil,
        error: "Unsupported pixel format: \(formatGroup)",
        debug: debug
      )
    }
    guard bytes.count >= height * bytesPerRow else {
      return PalmFrameBuildResult(
        frame: nil,
        error: "Invalid byte buffer size",
        debug: debug
      )
    }

    return PalmFrameBuildResult(
      frame: PalmFrame(
        bytes: bytes,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        bytesPerPixel: bytesPerPixel,
        sensorOrientation: sensorOrientation,
        isFrontCamera: isFrontCamera,
        debugMode: debugMode
      ),
      error: nil,
      debug: debug
    )
  }

  private func makeCGImage(from frame: PalmFrame) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(
      rawValue: CGBitmapInfo.byteOrder32Little.rawValue |
        CGImageAlphaInfo.premultipliedFirst.rawValue
    )

    guard let provider = CGDataProvider(data: frame.bytes as CFData) else {
      return nil
    }

    return CGImage(
      width: frame.width,
      height: frame.height,
      bitsPerComponent: 8,
      bitsPerPixel: (frame.bytesPerPixel ?? 4) * 8,
      bytesPerRow: frame.bytesPerRow,
      space: colorSpace,
      bitmapInfo: bitmapInfo,
      provider: provider,
      decode: nil,
      shouldInterpolate: false,
      intent: .defaultIntent
    )
  }

  private func cgOrientation(
    sensorOrientation: Int,
    isFrontCamera: Bool
  ) -> CGImagePropertyOrientation {
    let normalized = ((sensorOrientation % 360) + 360) % 360

    switch normalized {
    case 90:
      return isFrontCamera ? .leftMirrored : .right
    case 180:
      return isFrontCamera ? .downMirrored : .down
    case 270:
      return isFrontCamera ? .rightMirrored : .left
    default:
      return isFrontCamera ? .upMirrored : .up
    }
  }

  @available(iOS 14.0, *)
  private func performHandPoseRequest(
    cgImage: CGImage,
    orientation: CGImagePropertyOrientation
  ) throws -> [VNHumanHandPoseObservation] {
    let handler = VNImageRequestHandler(
      cgImage: cgImage,
      orientation: orientation,
      options: [:]
    )
    try handler.perform([handPoseRequest])
    return handPoseRequest.results ?? []
  }

  private func debugOrientationCandidates(
    excluding primary: CGImagePropertyOrientation
  ) -> [CGImagePropertyOrientation] {
    [
      .right,
      .left,
      .up,
      .down,
      .rightMirrored,
      .leftMirrored,
    ].filter { $0 != primary }
  }

  private func orientationName(_ orientation: CGImagePropertyOrientation) -> String {
    switch orientation {
    case .up:
      return "up"
    case .upMirrored:
      return "upMirrored"
    case .down:
      return "down"
    case .downMirrored:
      return "downMirrored"
    case .left:
      return "left"
    case .leftMirrored:
      return "leftMirrored"
    case .right:
      return "right"
    case .rightMirrored:
      return "rightMirrored"
    @unknown default:
      return "unknown"
    }
  }

  @available(iOS 14.0, *)
  private func classify(
    points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint],
    observationCount: Int,
    inheritedDebug: [String: Any?],
    debugMode: Bool
  ) -> [String: Any] {
    let pointThreshold: VNConfidence = 0.35
    let reliablePoints = points.values.filter { $0.confidence >= pointThreshold }
    let reliablePointCount = reliablePoints.count

    guard reliablePointCount >= 5 else {
      return Self.noHandResponse(
        labels: ["vision_hand_pose_low_confidence"],
        lastError: nil,
        debug: baseDebug(
          inheritedDebug,
          methodChannelSuccess: true,
          observationCount: observationCount,
          reliablePointCount: reliablePointCount,
          fingertipCount: 0,
          averageConfidence: averageConfidence(reliablePoints),
          openPalmScore: 0,
          spreadScore: 0,
          palmStructureScore: 0,
          palmAreaScore: 0,
          extendedFingerCount: 0,
          nonThumbFingertipCount: 0,
          thumbStructureCount: 0,
          thumbStructureScore: 0,
          fullPalmGate: false,
          debugMode: debugMode
        )
      )
    }

    let fingertipNames: [VNHumanHandPoseObservation.JointName] = [
      .thumbTip,
      .indexTip,
      .middleTip,
      .ringTip,
      .littleTip,
    ]
    let nonThumbFingertipNames: [VNHumanHandPoseObservation.JointName] = [
      .indexTip,
      .middleTip,
      .ringTip,
      .littleTip,
    ]
    let palmStructureNames: [VNHumanHandPoseObservation.JointName] = [
      .wrist,
      .indexMCP,
      .middleMCP,
      .ringMCP,
      .littleMCP,
    ]
    let thumbStructureNames: [VNHumanHandPoseObservation.JointName] = [
      .thumbCMC,
      .thumbMP,
      .thumbIP,
      .thumbTip,
    ]

    let fingertipCount = countReliablePoints(
      names: fingertipNames,
      in: points,
      threshold: pointThreshold
    )
    let nonThumbFingertipCount = countReliablePoints(
      names: nonThumbFingertipNames,
      in: points,
      threshold: pointThreshold
    )
    let palmStructureCount = countReliablePoints(
      names: palmStructureNames,
      in: points,
      threshold: pointThreshold
    )
    let thumbStructureCount = countReliablePoints(
      names: thumbStructureNames,
      in: points,
      threshold: pointThreshold
    )
    let hasWrist = reliablePoint(.wrist, in: points, threshold: pointThreshold) != nil
    let avgConfidence = averageConfidence(reliablePoints)
    let extendedFingerCount = extendedFingerCount(
      points: points,
      threshold: pointThreshold
    )
    let fingerVisibilityScore = fingerVisibilityScore(fingertipCount)
    let palmStructureScore = Double(palmStructureCount) / Double(palmStructureNames.count)
    let spreadScore = spreadScore(points: points, threshold: pointThreshold)
    let palmAreaScore = palmAreaScore(points: points, threshold: pointThreshold)
    let fingerExtensionScore = Double(extendedFingerCount) / 4.0
    let thumbStructureScore = Double(thumbStructureCount) / Double(thumbStructureNames.count)
    let fullPalmGate = hasWrist &&
      palmStructureCount == palmStructureNames.count &&
      nonThumbFingertipCount == nonThumbFingertipNames.count &&
      extendedFingerCount >= 4 &&
      thumbStructureCount >= 2 &&
      palmAreaScore >= 0.28
    let confidenceScore = min(max(Double(avgConfidence), 0), 1)
    let openPalmScore =
      fingerVisibilityScore * 0.22 +
      palmStructureScore * 0.22 +
      spreadScore * 0.14 +
      palmAreaScore * 0.16 +
      fingerExtensionScore * 0.16 +
      confidenceScore * 0.10

    let debug = baseDebug(
      inheritedDebug,
      methodChannelSuccess: true,
      observationCount: observationCount,
      reliablePointCount: reliablePointCount,
      fingertipCount: fingertipCount,
      averageConfidence: avgConfidence,
      openPalmScore: openPalmScore,
      spreadScore: spreadScore,
      palmStructureScore: palmStructureScore,
      palmAreaScore: palmAreaScore,
      extendedFingerCount: extendedFingerCount,
      nonThumbFingertipCount: nonThumbFingertipCount,
      thumbStructureCount: thumbStructureCount,
      thumbStructureScore: thumbStructureScore,
      fullPalmGate: fullPalmGate,
      debugMode: debugMode
    )

    if !hasWrist ||
       palmStructureCount < 4 ||
       nonThumbFingertipCount < 4 ||
       extendedFingerCount < 3 {
      return response(
        state: "partialHand",
        confidence: openPalmScore,
        labels: [
          "vision_hand_pose",
          "partial_palm",
          "fingertips_\(fingertipCount)",
          "extended_\(extendedFingerCount)",
        ],
        debug: debug
      )
    }

    if reliablePointCount >= 18,
       fingertipCount >= 5,
       avgConfidence >= 0.55,
       openPalmScore >= 0.72,
       fullPalmGate {
      return response(
        state: "validHand",
        confidence: openPalmScore,
        labels: [
          "vision_hand_pose",
          "open_palm",
          "full_palm_gate",
          "fingertips_\(fingertipCount)",
        ],
        debug: debug
      )
    }

    if reliablePointCount >= 14,
       nonThumbFingertipCount >= 4,
       extendedFingerCount >= 3,
       palmStructureCount >= 4,
       palmAreaScore >= 0.18 {
      return response(
        state: "possibleHand",
        confidence: openPalmScore,
        labels: [
          "vision_hand_pose",
          "possible_palm",
          "fingertips_\(fingertipCount)",
          "extended_\(extendedFingerCount)",
        ],
        debug: debug
      )
    }

    return response(
      state: "partialHand",
      confidence: openPalmScore,
      labels: ["vision_hand_pose", "partial_palm", "fingertips_\(fingertipCount)"],
      debug: debug
    )
  }

  private func response(
    state: String,
    confidence: Double,
    labels: [String],
    debug: [String: Any?]
  ) -> [String: Any] {
    [
      "source": "Vision",
      "state": state,
      "confidence": roundMetric(confidence),
      "labels": labels,
      "debug": debug.compactMapValues { $0 },
    ]
  }

  private func mergeDebug(
    _ base: [String: Any?],
    _ extra: [String: Any?]
  ) -> [String: Any?] {
    var merged = base
    extra.forEach { merged[$0.key] = $0.value }
    return merged
  }

  private func baseDebug(
    _ base: [String: Any?],
    methodChannelSuccess: Bool,
    observationCount: Int,
    reliablePointCount: Int,
    fingertipCount: Int,
    averageConfidence: Float,
    openPalmScore: Double,
    spreadScore: Double,
    palmStructureScore: Double,
    palmAreaScore: Double,
    extendedFingerCount: Int,
    nonThumbFingertipCount: Int,
    thumbStructureCount: Int,
    thumbStructureScore: Double,
    fullPalmGate: Bool,
    debugMode: Bool
  ) -> [String: Any?] {
    mergeDebug(
      base,
      [
      "methodChannelSuccess": methodChannelSuccess,
      "lastError": nil,
      "observationCount": observationCount,
      "reliablePointCount": reliablePointCount,
      "fingertipCount": fingertipCount,
      "averageConfidence": roundMetric(Double(averageConfidence)),
      "openPalmScore": roundMetric(openPalmScore),
      "spreadScore": roundMetric(spreadScore),
      "palmStructureScore": roundMetric(palmStructureScore),
      "palmAreaScore": roundMetric(palmAreaScore),
      "extendedFingerCount": extendedFingerCount,
      "nonThumbFingertipCount": nonThumbFingertipCount,
      "thumbStructureCount": thumbStructureCount,
      "thumbStructureScore": roundMetric(thumbStructureScore),
      "fullPalmGate": fullPalmGate,
      "debugSmokeMode": debugMode,
      ]
    )
  }

  @available(iOS 14.0, *)
  private func countReliablePoints(
    names: [VNHumanHandPoseObservation.JointName],
    in points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint],
    threshold: VNConfidence
  ) -> Int {
    names.filter { reliablePoint($0, in: points, threshold: threshold) != nil }.count
  }

  @available(iOS 14.0, *)
  private func extendedFingerCount(
    points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint],
    threshold: VNConfidence
  ) -> Int {
    let fingers: [(VNHumanHandPoseObservation.JointName,
                   VNHumanHandPoseObservation.JointName,
                   VNHumanHandPoseObservation.JointName,
                   VNHumanHandPoseObservation.JointName)] = [
      (.indexMCP, .indexPIP, .indexDIP, .indexTip),
      (.middleMCP, .middlePIP, .middleDIP, .middleTip),
      (.ringMCP, .ringPIP, .ringDIP, .ringTip),
      (.littleMCP, .littlePIP, .littleDIP, .littleTip),
    ]

    return fingers.filter { finger in
      isExtendedFinger(
        mcpName: finger.0,
        pipName: finger.1,
        dipName: finger.2,
        tipName: finger.3,
        points: points,
        threshold: threshold
      )
    }.count
  }

  @available(iOS 14.0, *)
  private func isExtendedFinger(
    mcpName: VNHumanHandPoseObservation.JointName,
    pipName: VNHumanHandPoseObservation.JointName,
    dipName: VNHumanHandPoseObservation.JointName,
    tipName: VNHumanHandPoseObservation.JointName,
    points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint],
    threshold: VNConfidence
  ) -> Bool {
    guard
      let wrist = reliablePoint(.wrist, in: points, threshold: threshold),
      let middleMCP = reliablePoint(.middleMCP, in: points, threshold: threshold),
      let mcp = reliablePoint(mcpName, in: points, threshold: threshold),
      let pip = reliablePoint(pipName, in: points, threshold: threshold),
      let dip = reliablePoint(dipName, in: points, threshold: threshold),
      let tip = reliablePoint(tipName, in: points, threshold: threshold)
    else {
      return false
    }

    let palmDepth = distance(wrist.location, middleMCP.location)
    guard palmDepth > 0.0001 else { return false }

    let wristToMCP = distance(wrist.location, mcp.location)
    let wristToPIP = distance(wrist.location, pip.location)
    let wristToDIP = distance(wrist.location, dip.location)
    let wristToTip = distance(wrist.location, tip.location)
    let mcpToTip = distance(mcp.location, tip.location)

    return wristToTip > wristToDIP &&
      wristToDIP > wristToPIP &&
      wristToPIP > wristToMCP &&
      mcpToTip >= palmDepth * 0.62 &&
      wristToTip >= wristToMCP + palmDepth * 0.48
  }

  @available(iOS 14.0, *)
  private func reliablePoint(
    _ name: VNHumanHandPoseObservation.JointName,
    in points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint],
    threshold: VNConfidence
  ) -> VNRecognizedPoint? {
    guard let point = points[name], point.confidence >= threshold else {
      return nil
    }
    return point
  }

  private func averageConfidence(_ points: [VNRecognizedPoint]) -> Float {
    guard !points.isEmpty else { return 0 }
    let total = points.reduce(Float(0)) { $0 + $1.confidence }
    return total / Float(points.count)
  }

  private func fingerVisibilityScore(_ fingertipCount: Int) -> Double {
    switch fingertipCount {
    case 0:
      return 0.0
    case 1...2:
      return 0.3
    case 3:
      return 0.6
    case 4:
      return 0.85
    default:
      return 1.0
    }
  }

  @available(iOS 14.0, *)
  private func spreadScore(
    points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint],
    threshold: VNConfidence
  ) -> Double {
    guard
      let indexTip = reliablePoint(.indexTip, in: points, threshold: threshold),
      let littleTip = reliablePoint(.littleTip, in: points, threshold: threshold),
      let wrist = reliablePoint(.wrist, in: points, threshold: threshold),
      let middleMCP = reliablePoint(.middleMCP, in: points, threshold: threshold)
    else {
      return 0
    }

    let fingerSpan = distance(indexTip.location, littleTip.location)
    let palmDepth = distance(wrist.location, middleMCP.location)
    guard palmDepth > 0.0001 else { return 0 }

    return min(max(fingerSpan / (palmDepth * 2.0), 0), 1)
  }

  @available(iOS 14.0, *)
  private func palmAreaScore(
    points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint],
    threshold: VNConfidence
  ) -> Double {
    guard
      let wrist = reliablePoint(.wrist, in: points, threshold: threshold),
      let indexMCP = reliablePoint(.indexMCP, in: points, threshold: threshold),
      let middleMCP = reliablePoint(.middleMCP, in: points, threshold: threshold),
      let ringMCP = reliablePoint(.ringMCP, in: points, threshold: threshold),
      let littleMCP = reliablePoint(.littleMCP, in: points, threshold: threshold)
    else {
      return 0
    }

    let palmWidth = distance(indexMCP.location, littleMCP.location)
    let palmDepth = distance(wrist.location, middleMCP.location)
    let polygonArea = polygonArea([
      wrist.location,
      indexMCP.location,
      middleMCP.location,
      ringMCP.location,
      littleMCP.location,
    ])
    let rectangularArea = palmWidth * palmDepth
    let area = max(polygonArea, rectangularArea * 0.65)

    return min(max(area / 0.055, 0), 1)
  }

  private func polygonArea(_ points: [CGPoint]) -> Double {
    guard points.count >= 3 else { return 0 }
    var sum = 0.0
    for index in points.indices {
      let current = points[index]
      let next = points[(index + 1) % points.count]
      sum += Double(current.x * next.y - next.x * current.y)
    }
    return abs(sum) / 2.0
  }

  private func distance(_ a: CGPoint, _ b: CGPoint) -> Double {
    let dx = Double(a.x - b.x)
    let dy = Double(a.y - b.y)
    return sqrt(dx * dx + dy * dy)
  }

  private func roundMetric(_ value: Double) -> Double {
    (value * 100).rounded() / 100
  }

  private func elapsedMilliseconds(since start: CFAbsoluteTime) -> Double {
    roundMetric((CFAbsoluteTimeGetCurrent() - start) * 1000)
  }
}

private struct PalmFrame {
  let bytes: Data
  let width: Int
  let height: Int
  let bytesPerRow: Int
  let bytesPerPixel: Int?
  let sensorOrientation: Int
  let isFrontCamera: Bool
  let debugMode: Bool
}

private struct PalmFrameBuildResult {
  let frame: PalmFrame?
  let error: String?
  let debug: [String: Any?]
}
