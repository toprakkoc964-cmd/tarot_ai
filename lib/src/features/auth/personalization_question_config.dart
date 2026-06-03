import 'package:flutter/material.dart';

enum PersonalizationQuestionType { singleChoice, multipleChoice }

class PersonalizationOptionConfig {
  const PersonalizationOptionConfig({
    required this.value,
    required this.labelKey,
    required this.icon,
  });

  final String value;
  final String labelKey;
  final IconData icon;
}

class PersonalizationQuestionConfig {
  const PersonalizationQuestionConfig({
    required this.id,
    required this.titleKey,
    required this.type,
    required this.options,
    this.subtitleKey,
  });

  final String id;
  final String titleKey;
  final String? subtitleKey;
  final PersonalizationQuestionType type;
  final List<PersonalizationOptionConfig> options;

  bool get allowMultiple => type == PersonalizationQuestionType.multipleChoice;
}

class PersonalizationQuestions {
  const PersonalizationQuestions._();

  static const relationshipStatus = PersonalizationQuestionConfig(
    id: 'relationshipStatus',
    titleKey: 'onboarding.step2.relationship',
    type: PersonalizationQuestionType.singleChoice,
    options: [
      PersonalizationOptionConfig(
        value: 'single',
        labelKey: 'onboarding.step2.rel.single',
        icon: Icons.person_outline_rounded,
      ),
      PersonalizationOptionConfig(
        value: 'taken',
        labelKey: 'onboarding.step2.rel.taken',
        icon: Icons.favorite_outline_rounded,
      ),
      PersonalizationOptionConfig(
        value: 'complicated',
        labelKey: 'onboarding.step2.rel.complicated',
        icon: Icons.alt_route_rounded,
      ),
    ],
  );

  static const lifeSpace = PersonalizationQuestionConfig(
    id: 'lifeSpace',
    titleKey: 'onboarding.step2.life_space',
    type: PersonalizationQuestionType.singleChoice,
    options: [
      PersonalizationOptionConfig(
        value: 'student',
        labelKey: 'onboarding.step2.life.student',
        icon: Icons.school_outlined,
      ),
      PersonalizationOptionConfig(
        value: 'corporate',
        labelKey: 'onboarding.step2.life.corporate',
        icon: Icons.business_center_outlined,
      ),
      PersonalizationOptionConfig(
        value: 'creative',
        labelKey: 'onboarding.step2.life.creative',
        icon: Icons.palette_outlined,
      ),
      PersonalizationOptionConfig(
        value: 'entrepreneur',
        labelKey: 'onboarding.step2.life.entrepreneur',
        icon: Icons.rocket_launch_outlined,
      ),
      PersonalizationOptionConfig(
        value: 'freelance',
        labelKey: 'onboarding.step2.life.freelance',
        icon: Icons.laptop_mac_outlined,
      ),
      PersonalizationOptionConfig(
        value: 'other',
        labelKey: 'onboarding.step2.life.other',
        icon: Icons.auto_awesome_outlined,
      ),
    ],
  );

  static const interpretationTone = PersonalizationQuestionConfig(
    id: 'interpretationTone',
    titleKey: 'onboarding.step2.tone',
    type: PersonalizationQuestionType.singleChoice,
    options: [
      PersonalizationOptionConfig(
        value: 'soft',
        labelKey: 'onboarding.step2.tone.soft',
        icon: Icons.auto_awesome_rounded,
      ),
      PersonalizationOptionConfig(
        value: 'direct',
        labelKey: 'onboarding.step2.tone.direct',
        icon: Icons.bolt_rounded,
      ),
      PersonalizationOptionConfig(
        value: 'spiritual',
        labelKey: 'onboarding.step2.tone.spiritual',
        icon: Icons.self_improvement_rounded,
      ),
    ],
  );

  static const focusAreas = PersonalizationQuestionConfig(
    id: 'focusAreas',
    titleKey: 'personalizationFocusAreasTitle',
    subtitleKey: 'onboarding.step3.subtitle_new',
    type: PersonalizationQuestionType.multipleChoice,
    options: [
      PersonalizationOptionConfig(
        value: 'love',
        labelKey: 'onboarding.step3.area.love',
        icon: Icons.favorite_outline_rounded,
      ),
      PersonalizationOptionConfig(
        value: 'career',
        labelKey: 'onboarding.step3.area.career',
        icon: Icons.work_history_outlined,
      ),
      PersonalizationOptionConfig(
        value: 'money',
        labelKey: 'onboarding.step3.area.money',
        icon: Icons.toll_outlined,
      ),
      PersonalizationOptionConfig(
        value: 'spiritual',
        labelKey: 'onboarding.step3.area.spiritual',
        icon: Icons.self_improvement_rounded,
      ),
      PersonalizationOptionConfig(
        value: 'family',
        labelKey: 'onboarding.step3.area.family',
        icon: Icons.diversity_3_outlined,
      ),
      PersonalizationOptionConfig(
        value: 'general',
        labelKey: 'onboarding.step3.area.general',
        icon: Icons.all_inclusive_rounded,
      ),
    ],
  );

  static const editable = [
    relationshipStatus,
    lifeSpace,
    interpretationTone,
    focusAreas,
  ];
}
