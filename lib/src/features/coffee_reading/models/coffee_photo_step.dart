enum CoffeePhotoStep {
  cupInside,
  saucer,
  cupSide,
}

extension CoffeePhotoStepKeys on CoffeePhotoStep {
  String get titleKey {
    switch (this) {
      case CoffeePhotoStep.cupInside:
        return 'coffeeStepInsideTitle';
      case CoffeePhotoStep.saucer:
        return 'coffeeStepSaucerTitle';
      case CoffeePhotoStep.cupSide:
        return 'coffeeStepCupSideTitle';
    }
  }

  String get descriptionKey {
    switch (this) {
      case CoffeePhotoStep.cupInside:
        return 'coffeeStepInsideDesc';
      case CoffeePhotoStep.saucer:
        return 'coffeeStepSaucerDesc';
      case CoffeePhotoStep.cupSide:
        return 'coffeeStepCupSideDesc';
    }
  }

  String get cropTitleKey {
    switch (this) {
      case CoffeePhotoStep.cupInside:
        return 'coffeeCropInsideTitle';
      case CoffeePhotoStep.saucer:
        return 'coffeeCropSaucerTitle';
      case CoffeePhotoStep.cupSide:
        return 'coffeeCropCupSideTitle';
    }
  }

  String get metadataKey {
    switch (this) {
      case CoffeePhotoStep.cupInside:
        return 'cupInside';
      case CoffeePhotoStep.saucer:
        return 'saucer';
      case CoffeePhotoStep.cupSide:
        return 'cupSide';
    }
  }
}
