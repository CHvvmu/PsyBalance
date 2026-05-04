import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/identity_avatar.dart';
import '../domain/coach_intervention_semantics.dart';
import 'coach_route_args.dart';

enum _QueueLoadMode { initial, refresh, loadMore }

class _BadgePalette {
  const _BadgePalette({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}

class _InterventionPreset {
  const _InterventionPreset({
    required this.key,
    required this.label,
    required this.interventionType,
    required this.messageType,
    required this.icon,
  });

  final String key;
  final String label;
  final String interventionType;
  final String messageType;
  final IconData icon;
}

const _InterventionPreset _softCheckInPreset = _InterventionPreset(
  key: 'soft_checkin',
  label: 'Мягкий чек-ин',
  interventionType: 'soft_checkin',
  messageType: 'checkin_followup',
  icon: Icons.chat_bubble_outline_rounded,
);

const _InterventionPreset _microStepPreset = _InterventionPreset(
  key: 'micro_step',
  label: 'Микро-шаг',
  interventionType: 'micro_step',
  messageType: 'intervention',
  icon: Icons.bolt_rounded,
);

String _normalizeKey(String value) {
  return value.trim().toLowerCase();
}

String _pluralizeRu(
  int value, {
  required String one,
  required String few,
  required String many,
}) {
  final int absValue = value.abs();
  final int mod100 = absValue % 100;
  if (mod100 >= 11 && mod100 <= 14) {
    return many;
  }

  switch (absValue % 10) {
    case 1:
      return one;
    case 2:
    case 3:
    case 4:
      return few;
    default:
      return many;
  }
}

String _countWithWord(
  int value, {
  required String one,
  required String few,
  required String many,
}) {
  return '$value ${_pluralizeRu(value, one: one, few: few, many: many)}';
}

String _daysLabel(int value) {
  if (value <= 0) {
    return 'сегодня';
  }

  return _countWithWord(
    value,
    one: 'день',
    few: 'дня',
    many: 'дней',
  );
}

String _formatRelativeDay(DateTime value) {
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

  return '${_daysLabel(days)} назад';
}

String _formatTime(DateTime value) {
  final DateTime local = value.toLocal();
  final String hour = local.hour.toString().padLeft(2, '0');
  final String minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _formatDate(DateTime value) {
  final DateTime local = value.toLocal();
  final String day = local.day.toString().padLeft(2, '0');
  final String month = local.month.toString().padLeft(2, '0');
  return '$day.$month.${local.year}';
}

Map<String, dynamic> _jsonMap(Object? value) {
  if (value == null) {
    return <String, dynamic>{};
  }

  if (value is Map<String, dynamic>) {
    return Map<String, dynamic>.from(value);
  }

  if (value is Map) {
    return value.map((Object? key, Object? rawValue) {
      return MapEntry(key?.toString() ?? '', rawValue);
    });
  }

  if (value is String && value.trim().isNotEmpty) {
    try {
      final dynamic decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
      if (decoded is Map) {
        return decoded.map((Object? key, Object? rawValue) {
          return MapEntry(key?.toString() ?? '', rawValue);
        });
      }
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  return <String, dynamic>{};
}

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

int _intValue(Object? value) {
  if (value == null) {
    return 0;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.round();
  }

  final String text = value.toString().trim();
  if (text.isEmpty) {
    return 0;
  }

  final int? asInt = int.tryParse(text);
  if (asInt != null) {
    return asInt;
  }

  final double? asDouble = double.tryParse(text);
  return asDouble?.round() ?? 0;
}

double _doubleValue(Object? value) {
  if (value == null) {
    return 0;
  }

  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  final String text = value.toString().trim();
  if (text.isEmpty) {
    return 0;
  }

  return double.tryParse(text) ?? 0;
}

bool _boolValue(Object? value) {
  if (value is bool) {
    return value;
  }

  final String text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'yes' || text == 't';
}

String _priorityLabel(String value) {
  switch (_normalizeKey(value)) {
    case 'urgent':
      return 'Срочный';
    case 'high':
      return 'Высокий';
    case 'medium':
      return 'Средний';
    default:
      return 'Низкий';
  }
}

_BadgePalette _priorityPaletteFor(String value) {
  switch (_normalizeKey(value)) {
    case 'urgent':
      return const _BadgePalette(
        background: Color(0xFFFFE7EB),
        border: Color(0xFFF3B8C1),
        foreground: Color(0xFFB42318),
      );
    case 'high':
      return const _BadgePalette(
        background: Color(0xFFFFE9DB),
        border: Color(0xFFF5C09B),
        foreground: Color(0xFFB45309),
      );
    case 'medium':
      return const _BadgePalette(
        background: Color(0xFFFFF4DB),
        border: Color(0xFFF2D59A),
        foreground: Color(0xFF8A5A00),
      );
    default:
      return const _BadgePalette(
        background: Color(0xFFEFF3F8),
        border: Color(0xFFD8E0EA),
        foreground: Color(0xFF334155),
      );
  }
}

String _queueStateLabel(String value) {
  switch (_normalizeKey(value)) {
    case 'snoozed':
      return 'На паузе';
    case 'resolved':
      return 'Закрыт';
    case 'dismissed':
      return 'Скрыт';
    default:
      return 'Активно';
  }
}

_BadgePalette _queueStatePaletteFor(String value) {
  switch (_normalizeKey(value)) {
    case 'snoozed':
      return const _BadgePalette(
        background: Color(0xFFF3F4F6),
        border: Color(0xFFE5E7EB),
        foreground: Color(0xFF6B7280),
      );
    case 'resolved':
    case 'dismissed':
      return const _BadgePalette(
        background: Color(0xFFEFF3F8),
        border: Color(0xFFD8E0EA),
        foreground: Color(0xFF64748B),
      );
    default:
      return const _BadgePalette(
        background: Color(0xFFE4F7ED),
        border: Color(0xFFB7E4CA),
        foreground: Color(0xFF166534),
      );
  }
}

String _attentionStateLabel(String value) {
  switch (_normalizeKey(value)) {
    case 'recovery_in_progress':
      return 'Возврат в ритм';
    case 'high_risk_silence':
      return 'Долгая пауза';
    case 'needs_support':
      return 'Нужна поддержка';
    case 'disengaging':
      return 'Снижение вовлечённости';
    case 'momentum_growth':
      return 'Стабильный ритм';
    case 'low_concern':
      return 'В норме';
    default:
      return 'В норме';
  }
}

_BadgePalette _attentionStatePaletteFor(String value) {
  switch (_normalizeKey(value)) {
    case 'recovery_in_progress':
      return const _BadgePalette(
        background: Color(0xFFE8F1FF),
        border: Color(0xFFC9D8FF),
        foreground: Color(0xFF1D4ED8),
      );
    case 'high_risk_silence':
      return const _BadgePalette(
        background: Color(0xFFFFF2DA),
        border: Color(0xFFF2DCA8),
        foreground: Color(0xFF9A6700),
      );
    case 'needs_support':
      return const _BadgePalette(
        background: Color(0xFFFFE8E8),
        border: Color(0xFFF5B5B5),
        foreground: Color(0xFFB42318),
      );
    case 'disengaging':
      return const _BadgePalette(
        background: Color(0xFFFFF4D9),
        border: Color(0xFFF2D08A),
        foreground: Color(0xFF9A6700),
      );
    case 'momentum_growth':
      return const _BadgePalette(
        background: Color(0xFFE4F7ED),
        border: Color(0xFFB7E4CA),
        foreground: Color(0xFF166534),
      );
    default:
      return const _BadgePalette(
        background: Color(0xFFF3F4F6),
        border: Color(0xFFE5E7EB),
        foreground: Color(0xFF6B7280),
      );
  }
}

String _recommendedActionLabel(String value) {
  switch (_normalizeKey(value)) {
    case 'soft_checkin':
      return 'Мягкий чек-ин';
    case 'micro_step':
      return 'Микро-шаг';
    case 'emotional_support':
      return 'Поддержать';
    case 'recovery_prompt':
      return 'Подсветить возврат';
    case 'review_plan':
      return 'Проверить план';
    case 'celebrate_progress':
      return 'Отметить прогресс';
    case 'clarify_barrier':
      return 'Уточнить барьер';
    case 'coach_followup':
      return 'Фоллоу-ап';
    default:
      return 'Наблюдение';
  }
}

_BadgePalette _badgePaletteFromBehaviorStatus(BehaviorStatusPalette palette) {
  return _BadgePalette(
    background: palette.background,
    border: palette.border,
    foreground: palette.foreground,
  );
}

String _eventLabel(String value) {
  switch (_normalizeKey(value)) {
    case 'task_completed':
      return 'Задача завершена';
    case 'task_skipped':
      return 'Задача пропущена';
    case 'checkin_submitted':
      return 'Чек-ин';
    case 'message_sent':
      return 'Сообщение';
    case 'message_read':
      return 'Сообщение прочитано';
    case 'intervention_created':
      return 'Интервенция';
    case 'intervention_responded':
      return 'Ответ на интервенцию';
    case 'intervention_expired':
      return 'Интервенция завершена';
    default:
      return 'Сигнал';
  }
}

String _attentionSummary(_BehaviorSnapshot snapshot) {
  if (snapshot.returnAfterSilence) {
    return 'Есть возврат после паузы. Лучше поддержать коротким и конкретным контактом.';
  }

  if (snapshot.readNoReply) {
    return 'Сообщения читаются, но ответа пока нет. Подойдёт мягкий и спокойный чек-ин.';
  }

  if (snapshot.recentInterventionNoResponse) {
    return 'Недавняя интервенция пока без ответа. Хорошо сработает короткий фоллоу-ап.';
  }

  if (snapshot.missedCheckin) {
    return 'В чек-инах появилась пауза внутри обычного ритма.';
  }

  if (snapshot.instability) {
    return 'Есть колебания в выполнении шагов. Полезно упростить следующий шаг и уточнить барьер.';
  }

  if (snapshot.positiveMomentum) {
    return 'Есть стабильная серия и свежие активности. Сейчас уместно закрепить ритм.';
  }

  return 'Сигналы спокойные и без резких изменений.';
}

String _trendLabel(_BehaviorSnapshot snapshot) {
  if (snapshot.returnAfterSilence) {
    return 'Возврат';
  }
  if (snapshot.positiveMomentum) {
    return 'Ровная серия';
  }
  if (snapshot.instability) {
    return 'Неровно';
  }
  if (snapshot.consistencyStreak >= 5) {
    return 'Стабильно';
  }
  if (snapshot.consistencyStreak >= 1) {
    return 'Формируется';
  }
  return 'Без серии';
}

String _silenceLabel(int days) {
  if (days <= 0) {
    return 'Сегодня';
  }

  return _countWithWord(
    days,
    one: 'день тишины',
    few: 'дня тишины',
    many: 'дней тишины',
  );
}

String _windowActivityLabel(_BehaviorSnapshot snapshot) {
  return '${_countWithWord(
    snapshot.checkins7d,
    one: 'чек-ин',
    few: 'чек-ина',
    many: 'чек-инов',
  )} · ${_countWithWord(
    snapshot.tasksDone7d,
    one: 'задача',
    few: 'задачи',
    many: 'задач',
  )}';
}

String _interventionWindowLabel(_BehaviorSnapshot snapshot) {
  return '${_countWithWord(
    snapshot.coachInterventions14d,
    one: 'интервенция',
    few: 'интервенции',
    many: 'интервенций',
  )} · ${_countWithWord(
    snapshot.interventionResponses14d,
    one: 'ответ',
    few: 'ответа',
    many: 'ответов',
  )}';
}

String _lastActivityLabel(_BehaviorSnapshot snapshot) {
  final DateTime? activity = snapshot.lastEventAt ?? snapshot.lastResponseAt ?? snapshot.latestCoachInterventionAt;
  if (activity == null) {
    return 'Пока без сигнала';
  }

  final String eventLabel = snapshot.lastEventAt != null
      ? _eventLabel(snapshot.lastEventType)
      : snapshot.lastResponseAt != null
          ? 'Ответ'
          : 'Интервенция';

  return '${_formatRelativeDay(activity)} · $eventLabel';
}

String _lastEventLabel(_BehaviorSnapshot snapshot) {
  if (snapshot.lastEventAt == null) {
    return 'Сигнал ожидается';
  }

  return '${_eventLabel(snapshot.lastEventType)} · ${_formatRelativeDay(snapshot.lastEventAt!)}';
}

String _lastResponseLabel(_BehaviorSnapshot snapshot) {
  if (snapshot.lastResponseAt == null) {
    return 'Без ответа';
  }

  return _formatRelativeDay(snapshot.lastResponseAt!);
}

String _draftForChat(_CoachWorkqueueEntry entry) {
  final _InterventionPreset preset = _presetForRecommendedAction(entry.recommendedAction);
  return _composeDraft(entry: entry, preset: preset);
}

String _composeDraft({
  required _CoachWorkqueueEntry entry,
  required _InterventionPreset preset,
}) {
  final String name = entry.displayName.trim();
  final String salutation = name.isEmpty || name == 'Без имени' ? 'Привет' : 'Привет, $name';

  switch (preset.key) {
    case 'micro_step':
      return '$salutation! Давай возьмём очень маленький и понятный шаг на сегодня. Можно коротко написать, какой вариант сейчас проще всего.';
    case 'soft_checkin':
    default:
      if (entry.snapshot.returnAfterSilence) {
        return '$salutation! Рад(а) видеть тебя снова. Хочу аккуратно свериться: какой маленький шаг сейчас будет самым комфортным?';
      }
      if (entry.snapshot.readNoReply) {
        return '$salutation! Вижу, что сообщение уже было прочитано. Хочу мягко уточнить, что сейчас было бы самым удобным шагом.';
      }
      if (entry.snapshot.instability) {
        return '$salutation! Хочу коротко поддержать и помочь упростить следующий шаг. Если удобно, напиши, что сейчас мешает больше всего.';
      }
      if (entry.snapshot.positiveMomentum) {
        return '$salutation! У тебя сейчас хороший ритм. Хочу просто поддержать и помочь закрепить его на ближайший день.';
      }
      return '$salutation! Хочу коротко свериться, как ты сейчас и какой маленький шаг будет самым комфортным сегодня.';
  }
}

String _summariseDraft(String draft, String presetLabel) {
  final String cleanDraft = draft.trim().replaceAll(RegExp(r'\s+'), ' ');
  final String prefix = presetLabel.trim().isEmpty ? 'Интервенция' : presetLabel.trim();
  if (cleanDraft.isEmpty) {
    return prefix;
  }

  if (cleanDraft.length <= 140) {
    return '$prefix: $cleanDraft';
  }

  return '$prefix: ${cleanDraft.substring(0, 140).trimRight()}…';
}

_InterventionPreset _presetForRecommendedAction(String value) {
  switch (_normalizeKey(value)) {
    case 'micro_step':
    case 'clarify_barrier':
    case 'review_plan':
      return _microStepPreset;
    default:
      return _softCheckInPreset;
  }
}

CoachInterventionSignalSnapshot _signalSnapshotForEntry(_CoachWorkqueueEntry entry) {
  final _BehaviorSnapshot snapshot = entry.snapshot;
  return CoachInterventionSignalSnapshot(
    priorityLevel: entry.priorityLevel,
    recommendedAction: entry.recommendedAction,
    attentionState: snapshot.attentionState,
    attentionReason: entry.attentionReason,
    silenceDays: snapshot.silenceDays,
    lastKnownStatus: snapshot.lastKnownStatus,
    lastEventType: snapshot.lastEventType,
    lastEventAt: snapshot.lastEventAt,
    consistencyStreak: snapshot.consistencyStreak,
    daysSinceLastActivity: snapshot.daysSinceLastActivity,
    progressScore: snapshot.progressScore,
    engagementLevel: snapshot.engagementLevel,
    returnAfterSilence: snapshot.returnAfterSilence,
    readNoReply: snapshot.readNoReply,
    missedCheckin: snapshot.missedCheckin,
    positiveMomentum: snapshot.positiveMomentum,
    instability: snapshot.instability,
    recentInterventionNoResponse: snapshot.recentInterventionNoResponse,
  );
}

Map<String, dynamic> _buildInterventionMetadata({
  required _CoachWorkqueueEntry entry,
  required _InterventionPreset preset,
  required String draft,
  required String conversationId,
  required String messageId,
  required DateTime sentAt,
  required String trigger,
  required String sourceScreen,
}) {
  final CoachInterventionSignalSnapshot signals = _signalSnapshotForEntry(entry);
  final CoachInterventionAttribution attribution = CoachInterventionAttribution.forWorkqueue(
    workqueueItemId: entry.id,
    sourceEventId: entry.sourceEventId,
    conversationId: conversationId,
    messageId: messageId,
  );
  final CoachInterventionSemantics semantics = CoachInterventionSemantics.forPreset(
    presetKey: preset.key,
    signals: signals,
  );
  return semantics.toMetadata(
    signals: signals,
    attribution: attribution,
    sourceScreen: sourceScreen,
    trigger: trigger,
    draft: draft,
  )
    ..addAll(<String, dynamic>{
      'source': 'coach_workqueue',
      'platform': 'mobile',
      'session_type': 'coach_workqueue',
      'preset_key': preset.key,
      'preset_label': preset.label,
      'queue_item_id': entry.id,
      'priority_level': entry.priorityLevel,
      'recommended_action': entry.recommendedAction,
      'last_event_type': entry.snapshot.lastEventType,
      'last_event_at': entry.snapshot.lastEventAt?.toIso8601String(),
      'sent_at': sentAt.toIso8601String(),
    });
}

class CoachWorkqueuePage extends StatefulWidget {
  const CoachWorkqueuePage({
    super.key,
    required this.onOpenClient,
    required this.onOpenChat,
    required this.onOpenClients,
    required this.onOpenProfile,
  });

