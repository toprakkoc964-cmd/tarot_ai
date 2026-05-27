import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/app_texts.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_compression_helper.dart';
import '../../../core/utils/palm_detection_result.dart';
import '../../../core/utils/palm_frame_analyzer.dart';
import '../services/i_palmistry_service.dart';
import '../widgets/cosmic_scan_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/palm_overlay_painter.dart';
import '../widgets/scanner_laser_painter.dart';
import 'palmistry_result_screen.dart';

class PalmScannerScreen extends StatefulWidget {
  const PalmScannerScreen({super.key});

  static const String heroTag = 'palmistry-scan-hero';

  @override
  State<PalmScannerScreen> createState() => _PalmScannerScreenState();
}

class _PalmScannerScreenState extends State<PalmScannerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const Duration _frameAnalysisInterval = Duration(milliseconds: 650);
  static const Duration _debugRefreshInterval = Duration(milliseconds: 900);
  static const int _detectionHistoryLimit = 5;

  final PalmFrameAnalyzer _frameAnalyzer = PalmFrameAnalyzer();
  final List<PalmDetectionResult> _recentDetections = <PalmDetectionResult>[];
  late final AnimationController _scanAnimation;
  late final AnimationController _overlayPulseAnimation;

  CameraController? _controller;
  CameraDescription? _camera;
  DateTime? _lastVisionAnalysisAt;
  DateTime? _lastDebugRefreshAt;
  DateTime? _lastDebugLogAt;
  File? _frozenImage;

  bool _isInitializing = true;
  bool _isPermissionDenied = false;
  bool _isPermissionPermanentlyDenied = false;
  bool _isProcessingFrame = false;
  bool _isScanning = false;
  PalmDetectionResult _detectionResult = const PalmDetectionResult.noHand();
  String? _errorTitle;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    );
    _overlayPulseAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    unawaited(_initializeCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isPermissionDenied) {
      unawaited(_initializeCamera());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recentDetections.clear();
    _overlayPulseAnimation.dispose();
    _scanAnimation.dispose();
    unawaited(_frameAnalyzer.dispose());
    unawaited(_disposeCamera());
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return;
    setState(() {
      _isInitializing = true;
      _isPermissionDenied = false;
      _isPermissionPermanentlyDenied = false;
      _errorTitle = null;
      _errorMessage = null;
      _resetDetectionState();
    });

    try {
      var permission = await Permission.camera.status;
      if (permission.isDenied) {
        permission = await Permission.camera.request();
      }

      if (!permission.isGranted) {
        if (!mounted) return;
        setState(() {
          _isPermissionDenied = true;
          _isPermissionPermanentlyDenied = permission.isPermanentlyDenied;
          _isInitializing = false;
        });
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no_camera', 'No camera is available.');
      }

      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _camera = camera;
        _controller = controller;
        _isInitializing = false;
      });

      await _startImageStream();
    } on CameraException catch (e) {
      debugPrint('Palm camera failed: ${e.code} ${e.description}');
      if (!mounted) return;
      final code = e.code.toLowerCase();
      final isPermissionError = code.contains('accessdenied');
      final isCameraUnavailable =
          code.contains('no_camera') || code.contains('notavailable');
      setState(() {
        _isPermissionDenied = isPermissionError;
        _isInitializing = false;
        _errorTitle = isPermissionError
            ? null
            : isCameraUnavailable
                ? AppTexts.t('cameraUnavailableTitle')
                : AppTexts.t('palmScanErrorTitle');
        _errorMessage = isPermissionError
            ? null
            : isCameraUnavailable
                ? AppTexts.t('cameraUnavailableDescription')
                : AppTexts.t('palmScanErrorDescription');
      });
    } catch (e, st) {
      debugPrint('Palm scanner init failed: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorTitle = AppTexts.t('palmScanErrorTitle');
        _errorMessage = AppTexts.t('palmScanErrorDescription');
      });
    }
  }

  Future<void> _startImageStream() async {
    final controller = _controller;
    final camera = _camera;
    if (controller == null ||
        camera == null ||
        !controller.value.isInitialized ||
        controller.value.isStreamingImages) {
      return;
    }

    await controller.startImageStream((image) {
      unawaited(_handleCameraImage(image, camera, controller));
    });
  }

  Future<void> _handleCameraImage(
    CameraImage image,
    CameraDescription camera,
    CameraController controller,
  ) async {
    if (!_shouldAnalyzeFrame()) return;

    try {
      final result = await _frameAnalyzer.analyze(
        image: image,
        camera: camera,
        deviceOrientation: controller.value.deviceOrientation,
      );

      if (!mounted || _isScanning) return;

      final shouldHaptic = _handleDetectionResult(result);
      _logDetectionResult(result);
      if (shouldHaptic) {
        await HapticFeedback.mediumImpact();
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('PalmVision ERROR: lastError=$e');
        debugPrintStack(stackTrace: st);
      }
    } finally {
      _isProcessingFrame = false;
    }
  }

  bool _shouldAnalyzeFrame() {
    if (_isScanning || _isProcessingFrame || !mounted) return false;

    final now = DateTime.now();
    final lastAnalysis = _lastVisionAnalysisAt;
    if (lastAnalysis != null &&
        now.difference(lastAnalysis) < _frameAnalysisInterval) {
      return false;
    }

    _lastVisionAnalysisAt = now;
    _isProcessingFrame = true;
    return true;
  }

  void _resetDetectionState() {
    _recentDetections.clear();
    _detectionResult = const PalmDetectionResult.noHand();
    _lastVisionAnalysisAt = null;
    _lastDebugRefreshAt = null;
    _lastDebugLogAt = null;
  }

  bool _handleDetectionResult(PalmDetectionResult result) {
    final previousDisplayState = _displayDetectionState;
    final previousCanScan = _canScan;

    _detectionResult = result;
    _recentDetections.add(result);
    if (_recentDetections.length > _detectionHistoryLimit) {
      _recentDetections.removeAt(0);
    }

    final nextDisplayState = _displayDetectionState;
    final nextCanScan = _canScan;
    final shouldUpdateUi = previousDisplayState != nextDisplayState ||
        previousCanScan != nextCanScan ||
        _shouldRefreshDebugPanel();

    if (shouldUpdateUi && mounted) {
      setState(() {});
    }

    return !previousCanScan && nextCanScan;
  }

  bool _shouldRefreshDebugPanel() {
    if (!kDebugMode) return false;

    final now = DateTime.now();
    final lastRefresh = _lastDebugRefreshAt;
    if (lastRefresh != null &&
        now.difference(lastRefresh) < _debugRefreshInterval) {
      return false;
    }

    _lastDebugRefreshAt = now;
    return true;
  }

  Future<void> _startScan() async {
    final controller = _controller;
    if (!_canScan ||
        _isScanning ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      await _safeStopImageStream();
      final picture = await controller.takePicture();
      final imageFile = File(picture.path);

      if (!mounted) return;
      setState(() => _frozenImage = imageFile);
      _scanAnimation.repeat();

      final compressed = await compressPalmImage(imageFile);
      final result = await getIt<IPalmistryService>().analyzePalm(compressed);

      if (!mounted) return;
      await _disposeCamera();

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, animation, __) {
            return FadeTransition(
              opacity: animation,
              child: PalmistryResultScreen(result: result),
            );
          },
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } catch (e, st) {
      debugPrint('Palm scan failed: $e');
      debugPrintStack(stackTrace: st);
      _scanAnimation.stop();
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _errorTitle = AppTexts.t('palmScanErrorTitle');
        _errorMessage = AppTexts.t('palmScanErrorDescription');
        _frozenImage = null;
        _resetDetectionState();
      });
      await _startImageStream();
    }
  }

  Future<void> _safeStopImageStream() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        !controller.value.isStreamingImages) {
      return;
    }

    try {
      await controller.stopImageStream();
    } catch (e) {
      debugPrint('Stopping palm image stream failed: $e');
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _controller;
    _controller = null;
    _camera = null;

    if (controller == null) return;
    try {
      if (controller.value.isInitialized &&
          controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.dispose();
    } catch (e) {
      debugPrint('Palm camera dispose failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _PalmScannerBackground(),
          SafeArea(
            child: Column(
              children: [
                _Header(onBack: () => Navigator.of(context).maybePop()),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                    child: _buildBody(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryPink),
      );
    }

    if (_isPermissionDenied) {
      return _PermissionPanel(
        isPermanentlyDenied: _isPermissionPermanentlyDenied,
        onOpenSettings: () async {
          await openAppSettings();
        },
        onRetry: _initializeCamera,
      );
    }

    final controller = _controller;
    if (_errorMessage != null ||
        controller == null ||
        !controller.value.isInitialized) {
      return _ErrorPanel(
        title: _errorTitle ?? AppTexts.t('palmScanErrorTitle'),
        description: _errorMessage ?? AppTexts.t('palmScanErrorDescription'),
        onRetry: _initializeCamera,
      );
    }

    final helperText = _helperText;
    final statusColor = _statusColor;
    final overlayState =
        _isScanning ? PalmDetectionState.validHand : _displayDetectionState;
    final detectionProgress = _isScanning ? 1.0 : _detectionProgress;
    final overlay = CustomPaint(
      painter: PalmOverlayPainter(
        detectionState: overlayState,
        readinessProgress: detectionProgress,
        pulseValue: 0,
      ),
    );
    final pulsingOverlay = AnimatedBuilder(
      animation: _overlayPulseAnimation,
      builder: (context, _) {
        return CustomPaint(
          painter: PalmOverlayPainter(
            detectionState: overlayState,
            readinessProgress: detectionProgress,
            pulseValue: _overlayPulseAnimation.value,
          ),
        );
      },
    );

    return Column(
      children: [
        Text(
          AppTexts.t('palmScannerDescription'),
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: AppColors.secondaryLavender.withValues(alpha: 0.9),
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Hero(
            tag: PalmScannerScreen.heroTag,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(34),
              child: RepaintBoundary(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RepaintBoundary(
                      child: _CameraSurface(
                        controller: controller,
                        frozenImage: _frozenImage,
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppColors.glassBorder,
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(34),
                      ),
                    ),
                    RepaintBoundary(
                      child: overlayState == PalmDetectionState.possibleHand
                          ? pulsingOverlay
                          : overlay,
                    ),
                    if (_isScanning)
                      RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _scanAnimation,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: ScannerLaserPainter(
                                progress: _scanAnimation.value,
                              ),
                            );
                          },
                        ),
                      ),
                    if (kDebugMode)
                      Positioned(
                        left: 12,
                        right: 12,
                        top: 12,
                        child: RepaintBoundary(
                          child: _PalmDebugPanel(
                            lastResult: _detectionResult,
                            canScan: _canScan,
                            recentDetectionsLength: _recentDetections.length,
                            validCount: _validDetectionCount,
                            possibleCount: _possibleDetectionCount,
                            partialCount: _partialDetectionCount,
                            noHandCount: _noHandDetectionCount,
                            isProcessingFrame: _isProcessingFrame,
                            isScanning: _isScanning,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        GlassPanel(
          borderRadius: 24,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            children: [
              Text(
                helperText,
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                  color: _canScan || _isScanning
                      ? AppColors.primaryPink
                      : statusColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 12),
              _DetectionProgress(
                progress: detectionProgress,
                state: overlayState,
              ),
              const SizedBox(height: 14),
              CosmicScanButton(
                text: AppTexts.t('palmTapToScan'),
                icon: Icons.front_hand_rounded,
                enabled: _canScan,
                isLoading: _isScanning,
                onTap: _startScan,
              ),
              const SizedBox(height: 12),
              Text(
                AppTexts.t('privacyTemporaryProcessing'),
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: AppColors.secondaryLavender.withValues(alpha: 0.66),
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: AppColors.primaryPink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  String get _helperText {
    if (_isScanning) return AppTexts.t('palmScanningLoading');
    if (_canScan) return AppTexts.t('palmDetected');

    switch (_displayDetectionState) {
      case PalmDetectionState.validHand:
      case PalmDetectionState.possibleHand:
        return AppTexts.t('palmHoldSteady');
      case PalmDetectionState.partialHand:
        return AppTexts.t('palmPartialHand');
      case PalmDetectionState.noHand:
        return AppTexts.t('palmAlignHand');
    }
  }

  Color get _statusColor {
    switch (_displayDetectionState) {
      case PalmDetectionState.validHand:
      case PalmDetectionState.possibleHand:
        return AppColors.primaryPink;
      case PalmDetectionState.partialHand:
        return AppColors.tertiaryGold;
      case PalmDetectionState.noHand:
        return AppColors.secondaryLavender;
    }
  }

  double get _detectionProgress {
    final weightedScore = _validDetectionCount * 2 + _possibleDetectionCount;
    return (weightedScore / 4).clamp(0, 1).toDouble();
  }

  PalmDetectionState get _displayDetectionState {
    if (_canScan) return PalmDetectionState.validHand;
    if (_recentDetections.isEmpty) return PalmDetectionState.noHand;

    final last = _recentDetections.last;
    if (last.state == PalmDetectionState.possibleHand) {
      return PalmDetectionState.possibleHand;
    }
    if (last.state == PalmDetectionState.partialHand) {
      return PalmDetectionState.partialHand;
    }
    return last.state;
  }

  bool get _canScan {
    if (_isScanning) return false;
    if (_recentDetections.length < 3) return false;

    final lastState = _recentDetections.last.state;
    if (lastState == PalmDetectionState.noHand ||
        lastState == PalmDetectionState.partialHand) {
      return false;
    }

    return _validDetectionCount >= 2 ||
        (_validDetectionCount >= 1 && _possibleDetectionCount >= 2);
  }

  int get _validDetectionCount {
    return _recentDetections
        .where((result) => result.state == PalmDetectionState.validHand)
        .length;
  }

  int get _possibleDetectionCount {
    return _recentDetections
        .where((result) => result.state == PalmDetectionState.possibleHand)
        .length;
  }

  int get _partialDetectionCount {
    return _recentDetections
        .where((result) => result.state == PalmDetectionState.partialHand)
        .length;
  }

  int get _noHandDetectionCount {
    return _recentDetections
        .where((result) => result.state == PalmDetectionState.noHand)
        .length;
  }

  void _logDetectionResult(PalmDetectionResult result) {
    if (!kDebugMode) return;

    final now = DateTime.now();
    final lastLog = _lastDebugLogAt;
    if (lastLog != null && now.difference(lastLog) < _debugRefreshInterval) {
      return;
    }

    _lastDebugLogAt = now;
    debugPrint(_debugLine(result));
  }

  String _debugLine(PalmDetectionResult result) {
    final debug = result.debug ?? const <String, dynamic>{};
    final methodChannelSuccess = debug['methodChannelSuccess'];
    final prefix =
        methodChannelSuccess == false ? 'PalmVision ERROR: ' : 'PalmVision: ';
    return '$prefix'
        'state=${result.state.name}, '
        'open=${debug['openPalmScore'] ?? '-'}, '
        'tips=${debug['fingertipCount'] ?? '-'}, '
        'ext=${debug['extendedFingerCount'] ?? '-'}, '
        'area=${debug['palmAreaScore'] ?? '-'}, '
        'gate=${debug['fullPalmGate'] ?? '-'}, '
        'validCount=$_validDetectionCount, '
        'possibleCount=$_possibleDetectionCount, '
        'canScan=$_canScan, '
        'channel=${debug['channelMs'] ?? '-'}ms, '
        'vision=${debug['visionMs'] ?? '-'}ms, '
        'total=${debug['totalMs'] ?? '-'}ms, '
        'error=${debug['lastError'] ?? '-'}';
  }
}

class _DetectionProgress extends StatelessWidget {
  const _DetectionProgress({
    required this.progress,
    required this.state,
  });

  final double progress;
  final PalmDetectionState state;

  @override
  Widget build(BuildContext context) {
    final activeSteps = (progress * 3).round();
    final color = switch (state) {
      PalmDetectionState.validHand => AppColors.primaryNeonPink,
      PalmDetectionState.possibleHand => AppColors.primaryPink,
      PalmDetectionState.partialHand => AppColors.tertiaryGold,
      PalmDetectionState.noHand => AppColors.secondaryLavender,
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index < activeSteps;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 30 : 18,
          height: 5,
          decoration: BoxDecoration(
            color: isActive
                ? color.withValues(alpha: 0.9)
                : AppColors.secondaryLavender.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(99),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class _PalmDebugPanel extends StatelessWidget {
  const _PalmDebugPanel({
    required this.lastResult,
    required this.canScan,
    required this.recentDetectionsLength,
    required this.validCount,
    required this.possibleCount,
    required this.partialCount,
    required this.noHandCount,
    required this.isProcessingFrame,
    required this.isScanning,
  });

  final PalmDetectionResult lastResult;
  final bool canScan;
  final int recentDetectionsLength;
  final int validCount;
  final int possibleCount;
  final int partialCount;
  final int noHandCount;
  final bool isProcessingFrame;
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    final labels = lastResult.labels.take(4).join(', ');
    final debug = lastResult.debug ?? const <String, dynamic>{};

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryPink.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: DefaultTextStyle(
          style: GoogleFonts.spaceGrotesk(
            color: AppColors.onSurface.withValues(alpha: 0.88),
            fontSize: 11,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('source: ${lastResult.source ?? '-'}  '
                  'method: ${debug['methodChannelSuccess'] ?? '-'}'),
              Text('error: ${debug['lastError'] ?? '-'}'),
              Text('state: ${lastResult.state.name}  '
                  'confidence: ${lastResult.confidence.toStringAsFixed(2)}'),
              Text('recent: $recentDetectionsLength  valid: $validCount  '
                  'possible: $possibleCount'),
              Text('partial: $partialCount  noHand: $noHandCount  '
                  'canScan: $canScan'),
              Text('processing: $isProcessingFrame  scanning: $isScanning'),
              Text('reliable: ${debug['reliablePointCount'] ?? '-'}  '
                  'tips: ${debug['fingertipCount'] ?? '-'}  '
                  'avg: ${debug['averageConfidence'] ?? '-'}'),
              Text('open: ${debug['openPalmScore'] ?? '-'}  '
                  'spread: ${debug['spreadScore'] ?? '-'}  '
                  'palm: ${debug['palmStructureScore'] ?? '-'}'),
              Text('area: ${debug['palmAreaScore'] ?? '-'}  '
                  'extended: ${debug['extendedFingerCount'] ?? '-'}  '
                  'nonThumbTips: ${debug['nonThumbFingertipCount'] ?? '-'}'),
              Text('thumb: ${debug['thumbStructureCount'] ?? '-'}  '
                  'gate: ${debug['fullPalmGate'] ?? '-'}'),
              Text('obs: ${debug['observationCount'] ?? '-'}  '
                  'cg: ${debug['cgImageCreated'] ?? '-'}  '
                  'vision: ${debug['visionRequestSucceeded'] ?? '-'}'),
              Text('fmt: ${debug['formatGroup'] ?? '-'}  '
                  'bytes: ${debug['byteCount'] ?? '-'}  '
                  'row: ${debug['bytesPerRow'] ?? '-'}'),
              Text('ori: ${debug['sensorOrientation'] ?? '-'}  '
                  'front: ${debug['isFrontCamera'] ?? '-'}  '
                  'visionOri: ${debug['visionOrientation'] ?? '-'}'),
              Text('labels: ${labels.isEmpty ? '-' : labels}'),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraSurface extends StatelessWidget {
  const _CameraSurface({
    required this.controller,
    required this.frozenImage,
  });

  final CameraController controller;
  final File? frozenImage;

  @override
  Widget build(BuildContext context) {
    final image = frozenImage;
    if (image != null) {
      return Image.file(image, fit: BoxFit.cover);
    }

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: controller.value.previewSize?.height ?? 1,
        height: controller.value.previewSize?.width ?? 1,
        child: CameraPreview(controller),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.primaryPink,
              size: 30,
            ),
          ),
          Expanded(
            child: Text(
              AppTexts.t('palmScannerTitle'),
              textAlign: TextAlign.center,
              style: GoogleFonts.newsreader(
                color: AppColors.primaryPink,
                fontSize: 30,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _PermissionPanel extends StatelessWidget {
  const _PermissionPanel({
    required this.isPermanentlyDenied,
    required this.onOpenSettings,
    required this.onRetry,
  });

  final bool isPermanentlyDenied;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_camera_rounded,
              color: AppColors.tertiaryGold,
              size: 42,
            ),
            const SizedBox(height: 16),
            Text(
              AppTexts.t('cameraPermissionRequired'),
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppTexts.t('cameraPermissionDescription'),
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: AppColors.secondaryLavender.withValues(alpha: 0.86),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            CosmicScanButton(
              text: isPermanentlyDenied
                  ? AppTexts.t('openSettings')
                  : AppTexts.t('grantCameraPermission'),
              icon: isPermanentlyDenied
                  ? Icons.settings_rounded
                  : Icons.photo_camera_rounded,
              onTap: isPermanentlyDenied ? onOpenSettings : onRetry,
            ),
            if (isPermanentlyDenied) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: onRetry,
                child: Text(AppTexts.t('tryAgain')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.title,
    required this.description,
    required this.onRetry,
  });

  final String title;
  final String description;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GlassPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_fix_off_rounded,
              color: AppColors.primaryPink,
              size: 42,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: AppColors.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: AppColors.secondaryLavender.withValues(alpha: 0.86),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            CosmicScanButton(
              text: AppTexts.t('tryAgain'),
              icon: Icons.refresh_rounded,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _PalmScannerBackground extends StatelessWidget {
  const _PalmScannerBackground();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.background,
              AppColors.cosmicGradientTop,
              AppColors.background,
            ],
          ),
        ),
      ),
    );
  }
}
