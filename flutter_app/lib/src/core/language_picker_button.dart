import 'package:flutter/material.dart';

import 'app_locale.dart';
import 'app_texts.dart';
import 'localization_service.dart';

class LanguagePickerButton extends StatelessWidget {
  const LanguagePickerButton({
    super.key,
    required this.onSelected,
    this.iconColor,
  });

  final Future<void> Function(String lang) onSelected;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.language, color: iconColor),
      onPressed: () async {
        final current = LocalizationService.instance.supportedLanguages.value;
        if (current.isEmpty) return;

        final selected = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: const Color(0xFF1A1022),
          builder: (sheetContext) {
            final active = AppLocale.current;
            final currentLang =
                LocalizationService.instance.supportedLanguages.value.contains(
              active,
            )
                    ? active
                    : 'en';

            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: Text(
                      AppTexts.t('common.select_language'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  ...current.map(
                    (lang) => ListTile(
                      title: Text(
                        _languageName(lang),
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: lang == currentLang
                          ? const Icon(Icons.check, color: Colors.greenAccent)
                          : null,
                      onTap: () => Navigator.of(sheetContext).pop(lang),
                    ),
                  ),
                ],
              ),
            );
          },
        );

        if (selected != null) {
          await onSelected(selected);
        }
      },
    );
  }

  String _languageName(String code) {
    switch (code) {
      case 'tr':
        return 'Turkce';
      case 'en':
        return 'English';
      case 'de':
        return 'Deutsch';
      case 'fr':
        return 'Francais';
      case 'es':
        return 'Espanol';
      default:
        return code.toUpperCase();
    }
  }
}
