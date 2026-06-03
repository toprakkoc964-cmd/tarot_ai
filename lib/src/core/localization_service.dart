import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_locale.dart';

class LocalizationService {
  LocalizationService._();
  static final LocalizationService instance = LocalizationService._();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  final ValueNotifier<List<String>> supportedLanguages =
      ValueNotifier<List<String>>(const ['tr', 'en']);

  final Map<String, Map<String, String>> _cache = {};

  static const Map<String, String> _fallbackEn = {
    'error.default': 'Something went wrong.',
    'error.name_required': 'Name is required.',
    'error.email_required': 'Email is required.',
    'error.password_required': 'Password is required.',
    'error.password_short': 'Password must be at least 6 characters.',
    'error.password_mismatch': 'Passwords do not match.',
    'error.accept_terms': 'Please accept terms to continue.',
    'error.profile_required': 'Please fill all required fields.',
    'error.cards_required': 'Please select at least one card.',
    'error.social_cancelled': 'Sign in was cancelled.',
    'error.google_sign_in_config':
        'Google Sign-In is not configured. Add SHA-1 in Firebase and update google-services.json.',
    'error.google_sign_in_failed': 'Google sign-in failed. Please try again.',
    'tarot.spread.headline': 'Your spread is ready',
    'tarot.spread.pick_from_deck':
        'Choose a card from the deck and reveal today\'s guidance.',
    'tarot.spread.tap_to_draw':
        'Tap the deck once — it slows down and a card is drawn for you.',
    'tarot.spread.pick_another_short': '+1 CARD',
    'tarot.spread.selection_hint':
        '{count}/{max} cards selected. Continue or add another card.',
    'tarot.spread.continue_cta': 'CONTINUE',
    'tarot.spread.pick_another': 'PICK ANOTHER',
    'tarot.spread.revealing': 'Revealing card...',
    'tarot.spread.duplicate_card': 'You already selected this card.',
    'tarot.spread.max_cards': 'You can select up to 7 cards.',
    'tarot.spread.load_failed': 'Card could not be loaded. Try again.',
    'tarot.spread.draw_failed': 'Card draw failed. Please try again.',
    'tarot.spread.chat_title': 'Bilge Aris · Tarot Spread',
    'tarot.spread.hero_title': 'Your chosen cards',
    'tarot.spread.hero_subtitle': 'Bilge Aris reads them as one spread',
    'aris.opening_error_generic':
        'Aris cannot respond right now. Please try again.',
    'aris.opening_error_api_key':
        'Gemini API key is not configured on the server. Add it to functions/.env and redeploy Cloud Functions.',
    'aris.opening_error_auth':
        'Session could not be verified. Sign out and sign in again.',
    'aris.opening_error_profile':
        'Profile record not found. Complete registration or onboarding.',
    'aris.opening_error_input':
        'Card data is missing. Restart the spread from the home screen.',
    'aris.opening_error_network':
        'Cannot reach the server. Check your connection or whether Cloud Functions are deployed.',
    'aris.opening_error_app_check': 'App Check verification failed.',
    'error.apple_not_supported':
        'Apple Sign-In is not supported on this device.',
    'toast.reset_sent': 'Password reset email has been sent.',
    'toast.restore_pending': 'Connect purchase history for restore.',
    'auth.login.title': 'Login',
    'auth.login.button': 'Login',
    'auth.login.social_title': 'OR CONTINUE WITH',
    'auth.login.apple_button': 'Apple',
    'auth.login.google_button': 'Google',
    'auth.login.submit_loading': 'OPENING THE PORTAL...',
    'auth.login.apple_continue': 'Continue with Apple',
    'auth.login.google_continue': 'Continue with Google',
    'auth.login.email_required': 'Email is required.',
    'auth.login.password_required': 'Password is required.',
    'auth.login.invalid_email': 'Enter a valid email address.',
    'auth.login.password_too_short': 'Password must be at least 6 characters.',
    'auth.login.invalid_credentials': 'Invalid email or password.',
    'auth.login.network_error': 'Check your connection and try again.',
    'auth.login.too_many_requests':
        'Too many attempts. Please try again later.',
    'auth.login.generic_error': 'Something went wrong. Please try again.',
    'auth.login.user_disabled': 'This account is currently unavailable.',
    'auth.login.show_password': 'Show password',
    'auth.login.hide_password': 'Hide password',
    'auth.login.legal_prefix': 'By continuing, you agree to the following:',
    'auth.login.legal_terms': 'Terms of Service',
    'auth.login.legal_privacy': 'Privacy Policy',
    'auth.login.legal_ai_notice': 'AI Usage Notice',
    'auth.login.legal_suffix': 'These links apply to all sign-in methods.',
    'auth.login.ai_disclaimer_short':
        'AI readings are for entertainment and personal reflection; they are not certain predictions.',
    'auth.forgot_password.title': 'Reset Your Password',
    'auth.forgot_password.description':
        'Enter your email. If the account is eligible, we will send a password reset link.',
    'auth.forgot_password.email_hint': 'your@email.com',
    'auth.forgot_password.send': 'SEND RESET LINK',
    'auth.forgot_password.sending': 'SENDING...',
    'auth.forgot_password.success':
        'If the email is eligible, a password reset link has been sent.',
    'auth.forgot_password.error':
        'The link could not be sent. Please try again.',
    'auth.forgot_password.cancel': 'Cancel',
    'toast.error_title': 'Something went wrong',
    'toast.success_title': 'Done',
    'auth.register.button': 'Create My Destiny',
    'auth.register.terms_accept_text':
        'I accept the Terms of Service and Privacy Policy.',
    'auth.register.terms_accept_suffix': '.',
    'auth.register.ai_notice': 'AI Usage Notice',
    'auth.register.ai_disclaimer_short':
        'AI readings are provided for entertainment and personal reflection; they do not contain medical, financial, legal advice or certain predictions.',
    'auth.register.social_legal_text':
        'By continuing, you agree to the Terms of Service, Privacy Policy, and AI Usage Notice.',
    'auth.register.button_loading': 'WEAVING YOUR DESTINY...',
    'auth.register.or_continue_with': 'OR CONTINUE WITH',
    'auth.register.apple_continue': 'Continue with Apple',
    'auth.register.google_continue': 'Continue with Google',
    'auth.register.name_required': 'Enter your name.',
    'auth.register.name_too_short': 'Name must be at least 2 characters.',
    'auth.register.email_required': 'Enter your email address.',
    'auth.register.invalid_email': 'Enter a valid email address.',
    'auth.register.password_required': 'Enter your password.',
    'auth.register.password_too_short':
        'Password must be at least 6 characters.',
    'auth.register.confirm_required': 'Enter your password again.',
    'auth.register.passwords_not_match': 'Passwords do not match.',
    'auth.register.terms_required':
        'Accept the Terms of Service and Privacy Policy to continue.',
    'auth.register.email_in_use':
        'An account already exists with this email address.',
    'auth.register.weak_password': 'Choose a stronger password.',
    'auth.register.network_error':
        'Could not connect. Check your internet connection.',
    'auth.register.too_many_requests':
        'Too many attempts. Please try again later.',
    'auth.register.operation_not_allowed':
        'Registration is currently unavailable.',
    'auth.register.generic_error':
        'The account could not be created. Please try again.',
    'auth.register.portal_title': 'Weaving your destiny...',
    'auth.register.portal_subtitle':
        'The circle opens and your journey begins.',
    'auth.register.show_password': 'Show password',
    'auth.register.hide_password': 'Hide password',
    'auth.register.legal_link_error':
        'The link could not be opened. Showing the in-app text instead.',
    'legal.terms.title': 'Terms of Service',
    'legal.privacy.title': 'Privacy Policy',
    'legal.ai_notice.title': 'AI Usage Notice',
    'legal.ai_notice.section_title': 'Entertainment and personal reflection',
    'legal.ai_notice.body':
        'Tarot, coffee reading, palm reading, and other AI interpretations in Tarot AI are provided for entertainment and personal reflection. They are not medical, financial, or legal advice and do not contain certain predictions.',
    'legal.last_updated': 'Last updated: March 10, 2026',
    'legal.view_terms': 'View Terms of Service',
    'legal.view_privacy': 'View Privacy Policy',
    'onboarding.hero_title': 'COSMIC\nPROFILE',
    'onboarding.hero_subtitle':
        'These details are collected once so the cards can know you better.',
    'onboarding.name_label_upper': 'NAME',
    'onboarding.name_hint': 'Your name in the language of the stars...',
    'onboarding.birth_section_title': 'BIRTH DATE & TIME',
    'onboarding.birth_date_placeholder': '12 Mar 1994',
    'onboarding.birth_time_placeholder': '14:45',
    'onboarding.dial_caption': 'Turn the dial to set your birth moment',
    'onboarding.cta_continue': 'CONTINUE',
    'onboarding.footer': 'Your data is as safe as the stars.',
    'onboarding.step': 'Step',
    'onboarding.step1.title': 'Core Details',
    'onboarding.step1.subtitle': 'Tell us about your base profile.',
    'onboarding.step2.title': 'Cosmic Preferences',
    'onboarding.step2.subtitle': 'Add optional birth and language details.',
    'onboarding.step3.title': 'Consent & Confirm',
    'onboarding.step3.subtitle': 'Accept policies and save your profile.',
    'onboarding.step3.subtitle_new':
        'Select the key areas where you want guidance and sharpen your destiny map.',
    'onboarding.step3.area.love': 'LOVE',
    'onboarding.step3.area.career': 'CAREER',
    'onboarding.step3.area.money': 'MONEY',
    'onboarding.step3.area.spiritual': 'SPIRITUAL GROWTH',
    'onboarding.step3.area.family': 'FAMILY',
    'onboarding.step3.area.general': 'GENERAL',
    'onboarding.step3.complete_profile': 'COMPLETE PROFILE',
    'onboarding.step3.footer': 'YOUR DATA IS PROTECTED WITH COSMIC ENCRYPTION.',
    'home.top.token_unit': 'TOKENS',
    'home.daily_draw.available': 'You have 1 free card draw today',
    'home.daily_draw.used': 'Your daily card draw is used',
    'home.daily_draw.paid_available': 'Each card draw costs 5 tokens',
    'home.daily_draw.insufficient': 'You need 5 tokens to draw a card',
    'home.daily_guide_label': 'DAILY GUIDE',
    'home.cta.draw_now': 'DRAW NOW (FREE)',
    'home.cta.drawing': 'DRAWING...',
    'home.cta.draw_locked': 'COME BACK TOMORROW',
    'home.cta.draw_with_credits': 'DRAW WITH 5 TOKENS',
    'home.cta.insufficient_credits': 'NEED 5 TOKENS',
    'home.cta.insufficient_credits_message':
        'You need at least 5 tokens to draw a card.',
    'home.card.star.title': 'Star Card',
    'home.card.star.name': 'The Star',
    'home.card.star.subtitle': 'Hope & Inspiration',
    'home.card.sun.title': 'Sun Card',
    'home.card.sun.name': 'The Sun',
    'home.card.sun.subtitle': 'Joy & Clarity',
    'home.card.moon.title': 'Moon Card',
    'home.card.moon.name': 'The Moon',
    'home.card.moon.subtitle': 'Intuition & Depth',
    'home.card.world.title': 'World Card',
    'home.card.world.name': 'The World',
    'home.card.world.subtitle': 'Completion & Flow',
    'home.birth_frequency.title': 'YOUR BIRTH FREQUENCY',
    'home.birth_frequency.sign': 'Aquarius',
    'home.birth_frequency.reading.lead':
        'You are strong in communication today. ',
    'home.birth_frequency.reading.body':
        'Mental clarity opens space for you, trust your intuition.',
    'home.birth_frequency.loading_comment':
        'Your daily insight is being prepared...',
    'home.birth_frequency.unavailable_retry':
        "Today's insight is unavailable right now. Please try again.",
    'home.birth_frequency.unavailable_missing_birth':
        'A daily insight could not be created because your birth date is missing.',
    'home.tab.ritual': 'Ritual',
    'home.tab.archive': 'Archive',
    'home.tab.messages': 'Messages',
    'home.tab.cosmic': 'Cosmic',
    'home.tab.credit': 'Credit',
    'home.tab.profile': 'Profile',
    'messages.title': 'Messages',
    'messages.subtitle':
        'Continue past tarot readings with Bilge Aris from here.',
    'messages.empty_title': 'No saved readings yet',
    'messages.empty_body':
        'After you draw cards in Ritual and chat with Bilge Aris, your conversations appear here.',
    'messages.load_error':
        'Could not load reading history. Check your connection and try again.',
    'messages.retry': 'Try again',
    'messages.resume_error': 'Could not open this chat. Please try again.',
    'messages.thread_count': '{count} messages',
    'home.cosmic.eyebrow': 'COSMIC GUIDE',
    'home.cosmic.title': 'Mystic Discovery',
    'home.cosmic.subtitle':
        'Discover the signs whispering to your soul through palm and coffee readings.',
    'home.cosmic.palm.title': 'Palm Reading',
    'home.cosmic.palm.description':
        'Discover the hidden messages in the lines of your palm.',
    'home.cosmic.palm.button': 'START PALM READING',
    'home.cosmic.coffee.title': 'Coffee Reading',
    'home.cosmic.coffee.description':
        'Explore the symbols through the cup interior, saucer, and outer traces.',
    'home.cosmic.coffee.button': 'START COFFEE READING',
    'home.cosmic.coming_soon': 'This cosmic path will open soon.',
    'palmScannerTitle': 'Palm Reading Scan',
    'palmScannerDescription': 'Place your palm inside the guide lines.',
    'palmAlignHand': 'Align your hand with the guide lines',
    'palmPartialHand': 'Show your full palm to the camera',
    'palmHoldSteady': 'Hold your hand steady, the lines are sharpening',
    'palmDetected': 'Hand detected. You are ready to scan.',
    'palmShowHand': 'Show your palm to the camera.',
    'palmPlaceInsideGuide': 'Place your palm inside the guide lines.',
    'palmMoveHandAway': 'Move your hand slightly away from the camera.',
    'palmMoveHandCloser': 'Move your hand a little closer to the camera.',
    'palmKeepHandVertical': 'Keep your hand upright.',
    'palmOpenFingers': 'Open your fingers.',
    'palmShowPalm': 'Turn your palm toward the camera.',
    'palmTapToScan': 'TAP TO SCAN',
    'palmReadyToScan': 'Center your palm and tap to scan.',
    'palmErrorNotPalm':
        'This does not look like an open palm. Show your inner palm clearly.',
    'palmErrorUnreadable':
        'The photo could not be analyzed. Improve lighting and try again.',
    'palmErrorInvalidImage':
        'Invalid or oversized photo. Please capture again.',
    'palmErrorAuth':
        'Session could not be verified. Sign out and sign in again.',
    'palmErrorServerConfig':
        'Gemini API key is missing on the server. Check functions/.env.',
    'palmScanningLoading': 'Decoding the universal lines...',
    'palmResultTitle': 'Your Palm Reading Is Ready',
    'palmResultDescription':
        'The symbols in your palm lines have been interpreted for you.',
    'mindLineTitle': 'Mind Line',
    'heartLineTitle': 'Heart Line',
    'lifeEnergyTitle': 'Life Energy',
    'scanAgain': 'Scan Again',
    'privacyTemporaryProcessing': 'Your photo is processed only for analysis.',
    'entertainmentDisclaimer':
        'These interpretations are created for entertainment and personal awareness. They do not include medical, financial, or definitive future predictions.',
    'cameraPermissionRequired': 'Camera Permission Required',
    'cameraPermissionDescription':
        'You need to allow camera access for the palm reading scan.',
    'cameraUnavailableTitle': 'Camera Not Available',
    'cameraUnavailableDescription':
        'Camera access could not be started on this device. The iOS simulator may not always provide a camera; test on a real device for the most reliable result.',
    'openSettings': 'Open Settings',
    'grantCameraPermission': 'Allow Camera Access',
    'palmScanErrorTitle': 'Scan Failed',
    'palmScanErrorDescription': 'Something went wrong. Please try again.',
    'tryAgain': 'Try Again',
    'home.profile.title': 'Cosmic Profile',
    'home.notifications.title': 'Notifications',
    'home.notifications.empty': 'You have no notifications yet.',
    'home.archive.title': 'Cosmic Archive',
    'home.archive.tab.cards': 'Cards',
    'home.archive.tab.chats': 'Chats',
    'home.archive.card1.date': '14 MAY, 22:15',
    'home.archive.card1.title': 'Moon Cycle Prophecy',
    'home.archive.card1.description':
        'Mysterious messages whispered to your soul by changes in the sky.',
    'home.archive.card1.action': 'Illuminate the Moment',
    'home.archive.card2.date': '12 MAY, 03:42',
    'home.archive.card2.title': 'Future Reflections',
    'home.archive.card2.description':
        'Unlock new possibilities in your star map.',
    'home.archive.card2.action': 'Unlock with Ad',
    'home.archive.end_flow': 'Endless Flow',
    'home.credit.title': 'Cosmic Wallet',
    'home.credit.balance_label': 'Balance',
    'home.credit.balance_value': '120 Tokens',
    'home.credit.perks.title': 'Cosmic Perks',
    'home.credit.perk.voice.title': 'Voice Guidance',
    'home.credit.perk.voice.desc':
        'Do not only see the cards, feel the sage voice in your ears.',
    'home.credit.perk.personalized.title': 'Personalized',
    'home.credit.perk.personalized.desc':
        'A deep frequency tailored to your birth chart.',
    'home.credit.perk.clarity.title': 'Mental Clarity',
    'home.credit.perk.clarity.desc':
        'Remove limits and illuminate with deeper questions.',
    'home.credit.package.50.coins': '50 Tokens',
    'home.credit.package.50.title': 'Star Pack',
    'home.credit.package.50.price': '₺49.99',
    'home.credit.package.50.feature1': '5 Voice Readings',
    'home.credit.package.50.feature2': '2 Deep Chats',
    'home.credit.package.50.feature3': 'Standard Analysis',
    'home.credit.package.250.coins': '250 Tokens',
    'home.credit.package.250.title': 'Cosmic Choice',
    'home.credit.package.250.badge': 'Cosmic Choice',
    'home.credit.package.250.price': '₺199.99',
    'home.credit.package.250.feature1': '25 Voice Readings',
    'home.credit.package.250.feature2': '10 Video Sessions',
    'home.credit.package.250.feature3': '20 Deep Chats',
    'home.credit.package.1000.coins': '1000 Tokens',
    'home.credit.package.1000.title': 'Sun Pack',
    'home.credit.package.1000.price': '₺699.99',
    'home.credit.package.1000.feature1': 'Unlimited Voice Readings',
    'home.credit.package.1000.feature2': 'Unlimited Video Sessions',
    'home.credit.package.1000.feature3': 'VIP Priority',
    'home.credit.cta.recharge': 'Recharge Energy',
    'home.credit.restore': 'Restore Purchases',
    'home.credit.terms': 'Terms of Use',
    'home.credit.privacy': 'Privacy Policy',
    'home.credit.legal_disclaimer':
        'Legal Notice: This application is for entertainment and personal exploration only. AI-generated interpretations are not definitive and do not replace professional advice (medical, legal, financial, etc.). Accuracy or realization of content is not guaranteed. Results may vary from person to person. Please evaluate this information with common sense.',
    'shopTitle': 'Cosmic Wallet',
    'shopCreditsTab': 'Tokens',
    'shopPremiumTab': 'Premium',
    'shopLoadingPrice': 'Calculating price...',
    'shopPriceUnavailable': 'This product is currently unavailable',
    'shopPurchaseUnavailable': 'Purchases are currently unavailable',
    'shopProductsNotFoundHint':
        'This product is temporarily unavailable. Please try again later.',
    'shopPurchasePending': 'Purchase is processing...',
    'shopPurchaseVerifying': 'Purchase is being verified...',
    'shopPurchaseVerified': 'Purchase verified.',
    'shopRestorePurchases': 'Restore Purchases',
    'shopRestoreInProgress': 'Restoring purchases...',
    'shopRestoreSuccess': 'Purchases restored.',
    'shopRestoreNoActiveSubscription': 'No active premium subscription found.',
    'shopTermsOfUse': 'Terms of Use',
    'shopPrivacyPolicy': 'Privacy Policy',
    'shopSubscriptionRenewalInfo':
        'Monthly Premium renews automatically every month. You can cancel it from your App Store account settings.',
    'shopTermsAndPrivacyAgreement':
        'By purchasing, you agree to the Terms of Use and Privacy Policy.',
    'shopFooterLegalText':
        'Subscriptions are managed and can be cancelled through your App Store account.',
    'shopLinkOpenFailed':
        'The link could not be opened. Please try again later.',
    'premiumMonthlyTitle': 'Monthly Premium',
    'premiumMonthlySubtitle': 'Ad-free Cosmic Experience',
    'premiumFeatureNoAds': 'Ad-free use',
    'premiumFeatureBonusCredits': '200 bonus tokens every month',
    'premiumFeatureDeepReadings': 'More detailed AI readings',
    'premiumFeaturePersonalizedExperience': 'Personalized fortune experience',
    'premiumFeaturePremiumAiDepth':
        'Premium response depth from Madam Aris & Sage Aris',
    'premiumCta': 'Go Monthly Premium',
    'premiumBadgePopular': 'Recommended',
    'premiumAutoRenewInfo': 'Monthly Premium renews automatically every month.',
    'premiumCancelInfo':
        'You can cancel your subscription anytime from your App Store account settings.',
    'premiumBonusCreditsInfo':
        'Premium members receive 200 bonus tokens in each subscription period.',
    'creditsPack50': '50 Tokens',
    'creditsPack250': '250 Tokens',
    'creditsPack1000': '1000 Tokens',
    'creditsPackSubtitle': 'One-time cosmic energy pack',
    'creditsConsumableInfo':
        'Token packs are one-time purchases and do not include premium membership.',
    'common.logout': 'Logout',
    'common.restore': 'Restore',
    'common.select_language': 'Select language',
    'common.back': 'Back',
    'common.next': 'Next',
    'common.save_profile': 'Save Profile',
    'common.generate': 'Generate Reading',
    'common.loading': 'Loading...',
    'common.done': 'Done',
    'common.cancel': 'Cancel',
    'common.close': 'Close',
    'arisTarotTitle': 'Cosmic Sage Aris',
    'arisAssistantName': 'Sage Aris',
    'arisLoadingSubtitle': "Gathering your card's energy.",
    'arisTyping': '{name} is typing',
    'arisMessageMeta': '{name} • Now',
    'arisMessageCost': 'Each message costs 10 tokens',
    'arisQuestionHint': 'Whisper a question to the sage...',
    'coffeeTitle': 'Coffee Reading',
    'coffeeDescription':
        'Madam Aris will read the inside of your cup, the saucer, and the outer surface together.',
    'coffeeOpenCamera': 'Open Camera',
    'coffeeChooseGallery': 'Choose from Gallery',
    'coffeeCropTitle': 'Center the Cup',
    'coffeeCropInsideTitle': 'Center the Inside of the Cup',
    'coffeeCropSaucerTitle': 'Center the Saucer',
    'coffeeCropCupSideTitle': 'Center the Outside of the Cup',
    'coffeePreparingPhoto': 'Preparing photo...',
    'coffeeValidatingPhoto': 'Validating photo...',
    'coffeeStepInsideTitle': '1/3 · Inside the Cup',
    'coffeeStepInsideDesc': 'Show the grounds and inner traces clearly.',
    'coffeeStepSaucerTitle': '2/3 · Cup Saucer',
    'coffeeStepSaucerDesc': 'Center the grounds left on the saucer.',
    'coffeeStepCupSideTitle': '3/3 · Outside the Cup',
    'coffeeStepCupSideDesc':
        'Show the side surface and overall shape of the cup.',
    'coffeeAddPhoto': 'Add Photo',
    'coffeeCaptureCompleted': 'This photo is ready.',
    'coffeeAllPhotosReady':
        'All three photos are ready. Tap the button below when you want Madam Aris to interpret them.',
    'coffeeProgressHint':
        '{count}/3 photos ready. Complete all three steps to analyze.',
    'coffeeContinue': 'Continue',
    'coffeeInvalidImage':
        'We could not detect the required coffee cup detail in this image. Please try a clearer photo.',
    'coffeeInvalidImageDetailed':
        'We could not detect the required coffee cup detail in this image. Please retake this step with the subject clearer and centered.',
    'coffeeCupDetected': 'Cup detected',
    'coffeeWeakImageWarning':
        'The photo looks a little unclear, but you can continue.',
    'coffeeStartMadamAris': 'Ask Madam Aris',
    'coffeeStartMadamArisWithCredits': 'Ask Madam Aris · 20 Tokens',
    'coffeeReadingCostInfo':
        'A coffee reading costs 20 tokens. Tokens are deducted only after a successful reading.',
    'coffeeRetakePhoto': 'Retake',
    'coffeeReselectPhoto': 'Choose Again',
    'coffeeAskMadamAris': 'Ask Madam Aris · 20 Tokens',
    'coffeeMadamArisPreparing': 'Madam Aris is preparing...',
    'coffeeNotEnoughCredits': 'You do not have enough tokens.',
    'coffeeReadyToAnalyze':
        'All three photos are ready. Your reading starts only when you ask.',
    'coffeeCreditInfo': '20 tokens · deducted only after a successful reading',
    'coffeePhotoReady': 'Photo ready',
    'coffeePhotoNeedsRetry': 'Replace this photo',
    'coffeePhotoValidating': 'Validating photo',
    'coffeeImageSourceCamera': 'Camera',
    'coffeeImageSourceGallery': 'Gallery',
    'coffeeLoadingTriangleTitle': 'THREE TRACES · ONE READING',
    'coffeeLoadingTriangleSubtitle':
        'Madam Aris is reading all three sides of your cup together.',
    'coffeeLoadingPhaseValidationTitle': 'Validating your photos...',
    'coffeeLoadingPhaseValidationSubtitle':
        'The cup interior, saucer, and outer view are being prepared securely.',
    'coffeeLoadingPhaseCombiningTitle':
        'The three traces are coming together...',
    'coffeeLoadingPhaseCombiningSubtitle':
        'The signs in the grounds are matching across each side of the cup.',
    'coffeeLoadingPhaseReadingTitle': 'Madam Aris is reading the symbols...',
    'coffeeLoadingPhaseReadingSubtitle':
        'The cup interior, saucer, and outer traces are being interpreted together.',
    'coffeeLoadingPhaseLongWaitTitle': 'Finishing the finer details...',
    'coffeeLoadingPhaseLongWaitSubtitle':
        'This can take a few more seconds. Please wait.',
    'coffeeRetake': 'Retake',
    'coffeeRetry': 'Try Again',
    'coffeeCamera': 'Take with Camera',
    'coffeeGallery': 'Choose from Gallery',
    'coffeeAnalyzingSymbols':
        'Madam Aris is decoding the symbols in the grounds...',
    'coffeeAnalyzingSubtitle':
        'The cup interior, saucer, and outer traces are being read together...',
    'coffeeMadamArisTitle': 'Madam Aris · Coffee Reading',
    'coffeeMadamArisName': 'Madam Aris',
    'coffeeMadamArisSubtitle': 'Coffee Reading Guide',
    'coffeeReadingReady': 'Madam Aris Interpreted Your Coffee Reading',
    'coffeePreviewTitle': 'Your Cup Is Ready',
    'coffeePast': 'Trace from the Past',
    'coffeePresent': 'Current Energy',
    'coffeeFuture': 'Near-Term Message',
    'coffeePermissionDenied':
        'The required permission for photo selection was denied.',
    'coffeeCropCancelled': 'Cropping was cancelled.',
    'coffeeCompressionFailed':
        'The photo could not be prepared. Please try again.',
    'coffeeValidationFailed': 'Coffee photo could not be validated',
    'coffeeValidationNoCup': 'No cup detected. Please show the cup clearly.',
    'coffeeValidationWrongStep': 'This photo is not suitable for this step.',
    'coffeeValidationNoResidue':
        'Coffee residue is not clear. Please capture the grounds more closely.',
    'coffeeValidationNoSaucer':
        'No saucer detected. Please show the saucer and residue clearly.',
    'coffeeValidationEmptyCup':
        'No coffee grounds or traces are visible inside the cup. Please use a cup with residue marks.',
    'coffeeValidationBlurry':
        'The photo looks blurry. Please take a sharper picture.',
    'coffeeValidationTooDark':
        'The photo is too dark. Please shoot in a brighter place.',
    'coffeeValidationTooBright':
        'The photo is too bright. Please reduce the light and try again.',
    'coffeeValidationDuplicate':
        'This photo looks too similar to one you already added. Please take a new angle.',
    'coffeeValidationScreenshotOrStock':
        'This image looks like a screenshot or stock photo. Please capture your real cup with the camera.',
    'coffeeValidationScreenSpoofing':
        'This cup appears to be photographed from another screen. Please use a physical cup.',
    'coffeeValidationInappropriateContent':
        'Inappropriate content detected. Please upload physical cup and saucer photos only.',
    'coffeeValidationLowConfidence':
        'We could not confidently validate this photo. Please try again.',
    'coffeeValidationCameraRecommended':
        'For the most accurate coffee reading, we recommend capturing your cup directly with the camera.',
    'coffeeValidationPrivacyInfo':
        'Your 3 selected photos are analyzed for your coffee reading. Successful reading photos are retained for up to 7 days and can be deleted immediately from the result screen.',
    'coffeeValidationLocalInfo':
        'Initial visual validation runs on your device.',
    'coffeeValidationBackendInfo':
        'To create your reading, photos may be sent securely to the analysis service.',
    'coffeeValidationParseError':
        'Something went wrong while validating the photos. Please try again.',
    'coffeePhotosRetentionInfo':
        'Your reading photos are retained for up to 7 days. You can delete them now if you prefer.',
    'coffeeDeletePhotos': 'Delete My Photos Now',
    'coffeeDeletePhotosSuccess': 'Your photos were deleted.',
    'coffeeDeletePhotosFailed':
        'Your photos could not be deleted. Please try again.',
    'coffeeAnalysisInProgress':
        'A coffee reading is already being prepared for you.',
    'coffeeRateLimited':
        'You have tried too many times in a short period. Please try again later.',
    'coffeeReadingDisclaimer':
        'This reading is for entertainment and personal awareness; it is not medical, financial, legal, or a definitive future prediction.',
    'coffeeReadingGeneralEnergy': 'General Energy',
    'coffeeReadingSymbols': 'Symbols in the Grounds',
    'coffeeReadingSaucerSigns': 'Saucer Signs',
    'coffeeReadingOuterCupMessage': 'Outer Cup Message',
    'coffeeReadingPastTrace': 'Trace from the Past',
    'coffeeReadingPresentMood': 'Present Mood',
    'coffeeReadingNearFutureMessage': 'Near Future Message',
    'coffeeReadingAdvice': 'Madam Aris Advice',
    'coffeeEntertainmentDisclaimer':
        'These readings are created for entertainment and personal awareness. They do not include medical, financial, legal, or definitive future predictions.',
    'coffeePhotoPrivacyNote':
        'Initial cup validation runs on your device. When you request a reading, your photos are sent securely for analysis and retained for up to 7 days.',
    'coffeeChatWithMadamAris': 'Chat with Madam Aris',
    'coffeeMessageNote': 'A coffee reading costs 20 tokens.',
    'coffeeQuestionHint': 'Ask about the symbols in the grounds...',
    'coffeeLoadingChatSubtitle': 'Listening to the symbols in the grounds.',
    'coffeeMockOpening':
        'I can see your cup and the traces in the grounds... Inside, on the saucer, and across the outer surface, there are symbols that complete each other. This reading is prepared for entertainment and personal awareness. Now, let us read these signs together...',
    'coffeeMockLoveReply':
        'Madam Aris notices a soft opening shaped like a heart in your cup. It whispers that listening calmly and clarifying your intention may serve your relationships well.',
    'coffeeMockCareerReply':
        'The lines rising toward the rim point to small but steady steps in work and money matters. This is not a promise, only a gentle reminder to gather your focus today.',
    'coffeeMockGeneralReply':
        'The overall energy of your cup is calm yet moving. Madam Aris suggests simplifying what is on your mind and noticing the small sign in front of you without magnifying it.',
    'common.retry': 'Try Again',
    'profileCosmicPersonalizationTitle': 'Cosmic Personalization',
    'profileCosmicPersonalizationSubtitle':
        'Make your readings feel more relevant to you',
    'personalizationTitle': 'Cosmic Personalization',
    'personalizationDescription':
        'Madam Aris and Bilge Aris use these details to tailor their readings more closely to you.',
    'personalizationPrivacyNote':
        'These details are used only to personalize readings for entertainment and personal awareness.',
    'personalizationEnabledTitle': 'Personalized readings',
    'personalizationEnabledSubtitle':
        'Allow my preferences to be used as gentle context in readings.',
    'personalizationFocusAreasTitle': 'GUIDANCE AREAS',
    'personalizationSave': 'Save Changes',
    'personalizationSaving': 'Saving...',
    'personalizationSaved': 'Your preferences have been updated.',
    'personalizationSaveError':
        'Your preferences could not be updated. Please try again.',
    'personalizationLoadError':
        'Your preferences could not be loaded. Please try again.',
    'personalizationUnsavedTitle': 'Changes have not been saved',
    'personalizationUnsavedMessage': 'If you leave, your changes will be lost.',
    'personalizationCancel': 'Stay',
    'personalizationExit': 'Leave',
  };

