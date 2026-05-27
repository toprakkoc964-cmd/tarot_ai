import 'dart:io';

import '../models/coffee_reading_result.dart';

abstract class CoffeeReadingService {
  Future<CoffeeReadingResult> analyzeCoffee(List<File> validImages);
}
