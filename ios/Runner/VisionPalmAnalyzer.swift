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
  private let minHandArea = 0.18
  private let maxHandArea = 0.65
  private let minimumGuideOverlap = 0.70
  private let maximumRotationFromVertical = 25.0
  private let minimumOpenPalmScore = 0.72

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

    let response: [String: Any] = [
      "source": "Vision",
      "state": "noHand",
      "confidence": 0.0,
      "labels": labels,
      "openPalmScore": 0.0,
      "extendedFingerCount": 0,
      "fingerSpreadRatio": 0.0,
      "handDetected": false,
      "validPalm": false,
      "debug": debugMap,
    ]
    if debugEnabled(debugMap) {
      NSLog(
        "[palmvision] native state=noHand scan=noHand valid=false labels=%@ debug=%@",
        labels.joined(separator: ","),
        String(describing: debugMap)
      )
    }
    return response
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
        debugMode: frame.debugMode,
        frame: frame
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
    let previewWidth = numericDouble(payload["previewWidth"])
    let previewHeight = numericDouble(payload["previewHeight"])
    let guideLeft = numericDouble(payload["guideLeft"])
    let guideTop = numericDouble(payload["guideTop"])
    let guideWidth = numericDouble(payload["guideWidth"])
    let guideHeight = numericDouble(payload["guideHeight"])
    let geometry: PalmFrameGeometry?
    if let previewWidth,
       let previewHeight,
       let guideLeft,
       let guideTop,
       let guideWidth,
       let guideHeight,
       previewWidth > 0,
       previewHeight > 0,
       guideWidth > 0,
       guideHeight > 0 {
      geometry = PalmFrameGeometry(
        previewSize: CGSize(width: previewWidth, height: previewHeight),
        guideRect: CGRect(
          x: guideLeft,
          y: guideTop,
          width: guideWidth,
          height: guideHeight
        )
      )
    } else {
      geometry = nil
    }
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
      "previewWidth": previewWidth ?? 0,
      "previewHeight": previewHeight ?? 0,
      "guideLeft": guideLeft ?? 0,
      "guideTop": guideTop ?? 0,
      "guideWidth": guideWidth ?? 0,
      "guideHeight": guideHeight ?? 0,
      "coordinateSpaceName": geometry == nil
        ? "visionNormalizedFallback"
        : "previewAspectFillGuide",
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
        debugMode: debugMode,
        geometry: geometry
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
    debugMode: Bool,
    frame: PalmFrame
  ) -> [String: Any] {
    let pointThreshold: VNConfidence = 0.35
    let reliablePoints = points.values.filter { $0.confidence >= pointThreshold }
    let reliablePointCount = reliablePoints.count
    let avgConfidence = averageConfidence(reliablePoints)
    let landmarks = recognizedLandmarks(
      points: points,
      threshold: pointThreshold,
      frame: frame
    )

    guard reliablePointCount >= 5 else {
      return Self.noHandResponse(
        labels: ["vision_hand_pose_low_confidence"],
        lastError: nil,
        debug: mergeDebug(
          inheritedDebug,
          [
            "methodChannelSuccess": true,
            "lastError": nil,
            "observationCount": observationCount,
            "handDetected": false,
            "possibleHand": false,
            "validPalm": false,
            "failureReason": "noHand",
            "scanState": "noHand",
            "reliablePointCount": reliablePointCount,
            "averageConfidence": roundMetric(Double(avgConfidence)),
            "openPalmScore": 0.0,
            "coordinateSpaceName": frame.geometry == nil
              ? "visionNormalizedFallback"
              : "previewAspectFillGuide",
          ]
        )
      )
    }

    let metrics = palmValidationMetrics(
      landmarks: landmarks,
      reliablePointCount: reliablePointCount,
      averageConfidence: avgConfidence,
      frame: frame
    )
    let validation = validatePalm(metrics)
    let debug = mergeDebug(
      inheritedDebug,
      validationDebug(
        metrics: metrics,
        validation: validation,
        observationCount: observationCount,
        debugMode: debugMode,
        frame: frame
      )
    )

    return response(
      state: validation.detectionState,
      scanState: validation.scanState,
      confidence: metrics.openPalmScore,
      labels: validation.labels,
      debug: debug,
      handDetected: validation.handDetected,
      possibleHand: validation.possibleHand,
      validPalm: validation.validPalm
    )
  }

  private func response(
    state: String,
    scanState: String,
    confidence: Double,
    labels: [String],
    debug: [String: Any?],
    handDetected: Bool,
    possibleHand: Bool,
    validPalm: Bool
  ) -> [String: Any] {
    let compactDebug = debug.compactMapValues { $0 }
    let openPalmScore = compactDebug["openPalmScore"] as? Double ?? roundMetric(confidence)
    let extendedFingerCount = compactDebug["extendedFingerCount"] as? Int ?? 0
    let fingerSpreadRatio = compactDebug["fingerSpreadRatio"] as? Double ?? 0.0
    let response: [String: Any] = [
      "source": "Vision",
      "state": state,
      "scanState": scanState,
      "confidence": roundMetric(confidence),
      "labels": labels,
      "openPalmScore": openPalmScore,
      "extendedFingerCount": extendedFingerCount,
      "fingerSpreadRatio": fingerSpreadRatio,
      "handDetected": handDetected,
      "possibleHand": possibleHand,
      "validPalm": validPalm,
      "debug": compactDebug,
    ]
    if Self.debugEnabled(compactDebug) {
      NSLog(
        "[palmvision] native state=%@ scan=%@ conf=%.2f valid=%@ labels=%@ debug=%@",
        state,
        scanState,
        roundMetric(confidence),
        validPalm ? "true" : "false",
        labels.joined(separator: ","),
        String(describing: compactDebug)
      )
    }
    return response
  }

  private static func debugEnabled(_ debug: [String: Any]) -> Bool {
    if let debugMode = debug["debugMode"] as? Bool, debugMode {
      return true
    }
    if let debugSmokeMode = debug["debugSmokeMode"] as? Bool, debugSmokeMode {
      return true
    }
    return false
  }

  @available(iOS 14.0, *)
  private func recognizedLandmarks(
    points: [VNHumanHandPoseObservation.JointName: VNRecognizedPoint],
    threshold: VNConfidence,
    frame: PalmFrame
  ) -> [VNHumanHandPoseObservation.JointName: PalmLandmark] {
    var landmarks: [VNHumanHandPoseObservation.JointName: PalmLandmark] = [:]
    for (name, point) in points where point.confidence >= threshold {
      let mappedPoint = mapPointToPreviewSpace(
        visionPoint: point.location,
        frame: frame
      )
      landmarks[name] = PalmLandmark(
        visionLocation: point.location,
        location: mappedPoint,
        confidence: point.confidence
      )
    }
    return landmarks
  }

  private func mapPointToPreviewSpace(
    visionPoint: CGPoint,
    frame: PalmFrame
  ) -> CGPoint {
    let normalized = correctedPreviewNormalizedPoint(
      visionPoint: visionPoint,
      frame: frame
    )

    guard let geometry = frame.geometry else {
      return normalized
    }

    let imageSize = orientedImageSize(frame: frame)
    let previewSize = geometry.previewSize
    guard imageSize.width > 0,
          imageSize.height > 0,
          previewSize.width > 0,
          previewSize.height > 0 else {
      return normalized
    }

    let scale = max(
      previewSize.width / imageSize.width,
      previewSize.height / imageSize.height
    )
    let renderedSize = CGSize(
      width: imageSize.width * scale,
      height: imageSize.height * scale
    )
    let cropOffset = CGPoint(
      x: (renderedSize.width - previewSize.width) / 2.0,
      y: (renderedSize.height - previewSize.height) / 2.0
    )

    let imagePoint = CGPoint(
      x: normalized.x * imageSize.width,
      y: normalized.y * imageSize.height
    )
    let previewPoint = CGPoint(
      x: imagePoint.x * scale - cropOffset.x,
      y: imagePoint.y * scale - cropOffset.y
    )

    return CGPoint(
      x: min(max(previewPoint.x / previewSize.width, 0), 1),
      y: min(max(previewPoint.y / previewSize.height, 0), 1)
    )
  }

  private func correctedPreviewNormalizedPoint(
    visionPoint: CGPoint,
    frame: PalmFrame
  ) -> CGPoint {
    var point = applyYAxisFlip(visionPoint)
    if frame.isFrontCamera {
      point.x = 1.0 - point.x
    }
    return CGPoint(
      x: min(max(point.x, 0), 1),
      y: min(max(point.y, 0), 1)
    )
  }

  private func applyYAxisFlip(_ point: CGPoint) -> CGPoint {
    CGPoint(x: point.x, y: 1.0 - point.y)
  }

  private func orientedImageSize(frame: PalmFrame) -> CGSize {
    let normalized = ((frame.sensorOrientation % 360) + 360) % 360
    if normalized == 90 || normalized == 270 {
      return CGSize(width: frame.height, height: frame.width)
    }
    return CGSize(width: frame.width, height: frame.height)
  }

  @available(iOS 14.0, *)
  private func palmValidationMetrics(
    landmarks: [VNHumanHandPoseObservation.JointName: PalmLandmark],
    reliablePointCount: Int,
    averageConfidence: Float,
    frame: PalmFrame
  ) -> PalmValidationMetrics {
    let fingertipNames: [VNHumanHandPoseObservation.JointName] = [
      .thumbTip,
      .indexTip,
      .middleTip,
      .ringTip,
      .littleTip,
    ]
    let mcpNames: [VNHumanHandPoseObservation.JointName] = [
      .indexMCP,
      .middleMCP,
      .ringMCP,
      .littleMCP,
    ]
    let requiredNames = requiredPalmJointNames()
    let requiredReliableCount = requiredNames
      .filter { landmarks[$0] != nil }
      .count
    let fingertipCount = fingertipNames
      .filter { landmarks[$0] != nil }
      .count
    let mcpCount = mcpNames
      .filter { landmarks[$0] != nil }
      .count
    let extendedFingerCount = extendedFingerCount(landmarks: landmarks)
    let palmCenter = averagePoint(mcpNames.compactMap { landmarks[$0]?.location })
    let guideRect = normalizedGuideRect(frame: frame)
    let handBox = boundingBox(landmarks.values.map(\.location))
    let handArea = handBox.width * handBox.height
    let guideOverlapRatio = calculateGuideOverlap(
      handBox: handBox,
      guideRect: guideRect
    )
    let wristInsideGuide = landmarks[.wrist]
      .map { guideRect.contains($0.location) } ?? false
    let palmCenterInsideGuide = palmCenter
      .map { guideRect.contains($0) } ?? false
    let fingertipsInsideGuide = fingertipNames
      .compactMap { landmarks[$0]?.location }
      .filter { guideRect.contains($0) }
      .count
    let handAreaState: PalmHandAreaState
    if handArea < minHandArea {
      handAreaState = .tooFar
    } else if handArea > maxHandArea {
      handAreaState = .tooClose
    } else {
      handAreaState = .ok
    }
    let rotationAngle = rotationAngleFromVertical(landmarks: landmarks)
    let fingerSpreadRatio = ratio(
      distanceBetween(.indexTip, .littleTip, in: landmarks),
      distanceBetween(.wrist, .middleTip, in: landmarks)
    )
    let thumbSpreadRatio = ratio(
      distanceBetween(.thumbTip, .indexMCP, in: landmarks),
      distanceBetween(.wrist, .middleTip, in: landmarks)
    )
    let orientation = calculatePalmOrientation(landmarks: landmarks)
    let fingerExtensionScore = min(max(Double(extendedFingerCount) / 4.0, 0), 1)
    let reliablePointScore = min(max(Double(requiredReliableCount) / Double(requiredNames.count), 0), 1)
    let fingerSpreadScore = normalizedRangeScore(
      value: fingerSpreadRatio,
      minValue: 0.35,
      maxValue: 0.62
    )
    let verticalOrientationScore = rotationAngle == nil
      ? 0
      : min(max(1.0 - ((rotationAngle ?? 90) / maximumRotationFromVertical), 0), 1)
    let guideAlignmentScore = guideAlignmentScore(
      guideOverlapRatio: guideOverlapRatio,
      palmCenterInsideGuide: palmCenterInsideGuide,
      wristInsideGuide: wristInsideGuide,
      fingertipsInsideGuide: fingertipsInsideGuide
    )
    let confidenceScore = min(max(Double(averageConfidence), 0), 1)
    let openPalmScore =
      reliablePointScore * 0.15 +
      fingerExtensionScore * 0.25 +
      fingerSpreadScore * 0.15 +
      verticalOrientationScore * 0.15 +
      orientation.score * 0.15 +
      guideAlignmentScore * 0.15 +
      confidenceScore * 0.05

    return PalmValidationMetrics(
      reliablePointCount: reliablePointCount,
      requiredReliableCount: requiredReliableCount,
      requiredPointCount: requiredNames.count,
      fingertipCount: fingertipCount,
      mcpCount: mcpCount,
      extendedFingerCount: extendedFingerCount,
      averageConfidence: averageConfidence,
      openPalmScore: openPalmScore,
      fingerSpreadRatio: fingerSpreadRatio,
      thumbSpreadRatio: thumbSpreadRatio,
      fingerSpreadScore: fingerSpreadScore,
      verticalOrientationScore: verticalOrientationScore,
      palmOrientationScore: orientation.score,
      palmOrientationReliable: orientation.isReliable,
      guideAlignmentScore: guideAlignmentScore,
      guideOverlapRatio: guideOverlapRatio,
      palmCenterInsideGuide: palmCenterInsideGuide,
      wristInsideGuide: wristInsideGuide,
      fingertipsInsideGuide: fingertipsInsideGuide,
      handArea: handArea,
      handAreaState: handAreaState,
      rotationAngleFromVertical: rotationAngle ?? 90,
      crossZ: orientation.crossZ,
      isFrontCameraMirrored: frame.isFrontCamera,
      coordinateSpaceName: frame.geometry == nil
        ? "visionNormalizedFallback"
        : "previewAspectFillGuide"
    )
  }

  @available(iOS 14.0, *)
  private func validatePalm(_ metrics: PalmValidationMetrics) -> PalmValidationResult {
    let handDetected = metrics.reliablePointCount >= 5
    let possibleHand = metrics.reliablePointCount >= 10 ||
      metrics.fingertipCount >= 3 ||
      metrics.mcpCount >= 3

    guard handDetected else {
      return PalmValidationResult.noHand(reason: "noHand")
    }

    if metrics.reliablePointCount < 16 ||
       metrics.requiredReliableCount < metrics.requiredPointCount ||
       metrics.fingertipCount < 5 ||
       metrics.mcpCount < 4 ||
       metrics.averageConfidence < 0.55 {
      return PalmValidationResult(
        detectionState: possibleHand ? "partialHand" : "noHand",
        scanState: metrics.fingertipCount < 5 ? "openFingers" : "showPalm",
        handDetected: true,
        possibleHand: possibleHand,
        validPalm: false,
        failureReason: metrics.fingertipCount < 5
          ? "missingFingertips"
          : "missingRequiredPalmJoints",
        labels: [
          "vision_hand_pose",
          "not_valid_palm",
          "required_\(metrics.requiredReliableCount)_of_\(metrics.requiredPointCount)",
          "fingertips_\(metrics.fingertipCount)",
        ]
      )
    }

    if metrics.extendedFingerCount < 4 {
      return PalmValidationResult.reject(
        scanState: "openFingers",
        reason: "fingersNotExtended",
        metrics: metrics
      )
    }

    switch metrics.handAreaState {
    case .tooFar:
      return PalmValidationResult.reject(
        scanState: "handTooFar",
        reason: "handTooFar",
        metrics: metrics
      )
    case .tooClose:
      return PalmValidationResult.reject(
        scanState: "handTooClose",
        reason: "handTooClose",
        metrics: metrics
      )
    case .ok:
      break
    }

    if metrics.guideOverlapRatio < minimumGuideOverlap ||
       !metrics.palmCenterInsideGuide ||
       !metrics.wristInsideGuide ||
       metrics.fingertipsInsideGuide < 4 {
      return PalmValidationResult.reject(
        scanState: "handOutsideGuide",
        reason: "handOutsideGuide",
        metrics: metrics
      )
    }

    if metrics.rotationAngleFromVertical > maximumRotationFromVertical ||
       metrics.verticalOrientationScore <= 0 {
      return PalmValidationResult.reject(
        scanState: "rotateHand",
        reason: "handNotVertical",
        metrics: metrics
      )
    }

    if metrics.fingerSpreadRatio < 0.35 ||
       metrics.thumbSpreadRatio < 0.20 ||
       !metrics.palmOrientationReliable ||
       metrics.palmOrientationScore < 0.62 {
      return PalmValidationResult.reject(
        scanState: "showPalm",
        reason: "palmOrientationUncertain",
        metrics: metrics
      )
    }

    guard metrics.openPalmScore >= minimumOpenPalmScore else {
      return PalmValidationResult.reject(
        scanState: "unstable",
        reason: "openPalmScoreLow",
        metrics: metrics
      )
    }

    return PalmValidationResult(
      detectionState: "validHand",
      scanState: "ready",
      handDetected: true,
      possibleHand: true,
      validPalm: true,
      failureReason: "none",
      labels: [
        "vision_hand_pose",
        "valid_palm",
        "open_palm",
        "fingertips_\(metrics.fingertipCount)",
        "extended_\(metrics.extendedFingerCount)",
      ]
    )
  }

  private func validationDebug(
    metrics: PalmValidationMetrics,
    validation: PalmValidationResult,
    observationCount: Int,
    debugMode: Bool,
    frame: PalmFrame
  ) -> [String: Any?] {
    [
      "methodChannelSuccess": true,
      "lastError": nil,
      "observationCount": observationCount,
      "handDetected": validation.handDetected,
      "possibleHand": validation.possibleHand,
      "validPalm": validation.validPalm,
      "scanState": validation.scanState,
      "failureReason": validation.failureReason,
      "reliablePointCount": metrics.reliablePointCount,
      "requiredReliableCount": metrics.requiredReliableCount,
      "requiredPointCount": metrics.requiredPointCount,
      "fingertipCount": metrics.fingertipCount,
      "mcpCount": metrics.mcpCount,
      "extendedFingerCount": metrics.extendedFingerCount,
      "averageConfidence": roundMetric(Double(metrics.averageConfidence)),
      "openPalmScore": roundMetric(metrics.openPalmScore),
      "fingerSpreadRatio": roundMetric(metrics.fingerSpreadRatio),
      "thumbSpreadRatio": roundMetric(metrics.thumbSpreadRatio),
      "fingerSpreadScore": roundMetric(metrics.fingerSpreadScore),
      "verticalOrientationScore": roundMetric(metrics.verticalOrientationScore),
      "palmOrientationScore": roundMetric(metrics.palmOrientationScore),
      "palmOrientationReliable": metrics.palmOrientationReliable,
      "guideAlignmentScore": roundMetric(metrics.guideAlignmentScore),
      "guideOverlapRatio": roundMetric(metrics.guideOverlapRatio),
      "palmCenterInsideGuide": metrics.palmCenterInsideGuide,
      "wristInsideGuide": metrics.wristInsideGuide,
      "fingertipsInsideGuide": metrics.fingertipsInsideGuide,
      "handArea": roundMetric(metrics.handArea),
      "handAreaState": metrics.handAreaState.rawValue,
      "rotationAngleFromVertical": roundMetric(metrics.rotationAngleFromVertical),
      "crossZ": roundMetric(metrics.crossZ),
      "isFrontCameraMirrored": metrics.isFrontCameraMirrored,
      "coordinateSpaceName": metrics.coordinateSpaceName,
      "debugSmokeMode": debugMode,
      "previewWidth": frame.geometry?.previewSize.width ?? 0,
      "previewHeight": frame.geometry?.previewSize.height ?? 0,
      "guideLeft": frame.geometry?.guideRect.minX ?? 0,
      "guideTop": frame.geometry?.guideRect.minY ?? 0,
      "guideWidth": frame.geometry?.guideRect.width ?? 0,
      "guideHeight": frame.geometry?.guideRect.height ?? 0,
    ]
  }

  @available(iOS 14.0, *)
  private func requiredPalmJointNames() -> [VNHumanHandPoseObservation.JointName] {
    [
      .wrist,
      .thumbCMC,
      .thumbMP,
      .thumbIP,
      .thumbTip,
      .indexMCP,
      .indexPIP,
      .indexDIP,
      .indexTip,
      .middleMCP,
      .middlePIP,
      .middleDIP,
      .middleTip,
      .ringMCP,
      .ringPIP,
      .ringDIP,
      .ringTip,
      .littleMCP,
      .littlePIP,
      .littleDIP,
      .littleTip,
    ]
  }

  @available(iOS 14.0, *)
  private func extendedFingerCount(
    landmarks: [VNHumanHandPoseObservation.JointName: PalmLandmark]
  ) -> Int {
    [
      (.indexPIP, .indexTip),
      (.middlePIP, .middleTip),
      (.ringPIP, .ringTip),
      (.littlePIP, .littleTip),
    ].filter { pipName, tipName in
      guard let wrist = landmarks[.wrist],
            let pip = landmarks[pipName],
            let tip = landmarks[tipName] else {
        return false
      }
      return distance(tip.location, wrist.location) >
        distance(pip.location, wrist.location)
    }.count
  }

  private func normalizedGuideRect(frame: PalmFrame) -> CGRect {
    guard let geometry = frame.geometry,
          geometry.previewSize.width > 0,
          geometry.previewSize.height > 0 else {
      return CGRect(x: 0.18, y: 0.22, width: 0.64, height: 0.56)
    }

    return CGRect(
      x: geometry.guideRect.minX / geometry.previewSize.width,
      y: geometry.guideRect.minY / geometry.previewSize.height,
      width: geometry.guideRect.width / geometry.previewSize.width,
      height: geometry.guideRect.height / geometry.previewSize.height
    )
  }

  private func calculateGuideOverlap(handBox: CGRect, guideRect: CGRect) -> Double {
    guard handBox.width > 0, handBox.height > 0 else { return 0 }
    let intersection = handBox.intersection(guideRect)
    if intersection.isNull || intersection.isEmpty { return 0 }
    return min(max((intersection.width * intersection.height) / (handBox.width * handBox.height), 0), 1)
  }

  private func averagePoint(_ points: [CGPoint]) -> CGPoint? {
    guard !points.isEmpty else { return nil }
    let total = points.reduce(CGPoint.zero) { partial, point in
      CGPoint(x: partial.x + point.x, y: partial.y + point.y)
    }
    return CGPoint(
      x: total.x / CGFloat(points.count),
      y: total.y / CGFloat(points.count)
    )
  }

  private func boundingBox(_ points: [CGPoint]) -> CGRect {
    guard let first = points.first else { return .zero }
    var minX = first.x
    var maxX = first.x
    var minY = first.y
    var maxY = first.y
    for point in points.dropFirst() {
      minX = min(minX, point.x)
      maxX = max(maxX, point.x)
      minY = min(minY, point.y)
      maxY = max(maxY, point.y)
    }
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  }

  @available(iOS 14.0, *)
  private func rotationAngleFromVertical(
    landmarks: [VNHumanHandPoseObservation.JointName: PalmLandmark]
  ) -> Double? {
    guard let wrist = landmarks[.wrist],
          let middleMCP = landmarks[.middleMCP],
          let middleTip = landmarks[.middleTip] else {
      return nil
    }

    let dx = Double(middleMCP.location.x - wrist.location.x)
    let dy = Double(middleMCP.location.y - wrist.location.y)
    let upwardDistance = Double(wrist.location.y - middleTip.location.y)
    guard upwardDistance > 0.08, dy < -0.01 else { return 90 }

    let radians = atan2(abs(dx), max(0.0001, -dy))
    return radians * 180.0 / .pi
  }

  @available(iOS 14.0, *)
  private func distanceBetween(
    _ first: VNHumanHandPoseObservation.JointName,
    _ second: VNHumanHandPoseObservation.JointName,
    in landmarks: [VNHumanHandPoseObservation.JointName: PalmLandmark]
  ) -> Double? {
    guard let a = landmarks[first], let b = landmarks[second] else {
      return nil
    }
    return distance(a.location, b.location)
  }

  private func ratio(_ numerator: Double?, _ denominator: Double?) -> Double {
    guard let numerator,
          let denominator,
          denominator > 0.0001 else {
      return 0
    }
    return numerator / denominator
  }

  private func normalizedRangeScore(
    value: Double,
    minValue: Double,
    maxValue: Double
  ) -> Double {
    guard maxValue > minValue else { return 0 }
    return min(max((value - minValue) / (maxValue - minValue), 0), 1)
  }

  private func guideAlignmentScore(
    guideOverlapRatio: Double,
    palmCenterInsideGuide: Bool,
    wristInsideGuide: Bool,
    fingertipsInsideGuide: Int
  ) -> Double {
    let centerScore = palmCenterInsideGuide ? 1.0 : 0.0
    let wristScore = wristInsideGuide ? 1.0 : 0.0
    let tipScore = min(max(Double(fingertipsInsideGuide) / 4.0, 0), 1)
    return guideOverlapRatio * 0.55 + centerScore * 0.15 + wristScore * 0.15 + tipScore * 0.15
  }

  @available(iOS 14.0, *)
  private func calculatePalmOrientation(
    landmarks: [VNHumanHandPoseObservation.JointName: PalmLandmark]
  ) -> PalmOrientationAssessment {
    guard let wrist = landmarks[.wrist],
          let thumbTip = landmarks[.thumbTip],
          let indexMCP = landmarks[.indexMCP],
          let littleMCP = landmarks[.littleMCP],
          let middleMCP = landmarks[.middleMCP],
          let indexTip = landmarks[.indexTip],
          let littleTip = landmarks[.littleTip],
          let middleTip = landmarks[.middleTip] else {
      return PalmOrientationAssessment(score: 0, isReliable: false, crossZ: 0)
    }

    let vectorA = CGPoint(
      x: indexMCP.location.x - wrist.location.x,
      y: indexMCP.location.y - wrist.location.y
    )
    let vectorB = CGPoint(
      x: littleMCP.location.x - wrist.location.x,
      y: littleMCP.location.y - wrist.location.y
    )
    let crossZ = Double(vectorA.x * vectorB.y - vectorA.y * vectorB.x)
    let palmWidth = distance(indexMCP.location, littleMCP.location)
    let palmDepth = distance(wrist.location, middleMCP.location)
    let crossScore = palmWidth > 0.0001 && palmDepth > 0.0001
      ? min(max(abs(crossZ) / (palmWidth * palmDepth), 0), 1)
      : 0
    let fingerSpreadRatio = ratio(
      distance(indexTip.location, littleTip.location),
      distance(wrist.location, middleTip.location)
    )
    let thumbSpreadRatio = ratio(
      distance(thumbTip.location, indexMCP.location),
      distance(wrist.location, middleTip.location)
    )
    let mcpDy = abs(Double(indexMCP.location.y - littleMCP.location.y))
    let mcpDx = abs(Double(indexMCP.location.x - littleMCP.location.x))
    let mcpLineScore = min(max(1.0 - (mcpDy / max(mcpDx, 0.0001)), 0), 1)
    let minMcpX = min(indexMCP.location.x, littleMCP.location.x)
    let maxMcpX = max(indexMCP.location.x, littleMCP.location.x)
    let thumbSideScore = thumbTip.location.x < minMcpX - 0.015 ||
      thumbTip.location.x > maxMcpX + 0.015 ? 1.0 : 0.0
    let spreadScore = normalizedRangeScore(
      value: fingerSpreadRatio,
      minValue: 0.35,
      maxValue: 0.62
    )
    let thumbScore = normalizedRangeScore(
      value: thumbSpreadRatio,
      minValue: 0.20,
      maxValue: 0.38
    )
    let score = thumbScore * 0.35 +
      thumbSideScore * 0.20 +
      crossScore * 0.20 +
      mcpLineScore * 0.15 +
      spreadScore * 0.10
    let isReliable = thumbSpreadRatio >= 0.20 &&
      fingerSpreadRatio >= 0.35 &&
      crossScore >= 0.12 &&
      mcpDx >= 0.06 &&
      mcpLineScore >= 0.35

    return PalmOrientationAssessment(
      score: min(max(score, 0), 1),
      isReliable: isReliable,
      crossZ: crossZ
    )
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

  private func numericDouble(_ value: Any?) -> Double? {
    if let value = value as? Double { return value }
    if let value = value as? CGFloat { return Double(value) }
    if let value = value as? Float { return Double(value) }
    if let value = value as? Int { return Double(value) }
    if let value = value as? NSNumber { return value.doubleValue }
    return nil
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
  let geometry: PalmFrameGeometry?
}

private struct PalmFrameGeometry {
  let previewSize: CGSize
  let guideRect: CGRect
}

private struct PalmLandmark {
  let visionLocation: CGPoint
  let location: CGPoint
  let confidence: VNConfidence
}

private enum PalmHandAreaState: String {
  case tooFar
  case ok
  case tooClose
}

private struct PalmOrientationAssessment {
  let score: Double
  let isReliable: Bool
  let crossZ: Double
}

private struct PalmValidationMetrics {
  let reliablePointCount: Int
  let requiredReliableCount: Int
  let requiredPointCount: Int
  let fingertipCount: Int
  let mcpCount: Int
  let extendedFingerCount: Int
  let averageConfidence: Float
  let openPalmScore: Double
  let fingerSpreadRatio: Double
  let thumbSpreadRatio: Double
  let fingerSpreadScore: Double
  let verticalOrientationScore: Double
  let palmOrientationScore: Double
  let palmOrientationReliable: Bool
  let guideAlignmentScore: Double
  let guideOverlapRatio: Double
  let palmCenterInsideGuide: Bool
  let wristInsideGuide: Bool
  let fingertipsInsideGuide: Int
  let handArea: Double
  let handAreaState: PalmHandAreaState
  let rotationAngleFromVertical: Double
  let crossZ: Double
  let isFrontCameraMirrored: Bool
  let coordinateSpaceName: String
}

private struct PalmValidationResult {
  let detectionState: String
  let scanState: String
  let handDetected: Bool
  let possibleHand: Bool
  let validPalm: Bool
  let failureReason: String
  let labels: [String]

  static func noHand(reason: String) -> PalmValidationResult {
    PalmValidationResult(
      detectionState: "noHand",
      scanState: "noHand",
      handDetected: false,
      possibleHand: false,
      validPalm: false,
      failureReason: reason,
      labels: ["vision_no_valid_hand"]
    )
  }

  static func reject(
    scanState: String,
    reason: String,
    metrics: PalmValidationMetrics
  ) -> PalmValidationResult {
    PalmValidationResult(
      detectionState: metrics.reliablePointCount >= 14 ? "possibleHand" : "partialHand",
      scanState: scanState,
      handDetected: true,
      possibleHand: true,
      validPalm: false,
      failureReason: reason,
      labels: [
        "vision_hand_pose",
        "not_valid_palm",
        "failure_\(reason)",
        "fingertips_\(metrics.fingertipCount)",
        "extended_\(metrics.extendedFingerCount)",
      ]
    )
  }
}

private struct PalmFrameBuildResult {
  let frame: PalmFrame?
  let error: String?
  let debug: [String: Any?]
}
