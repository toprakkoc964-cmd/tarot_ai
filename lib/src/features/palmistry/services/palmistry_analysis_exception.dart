class PalmistryAnalysisException implements Exception {
  const PalmistryAnalysisException(this.code);

  final String code;

  @override
  String toString() => 'PalmistryAnalysisException($code)';
}
