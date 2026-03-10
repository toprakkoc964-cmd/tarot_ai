import 'package:flutter/material.dart';

import '../../core/app_locale.dart';
import '../../core/app_texts.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = AppLocale.current;
    final sections = _termsSections(lang);
    return _LegalScaffold(
      title: AppTexts.t('legal.terms.title'),
      sections: sections,
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = AppLocale.current;
    final sections = _privacySections(lang);
    return _LegalScaffold(
      title: AppTexts.t('legal.privacy.title'),
      sections: sections,
    );
  }
}

class _LegalScaffold extends StatelessWidget {
  const _LegalScaffold({
    required this.title,
    required this.sections,
  });

  final String title;
  final List<_LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Text(
              AppTexts.t('legal.last_updated'),
              style: Theme.of(context).textTheme.bodySmall,
            );
          }
          final section = sections[index - 1];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                section.body,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection(this.title, this.body);

  final String title;
  final String body;
}

List<_LegalSection> _termsSections(String lang) {
  if (lang == 'tr') {
    return const [
      _LegalSection(
        '1. Hizmetin Kapsami',
        'Tarot AI, eglence ve kisisel farkindalik amacli dijital tarot yorumlari sunar. '
            'Uygulama tibbi, hukuki veya finansal tavsiye vermez.',
      ),
      _LegalSection(
        '2. Hesap ve Guvenlik',
        'Hesap bilgilerinin dogrulugu ve guvenligi kullanicinin sorumlulugundadir. '
            'Supheli kullanim tespit edilirse hesap erisimi gecici olarak kisitlanabilir.',
      ),
      _LegalSection(
        '3. Kredi ve Satin Alma',
        'Uygulama ici krediler iade edilmez nitelikte olabilir. '
            'Satin alma ve geri yukleme islemleri App Store kurallarina tabidir.',
      ),
      _LegalSection(
        '4. Kabul Edilebilir Kullanim',
        'Servisi kotuye kullanmak, otomasyonla suistimal etmek veya baska kullanicilarin '
            'erisimini engellemek yasaktir.',
      ),
      _LegalSection(
        '5. Sorumlulugun Sinirlandirilmasi',
        'Tarot AI, uygulamanin kesintisiz veya hatasiz calisacagini garanti etmez. '
            'Olasi veri kaybi veya dolayli zararlardan sorumlu degildir.',
      ),
      _LegalSection(
        '6. Guncellemeler',
        'Bu kosullar zaman zaman guncellenebilir. Uygulamayi kullanmaya devam etmek '
            'guncel kosullarin kabul edildigi anlamina gelir.',
      ),
    ];
  }

  return const [
    _LegalSection(
      '1. Scope of Service',
      'Tarot AI provides digital tarot readings for entertainment and personal reflection. '
          'It does not provide medical, legal, or financial advice.',
    ),
    _LegalSection(
      '2. Account and Security',
      'You are responsible for your account accuracy and security. '
          'We may temporarily restrict access if suspicious activity is detected.',
    ),
    _LegalSection(
      '3. Credits and Purchases',
      'In-app credits may be non-refundable. '
          'Purchases and restore flows are subject to App Store policies.',
    ),
    _LegalSection(
      '4. Acceptable Use',
      'Abuse of the service, automated exploitation, or disrupting access for others is prohibited.',
    ),
    _LegalSection(
      '5. Limitation of Liability',
      'Tarot AI does not guarantee uninterrupted or error-free operation '
          'and is not liable for indirect damages.',
    ),
    _LegalSection(
      '6. Updates',
      'These terms may be updated from time to time. '
          'Continued use means acceptance of the latest terms.',
    ),
  ];
}

List<_LegalSection> _privacySections(String lang) {
  if (lang == 'tr') {
    return const [
      _LegalSection(
        '1. Toplanan Veriler',
        'Hesap bilgileri (e-posta), profil verileri (isim, dogum tarihi, meslek) ve '
            'uygulama ici islem kayitlari toplanabilir.',
      ),
      _LegalSection(
        '2. Veri Kullanim Amaci',
        'Veriler; kimlik dogrulama, kisisellestirilmis yorum uretimi, kredi yonetimi '
            've teknik destek amaclariyla kullanilir.',
      ),
      _LegalSection(
        '3. Saklama ve Guvenlik',
        'Veriler Firebase altyapisinda saklanir. '
            'Makbul teknik ve organizasyonel onlemlerle korunur.',
      ),
      _LegalSection(
        '4. Ucuncu Taraf Servisler',
        'OpenAI, ElevenLabs, Apple ve Firebase gibi servis saglayicilar '
            'islemlerin bir kismini teknik olarak gerceklestirebilir.',
      ),
      _LegalSection(
        '5. Kullanici Haklari',
        'Hesabinizdaki verilerin duzeltilmesini veya silinmesini talep edebilirsiniz. '
            'Yasal zorunluluklar sakli kalmak kaydiyla talepler degerlendirilir.',
      ),
      _LegalSection(
        '6. Iletisim',
        'Gizlilikle ilgili talepleriniz icin uygulama icinden destek kanallarina ulasabilirsiniz.',
      ),
    ];
  }

  return const [
    _LegalSection(
      '1. Data We Collect',
      'We may collect account details (email), profile data (name, birth date, occupation), '
          'and in-app transaction records.',
    ),
    _LegalSection(
      '2. Purpose of Processing',
      'Data is used for authentication, personalized reading generation, '
          'credit management, and support.',
    ),
    _LegalSection(
      '3. Storage and Security',
      'Data is stored on Firebase infrastructure and protected with '
          'reasonable technical and organizational safeguards.',
    ),
    _LegalSection(
      '4. Third-party Services',
      'Providers such as OpenAI, ElevenLabs, Apple, and Firebase may process '
          'data as part of service delivery.',
    ),
    _LegalSection(
      '5. User Rights',
      'You may request correction or deletion of your account data. '
          'Requests are processed subject to legal obligations.',
    ),
    _LegalSection(
      '6. Contact',
      'For privacy-related requests, please use the support channels inside the app.',
    ),
  ];
}
