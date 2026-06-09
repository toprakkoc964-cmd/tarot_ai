import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/app_texts.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/function_error_codes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_compression_helper.dart';
import '../../../core/utils/palm_detection_result.dart';
import '../services/i_palmistry_service.dart';
import '../services/palmistry_analysis_exception.dart';
import '../services/palm_vision_channel.dart';
import '../widgets/cosmic_scan_button.dart';
import '../widgets/glass_panel.dart';
import '../widgets/palm_overlay_painter.dart';
import '../widgets/scanner_laser_painter.dart';
import 'palmistry_result_screen.dart';

enum _PalmLivenessPhase {
  idle,
  detecting,
  palmLocked,
  livenessChallenge,
  verified,
}

class PalmScannerScreen extends StatefulWidget {
  const PalmScannerScreen({super.key});

  static const String heroTag = 'palmistry-scan-hero';

  @override
  State<PalmScannerScreen> createState() => _PalmScannerScreenState();
}

class _PalmScannerScreenState extends State<PalmScannerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _scanAnimation;

  final PalmVisionChannel _visionChannel = PalmVisionChannel();
  CameraController? _controller;
  File? _frozenImage;
  PalmDetectionResult _detectionResult = const PalmDetectionResult.noHand();
  _PalmLivenessPhase _livenessPhase = _PalmLivenessPhase.idle;

  bool _isInitializing = true;
  bool _isPermissionDenied = false;
  bool _isPermissionPermanentlyDenied = false;
  bool _isScanning = false;
  bool _isProcessingFrame = false;
  bool _isImageStreamActive = false;
  int _stableValidFrameCount = 0;
  bool _challengeSawClosed = false;
  Timer? _challengeTimer;
  DateTime? _lastFrameAnalysisAt;
  Size? _lastPreviewSurfaceSize;
  Rect? _lastGuideRect;
  String? _livenessStatusOverride;
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
    _challengeTimer?.cancel();
    _scanAnimation.dispose();
    unawaited(_disposeCamera());
    super.dispose();
  }

  bool get _canTapScan {
    final controller = _controller;
    if (_isScanning || controller == null || !controller.value.isInitialized) {
      return false;
    }
    return !Platform.isIOS || _livenessPhase == _PalmLivenessPhase.verified;
  }

  bool get _canStartPalmDetection {
    final controller = _controller;
    return Platform.isIOS &&
        !_isScanning &&
        controller != null &&
        controller.value.isInitialized &&
        (_livenessPhase == _PalmLivenessPhase.idle ||
            _livenessPhase == _PalmLivenessPhase.detecting);
  }

  bool get _canConfirmLiveness {
    final controller = _controller;
    return Platform.isIOS &&
        !_isScanning &&
        controller != null &&
        controller.value.isInitialized &&
        _livenessPhase == _PalmLivenessPhase.palmLocked;
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return;
    setState(() {
      _isInitializing = true;
      _isPermissionDenied = false;
      _isPermissionPermanentlyDenied = false;
      _errorTitle = null;
      _errorMessage = null;
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
      await controller.setFlashMode(FlashMode.off);
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      try {
        await controller.setFocusMode(FocusMode.auto);
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitializing = false;
        _livenessPhase = Platform.isIOS
            ? _PalmLivenessPhase.idle
            : _PalmLivenessPhase.verified;
        _detectionResult = Platform.isIOS
            ? const PalmDetectionResult.noHand()
            : const PalmDetectionResult(
                state: PalmDetectionState.validHand,
                scanState: PalmScanState.ready,
                confidence: 1,
                labels: ['manual_android_fallback'],
                source: 'manual',
                handDetected: true,
                possibleHand: true,
                validPalm: true,
                openPalmScore: 1,
                extendedFingerCount: 5,
                fingerSpreadRatio: 1,
              );
      });
    } on CameraException catch (e) {
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _errorTitle = AppTexts.t('palmScanErrorTitle');
        _errorMessage = AppTexts.t('palmScanErrorDescription');
      });
    }
  }

  String _mapScanError(Object error) {
    if (error is PalmistryAnalysisException) {
      switch (error.code) {
        case 'NOT_A_PALM':
          return AppTexts.t('palmErrorNotPalm');
        case 'IMAGE_UNREADABLE':
        case 'PALM_PARTIAL':
        case 'PALM_IMAGE_TOO_SMALL':
          return AppTexts.t('palmErrorUnreadable');
        case 'PALM_IMAGE_TOO_LARGE':
        case 'INVALID_PALM_IMAGE_INPUT':
          return AppTexts.t('palmErrorInvalidImage');
        case 'AUTH_REQUIRED':
        case 'unauthenticated':
          return AppTexts.t('palmErrorAuth');
        case 'GEMINI_API_KEY_MISSING':
          return AppTexts.t('palmErrorServerConfig');
        case FunctionErrorCodes.rateLimited:
          return AppTexts.t('readingRateLimited');
        default:
          return AppTexts.t('palmScanErrorDescription');
      }
    }
    if (error is FirebaseFunctionsException) {
      final code = (error.message ?? error.code).trim();
      return _mapScanError(PalmistryAnalysisException(code));
    }
    return AppTexts.t('palmScanErrorDescription');
  }

  Future<void> _startScan() async {
    final controller = _controller;
    if (!_canTapScan || controller == null) return;

    if (!mounted) return;
    setState(() {
      _isScanning = true;
      _errorTitle = null;
      _errorMessage = null;
    });

    try {
      await _stopImageStreamIfNeeded();
      await controller.setFlashMode(FlashMode.off);
      final picture = await controller.takePicture();
      final imageFile = File(picture.path);

      if (!mounted) return;
      setState(() => _frozenImage = imageFile);
      _scanAnimation.repeat();

      final compressed = await compressPalmImage(imageFile);
      final result = await getIt<IPalmistryService>().analyzePalm(
        compressed,
        preValidated: Platform.isIOS && _detectionResult.isValid,
      );

      if (!mounted) return;
      _scanAnimation.stop();
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
        ),
      );
    } catch (error) {
      _scanAnimation.stop();
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _frozenImage = null;
        _stableValidFrameCount = 0;
        _livenessPhase = Platform.isIOS
            ? _PalmLivenessPhase.idle
            : _PalmLivenessPhase.verified;
        _errorTitle = AppTexts.t('palmScanErrorTitle');
        _errorMessage = _mapScanError(error);
      });
    }
  }

  Future<void> _startImageStreamIfNeeded(CameraController controller) async {
    if (!Platform.isIOS ||
        _isImageStreamActive ||
        _isScanning ||
        _livenessPhase == _PalmLivenessPhase.idle ||
        _livenessPhase == _PalmLivenessPhase.verified) {
      return;
    }
    if (!controller.value.isInitialized) return;
    try {
      await controller.startImageStream(_handleCameraImage);
      _isImageStreamActive = true;
    } catch (_) {
      _isImageStreamActive = false;
    }
  }

  Future<void> _stopImageStreamIfNeeded() async {
    final controller = _controller;
    if (!_isImageStreamActive || controller == null) return;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {
    } finally {
      _isImageStreamActive = false;
      _isProcessingFrame = false;
    }
  }

  Future<void> _startPalmDetection() async {
    final controller = _controller;
    if (!_canStartPalmDetection || controller == null) return;
    _challengeTimer?.cancel();
    setState(() {
      _livenessPhase = _PalmLivenessPhase.detecting;
      _stableValidFrameCount = 0;
      _challengeSawClosed = false;
      _livenessStatusOverride = null;
      _errorTitle = null;
      _errorMessage = null;
      _detectionResult = const PalmDetectionResult.noHand();
    });
    await _startImageStreamIfNeeded(controller);
  }

  void _startLivenessChallenge() {
    if (!_canConfirmLiveness) return;
    _challengeTimer?.cancel();
    setState(() {
      _livenessPhase = _PalmLivenessPhase.livenessChallenge;
      _challengeSawClosed = false;
      _livenessStatusOverride = null;
    });
    _challengeTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || _livenessPhase != _PalmLivenessPhase.livenessChallenge) {
        return;
      }
      HapticFeedback.selectionClick();
      setState(() {
        _livenessPhase = _PalmLivenessPhase.detecting;
        _stableValidFrameCount = 0;
        _challengeSawClosed = false;
        _livenessStatusOverride = AppTexts.t('palmLivenessTimeout');
      });
    });
  }

  Future<void> _completeLivenessChallenge() async {
    if (!mounted || _isScanning) return;
    _challengeTimer?.cancel();
    setState(() {
      _livenessPhase = _PalmLivenessPhase.verified;
      _livenessStatusOverride = null;
    });
    HapticFeedback.mediumImpact();
    await _stopImageStreamIfNeeded();
    if (!mounted) return;
    await _startScan();
  }

  void _handleCameraImage(CameraImage image) {
    if (!mounted || _isScanning || _isProcessingFrame) return;
    if (_livenessPhase == _PalmLivenessPhase.idle ||
        _livenessPhase == _PalmLivenessPhase.verified) {
      return;
    }

    final now = DateTime.now();
    final last = _lastFrameAnalysisAt;
    if (last != null && now.difference(last).inMilliseconds < 280) {
      return;
    }
    _lastFrameAnalysisAt = now;
    _isProcessingFrame = true;

    final controller = _controller;
    final previewSize = _lastPreviewSurfaceSize;
    final guideRect = _lastGuideRect;
    if (controller == null || previewSize == null || guideRect == null) {
      _isProcessingFrame = false;
      return;
    }
    unawaited(
      _visionChannel
          .analyzeFrame(
            image,
            sensorOrientation: controller.description.sensorOrientation,
            previewSize: previewSize,
            guideRect: guideRect,
            debugMode: kDebugMode,
          )
          .then(_handleDetectionResult)
          .catchError((_) {
            if (!mounted) return;
            _handleDetectionResult(const PalmDetectionResult.noHand());
          })
          .whenComplete(() {
            _isProcessingFrame = false;
          }),
    );
  }

  void _handleDetectionResult(PalmDetectionResult result) {
    if (!mounted || _isScanning) return;
    _logPalmVisionResult(result);

    final phase = _livenessPhase;
    var nextPhase = phase;
    var nextStableCount = _stableValidFrameCount;
    var nextSawClosed = _challengeSawClosed;
    var shouldVerify = false;

    if (phase == _PalmLivenessPhase.detecting) {
      final score = result.openPalmScore > 0
          ? result.openPalmScore
          : result.confidence;
      final stableOpenPalm = result.handDetected && score >= 0.70;
      nextStableCount = stableOpenPalm ? nextStableCount + 1 : 0;
      if (nextStableCount >= 3) {
        nextPhase = _PalmLivenessPhase.palmLocked;
      }
    } else if (phase == _PalmLivenessPhase.palmLocked) {
      nextStableCount = result.handDetected ? nextStableCount : 0;
      if (!result.handDetected || result.confidence < 0.45) {
        nextPhase = _PalmLivenessPhase.detecting;
      }
    } else if (phase == _PalmLivenessPhase.livenessChallenge) {
      final closed =
          result.extendedFingerCount <= 1 || result.fingerSpreadRatio < 0.30;
      final opened =
          result.extendedFingerCount >= 4 || result.fingerSpreadRatio > 0.55;
      if (closed) nextSawClosed = true;
      if (nextSawClosed && opened) {
        shouldVerify = true;
      }
    }

    final becameLocked =
        _livenessPhase != _PalmLivenessPhase.palmLocked &&
        nextPhase == _PalmLivenessPhase.palmLocked;

    setState(() {
      _detectionResult = result;
      _stableValidFrameCount = nextStableCount;
      _challengeSawClosed = nextSawClosed;
      _livenessPhase = nextPhase;
      if (phase == _PalmLivenessPhase.detecting && result.handDetected) {
        _livenessStatusOverride = null;
      }
    });

    if (becameLocked) {
      HapticFeedback.lightImpact();
    }

    if (shouldVerify) {
      unawaited(_completeLivenessChallenge());
    }
  }

  void _logPalmVisionResult(PalmDetectionResult result) {
    if (!kDebugMode || !Platform.isIOS) return;
    dev.log(
      '[palmvision] screen state=${result.state.name} '
      'scan=${result.effectiveScanState.name} '
      'conf=${result.confidence.toStringAsFixed(2)} '
      'valid=${result.validPalm} labels=${result.labels} '
      'source=${result.source} phase=${_livenessPhase.name} '
      'stable=$_stableValidFrameCount extended=${result.extendedFingerCount} '
      'spread=${result.fingerSpreadRatio.toStringAsFixed(2)}',
      name: 'palmvision',
    );
    final debug = result.debug;
    if (debug != null) {
      dev.log('[palmvision] screen debug=$debug', name: 'palmvision');
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await _stopImageStreamIfNeeded();
      _challengeTimer?.cancel();
      await controller.dispose();
    } catch (_) {
    } finally {
      _controller = null;
    }
  }

  String _instructionForScanState(PalmScanState state) {
    return switch (state) {
      PalmScanState.noHand => AppTexts.t('palmShowHand'),
      PalmScanState.handOutsideGuide => AppTexts.t('palmPlaceInsideGuide'),
      PalmScanState.handTooClose => AppTexts.t('palmMoveHandAway'),
      PalmScanState.handTooFar => AppTexts.t('palmMoveHandCloser'),
      PalmScanState.rotateHand => AppTexts.t('palmKeepHandVertical'),
      PalmScanState.openFingers => AppTexts.t('palmOpenFingers'),
      PalmScanState.showPalm => AppTexts.t('palmShowPalm'),
      PalmScanState.unstable => AppTexts.t('palmHoldSteady'),
      PalmScanState.ready => AppTexts.t('palmDetected'),
    };
  }

  String _helperText() {
    if (_isScanning) return AppTexts.t('palmScanningLoading');
    if (!Platform.isIOS) return AppTexts.t('palmReadyToScan');
    final override = _livenessStatusOverride;
    if (override != null) return override;
    return switch (_livenessPhase) {
      _PalmLivenessPhase.idle => AppTexts.t('palmReadyToScan'),
      _PalmLivenessPhase.detecting => _instructionForScanState(
        _detectionResult.effectiveScanState,
      ),
      _PalmLivenessPhase.palmLocked => AppTexts.t('palmLivenessReady'),
      _PalmLivenessPhase.livenessChallenge => AppTexts.t(
        'palmLivenessInstruction',
      ),
      _PalmLivenessPhase.verified => AppTexts.t('palmDetected'),
    };
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
        onOpenSettings: openAppSettings,
        onRetry: _initializeCamera,
      );
    }

    final controller = _controller;
    if (_errorMessage != null &&
        (controller == null || !controller.value.isInitialized)) {
      return _ErrorPanel(
        title: _errorTitle ?? AppTexts.t('palmScanErrorTitle'),
        description: _errorMessage ?? AppTexts.t('palmScanErrorDescription'),
        onRetry: _initializeCamera,
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return _ErrorPanel(
        title: AppTexts.t('palmScanErrorTitle'),
        description: AppTexts.t('palmScanErrorDescription'),
        onRetry: _initializeCamera,
      );
    }

    final overlayState = _isScanning
        ? PalmDetectionState.validHand
        : _detectionResult.state;
    final helperText = _helperText();

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final surfaceSize = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              _lastPreviewSurfaceSize = surfaceSize;
              _lastGuideRect = PalmOverlayPainter.guideRectForSize(surfaceSize);

              return Hero(
                tag: PalmScannerScreen.heroTag,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(34),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _CameraSurface(
                        controller: controller,
                        frozenImage: _frozenImage,
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
                      CustomPaint(
                        painter: PalmOverlayPainter(
                          detectionState: overlayState,
                          readinessProgress: _isScanning
                              ? 1
                              : _detectionResult.confidence
                                    .clamp(0.0, 1.0)
                                    .toDouble(),
                          pulseValue:
                              _detectionResult.state ==
                                  PalmDetectionState.possibleHand
                              ? 0.6
                              : 0,
                        ),
                      ),
                      if (_isScanning)
                        AnimatedBuilder(
                          animation: _scanAnimation,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: ScannerLaserPainter(
                                progress: _scanAnimation.value,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
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
                  color:
                      _canTapScan ||
                          _canConfirmLiveness ||
                          _livenessPhase == _PalmLivenessPhase.palmLocked ||
                          _isScanning
                      ? AppColors.primaryPink
                      : AppColors.secondaryLavender,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 14),
              if (Platform.isIOS) ...[
                CosmicScanButton(
                  text: AppTexts.t('palmLivenessStart'),
                  icon: Icons.front_hand_rounded,
                  enabled: _canStartPalmDetection,
                  isLoading: _isScanning,
                  onTap: _startPalmDetection,
                ),
                const SizedBox(height: 10),
                CosmicScanButton(
                  text: AppTexts.t('palmLivenessConfirm'),
                  icon: Icons.back_hand_rounded,
                  enabled: _canConfirmLiveness,
                  isLoading: _isScanning,
                  onTap: _startLivenessChallenge,
                ),
              ] else
                CosmicScanButton(
                  text: AppTexts.t('palmTapToScan'),
                  icon: Icons.front_hand_rounded,
                  enabled: _canTapScan,
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
        if (_errorMessage != null && !_isScanning) ...[
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
}

class _CameraSurface extends StatelessWidget {
  const _CameraSurface({required this.controller, required this.frozenImage});

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
  final Future<bool> Function() onOpenSettings;
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
              onTap: isPermanentlyDenied ? () => onOpenSettings() : onRetry,
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