  final ValueChanged<CoachClientRouteArgs> onOpenClient;
  final ValueChanged<CoachClientRouteArgs> onOpenChat;
  final VoidCallback onOpenClients;
  final VoidCallback onOpenProfile;

  @override
  State<CoachWorkqueuePage> createState() => _CoachWorkqueuePageState();
}

class _CoachWorkqueuePageState extends State<CoachWorkqueuePage> {
  static const int _pageSize = 8;

  final SupabaseClient _client = Supabase.instance.client;

  int _requestToken = 0;
  int _visibleLimit = _pageSize;

  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  String? _errorMessage;

  String? _selectedEntryId;
  List<_CoachWorkqueueEntry> _entries = <_CoachWorkqueueEntry>[];

  @override
  void initState() {
    super.initState();
    unawaited(_loadQueue(_QueueLoadMode.initial));
  }

  _CoachWorkqueueEntry? get _selectedEntry {
    if (_entries.isEmpty) {
      return null;
    }

    final String? selectedId = _selectedEntryId;
    if (selectedId != null) {
      for (final _CoachWorkqueueEntry entry in _entries) {
        if (entry.id == selectedId) {
          return entry;
        }
      }
    }

    return _entries.first;
  }

  int get _activeCount {
    return _entries.where((_CoachWorkqueueEntry entry) => _normalizeKey(entry.queueState) == 'active').length;
  }

