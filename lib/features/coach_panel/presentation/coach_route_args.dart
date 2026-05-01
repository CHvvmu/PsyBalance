import 'package:flutter/material.dart';

class BehaviorStatusPalette {
  const BehaviorStatusPalette({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}

String normalizeBehaviorStatus(String value) {
  switch (value.trim().toLowerCase()) {
    case 'engaged':
    case 'active':
      return 'engaged';
    case 'stable':
      return 'stable';
    case 'inconsistent':
    case 'stagnating':
      return 'inconsistent';
    case 'struggling':
      return 'struggling';
    case 'inactive':
      return 'inactive';
    case 'onboarding':
    case 'beginner':
      return 'onboarding';
    default:
      return '';
  }
}

String behaviorStatusLabel(String value) {
  switch (normalizeBehaviorStatus(value)) {
    case 'engaged':
      return 'Вовлечён';
    case 'stable':
      return 'Стабильно';
    case 'inconsistent':
      return 'Нестабильно';
    case 'struggling':
      return 'Нужна поддержка';
    case 'inactive':
      return 'Пауза';
    case 'onboarding':
      return 'Адаптация';
    default:
      return 'Появится после первых шагов';
  }
}

BehaviorStatusPalette behaviorStatusPaletteFor(String value) {
  switch (normalizeBehaviorStatus(value)) {
    case 'engaged':
      return const BehaviorStatusPalette(
        background: Color(0xFFE4F7ED),
        border: Color(0xFFB7E4CA),
        foreground: Color(0xFF166534),
      );
    case 'stable':
      return const BehaviorStatusPalette(
        background: Color(0xFFE8F1FF),
        border: Color(0xFFC9D8FF),
        foreground: Color(0xFF1D4ED8),
      );
    case 'inconsistent':
      return const BehaviorStatusPalette(
        background: Color(0xFFFFF3D9),
        border: Color(0xFFF2D08A),
        foreground: Color(0xFF9A6700),
      );
    case 'struggling':
      return const BehaviorStatusPalette(
        background: Color(0xFFFFE8E8),
        border: Color(0xFFF5B5B5),
        foreground: Color(0xFFB42318),
      );
    case 'inactive':
      return const BehaviorStatusPalette(
        background: Color(0xFFF3F4F6),
        border: Color(0xFFE5E7EB),
        foreground: Color(0xFF6B7280),
      );
    case 'onboarding':
      return const BehaviorStatusPalette(
        background: Color(0xFFF3E8FF),
        border: Color(0xFFE9D5FF),
        foreground: Color(0xFF7C3AED),
      );
    default:
      return const BehaviorStatusPalette(
        background: Color(0xFFF3F4F6),
        border: Color(0xFFE5E7EB),
        foreground: Color(0xFF6B7280),
      );
  }
}

class CoachClientRouteArgs {
  const CoachClientRouteArgs({
    required this.clientId,
    required this.clientName,
    this.avatarUrl = '',
    this.initialDraft = '',
  });

  final String clientId;
  final String clientName;
  final String avatarUrl;
  final String initialDraft;

  String get userId => clientId;
}

class CoachClientCardData {
  const CoachClientCardData({
    required this.clientId,
    required this.clientName,
    required this.avatarUrl,
    required this.email,
    required this.birthDate,
    required this.gender,
    required this.goal,
    required this.activityLevel,
    required this.lastActivityDate,
    required this.lastSessionDate,
    required this.progressStatus,
    required this.notes,
    required this.onboardingCompleted,
  });

  factory CoachClientCardData.fromUserRow({
    required String clientId,
    required Map<String, dynamic>? row,
  }) {
    final Map<String, dynamic> source = row ?? <String, dynamic>{};

    String readText(String key) {
      final dynamic raw = source[key];
      if (raw == null) {
        return '';
      }

      return raw.toString().trim();
    }

    DateTime? readDateTime(String key) {
      final dynamic raw = source[key];
      if (raw == null) {
        return null;
      }

      if (raw is DateTime) {
        return raw;
      }

      final String value = raw.toString().trim();
      if (value.isEmpty) {
        return null;
      }

      return DateTime.tryParse(value);
    }

    bool readBool(String key) {
      final dynamic raw = source[key];
      if (raw is bool) {
        return raw;
      }

      final String value = raw?.toString().trim().toLowerCase() ?? '';
      return value == 'true' || value == '1' || value == 'yes';
    }

    final String fullName = readText('full_name');
    final String email = readText('email');
    final String progressStatus = readText('progress_status');
    final String notes = readText('notes');
    final String clientName = fullName.isNotEmpty ? fullName : 'Без имени';

    return CoachClientCardData(
      clientId: clientId,
      clientName: clientName,
      avatarUrl: readText('avatar_url'),
      email: email,
      birthDate: readDateTime('birth_date'),
      gender: readText('gender'),
      goal: readText('goal'),
      activityLevel: readText('activity_level'),
      lastActivityDate: readDateTime('last_activity_date'),
      lastSessionDate: readDateTime('last_session_date'),
      progressStatus: progressStatus,
      notes: notes,
      onboardingCompleted: readBool('onboarding_completed'),
    );
  }

  final String clientId;
  final String clientName;
  final String avatarUrl;
  final String email;
  final DateTime? birthDate;
  final String gender;
  final String goal;
  final String activityLevel;
  final DateTime? lastActivityDate;
  final DateTime? lastSessionDate;
  final String progressStatus;
  final String notes;
  final bool onboardingCompleted;

  String get userId => clientId;

  int? get age {
    final DateTime? value = birthDate;
    if (value == null) {
      return null;
    }

    final DateTime now = DateTime.now();
    int years = now.year - value.year;
    final bool hadBirthdayThisYear =
        now.month > value.month || (now.month == value.month && now.day >= value.day);
    if (!hadBirthdayThisYear) {
      years -= 1;
    }
    return years < 0 ? null : years;
  }

  String get displayName => clientName.isEmpty ? 'Без имени' : clientName;

  String get displayAgeLabel =>
      age == null ? 'Возраст не указан' : '${age.toString()} лет';

  String get displayGoal => goal.isEmpty ? 'Цель не указана' : goal;

  String get displayActivityLevel =>
      activityLevel.isEmpty ? 'Уровень не указан' : activityLevel;

  String get displayProgressStatus {
    final String value = progressStatus.trim();
    if (value.isEmpty || value.toLowerCase() == 'no data' || value.toLowerCase() == 'недостаточно данных') {
      return 'Появится после первых шагов';
    }

    return value;
  }

  String get displayProgressStatusLabel {
    return behaviorStatusLabel(progressStatus);
  }

  String get displayLastActivityDate {
    final DateTime? value = lastActivityDate;
    if (value == null) {
      return '-';
    }

    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  String get displayLastSessionDate {
    final DateTime? value = lastSessionDate;
    if (value == null) {
      return '-';
    }

    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  String get onboardingLabel => onboardingCompleted ? 'Онбординг завершен' : 'Онбординг не завершен';
}