  static const Map<String, String> _fallbackTr = {
    'error.default': 'Bir hata olustu.',
    'error.name_required': 'Isim alani zorunlu.',
    'error.email_required': 'E-posta alani zorunlu.',
    'error.password_required': 'Sifre alani zorunlu.',
    'error.password_short': 'Sifre en az 6 karakter olmali.',
    'error.password_mismatch': 'Sifreler eslesmiyor.',
    'error.accept_terms': 'Devam etmek icin kosullari kabul etmelisin.',
    'error.profile_required': 'Lutfen zorunlu alanlari doldur.',
    'error.cards_required': 'En az bir kart secmelisin.',
    'error.social_cancelled': 'Giris islemi iptal edildi.',
    'error.google_sign_in_config':
        'Google girisi yapilandirilmamis. Firebase\'de SHA-1 ekleyip google-services.json dosyasini guncelleyin.',
    'error.google_sign_in_failed':
        'Google ile giris basarisiz. Tekrar deneyin.',
    'tarot.spread.headline': 'Secimin hazir',
    'tarot.spread.pick_from_deck':
        'Dolasimdaki kartlardan birini sec ve bugunun rehberligini aciga cikar.',
    'tarot.spread.tap_to_draw':
        'Desteye bir kez dokun; kartlar yavaslar ve bir kart otomatik secilir.',
    'tarot.spread.pick_another_short': '+1 KART',
    'tarot.spread.selection_hint':
        '{count}/{max} kart sectin. Devam edebilir veya yeni kart ekleyebilirsin.',
    'tarot.spread.continue_cta': 'DEVAM ET',
    'tarot.spread.pick_another': 'BIR KART DAHA SEC',
    'tarot.spread.revealing': 'Kart aciliyor...',
    'tarot.spread.duplicate_card': 'Bu karti zaten sectin.',
    'tarot.spread.max_cards': 'En fazla 7 kart secebilirsin.',
    'tarot.spread.load_failed': 'Kart yuklenemedi. Tekrar dene.',
    'tarot.spread.draw_failed': 'Kart cekimi tamamlanamadi. Tekrar dene.',
    'tarot.spread.chat_title': 'Bilge Aris · Tarot Yayilimi',
    'tarot.spread.hero_title': 'Sectigin kartlar',
    'tarot.spread.hero_subtitle':
        'Bilge Aris bunlari tek bir yayilim olarak yorumlar',
    'error.apple_not_supported': 'Bu cihazda Apple girisi desteklenmiyor.',
    'toast.reset_sent': 'Sifre sifirlama e-postasi gonderildi.',
    'toast.restore_pending': 'Restore icin satin alma gecmisi baglanmali.',
    'auth.login.title': 'Giris Yap',
    'auth.login.button': 'Giris Yap',
    'auth.login.social_title': 'VEYA SUNUNLA DEVAM ET',
    'auth.login.apple_button': 'Apple',
    'auth.login.google_button': 'Google',
    'auth.login.submit_loading': 'PORTAL AÇILIYOR...',
    'auth.login.apple_continue': 'Apple ile devam et',
    'auth.login.google_continue': 'Google ile devam et',
    'auth.login.email_required': 'E-posta alanı zorunlu.',
    'auth.login.password_required': 'Şifre alanı zorunlu.',
    'auth.login.invalid_email': 'Geçerli bir e-posta adresi gir.',
    'auth.login.password_too_short': 'Şifre en az 6 karakter olmalı.',
    'auth.login.invalid_credentials': 'E-posta veya şifre hatalı.',
    'auth.login.network_error': 'Bağlantını kontrol edip tekrar dene.',
    'auth.login.too_many_requests':
        'Çok fazla deneme yapıldı. Biraz sonra tekrar dene.',
    'auth.login.generic_error': 'Bir sorun oluştu. Lütfen tekrar dene.',
    'auth.login.user_disabled': 'Bu hesap şu anda kullanılamıyor.',
    'auth.login.show_password': 'Şifreyi göster',
    'auth.login.hide_password': 'Şifreyi gizle',
    'auth.login.legal_prefix':
        'Devam ederek aşağıdaki metinleri kabul etmiş olursun:',
    'auth.login.legal_terms': 'Kullanım Koşulları',
    'auth.login.legal_privacy': 'Gizlilik Politikası',
    'auth.login.legal_ai_notice': 'AI Kullanım Notu',
    'auth.login.legal_suffix':
        'Bu bağlantılar tüm giriş yöntemleri için geçerlidir.',
    'auth.login.ai_disclaimer_short':
        'AI yorumları eğlence ve kişisel farkındalık amaçlıdır; kesin gelecek tahmini değildir.',
    'auth.forgot_password.title': 'Şifreni Sıfırla',
    'auth.forgot_password.description':
        'E-posta adresini gir. Hesabın uygunsa şifre yenileme bağlantısını göndereceğiz.',
    'auth.forgot_password.email_hint': 'senin@adresin.com',
    'auth.forgot_password.send': 'YENİLEME BAĞLANTISI GÖNDER',
    'auth.forgot_password.sending': 'GÖNDERİLİYOR...',
    'auth.forgot_password.success':
        'E-posta adresi uygunsa şifre yenileme bağlantısı gönderildi.',
    'auth.forgot_password.error': 'Bağlantı gönderilemedi. Lütfen tekrar dene.',
    'auth.forgot_password.cancel': 'Vazgeç',
    'toast.error_title': 'Bir sorun oluştu',
    'toast.success_title': 'İşlem tamamlandı',
    'auth.register.button': 'Kaderimi Olustur',
    'auth.register.terms_accept_text':
        'Kullanım Koşulları’nı ve Gizlilik Politikası’nı kabul ediyorum.',
    'auth.register.terms_accept_suffix': ' metinlerini kabul ediyorum.',
    'auth.register.ai_notice': 'AI Kullanım Notu',
    'auth.register.ai_disclaimer_short':
        'AI yorumları eğlence ve kişisel farkındalık amacıyla sunulur; tıbbi, finansal, hukuki veya kesin gelecek tahmini içermez.',
    'auth.register.social_legal_text':
        'Devam ederek Kullanım Koşulları’nı, Gizlilik Politikası’nı ve AI Kullanım Notu’nu kabul etmiş olursun.',
    'auth.register.button_loading': 'KADERİN ÖRÜLÜYOR...',
    'auth.register.or_continue_with': 'VEYA ŞUNUNLA DEVAM ET',
    'auth.register.apple_continue': 'Apple ile devam et',
    'auth.register.google_continue': 'Google ile devam et',
    'auth.register.name_required': 'Adını yazmalısın.',
    'auth.register.name_too_short': 'Ad en az 2 karakter olmalı.',
    'auth.register.email_required': 'E-posta adresini girmelisin.',
    'auth.register.invalid_email': 'Geçerli bir e-posta adresi gir.',
    'auth.register.password_required': 'Şifreni girmelisin.',
    'auth.register.password_too_short': 'Şifre en az 6 karakter olmalı.',
    'auth.register.confirm_required': 'Şifreni tekrar yazmalısın.',
    'auth.register.passwords_not_match': 'Şifreler eşleşmiyor.',
    'auth.register.terms_required':
        'Devam etmek için Kullanım Koşulları ve Gizlilik Politikası’nı kabul etmelisin.',
    'auth.register.email_in_use': 'Bu e-posta adresiyle zaten bir hesap var.',
    'auth.register.weak_password': 'Şifren daha güçlü olmalı.',
    'auth.register.network_error':
        'Bağlantı kurulamadı. Lütfen internetini kontrol et.',
    'auth.register.too_many_requests':
        'Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar dene.',
    'auth.register.operation_not_allowed':
        'Kayıt işlemi şu anda kullanılamıyor.',
    'auth.register.generic_error': 'Kayıt oluşturulamadı. Lütfen tekrar dene.',
    'auth.register.portal_title': 'Kaderin örülüyor...',
    'auth.register.portal_subtitle': 'Çember açılıyor, yolculuğun başlıyor.',
    'auth.register.show_password': 'Şifreyi göster',
    'auth.register.hide_password': 'Şifreyi gizle',
    'auth.register.legal_link_error':
        'Bağlantı açılamadı. Uygulama içindeki metni gösteriyoruz.',
    'legal.terms.title': 'Kullanim Kosullari',
    'legal.privacy.title': 'Gizlilik Politikasi',
    'legal.ai_notice.title': 'AI Kullanım Notu',
    'legal.ai_notice.section_title': 'Eğlence ve kişisel farkındalık',
    'legal.ai_notice.body':
        'Tarot AI içindeki tarot, kahve falı, el falı ve diğer AI yorumları eğlence ve kişisel farkındalık amacıyla sunulur. Tıbbi, finansal veya hukuki tavsiye değildir ve kesin gelecek tahmini içermez.',
    'legal.last_updated': 'Son guncelleme: 10 Mart 2026',
    'legal.view_terms': 'Kullanim Kosullarini Gor',
    'legal.view_privacy': 'Gizlilik Politikasini Gor',
    'onboarding.hero_title': 'KOZMIK\nPROFIL',
    'onboarding.hero_subtitle':
        'Bu bilgiler yalnizca bir kez alinir. Kartlar seni daha iyi tanisin.',
    'onboarding.name_label_upper': 'ADIN',
    'onboarding.name_hint': 'Goklerin diliyle ismin...',
    'onboarding.birth_section_title': 'DOGUM TARIHI & SAATI',
    'onboarding.birth_date_placeholder': '12 Mart 1994',
    'onboarding.birth_time_placeholder': '14:45',
    'onboarding.dial_caption': 'Kadrani cevirerek dogum anini secin',
    'onboarding.cta_continue': 'DEVAM ET',
    'onboarding.footer': 'Verilerin yildizlar kadar guvende.',
    'onboarding.step': 'Adim',
    'onboarding.step1.title': 'Temel Bilgiler',
    'onboarding.step1.subtitle':
        'Profilini olusturmak icin zorunlu alanlari doldur.',
    'onboarding.step2.title': 'Kisisel Tercihler',
    'onboarding.step2.subtitle': 'Dogum ve dil tercihlerini ekleyebilirsin.',
    'onboarding.step3.title': 'Onay ve Kayit',
    'onboarding.step3.subtitle': 'Onay kutularini isaretleyip profili kaydet.',
    'onboarding.step3.subtitle_new':
        'Rehberlik almak istedigin temel alanlari secerek kaderinin haritasini netlestir.',
    'onboarding.step3.area.love': 'ASK',
    'onboarding.step3.area.career': 'KARIYER',
    'onboarding.step3.area.money': 'PARA',
    'onboarding.step3.area.spiritual': 'RUHSAL GELISIM',
    'onboarding.step3.area.family': 'AILE',
    'onboarding.step3.area.general': 'GENEL',
    'onboarding.step3.complete_profile': 'PROFILI TAMAMLA',
    'onboarding.step3.footer': 'VERILERIN KOZMIK SIFRELEME ILE KORUNUR.',
    'home.top.token_unit': 'JETON',
    'home.daily_draw.available': 'Bugun 1 Kart Cekim Hakkin Var',
    'home.daily_draw.used': 'Gunluk kart hakkin kullanildi',
    'home.daily_draw.paid_available': 'Her kart cekimi 5 jeton',
    'home.daily_draw.insufficient': 'Kart cekmek icin 5 jeton gerekli',
    'home.daily_guide_label': 'GUNUN REHBERI',
    'home.cta.draw_now': 'HEMEN CEK (UCRETSIZ)',
    'home.cta.drawing': 'CEKILIYOR...',
    'home.cta.draw_locked': 'YARIN TEKRAR GEL',
    'home.cta.draw_with_credits': '5 JETONLA CEK',
    'home.cta.insufficient_credits': '5 JETON GEREKLI',
    'home.cta.insufficient_credits_message':
        'Kart cekmek icin en az 5 jeton gerekli.',
    'home.card.star.title': 'Yildiz Karti',
    'home.card.star.name': 'The Star',
    'home.card.star.subtitle': 'Umut & Ilham',
    'home.card.sun.title': 'Gunes Karti',
    'home.card.sun.name': 'The Sun',
    'home.card.sun.subtitle': 'Nese & Netlik',
    'home.card.moon.title': 'Ay Karti',
    'home.card.moon.name': 'The Moon',
    'home.card.moon.subtitle': 'Sezgi & Derinlik',
    'home.card.world.title': 'Dunya Karti',
    'home.card.world.name': 'The World',
    'home.card.world.subtitle': 'Tamamlanma & Akis',
    'home.birth_frequency.title': 'DOGUM FREKANSINI',
    'home.birth_frequency.sign': 'Kova Burcu',
    'home.birth_frequency.reading.lead': 'Bugun iletisimde guclusun. ',
    'home.birth_frequency.reading.body':
        'Zihinsel berraklik sana alan aciyor, sezgilerine guvenmekten cekinme.',
    'home.birth_frequency.loading_comment': 'Gunluk yorumun hazirlaniyor...',
    'home.birth_frequency.unavailable_retry':
        'Bugunluk yorum su an alinamiyor. Lutfen tekrar dene.',
    'home.birth_frequency.unavailable_missing_birth':
        'Dogum tarihin kayitli olmadigi icin bugunluk yorum olusturulamadi.',
    'home.tab.ritual': 'Rituel',
    'home.tab.archive': 'Arsiv',
    'home.tab.messages': 'Mesajlar',
    'home.tab.cosmic': 'Kozmik',
    'home.tab.credit': 'Kredi',
    'home.tab.profile': 'Profil',
    'messages.title': 'Mesajlar',
    'messages.subtitle':
        'Her kart çekimindeki Bilge Aris sohbetlerin burada listelenir.',
    'messages.empty_title': 'Henüz kayıtlı yorum yok',
    'messages.empty_body':
        'Ritüelden kart çekip Bilge Aris ile konuştuğunda sohbetlerin burada saklanır.',
    'messages.load_error':
        'Yorum geçmişi yüklenemedi. Bağlantını kontrol edip tekrar dene.',
    'messages.retry': 'Tekrar dene',
    'messages.resume_error': 'Sohbet yüklenemedi. Lütfen tekrar dene.',
    'messages.thread_count': '{count} mesaj',
    'home.cosmic.eyebrow': 'KOZMİK REHBER',
    'home.cosmic.title': 'Mistik Keşif',
    'home.cosmic.subtitle':
        'El falı ve kahve falı ile ruhuna fısıldayan işaretleri keşfet.',
    'home.cosmic.palm.title': 'El Falı',
    'home.cosmic.palm.description':
        'Avuç çizgilerindeki gizli mesajları keşfet.',
    'home.cosmic.palm.button': 'EL FALINI BAŞLAT',
    'home.cosmic.coffee.title': 'Kahve Falı',
    'home.cosmic.coffee.description':
        'Fincanın içi, tabağı ve dış izleriyle sembolleri keşfet.',
    'home.cosmic.coffee.button': 'KAHVE FALINI BAŞLAT',
    'home.cosmic.coming_soon': 'Bu kozmik yol çok yakında açılacak.',
    'palmScannerTitle': 'El Falı Taraması',
    'palmScannerDescription': 'Avucunu kılavuz çizgilerin içine yerleştir.',
    'palmAlignHand': 'Elini kılavuz çizgilere hizala',
    'palmPartialHand': 'Avucunun tamamını kameraya göster',
    'palmHoldSteady': 'Elini sabit tut, çizgiler netleşiyor',
    'palmDetected': 'El algılandı. Tarama için hazırsın.',
    'palmShowHand': 'Avucunu kameraya göster.',
    'palmPlaceInsideGuide': 'Avucunu kılavuz çizgilerin içine yerleştir.',
    'palmMoveHandAway': 'Elini kameradan biraz uzaklaştır.',
    'palmMoveHandCloser': 'Elini kameraya biraz yaklaştır.',
    'palmKeepHandVertical': 'Elini dik tut.',
    'palmOpenFingers': 'Parmaklarını aç.',
    'palmShowPalm': 'Avuç içini kameraya çevir.',
    'palmTapToScan': 'TARAMA İÇİN DOKUN',
    'palmReadyToScan': 'Avucunu ortaya hizala ve taramak için dokun.',
    'palmErrorNotPalm':
        'Bu görüntü avuç içi gibi görünmüyor. Avucunu açık ve net şekilde göster.',
    'palmErrorUnreadable':
        'Fotoğraf analiz edilemedi. Işığı artırıp avucunu sabit tutarak tekrar dene.',
    'palmErrorInvalidImage':
        'Fotoğraf geçersiz veya çok büyük. Tekrar çekmeyi dene.',
    'palmErrorAuth': 'Oturumun doğrulanamadı. Çıkış yapıp tekrar giriş yap.',
    'palmErrorServerConfig':
        'Sunucuda Gemini API anahtarı eksik. Geliştirici functions/.env dosyasını kontrol etmeli.',
    'palmScanningLoading': 'Evrensel çizgilerin kodları çözülüyor...',
    'palmResultTitle': 'El Falı Analizin Hazır',
    'palmResultDescription':
        'Avuç çizgilerindeki semboller senin için yorumlandı.',
    'mindLineTitle': 'Akıl Çizgisi',
    'heartLineTitle': 'Kalp Çizgisi',
    'lifeEnergyTitle': 'Yaşam Enerjisi',
    'scanAgain': 'Yeniden Tara',
    'privacyTemporaryProcessing':
        'Fotoğrafın yalnızca analiz amacıyla işlenir.',
    'entertainmentDisclaimer':
        'Bu yorumlar eğlence ve kişisel farkındalık amacıyla hazırlanmıştır. Tıbbi, finansal veya kesin gelecek tahmini içermez.',
    'cameraPermissionRequired': 'Kamera İzni Gerekli',
    'cameraPermissionDescription':
        'El falı taraması için kameraya erişim izni vermelisin.',
    'cameraUnavailableTitle': 'Kamera Bulunamadı',
    'cameraUnavailableDescription':
        'Bu cihazda kamera erişimi başlatılamadı. iOS simülatörde kamera her zaman kullanılamayabilir; en doğru test için gerçek cihazda dene.',
    'openSettings': 'Ayarlara Git',
    'grantCameraPermission': 'Kamera İzni Ver',
    'palmScanErrorTitle': 'Tarama Başarısız',
    'palmScanErrorDescription': 'Bir sorun oluştu. Lütfen tekrar dene.',
    'tryAgain': 'Tekrar Dene',
    'home.profile.title': 'Kozmik Profil',
    'home.notifications.title': 'Kozmik Bildirimler',
    'home.notifications.empty': 'Henuz bildirimin yok.',
    'home.archive.title': 'Kozmik Arsiv',
    'home.archive.tab.cards': 'Kartlar',
    'home.archive.tab.chats': 'Sohbetler',
    'home.archive.card1.date': '14 MAYIS, 22:15',
    'home.archive.card1.title': 'Ay Dongusu Kehaneti',
    'home.archive.card1.description':
        'Gokyuzundeki degisimlerin ruhuna fisildadigi gizemli mesajlar.',
    'home.archive.card1.action': 'Aniyi Aydinlat',
    'home.archive.card2.date': '12 MAYIS, 03:42',
    'home.archive.card2.title': 'Gelecek Yansimalari',
    'home.archive.card2.description':
        'Yildiz haritandaki yeni olasiliklarin kilidini ac.',
    'home.archive.card2.action': 'Reklamla Ac',
    'home.archive.end_flow': 'Sonsuz Akis',
    'home.credit.title': 'Kozmik Cuzdan',
    'home.credit.balance_label': 'Bakiyen',
    'home.credit.balance_value': '120 Jeton',
    'home.credit.perks.title': 'Kozmik Ayricaliklar',
    'home.credit.perk.voice.title': 'Sesli Rehberlik',
    'home.credit.perk.voice.desc':
        'Sadece kartlari gorme, bilge sesi kulaklarinda hisset.',
    'home.credit.perk.personalized.title': 'Kisisellestirilmis',
    'home.credit.perk.personalized.desc':
        'Dogum haritana ozel, sana ozgu derin frekans.',
    'home.credit.perk.clarity.title': 'Zihinsel Aciklik',
    'home.credit.perk.clarity.desc':
        'Sinirlari kaldir; derinlesen sorularla aydinlan.',
    'home.credit.package.50.coins': '50 Jeton',
    'home.credit.package.50.title': 'Yildiz Paketi',
    'home.credit.package.50.price': '₺49,99',
    'home.credit.package.50.feature1': '5 Sesli Yorum',
    'home.credit.package.50.feature2': '2 Derin Sohbet',
    'home.credit.package.50.feature3': 'Standart Analiz',
    'home.credit.package.250.coins': '250 Jeton',
    'home.credit.package.250.title': 'Kozmik Tercih',
    'home.credit.package.250.badge': 'Kozmik Tercih',
    'home.credit.package.250.price': '₺199,99',
    'home.credit.package.250.feature1': '25 Sesli Yorum',
    'home.credit.package.250.feature2': '10 Goruntulu Gorusme',
    'home.credit.package.250.feature3': '20 Derin Sohbet',
    'home.credit.package.1000.coins': '1000 Jeton',
    'home.credit.package.1000.title': 'Gunes Paketi',
    'home.credit.package.1000.price': '₺699,99',
    'home.credit.package.1000.feature1': 'Sinirsiz Sesli Yorum',
    'home.credit.package.1000.feature2': 'Sinirsiz Goruntulu',
    'home.credit.package.1000.feature3': 'VIP Oncelik',
    'home.credit.cta.recharge': 'Enerjiyi Yukle',
    'home.credit.restore': 'Satin Alimlari Geri Yukle',
    'home.credit.terms': 'Terms of Use',
    'home.credit.privacy': 'Privacy Policy',
    'home.credit.legal_disclaimer':
        'Yasal Uyari: Bu uygulama yalnizca eglence ve kisisel kesif amaclidir. AI tarafindan olusturulan yorumlar kesinlik tasimaz ve profesyonel tavsiye (tibbi, yasal, finansal vb.) yerine gecmez. Iceriklerin dogrulugu veya gerceklesecegi garanti edilmez. Sonuclar kisiden kisiye degisebilir. Lutfen bu bilgileri sagduyu ile degerlendirin.',
    'shopTitle': 'Kozmik Cüzdan',
    'shopCreditsTab': 'Jetonlar',
    'shopPremiumTab': 'Premium',
    'shopLoadingPrice': 'Fiyat hesaplanıyor...',
    'shopPriceUnavailable': 'Ürün şu anda kullanılamıyor',
    'shopPurchaseUnavailable': 'Satın alma şu anda kullanılamıyor',
    'shopProductsNotFoundHint':
        'Bu ürün şu an kullanılamıyor. Lütfen daha sonra tekrar deneyin.',
    'shopPurchasePending': 'Satın alma işleniyor...',
    'shopPurchaseVerifying': 'Satın alma doğrulanıyor...',
    'shopPurchaseVerified': 'Satın alma doğrulandı.',
    'shopRestorePurchases': 'Satın Alımları Geri Yükle',
    'shopRestoreInProgress': 'Satın alımlar geri yükleniyor...',
    'shopRestoreSuccess': 'Satın alımlar geri yüklendi.',
    'shopRestoreNoActiveSubscription': 'Aktif premium abonelik bulunamadı.',
    'shopTermsOfUse': 'Kullanım Koşulları',
    'shopPrivacyPolicy': 'Gizlilik Politikası',
    'shopSubscriptionRenewalInfo':
        'Aylık Premium aboneliği her ay otomatik yenilenir. Aboneliğini App Store hesap ayarlarından iptal edebilirsin.',
    'shopTermsAndPrivacyAgreement':
        'Satın alarak Kullanım Koşulları’nı ve Gizlilik Politikası’nı kabul etmiş olursun.',
    'shopFooterLegalText':
        'Abonelikler App Store hesabın üzerinden yönetilir ve iptal edilebilir.',
    'shopLinkOpenFailed': 'Bağlantı açılamadı. Lütfen daha sonra tekrar dene.',
    'premiumMonthlyTitle': 'Aylık Premium',
    'premiumMonthlySubtitle': 'Reklamsız Kozmik Deneyim',
    'premiumFeatureNoAds': 'Reklamsız kullanım',
    'premiumFeatureBonusCredits': 'Her ay 200 bonus jeton',
    'premiumFeatureDeepReadings': 'Daha detaylı AI yorumları',
    'premiumFeaturePersonalizedExperience': 'Kişiselleştirilmiş fal deneyimi',
    'premiumFeaturePremiumAiDepth':
        'Madam Aris & Bilge Aris premium cevap derinliği',
    'premiumCta': 'Aylık Premium’a Geç',
    'premiumBadgePopular': 'Önerilen',
    'premiumAutoRenewInfo':
        'Aylık Premium aboneliği her ay otomatik yenilenir.',
    'premiumCancelInfo':
        'Aboneliğini App Store hesap ayarlarından istediğin zaman iptal edebilirsin.',
    'premiumBonusCreditsInfo':
        'Premium üyeler her abonelik döneminde 200 bonus jeton kazanır.',
    'creditsPack50': '50 Jeton',
    'creditsPack250': '250 Jeton',
    'creditsPack1000': '1000 Jeton',
    'creditsPackSubtitle': 'Tek seferlik kozmik enerji paketi',
    'creditsConsumableInfo':
        'Jeton paketleri tek seferliktir ve premium üyelik sağlamaz.',
    'common.logout': 'Cikis',
    'common.restore': 'Restore',
    'common.select_language': 'Dil sec',
    'common.back': 'Geri',
    'common.next': 'Ileri',
    'common.save_profile': 'Profili Kaydet',
    'common.generate': 'Fal Uret',
    'common.loading': 'Yukleniyor...',
    'common.done': 'Tamam',
    'common.cancel': 'İptal',
    'common.close': 'Kapat',
    'arisTarotTitle': 'Kozmik Bilge Aris',
    'arisAssistantName': 'Bilge Aris',
    'arisLoadingSubtitle': 'Kartının enerjisini topluyor.',
    'arisTyping': '{name} yazıyor',
    'arisMessageMeta': '{name} • Şimdi',
    'arisMessageCost': 'Her mesaj 10 jeton',
    'arisQuestionHint': 'Bilgeye bir soru fısılda...',
    'coffeeTitle': 'Kahve Falı',
    'coffeeDescription':
        'Madam Aris fincanın içini, tabağını ve dış görünümünü birlikte yorumlayacak.',
    'coffeeOpenCamera': 'Kamerayı Aç',
    'coffeeChooseGallery': 'Galeriden Seç',
    'coffeeCropTitle': 'Fincanı Ortala',
    'coffeeCropInsideTitle': 'Fincanın İçini Ortala',
    'coffeeCropSaucerTitle': 'Tabağı Ortala',
    'coffeeCropCupSideTitle': 'Fincanın Dışını Ortala',
    'coffeePreparingPhoto': 'Fotoğraf hazırlanıyor...',
    'coffeeValidatingPhoto': 'Fotoğraf doğrulanıyor...',
    'coffeeStepInsideTitle': '1/3 · Fincanın İçi',
    'coffeeStepInsideDesc': 'Telveyi ve fincanın iç izlerini net göster.',
    'coffeeStepSaucerTitle': '2/3 · Fincan Tabağı',
    'coffeeStepSaucerDesc': 'Tabağın üzerindeki telve izlerini ortaya al.',
    'coffeeStepCupSideTitle': '3/3 · Fincanın Dışı',
    'coffeeStepCupSideDesc': 'Fincanın yan yüzeyini ve genel formunu göster.',
    'coffeeAddPhoto': 'Fotoğraf Ekle',
    'coffeeCaptureCompleted': 'Bu fotoğraf hazır.',
    'coffeeAllPhotosReady':
        'Üç fotoğraf hazır. Yorumlatmak için aşağıdaki butona dokun.',
    'coffeeProgressHint':
        '{count}/3 fotoğraf hazır. Analiz için üç adımı tamamla.',
    'coffeeContinue': 'Devam Et',
    'coffeeInvalidImage':
        'Bu görselde gerekli kahve fincanı detayını algılayamadık. Lütfen daha net bir fotoğraf deneyin.',
    'coffeeInvalidImageDetailed':
        'Bu görselde gerekli kahve fincanı detayını algılayamadık. Lütfen ilgili adımı daha net ve ortada olacak şekilde tekrar deneyin.',
    'coffeeCupDetected': 'Fincan algılandı',
    'coffeeWeakImageWarning':
        'Fotoğraf biraz belirsiz görünüyor ama devam edebilirsin.',
    'coffeeStartMadamAris': 'Madam Aris’e Yorumlat',
    'coffeeStartMadamArisWithCredits': 'Madam Aris’e Yorumlat · 20 Jeton',
    'coffeeReadingCostInfo':
        'Kahve falı yorumlaması 20 jetondur. Jeton yalnızca başarılı yorumda düşer.',
    'coffeeRetakePhoto': 'Yeniden Çek',
    'coffeeReselectPhoto': 'Yeniden Seç',
    'coffeeAskMadamAris': 'Madam Aris’e Yorumlat · 20 Jeton',
    'coffeeMadamArisPreparing': 'Madam Aris hazırlanıyor...',
    'coffeeNotEnoughCredits': 'Yeterli jetonun yok.',
    'coffeeReadyToAnalyze':
        'Üç fotoğraf hazır. Yorum yalnızca sen başlattığında oluşturulur.',
    'coffeeCreditInfo': '20 jeton · yalnızca başarılı yorumdan sonra düşer',
    'coffeePhotoReady': 'Fotoğraf hazır',
    'coffeePhotoNeedsRetry': 'Bu fotoğrafı yenile',
    'coffeePhotoValidating': 'Fotoğraf doğrulanıyor',
    'coffeeImageSourceCamera': 'Kamera',
    'coffeeImageSourceGallery': 'Galeri',
    'coffeeLoadingTriangleTitle': 'ÜÇ İZ · TEK YORUM',
    'coffeeLoadingTriangleSubtitle':
        'Madam Aris fincanın üç yüzünü birlikte okuyor.',
    'coffeeLoadingPhaseValidationTitle': 'Fotoğraflar doğrulanıyor...',
    'coffeeLoadingPhaseValidationSubtitle':
        'Fincanın içi, tabağı ve dış görünümü güvenle hazırlanıyor.',
    'coffeeLoadingPhaseCombiningTitle': 'Üç iz bir araya geliyor...',
    'coffeeLoadingPhaseCombiningSubtitle':
        'Telvenin işaretleri fincanın farklı yüzlerinde eşleşiyor.',
    'coffeeLoadingPhaseReadingTitle': 'Madam Aris sembolleri okuyor...',
    'coffeeLoadingPhaseReadingSubtitle':
        'Fincanın içi, tabağı ve dış izleri birlikte yorumlanıyor.',
    'coffeeLoadingPhaseLongWaitTitle': 'Yorumun incelikleri tamamlanıyor...',
    'coffeeLoadingPhaseLongWaitSubtitle':
        'Bu bazen birkaç saniye daha sürebilir. Lütfen bekle.',
    'coffeeRetake': 'Yeniden çek',
    'coffeeRetry': 'Tekrar dene',
    'coffeeCamera': 'Kamera ile çek',
    'coffeeGallery': 'Galeriden seç',
    'coffeeAnalyzingSymbols': 'Madam Aris telvedeki sembolleri çözümlüyor...',
    'coffeeAnalyzingSubtitle':
        'Fincanın içi, tabağı ve dış izleri birlikte okunuyor...',
    'coffeeMadamArisTitle': 'Madam Aris · Kahve Falı',
    'coffeeMadamArisName': 'Madam Aris',
    'coffeeMadamArisSubtitle': 'Kahve Falı Rehberi',
    'coffeeReadingReady': 'Madam Aris Kahve Falını Yorumladı',
    'coffeePreviewTitle': 'Fincanın Hazır',
    'coffeePast': 'Geçmişten Gelen İz',
    'coffeePresent': 'Şu Anki Enerji',
    'coffeeFuture': 'Yakın Dönem Mesajı',
    'coffeePermissionDenied': 'Fotoğraf seçimi için gerekli izin verilmedi.',
    'coffeeCropCancelled': 'Kırpma işlemi iptal edildi.',
    'coffeeCompressionFailed': 'Fotoğraf hazırlanamadı. Lütfen tekrar dene.',
    'coffeeValidationFailed': 'Kahve fotoğrafı doğrulanamadı',
    'coffeeValidationNoCup':
        'Fincan algılanamadı. Lütfen fincanı net şekilde göster.',
    'coffeeValidationWrongStep': 'Bu fotoğraf bu adım için uygun değil.',
    'coffeeValidationNoResidue':
        'Telve izleri net görünmüyor. Lütfen kahve izlerini daha yakından çek.',
    'coffeeValidationNoSaucer':
        'Fincan tabağı algılanamadı. Lütfen tabağı ve telve izlerini net göster.',
    'coffeeValidationEmptyCup':
        'Fincanın içinde kahve telvesi veya izleri görünmüyor. Kahve falı için telve izleri olan fincanını çekmelisin.',
    'coffeeValidationBlurry':
        'Fotoğraf bulanık görünüyor. Lütfen daha net çek.',
    'coffeeValidationTooDark':
        'Fotoğraf çok karanlık. Lütfen daha aydınlık bir yerde çek.',
    'coffeeValidationTooBright':
        'Fotoğraf çok parlak. Lütfen ışığı biraz azaltıp tekrar dene.',
    'coffeeValidationDuplicate':
        'Bu fotoğraf daha önce eklediğin görsele çok benziyor. Lütfen farklı açıdan yeni bir fotoğraf çek.',
    'coffeeValidationScreenshotOrStock':
        'Bu görsel ekran görüntüsü veya internet görseli gibi görünüyor. Lütfen fincanını doğrudan kamerayla çek.',
    'coffeeValidationScreenSpoofing':
        'Bu fincan başka bir dijital ekrandan çekilmiş gibi görünüyor. Lütfen fiziksel, gerçek bir fincan fotoğrafı çek.',
    'coffeeValidationInappropriateContent':
        'Uygunsuz içerik algılandı. Lütfen kahve falı için fiziksel fincan ve tabak fotoğrafları yükle.',
    'coffeeValidationLowConfidence':
        'Bu fotoğraf güvenle doğrulanamadı. Lütfen tekrar dene.',
    'coffeeValidationCameraRecommended':
        'En doğru kahve falı için fincanını doğrudan kamerayla çekmeni öneririz.',
    'coffeeValidationPrivacyInfo':
        'Kahve falı yorumun için seçtiğin 3 fotoğraf analiz edilir. Başarılı analiz fotoğrafları en fazla 7 gün saklanır ve istersen sonuç ekranından hemen silebilirsin.',
    'coffeeValidationLocalInfo': 'İlk görsel doğrulama cihazında yapılır.',
    'coffeeValidationBackendInfo':
        'Fal yorumunu oluşturmak için fotoğrafların güvenli şekilde analiz servisine gönderilebilir.',
    'coffeeValidationParseError':
        'Fotoğraflar doğrulanırken bir sorun oluştu. Lütfen tekrar dene.',
    'coffeePhotosRetentionInfo':
        'Yorum fotoğrafların en fazla 7 gün saklanır. Dilersen şimdi silebilirsin.',
    'coffeeDeletePhotos': 'Fotoğraflarımı Şimdi Sil',
    'coffeeDeletePhotosSuccess': 'Fotoğrafların silindi.',
    'coffeeDeletePhotosFailed': 'Fotoğraflar silinemedi. Lütfen tekrar dene.',
    'coffeeAnalysisInProgress': 'Bir kahve falı yorumun zaten hazırlanıyor.',
    'coffeeRateLimited':
        'Kısa sürede çok fazla deneme yaptın. Lütfen biraz sonra tekrar dene.',
    'coffeeReadingDisclaimer':
        'Bu yorum eğlence ve kişisel farkındalık amacıyla hazırlanmıştır; tıbbi, finansal, hukuki veya kesin gelecek tahmini içermez.',
    'coffeeReadingGeneralEnergy': 'Genel Enerji',
    'coffeeReadingSymbols': 'Telvedeki Semboller',
    'coffeeReadingSaucerSigns': 'Tabak İzleri',
    'coffeeReadingOuterCupMessage': 'Fincanın Dış Mesajı',
    'coffeeReadingPastTrace': 'Geçmişten Gelen İz',
    'coffeeReadingPresentMood': 'Şu Anki Ruh Hali',
    'coffeeReadingNearFutureMessage': 'Yakın Dönem Mesajı',
    'coffeeReadingAdvice': 'Madam Aris’in Tavsiyesi',
    'coffeeEntertainmentDisclaimer':
        'Bu yorumlar eğlence ve kişisel farkındalık amacıyla hazırlanmıştır. Tıbbi, finansal, hukuki veya kesin gelecek tahmini içermez.',
    'coffeePhotoPrivacyNote':
        'İlk fincan doğrulaması cihazında yapılır. Yorumlatmayı seçtiğinde fotoğrafların güvenli analiz servisine gönderilir ve en fazla 7 gün saklanır.',
    'coffeeChatWithMadamAris': 'Madam Aris ile Sohbet Et',
    'coffeeMessageNote': 'Kahve falı yorumlaması 20 jetondur.',
    'coffeeQuestionHint': 'Telvedeki sembolleri sor...',
    'coffeeLoadingChatSubtitle': 'Telvedeki sembolleri dinliyor.',
    'coffeeMockOpening':
        'Fincanını ve telvenin izlerini gördüm... İçte, tabakta ve dış yüzeyde birbirini tamamlayan semboller var. Bu yorum eğlence ve kişisel farkındalık amacıyla hazırlanıyor. Şimdi birlikte bu işaretlere bakalım...',
    'coffeeMockLoveReply':
        'Madam Aris fincanında kalbe benzeyen yumuşak bir açıklık görüyor. Bu, ilişkilerde acele etmeden dinlemenin ve niyetini netleştirmenin sana iyi geleceğini fısıldıyor.',
    'coffeeMockCareerReply':
        'Telvenin kenara doğru yükselen çizgileri iş ve para alanında küçük ama düzenli adımları işaret ediyor. Bu kesin bir vaat değil; sadece bugün odağını toparlaman için zarif bir hatırlatma.',
    'coffeeMockGeneralReply':
        'Fincanın genel enerjisi sakin ama hareketli. Madam Aris, bu dönemde içinden geçenleri sadeleştirmeni ve önündeki küçük işareti büyütmeden fark etmeni öneriyor.',
    'common.retry': 'Tekrar Dene',
    'profileCosmicPersonalizationTitle': 'Kozmik Kişiselleştirme',
    'profileCosmicPersonalizationSubtitle':
        'Yorumlarını sana daha uygun hale getir',
    'personalizationTitle': 'Kozmik Kişiselleştirme',
    'personalizationDescription':
        'Madam Aris ve Bilge Aris yorumlarını sana daha uygun hale getirmek için bu bilgileri kullanır.',
    'personalizationPrivacyNote':
        'Bu bilgiler yalnızca eğlence ve kişisel farkındalık amaçlı yorumları kişiselleştirmek için kullanılır.',
    'personalizationEnabledTitle': 'Kişiselleştirilmiş yorumlar',
    'personalizationEnabledSubtitle':
        'Tercihlerimin yorumlarda yumuşak bir bağlam olarak kullanılmasına izin ver.',
    'personalizationFocusAreasTitle': 'REHBERLİK ALANLARI',
    'personalizationSave': 'Değişiklikleri Kaydet',
    'personalizationSaving': 'Kaydediliyor...',
    'personalizationSaved': 'Tercihlerin güncellendi.',
    'personalizationSaveError': 'Tercihler güncellenemedi. Lütfen tekrar dene.',
    'personalizationLoadError': 'Tercihlerin yüklenemedi. Lütfen tekrar dene.',
    'personalizationUnsavedTitle': 'Değişiklikler kaydedilmedi',
    'personalizationUnsavedMessage':
        'Çıkarsan yaptığın değişiklikler kaybolacak.',
    'personalizationCancel': 'Vazgeç',
    'personalizationExit': 'Çık',
  };

