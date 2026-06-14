import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';
import 'app_locale.dart';

class LocalizationService {
  LocalizationService._();
  static final LocalizationService instance = LocalizationService._();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);
  final ValueNotifier<List<String>> supportedLanguages =
      ValueNotifier<List<String>>(const ['tr', 'en']);

  final Map<String, Map<String, String>> _cache = {};
  static const String _languagePrefKey = 'app_language_code';

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
    'tarot.spread.selection_hint': '{count}/{max} cards revealed.',
    'tarot.spread.continue_cta': 'CONTINUE',
    'tarot.spread.pick_another': 'PICK ANOTHER',
    'tarot.spread.cta_draw': '✦ DRAW CARD',
    'tarot.spread.cta_cancel': 'Cancel',
    'tarot.spread.cost_note': '⚡ 1 card = 5 tokens',
    'tarot.spread.free': 'Free',
    'tarot.spread.single': 'Single',
    'tarot.spread.three': '3-card',
    'tarot.spread.five': '5-card',
    'tarot.spread.seven': '7-card',
    'tarot.spread.name.single': 'Daily Guide',
    'tarot.spread.name.three': 'Time Journey',
    'tarot.spread.name.five': 'Crossroads',
    'tarot.spread.name.seven': 'Cosmic Spread',
    'tarot.spread.position.message': 'Message',
    'tarot.spread.position.past': 'Past',
    'tarot.spread.position.now': 'Now',
    'tarot.spread.position.future': 'Future',
    'tarot.spread.position.situation': 'Situation',
    'tarot.spread.position.obstacle': 'Obstacle',
    'tarot.spread.position.advice': 'Advice',
    'tarot.spread.position.pastInfluence': 'Past influence',
    'tarot.spread.position.possibleOutcome': 'Possible outcome',
    'tarot.spread.position.you': 'You',
    'tarot.spread.position.conscious': 'Conscious',
    'tarot.spread.position.subconscious': 'Subconscious',
    'tarot.spread.position.nearFuture': 'Near future',
    'tarot.spread.position.result': 'Result',
    'tarot.gate.insufficient': 'You do not have enough tokens for this spread.',
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
        'Enter your email. If it can use password sign-in, we will send a reset link. If you joined with Apple or Google, continue with that method.',
    'auth.forgot_password.email_hint': 'your@email.com',
    'auth.forgot_password.send': 'SEND RESET LINK',
    'auth.forgot_password.sending': 'SENDING...',
    'auth.forgot_password.success':
        'If this email can use password sign-in, a reset link has been sent. If you joined with Apple or Google, continue with that method.',
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
    'auth.register.disposable_email':
        'Temporary email addresses cannot be used to register.',
    'toast.warning_title': 'Notice',
    'toast.info_title': 'Info',
    'verifyEmailTitle': 'Verify Your Email',
    'verifyEmailSubtitle': 'Tap the link in your email to open your star gate.',
    'verifyEmailDescription':
        'We sent you a verification link. Please check your email and tap the link.',
    'verifyEmailSecurityTitle': 'Account security',
    'verifyEmailSecurityDescription':
        'Verifying your email helps us protect your account and provide secure access.',
    'verifyEmailSentTo': 'Link sent to',
    'verifyEmailUnknownEmail': 'Your email address',
    'verifyEmailCheckedButton': 'I Verified',
    'verifyEmailChecking': 'Checking...',
    'verifyEmailResendButton': 'Resend',
    'verifyEmailResending': 'Sending...',
    'verifyEmailChangeEmail': 'Change Email Address',
    'verifyEmailSignOut': 'Sign Out',
    'verifyEmailDeadlineInfo':
        'If you do not verify your account within 24 hours, registration may be cancelled.',
    'verifyEmailNotVerifiedYet':
        'Your email does not look verified yet. Make sure you tapped the verification link.',
    'verifyEmailVerifiedSuccess':
        'Your email is verified. You can now complete your cosmic profile.',
    'verifyEmailNetworkError':
        'Verification status could not be checked. Check your connection and try again.',
    'verifyEmailResendSuccess': 'A new verification link has been sent.',
    'verifyEmailResendError':
        'The verification link could not be sent. Please try again.',
    'verifyEmailCheckSpamTitle': 'Can’t see the email?',
    'verifyEmailCheckSpamDescription':
        'Check your Spam, Junk, or Promotions folder. Then request a new link if needed.',
    'verifyEmailWaitingTitle': 'Waiting for verification',
    'verifyEmailWaitingDescription':
        'We are checking in the background. Once you tap the link, this screen will continue automatically.',
    'verifyEmailMailNotArrived':
        'If the email does not arrive within a few minutes, check Spam/Junk too.',
    'verifyEmailManualCooldown': 'Wait a few seconds before checking again.',
    'verifyEmailCooldownInline': 'Wait {seconds}s before sending again.',
    'verifyEmailDailyLimitInline':
        'You requested too many verification links today. Please try again later.',
    'toastDuplicateSuppressed': '',
    'toastGenericInfo': 'Info',
    'legal.terms.title': 'Terms of Service',
    'legal.privacy.title': 'Privacy Policy',
    'legal.ai_notice.title': 'AI Usage Notice',
    'legal.ai_notice.section_title': 'Entertainment and personal reflection',
    'legal.ai_notice.body':
        'Tarot, coffee reading, palm reading, and other AI interpretations in Tarot AI are provided for entertainment and personal reflection. They are not medical, financial, or legal advice and do not contain certain predictions.',
    'legal.last_updated': 'Last updated: March 10, 2026',
    'legal.view_terms': 'View Terms of Service',
    'legal.view_privacy': 'View Privacy Policy',
    'onboarding.welcome.title': 'Three ways to discover yourself',
    'onboarding.welcome.subtitle': 'Cards, cup, and palm — Aris is with you.',
    'onboarding.welcome.persona_bilge_role': 'Tarot',
    'onboarding.welcome.persona_madam_role': 'Coffee & Palm',
    'onboarding.welcome.cta_start': 'Begin the journey',
    'onboarding.card_pick.title': 'Choose a card',
    'onboarding.card_pick.subtitle':
        'Three hidden cards, three paths — Tarot, Coffee Reading, or Palm Reading. Choose one and let fate pick your first reading.',
    'onboarding.card_pick.hint': 'Tap to choose',
    'onboarding.card_pick.tarot_title': 'Tarot',
    'onboarding.card_pick.tarot_desc': 'Draw one card',
    'onboarding.card_pick.tarot_persona': 'Bilge Aris',
    'onboarding.card_pick.coffee_title': 'Coffee Reading',
    'onboarding.card_pick.coffee_desc': 'Turn the cup',
    'onboarding.card_pick.coffee_persona': 'Madam Aris',
    'onboarding.card_pick.palm_title': 'Palm Reading',
    'onboarding.card_pick.palm_desc': 'Scan your palm',
    'onboarding.card_pick.palm_persona': 'Madam Aris',
    'onboarding.tarot_draw.title': 'Choose your card',
    'onboarding.tarot_draw.subtitle':
        'As the cards flow, touch the one that calls you. Bilge Aris will keep it safe for you.',
    'onboarding.tarot_draw.hint': 'Touch and choose',
    'onboarding.tarot_draw.confirmation':
        'You chose your card, {name}. Let it stay closed for now… I will ask a few more questions, then Aris will open it for you. 🔮',
    'onboarding.tarot_draw.confirmation_no_name':
        'You chose your card. Let it stay closed for now… I will ask a few more questions, then Aris will open it for you. 🔮',
    'onboarding.tarot_draw.cta': 'CONTINUE',
    'onboarding.cards.the_star': 'The Star',
    'onboarding.cards.the_sun': 'The Sun',
    'onboarding.cards.the_world': 'The World',
    'onboarding.cards.wheel_of_fortune': 'Wheel of Fortune',
    'onboarding.cards.ace_of_wands': 'Ace of Wands',
    'onboarding.cards.ace_of_cups': 'Ace of Cups',
    'onboarding.cards.the_lovers': 'The Lovers',
    'onboarding.cards.the_magician': 'The Magician',
    'onboarding.palm.title': 'Let us read your palm',
    'onboarding.palm.subtitle':
        'Madam Aris needs a brief palm view to glimpse the first signs.',
    'onboarding.palm.why_camera': 'The camera is used only to frame your palm.',
    'onboarding.palm.why_privacy':
        'The photo is processed and not stored during onboarding.',
    'onboarding.palm.why_fallback':
        'If you are not ready, another reading door opens for you.',
    'onboarding.palm.permission_cta': 'ALLOW CAMERA',
    'onboarding.palm.permission_loading': 'PREPARING...',
    'onboarding.palm.permission_denied_title': 'Camera permission is off',
    'onboarding.palm.permission_denied_body':
        'For palm reading, I need to frame your palm with the camera. You can enable permission or continue this step with cards.',
    'onboarding.palm.permission_retry': 'TRY AGAIN',
    'onboarding.palm.permission_settings': 'OPEN SETTINGS',
    'onboarding.palm.permission_fallback': 'Continue with cards',
    'onboarding.palm.camera_title': 'Show your palm',
    'onboarding.palm.camera_hint':
        'Place your palm inside the frame and keep your fingers open.',
    'onboarding.palm.frame_hint': 'Place your palm in the frame, fingers open',
    'onboarding.palm.scanning': 'Scanning your lines...',
    'onboarding.palm.confirm_title': 'I read your palm',
    'onboarding.palm.confirm_body':
        'I saw your lines, {name}... but I will keep them to myself for now. I will ask a few more questions, then Madam Aris will interpret them for you. 🤚',
    'onboarding.palm.confirm_body_no_name':
        'I saw your lines... but I will keep them to myself for now. I will ask a few more questions, then Madam Aris will interpret them for you. 🤚',
    'onboarding.palm.cta': 'CONTINUE',
    'onboarding.palm.fallback_title': 'No problem',
    'onboarding.palm.fallback_subtitle':
        'Let us not read your palm right now. I open two doors for you — choose the card that calls you and let fate decide.',
    'onboarding.palm.fallback_result': 'Fate chose {modality} for you.',
    'onboarding.coffee.title_intro': 'Hold your intention',
    'onboarding.coffee.subtitle_intro':
        'Think of the question in your heart and drink your coffee...',
    'onboarding.coffee.title_drank': 'Your coffee is finished',
    'onboarding.coffee.subtitle_drank':
        'Now close the cup onto the saucer and seal your intention.',
    'onboarding.coffee.title_settle': 'The grounds are cooling',
    'onboarding.coffee.subtitle_settle': 'The shapes are slowly forming...',
    'onboarding.coffee.title_sealed': 'Your cup is ready',
    'onboarding.coffee.subtitle_sealed':
        'Madam Aris keeps your cup closed for now.',
    'onboarding.coffee.hold_button': 'HOLD INTENTION',
    'onboarding.coffee.release_hint':
        'The cup is not empty yet — keep holding your intention.',
    'onboarding.coffee.bridge_title':
        'Complete a few steps to see your reading',
    'onboarding.coffee.bridge_subtitle':
        'Madam Aris needs to know you a little before reading your cup.',
    'onboarding.coffee.cta_drink': 'INTEND & DRINK',
    'onboarding.coffee.cta_flip': 'CLOSE THE CUP',
    'onboarding.coffee.cta_wait': 'SHAPES ARE FORMING...',
    'onboarding.coffee.cta_continue': 'CONTINUE',
    'onboarding.coffee.confirm':
        'Your cup is closed, {name}... the shapes have formed. Let it stay sealed for now; after a few questions, Madam Aris will open and read it. ☕',
    'onboarding.coffee.confirm_no_name':
        'Your cup is closed... the shapes have formed. Let it stay sealed for now; after a few questions, Madam Aris will open and read it. ☕',
    'onboarding.reveal.friend': 'traveler',
    'onboarding.reveal.persona_bilge': 'Bilge Aris',
    'onboarding.reveal.persona_madam': 'Madam Aris',
    'onboarding.reveal.status_tarot': 'reading your cards…',
    'onboarding.reveal.status_coffee': 'reading your cup…',
    'onboarding.reveal.status_palm': 'reading your palm…',
    'onboarding.reveal.status_ready': 'your reading is ready',
    'onboarding.reveal.greeting':
        'Welcome, {name}. 🌙 I am {persona}… I am opening the first signs of your path.',
    'onboarding.reveal.interpretation_tarot':
        'Your {zodiac} energy meets the light of {artifact}. In {focus}, a calm intuitive doorway begins to open.',
    'onboarding.reveal.interpretation_coffee':
        'Your {zodiac} rhythm makes the symbol of {artifact} clearer in the cup. In {focus}, there is a small but meaningful sign.',
    'onboarding.reveal.interpretation_palm':
        'Your {zodiac} frequency becomes visible through {artifact}. In {focus}, your inner voice begins to sound clearer.',
    'onboarding.reveal.interpretation_bridge':
        'The answer you seek in {focus} is not hidden in one moment, but in a few small signs coming together. With {zodiac} patience and intuition, the path softens.',
    'onboarding.reveal.closing_soft':
        '{name}, move gently. Let your heart speak without force; in {focus}, the kindest answer rises from within first.',
    'onboarding.reveal.closing_direct':
        '{name}, the sign is clear: gather scattered energy into one intention. In {focus}, the path appears as you decide.',
    'onboarding.reveal.closing_spiritual':
        '{name}, the language of the stars shows you a subtle threshold today. Your {zodiac} light carries an intuitive key into {focus}.',
    'onboarding.reveal.hook':
        'This is only the beginning… Your deeper reading is waiting in the app. 🔮',
    'onboarding.reveal.ask_label': 'ASK ARIS',
    'onboarding.reveal.gating':
        'Let us deepen this together, {name}… but first, complete your journey. 🔮',
    'onboarding.reveal.cta': 'CONTINUE',
    'onboarding.reveal.cta_after_chip': 'CONTINUE MY JOURNEY',
    'onboarding.reveal.chip.love_1': 'Who is this person?',
    'onboarding.reveal.chip.love_2': 'When will it happen?',
    'onboarding.reveal.chip.love_3': 'What about my career?',
    'onboarding.reveal.chip.career_1': 'Will I rise?',
    'onboarding.reveal.chip.career_2': 'When?',
    'onboarding.reveal.chip.career_3': 'What about love?',
    'onboarding.reveal.chip.default_1': 'What about my career?',
    'onboarding.reveal.chip.default_2': 'Who is this person?',
    'onboarding.reveal.chip.default_3': 'When will it happen?',
    'onboarding.reveal.zodiac_unknown': 'cosmic',
    'onboarding.paywall.title': 'Charge Your Cosmic Energy',
    'onboarding.paywall.subtitle':
        'Choose a credit pack for your first deep reading. No premium, no subscription; only one-time credits.',
    'onboarding.paywall.badge_popular': 'MOST POPULAR',
    'onboarding.paywall.badge_best': 'BEST VALUE',
    'onboarding.paywall.pack_title': '{amount} Credits',
    'onboarding.paywall.pack_subtitle': 'One-time reading credits',
    'onboarding.paywall.cta': 'GET {amount} CREDITS · {price}',
    'onboarding.paywall.apple_notice':
        'Purchases are charged to your Apple ID. Credit packs are one-time purchases and do not start a subscription.',
    'onboarding.paywall.retry': 'Try again',
    'onboarding.paywall.load_error':
        'Credit packs could not be loaded. Please try again.',
    'onboarding.paywall.link_error':
        'The link could not be opened. Please try again later.',
    'onboarding.account.title': 'Your journey is ready',
    'onboarding.account.subtitle':
        'Create your account so your readings, credits, and cosmic profile stay safe.',
    'onboarding.account.consent':
        'By continuing, you accept the Terms of Use, Privacy Policy, and AI data processing.',
    'onboarding.account.apple': 'Continue with Apple',
    'onboarding.account.google': 'Continue with Google',
    'onboarding.account.guest': 'Continue as guest',
    'onboarding.account.email_register': 'Sign up with email',
    'onboarding.account.login': 'Already have an account? Log in',
    'onboarding.account.auth_failed': 'Giriş yapılamadı, lütfen tekrar dene.',
    'onboarding.hero_title': 'COSMIC\nPROFILE',
    'onboarding.hero_subtitle':
        'These details are collected once so the cards can know you better.',
    'onboarding.name_label_upper': 'NAME',
    'onboarding.name_hint': 'Your name in the language of the stars...',
    'onboarding.apple_name_prompt_title': 'Complete your name',
    'onboarding.apple_name_prompt_body':
        'Apple did not share your name with the app this time. Enter your name for your cosmic profile.',
    'onboarding.apple_name_prompt_cta': 'Save',
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
    'readingRateLimited':
        'You have made too many attempts. Please try again shortly.',
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
    'messages.title': 'Cosmic Archive',
    'messages.subtitle': 'Continue your tarot and coffee readings from here.',
    'messages.empty_title': 'No saved readings yet',
    'messages.empty_body':
        'After you draw cards in Ritual and chat with Bilge Aris, your conversations appear here.',
    'messages.load_error':
        'Could not load reading history. Check your connection and try again.',
    'messages.retry': 'Try again',
    'messages.resume_error': 'Could not open this chat. Please try again.',
    'messages.thread_count': '{count} messages',
    'archive.tab.tarot': 'Tarot',
    'archive.tab.coffee': 'Coffee Reading',
    'archive.tab.palm': 'Palm Reading',
    'archive.empty.tarot': 'No tarot chats yet.',
    'archive.empty.coffee': 'No coffee readings yet.',
    'archive.empty.palm': 'Palm reading is coming soon.',
    'archive.coffee_title': 'Madam Aris · Coffee Reading',
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
    'palmHoldSteady': 'Hold your hand steady',
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
    'palmScanStart': 'Scan',
    'palmScanAnyway': 'Scan anyway',
    'palmLivenessFrame': 'Frame your hand',
    'palmLivenessInstruction': 'Open and close your fingers',
    'palmLivenessConfirm': 'Confirm Movement',
    'palmLivenessStart': 'Start Scan',
    'palmLivenessReady': 'Palm ready',
    'palmLivenessClose': 'Close your hand',
    'palmLivenessOpen': 'Now open',
    'palmLivenessTimeout': 'Try again',
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
    'notificationsCategoryTarot': 'Tarot',
    'notificationsCategoryCoffee': 'Coffee Reading',
    'notificationsCategoryPalm': 'Palm Reading',
    'notificationsEmpty': 'No notifications yet',
    'notificationSettingsTitle': 'Notification Settings',
    'notificationSettingsGeneral': 'General',
    'notificationSettingsDailyCard': 'Daily Card',
    'notificationSettingsTime': 'Notification time',
    'notificationSettingsCoffeePalm': 'Coffee & Palm Follow-ups',
    'notificationSettingsWalletOffers': 'Wallet Offers',
    'notificationSettingsEnabled': 'Notifications enabled',
    'notificationSettingsDisabled': 'Notifications disabled',
    'notificationsPrimingTitle': 'Enable notifications',
    'notificationsPrimingBody':
        'Get notified when your daily card and coffee/palm readings are ready.',
    'notificationsPrimingAllow': 'Allow',
    'notificationsPrimingNotNow': 'Not now',
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
    'shopBenefitsSectionTitle': 'Cosmic Benefits',
    'shopBenefit1Title': 'Voice Guidance',
    'shopBenefit1Desc': 'Listen to tarot readings aloud.',
    'shopBenefit2Title': 'Personal Flow',
    'shopBenefit2Desc': 'Shape your card experience with your preferences.',
    'shopBenefit3Title': 'Calm Reading',
    'shopBenefit3Desc': 'Follow interpretations in a clear, gentle flow.',
    'premiumMonthlyTitle': 'Monthly Premium',
    'premiumMonthlySubtitle': 'Ad-free Cosmic Experience',
    'premiumFeatureNoAds': 'Ad-free use',
    'premiumFeatureBonusCredits': '200 bonus tokens every month',
    'premiumFeatureDeepReadings': 'Richer card interpretations',
    'premiumFeaturePersonalizedExperience': 'Personal reading experience',
    'premiumFeaturePremiumAiDepth':
        'Richer response flow with Madam Aris & Sage Aris',
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
    'creditsPack50Feature1': '5 voice readings',
    'creditsPack50Feature2': '2 video readings',
    'creditsPack50Feature3': '4 deep chats',
    'creditsPack250Feature1': '25 voice readings',
    'creditsPack250Feature2': '10 video readings',
    'creditsPack250Feature3': '20 deep chats',
    'creditsPack1000Feature1': '100 voice readings',
    'creditsPack1000Feature2': '40 video readings',
    'creditsPack1000Feature3': '80 deep chats',
    'common.logout': 'Logout',
    'common.restore': 'Restore',
    'common.select_language': 'Select language',
    'profile.section.identity': 'PERSONAL INFO',
    'profile.section.preferences': 'PREFERENCES',
    'profile.section.purchases': 'PURCHASES',
    'profile.field.name': 'FULL NAME',
    'profile.field.birth_date': 'BIRTH DATE',
    'profile.field.email': 'EMAIL',
    'profile.language.title': 'Language',
    'profile.language.updated': 'Language set to {language}.',
    'profile.language.save_error': 'Could not save language. Please try again.',
    'profile.hero.subtitle': 'Manage your account and app preferences here.',
    'profile.name.edit_title': 'Update Name',
    'profile.name.edit_hint': 'Enter the name that appears on your profile.',
    'profile.name.placeholder': 'Full Name',
    'profile.name.updated': 'Full name updated.',
    'profile.name.save_error': 'Full name could not be saved: {error}',
    'profile.birth.updated': 'Birth date updated.',
    'profile.birth.save_error': 'Birth date could not be saved: {error}',
    'profile.email.updated': 'Email updated.',
    'profile.email.save_error': 'Email could not be saved: {error}',
    'profile.email.edit_title': 'Update Email',
    'profile.email.edit_hint': 'Enter your new email address.',
    'profile.guest.upgrade_value': 'Upgrade your profile',
    'profile.guest.upgrade_title': 'Upgrade Your Profile',
    'profile.guest.upgrade_subtitle':
        'Keep your readings, credits, and cosmic profile safe.',
    'profile.guest.upgrade_apple': 'Connect with Apple',
    'profile.guest.upgrade_google': 'Connect with Google',
    'profile.guest.upgrade_email': 'Connect with email',
    'profile.guest.email_title': 'Upgrade with email',
    'profile.guest.email_subtitle':
        'Verify your email to make your guest profile permanent.',
    'profile.guest.email_password_hint': 'Create password',
    'profile.guest.email_confirm_hint': 'Repeat password',
    'profile.guest.email_cta': 'Send Verification',
    'profile.guest.upgrade_success': 'Your profile has been upgraded.',
    'profile.guest.upgrade_email_sent': 'Verification link sent.',
    'profile.guest.upgrade_error':
        'Could not upgrade profile. Please try again.',
    'profile.guest.password_short': 'Password must be at least 6 characters.',
    'profile.guest.password_mismatch': 'Passwords do not match.',
    'profile.guest.email_in_use':
        'This email is already in use. Try signing in.',
    'profile.purchases.history': 'Purchase History',
    'profile.purchases.history_opening': 'Opening purchase history...',
    'profile.purchases.manage_subscription': 'Manage Subscription',
    'profile.purchases.manage_subscription_opening':
        'Opening subscription management...',
    'profile.purchases.restore': 'Restore Purchases',
    'profile.purchases.restore_started': 'Restore started.',
    'profile.logout.confirm_title': 'Log out?',
    'profile.logout.confirm_body': 'Your current session will be closed.',
    'profile.logout.confirm_action': 'Log Out',
    'profile.logout.failed': 'Could not log out: {error}',
    'profile.delete.confirm_title': 'Delete account?',
    'profile.delete.confirm_body': 'This action cannot be undone.',
    'profile.delete.confirm_cancel': 'Cancel',
    'profile.delete.confirm_action': 'Delete Account',
    'profile.delete.success': 'Your account was deleted.',
    'profile.delete.failed': 'Action could not be completed: {error}',
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
    'coffeeArisLookingAtCup': 'Madam Aris is looking into your cup...',
    'coffeeMadamArisGreeting': 'Hello {name}, how are you feeling today?',
    'coffeeMadamArisGreetingNoName': 'Hello, how are you feeling today?',
    'coffeeReadingError':
        'Your cup is close, but the signs blurred for a moment. Try again and I will look once more.',
    'coffeeChatReplyEmpty':
        'The cup went quiet for a moment. Ask me again and I will listen more closely.',
    'coffeeChatMessageFailed':
        'Madam Aris could not answer right now. Please try again.',
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
    'tarot.spread.selection_hint': '{count}/{max} kart acildi.',
    'tarot.spread.continue_cta': 'DEVAM ET',
    'tarot.spread.pick_another': 'BIR KART DAHA SEC',
    'tarot.spread.cta_draw': '✦ KART ÇEK',
    'tarot.spread.cta_cancel': 'Vazgeç',
    'tarot.spread.cost_note': '⚡ 1 kart = 5 jeton',
    'tarot.spread.free': 'Ücretsiz',
    'tarot.spread.single': 'Tek',
    'tarot.spread.three': '3’lü',
    'tarot.spread.five': '5’li',
    'tarot.spread.seven': '7’li',
    'tarot.spread.name.single': 'Günün Rehberi',
    'tarot.spread.name.three': 'Zaman Yolculuğu',
    'tarot.spread.name.five': 'Yol Ayrımı',
    'tarot.spread.name.seven': 'Kozmik Açılım',
    'tarot.spread.position.message': 'Mesaj',
    'tarot.spread.position.past': 'Geçmiş',
    'tarot.spread.position.now': 'Şimdi',
    'tarot.spread.position.future': 'Gelecek',
    'tarot.spread.position.situation': 'Durum',
    'tarot.spread.position.obstacle': 'Engel',
    'tarot.spread.position.advice': 'Tavsiye',
    'tarot.spread.position.pastInfluence': 'Geçmiş Etki',
    'tarot.spread.position.possibleOutcome': 'Olası Sonuç',
    'tarot.spread.position.you': 'Sen',
    'tarot.spread.position.conscious': 'Bilinç',
    'tarot.spread.position.subconscious': 'Bilinçaltı',
    'tarot.spread.position.nearFuture': 'Yakın Gelecek',
    'tarot.spread.position.result': 'Sonuç',
    'tarot.gate.insufficient': 'Bu açılım için yeterli jetonun yok.',
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
        'E-posta adresini gir. Bu e-posta şifreli girişe uygunsa yenileme bağlantısı göndereceğiz. Apple veya Google ile katıldıysan aynı yöntemle devam et.',
    'auth.forgot_password.email_hint': 'senin@adresin.com',
    'auth.forgot_password.send': 'YENİLEME BAĞLANTISI GÖNDER',
    'auth.forgot_password.sending': 'GÖNDERİLİYOR...',
    'auth.forgot_password.success':
        'Bu e-posta şifreli girişe uygunsa yenileme bağlantısı gönderildi. Apple veya Google ile katıldıysan aynı yöntemle devam et.',
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
    'auth.register.disposable_email':
        'Geçici e-posta adresleriyle kayıt yapılamaz.',
    'toast.warning_title': 'Dikkat',
    'toast.info_title': 'Bilgilendirme',
    'verifyEmailTitle': 'E-postanı Doğrula',
    'verifyEmailSubtitle':
        'Yıldız kapını açmak için e-postandaki bağlantıya dokun.',
    'verifyEmailDescription':
        'Sana bir doğrulama bağlantısı gönderdik. Lütfen e-postanı kontrol et ve bağlantıya tıkla.',
    'verifyEmailSecurityTitle': 'Hesap güvenliği',
    'verifyEmailSecurityDescription':
        'E-postanı doğrulaman, hesabını korumamıza ve sana güvenli erişim sağlamamıza yardımcı olur.',
    'verifyEmailSentTo': 'Bağlantı gönderildi',
    'verifyEmailUnknownEmail': 'E-posta adresin',
    'verifyEmailCheckedButton': 'Doğruladım',
    'verifyEmailChecking': 'Kontrol ediliyor...',
    'verifyEmailResendButton': 'Yeniden Gönder',
    'verifyEmailResending': 'Gönderiliyor...',
    'verifyEmailChangeEmail': 'E-posta Adresini Değiştir',
    'verifyEmailSignOut': 'Çıkış Yap',
    'verifyEmailDeadlineInfo':
        'Hesabını 24 saat içinde doğrulamazsan kayıt işlemin iptal edilebilir.',
    'verifyEmailNotVerifiedYet':
        'E-posta henüz doğrulanmamış görünüyor. Lütfen bağlantıya tıkladığından emin ol.',
    'verifyEmailVerifiedSuccess':
        'E-postan doğrulandı. Şimdi kozmik profilini tamamlayabilirsin.',
    'verifyEmailNetworkError':
        'Doğrulama durumu kontrol edilemedi. Bağlantını kontrol edip tekrar dene.',
    'verifyEmailResendSuccess': 'Yeni doğrulama bağlantısı gönderildi.',
    'verifyEmailResendError':
        'Doğrulama bağlantısı gönderilemedi. Lütfen tekrar dene.',
    'verifyEmailCheckSpamTitle': 'Maili göremiyor musun?',
    'verifyEmailCheckSpamDescription':
        'Spam, Gereksiz veya Tanıtımlar klasörünü kontrol et. Ardından gerekirse yeni doğrulama bağlantısı isteyebilirsin.',
    'verifyEmailWaitingTitle': 'Doğrulama bekleniyor',
    'verifyEmailWaitingDescription':
        'Arka planda kontrol ediliyor. Bağlantıya tıkladığında bu ekran otomatik olarak devam edecek.',
    'verifyEmailMailNotArrived':
        'E-posta birkaç dakika içinde gelmezse Spam/Gereksiz klasörünü kontrol etmeyi unutma.',
    'verifyEmailManualCooldown':
        'Tekrar kontrol etmek için birkaç saniye bekle.',
    'verifyEmailCooldownInline': 'Tekrar göndermek için {seconds} sn bekle.',
    'verifyEmailDailyLimitInline':
        'Bugün çok fazla doğrulama bağlantısı istedin. Lütfen daha sonra tekrar dene.',
    'toastDuplicateSuppressed': '',
    'toastGenericInfo': 'Bilgilendirme',
    'legal.terms.title': 'Kullanim Kosullari',
    'legal.privacy.title': 'Gizlilik Politikasi',
    'legal.ai_notice.title': 'AI Kullanım Notu',
    'legal.ai_notice.section_title': 'Eğlence ve kişisel farkındalık',
    'legal.ai_notice.body':
        'Tarot AI içindeki tarot, kahve falı, el falı ve diğer AI yorumları eğlence ve kişisel farkındalık amacıyla sunulur. Tıbbi, finansal veya hukuki tavsiye değildir ve kesin gelecek tahmini içermez.',
    'legal.last_updated': 'Son guncelleme: 10 Mart 2026',
    'legal.view_terms': 'Kullanim Kosullarini Gor',
    'legal.view_privacy': 'Gizlilik Politikasini Gor',
    'onboarding.welcome.title': 'Kendini keşfetmenin üç yolu',
    'onboarding.welcome.subtitle': 'Kartlar, fincan ve avucun — Aris seninle.',
    'onboarding.welcome.persona_bilge_role': 'Tarot',
    'onboarding.welcome.persona_madam_role': 'Kahve & El Falı',
    'onboarding.welcome.cta_start': 'Yolculuğa başla',
    'onboarding.card_pick.title': 'Bir kart seç',
    'onboarding.card_pick.subtitle':
        'Üç kapalı kart, üç yol — Tarot, Kahve Falı ya da El Falı. Birini seç, ilk falını kader belirlesin.',
    'onboarding.card_pick.hint': 'Dokun ve seç',
    'onboarding.card_pick.tarot_title': 'Tarot',
    'onboarding.card_pick.tarot_desc': 'Tek kart çek',
    'onboarding.card_pick.tarot_persona': 'Bilge Aris',
    'onboarding.card_pick.coffee_title': 'Kahve Falı',
    'onboarding.card_pick.coffee_desc': 'Fincanı çevir',
    'onboarding.card_pick.coffee_persona': 'Madam Aris',
    'onboarding.card_pick.palm_title': 'El Falı',
    'onboarding.card_pick.palm_desc': 'Avucunu tara',
    'onboarding.card_pick.palm_persona': 'Madam Aris',
    'onboarding.tarot_draw.title': 'Kartını seç',
    'onboarding.tarot_draw.subtitle':
        'Kartlar akarken, içine doğana dokun. Bilge Aris onu senin için saklayacak.',
    'onboarding.tarot_draw.hint': 'Dokun ve seç',
    'onboarding.tarot_draw.confirmation':
        'Kartını seçtin, {name}. Şimdilik kapalı kalsın… birkaç soru daha soracağım, sonra Aris onu senin için açacak. 🔮',
    'onboarding.tarot_draw.confirmation_no_name':
        'Kartını seçtin. Şimdilik kapalı kalsın… birkaç soru daha soracağım, sonra Aris onu senin için açacak. 🔮',
    'onboarding.tarot_draw.cta': 'DEVAM ET',
    'onboarding.cards.the_star': 'Yıldız',
    'onboarding.cards.the_sun': 'Güneş',
    'onboarding.cards.the_world': 'Dünya',
    'onboarding.cards.wheel_of_fortune': 'Kader Çarkı',
    'onboarding.cards.ace_of_wands': 'Asa Ası',
    'onboarding.cards.ace_of_cups': 'Kupa Ası',
    'onboarding.cards.the_lovers': 'Aşıklar',
    'onboarding.cards.the_magician': 'Büyücü',
    'onboarding.palm.title': 'Avucunu okuyalım',
    'onboarding.palm.subtitle':
        'Madam Aris ilk işaretleri görebilmek için avucunun kısa bir görüntüsüne ihtiyaç duyar.',
    'onboarding.palm.why_camera':
        'Kamera yalnızca avucunu çerçevelemek için kullanılır.',
    'onboarding.palm.why_privacy':
        'Fotoğraf işlenir ve onboarding sırasında saklanmaz.',
    'onboarding.palm.why_fallback':
        'Hazır değilsen sana başka bir fal kapısı açılır.',
    'onboarding.palm.permission_cta': 'KAMERAYA İZİN VER',
    'onboarding.palm.permission_loading': 'HAZIRLANIYOR...',
    'onboarding.palm.permission_denied_title': 'Kamera izni kapalı',
    'onboarding.palm.permission_denied_body':
        'El falı için avucunu kamerayla çerçevelemem gerekiyor. İzni açabilir ya da bu adımı kartlarla sürdürebilirsin.',
    'onboarding.palm.permission_retry': 'TEKRAR DENE',
    'onboarding.palm.permission_settings': 'AYARLARI AÇ',
    'onboarding.palm.permission_fallback': 'Kartlarla devam et',
    'onboarding.palm.camera_title': 'Avucunu göster',
    'onboarding.palm.camera_hint':
        'Avucunu çerçeveye yerleştir, parmaklarını açık tut.',
    'onboarding.palm.frame_hint': 'Avucunu çerçeveye yerleştir, parmaklar açık',
    'onboarding.palm.scanning': 'Çizgilerin taranıyor...',
    'onboarding.palm.confirm_title': 'Avucunu okudum',
    'onboarding.palm.confirm_body':
        'Çizgilerini gördüm, {name}... ama şimdilik kendime saklayayım. Birkaç soru daha soracağım, sonra Madam Aris senin için yorumlayacak. 🤚',
    'onboarding.palm.confirm_body_no_name':
        'Çizgilerini gördüm... ama şimdilik kendime saklayayım. Birkaç soru daha soracağım, sonra Madam Aris senin için yorumlayacak. 🤚',
    'onboarding.palm.cta': 'DEVAM ET',
    'onboarding.palm.fallback_title': 'Sorun değil',
    'onboarding.palm.fallback_subtitle':
        'Avucunu şimdi okumayalım. Sana iki kapı açıyorum — içine doğan kartı seç, ne çıkacağını kader söylesin.',
    'onboarding.palm.fallback_result': 'Kader senin için {modality} dedi.',
    'onboarding.coffee.title_intro': 'Niyetini tut',
    'onboarding.coffee.subtitle_intro':
        'Aklından geçen soruyu düşün ve kahveni iç...',
    'onboarding.coffee.title_drank': 'Kahven bitti',
    'onboarding.coffee.subtitle_drank':
        'Şimdi fincanı tabağa kapat ve niyetini mühürle.',
    'onboarding.coffee.title_settle': 'Telve soğuyor',
    'onboarding.coffee.subtitle_settle': 'Şekiller yavaşça oluşuyor...',
    'onboarding.coffee.title_sealed': 'Fincanın hazır',
    'onboarding.coffee.subtitle_sealed':
        'Madam Aris fincanını şimdilik kapalı tutuyor.',
    'onboarding.coffee.hold_button': 'NİYET TUT',
    'onboarding.coffee.release_hint':
        'Fincan henüz boşalmadı — niyetini tutmaya devam et.',
    'onboarding.coffee.bridge_title':
        'Yorumunu görmek için birkaç adımı tamamla',
    'onboarding.coffee.bridge_subtitle':
        'Madam Aris fincanını okuyabilmek için önce seni biraz tanımalı.',
    'onboarding.coffee.cta_drink': 'NİYET TUT & İÇ',
    'onboarding.coffee.cta_flip': 'FİNCANI KAPAT',
    'onboarding.coffee.cta_wait': 'ŞEKİLLER OLUŞUYOR...',
    'onboarding.coffee.cta_continue': 'DEVAM ET',
    'onboarding.coffee.confirm':
        'Fincanın kapandı, {name}... şekiller oluştu. Şimdilik kapalı kalsın; birkaç soru sonra Madam Aris açıp okuyacak. ☕',
    'onboarding.coffee.confirm_no_name':
        'Fincanın kapandı... şekiller oluştu. Şimdilik kapalı kalsın; birkaç soru sonra Madam Aris açıp okuyacak. ☕',
    'onboarding.reveal.friend': 'yolcu',
    'onboarding.reveal.persona_bilge': 'Bilge Aris',
    'onboarding.reveal.persona_madam': 'Madam Aris',
    'onboarding.reveal.status_tarot': 'kartlarını okuyor…',
    'onboarding.reveal.status_coffee': 'fincanını okuyor…',
    'onboarding.reveal.status_palm': 'avucunu okuyor…',
    'onboarding.reveal.status_ready': 'okuman hazır',
    'onboarding.reveal.greeting':
        'Hoşgeldin {name}. 🌙 Ben {persona}… Yolunun ilk işaretlerini birlikte açıyorum.',
    'onboarding.reveal.interpretation_tarot':
        '{zodiac} enerjin {artifact} kartının ışığıyla birleşiyor. {focus} alanında sezgisel ama sakin bir kapı aralanıyor.',
    'onboarding.reveal.interpretation_coffee':
        '{zodiac} ritmin fincandaki {artifact} sembolünü daha görünür kılıyor. {focus} konusunda küçük ama anlamlı bir haber izi var.',
    'onboarding.reveal.interpretation_palm':
        '{zodiac} frekansın {artifact} üzerinde belirginleşiyor. {focus} alanında iç sesini daha net duyacağın bir dönem başlıyor.',
    'onboarding.reveal.interpretation_bridge':
        '{focus} için aradığın cevap tek bir anda değil, birkaç küçük işaretin birleşiminde saklı. {zodiac} doğan sabrı ve sezgiyi aynı anda kullanınca yol yumuşar.',
    'onboarding.reveal.closing_soft':
        '{name}, acele etmeden ilerle. Kalbinin bildiği şeyi zorlamadan duy; {focus} alanında en şefkatli cevap önce içeriden gelir.',
    'onboarding.reveal.closing_direct':
        '{name}, işaret net: dağınık enerjiyi tek niyete indir. {focus} alanında karar verdikçe yol da belirginleşir.',
    'onboarding.reveal.closing_spiritual':
        '{name}, yıldızların dili bugün sana ince bir eşik gösteriyor. {zodiac} ışığın {focus} kapısında sezgisel bir anahtar taşıyor.',
    'onboarding.reveal.hook':
        'Bu yalnızca bir başlangıç… Derin okuman uygulamada seni bekliyor. 🔮',
    'onboarding.reveal.ask_label': 'ARİS\'E SOR',
    'onboarding.reveal.gating':
        'Bunu birlikte derinleştirelim, {name}… ama önce yolculuğunu tamamlayalım. 🔮',
    'onboarding.reveal.cta': 'DEVAM ET',
    'onboarding.reveal.cta_after_chip': 'YOLCULUĞUMA DEVAM ET',
    'onboarding.reveal.chip.love_1': 'Bu kişi kim?',
    'onboarding.reveal.chip.love_2': 'Ne zaman olacak?',
    'onboarding.reveal.chip.love_3': 'Peki ya kariyerim?',
    'onboarding.reveal.chip.career_1': 'Yükselir miyim?',
    'onboarding.reveal.chip.career_2': 'Ne zaman?',
    'onboarding.reveal.chip.career_3': 'Peki ya aşk?',
    'onboarding.reveal.chip.default_1': 'Peki ya kariyerim?',
    'onboarding.reveal.chip.default_2': 'Bu kişi kim?',
    'onboarding.reveal.chip.default_3': 'Ne zaman olacak?',
    'onboarding.reveal.zodiac_unknown': 'kozmik',
    'onboarding.paywall.title': 'Kozmik Enerjini Yükle',
    'onboarding.paywall.subtitle':
        'İlk derin okuman için kredi paketini seç. Premium yok, abonelik yok; yalnızca tek seferlik kredi.',
    'onboarding.paywall.badge_popular': 'EN POPÜLER',
    'onboarding.paywall.badge_best': 'EN AVANTAJLI',
    'onboarding.paywall.pack_title': '{amount} Kredi',
    'onboarding.paywall.pack_subtitle': 'Tek seferlik okuma kredisi',
    'onboarding.paywall.cta': '{amount} KREDİ AL · {price}',
    'onboarding.paywall.apple_notice':
        'Satın alma Apple Kimliğine geçilir. Kredi paketleri tek seferliktir ve abonelik başlatmaz.',
    'onboarding.paywall.retry': 'Tekrar dene',
    'onboarding.paywall.load_error':
        'Kredi paketleri yüklenemedi. Lütfen tekrar dene.',
    'onboarding.paywall.link_error':
        'Bağlantı açılamadı. Lütfen daha sonra tekrar dene.',
    'onboarding.account.title': 'Yolculuğun hazır',
    'onboarding.account.subtitle':
        'Hesabını oluştur; falların, kredilerin ve kozmik profilin kaybolmasın.',
    'onboarding.account.consent':
        'Devam ederek Kullanım Koşulları, Gizlilik Politikası ve yapay zekâ ile veri işlemeyi kabul etmiş olursun.',
    'onboarding.account.apple': 'Apple ile devam et',
    'onboarding.account.google': 'Google ile devam et',
    'onboarding.account.guest': 'Misafir olarak devam et',
    'onboarding.account.email_register': 'E-posta ile kayıt ol',
    'onboarding.account.login': 'Zaten hesabın var mı? Giriş yap',
    'onboarding.account.auth_failed': 'Giriş yapılamadı, lütfen tekrar dene.',
    'onboarding.hero_title': 'KOZMIK\nPROFIL',
    'onboarding.hero_subtitle':
        'Bu bilgiler yalnizca bir kez alinir. Kartlar seni daha iyi tanisin.',
    'onboarding.name_label_upper': 'ADIN',
    'onboarding.name_hint': 'Goklerin diliyle ismin...',
    'onboarding.apple_name_prompt_title': 'Adını tamamla',
    'onboarding.apple_name_prompt_body':
        'Apple bu girişte adını uygulamaya iletmedi. Kozmik profilin için adını yaz.',
    'onboarding.apple_name_prompt_cta': 'Kaydet',
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
    'readingRateLimited':
        'Cok fazla deneme yaptiniz, lutfen birazdan tekrar deneyin.',
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
    'messages.title': 'Kozmik Arşiv',
    'messages.subtitle': 'Tarot ve kahve falı yorumlarına buradan devam et.',
    'messages.empty_title': 'Henüz kayıtlı yorum yok',
    'messages.empty_body':
        'Ritüelden kart çekip Bilge Aris ile konuştuğunda sohbetlerin burada saklanır.',
    'messages.load_error':
        'Yorum geçmişi yüklenemedi. Bağlantını kontrol edip tekrar dene.',
    'messages.retry': 'Tekrar dene',
    'messages.resume_error': 'Sohbet yüklenemedi. Lütfen tekrar dene.',
    'messages.thread_count': '{count} mesaj',
    'archive.tab.tarot': 'Tarot',
    'archive.tab.coffee': 'Kahve Falı',
    'archive.tab.palm': 'El Falı',
    'archive.empty.tarot': 'Henüz tarot sohbetin yok.',
    'archive.empty.coffee': 'Henüz kahve falı yorumun yok.',
    'archive.empty.palm': 'El falı yakında burada olacak.',
    'archive.coffee_title': 'Madam Aris · Kahve Falı',
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
    'palmHoldSteady': 'Elini sabit tut',
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
    'palmScanStart': 'Tara',
    'palmScanAnyway': 'Yine de tara',
    'palmLivenessFrame': 'Eli çerçeveye al',
    'palmLivenessInstruction': 'Parmaklarını aç-kapat',
    'palmLivenessConfirm': 'Hareketi Onayla',
    'palmLivenessStart': 'Taramayı Başlat',
    'palmLivenessReady': 'Avuç hazır',
    'palmLivenessClose': 'Elini kapat',
    'palmLivenessOpen': 'Şimdi aç',
    'palmLivenessTimeout': 'Tekrar dene',
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
    'notificationsCategoryTarot': 'Tarot',
    'notificationsCategoryCoffee': 'Kahve Falı',
    'notificationsCategoryPalm': 'El Falı',
    'notificationsEmpty': 'Henüz bildirim yok',
    'notificationSettingsTitle': 'Bildirim Ayarları',
    'notificationSettingsGeneral': 'Genel',
    'notificationSettingsDailyCard': 'Günün Kartı',
    'notificationSettingsTime': 'Bildirim saati',
    'notificationSettingsCoffeePalm': 'Kahve & El Falı Takibi',
    'notificationSettingsWalletOffers': 'Cüzdan Teklifleri',
    'notificationSettingsEnabled': 'Bildirimler açık',
    'notificationSettingsDisabled': 'Bildirimler kapalı',
    'notificationsPrimingTitle': 'Bildirimlere izin ver',
    'notificationsPrimingBody':
        'Günün kartı, kahve ve el falı yorumların hazır olduğunda haberdar ol.',
    'notificationsPrimingAllow': 'İzin ver',
    'notificationsPrimingNotNow': 'Şimdi değil',
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
    'shopBenefitsSectionTitle': 'Kozmik Ayrıcalıklar',
    'shopBenefit1Title': 'Sesli Rehberlik',
    'shopBenefit1Desc': 'Tarot yorumlarını sesli dinle.',
    'shopBenefit2Title': 'Kişisel Akış',
    'shopBenefit2Desc': 'Kart deneyimini tercihlerinle şekillendir.',
    'shopBenefit3Title': 'Sakin Okuma',
    'shopBenefit3Desc': 'Yorumları net ve yumuşak bir akışta takip et.',
    'premiumMonthlyTitle': 'Aylık Premium',
    'premiumMonthlySubtitle': 'Reklamsız Kozmik Deneyim',
    'premiumFeatureNoAds': 'Reklamsız kullanım',
    'premiumFeatureBonusCredits': 'Her ay 200 bonus jeton',
    'premiumFeatureDeepReadings': 'Daha detaylı kart yorumları',
    'premiumFeaturePersonalizedExperience': 'Kişisel fal deneyimi',
    'premiumFeaturePremiumAiDepth':
        'Madam Aris & Bilge Aris için zengin cevap akışı',
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
    'creditsPack50Feature1': '5 sesli yorum',
    'creditsPack50Feature2': '2 görüntülü görüşme',
    'creditsPack50Feature3': '4 derin sohbet',
    'creditsPack250Feature1': '25 sesli yorum',
    'creditsPack250Feature2': '10 görüntülü görüşme',
    'creditsPack250Feature3': '20 derin sohbet',
    'creditsPack1000Feature1': '100 sesli yorum',
    'creditsPack1000Feature2': '40 görüntülü görüşme',
    'creditsPack1000Feature3': '80 derin sohbet',
    'common.logout': 'Cikis',
    'common.restore': 'Restore',
    'common.select_language': 'Dil sec',
    'profile.section.identity': 'KISISEL BILGILER',
    'profile.section.preferences': 'TERCIHLER',
    'profile.section.purchases': 'SATIN ALIMLAR',
    'profile.field.name': 'AD SOYAD',
    'profile.field.birth_date': 'DOGUM TARIHI',
    'profile.field.email': 'E-POSTA',
    'profile.language.title': 'Dil',
    'profile.language.updated': 'Dil "{language}" olarak guncellendi.',
    'profile.language.save_error': 'Dil kaydedilemedi. Lutfen tekrar dene.',
    'profile.hero.subtitle':
        'Hesabini ve uygulama tercihlerini buradan yonetebilirsin',
    'profile.name.edit_title': 'Adini Guncelle',
    'profile.name.edit_hint': 'Profilde gorunecek adini yaz.',
    'profile.name.placeholder': 'Ad Soyad',
    'profile.name.updated': 'Ad soyad guncellendi.',
    'profile.name.save_error': 'Ad soyad kaydedilemedi: {error}',
    'profile.birth.updated': 'Dogum tarihi guncellendi.',
    'profile.birth.save_error': 'Dogum tarihi kaydedilemedi: {error}',
    'profile.email.updated': 'E-posta guncellendi.',
    'profile.email.save_error': 'E-posta kaydedilemedi: {error}',
    'profile.email.edit_title': 'E-posta Guncelle',
    'profile.email.edit_hint': 'Yeni e-posta adresini gir.',
    'profile.guest.upgrade_value': 'Profilini yukselt',
    'profile.guest.upgrade_title': 'Profilini Yukselt',
    'profile.guest.upgrade_subtitle':
        'Fal gecmisin, jetonlarin ve kozmik profilin kaybolmasin.',
    'profile.guest.upgrade_apple': 'Apple ile bagla',
    'profile.guest.upgrade_google': 'Google ile bagla',
    'profile.guest.upgrade_email': 'E-posta ile bagla',
    'profile.guest.email_title': 'E-posta ile yukselt',
    'profile.guest.email_subtitle':
        'E-postani dogrulayarak misafir profilini kalici hale getir.',
    'profile.guest.email_password_hint': 'Sifre olustur',
    'profile.guest.email_confirm_hint': 'Sifreyi tekrar gir',
    'profile.guest.email_cta': 'Dogrulama Gonder',
    'profile.guest.upgrade_success': 'Profilin yukseltildi.',
    'profile.guest.upgrade_email_sent': 'Dogrulama baglantisi gonderildi.',
    'profile.guest.upgrade_error': 'Profil yukseltilemedi. Lutfen tekrar dene.',
    'profile.guest.password_short': 'Sifre en az 6 karakter olmali.',
    'profile.guest.password_mismatch': 'Sifreler eslesmiyor.',
    'profile.guest.email_in_use':
        'Bu e-posta zaten kullaniliyor. Giris yapmayi dene.',
    'profile.purchases.history': 'Satin Alim Gecmisi',
    'profile.purchases.history_opening': 'Satin alim gecmisi aciliyor...',
    'profile.purchases.manage_subscription': 'Aboneligi Yonet',
    'profile.purchases.manage_subscription_opening':
        'Abonelik yonetimi aciliyor...',
    'profile.purchases.restore': 'Satin Alimlari Geri Yukle',
    'profile.purchases.restore_started': 'Geri yukleme baslatildi.',
    'profile.logout.confirm_title': 'Cikis yapilsin mi?',
    'profile.logout.confirm_body': 'Mevcut oturum kapatilacak.',
    'profile.logout.confirm_action': 'Cikis Yap',
    'profile.logout.failed': 'Cikis yapilamadi: {error}',
    'profile.delete.confirm_title': 'Hesap silinsin mi?',
    'profile.delete.confirm_body': 'Bu islem geri alinamaz.',
    'profile.delete.confirm_cancel': 'Vazgec',
    'profile.delete.confirm_action': 'Hesabi Sil',
    'profile.delete.success': 'Hesabin silindi.',
    'profile.delete.failed': 'Islem tamamlanamadi: {error}',
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
    'coffeeArisLookingAtCup': 'Madam Aris fincanına bakıyor...',
    'coffeeMadamArisGreeting':
        'Merhaba {name}, bugün kendini nasıl hissediyorsun?',
    'coffeeMadamArisGreetingNoName':
        'Merhaba, bugün kendini nasıl hissediyorsun?',
    'coffeeReadingError':
        'Fincanın çok yakın, ama işaretler bir anlığına bulanıklaştı. Tekrar dene; yeniden bakacağım.',
    'coffeeChatReplyEmpty':
        'Fincan bir anlığına sessizleşti. Yeniden sor; daha yakından dinleyeceğim.',
    'coffeeChatMessageFailed':
        'Madam Aris şu anda yanıt veremedi. Lütfen tekrar dene.',
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
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_languagePrefKey);
    if (stored != null && AppLanguage.isSupported(stored)) {
      await setLanguage(stored);
      return;
    }
    await setLanguage(AppLocale.current);
  }

  Future<void> setLanguage(String lang, {bool notifyLocale = true}) async {
    final code = AppLanguage.normalize(lang);
    if (!AppLanguage.isSupported(code)) return;
    if (!_cache.containsKey(code)) {
      await _loadLanguage(code);
    }
    if (notifyLocale && AppLocale.current != code) {
      AppLocale.set(code);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePrefKey, code);
    revision.value++;
  }

  Future<void> applyUserLanguage(String? lang) async {
    final code = AppLanguage.normalize(lang);
    if (!AppLanguage.isSupported(code)) return;
    if (code == AppLocale.current) return;
    await setLanguage(code);
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
