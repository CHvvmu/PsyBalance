import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/identity_avatar.dart';
import '../../../core/navigation/app_route_observer.dart';
import '../../plan/active_plan_repository.dart';
import 'coach_route_args.dart';

String _text(Map<String, dynamic>? row, String key, {String fallback = ''}) {
  final dynamic raw = row == null ? null : row[key];
  final String value = raw?.toString().trim() ?? '';
  return value.isEmpty ? fallback : value;
}

DateTime? _dateTime(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is DateTime) {
    return value;
  }

  final String text = value.toString().trim();
  if (text.isEmpty) {
    return null;
  }

  return DateTime.tryParse(text);
}

int? _intValue(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.round();
  }

  final String text = value.toString().trim();
  final int? asInt = int.tryParse(text);
  if (asInt != null) {
    return asInt;
  }

  final double? asDouble = double.tryParse(text);
  if (asDouble != null) {
    return asDouble.round();
  }

  return null;
}

double _toRatio(int value, int total) {
  if (total <= 0) {
    return 0;
  }

  return value / total;
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _dateKey(DateTime value) {
  return DateUtils.dateOnly(value).toIso8601String().split('T').first;
}

String _dateLabel(DateTime value) {
  final DateTime local = value.toLocal();
  return '${_twoDigits(local.day)}.${_twoDigits(local.month)}.${local.year}';
}

String _timeLabel(DateTime value) {
  final DateTime local = value.toLocal();
  return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String _relativeDayLabel(DateTime value) {
  final DateTime today = DateUtils.dateOnly(DateTime.now());
  final DateTime day = DateUtils.dateOnly(value);
  final int days = today.difference(day).inDays;

  if (days <= 0) {
    return 'сегодня';
  }
  if (days == 1) {
    return 'вчера';
  }
  if (days == 2) {
    return '2 дня назад';
  }

  final int mod100 = days % 100;
  if (mod100 >= 11 && mod100 <= 14) {
    return '$days дней назад';
  }

  switch (days % 10) {
    case 1:
      return '$days день назад';
    case 2:
    case 3:
    case 4:
      return '$days дня назад';
    default:
      return '$days дней назад';
  }
}

String _daysLabel(int days) {
  final int mod100 = days % 100;
  if (mod100 >= 11 && mod100 <= 14) {
    return '$days дней';
  }

  switch (days % 10) {
    case 1:
      return '$days день';
    case 2:
    case 3:
    case 4:
      return '$days дня';
    default:
      return '$days дней';
  }
}

String _formatPercent(double value) {
  return '${(value * 100).round()}%';
}

String _displayCountOrPlaceholder(int value, bool hasData) {
  return hasData ? value.toString() : _behaviorEmptyLabel;
}

String _displayPercentOrPlaceholder(double value, bool hasData) {
  return hasData ? _formatPercent(value) : _behaviorEmptyLabel;
}

bool _isMissingColumnError(PostgrestException error, Iterable<String> columnNames) {
  final StringBuffer buffer = StringBuffer(error.message);
  final Object? details = error.details;
  if (details != null) {
    buffer.write(' ${details.toString()}');
  }

  final Object? hint = error.hint;
  if (hint != null) {
    buffer.write(' ${hint.toString()}');
  }

  final String message = buffer.toString().toLowerCase();

  if (!message.contains('column') && !message.contains('does not exist')) {
    return false;
  }

  for (final String column in columnNames) {
    if (message.contains(column.toLowerCase())) {
      return true;
    }
  }

  return false;
}

String _clientRowSelect({required bool includeAnalytics}) {
  final String analyticsColumns = includeAnalytics
      ? ', progress_score, consistency_streak, engagement_level'
      : '';

  return 'id, full_name, avatar_url, birth_date, goal, activity_level, progress_status$analyticsColumns, notes, last_activity_date, last_session_date, onboarding_completed';
}

String _statusLabel(String value) {
  return behaviorStatusLabel(value);
}

String _engagementLabelFromRaw(Object? value) {
  if (value == null) {
    return _behaviorEmptyLabel;
  }

  final String text = value.toString().trim();
  if (text.isEmpty) {
    return _behaviorEmptyLabel;
  }

  switch (text.toLowerCase()) {
    case 'low':
    case 'low_engagement':
    case 'низкая':
    case 'низкий':
      return 'Низкая';
    case 'medium':
    case 'moderate':
    case 'средняя':
      return 'Средняя';
    case 'high':
    case 'высокая':
      return 'Высокая';
  }

  final num? numeric = num.tryParse(text);
  if (numeric != null) {
    final int score = numeric.round();
    if (score >= 0 && score <= 100) {
      return '$score / 100';
    }
  }

  return _behaviorEmptyLabel;
}

Color _statusColor(ColorScheme colors, String value) {
  final BehaviorStatusPalette palette = behaviorStatusPaletteFor(value);
  return palette.foreground;
}

String _moodLabel(int? value) {
  switch (value) {
    case 1:
      return 'Хорошо';
    case 2:
      return 'Нормально';
    case 3:
      return 'Устал(а)';
    case 4:
      return 'Стресс';
    case 5:
      return 'Нет энергии';
    default:
      return 'Без отметки';
  }
}

String _moodEmoji(int? value) {
  switch (value) {
    case 1:
      return '🙂';
    case 2:
      return '😐';
    case 3:
      return '😔';
    case 4:
      return '😤';
    case 5:
      return '😴';
    default:
      return '•';
  }
}

bool _isDoneStatus(String value) {
  return value.trim().toLowerCase() == 'done';
}

DateTime? _latestDate(Iterable<DateTime?> values) {
  DateTime? latest;
  for (final DateTime? value in values) {
    if (value == null) {
      continue;
    }
    if (latest == null || value.isAfter(latest)) {
      latest = value;
    }
  }
  return latest;
}

int _calculateStreak(Set<String> activeDayKeys) {
  if (activeDayKeys.isEmpty) {
    return 0;
  }

  final List<String> sorted = activeDayKeys.toList()..sort();
  DateTime cursor = DateTime.tryParse(sorted.last) ?? DateTime.now();
  int streak = 0;

  while (activeDayKeys.contains(_dateKey(cursor))) {
    streak += 1;
    cursor = cursor.subtract(const Duration(days: 1));
    if (streak >= 90) {
      break;
    }
  }

  return streak;
}

int _calculateProgressScore({
  required double completionRate,
  required double checkInConsistency,
  required int streak,
  required int daysSinceLastActivity,
  required String status,
}) {
  double score = 0;
  score += completionRate * 35;
  score += checkInConsistency * 25;
  score += math.min(streak * 4.0, 20.0);

  if (daysSinceLastActivity <= 1) {
    score += 20;
  } else if (daysSinceLastActivity <= 3) {
    score += 15;
  } else if (daysSinceLastActivity <= 7) {
    score += 8;
  } else if (daysSinceLastActivity <= 14) {
    score += 3;
  }

  switch (status.trim().toLowerCase()) {
    case 'engaged':
    case 'active':
      score += 10;
      break;
    case 'stable':
      score += 12;
      break;
    case 'inconsistent':
    case 'stagnating':
      score += 4;
      break;
    case 'struggling':
      score += 2;
      break;
    case 'inactive':
      score += 0;
      break;
    case 'onboarding':
    case 'beginner':
      score += 6;
      break;
  }

  return score.round().clamp(0, 100);
}

String _consistencyLevelLabel({
  required int streak,
  required double checkInConsistency,
}) {
  if (streak <= 0 && checkInConsistency <= 0) {
    return _behaviorEmptyLabel;
  }

  if (streak >= 5 || checkInConsistency >= 0.7) {
    return 'Высокая';
  }
  if (streak >= 2 || checkInConsistency >= 0.4) {
    return 'Средняя';
  }
  return 'Низкая';
}

String _engagementLevelLabel({
  required int recentActiveDays,
  required int daysSinceLastActivity,
}) {
  if (recentActiveDays <= 0 && daysSinceLastActivity >= 999) {
    return _behaviorEmptyLabel;
  }

  if (recentActiveDays >= 4 || daysSinceLastActivity <= 2) {
    return 'Высокая';
  }
  if (recentActiveDays >= 2 || daysSinceLastActivity <= 7) {
    return 'Средняя';
  }
  return 'Низкая';
}

String _behaviorHeadline({
  required int streak,
  required double completionRate,
  required double checkInConsistency,
  required int daysSinceLastActivity,
  required int checkInDaysLast7,
  required int recentActiveDays,
  required bool hasActiveSignals,
}) {
  if (!hasActiveSignals) {
    return _behaviorStarterHeadline;
  }

  if (daysSinceLastActivity > 10 && recentActiveDays > 0) {
    return 'Возвращается после паузы';
  }

  if (streak >= 5 && completionRate >= 0.7 && checkInConsistency >= 0.5) {
    return 'Сильная стабильность на этой неделе';
  }

  if (checkInConsistency >= 0.5 || recentActiveDays >= 3) {
    return 'Стабильная вовлечённость';
  }

  if (daysSinceLastActivity <= 3) {
    return 'Ритм держится';
  }

  return 'Нужна мягкая поддержка';
}

String _behaviorDescription({
  required String headline,
  required int progressScore,
  required int recentActiveDays,
  required int tasksCompleted,
  required int tasksTotal,
}) {
  switch (headline) {
    case _behaviorStarterHeadline:
      return 'Как только появятся чек-ины, задачи и чат-активность, здесь будет спокойный обзор.';
    case 'Возвращается после паузы':
      return 'Сейчас лучше работать мягко: короткие задачи, простые чек-ины и без лишнего давления.';
    case 'Сильная стабильность на этой неделе':
      return 'Клиент держит хороший ритм в задачах и чек-инах, можно опираться на уже созданную привычку.';
    case 'Стабильная вовлечённость':
      return 'Есть регулярные отклики и понятный ритм. Хороший момент для аккуратного развития.';
    case 'Ритм держится':
      return 'Последние отклики есть, но лучше поддерживать регулярность короткими шагами.';
    default:
      return 'Ритм немного проседает. Поможет короткая поддержка и один понятный следующий шаг.';
  }
}

String _checkedCountLabel(int value, int total) {
  return '$value / $total';
}

const String _behaviorEmptyLabel = 'Появится после первых шагов';
const String _behaviorStarterHeadline = 'Начните с небольшого действия сегодня';

class _CheckInCardData {
  const _CheckInCardData({
    required this.dateTime,
    required this.moodLabel,
    required this.moodEmoji,
    required this.stressLabel,
    required this.energyLabel,
  });

  final DateTime dateTime;
  final String moodLabel;
  final String moodEmoji;
  final String stressLabel;
  final String energyLabel;
}

enum _TimelineEntryType {
  checkIn,
  task,
  message,
  gap,
}

class _TimelineEntryData {
  const _TimelineEntryData({
    required this.dateTime,
    required this.type,
    required this.title,
    required this.subtitle,
  });

  final DateTime dateTime;
  final _TimelineEntryType type;
  final String title;
  final String subtitle;
}

class _ClientDetailsViewData {
  const _ClientDetailsViewData({
    required this.displayName,
    required this.avatarUrl,
    required this.ageValue,
    required this.goalValue,
    required this.activityLevelValue,
    required this.progressStatusRaw,
    required this.progressStatusLabel,
    required this.progressScore,
    required this.consistencyStreak,
    required this.behaviorHeadline,
    required this.behaviorDescription,
    required this.consistencyLevelLabel,
    required this.engagementLevelLabel,
    required this.tasksCompletedThisWeek,
    required this.tasksSkippedThisWeek,
    required this.tasksTotalThisWeek,
    required this.completionRate,
    required this.checkInDaysLast7,
    required this.checkInConsistency,
    required this.missedDays,
    required this.lastActivityValue,
    required this.weekValue,
    required this.recentCheckIns,
    required this.timelineEntries,
    required this.notes,
    required this.hasAnySignals,
    required this.hasTaskActivity,
    required this.hasCheckInActivity,
  });

  factory _ClientDetailsViewData.fromRaw({
    required Map<String, dynamic>? clientRow,
    required Map<String, dynamic>? planRow,
    required List<Map<String, dynamic>> planItems,
    required List<Map<String, dynamic>> checkInRows,
    required List<Map<String, dynamic>> inboundMessages,
    required List<Map<String, dynamic>> outboundMessages,
    required String fallbackName,
    required String fallbackAvatarUrl,
  }) {
    final String rowName = _text(clientRow, 'full_name');
    final String displayName = rowName.isNotEmpty
        ? rowName
        : (fallbackName.trim().isNotEmpty ? fallbackName.trim() : 'Без имени');

    final String rowAvatar = _text(clientRow, 'avatar_url');
    final String avatarUrl = rowAvatar.isNotEmpty ? rowAvatar : fallbackAvatarUrl.trim();
    final DateTime? birthDate = _dateTime(clientRow?['birth_date']);
    final int? age = _ageFrom(birthDate);
    final String ageValue = age == null ? 'Возраст не указан' : '$age лет';

    final String goalValue = _text(clientRow, 'goal', fallback: 'Без цели');
    final String activityLevelValue = _text(
      clientRow,
      'activity_level',
      fallback: 'Уровень не указан',
    );
    final String progressStatusRaw = _text(clientRow, 'progress_status');
    final String progressStatusLabel = _statusLabel(progressStatusRaw);
    final String notes = _text(clientRow, 'notes');
    final int? rawProgressScore = _intValue(clientRow?['progress_score']);
    final int? rawConsistencyStreak = _intValue(clientRow?['consistency_streak']);
    final String rawEngagementLevel = _engagementLabelFromRaw(clientRow?['engagement_level']);

    final DateTime? planStart = _dateTime(planRow?['week_start']) ?? _dateTime(planRow?['created_at']);
    final String weekValue = planStart == null ? 'Текущая неделя' : 'Неделя с ${_dateLabel(planStart)}';

    final List<_CheckInCardData> recentCheckIns = checkInRows
        .map(_checkInCardFromRow)
        .toList()
      ..sort((_CheckInCardData left, _CheckInCardData right) => right.dateTime.compareTo(left.dateTime));

    final List<_TimelineEntryData> timelineEntries = <_TimelineEntryData>[];
    final Set<String> activeDayKeys = <String>{};

    for (final _CheckInCardData checkIn in recentCheckIns) {
      activeDayKeys.add(_dateKey(checkIn.dateTime));
      timelineEntries.add(
        _TimelineEntryData(
          dateTime: checkIn.dateTime,
          type: _TimelineEntryType.checkIn,
          title: 'Чек-ин отправлен',
          subtitle: '${checkIn.moodEmoji} ${checkIn.moodLabel} · стресс ${checkIn.stressLabel} · энергия ${checkIn.energyLabel}',
        ),
      );
    }

    for (final Map<String, dynamic> row in planItems) {
      final String status = _text(row, 'status');
      if (!_isDoneStatus(status)) {
        continue;
      }

      final DateTime? date = _dateTime(row['updated_at']) ?? _dateTime(row['created_at']);
      if (date == null) {
        continue;
      }

      activeDayKeys.add(_dateKey(date));
      timelineEntries.add(
        _TimelineEntryData(
          dateTime: date,
          type: _TimelineEntryType.task,
          title: 'Задача завершена',
          subtitle: _text(row, 'title', fallback: 'Без названия'),
        ),
      );
    }

    for (final Map<String, dynamic> row in inboundMessages) {
      final DateTime? date = _dateTime(row['created_at']);
      if (date == null) {
        continue;
      }

      activeDayKeys.add(_dateKey(date));
      timelineEntries.add(
        _TimelineEntryData(
          dateTime: date,
          type: _TimelineEntryType.message,
          title: 'Сообщение клиента',
          subtitle: _messagePreview(row),
        ),
      );
    }

    for (final Map<String, dynamic> row in outboundMessages) {
      final DateTime? date = _dateTime(row['created_at']);
      if (date == null) {
        continue;
      }

      activeDayKeys.add(_dateKey(date));
      timelineEntries.add(
        _TimelineEntryData(
          dateTime: date,
          type: _TimelineEntryType.message,
          title: 'Ответ коуча',
          subtitle: _messagePreview(row),
        ),
      );
    }

    final DateTime? userLastActivity = _dateTime(clientRow?['last_activity_date']);
    final DateTime? userLastSession = _dateTime(clientRow?['last_session_date']);
    final DateTime? latestTimelineDate = _latestDate(<DateTime?>[
      ...recentCheckIns.map((_CheckInCardData checkIn) => checkIn.dateTime),
      ...timelineEntries.map((_TimelineEntryData entry) => entry.dateTime),
      userLastActivity,
      userLastSession,
    ]);

    final int daysSinceLastActivity = latestTimelineDate == null
        ? 999
        : DateUtils.dateOnly(DateTime.now()).difference(DateUtils.dateOnly(latestTimelineDate)).inDays;

    if (daysSinceLastActivity > 3) {
      timelineEntries.add(
        _TimelineEntryData(
          dateTime: latestTimelineDate ?? DateTime.now(),
          type: _TimelineEntryType.gap,
          title: 'Пауза в активности',
          subtitle: 'Есть ${_daysLabel(daysSinceLastActivity)} без заметной активности',
        ),
      );
    }

    timelineEntries.sort((_TimelineEntryData left, _TimelineEntryData right) {
      return right.dateTime.compareTo(left.dateTime);
    });

    final int tasksTotal = planItems.length;
    final int tasksCompleted = planItems.where((Map<String, dynamic> row) {
      return _isDoneStatus(_text(row, 'status'));
    }).length;
    final int tasksSkipped = math.max(0, tasksTotal - tasksCompleted);
    final double completionRate = _toRatio(tasksCompleted, tasksTotal);
    final bool hasTaskActivity = tasksTotal > 0;

    final Set<String> checkInDays = recentCheckIns
        .map((_CheckInCardData data) => _dateKey(data.dateTime))
        .toSet();
    final int checkInDaysLast7 = checkInDays.length;
    final double checkInConsistency = _toRatio(checkInDaysLast7, 7);
    final int missedDays = math.max(0, 7 - checkInDaysLast7);
    final bool hasCheckInActivity = recentCheckIns.isNotEmpty;

    final Set<String> recentActivityDays = <String>{};
    for (final _TimelineEntryData entry in timelineEntries) {
      final int diff = DateUtils.dateOnly(DateTime.now())
          .difference(DateUtils.dateOnly(entry.dateTime))
          .inDays;
      if (diff <= 7) {
        recentActivityDays.add(_dateKey(entry.dateTime));
      }
    }
    final int recentActiveDays = recentActivityDays.length;
    final int derivedConsistencyStreak = _calculateStreak(activeDayKeys);
    final int consistencyStreak = rawConsistencyStreak ?? derivedConsistencyStreak;

    final bool hasAnySignals = rawProgressScore != null ||
        rawConsistencyStreak != null ||
        rawEngagementLevel != _behaviorEmptyLabel ||
        progressStatusRaw.isNotEmpty ||
        hasTaskActivity ||
        hasCheckInActivity ||
        inboundMessages.isNotEmpty ||
        outboundMessages.isNotEmpty ||
        userLastActivity != null ||
        userLastSession != null;

    final String behaviorHeadline = _behaviorHeadline(
      streak: consistencyStreak,
      completionRate: completionRate,
      checkInConsistency: checkInConsistency,
      daysSinceLastActivity: daysSinceLastActivity,
      checkInDaysLast7: checkInDaysLast7,
      recentActiveDays: recentActiveDays,
      hasActiveSignals: hasAnySignals,
    );
    final String behaviorDescription = _behaviorDescription(
      headline: behaviorHeadline,
      progressScore: 0,
      recentActiveDays: recentActiveDays,
      tasksCompleted: tasksCompleted,
      tasksTotal: tasksTotal,
    );

    final String consistencyLevelLabel = _consistencyLevelLabel(
      streak: consistencyStreak,
      checkInConsistency: checkInConsistency,
    );
    final String engagementLevelLabel = _engagementLevelLabel(
      recentActiveDays: recentActiveDays,
      daysSinceLastActivity: daysSinceLastActivity,
    );
    final String engagementLabel = rawEngagementLevel == _behaviorEmptyLabel
        ? engagementLevelLabel
        : rawEngagementLevel;

    final int progressScore = _calculateProgressScore(
      completionRate: completionRate,
      checkInConsistency: checkInConsistency,
      streak: consistencyStreak,
      daysSinceLastActivity: daysSinceLastActivity,
      status: progressStatusRaw,
    );
    final int finalProgressScore = rawProgressScore ?? progressScore;

    final String lastActivityValue = latestTimelineDate == null
        ? _behaviorEmptyLabel
        : _relativeDayLabel(latestTimelineDate);

    return _ClientDetailsViewData(
      displayName: displayName,
      avatarUrl: avatarUrl,
      ageValue: ageValue,
      goalValue: goalValue,
      activityLevelValue: activityLevelValue,
      progressStatusRaw: progressStatusRaw,
      progressStatusLabel: progressStatusLabel,
      progressScore: finalProgressScore,
      consistencyStreak: consistencyStreak,
      behaviorHeadline: behaviorHeadline,
      behaviorDescription: behaviorDescription,
      consistencyLevelLabel: consistencyLevelLabel,
      engagementLevelLabel: engagementLabel,
      tasksCompletedThisWeek: tasksCompleted,
      tasksSkippedThisWeek: tasksSkipped,
      tasksTotalThisWeek: tasksTotal,
      completionRate: completionRate,
      checkInDaysLast7: checkInDaysLast7,
      checkInConsistency: checkInConsistency,
      missedDays: missedDays,
      lastActivityValue: lastActivityValue,
      weekValue: weekValue,
      recentCheckIns: recentCheckIns.take(4).toList(),
      timelineEntries: timelineEntries.take(6).toList(),
      notes: notes,
      hasAnySignals: hasAnySignals,
      hasTaskActivity: hasTaskActivity,
      hasCheckInActivity: hasCheckInActivity,
    );
  }

  final String displayName;
  final String avatarUrl;
  final String ageValue;
  final String goalValue;
  final String activityLevelValue;
  final String progressStatusRaw;
  final String progressStatusLabel;
  final int progressScore;
  final int consistencyStreak;
  final String behaviorHeadline;
  final String behaviorDescription;
  final String consistencyLevelLabel;
  final String engagementLevelLabel;
  final int tasksCompletedThisWeek;
  final int tasksSkippedThisWeek;
  final int tasksTotalThisWeek;
  final double completionRate;
  final int checkInDaysLast7;
  final double checkInConsistency;
  final int missedDays;
  final String lastActivityValue;
  final String weekValue;
  final List<_CheckInCardData> recentCheckIns;
  final List<_TimelineEntryData> timelineEntries;
  final String notes;
  final bool hasAnySignals;
  final bool hasTaskActivity;
  final bool hasCheckInActivity;

  _ClientDetailsViewData copyWith({String? notes}) {
    return _ClientDetailsViewData(
      displayName: displayName,
      avatarUrl: avatarUrl,
      ageValue: ageValue,
      goalValue: goalValue,
      activityLevelValue: activityLevelValue,
      progressStatusRaw: progressStatusRaw,
      progressStatusLabel: progressStatusLabel,
      progressScore: progressScore,
      consistencyStreak: consistencyStreak,
      behaviorHeadline: behaviorHeadline,
      behaviorDescription: behaviorDescription,
      consistencyLevelLabel: consistencyLevelLabel,
      engagementLevelLabel: engagementLevelLabel,
      tasksCompletedThisWeek: tasksCompletedThisWeek,
      tasksSkippedThisWeek: tasksSkippedThisWeek,
      tasksTotalThisWeek: tasksTotalThisWeek,
      completionRate: completionRate,
      checkInDaysLast7: checkInDaysLast7,
      checkInConsistency: checkInConsistency,
      missedDays: missedDays,
      lastActivityValue: lastActivityValue,
      weekValue: weekValue,
      recentCheckIns: recentCheckIns,
      timelineEntries: timelineEntries,
      notes: notes ?? this.notes,
      hasAnySignals: hasAnySignals,
      hasTaskActivity: hasTaskActivity,
      hasCheckInActivity: hasCheckInActivity,
    );
  }
}

_CheckInCardData _checkInCardFromRow(Map<String, dynamic> row) {
  final DateTime dateTime = _dateTime(row['created_at']) ?? _dateTime(row['date']) ?? DateTime.now();
  final int? mood = _intValue(row['mood']);
  final int? stress = _intValue(row['stress']);
  final int? energy = _intValue(row['energy']);

  return _CheckInCardData(
    dateTime: dateTime,
    moodLabel: _moodLabel(mood),
    moodEmoji: _moodEmoji(mood),
    stressLabel: stress == null ? '—' : '$stress/10',
    energyLabel: energy == null ? '—' : '$energy/10',
  );
}

String _messagePreview(Map<String, dynamic> row) {
  final String text = _text(row, 'text');
  if (text.isNotEmpty) {
    return text.length > 72 ? '${text.substring(0, 72).trimRight()}…' : text;
  }

  final String imageUrl = _text(row, 'image_url');
  if (imageUrl.isNotEmpty) {
    return 'Фото в чате';
  }

  return 'Сообщение без текста';
}

class CoachClientDetailsPage extends StatefulWidget {
  const CoachClientDetailsPage({
    super.key,
    required this.clientId,
    required this.clientName,
    this.avatarUrl = '',
    required this.onOpenChat,
    required this.onOpenCall,
    required this.onOpenPlanEditor,
    required this.onBack,
  });

  final String clientId;
  final String clientName;
  final String avatarUrl;
  final ValueChanged<CoachClientRouteArgs> onOpenChat;
  final VoidCallback onOpenCall;
  final ValueChanged<CoachClientRouteArgs> onOpenPlanEditor;
  final VoidCallback onBack;

  @override
  State<CoachClientDetailsPage> createState() => _CoachClientDetailsPageState();
}

class _CoachClientDetailsPageState extends State<CoachClientDetailsPage>
    with RouteAware {
  final SupabaseClient _client = Supabase.instance.client;
  final TextEditingController _notesController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isSummaryExpanded = false;
  bool _isProgressExpanded = false;
  bool _isShiftExpanded = false;
  bool _isWeeklyStepsExpanded = false;
  bool _isCheckInsExpanded = false;
  bool _isTimelineExpanded = false;

  bool _isLoading = true;
  bool _isSavingNotes = false;
  bool _notesDirty = false;
  String? _errorMessage;
  _ClientDetailsViewData? _data;

  PageRoute<dynamic>? _route;

  String get _clientId => widget.clientId.trim();

  String get _fallbackClientName {
    final String trimmed = widget.clientName.trim();
    return trimmed.isEmpty ? 'Без имени' : trimmed;
  }

  String get _fallbackAvatarUrl => widget.avatarUrl.trim();

  CoachClientRouteArgs _routeArgs() {
    final _ClientDetailsViewData? data = _data;
    return CoachClientRouteArgs(
      clientId: _clientId,
      clientName: data?.displayName ?? _fallbackClientName,
      avatarUrl: data?.avatarUrl ?? _fallbackAvatarUrl,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final ModalRoute<dynamic>? modalRoute = ModalRoute.of(context);
    if (modalRoute is PageRoute<dynamic> && modalRoute != _route) {
      if (_route != null) {
        appRouteObserver.unsubscribe(this);
      }

      _route = modalRoute;
      appRouteObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void didPopNext() {
    unawaited(_loadDetails());
  }

  @override
  void dispose() {
    if (_route != null) {
      appRouteObserver.unsubscribe(this);
    }
    _notesController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openChat() {
    final CoachClientRouteArgs args = _routeArgs();
    debugPrint('CLIENT DETAILS OPEN CHAT: clientId=${args.clientId} clientName=${args.clientName}');
    widget.onOpenChat(args);
  }

  void _openPlanEditor() {
    final CoachClientRouteArgs args = _routeArgs();
    debugPrint('CLIENT DETAILS OPEN PLAN EDITOR: clientId=${args.clientId} clientName=${args.clientName}');
    widget.onOpenPlanEditor(args);
  }

  void _sendCheckInStub() {
    _showSnackBar('Отправка check-in появится в следующем обновлении.');
  }

  void _encourageClientStub() {
    _showSnackBar('Мягкая поддержка появится позже.');
  }

  void _toggleSection(_ClientDetailsSection section) {
    setState(() {
      switch (section) {
        case _ClientDetailsSection.summary:
          _isSummaryExpanded = !_isSummaryExpanded;
          break;
        case _ClientDetailsSection.progress:
          _isProgressExpanded = !_isProgressExpanded;
          break;
        case _ClientDetailsSection.shift:
          _isShiftExpanded = !_isShiftExpanded;
          break;
        case _ClientDetailsSection.weeklySteps:
          _isWeeklyStepsExpanded = !_isWeeklyStepsExpanded;
          break;
        case _ClientDetailsSection.checkIns:
          _isCheckInsExpanded = !_isCheckInsExpanded;
          break;
        case _ClientDetailsSection.timeline:
          _isTimelineExpanded = !_isTimelineExpanded;
          break;
      }
    });
  }

  Future<void> _loadDetails() async {
    final User? currentUser = _client.auth.currentUser;
    final String clientId = _clientId;

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (currentUser == null || clientId.isEmpty) {
      debugPrint('CLIENT DETAILS LOAD ERROR: missing auth or clientId');
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Не удалось открыть карточку клиента';
      });
      return;
    }

    debugPrint('CLIENT DETAILS LOAD START: coachId=${currentUser.id} clientId=$clientId');

    final List<dynamic> initialResults = await Future.wait<dynamic>(<Future<dynamic>>[
      _loadClientRow(clientId),
      _loadRelationRow(clientId),
      _loadPlanRow(clientId),
      _loadCheckIns(clientId),
      _loadMessages(
        userIdA: clientId,
        userIdB: currentUser.id,
        label: 'CLIENT DETAILS CONVERSATION MESSAGES',
      ),
    ]);

    final Map<String, dynamic>? clientRow = initialResults[0] as Map<String, dynamic>?;
    final Map<String, dynamic>? relationRow = initialResults[1] as Map<String, dynamic>?;
    final Map<String, dynamic>? planRow = initialResults[2] as Map<String, dynamic>?;
    final List<Map<String, dynamic>> checkInRows =
        (initialResults[3] as List<Map<String, dynamic>>?) ?? <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> conversationMessages =
        (initialResults[4] as List<Map<String, dynamic>>?) ?? <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> inboundMessages = conversationMessages
        .where((Map<String, dynamic> row) => _text(row, 'sender_id') == clientId)
        .toList();
    final List<Map<String, dynamic>> outboundMessages = conversationMessages
        .where((Map<String, dynamic> row) => _text(row, 'sender_id') == currentUser.id)
        .toList();

    final String planId = _text(planRow, 'id');
    final List<Map<String, dynamic>> planItems = planId.isEmpty
        ? <Map<String, dynamic>>[]
        : await _loadPlanItems(planId);

    final String relationCoachId = _text(relationRow, 'coach_id');
    if (relationCoachId.isNotEmpty && relationCoachId != currentUser.id) {
      debugPrint(
        'CLIENT DETAILS RELATION WARNING: clientId=$clientId coachId=$relationCoachId currentCoach=${currentUser.id}',
      );
    } else {
      debugPrint(
        'CLIENT DETAILS RELATION LOADED: clientId=$clientId coachId=${relationCoachId.isEmpty ? '—' : relationCoachId}',
      );
    }

    final _ClientDetailsViewData data = _ClientDetailsViewData.fromRaw(
      clientRow: clientRow,
      planRow: planRow,
      planItems: planItems,
      checkInRows: checkInRows,
      inboundMessages: inboundMessages,
      outboundMessages: outboundMessages,
      fallbackName: _fallbackClientName,
      fallbackAvatarUrl: _fallbackAvatarUrl,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _data = data;
      _notesController.text = data.notes;
      _notesDirty = false;
      _isLoading = false;
      _errorMessage = null;
    });

    debugPrint(
      'CLIENT DETAILS LOAD SUCCESS: clientId=$clientId score=${data.progressScore} streak=${data.consistencyStreak}',
    );
  }

  Future<Map<String, dynamic>?> _loadClientRow(String clientId) async {
    Future<Map<String, dynamic>?> selectRow({required bool includeAnalytics}) {
      return _client
          .from('users')
          .select(_clientRowSelect(includeAnalytics: includeAnalytics))
          .eq('id', clientId)
          .maybeSingle();
    }

    try {
      final Map<String, dynamic>? row = await selectRow(includeAnalytics: true);

      debugPrint('CLIENT DETAILS CLIENT LOADED: clientId=$clientId hasRow=${row != null}');
      return row;
    } on PostgrestException catch (error) {
      if (_isMissingColumnError(
        error,
        const <String>['progress_score', 'consistency_streak', 'engagement_level'],
      )) {
        debugPrint('CLIENT DETAILS CLIENT FALLBACK: clientId=$clientId analytics columns missing');
        try {
          final Map<String, dynamic>? row = await selectRow(includeAnalytics: false);
          debugPrint(
            'CLIENT DETAILS CLIENT LOADED: clientId=$clientId hasRow=${row != null} analytics=false',
          );
          return row;
        } on PostgrestException catch (fallbackError) {
          debugPrint(
            'CLIENT DETAILS CLIENT ERROR: message=${fallbackError.message} details=${fallbackError.details} hint=${fallbackError.hint}',
          );
        } catch (fallbackError) {
          debugPrint('CLIENT DETAILS CLIENT ERROR: $fallbackError');
        }
      }

      debugPrint(
        'CLIENT DETAILS CLIENT ERROR: message=${error.message} details=${error.details} hint=${error.hint}',
      );
    } catch (error) {
      debugPrint('CLIENT DETAILS CLIENT ERROR: $error');
    }

    return null;
  }

  Future<Map<String, dynamic>?> _loadRelationRow(String clientId) async {
    try {
      final Map<String, dynamic>? row = await _client
          .from('clients')
          .select('coach_id, created_at')
          .eq('user_id', clientId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      debugPrint('CLIENT DETAILS RELATION QUERY: clientId=$clientId hasRow=${row != null}');
      return row;
    } on PostgrestException catch (error) {
      debugPrint(
        'CLIENT DETAILS RELATION ERROR: message=${error.message} details=${error.details} hint=${error.hint}',
      );
    } catch (error) {
      debugPrint('CLIENT DETAILS RELATION ERROR: $error');
    }

    return null;
  }

  Future<Map<String, dynamic>?> _loadPlanRow(String clientId) async {
    try {
      final Map<String, dynamic>? row = await loadOrCreateActivePlanRow(
        client: _client,
        userId: clientId,
        sourceLabel: 'coach-client-details',
      );

      debugPrint('CLIENT DETAILS PLAN LOADED: clientId=$clientId hasRow=${row != null}');
      return row;
    } on PostgrestException catch (error) {
      debugPrint(
        'CLIENT DETAILS PLAN ERROR: message=${error.message} details=${error.details} hint=${error.hint}',
      );
    } catch (error) {
      debugPrint('CLIENT DETAILS PLAN ERROR: $error');
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> _loadPlanItems(String planId) async {
    try {
      final List<Map<String, dynamic>> rows = await loadActivePlanItemRows(
        client: _client,
        planId: planId,
        sourceLabel: 'coach-client-details',
      );

      debugPrint('CLIENT DETAILS PLAN ITEMS LOADED: planId=$planId count=${rows.length}');
      return rows;
    } on PostgrestException catch (error) {
      debugPrint(
        'CLIENT DETAILS PLAN ITEMS ERROR: message=${error.message} details=${error.details} hint=${error.hint}',
      );
    } catch (error) {
      debugPrint('CLIENT DETAILS PLAN ITEMS ERROR: $error');
    }

    return <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> _loadCheckIns(String clientId) async {
    try {
      final List<dynamic> rows = await _client
          .from('check_ins')
          .select('id, mood, stress, energy, date, created_at')
          .eq('user_id', clientId)
          .order('date', ascending: false)
          .limit(7);

      debugPrint('CLIENT DETAILS CHECK-INS LOADED: clientId=$clientId count=${rows.length}');
      return rows.cast<Map<String, dynamic>>();
    } on PostgrestException catch (error) {
      debugPrint(
        'CLIENT DETAILS CHECK-INS ERROR: message=${error.message} details=${error.details} hint=${error.hint}',
      );
    } catch (error) {
      debugPrint('CLIENT DETAILS CHECK-INS ERROR: $error');
    }

    return <Map<String, dynamic>>[];
  }

  Future<List<Map<String, dynamic>>> _loadMessages({
    required String userIdA,
    required String userIdB,
    required String label,
  }) async {
    try {
      final List<dynamic> rows = await _client
          .from('messages')
          .select('id, sender_id, receiver_id, text, image_url, created_at')
          .inFilter('sender_id', <String>[userIdA, userIdB])
          .inFilter('receiver_id', <String>[userIdA, userIdB])
          .order('created_at', ascending: false)
          .limit(12);

      debugPrint('$label: userIdA=$userIdA userIdB=$userIdB count=${rows.length}');
      return rows.cast<Map<String, dynamic>>();
    } on PostgrestException catch (error) {
      debugPrint(
        '$label ERROR: message=${error.message} details=${error.details} hint=${error.hint}',
      );
    } catch (error) {
      debugPrint('$label ERROR: $error');
    }

    return <Map<String, dynamic>>[];
  }

  Future<void> _saveNotes() async {
    final _ClientDetailsViewData? data = _data;
    final String clientId = _clientId;
    if (data == null || clientId.isEmpty || _isSavingNotes) {
      return;
    }

    final String normalizedNotes = _notesController.text.trim();
    final String currentNotes = data.notes.trim();
    if (normalizedNotes == currentNotes) {
      if (mounted) {
        setState(() {
          _notesDirty = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSavingNotes = true;
      });
    }

    try {
      await _client.from('users').update(<String, dynamic>{
        'notes': normalizedNotes.isEmpty ? null : normalizedNotes,
      }).eq('id', clientId);

      if (!mounted) {
        return;
      }

      setState(() {
        _data = data.copyWith(notes: normalizedNotes);
        _notesDirty = false;
        _isSavingNotes = false;
      });

      debugPrint('CLIENT DETAILS NOTES SAVE SUCCESS: clientId=$clientId notesLength=${normalizedNotes.length}');
      _showSnackBar('Заметка сохранена');
    } on PostgrestException catch (error) {
      debugPrint(
        'CLIENT DETAILS NOTES SAVE ERROR: message=${error.message} details=${error.details} hint=${error.hint}',
      );
      if (mounted) {
        setState(() {
          _isSavingNotes = false;
        });
      }
      _showSnackBar('Не удалось сохранить заметку');
    } catch (error) {
      debugPrint('CLIENT DETAILS NOTES SAVE ERROR: $error');
      if (mounted) {
        setState(() {
          _isSavingNotes = false;
        });
      }
      _showSnackBar('Не удалось сохранить заметку');
    }
  }

  Widget _buildTopBar(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        IconButton(
          onPressed: widget.onBack,
          icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
          tooltip: 'Назад',
        ),
        Row(
          children: <Widget>[
            IconButton(
              onPressed: widget.onOpenCall,
              icon: Icon(Icons.videocam_rounded, color: colors.onSurface),
              tooltip: 'Видеозвонок',
            ),
            IconButton(
              onPressed: _openChat,
              icon: Icon(Icons.chat_bubble_rounded, color: colors.onSurface),
              tooltip: 'Чат',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderCard(BuildContext context, _ClientDetailsViewData data) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final BehaviorStatusPalette statusPalette = behaviorStatusPaletteFor(data.progressStatusRaw);

    return _SectionCard(
      title: 'Клиент',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IdentityAvatar(
                displayName: data.displayName,
                avatarUrl: data.avatarUrl,
                size: 72,
                backgroundColor: colors.primary.withValues(alpha: 0.1),
                borderColor: colors.primary.withValues(alpha: 0.18),
                borderWidth: 2,
                textColor: colors.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  data.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusPalette.background,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: statusPalette.border),
                ),
                child: Text(
                  data.progressStatusLabel,
                  style: textTheme.labelSmall?.copyWith(
                    color: statusPalette.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _headerOperationalSubtitle(data),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${data.ageValue} • ${data.goalValue} • Ритм: ${data.activityLevelValue}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          _MiniLiveStrip(data: data),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MiniChip(
                icon: Icons.auto_awesome_rounded,
                label: 'Балл ${data.progressScore}',
                backgroundColor: colors.secondary.withValues(alpha: 0.12),
                textColor: colors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context, _ClientDetailsViewData data) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final _BehaviorShiftSummary shiftSummary = _behaviorShiftSummaryFor(data);

    return _SectionCard(
      title: 'Поведенческая сводка',
      subtitle: 'Что текущее состояние значит для коуча прямо сейчас',
      isExpanded: _isSummaryExpanded,
      onToggle: () => _toggleSection(_ClientDetailsSection.summary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            data.behaviorHeadline,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.behaviorDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          _buildSectionBridge(
            context,
            icon: Icons.alt_route_rounded,
            text: shiftSummary.description,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _StatCard(
                title: 'Текущий статус',
                value: data.progressStatusLabel,
                icon: Icons.verified_rounded,
                accentColor: _statusColor(colors, data.progressStatusLabel),
              ),
              _StatCard(
                title: 'Тренд',
                value: data.behaviorHeadline,
                subtitle: data.behaviorDescription,
                icon: Icons.insights_rounded,
                accentColor: colors.primary,
              ),
              _StatCard(
                title: 'Стабильность',
                value: data.consistencyLevelLabel,
                subtitle: '${data.consistencyStreak}-дневная серия',
                icon: Icons.local_fire_department_rounded,
                accentColor: const Color(0xFFB45309),
              ),
              _StatCard(
                title: 'Вовлечённость',
                value: data.engagementLevelLabel,
                subtitle: data.lastActivityValue,
                icon: Icons.favorite_border_rounded,
                accentColor: colors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressMetricsSection(BuildContext context, _ClientDetailsViewData data) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return _SectionCard(
      title: 'Прогресс',
      subtitle: 'Где держится ритм, а где внимание уже нужно предметно',
      isExpanded: _isProgressExpanded,
      onToggle: () => _toggleSection(_ClientDetailsSection.progress),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: <Widget>[
          _StatCard(
            title: 'Поведенческий балл',
            value: '${data.progressScore}',
            subtitle: 'из 100',
            icon: Icons.auto_awesome_rounded,
            accentColor: colors.primary,
          ),
          _StatCard(
            title: 'Серия',
            value: '${data.consistencyStreak} дней',
            subtitle: 'по активности',
            icon: Icons.local_fire_department_rounded,
            accentColor: const Color(0xFFB45309),
          ),
          _StatCard(
            title: 'Последняя активность',
            value: data.lastActivityValue,
            subtitle: data.weekValue,
            icon: Icons.schedule_rounded,
            accentColor: colors.secondary,
          ),
          _StatCard(
            title: 'Вовлечённость',
            value: data.engagementLevelLabel,
            subtitle: data.behaviorHeadline,
            icon: Icons.favorite_border_rounded,
            accentColor: colors.secondary,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCompletionSection(BuildContext context, _ClientDetailsViewData data) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool hasTaskActivity = data.hasTaskActivity;
    final double completionRate = data.completionRate;
    final String tasksValue = _checkedCountLabel(data.tasksCompletedThisWeek, data.tasksTotalThisWeek);
    final String completedValue = _displayCountOrPlaceholder(data.tasksCompletedThisWeek, hasTaskActivity);
    final String skippedValue = _displayCountOrPlaceholder(data.tasksSkippedThisWeek, hasTaskActivity);
    final String totalValue = _displayCountOrPlaceholder(data.tasksTotalThisWeek, hasTaskActivity);
    final String rateValue = _displayPercentOrPlaceholder(completionRate, hasTaskActivity);

    return _SectionCard(
      title: 'Шаги недели',
      subtitle: hasTaskActivity
          ? 'Показывает, дошел ли клиент до действия после контакта и намерения'
          : _behaviorStarterHeadline,
      isExpanded: _isWeeklyStepsExpanded,
      onToggle: () => _toggleSection(_ClientDetailsSection.weeklySteps),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (hasTaskActivity) ...<Widget>[
            LinearProgressIndicator(
              value: completionRate,
              minHeight: 8,
              backgroundColor: colors.primary.withValues(alpha: 0.12),
              color: colors.primary,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 14),
          ] else ...<Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
              ),
              child: Text(
                'Начните с небольшого действия сегодня.',
                style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _StatCard(
                title: 'Завершено',
                value: completedValue,
                subtitle: hasTaskActivity ? 'за текущую неделю' : _behaviorEmptyLabel,
                icon: Icons.task_alt_rounded,
                accentColor: colors.primary,
              ),
              _StatCard(
                title: 'Не завершено',
                value: skippedValue,
                subtitle: hasTaskActivity ? 'за текущую неделю' : _behaviorEmptyLabel,
                icon: Icons.do_not_disturb_on_rounded,
                accentColor: const Color(0xFFEA580C),
              ),
              _StatCard(
                title: 'Ритм выполнения',
                value: rateValue,
                subtitle: hasTaskActivity ? tasksValue : _behaviorEmptyLabel,
                icon: Icons.pie_chart_outline_rounded,
                accentColor: colors.primary,
              ),
              _StatCard(
                title: 'Всего шагов',
                value: totalValue,
                subtitle: hasTaskActivity ? 'за текущую неделю' : _behaviorEmptyLabel,
                icon: Icons.view_list_rounded,
                accentColor: colors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCheckInsSection(BuildContext context, _ClientDetailsViewData data) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<_CheckInCardData> checkIns = data.recentCheckIns;

    return _SectionCard(
      title: 'Свежие чек-ины',
      subtitle: 'Эмоциональный фон помогает понять, почему ритм держится или начинает проседать',
      isExpanded: _isCheckInsExpanded,
      onToggle: () => _toggleSection(_ClientDetailsSection.checkIns),
      child: checkIns.isEmpty
          ? Text(
              'Первые чек-ины появятся здесь, как только клиент начнет отмечать состояние.',
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            )
          : Column(
              children: <Widget>[
                for (int index = 0; index < checkIns.length; index++) ...<Widget>[
                  _CheckInCard(data: checkIns[index]),
                  if (index != checkIns.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  Widget _buildTimelineSection(BuildContext context, _ClientDetailsViewData data) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<_TimelineEntryData> entries = data.timelineEntries;

    return _SectionCard(
      title: 'Лента активности',
      subtitle: 'Здесь видно, был ли отклик после задач, check-in или паузы',
      isExpanded: _isTimelineExpanded,
      onToggle: () => _toggleSection(_ClientDetailsSection.timeline),
      child: entries.isEmpty
          ? Text(
              'Лента заполнится после первых шагов и откликов.',
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            )
          : Column(
              children: <Widget>[
                for (int index = 0; index < entries.length; index++) ...<Widget>[
                  _TimelineEntryTile(data: entries[index], isLast: index == entries.length - 1),
                  if (index != entries.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  Widget _buildNotesSection(BuildContext context, _ClientDetailsViewData data) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return _SectionCard(
      title: 'Заметка коуча',
      subtitle: 'Короткая рабочая заметка по клиенту',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _notesController,
            minLines: 4,
            maxLines: 6,
            onChanged: (String value) {
              final bool dirty = value.trim() != data.notes.trim();
              if (dirty == _notesDirty) {
                return;
              }
              setState(() {
                _notesDirty = dirty;
              });
            },
            decoration: InputDecoration(
              hintText: 'Например: лучше отклик на короткие задачи, стоит мягко удерживать ритм.',
              filled: true,
              fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.7)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.7)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _notesDirty ? 'Есть несохраненные изменения.' : 'Заметка сохраняется только вручную.',
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: _isSavingNotes || !_notesDirty ? null : _saveNotes,
                icon: _isSavingNotes
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onSurface,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text('Сохранить'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return _SectionCard(
      title: 'Следующие шаги коуча',
      subtitle: 'Operational actions вместо простой навигации',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: <Widget>[
          _QuickActionButton(
            icon: Icons.chat_bubble_rounded,
            label: 'Открыть чат',
            onPressed: _openChat,
            accentColor: colors.primary,
          ),
          _QuickActionButton(
            icon: Icons.fact_check_rounded,
            label: 'Мягкий check-in',
            onPressed: _sendCheckInStub,
            accentColor: colors.secondary,
          ),
          _QuickActionButton(
            icon: Icons.playlist_add_check_rounded,
            label: 'Предложить micro-step',
            onPressed: _openPlanEditor,
            accentColor: colors.primary,
          ),
          _QuickActionButton(
            icon: Icons.timeline_rounded,
            label: 'Открыть timeline',
            onPressed: _encourageClientStub,
            accentColor: const Color(0xFFB45309),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeSinceVisitSection(BuildContext context, _ClientDetailsViewData data) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final _ChangeNarrative summary = _changeNarrativeFor(data);

    return _SectionCard(
      title: 'Что изменилось с прошлого визита',
      subtitle: 'Change-awareness по доступным событиям без выдуманного last-view state',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(summary.icon, color: colors.primary.withValues(alpha: 0.8), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        summary.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        summary.detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: summary.items.map((_MiniSignalItem item) => _SignalChip(item: item)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftNarrativeSection(BuildContext context, _ClientDetailsViewData data) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final _BehaviorShiftSummary summary = _behaviorShiftSummaryFor(data);

    return _SectionCard(
      title: 'Поведенческий сдвиг за 7 дней',
      subtitle: 'Связывает ритм, шаги, чек-ины и контакт в одну рабочую историю',
      isExpanded: _isShiftExpanded,
      onToggle: () => _toggleSection(_ClientDetailsSection.shift),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            summary.title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            summary.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: summary.links
                .map((_NarrativeLinkItem item) => _NarrativeLinkChip(item: item))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionBridge(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading && _data == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      CircularProgressIndicator(color: colors.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Загружаем поведенческий обзор...',
                        style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _buildTopBar(context),
                    if (_errorMessage != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.errorContainer,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(color: colors.onErrorContainer),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildHeaderCard(context, _data ?? _fallbackViewData()),
                    const SizedBox(height: 16),
                    _buildChangeSinceVisitSection(context, _data ?? _fallbackViewData()),
                    const SizedBox(height: 16),
                    _buildSummarySection(context, _data ?? _fallbackViewData()),
                    const SizedBox(height: 16),
                    _buildShiftNarrativeSection(context, _data ?? _fallbackViewData()),
                    const SizedBox(height: 16),
                    _buildProgressMetricsSection(context, _data ?? _fallbackViewData()),
                    const SizedBox(height: 16),
                    _buildSectionBridge(
                      context,
                      icon: Icons.arrow_downward_rounded,
                      text: 'Если прогресс проседает, следующий вопрос — дошел ли клиент до конкретных шагов на этой неделе.',
                    ),
                    const SizedBox(height: 12),
                    _buildTaskCompletionSection(context, _data ?? _fallbackViewData()),
                    const SizedBox(height: 16),
                    _buildSectionBridge(
                      context,
                      icon: Icons.arrow_downward_rounded,
                      text: 'Если шаги не двигаются, эмоциональный фон и регулярность check-in помогают понять, это перегрузка, сопротивление или просто тишина.',
                    ),
                    const SizedBox(height: 12),
                    _buildRecentCheckInsSection(context, _data ?? _fallbackViewData()),
                    const SizedBox(height: 16),
                    _buildSectionBridge(
                      context,
                      icon: Icons.arrow_downward_rounded,
                      text: 'После этого полезно открыть ленту: был ли вообще отклик, сообщение или заметная пауза после предыдущих касаний.',
                    ),
                    const SizedBox(height: 12),
                    _buildTimelineSection(context, _data ?? _fallbackViewData()),
                    const SizedBox(height: 16),
                    _buildNotesSection(context, _data ?? _fallbackViewData()),
                    const SizedBox(height: 16),
                    _buildQuickActionsSection(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  _ClientDetailsViewData _fallbackViewData() {
    return _ClientDetailsViewData(
      displayName: _fallbackClientName,
      avatarUrl: _fallbackAvatarUrl,
      ageValue: 'Возраст не указан',
      goalValue: 'Без цели',
      activityLevelValue: 'Уровень не указан',
      progressStatusRaw: '',
      progressStatusLabel: _behaviorEmptyLabel,
      progressScore: 0,
      consistencyStreak: 0,
      behaviorHeadline: _behaviorStarterHeadline,
      behaviorDescription: 'Обзор заполнится после первых шагов.',
      consistencyLevelLabel: _behaviorEmptyLabel,
      engagementLevelLabel: _behaviorEmptyLabel,
      tasksCompletedThisWeek: 0,
      tasksSkippedThisWeek: 0,
      tasksTotalThisWeek: 0,
      completionRate: 0,
      checkInDaysLast7: 0,
      checkInConsistency: 0,
      missedDays: 7,
      lastActivityValue: _behaviorEmptyLabel,
      weekValue: 'Текущая неделя',
      recentCheckIns: <_CheckInCardData>[],
      timelineEntries: <_TimelineEntryData>[],
      notes: '',
      hasAnySignals: false,
      hasTaskActivity: false,
      hasCheckInActivity: false,
    );
  }
}

int? _ageFrom(DateTime? birthDate) {
  if (birthDate == null) {
    return null;
  }

  final DateTime now = DateTime.now();
  int years = now.year - birthDate.year;
  final bool hadBirthdayThisYear =
      now.month > birthDate.month || (now.month == birthDate.month && now.day >= birthDate.day);
  if (!hadBirthdayThisYear) {
    years -= 1;
  }

  return years < 0 ? null : years;
}

String _headerOperationalSubtitle(_ClientDetailsViewData data) {
  if (!data.hasAnySignals) {
    return 'Пока доступен только базовый профиль без живых поведенческих сигналов';
  }

  if (data.lastActivityValue == _behaviorEmptyLabel) {
    return 'Контекст пока частичный: есть отдельные сигналы, но без устойчивого ритма';
  }

  return 'Последний подтвержденный сигнал: ${data.lastActivityValue.toLowerCase()}';
}

_ChangeNarrative _changeNarrativeFor(_ClientDetailsViewData data) {
  final List<_MiniSignalItem> items = <_MiniSignalItem>[];

  if (data.hasTaskActivity) {
    items.add(
      _MiniSignalItem(
        icon: Icons.task_alt_rounded,
        text: '${data.tasksCompletedThisWeek} завершено из ${data.tasksTotalThisWeek}',
      ),
    );
  }

  if (data.hasCheckInActivity) {
    items.add(
      _MiniSignalItem(
        icon: Icons.favorite_border_rounded,
        text: '${data.checkInDaysLast7} check-in за 7 дней',
      ),
    );
  }

  if (data.timelineEntries.isNotEmpty) {
    final _TimelineEntryData latestEntry = data.timelineEntries.first;
    items.add(
      _MiniSignalItem(
        icon: Icons.timeline_rounded,
        text: '${latestEntry.title}: ${_relativeDayLabel(latestEntry.dateTime)}',
      ),
    );
  }

  if (!data.hasAnySignals) {
    return const _ChangeNarrative(
      title: 'Подтвержденных новых событий пока нет',
      detail: 'История изменений еще не собрана: доступны только базовые поля клиента без событий чата, шагов и check-in.',
      icon: Icons.info_outline_rounded,
      items: <_MiniSignalItem>[
        _MiniSignalItem(icon: Icons.person_outline_rounded, text: 'Доступен только профиль клиента'),
      ],
    );
  }

  if (data.timelineEntries.isEmpty) {
    return _ChangeNarrative(
      title: 'История изменений пока ограничена',
      detail: 'Есть отдельные статусные поля, но лента событий еще не дает уверенно сказать, что поменялось после прошлого визита коуча.',
      icon: Icons.history_toggle_off_rounded,
      items: items,
    );
  }

  return _ChangeNarrative(
    title: 'Видны новые поведенческие сигналы, но не точный delta-since-last-view',
    detail: 'Сейчас экран показывает последние подтвержденные события. Реальное “с прошлого визита коуча” потребует отдельного last-view state, которого пока нет в текущем data contract.',
    icon: Icons.update_rounded,
    items: items,
  );
}

_BehaviorShiftSummary _behaviorShiftSummaryFor(_ClientDetailsViewData data) {
  final List<_NarrativeLinkItem> links = <_NarrativeLinkItem>[];

  if (data.hasCheckInActivity) {
    links.add(
      _NarrativeLinkItem(
        icon: Icons.favorite_border_rounded,
        text: 'Check-in ритм: ${data.checkInDaysLast7}/7 дней',
      ),
    );
  }

  if (data.hasTaskActivity) {
    links.add(
      _NarrativeLinkItem(
        icon: Icons.task_alt_rounded,
        text: 'Шаги недели: ${_formatPercent(data.completionRate)} выполнения',
      ),
    );
  }

  if (data.timelineEntries.isNotEmpty) {
    links.add(
      const _NarrativeLinkItem(
        icon: Icons.timeline_rounded,
        text: 'Лента уже показывает живые события и паузы',
      ),
    );
  }

  if (!data.hasAnySignals) {
    return const _BehaviorShiftSummary(
      title: 'Поведенческий сдвиг пока не читается',
      description: 'Недостаточно событий, чтобы связать состояние, действия и отклик в рабочую историю. Пока это скорее стартовый профиль, чем narrative клиента.',
      links: <_NarrativeLinkItem>[
        _NarrativeLinkItem(icon: Icons.info_outline_rounded, text: 'Нужны первые шаги, check-in или сообщения'),
      ],
    );
  }

  if (data.missedDays >= 4 && data.tasksCompletedThisWeek == 0) {
    return _BehaviorShiftSummary(
      title: 'Ритм ослаб и до действия клиент почти не доходит',
      description: 'За последние 7 дней мало регулярных check-in, а в шагах недели пока нет уверенного движения. Это больше похоже на затухание ритма, чем на устойчивый прогресс.',
      links: links,
    );
  }

  if (data.tasksCompletedThisWeek > 0 && data.checkInDaysLast7 >= 2) {
    return _BehaviorShiftSummary(
      title: 'Есть связка между вниманием к себе и переходом к действию',
      description: 'Клиент не только появляется в данных, но и доходит до конкретных шагов. Это хороший момент для поддерживающего follow-up, а не для давления.',
      links: links,
    );
  }

  return _BehaviorShiftSummary(
    title: 'Сигналы смешанные: контакт есть, но причинность пока частичная',
    description: 'Экран уже показывает отдельные поведенческие следы, но без read-state, intervention outcome и last-view delta narrative остается приближенным, а не полным.',
    links: links.isEmpty
        ? const <_NarrativeLinkItem>[
            _NarrativeLinkItem(icon: Icons.insights_rounded, text: 'Есть базовые сигналы, но причинность еще слабая'),
          ]
        : links,
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.isExpanded = true,
    this.onToggle,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool isExpanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isCollapsible = onToggle != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (subtitle != null) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isCollapsible) ...<Widget>[
                    const SizedBox(width: 12),
                    AnimatedRotation(
                      turns: isExpanded ? 0 : 0.5,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 14),
                      child,
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _MiniSignalItem {
  const _MiniSignalItem({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

class _NarrativeLinkItem {
  const _NarrativeLinkItem({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

class _ChangeNarrative {
  const _ChangeNarrative({
    required this.title,
    required this.detail,
    required this.icon,
    required this.items,
  });

  final String title;
  final String detail;
  final IconData icon;
  final List<_MiniSignalItem> items;
}

class _BehaviorShiftSummary {
  const _BehaviorShiftSummary({
    required this.title,
    required this.description,
    required this.links,
  });

  final String title;
  final String description;
  final List<_NarrativeLinkItem> links;
}

enum _ClientDetailsSection {
  summary,
  progress,
  shift,
  weeklySteps,
  checkIns,
  timeline,
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.accentColor,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color accent = accentColor ?? colors.primary;

    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null)
            Align(
              alignment: Alignment.topRight,
              child: Icon(icon, size: 18, color: accent.withValues(alpha: 0.85)),
            ),
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.25,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniLiveStrip extends StatelessWidget {
  const _MiniLiveStrip({required this.data});

  final _ClientDetailsViewData data;

  @override
  Widget build(BuildContext context) {
    final List<_MiniSignalItem> items = <_MiniSignalItem>[
      _MiniSignalItem(
        icon: Icons.schedule_rounded,
        text: data.lastActivityValue == _behaviorEmptyLabel ? 'Активность: нет сигнала' : 'Активность: ${data.lastActivityValue}',
      ),
      _MiniSignalItem(
        icon: Icons.local_fire_department_rounded,
        text: data.consistencyStreak > 0 ? 'Серия: ${data.consistencyStreak} дн.' : 'Серия пока не видна',
      ),
      _MiniSignalItem(
        icon: Icons.favorite_border_rounded,
        text: data.hasCheckInActivity ? 'Check-in: ${data.checkInDaysLast7}/7 дней' : 'Check-in: нет данных',
      ),
      _MiniSignalItem(
        icon: Icons.visibility_outlined,
        text: data.hasAnySignals ? 'Внимание: ${data.progressStatusLabel}' : 'Внимание: мало данных',
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((_MiniSignalItem item) => _SignalChip(item: item)).toList(),
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({required this.item});

  final _MiniSignalItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(item.icon, size: 15, color: colors.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              item.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NarrativeLinkChip extends StatelessWidget {
  const _NarrativeLinkChip({required this.item});

  final _NarrativeLinkItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(item.icon, size: 15, color: colors.onSurfaceVariant),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              item.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  const _CheckInCard({required this.data});

  final _CheckInCardData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                data.moodEmoji,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      data.moodLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_dateLabel(data.dateTime)} · ${_timeLabel(data.dateTime)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MiniChip(
                icon: Icons.self_improvement_rounded,
                label: 'Стресс ${data.stressLabel}',
                backgroundColor: colors.primary.withValues(alpha: 0.1),
                textColor: colors.primary,
              ),
              _MiniChip(
                icon: Icons.bolt_rounded,
                label: 'Энергия ${data.energyLabel}',
                backgroundColor: colors.secondary.withValues(alpha: 0.12),
                textColor: colors.secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineEntryTile extends StatelessWidget {
  const _TimelineEntryTile({
    required this.data,
    required this.isLast,
  });

  final _TimelineEntryData data;
  final bool isLast;

  IconData _iconForType(_TimelineEntryType type) {
    switch (type) {
      case _TimelineEntryType.checkIn:
        return Icons.fact_check_rounded;
      case _TimelineEntryType.task:
        return Icons.task_alt_rounded;
      case _TimelineEntryType.message:
        return Icons.chat_bubble_outline_rounded;
      case _TimelineEntryType.gap:
        return Icons.pause_circle_outline_rounded;
    }
  }

  Color _colorForType(BuildContext context, _TimelineEntryType type) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    switch (type) {
      case _TimelineEntryType.checkIn:
        return colors.primary;
      case _TimelineEntryType.task:
        return const Color(0xFF16A34A);
      case _TimelineEntryType.message:
        return colors.secondary;
      case _TimelineEntryType.gap:
        return const Color(0xFFE08A00);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color accent = _colorForType(context, data.type);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Column(
          children: <Widget>[
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.2),
              ),
              child: Center(
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 44,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: theme.dividerColor.withValues(alpha: 0.8),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        data.title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _timeLabel(data.dateTime),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  data.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _MiniChip(
                    icon: _iconForType(data.type),
                    label: _timelineLabelForType(data.type),
                    backgroundColor: accent.withValues(alpha: 0.12),
                    textColor: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _timelineLabelForType(_TimelineEntryType type) {
    switch (type) {
      case _TimelineEntryType.checkIn:
        return 'Чек-ин';
      case _TimelineEntryType.task:
        return 'Задача';
      case _TimelineEntryType.message:
        return 'Чат';
      case _TimelineEntryType.gap:
        return 'Пауза';
    }
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return SizedBox(
      width: 168,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: accentColor,
          backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.18),
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.7)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
