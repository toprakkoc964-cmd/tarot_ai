import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TarotCardView extends StatelessWidget {
  const TarotCardView({
    super.key,
    required this.imageUrl,
    this.borderRadius = const BorderRadius.all(Radius.circular(15)),
  });

  final String imageUrl;
  final BorderRadius borderRadius;

  static const _backgroundColor = Color(0xFF1A0B2E);

  bool get _isNetworkImage =>
      imageUrl.startsWith('http://') || imageUrl.startsWith('https://');

  String get _assetPath {
    final trimmed = imageUrl.trim();
    if (trimmed.startsWith('assets/')) return trimmed;
    if (trimmed.startsWith('card-images/')) {
      return 'assets/$trimmed';
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: const [
            BoxShadow(
              color: Colors.amber,
              blurRadius: 18,
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: _isNetworkImage
              ? _TarotNetworkImage(imageUrl: imageUrl)
              : _TarotAssetImage(assetPath: _assetPath),
        ),
      ),
    );
  }
}

class _TarotAssetImage extends StatefulWidget {
  const _TarotAssetImage({required this.assetPath});

  final String assetPath;

  @override
  State<_TarotAssetImage> createState() => _TarotAssetImageState();
}

class _TarotAssetImageState extends State<_TarotAssetImage> {
  AssetImage? _provider;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolveAsset();
  }

  @override
  void didUpdateWidget(covariant _TarotAssetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _provider = null;
      _failed = false;
      _resolveAsset();
    }
  }

  Future<void> _resolveAsset() async {
    try {
      await rootBundle.load(widget.assetPath);
      if (!mounted) return;
      setState(() => _provider = AssetImage(widget.assetPath));
    } catch (error, stackTrace) {
      debugPrint('Tarot asset missing: ${widget.assetPath} ($error)');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const _TarotCardError();
    final provider = _provider;
    if (provider == null) return const _TarotCardPlaceholder();
    return Image(
      image: provider,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, error, __) {
        debugPrint('Tarot asset decode failed: ${widget.assetPath} ($error)');
        return const _TarotCardError();
      },
    );
  }
}

class _TarotNetworkImage extends StatelessWidget {
  const _TarotNetworkImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 220),
      fadeOutDuration: Duration.zero,
      placeholder: (context, url) => const _TarotCardPlaceholder(),
      errorWidget: (context, url, error) => const _TarotCardError(),
    );
  }
}

class _TarotCardPlaceholder extends StatelessWidget {
  const _TarotCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: TarotCardView._backgroundColor,
      child: Center(
        child: Icon(
          Icons.auto_awesome,
          color: Colors.amber,
          size: 36,
        ),
      ),
    );
  }
}

class _TarotCardError extends StatelessWidget {
  const _TarotCardError();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: TarotCardView._backgroundColor,
      child: Center(
        child: Icon(
          Icons.auto_awesome,
          color: Colors.amber,
          size: 42,
        ),
      ),
    );
  }
}