  Future<void> initialize() async {
    await _loadSupportedLanguages();
    await setLanguage(AppLocale.current, notifyLocale: false);
  }

  Future<void> setLanguage(String lang, {bool notifyLocale = true}) async {
    if (notifyLocale) {
      AppLocale.set(lang);
    }
    if (!_cache.containsKey(lang)) {
      await _loadLanguage(lang);
    }
    revision.value++;
  }

  String t(String key) {
    final lang = AppLocale.current;
    final active = _cache[lang];
    if (active != null && active.containsKey(key)) return active[key]!;

    if (lang != 'en') {
      final en = _cache['en'];
      if (en != null && en.containsKey(key)) return en[key]!;
    }

    return _fallbackFor(lang)[key] ?? _fallbackEn[key] ?? key;
  }

  String nextLanguage() {
    final langs = supportedLanguages.value;
    if (langs.isEmpty) return 'en';
    final currentIdx = langs.indexOf(AppLocale.current);
    if (currentIdx < 0) return langs.first;
    return langs[(currentIdx + 1) % langs.length];
  }

  Future<void> _loadSupportedLanguages() async {
    try {
      final raw = await rootBundle.loadString('assets/locales/index.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final list = data['supportedLanguages'];
      if (list is List) {
        final langs = list
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (langs.isNotEmpty) {
          supportedLanguages.value = langs;
          return;
        }
      }
    } catch (_) {}
    supportedLanguages.value = const ['tr', 'en'];
  }

  Future<void> _loadLanguage(String lang) async {
    try {
      final raw = await rootBundle.loadString('assets/locales/$lang.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _cache[lang] = map.map((k, v) => MapEntry(k.toString(), v.toString()));
      return;
    } catch (_) {
      try {
        final fallbackRaw = await rootBundle.loadString(
          'assets/locales/en.json',
        );
        final fallback = jsonDecode(fallbackRaw) as Map<String, dynamic>;
        _cache[lang] = fallback.map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        );
        return;
      } catch (_) {}
    }
    _cache[lang] = Map<String, String>.from(_fallbackFor(lang));
  }

  Map<String, String> _fallbackFor(String lang) {
    if (lang == 'tr') return _fallbackTr;
    return _fallbackEn;
  }
}
