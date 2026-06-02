class CoffeeImageSourceEvidence {
  const CoffeeImageSourceEvidence({
    required this.originalWidth,
    required this.originalHeight,
    required this.originalAspectRatio,
    required this.hasExifMetadata,
    required this.fromGallery,
  });

  final int originalWidth;
  final int originalHeight;
  final double originalAspectRatio;
  final bool hasExifMetadata;
  final bool fromGallery;

  Map<String, dynamic> toMap() {
    return {
      'originalWidth': originalWidth,
      'originalHeight': originalHeight,
      'originalAspectRatio': originalAspectRatio,
      'hasExifMetadata': hasExifMetadata,
      'fromGallery': fromGallery,
    };
  }
}
