import 'dart:io';

import '../models/palmistry_result.dart';
import 'i_palmistry_service.dart';

class MockPalmistryService implements IPalmistryService {
  @override
  Future<PalmistryResult> analyzePalm(File image) async {
    await Future<void>.delayed(const Duration(seconds: 3));

    return const PalmistryResult(
      isValid: true,
      reading: PalmReading(
        mindLine:
            'Akıl çizginin derinliği ve netliği, analitik zekanın çok güçlü olduğunu fısıldıyor.',
        heartLine:
            'Kalp çizginin hafif kavisli yapısı, duygusal dünyanda dengeyi aradığını gösteriyor.',
        lifeEnergy: 'Avuç içindeki genel enerji akışı oldukça canlı ve taze.',
      ),
    );
  }
}