  int get _snoozedCount {
    return _entries.where((_CoachWorkqueueEntry entry) => _normalizeKey(entry.queueState) == 'snoozed').length;
  }

  int get _urgentCount {
    return _entries.where((_CoachWorkqueueEntry entry) {
      final String level = _normalizeKey(entry.priorityLevel);
      return level == 'high' || level == 'urgent';
    }).length;
  }

  Future<void> _loadQueue(_QueueLoadMode mode) async {
    final int requestId = ++_requestToken;
    final User? currentUser = _client.auth.currentUser;

    if (currentUser == null) {
      if (!mounted || requestId != _requestToken) {
        return;
      }

      setState(() {
        _entries = <_CoachWorkqueueEntry>[];
        _hasMore = false;
        _selectedEntryId = null;
        _errorMessage = 'Не удалось определить текущего коуча';
        _isInitialLoading = false;
        _isRefreshing = false;
        _isLoadingMore = false;
      });
      return;
    }

    final int targetLimit = switch (mode) {
      _QueueLoadMode.initial => _pageSize,
      _QueueLoadMode.refresh => _visibleLimit > 0 ? _visibleLimit : _pageSize,
      _QueueLoadMode.loadMore => _visibleLimit + _pageSize,
    };
    final int fetchLimit = targetLimit + 1;

    if (mode == _QueueLoadMode.initial) {
      debugPrint('COACH WORKQUEUE LOAD START: coachId=${currentUser.id} limit=$targetLimit');
    } else if (mode == _QueueLoadMode.refresh) {
      debugPrint('COACH WORKQUEUE REFRESH START: coachId=${currentUser.id} limit=$targetLimit');
    } else {
      debugPrint('COACH WORKQUEUE LOAD MORE START: coachId=${currentUser.id} limit=$targetLimit');
    }

    if (mounted) {
      setState(() {
        _errorMessage = null;
        _isInitialLoading = mode == _QueueLoadMode.initial && _entries.isEmpty;
        _isRefreshing = mode == _QueueLoadMode.refresh;
        _isLoadingMore = mode == _QueueLoadMode.loadMore;
      });
    }

    try {
      final List<dynamic> itemRows = await _client
          .from('coach_workqueue_items')
          .select(
            'id, coach_id, user_id, priority_score, priority_level, queue_state, attention_reason, recommended_action, behavior_snapshot, metadata, source_event_id, source_event_type, created_at, updated_at, resolved_at, last_evaluated_at',
          )
          .eq('coach_id', currentUser.id)
          .inFilter('queue_state', <String>['active', 'snoozed'])
          .order('queue_state', ascending: true)
          .order('priority_score', ascending: false)
          .order('updated_at', ascending: false)
          .range(0, fetchLimit - 1);

      if (!mounted || requestId != _requestToken) {
        return;
      }

      final List<dynamic> visibleRows = itemRows.take(targetLimit).toList(growable: false);
      final bool hasMore = itemRows.length > targetLimit;

      final List<String> userIds = visibleRows
          .map((dynamic rowData) {
            final Map<String, dynamic> row = rowData as Map<String, dynamic>;
            return row['user_id']?.toString().trim() ?? '';
          })
          .where((String value) => value.isNotEmpty)
          .toSet()
          .toList();

      final Map<String, Map<String, dynamic>> usersById = <String, Map<String, dynamic>>{};
      if (userIds.isNotEmpty) {
        try {
          final List<dynamic> userRows = await _client
              .from('users')
              .select('id, full_name, avatar_url')
              .inFilter('id', userIds);

          for (final dynamic rowData in userRows) {
            final Map<String, dynamic> row = rowData as Map<String, dynamic>;
            final String userId = row['id']?.toString().trim() ?? '';
            if (userId.isNotEmpty) {
              usersById[userId] = row;
            }
          }
        } catch (error, stackTrace) {
          debugPrint('COACH WORKQUEUE USERS LOAD ERROR: $error');
          debugPrint('COACH WORKQUEUE USERS LOAD STACK: $stackTrace');
        }
      }

      final List<_CoachWorkqueueEntry> loadedEntries = <_CoachWorkqueueEntry>[];
      for (final dynamic rowData in visibleRows) {
        final Map<String, dynamic> itemRow = rowData as Map<String, dynamic>;
        final String userId = itemRow['user_id']?.toString().trim() ?? '';
        final Map<String, dynamic>? userRow = usersById[userId];
        loadedEntries.add(
          _CoachWorkqueueEntry.fromRows(
            itemRow: itemRow,
            userRow: userRow,
          ),
        );
      }

      final String? selectedEntryId = _selectedEntryId != null && loadedEntries.any((_CoachWorkqueueEntry entry) => entry.id == _selectedEntryId)
          ? _selectedEntryId
          : (loadedEntries.isNotEmpty ? loadedEntries.first.id : null);

      if (!mounted || requestId != _requestToken) {
        return;
      }

      setState(() {
        _visibleLimit = targetLimit;
        _entries = loadedEntries;
        _hasMore = hasMore;
        _selectedEntryId = selectedEntryId;
        _errorMessage = null;
        _isInitialLoading = false;
        _isRefreshing = false;
        _isLoadingMore = false;
      });

      debugPrint('COACH WORKQUEUE LOAD SUCCESS: coachId=${currentUser.id} items=${loadedEntries.length} hasMore=$hasMore');
    } catch (error, stackTrace) {
      debugPrint('COACH WORKQUEUE LOAD ERROR: coachId=${currentUser.id} error=$error');
      debugPrint('COACH WORKQUEUE LOAD STACK: $stackTrace');

      if (!mounted || requestId != _requestToken) {
        return;
      }

      setState(() {
        _errorMessage = 'Не удалось загрузить очередь';
        _isInitialLoading = false;
        _isRefreshing = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refreshQueue() async {
    await _loadQueue(_QueueLoadMode.refresh);
  }

  Future<void> _retryQueue() async {
    await _loadQueue(_QueueLoadMode.initial);
  }

  Future<void> _loadMore() async {
    if (_isInitialLoading || _isRefreshing || _isLoadingMore || !_hasMore) {
      return;
    }

    await _loadQueue(_QueueLoadMode.loadMore);
  }

  void _selectEntry(String entryId) {
    if (_selectedEntryId == entryId) {
      return;
    }

    setState(() {
      _selectedEntryId = entryId;
    });
  }

  void _openClient(_CoachWorkqueueEntry entry) {
    widget.onOpenClient(entry.routeArgs());
  }

  void _openChat(_CoachWorkqueueEntry entry, {String? initialDraft}) {
    widget.onOpenChat(
      entry.routeArgs(initialDraft: initialDraft ?? _draftForChat(entry)),
    );
  }

  Future<void> _openInterventionComposer(
    _CoachWorkqueueEntry entry,
    _InterventionPreset preset,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: _composeDraft(entry: entry, preset: preset),
    );
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: controller.text.length),
    );

    bool submitting = false;
    String? requestKey;
    String? requestDraft;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext dialogContext) {
          final NavigatorState navigator = Navigator.of(dialogContext);

          return StatefulBuilder(
            builder: (BuildContext context, void Function(void Function()) setModalState) {
              Future<void> sendNow() async {
                final String draft = controller.text.trim();
                if (draft.isEmpty || submitting) {
                  return;
                }

                if (requestKey == null || requestDraft != draft) {
                  requestKey = 'coach-workqueue:${entry.id}:${preset.key}:${DateTime.now().microsecondsSinceEpoch}';
                  requestDraft = draft;
                }

                setModalState(() {
                  submitting = true;
                });

                final bool success = await _sendIntervention(
                  entry: entry,
                  preset: preset,
                  draft: draft,
                  requestKey: requestKey!,
                );

                if (!mounted) {
                  return;
                }

                setModalState(() {
                  submitting = false;
                });

                if (success) {
                  navigator.pop();
                }
              }

              void openChat() {
                final String draft = controller.text.trim();
                navigator.pop();
                _openChat(
                  entry,
                  initialDraft: draft.isNotEmpty ? draft : _composeDraft(entry: entry, preset: preset),
                );
              }

              final ThemeData theme = Theme.of(context);
              final ColorScheme colors = theme.colorScheme;
              final String draftPreview = controller.text.trim();

              return AlertDialog(
                backgroundColor: colors.surface,
                title: Text(
                  preset.label,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                content: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            IdentityAvatar(
                              displayName: entry.displayName,
                              avatarUrl: entry.avatarUrl,
                              size: 48,
                              backgroundColor: colors.primary.withValues(alpha: 0.16),
                              textColor: colors.onSurface,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    entry.displayName,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: colors.onSurface,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _attentionSummary(entry.snapshot),
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
                        const SizedBox(height: 16),
                        TextField(
                          controller: controller,
                          autofocus: true,
                          minLines: 5,
                          maxLines: 10,
                          keyboardType: TextInputType.multiline,
                          decoration: InputDecoration(
                            labelText: 'Черновик сообщения',
                            alignLabelWithHint: true,
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
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide(color: colors.primary, width: 1.3),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          draftPreview.isEmpty
                              ? 'Можно отправить сразу или открыть чат с этим черновиком.'
                              : 'Черновик можно отредактировать перед отправкой или открыть в чате.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                actions: <Widget>[
                  TextButton(
                    onPressed: submitting ? null : openChat,
                    child: const Text('Открыть чат'),
                  ),
                  FilledButton.icon(
                    onPressed: submitting ? null : sendNow,
                    icon: submitting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(colors.onPrimary),
                            ),
                          )
                        : Icon(preset.icon, size: 18),
                    label: Text(submitting ? 'Отправляем...' : 'Отправить'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<bool> _sendIntervention({
    required _CoachWorkqueueEntry entry,
    required _InterventionPreset preset,
    required String draft,
    required String requestKey,
  }) async {
    final User? currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось определить текущего коуча')),
        );
      }
      return false;
    }

    try {
      final dynamic conversationResult = await _client.rpc(
        'get_or_create_direct_conversation',
        params: <String, dynamic>{'p_peer_user_id': entry.userId},
      );

      final Map<String, dynamic>? conversationRow = _singleRowFromRpc(conversationResult);
      final String conversationId = conversationRow?['id']?.toString().trim() ?? '';
      if (conversationId.isEmpty) {
        throw StateError('Conversation RPC returned no id');
      }

      final DateTime now = DateTime.now();
      final Map<String, dynamic> messageMetadata = _buildInterventionMetadata(
        entry: entry,
        preset: preset,
        draft: draft,
        conversationId: conversationId,
        messageId: '',
        sentAt: now,
        trigger: 'manual_message',
        sourceScreen: 'coach_workqueue_page',
      );

      final dynamic messageResult = await _client.rpc(
        'send_chat_message',
        params: <String, dynamic>{
          'p_conversation_id': conversationId,
          'p_content': draft,
          'p_message_type': preset.messageType,
          'p_metadata': messageMetadata,
          'p_request_key': requestKey,
        },
      );

      final Map<String, dynamic>? messageRow = _singleRowFromRpc(messageResult);
      final String messageId = messageRow?['id']?.toString().trim() ?? '';

      final String summary = _summariseDraft(draft, preset.label);
      final Map<String, dynamic> interventionMetadata = _buildInterventionMetadata(
        entry: entry,
        preset: preset,
        draft: draft,
        conversationId: conversationId,
        messageId: messageId,
        sentAt: now,
        trigger: 'manual_message',
        sourceScreen: 'coach_workqueue_page',
      );

      await _client.from('coach_interventions').insert(<String, dynamic>{
        'coach_id': currentUser.id,
        'user_id': entry.userId,
        'workqueue_item_id': entry.id,
        'intervention_type': preset.interventionType,
        'intervention_channel': 'chat',
        'status': 'delivered',
        'message_id': messageId.isEmpty ? null : messageId,
        'conversation_id': conversationId,
        'trigger_event_id': entry.sourceEventId.isEmpty ? null : entry.sourceEventId,
        'summary': summary,
        'metadata': interventionMetadata,
        'delivered_at': now.toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Интервенция отправлена')),
        );
      }

      debugPrint(
        'COACH WORKQUEUE INTERVENTION SUCCESS: entryId=${entry.id} conversationId=$conversationId messageId=$messageId type=${preset.interventionType}',
      );
      return true;
    } catch (error, stackTrace) {
      debugPrint('COACH WORKQUEUE INTERVENTION ERROR: entryId=${entry.id} error=$error');
      debugPrint('COACH WORKQUEUE INTERVENTION STACK: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить сообщение')),
        );
      }
      return false;
    }
  }

  Future<void> _updateQueueState(
    _CoachWorkqueueEntry entry,
    String nextState,
  ) async {
    final User? currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      return;
    }

    try {
      final DateTime now = DateTime.now();
      final Map<String, dynamic> metadata = Map<String, dynamic>.from(entry.metadata);
      metadata['last_manual_queue_state'] = nextState;
      metadata['last_manual_queue_state_at'] = now.toIso8601String();

      await _client
          .from('coach_workqueue_items')
          .update(<String, dynamic>{
            'queue_state': nextState,
            'resolved_at': nextState == 'resolved' ? now.toIso8601String() : null,
            'metadata': metadata,
          })
          .eq('id', entry.id)
          .eq('coach_id', currentUser.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextState == 'resolved' ? 'Клиент снят с очереди' : 'Клиент отложен на паузу',
          ),
        ),
      );

      await _loadQueue(_QueueLoadMode.refresh);
    } catch (error, stackTrace) {
      debugPrint('COACH WORKQUEUE UPDATE ERROR: entryId=${entry.id} error=$error');
      debugPrint('COACH WORKQUEUE UPDATE STACK: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось обновить очередь')),
        );
      }
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Рабочая очередь'),
      actions: <Widget>[
        IconButton(
          tooltip: 'Обновить',
          onPressed: _isRefreshing || _isInitialLoading ? null : _refreshQueue,
          icon: _isRefreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
        ),
        IconButton(
          tooltip: 'Клиенты',
          onPressed: widget.onOpenClients,
          icon: const Icon(Icons.people_alt_rounded),
        ),
        IconButton(
          tooltip: 'Профиль',
          onPressed: widget.onOpenProfile,
          icon: const Icon(Icons.account_circle_outlined),
        ),
      ],
    );
  }

  Widget _buildIntroSection(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final _CoachWorkqueueEntry? selectedEntry = _selectedEntry;
    final DateTime? lastEvaluatedAt = selectedEntry?.lastEvaluatedAt;

    return _SectionCard(
      title: 'Очередь внимания',
      subtitle: 'Порционная загрузка, спокойные приоритеты и объяснимые сигналы.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Сначала показываем ближайшие по приоритету карточки. Можно выбрать клиента, отправить мягкий контакт, открыть чат или отложить запись на паузу.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _StatCard(
                title: 'Активные',
                value: _activeCount.toString(),
                subtitle: 'Карточки в фокусе',
                icon: Icons.playlist_add_check_rounded,
                accentColor: colors.primary,
              ),
              _StatCard(
                title: 'На паузе',
                value: _snoozedCount.toString(),
                subtitle: 'Временно отложены',
                icon: Icons.snooze_rounded,
                accentColor: colors.secondary,
              ),
              _StatCard(
                title: 'Высокий приоритет',
                value: _urgentCount.toString(),
                subtitle: 'Высокий и urgent',
                icon: Icons.priority_high_rounded,
                accentColor: const Color(0xFFB45309),
              ),
              _StatCard(
                title: 'Загружено',
                value: _entries.length.toString(),
                subtitle: _hasMore ? 'Можно подгрузить еще' : 'Весь текущий список',
                icon: Icons.view_list_rounded,
                accentColor: lastEvaluatedAt == null ? colors.primary : colors.tertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotSection(BuildContext context, _CoachWorkqueueEntry entry) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final _BadgePalette priorityPalette = _priorityPaletteFor(entry.priorityLevel);
    final _BadgePalette statePalette = _attentionStatePaletteFor(entry.snapshot.attentionState);
    final _BadgePalette statusPalette = _badgePaletteFromBehaviorStatus(
      behaviorStatusPaletteFor(entry.snapshot.lastKnownStatus),
    );

    return _SectionCard(
      title: 'Поведенческий снимок',
      subtitle: 'Коротко, объяснимо и без скрытых оценок.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              IdentityAvatar(
                displayName: entry.displayName,
                avatarUrl: entry.avatarUrl,
                size: 52,
                backgroundColor: colors.primary.withValues(alpha: 0.14),
                textColor: colors.onSurface,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _attentionSummary(entry.snapshot),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  _Badge(label: _priorityLabel(entry.priorityLevel), palette: priorityPalette),
                  const SizedBox(height: 8),
                  _Badge(label: _attentionStateLabel(entry.snapshot.attentionState), palette: statePalette),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _Badge(
                label: behaviorStatusLabel(entry.snapshot.lastKnownStatus),
                palette: statusPalette,
              ),
              _InfoChip(
                icon: Icons.schedule_rounded,
                label: 'Тишина: ${_silenceLabel(entry.snapshot.silenceDays)}',
                backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.12),
                textColor: colors.onSurfaceVariant,
              ),
              _InfoChip(
                icon: Icons.local_fire_department_rounded,
                label: 'Серия: ${_trendLabel(entry.snapshot)}',
                backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.12),
                textColor: colors.onSurfaceVariant,
              ),
              _InfoChip(
                icon: Icons.history_rounded,
                label: 'Последний сигнал: ${_lastEventLabel(entry.snapshot)}',
                backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.12),
                textColor: colors.onSurfaceVariant,
              ),
              _InfoChip(
                icon: Icons.arrow_forward_rounded,
                label: 'Следующий шаг: ${_recommendedActionLabel(entry.recommendedAction)}',
                backgroundColor: priorityPalette.background,
                textColor: priorityPalette.foreground,
              ),
              _InfoChip(
                icon: Icons.today_rounded,
                label: 'Последняя активность: ${_lastActivityLabel(entry.snapshot)}',
                backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.12),
                textColor: colors.onSurfaceVariant,
              ),
              if (entry.snapshot.lastResponseAt != null)
                _InfoChip(
                  icon: Icons.reply_rounded,
                  label: 'Последний ответ: ${_lastResponseLabel(entry.snapshot)}',
                  backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.12),
                  textColor: colors.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _StatCard(
                title: '7 дней',
                value: _windowActivityLabel(entry.snapshot),
                subtitle: 'Чек-ины и завершённые задачи',
                icon: Icons.insights_rounded,
                accentColor: colors.primary,
              ),
              _StatCard(
                title: '14 дней',
                value: _interventionWindowLabel(entry.snapshot),
                subtitle: 'Интервенции и ответы',
                icon: Icons.forum_outlined,
                accentColor: colors.secondary,
              ),
              _StatCard(
                title: 'Статус',
                value: behaviorStatusLabel(entry.snapshot.lastKnownStatus),
                subtitle: 'Последний известный статус',
                icon: Icons.verified_rounded,
                accentColor: statusPalette.foreground,
              ),
              _StatCard(
                title: 'Последняя оценка',
                value: _formatDate(entry.lastEvaluatedAt),
                subtitle: _formatTime(entry.lastEvaluatedAt),
                icon: Icons.update_rounded,
                accentColor: colors.tertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQueueHeader(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Клиенты в очереди',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Карточки можно выбрать без навигации, чтобы быстро свериться со сводкой.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton.icon(
            onPressed: widget.onOpenClients,
            icon: const Icon(Icons.people_alt_rounded),
            label: const Text('Список клиентов'),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueCard(BuildContext context, _CoachWorkqueueEntry entry) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final _BadgePalette priorityPalette = _priorityPaletteFor(entry.priorityLevel);
    final bool isSelected = entry.id == _selectedEntryId;
    final Color borderColor = isSelected ? priorityPalette.border : theme.dividerColor.withValues(alpha: 0.7);
    final Color backgroundColor = isSelected
        ? priorityPalette.background.withValues(alpha: 0.14)
        : colors.surface;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => _selectEntry(entry.id),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: isSelected ? 1.4 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  IdentityAvatar(
                    displayName: entry.displayName,
                    avatarUrl: entry.avatarUrl,
                    size: 52,
                    backgroundColor: colors.secondary.withValues(alpha: 0.14),
                    textColor: colors.onSurface,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          entry.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _lastActivityLabel(entry.snapshot),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      _Badge(label: _priorityLabel(entry.priorityLevel), palette: priorityPalette),
                      if (_normalizeKey(entry.queueState) == 'snoozed') ...<Widget>[
                        const SizedBox(height: 8),
                        _Badge(
                          label: _queueStateLabel(entry.queueState),
                          palette: _queueStatePaletteFor(entry.queueState),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                entry.behaviorSummary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _InfoChip(
                    icon: Icons.arrow_forward_rounded,
                    label: 'Шаг: ${entry.nextStepLabel}',
                    backgroundColor: priorityPalette.background,
                    textColor: priorityPalette.foreground,
                  ),
                  _InfoChip(
                    icon: Icons.history_rounded,
                    label: 'Активность: ${entry.lastMeaningfulActivityLabel}',
                    backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.12),
                    textColor: colors.onSurfaceVariant,
                  ),
                  _InfoChip(
                    icon: Icons.local_fire_department_rounded,
                    label: 'Серия: ${entry.streakTrendLabel}',
                    backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.12),
                    textColor: colors.onSurfaceVariant,
                  ),
                  _InfoChip(
                    icon: Icons.do_not_disturb_rounded,
                    label: 'Тишина: ${entry.silenceLabel}',
                    backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.12),
                    textColor: colors.onSurfaceVariant,
                  ),
                  _InfoChip(
                    icon: Icons.bolt_rounded,
                    label: 'Сигнал: ${entry.latestEventLabel}',
                    backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.12),
                    textColor: colors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _ActionChipButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: _softCheckInPreset.label,
                    backgroundColor: colors.primary.withValues(alpha: 0.12),
                    borderColor: colors.primary.withValues(alpha: 0.28),
                    foregroundColor: colors.primary,
                    onPressed: () => unawaited(_openInterventionComposer(entry, _softCheckInPreset)),
                  ),
                  _ActionChipButton(
                    icon: Icons.bolt_rounded,
                    label: _microStepPreset.label,
                    backgroundColor: colors.secondary.withValues(alpha: 0.12),
                    borderColor: colors.secondary.withValues(alpha: 0.28),
                    foregroundColor: colors.secondary,
                    onPressed: () => unawaited(_openInterventionComposer(entry, _microStepPreset)),
                  ),
                  _ActionChipButton(
                    icon: Icons.forum_rounded,
                    label: 'Открыть чат',
                    backgroundColor: colors.tertiary.withValues(alpha: 0.12),
                    borderColor: colors.tertiary.withValues(alpha: 0.28),
                    foregroundColor: colors.tertiary,
                    onPressed: () => _openChat(entry),
                  ),
                  _ActionChipButton(
                    icon: Icons.timeline_rounded,
                    label: 'Таймлайн',
                    backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.12),
                    borderColor: theme.dividerColor.withValues(alpha: 0.7),
                    foregroundColor: colors.onSurfaceVariant,
                    onPressed: () => _openClient(entry),
                  ),
                  _ActionChipButton(
                    icon: Icons.snooze_rounded,
                    label: 'Пауза',
                    backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.12),
                    borderColor: theme.dividerColor.withValues(alpha: 0.7),
                    foregroundColor: colors.onSurfaceVariant,
                    onPressed: () => unawaited(_updateQueueState(entry, 'snoozed')),
                  ),
                  _ActionChipButton(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Закрыть',
                    backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.12),
                    borderColor: theme.dividerColor.withValues(alpha: 0.7),
                    foregroundColor: colors.onSurfaceVariant,
                    onPressed: () => unawaited(_updateQueueState(entry, 'resolved')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(color: colors.primary),
            const SizedBox(height: 16),
            Text(
              'Загружаем очередь...',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Сначала появятся ближайшие по приоритету карточки.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _SectionCard(
            title: 'Очередь спокойна',
            subtitle: 'Сейчас нет активных клиентов в фокусе.',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Icon(
                  Icons.inbox_outlined,
                  size: 44,
                  color: colors.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Как только появится новый сигнал, карточка отобразится здесь. Можно обновить экран или перейти к полному списку клиентов.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _refreshQueue,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Обновить'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.onOpenClients,
                      icon: const Icon(Icons.people_alt_rounded),
                      label: const Text('Клиенты'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _SectionCard(
            title: 'Не удалось загрузить очередь',
            subtitle: 'Можно повторить запрос без потери состояния экрана.',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Icon(
                  Icons.cloud_off_rounded,
                  size: 44,
                  color: colors.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'Сервис очереди временно недоступен.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.center,
                  child: FilledButton.icon(
                    onPressed: _retryQueue,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Повторить'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreFooter(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    if (_isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: <Widget>[
              CircularProgressIndicator(color: colors.primary),
              const SizedBox(height: 12),
              Text(
                'Подгружаем следующую порцию...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasMore) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Text(
          'Показаны все актуальные записи.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Center(
        child: FilledButton.icon(
          onPressed: _loadMore,
          icon: const Icon(Icons.expand_more_rounded),
          label: const Text('Показать еще'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (_isInitialLoading && _entries.isEmpty) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: _buildLoadingState(context),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        onRefresh: _refreshQueue,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: <Widget>[
            if (_isRefreshing)
              const SliverToBoxAdapter(
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_entries.isNotEmpty) ...<Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildIntroSection(context),
                ),
              ),
              if (_errorMessage != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.7)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Icon(
                            Icons.info_outline_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _retryQueue,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _buildSnapshotSection(context, _selectedEntry ?? _entries.first),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: _buildQueueHeader(context),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      final _CoachWorkqueueEntry entry = _entries[index];
                      return Padding(
                        padding: EdgeInsets.only(bottom: index == _entries.length - 1 ? 0 : 12),
                        child: _buildQueueCard(context, entry),
                      );
                    },
                    childCount: _entries.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _buildLoadMoreFooter(context),
              ),
            ] else ...<Widget>[
              if (_errorMessage != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildErrorState(context),
                )
              else
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(context),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CoachWorkqueueEntry {
  const _CoachWorkqueueEntry({
    required this.id,
    required this.coachId,
    required this.userId,
    required this.displayName,
    required this.avatarUrl,
    required this.priorityScore,
    required this.priorityLevel,
    required this.queueState,
    required this.attentionReason,
    required this.recommendedAction,
    required this.snapshot,
    required this.metadata,
    required this.sourceEventId,
    required this.sourceEventType,
    required this.createdAt,
    required this.updatedAt,
    required this.resolvedAt,
    required this.lastEvaluatedAt,
  });

  factory _CoachWorkqueueEntry.fromRows({
    required Map<String, dynamic> itemRow,
    required Map<String, dynamic>? userRow,
  }) {
    final String userId = itemRow['user_id']?.toString().trim() ?? '';
    final String displayName = _text(userRow, 'full_name').trim().isNotEmpty
        ? _text(userRow, 'full_name')
        : 'Без имени';

    return _CoachWorkqueueEntry(
      id: itemRow['id']?.toString().trim() ?? '',
      coachId: itemRow['coach_id']?.toString().trim() ?? '',
      userId: userId,
      displayName: displayName,
      avatarUrl: _text(userRow, 'avatar_url'),
      priorityScore: _doubleValue(itemRow['priority_score']),
      priorityLevel: _text(itemRow, 'priority_level', fallback: 'low'),
      queueState: _text(itemRow, 'queue_state', fallback: 'active'),
      attentionReason: _text(itemRow, 'attention_reason'),
      recommendedAction: _text(itemRow, 'recommended_action', fallback: 'no_action'),
      snapshot: _BehaviorSnapshot.fromMap(_jsonMap(itemRow['behavior_snapshot'])),
      metadata: _jsonMap(itemRow['metadata']),
      sourceEventId: itemRow['source_event_id']?.toString().trim() ?? '',
      sourceEventType: _text(itemRow, 'source_event_type'),
      createdAt: _dateTime(itemRow['created_at']) ?? DateTime.now(),
      updatedAt: _dateTime(itemRow['updated_at']) ?? DateTime.now(),
      resolvedAt: _dateTime(itemRow['resolved_at']),
      lastEvaluatedAt: _dateTime(itemRow['last_evaluated_at']) ?? DateTime.now(),
    );
  }

  final String id;
  final String coachId;
  final String userId;
  final String displayName;
  final String avatarUrl;
  final double priorityScore;
  final String priorityLevel;
  final String queueState;
  final String attentionReason;
  final String recommendedAction;
  final _BehaviorSnapshot snapshot;
  final Map<String, dynamic> metadata;
  final String sourceEventId;
  final String sourceEventType;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final DateTime lastEvaluatedAt;

  String get priorityLabel => _priorityLabel(priorityLevel);

  String get behaviorSummary => _attentionSummary(snapshot);

  String get nextStepLabel => _recommendedActionLabel(recommendedAction);

  String get latestEventLabel => _lastEventLabel(snapshot);

  String get lastMeaningfulActivityLabel => _lastActivityLabel(snapshot);

  String get silenceLabel => _silenceLabel(snapshot.silenceDays);

  String get streakTrendLabel => _trendLabel(snapshot);

  CoachClientRouteArgs routeArgs({String initialDraft = ''}) {
    return CoachClientRouteArgs(
      clientId: userId,
      clientName: displayName,
      avatarUrl: avatarUrl,
      initialDraft: initialDraft,
    );
  }
}

class _BehaviorSnapshot {
  const _BehaviorSnapshot({
    required this.attentionState,
    required this.priorityLevel,
    required this.priorityScore,
    required this.recommendedAction,
    required this.attentionReason,
    required this.lastEventAt,
    required this.lastEventType,
    required this.lastEventFamily,
    required this.latestCheckinAt,
    required this.latestTaskAt,
    required this.latestMessageAt,
    required this.latestCoachInterventionAt,
    required this.silenceDays,
    required this.baselineWindowDays,
    required this.totalEvents7d,
    required this.checkins7d,
    required this.tasksDone7d,
    required this.tasksSkipped7d,
    required this.messagesSent7d,
    required this.messagesRead7d,
    required this.coachMessagesSent7d,
    required this.coachInterventions14d,
    required this.interventionResponses14d,
    required this.interventionCreated14d,
    required this.returnAfterSilence,
    required this.positiveMomentum,
    required this.instability,
    required this.readNoReply,
    required this.recentInterventionNoResponse,
    required this.missedCheckin,
    required this.progressScore,
    required this.engagementLevel,
    required this.consistencyStreak,
    required this.daysSinceLastActivity,
    required this.lastKnownStatus,
    required this.lastResponseAt,
  });

  factory _BehaviorSnapshot.fromMap(Map<String, dynamic> row) {
    return _BehaviorSnapshot(
      attentionState: _text(row, 'attention_state', fallback: 'low_concern'),
      priorityLevel: _text(row, 'priority_level', fallback: 'low'),
      priorityScore: _doubleValue(row['priority_score']),
      recommendedAction: _text(row, 'recommended_action', fallback: 'no_action'),
      attentionReason: _text(row, 'attention_reason'),
      lastEventAt: _dateTime(row['last_event_at']),
      lastEventType: _text(row, 'last_event_type'),
      lastEventFamily: _text(row, 'last_event_family'),
      latestCheckinAt: _dateTime(row['latest_checkin_at']),
      latestTaskAt: _dateTime(row['latest_task_at']),
      latestMessageAt: _dateTime(row['latest_message_at']),
      latestCoachInterventionAt: _dateTime(row['latest_coach_intervention_at']),
      silenceDays: _intValue(row['silence_days']),
      baselineWindowDays: _intValue(row['baseline_window_days']),
      totalEvents7d: _intValue(row['total_events_7d']),
      checkins7d: _intValue(row['checkins_7d']),
      tasksDone7d: _intValue(row['tasks_done_7d']),
      tasksSkipped7d: _intValue(row['tasks_skipped_7d']),
      messagesSent7d: _intValue(row['messages_sent_7d']),
      messagesRead7d: _intValue(row['messages_read_7d']),
      coachMessagesSent7d: _intValue(row['coach_messages_sent_7d']),
      coachInterventions14d: _intValue(row['coach_interventions_14d']),
      interventionResponses14d: _intValue(row['intervention_responses_14d']),
      interventionCreated14d: _intValue(row['intervention_created_14d']),
      returnAfterSilence: _boolValue(row['return_after_silence']),
      positiveMomentum: _boolValue(row['positive_momentum']),
      instability: _boolValue(row['instability']),
      readNoReply: _boolValue(row['read_no_reply']),
      recentInterventionNoResponse: _boolValue(row['recent_intervention_no_response']),
      missedCheckin: _boolValue(row['missed_checkin']),
      progressScore: _intValue(row['progress_score']),
      engagementLevel: _intValue(row['engagement_level']),
      consistencyStreak: _intValue(row['consistency_streak']),
      daysSinceLastActivity: _intValue(row['days_since_last_activity']),
      lastKnownStatus: _text(row, 'last_known_status', fallback: 'onboarding'),
      lastResponseAt: _dateTime(row['last_response_at']),
    );
  }

  final String attentionState;
  final String priorityLevel;
  final double priorityScore;
  final String recommendedAction;
  final String attentionReason;
  final DateTime? lastEventAt;
  final String lastEventType;
  final String lastEventFamily;
  final DateTime? latestCheckinAt;
  final DateTime? latestTaskAt;
  final DateTime? latestMessageAt;
  final DateTime? latestCoachInterventionAt;
  final int silenceDays;
  final int baselineWindowDays;
  final int totalEvents7d;
  final int checkins7d;
  final int tasksDone7d;
  final int tasksSkipped7d;
  final int messagesSent7d;
  final int messagesRead7d;
  final int coachMessagesSent7d;
  final int coachInterventions14d;
  final int interventionResponses14d;
  final int interventionCreated14d;
  final bool returnAfterSilence;
  final bool positiveMomentum;
  final bool instability;
  final bool readNoReply;
  final bool recentInterventionNoResponse;
  final bool missedCheckin;
  final int progressScore;
  final int engagementLevel;
  final int consistencyStreak;
  final int daysSinceLastActivity;
  final String lastKnownStatus;
  final DateTime? lastResponseAt;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

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
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
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
        color: colors.surfaceContainerHighest.withValues(alpha: 0.15),
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

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.palette,
  });

  final String label;
  final _BadgePalette palette;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: palette.foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
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

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color resolvedBackground = backgroundColor ?? colors.surfaceContainerHighest.withValues(alpha: 0.14);
    final Color resolvedForeground = foregroundColor ?? colors.onSurfaceVariant;
    final Color resolvedBorder = borderColor ?? theme.dividerColor.withValues(alpha: 0.7);

    return Material(
      color: resolvedBackground,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: resolvedBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 14, color: resolvedForeground),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: resolvedForeground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Map<String, dynamic>? _singleRowFromRpc(dynamic result) {
  if (result is Map<String, dynamic>) {
    return result;
  }

  if (result is List<dynamic> && result.isNotEmpty) {
    final Object? first = result.first;
    if (first is Map<String, dynamic>) {
      return first;
    }
    if (first is Map) {
      return first.map((Object? key, Object? value) {
        return MapEntry(key?.toString() ?? '', value);
      });
    }
  }

  return null;
}
