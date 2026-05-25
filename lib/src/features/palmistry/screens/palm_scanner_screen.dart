import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const Duration _frameAnalysisInterval = Duration(milliseconds: 650);
  static const int _stablePalmTarget = 3;
  static const int _detectionHistoryLimit = 5;

  final PalmFrameAnalyzer _frameAnalyzer = PalmFrameAnalyzer();
  final List<PalmDetectionResult> _detectionHistory = <PalmDetectionResult>[];
  late final AnimationController _scanAnimation;

  CameraController? _controller;
  CameraDescription? _camera;
  DateTime _lastFrameAnalysis = DateTime.fromMillisecondsSinceEpoch(0);
  File? _frozenImage;

  bool _isInitializing = true;
  bool _isPermissionDenied = false;
  bool _isPermissionPermanentlyDenied = false;
  bool _isProcessingFrame = false;
  bool _isHandDetected = false;
  bool _isScanning = false;
  int _stablePalmScore = 0;
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
        ResolutionPreset.high,
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
    if (_isScanning || _isProcessingFrame || !mounted) return;

    final now = DateTime.now();
    if (now.difference(_lastFrameAnalysis) < _frameAnalysisInterval) {
      return;
    }
    _lastFrameAnalysis = now;
    _isProcessingFrame = true;

    final result = await _frameAnalyzer.analyze(
      image: image,
      camera: camera,
      deviceOrientation: controller.value.deviceOrientation,
    );

    if (!mounted) {
      _isProcessingFrame = false;
      return;
    }

    final wasReady = _isHandDetected;
    setState(() => _applyDetectionResult(result));
    if (!wasReady && _isHandDetected) {
      await HapticFeedback.mediumImpact();
    }
    _isProcessingFrame = false;
  }

  void _resetDetectionState() {
    _detectionHistory.clear();
    _detectionResult = const PalmDetectionResult.noHand();
    _stablePalmScore = 0;
    _isHandDetected = false;
  }

  void _applyDetectionResult(PalmDetectionResult result) {
    _detectionResult = result;
    _detectionHistory.add(result);
    if (_detectionHistory.length > _detectionHistoryLimit) {
      _detectionHistory.removeAt(0);
    }

    switch (result.state) {
      case PalmDetectionState.validHand:
        _stablePalmScore = math.min(_stablePalmTarget, _stablePalmScore + 1);
        break;
      case PalmDetectionState.possibleHand:
        // Keep the accumulated score so one softer frame does not flicker.
        break;
      case PalmDetectionState.partialHand:
        _stablePalmScore = math.max(0, _stablePalmScore - 1);
        break;
      case PalmDetectionState.noHand:
        _stablePalmScore = 0;
        break;
    }

    final validFrameCount =
        _detectionHistory.where((item) => item.isValid).length;
    _isHandDetected =
        _stablePalmScore >= _stablePalmTarget && validFrameCount >= 2;
  }

  Future<void> _startScan() async {
    final controller = _controller;
    if (!_isHandDetected ||
        _isScanning ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    await HapticFeedback.mediumImpact();
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
    final overlayState = _isHandDetected || _isScanning
        ? PalmDetectionState.validHand
        : _detectionResult.state;
    final detectionProgress = _isScanning ? 1.0 : _detectionProgress;

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
                        readinessProgress: detectionProgress,
                      ),
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
                  color: _isHandDetected || _isScanning
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
                enabled: _isHandDetected,
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
    if (_isHandDetected) return AppTexts.t('palmDetected');

    switch (_detectionResult.state) {
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
    switch (_detectionResult.state) {
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
    return (_stablePalmScore / _stablePalmTarget).clamp(0, 1).toDouble();
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
