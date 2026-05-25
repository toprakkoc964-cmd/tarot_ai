enum PalmistryStorageMode {
  none,
  temporary,
  premiumOnly,
}

class PalmistryStorageConfig {
  const PalmistryStorageConfig._();

  static const PalmistryStorageMode mode = PalmistryStorageMode.temporary;
}
