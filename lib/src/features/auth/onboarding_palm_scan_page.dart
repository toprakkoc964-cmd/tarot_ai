import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/app_texts.dart';
import '../../core/diagnostics/camera_diagnostics.dart';
import 'onboarding_card_pick_page.dart';

class OnboardingPalmScanPage extends StatefulWidget {
  const OnboardingPalmScanPage({
    super.key,
    required this.name,
    required this.onPalmCaptured,
    required this.onModalitySwitch,
    this.onBack,
  });

  final String name;
  final void Function(String palmTeaserKey) onPalmCaptured;
  final void Function(OnboardingModality newModality) onModalitySwitch;
  final VoidCallback? onBack;

  @override
  State<OnboardingPalmScanPage> createState() => _OnboardingPalmScanPageState();
}

enum _PalmOnboardingPhase {
  intro,
  permissionDenied,
  camera,
  scanning,
  confirm,
  fallback,
}

class _OnboardingPalmScanPageState extends State<OnboardingPalmScanPage>
    with TickerProviderStateMixin {
  static const _bg = Color(0xFF17081C);
  static const _surface = Color(0xFF1E0C25);
  static const _surfaceHigh = Color(0xFF361A41);
  static const _primary = Color(0xFFFF5ED6);
  static const _primaryDeep = Color(0xFFFF00D4);
  static const _secondary = Color(0xFFCDBDFF);
  static const _onSurface = Color(0xFFFADCFF);
  static const _gold = Color(0xFFFFE792);
  static const _ctaText = Color(0xFF430036);

  static const _teaserKeys = [
    'palm_heart',
    'palm_head',
    'palm_life',
    'palm_fate',
  ];

  final math.Random _random = math.Random();
  late final AnimationController _introController;
  late final AnimationController _scanController;
  late final AnimationController _glowController;

  _PalmOnboardingPhase _phase = _PalmOnboardingPhase.intro;
  CameraController? _cameraController;
  Future<void>? _cameraInitFuture;
  String? _palmTeaserKey;
  bool _busy = false;

  List<OnboardingModality> _fallbackModalities = const [
    OnboardingModality.tarot,
    OnboardingModality.coffee,
  ];
  int? _fallbackPickedIndex;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _disposeCamera();
    _introController.dispose();
    _scanController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    if (_busy) return;
    setState(() => _busy = true);
    unawaited(
      CameraDiagnostics.log(
        'permission_request_start',
        flow: 'onboarding_palm',
        data: {'platform': Platform.operatingSystem},
      ),
    );
    try {
      if (!Platform.isIOS) {
        unawaited(
          CameraDiagnostics.log(
            'permission_skipped_non_ios',
            flow: 'onboarding_palm',
          ),
        );
        _showFallback();
        return;
      }
      final status = await Permission.camera.request();
      unawaited(
        CameraDiagnostics.log(
          'permission_request_done',
          flow: 'onboarding_palm',
          data: {'status': status.name},
        ),
      );
      if (!mounted) return;
      if (status.isGranted || status.isLimited) {
        await _startCamera();
      } else {
        _showPermissionDenied();
      }
    } catch (error, stackTrace) {
      unawaited(
        CameraDiagnostics.log(
          'permission_request_error',
          flow: 'onboarding_palm',
          error: error,
          stackTrace: stackTrace,
        ),
      );
      if (mounted) _showPermissionDenied();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showPermissionDenied() {
    _disposeCamera();
    setState(() => _phase = _PalmOnboardingPhase.permissionDenied);
  }

  Future<void> _openCameraSettings() async {
    await openAppSettings();
  }

  Future<void> _startCamera() async {
    try {
      await CameraDiagnostics.log(
        'available_cameras_start',
        flow: 'onboarding_palm',
      );
      final cameras = await availableCameras();
      await CameraDiagnostics.log(
        'available_cameras_done',
        flow: 'onboarding_palm',
        data: CameraDiagnostics.describeCameras(cameras),
      );
      if (cameras.isEmpty) {
        await CameraDiagnostics.log(
          'available_cameras_empty',
          flow: 'onboarding_palm',
        );
        _showFallback();
        return;
      }
      final camera = cameras.firstWhere(
        (candidate) => candidate.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      await CameraDiagnostics.log(
        'camera_selected',
        flow: 'onboarding_palm',
        data: CameraDiagnostics.describeCamera(camera),
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _cameraController = controller;
      await CameraDiagnostics.log(
        'initialize_future_created',
        flow: 'onboarding_palm',
        data: CameraDiagnostics.describeController(controller),
      );
      _cameraInitFuture = controller
          .initialize()
          .then((_) async {
            await controller.setFlashMode(FlashMode.off);
            await CameraDiagnostics.log(
              'initialize_done',
              flow: 'onboarding_palm',
              data: CameraDiagnostics.describeController(controller),
            );
          })
          .catchError((Object error, StackTrace stackTrace) {
            CameraDiagnostics.logSync(
              'initialize_error',
              flow: 'onboarding_palm',
              data: CameraDiagnostics.describeController(controller),
              error: error,
              stackTrace: stackTrace,
            );
            Error.throwWithStackTrace(error, stackTrace);
          });
      setState(() => _phase = _PalmOnboardingPhase.camera);
    } catch (error, stackTrace) {
      await CameraDiagnostics.log(
        'start_camera_error',
        flow: 'onboarding_palm',
        error: error,
        stackTrace: stackTrace,
      );
      _showFallback();
    }
  }

  Future<void> _capturePalm() async {
    if (_busy) return;
    final controller = _cameraController;
    if (controller == null) {
      _showFallback();
      return;
    }
    setState(() {
      _busy = true;
      _phase = _PalmOnboardingPhase.scanning;
    });
    try {
      await CameraDiagnostics.log(
        'take_picture_prepare',
        flow: 'onboarding_palm',
        data: CameraDiagnostics.describeController(controller),
      );
      await _cameraInitFuture;
      await CameraDiagnostics.log(
        'take_picture_start',
        flow: 'onboarding_palm',
        data: CameraDiagnostics.describeController(controller),
      );
      final photo = await controller.takePicture();
      await CameraDiagnostics.log(
        'take_picture_done',
        flow: 'onboarding_palm',
        data: {
          'path': photo.path,
          ...CameraDiagnostics.describeController(controller),
        },
      );
      unawaited(_deleteTempPhoto(photo.path));
      _palmTeaserKey = _teaserKeys[_random.nextInt(_teaserKeys.length)];
      await _disposeCamera();
      await _scanController.forward(from: 0);
      if (!mounted) return;
      setState(() => _phase = _PalmOnboardingPhase.confirm);
    } catch (error, stackTrace) {
      unawaited(
        CameraDiagnostics.log(
          'take_picture_error',
          flow: 'onboarding_palm',
          data: CameraDiagnostics.describeController(controller),
          error: error,
          stackTrace: stackTrace,
        ),
      );
      if (mounted) _showFallback();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteTempPhoto(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Onboarding capture is process-and-discard; deletion failures are ignored.
    }
  }

  Future<void> _disposeCamera() async {
    final controller = _cameraController;
    _cameraController = null;
    _cameraInitFuture = null;
    if (controller == null) return;
    await CameraDiagnostics.log(
      'dispose_start',
      flow: 'onboarding_palm',
      data: CameraDiagnostics.describeController(controller),
    );
    try {
      await controller.dispose();
      await CameraDiagnostics.log('dispose_done', flow: 'onboarding_palm');
    } catch (error, stackTrace) {
      await CameraDiagnostics.log(
        'dispose_error',
        flow: 'onboarding_palm',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _showFallback() {
    _disposeCamera();
    _fallbackModalities = [OnboardingModality.tarot, OnboardingModality.coffee]
      ..shuffle(_random);
    setState(() {
      _phase = _PalmOnboardingPhase.fallback;
      _fallbackPickedIndex = null;
    });
  }

  Future<void> _pickFallback(int index) async {
    if (_fallbackPickedIndex != null) return;
    setState(() => _fallbackPickedIndex = index);
    await Future<void>.delayed(const Duration(milliseconds: 950));
    if (!mounted) return;
    widget.onModalitySwitch(_fallbackModalities[index]);
  }

  void _continue() {
    widget.onPalmCaptured(_palmTeaserKey ?? _teaserKeys.first);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _PalmBackground()),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                10,
                22,
                math.max(18, bottom + 8),
              ),
              child: Column(
                children: [
                  _topBar(),
                  Expanded(child: _body()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        IconButton(
          onPressed: _busy ? null : widget.onBack,
          icon: const Icon(
            Icons.chevron_left_rounded,
            color: _secondary,
            size: 34,
          ),
        ),
        const Spacer(),
        _MadamAvatar(size: 44),
      ],
    );
  }

  Widget _body() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 360),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: switch (_phase) {
        _PalmOnboardingPhase.intro => _intro(),
        _PalmOnboardingPhase.permissionDenied => _permissionDenied(),
        _PalmOnboardingPhase.camera => _camera(),
        _PalmOnboardingPhase.scanning => _scanning(),
        _PalmOnboardingPhase.confirm => _confirm(),
        _PalmOnboardingPhase.fallback => _fallback(),
      },
    );
  }

  Widget _intro() {
    return _IntroFade(
      controller: _introController,
      child: Column(
        key: const ValueKey('intro'),
        children: [
          const Spacer(),
          _MadamAvatar(size: 94),
          const SizedBox(height: 22),
          _TitleBlock(
            title: AppTexts.t('onboarding.palm.title'),
            subtitle: AppTexts.t('onboarding.palm.subtitle'),
          ),
          const SizedBox(height: 24),
          _WhyBox(),
          const Spacer(),
          _PrimaryButton(
            label: _busy
                ? AppTexts.t('onboarding.palm.permission_loading')
                : AppTexts.t('onboarding.palm.permission_cta'),
            onTap: _busy ? null : _requestPermission,
          ),
        ],
      ),
    );
  }

  Widget _camera() {
    final controller = _cameraController;
    return Column(
      key: const ValueKey('camera'),
      children: [
        const SizedBox(height: 10),
        _TitleBlock(
          title: AppTexts.t('onboarding.palm.camera_title'),
          subtitle: AppTexts.t('onboarding.palm.camera_hint'),
          titleSize: 34,
        ),
        const SizedBox(height: 22),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: _surfaceHigh.withValues(alpha: 0.32),
                border: Border.all(color: _primary.withValues(alpha: 0.42)),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (controller != null)
                    FutureBuilder<void>(
                      future: _cameraInitFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(color: _primary),
                          );
                        }
                        if (snapshot.hasError) {
                          unawaited(
                            CameraDiagnostics.log(
                              'preview_future_error_visible',
                              flow: 'onboarding_palm',
                              data: CameraDiagnostics.describeController(
                                controller,
                              ),
                              error: snapshot.error,
                              stackTrace: snapshot.stackTrace,
                            ),
                          );
                          return _CameraErrorCard(onFallback: _showFallback);
                        }
                        return CameraPreview(controller);
                      },
                    )
                  else
                    const ColoredBox(color: _surface),
                  const _PalmFrameOverlay(),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: _GlassLabel(
                        text: AppTexts.t('onboarding.palm.frame_hint'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: _busy ? null : _capturePalm,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primary,
              border: Border.all(color: _gold, width: 3),
              boxShadow: [
                BoxShadow(
                  color: _primaryDeep.withValues(alpha: 0.38),
                  blurRadius: 28,
                ),
              ],
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: _ctaText,
              size: 30,
            ),
          ),
        ),
      ],
    );
  }

  Widget _permissionDenied() {
    return Column(
      key: const ValueKey('permissionDenied'),
      children: [
        const Spacer(),
        _MadamAvatar(size: 94),
        const SizedBox(height: 22),
        _TitleBlock(
          title: AppTexts.t('onboarding.palm.permission_denied_title'),
          subtitle: AppTexts.t('onboarding.palm.permission_denied_body'),
          titleSize: 38,
        ),
        const SizedBox(height: 24),
        _WhyBox(),
        const Spacer(),
        _PrimaryButton(
          label: AppTexts.t('onboarding.palm.permission_retry'),
          onTap: _requestPermission,
        ),
        const SizedBox(height: 12),
        _SecondaryButton(
          label: AppTexts.t('onboarding.palm.permission_settings'),
          onTap: _openCameraSettings,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _showFallback,
          child: Text(
            AppTexts.t('onboarding.palm.permission_fallback'),
            style: GoogleFonts.spaceGrotesk(
              color: _secondary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _scanning() {
    return Center(
      key: const ValueKey('scanning'),
      child: AnimatedBuilder(
        animation: _scanController,
        builder: (context, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 190,
                height: 230,
                child: CustomPaint(
                  painter: _PalmScanPainter(_scanController.value),
                ),
              ),
              const SizedBox(height: 26),
              Text(
                AppTexts.t('onboarding.palm.scanning'),
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  color: _onSurface,
                  fontSize: 30,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _confirm() {
    return Column(
      key: const ValueKey('confirm'),
      children: [
        const Spacer(),
        _MadamAvatar(size: 96),
        const SizedBox(height: 22),
        _TitleBlock(
          title: AppTexts.t('onboarding.palm.confirm_title'),
          subtitle: _confirmationText(),
          titleSize: 38,
          subtitleStyle: GoogleFonts.newsreader(
            color: _onSurface.withValues(alpha: 0.94),
            fontSize: 24,
            height: 1.18,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        _PrimaryButton(
          label: AppTexts.t('onboarding.palm.cta'),
          onTap: _continue,
        ),
      ],
    );
  }

  Widget _fallback() {
    return Column(
      key: const ValueKey('fallback'),
      children: [
        const Spacer(),
        _TitleBlock(
          title: AppTexts.t('onboarding.palm.fallback_title'),
          subtitle: AppTexts.t('onboarding.palm.fallback_subtitle'),
          titleSize: 38,
        ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _FallbackCard(
              modality: _fallbackModalities[0],
              picked: _fallbackPickedIndex == 0,
              dimmed: _fallbackPickedIndex != null && _fallbackPickedIndex != 0,
              onTap: () => _pickFallback(0),
            ),
            const SizedBox(width: 18),
            _FallbackCard(
              modality: _fallbackModalities[1],
              picked: _fallbackPickedIndex == 1,
              dimmed: _fallbackPickedIndex != null && _fallbackPickedIndex != 1,
              onTap: () => _pickFallback(1),
            ),
          ],
        ),
        const SizedBox(height: 22),
        AnimatedOpacity(
          opacity: _fallbackPickedIndex == null ? 0 : 1,
          duration: const Duration(milliseconds: 240),
          child: Text(
            _fallbackPickedIndex == null
                ? ''
                : AppTexts.t('onboarding.palm.fallback_result').replaceAll(
                    '{modality}',
                    AppTexts.t(
                      _fallbackModalities[_fallbackPickedIndex!] ==
                              OnboardingModality.tarot
                          ? 'onboarding.card_pick.tarot_title'
                          : 'onboarding.card_pick.coffee_title',
                    ),
                  ),
            textAlign: TextAlign.center,
            style: GoogleFonts.newsreader(
              color: _gold,
              fontSize: 22,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  String _confirmationText() {
    final name = widget.name.trim();
    final key = name.isEmpty
        ? 'onboarding.palm.confirm_body_no_name'
        : 'onboarding.palm.confirm_body';
    return AppTexts.t(key).replaceAll('{name}', name);
  }
}

class _CameraErrorCard extends StatelessWidget {
  const _CameraErrorCard({required this.onFallback});

  final VoidCallback onFallback;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _OnboardingPalmPalette.surface.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _OnboardingPalmPalette.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.videocam_off_rounded,
                color: _OnboardingPalmPalette.gold,
                size: 34,
              ),
              const SizedBox(height: 14),
              Text(
                AppTexts.t('cameraUnavailableTitle'),
                textAlign: TextAlign.center,
                style: GoogleFonts.newsreader(
                  color: _OnboardingPalmPalette.onSurface,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppTexts.t('cameraUnavailableDescription'),
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: _OnboardingPalmPalette.secondary.withValues(
                    alpha: 0.88,
                  ),
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              _SecondaryButton(
                label: AppTexts.t('onboarding.palm.permission_fallback'),
                onTap: onFallback,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.title,
    required this.subtitle,
    this.titleSize = 42,
    this.subtitleStyle,
  });

  final String title;
  final String subtitle;
  final double titleSize;
  final TextStyle? subtitleStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.newsreader(
            color: _OnboardingPalmPalette.onSurface,
            fontSize: titleSize,
            height: 1.05,
            fontWeight: FontWeight.w600,
            shadows: [
              Shadow(
                color: _OnboardingPalmPalette.primary.withValues(alpha: 0.20),
                blurRadius: 16,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style:
              subtitleStyle ??
              GoogleFonts.manrope(
                color: _OnboardingPalmPalette.secondary.withValues(alpha: 0.88),
                fontSize: 15.5,
                height: 1.42,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _WhyBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _OnboardingPalmPalette.surface.withValues(alpha: 0.54),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _OnboardingPalmPalette.outline.withValues(alpha: 0.52),
            ),
          ),
          child: Column(
            children: [
              _WhyRow(
                icon: Icons.photo_camera_rounded,
                text: AppTexts.t('onboarding.palm.why_camera'),
              ),
              _WhyRow(
                icon: Icons.lock_outline_rounded,
                text: AppTexts.t('onboarding.palm.why_privacy'),
              ),
              _WhyRow(
                icon: Icons.auto_awesome_rounded,
                text: AppTexts.t('onboarding.palm.why_fallback'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhyRow extends StatelessWidget {
  const _WhyRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: _OnboardingPalmPalette.gold, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                color: _OnboardingPalmPalette.secondary.withValues(alpha: 0.88),
                fontSize: 13.5,
                height: 1.32,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: onTap == null ? 0.56 : 1,
        child: Container(
          height: 58,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(
              colors: [
                _OnboardingPalmPalette.primary,
                _OnboardingPalmPalette.primaryDeep,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _OnboardingPalmPalette.primaryDeep.withValues(
                  alpha: 0.34,
                ),
                blurRadius: 28,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: _OnboardingPalmPalette.ctaText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: _OnboardingPalmPalette.surfaceHigh.withValues(alpha: 0.34),
          border: Border.all(
            color: _OnboardingPalmPalette.secondary.withValues(alpha: 0.42),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            color: _OnboardingPalmPalette.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}

class _MadamAvatar extends StatelessWidget {
  const _MadamAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [_OnboardingPalmPalette.primary, _OnboardingPalmPalette.gold],
        ),
        boxShadow: [
          BoxShadow(
            color: _OnboardingPalmPalette.primary.withValues(alpha: 0.26),
            blurRadius: 26,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/onboarding/madam_aris.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _PalmFrameOverlay extends StatelessWidget {
  const _PalmFrameOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PalmFramePainter());
  }
}

class _PalmFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.46),
      width: size.width * 0.58,
      height: size.height * 0.58,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = _OnboardingPalmPalette.gold.withValues(alpha: 0.78);
    _drawDashedRRect(
      canvas,
      RRect.fromRectAndRadius(rect, const Radius.circular(120)),
      paint,
    );

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = _OnboardingPalmPalette.primary.withValues(alpha: 0.42);
    final palm = Path()
      ..moveTo(rect.left + rect.width * 0.18, rect.top + rect.height * 0.34)
      ..cubicTo(
        rect.left,
        rect.top + rect.height * 0.45,
        rect.left + 12,
        rect.bottom - 18,
        rect.center.dx,
        rect.bottom - 8,
      )
      ..cubicTo(
        rect.right - 12,
        rect.bottom - 18,
        rect.right,
        rect.top + rect.height * 0.45,
        rect.right - rect.width * 0.18,
        rect.top + rect.height * 0.34,
      );
    canvas.drawPath(palm, linePaint);
    for (var i = 0; i < 4; i++) {
      final x = rect.left + rect.width * (0.26 + i * 0.16);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            rect.top + rect.height * 0.08,
            rect.width * 0.10,
            rect.height * (0.30 + (i % 2) * 0.08),
          ),
          const Radius.circular(24),
        ),
        linePaint,
      );
    }
  }

  void _drawDashedRRect(Canvas canvas, RRect rrect, Paint paint) {
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final extract = metric.extractPath(distance, distance + 12);
        canvas.drawPath(extract, paint);
        distance += 22;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GlassLabel extends StatelessWidget {
  const _GlassLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _OnboardingPalmPalette.surface.withValues(alpha: 0.54),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: _OnboardingPalmPalette.gold.withValues(alpha: 0.28),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              color: _OnboardingPalmPalette.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackCard extends StatelessWidget {
  const _FallbackCard({
    required this.modality,
    required this.picked,
    required this.dimmed,
    required this.onTap,
  });

  final OnboardingModality modality;
  final bool picked;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final titleKey = modality == OnboardingModality.tarot
        ? 'onboarding.card_pick.tarot_title'
        : 'onboarding.card_pick.coffee_title';
    final icon = modality == OnboardingModality.tarot
        ? Icons.style_rounded
        : Icons.coffee_rounded;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: picked || dimmed ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 260),
        opacity: dimmed ? 0.32 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 360),
          width: 136,
          height: 206,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _OnboardingPalmPalette.surfaceHigh,
                _OnboardingPalmPalette.bg,
              ],
            ),
            border: Border.all(
              color: _OnboardingPalmPalette.gold.withValues(alpha: 0.84),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _OnboardingPalmPalette.primary.withValues(alpha: 0.28),
                blurRadius: 24,
              ),
            ],
          ),
          child: picked
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: _OnboardingPalmPalette.primary, size: 44),
                    const SizedBox(height: 16),
                    Text(
                      AppTexts.t(titleKey),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.newsreader(
                        color: _OnboardingPalmPalette.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: _OnboardingPalmPalette.gold,
                      size: 40,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Tarot AI',
                      style: GoogleFonts.newsreader(
                        color: _OnboardingPalmPalette.onSurface,
                        fontSize: 22,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PalmScanPainter extends CustomPainter {
  const _PalmScanPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final palmPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = _OnboardingPalmPalette.gold.withValues(alpha: 0.62);
    final palm = Path()
      ..moveTo(size.width * 0.25, size.height * 0.28)
      ..cubicTo(
        size.width * 0.06,
        size.height * 0.44,
        size.width * 0.22,
        size.height * 0.92,
        size.width * 0.50,
        size.height * 0.94,
      )
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.92,
        size.width * 0.94,
        size.height * 0.44,
        size.width * 0.75,
        size.height * 0.28,
      );
    canvas.drawPath(palm, palmPaint);
    for (var i = 0; i < 4; i++) {
      final x = size.width * (0.29 + i * 0.12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            size.height * 0.04,
            size.width * 0.08,
            size.height * (0.36 + (i % 2) * 0.08),
          ),
          const Radius.circular(24),
        ),
        palmPaint,
      );
    }

    final y = lerpDouble(size.height * 0.02, size.height * 0.96, progress)!;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          _OnboardingPalmPalette.gold.withValues(alpha: 0.85),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, y - 16, size.width, 32));
    canvas.drawRect(Rect.fromLTWH(0, y - 16, size.width, 32), scanPaint);
  }

  @override
  bool shouldRepaint(covariant _PalmScanPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _IntroFade extends StatelessWidget {
  const _IntroFade({required this.controller, required this.child});

  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}

class _PalmBackground extends StatelessWidget {
  const _PalmBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.22, -0.82),
          radius: 1.22,
          colors: [Color(0xFF32133B), Color(0xFF17081C), Color(0xFF0D0411)],
          stops: [0, 0.62, 1],
        ),
      ),
      child: CustomPaint(painter: _PalmStarsPainter()),
    );
  }
}

class _PalmStarsPainter extends CustomPainter {
  const _PalmStarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 54; i++) {
      final x = _fract(math.sin(i * 12.9898) * 43758.5453);
      final y = _fract(math.sin(i * 78.233) * 12731.731);
      paint.color =
          (i % 3 == 0
                  ? _OnboardingPalmPalette.gold
                  : i % 3 == 1
                  ? _OnboardingPalmPalette.primary
                  : _OnboardingPalmPalette.secondary)
              .withValues(alpha: i % 5 == 0 ? 0.36 : 0.18);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        i % 6 == 0 ? 1.8 : 1.0,
        paint,
      );
    }
  }

  double _fract(double value) => value - value.floorToDouble();

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OnboardingPalmPalette {
  const _OnboardingPalmPalette._();

  static const bg = Color(0xFF17081C);
  static const surface = Color(0xFF1E0C25);
  static const surfaceHigh = Color(0xFF361A41);
  static const primary = Color(0xFFFF5ED6);
  static const primaryDeep = Color(0xFFFF00D4);
  static const secondary = Color(0xFFCDBDFF);
  static const onSurface = Color(0xFFFADCFF);
  static const gold = Color(0xFFFFE792);
  static const outline = Color(0xFF5B3C66);
  static const ctaText = Color(0xFF430036);
}
