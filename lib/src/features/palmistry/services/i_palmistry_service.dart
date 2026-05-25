import 'dart:io';

import '../models/palmistry_result.dart';

abstract class IPalmistryService {
  Future<PalmistryResult> analyzePalm(File image);
}
