import 'package:get_it/get_it.dart';

import '../../features/coffee_reading/services/backend_coffee_reading_service.dart';
import '../../features/coffee_reading/services/coffee_backend_service.dart';
import '../../features/coffee_reading/services/coffee_image_pipeline_service.dart';
import '../../features/coffee_reading/services/coffee_image_quality_service.dart';
import '../../features/coffee_reading/services/coffee_image_similarity_service.dart';
import '../../features/coffee_reading/services/coffee_reading_service.dart';
import '../../features/coffee_reading/services/coffee_residue_detection_service.dart';
import '../../features/coffee_reading/services/coffee_screen_spoofing_risk_service.dart';
import '../../features/coffee_reading/services/coffee_screenshot_risk_service.dart';
import '../../features/coffee_reading/services/coffee_temp_file_cleaner.dart';
import '../../features/coffee_reading/services/coffee_validation_service.dart';
import '../../features/coffee_reading/services/mock_coffee_reading_service.dart';
import '../../features/palmistry/services/i_palmistry_service.dart';
import '../../features/palmistry/services/mock_palmistry_service.dart';
import '../../features/shop/services/backend_purchase_verification_service.dart';
import '../../features/shop/services/entitlement_service.dart';
import '../../features/shop/services/purchase_service.dart';
import '../../features/shop/services/shop_config_service.dart';
import '../tarot_functions_client.dart';

final getIt = GetIt.instance;

const _useMockCoffeeReading = bool.fromEnvironment(
  'USE_MOCK_COFFEE_READING',
  defaultValue: false,
);

Future<void> setupServiceLocator() async {
  if (!getIt.isRegistered<IPalmistryService>()) {
    getIt.registerLazySingleton<IPalmistryService>(
      () => MockPalmistryService(),
    );
  }
  if (!getIt.isRegistered<CoffeeTempFileCleaner>()) {
    getIt.registerLazySingleton<CoffeeTempFileCleaner>(
      () => CoffeeTempFileCleaner(),
    );
  }
  if (!getIt.isRegistered<CoffeeImageQualityService>()) {
    getIt.registerLazySingleton<CoffeeImageQualityService>(
      () => CoffeeImageQualityService(),
    );
  }
  if (!getIt.isRegistered<CoffeeResidueDetectionService>()) {
    getIt.registerLazySingleton<CoffeeResidueDetectionService>(
      () => CoffeeResidueDetectionService(),
    );
  }
  if (!getIt.isRegistered<CoffeeImageSimilarityService>()) {
    getIt.registerLazySingleton<CoffeeImageSimilarityService>(
      () => CoffeeImageSimilarityService(),
    );
  }
  if (!getIt.isRegistered<CoffeeScreenshotRiskService>()) {
    getIt.registerLazySingleton<CoffeeScreenshotRiskService>(
      () => CoffeeScreenshotRiskService(),
    );
  }
  if (!getIt.isRegistered<CoffeeScreenSpoofingRiskService>()) {
    getIt.registerLazySingleton<CoffeeScreenSpoofingRiskService>(
      () => CoffeeScreenSpoofingRiskService(),
    );
  }
  if (!getIt.isRegistered<CoffeeValidationService>()) {
    getIt.registerLazySingleton<CoffeeValidationService>(
      () => CoffeeValidationService(),
      dispose: (service) => service.dispose(),
    );
  }
  if (!getIt.isRegistered<CoffeeImagePipelineService>()) {
    getIt.registerLazySingleton<CoffeeImagePipelineService>(
      () => CoffeeImagePipelineService(
        validationService: getIt<CoffeeValidationService>(),
        tempFileCleaner: getIt<CoffeeTempFileCleaner>(),
        similarityService: getIt<CoffeeImageSimilarityService>(),
      ),
    );
  }
  if (!getIt.isRegistered<TarotFunctionsClient>()) {
    getIt.registerLazySingleton<TarotFunctionsClient>(
      () => TarotFunctionsClient(),
    );
  }
  if (!getIt.isRegistered<CoffeeBackendService>()) {
    getIt.registerLazySingleton<CoffeeBackendService>(
      () => CoffeeBackendService(),
    );
  }
  if (!getIt.isRegistered<CoffeeReadingService>()) {
    getIt.registerLazySingleton<CoffeeReadingService>(
      () => _useMockCoffeeReading
          ? MockCoffeeReadingService()
          : BackendCoffeeReadingService(
              functionsClient: getIt<TarotFunctionsClient>(),
              backendService: getIt<CoffeeBackendService>(),
            ),
    );
  }
  if (!getIt.isRegistered<ShopConfigService>()) {
    getIt.registerLazySingleton<ShopConfigService>(
      () => ShopConfigService(),
    );
  }
  if (!getIt.isRegistered<EntitlementService>()) {
    getIt.registerLazySingleton<EntitlementService>(
      () => EntitlementService(),
    );
  }
  if (!getIt.isRegistered<BackendPurchaseVerificationService>()) {
    getIt.registerLazySingleton<BackendPurchaseVerificationService>(
      () => BackendPurchaseVerificationService(),
    );
  }
  if (!getIt.isRegistered<PurchaseService>()) {
    getIt.registerLazySingleton<PurchaseService>(
      () => PurchaseService(
        verificationService: getIt<BackendPurchaseVerificationService>(),
      ),
      dispose: (service) => service.dispose(),
    );
  }
}
