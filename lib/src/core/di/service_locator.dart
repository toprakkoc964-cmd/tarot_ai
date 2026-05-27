import 'package:get_it/get_it.dart';

import '../../features/coffee_reading/services/coffee_image_pipeline_service.dart';
import '../../features/coffee_reading/services/coffee_reading_service.dart';
import '../../features/coffee_reading/services/coffee_temp_file_cleaner.dart';
import '../../features/coffee_reading/services/coffee_validation_service.dart';
import '../../features/coffee_reading/services/mock_coffee_reading_service.dart';
import '../../features/palmistry/services/i_palmistry_service.dart';
import '../../features/palmistry/services/mock_palmistry_service.dart';
import '../../features/shop/services/backend_purchase_verification_service.dart';
import '../../features/shop/services/entitlement_service.dart';
import '../../features/shop/services/purchase_service.dart';
import '../../features/shop/services/shop_config_service.dart';

final getIt = GetIt.instance;

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
      ),
    );
  }
  if (!getIt.isRegistered<CoffeeReadingService>()) {
    getIt.registerLazySingleton<CoffeeReadingService>(
      () => MockCoffeeReadingService(),
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
