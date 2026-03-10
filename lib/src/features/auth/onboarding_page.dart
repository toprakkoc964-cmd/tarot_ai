import 'package:flutter/material.dart';

import '../../core/app_texts.dart';
import '../../core/language_picker_button.dart';
import '../../core/localization_service.dart';
import '../../core/tarot_functions_client.dart';
import 'auth_service.dart';
import 'legal_pages.dart';
import 'onboarding_payload.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.authService,
    required this.uid,
  });

  final AuthService authService;
  final String uid;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _client = TarotFunctionsClient();
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _occupationController = TextEditingController();
  final _birthTimeController = TextEditingController();
  final _birthCityController = TextEditingController();

  String _lang = 'tr';
  String _selectedPersonaId = 'emilia';
  bool _privacy = false;
  bool _terms = false;
  bool _aiConsent = false;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _occupationController.dispose();
    _birthTimeController.dispose();
    _birthCityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty ||
        _birthDateController.text.trim().isEmpty ||
        _occupationController.text.trim().isEmpty) {
      _showError(AppTexts.t('error.profile_required'));
      return;
    }
    if (!_privacy || !_terms || !_aiConsent) {
      _showError(AppTexts.t('error.accept_terms'));
      return;
    }

    setState(() => _loading = true);
    try {
      await _client.saveOnboardingProfile(
        OnboardingPayload(
          name: _nameController.text.trim(),
          birthDate: _birthDateController.text.trim(),
          occupation: _occupationController.text.trim(),
          birthTime: _birthTimeController.text.trim().isEmpty
              ? null
              : _birthTimeController.text.trim(),
          birthCity: _birthCityController.text.trim().isEmpty
              ? null
              : _birthCityController.text.trim(),
          privacyAccepted: _privacy,
          termsAccepted: _terms,
          aiProcessingAccepted: _aiConsent,
          lang: _lang,
          selectedPersonaId: _selectedPersonaId,
        ),
      );
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTexts.t('onboarding.title')),
        actions: [
          LanguagePickerButton(
            onSelected: (lang) async {
              await LocalizationService.instance.setLanguage(lang);
              if (mounted) {
                setState(() {
                  _lang = lang;
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => widget.authService.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration:
                  InputDecoration(labelText: AppTexts.t('onboarding.name')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _birthDateController,
              decoration: InputDecoration(
                labelText: AppTexts.t('onboarding.birth_date'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _occupationController,
              decoration:
                  InputDecoration(labelText: AppTexts.t('onboarding.occupation')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _birthTimeController,
              decoration: InputDecoration(
                labelText: AppTexts.t('onboarding.birth_time_optional'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _birthCityController,
              decoration: InputDecoration(
                labelText: AppTexts.t('onboarding.birth_city_optional'),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _lang,
              decoration:
                  InputDecoration(labelText: AppTexts.t('onboarding.language')),
              items: LocalizationService.instance.supportedLanguages.value
                  .map(
                    (lang) => DropdownMenuItem(
                      value: lang,
                      child: Text(lang.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _lang = value ?? 'tr');
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedPersonaId,
              decoration:
                  InputDecoration(labelText: AppTexts.t('onboarding.persona')),
              items: [
                DropdownMenuItem(
                  value: 'emilia',
                  child: Text(AppTexts.t('onboarding.persona.emilia')),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _selectedPersonaId = value ?? 'emilia'),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _privacy,
              onChanged: (value) => setState(() => _privacy = value ?? false),
              title: Text(AppTexts.t('onboarding.consent.privacy')),
              subtitle: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyPage(),
                      ),
                    );
                  },
                  child: Text(AppTexts.t('legal.view_privacy')),
                ),
              ),
            ),
            CheckboxListTile(
              value: _terms,
              onChanged: (value) => setState(() => _terms = value ?? false),
              title: Text(AppTexts.t('onboarding.consent.terms')),
              subtitle: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TermsOfServicePage(),
                      ),
                    );
                  },
                  child: Text(AppTexts.t('legal.view_terms')),
                ),
              ),
            ),
            CheckboxListTile(
              value: _aiConsent,
              onChanged: (value) => setState(() => _aiConsent = value ?? false),
              title: Text(AppTexts.t('onboarding.consent.ai')),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(AppTexts.t('common.save_profile')),
            ),
          ],
        ),
      ),
    );
  }
}

