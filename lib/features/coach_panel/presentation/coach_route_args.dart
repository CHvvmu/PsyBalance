class CoachClientRouteArgs {
  const CoachClientRouteArgs({
    required this.clientId,
    required this.clientName,
  });

  final String clientId;
  final String clientName;

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
    final String fallbackName = readText('name');
    final String email = readText('email');
    final String progressStatus = readText('progress_status');
    final String notes = readText('notes');
    final String clientName = fullName.isNotEmpty
        ? fullName
        : fallbackName.isNotEmpty
            ? fallbackName
            : email.isNotEmpty
                ? email
                : clientId;

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
      progressStatus: progressStatus.isEmpty ? 'no data' : progressStatus,
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

  String get displayProgressStatus =>
      progressStatus.trim().isEmpty ? 'no data' : progressStatus.trim();

  String get displayProgressStatusLabel {
    switch (displayProgressStatus.toLowerCase()) {
      case 'active':
        return 'Активен';
      case 'stagnating':
        return 'Снижение';
      case 'beginner':
        return 'Начинающий';
      case 'no data':
        return 'no data';
      default:
        return 'no data';
    }
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
