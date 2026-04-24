import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class TarotCardView extends StatelessWidget {
  const TarotCardView({
    super.key,
    required this.imageUrl,
    this.borderRadius = const BorderRadius.all(Radius.circular(15)),
  });

  final String imageUrl;
  final BorderRadius borderRadius;

  static const _backgroundColor = Color(0xFF1A0B2E);

  @override
  Widget build(BuildContext context) {
    return Container(
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
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => const _TarotCardPlaceholder(),
          errorWidget: (context, url, error) => const _TarotCardError(),
        ),
      ),
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
        child: CircularProgressIndicator(
          color: Colors.amber,
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
