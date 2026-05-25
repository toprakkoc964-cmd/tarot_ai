import 'package:get_it/get_it.dart';

import '../../features/palmistry/services/i_palmistry_service.dart';
import '../../features/palmistry/services/mock_palmistry_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  if (!getIt.isRegistered<IPalmistryService>()) {
    getIt.registerLazySingleton<IPalmistryService>(
      () => MockPalmistryService(),
    );
  }
}
