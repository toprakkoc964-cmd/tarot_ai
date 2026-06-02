enum CoffeeValidationFailureReason {
  noCupDetected,
  wrongStepImage,
  noCoffeeResidueDetected,
  noSaucerDetected,
  emptyCup,
  imageTooBlurry,
  imageTooDark,
  imageTooBright,
  screenshotOrStockLike,
  screenSpoofing,
  duplicateImage,
  inappropriateContent,
  lowConfidence,
  unknown;

  String get messageKey {
    switch (this) {
      case CoffeeValidationFailureReason.noCupDetected:
        return 'coffeeValidationNoCup';
      case CoffeeValidationFailureReason.wrongStepImage:
        return 'coffeeValidationWrongStep';
      case CoffeeValidationFailureReason.noCoffeeResidueDetected:
        return 'coffeeValidationNoResidue';
      case CoffeeValidationFailureReason.noSaucerDetected:
        return 'coffeeValidationNoSaucer';
      case CoffeeValidationFailureReason.emptyCup:
        return 'coffeeValidationEmptyCup';
      case CoffeeValidationFailureReason.imageTooBlurry:
        return 'coffeeValidationBlurry';
      case CoffeeValidationFailureReason.imageTooDark:
        return 'coffeeValidationTooDark';
      case CoffeeValidationFailureReason.imageTooBright:
        return 'coffeeValidationTooBright';
      case CoffeeValidationFailureReason.screenshotOrStockLike:
        return 'coffeeValidationScreenshotOrStock';
      case CoffeeValidationFailureReason.screenSpoofing:
        return 'coffeeValidationScreenSpoofing';
      case CoffeeValidationFailureReason.duplicateImage:
        return 'coffeeValidationDuplicate';
      case CoffeeValidationFailureReason.inappropriateContent:
        return 'coffeeValidationInappropriateContent';
      case CoffeeValidationFailureReason.lowConfidence:
        return 'coffeeValidationLowConfidence';
      case CoffeeValidationFailureReason.unknown:
        return 'coffeeValidationFailed';
    }
  }

  static CoffeeValidationFailureReason fromBackend(String? value) {
    switch (value) {
      case 'no_cup_detected':
        return CoffeeValidationFailureReason.noCupDetected;
      case 'wrong_step_image':
        return CoffeeValidationFailureReason.wrongStepImage;
      case 'no_residue_visible':
        return CoffeeValidationFailureReason.noCoffeeResidueDetected;
      case 'no_saucer_detected':
        return CoffeeValidationFailureReason.noSaucerDetected;
      case 'empty_cup':
        return CoffeeValidationFailureReason.emptyCup;
      case 'image_too_blurry':
        return CoffeeValidationFailureReason.imageTooBlurry;
      case 'image_too_dark':
        return CoffeeValidationFailureReason.imageTooDark;
      case 'image_too_bright':
        return CoffeeValidationFailureReason.imageTooBright;
      case 'screenshot_or_stock':
        return CoffeeValidationFailureReason.screenshotOrStockLike;
      case 'screen_spoofing':
        return CoffeeValidationFailureReason.screenSpoofing;
      case 'duplicate_images':
        return CoffeeValidationFailureReason.duplicateImage;
      case 'inappropriate_content':
        return CoffeeValidationFailureReason.inappropriateContent;
      case 'low_confidence':
        return CoffeeValidationFailureReason.lowConfidence;
      default:
        return CoffeeValidationFailureReason.unknown;
    }
  }
}
