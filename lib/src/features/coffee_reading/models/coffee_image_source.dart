import 'package:image_picker/image_picker.dart';

enum CoffeeImageSource {
  camera,
  gallery;

  factory CoffeeImageSource.fromPicker(ImageSource source) {
    return source == ImageSource.camera
        ? CoffeeImageSource.camera
        : CoffeeImageSource.gallery;
  }

  bool get isGallery => this == CoffeeImageSource.gallery;

  String get labelKey {
    switch (this) {
      case CoffeeImageSource.camera:
        return 'coffeeImageSourceCamera';
      case CoffeeImageSource.gallery:
        return 'coffeeImageSourceGallery';
    }
  }

  String get replaceActionKey {
    switch (this) {
      case CoffeeImageSource.camera:
        return 'coffeeRetakePhoto';
      case CoffeeImageSource.gallery:
        return 'coffeeReselectPhoto';
    }
  }
}
