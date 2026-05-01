import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Stable, explainable contract for coach-authored support actions.
///
/// This layer is intentionally operational rather than autonomous: it records
/// what the coach chose, why it was chosen, and which signals were visible at
/// the time. No hidden scoring or automatic therapy logic lives here.
class CoachInterventionSignalSnapshot {
  const CoachInterventionSignalSnapshot({
    required this.priorityLevel,
    required this.recommendedAction,
    required this.attentionState,
    required this.attentionReason,
    required this.silenceDays,
    required this.lastKnownStatus,
    required this.lastEventType,
    required this.lastEventAt,
    required this.consistencyStreak,
    required this.daysSinceLastActivity,
    required this.progressScore,
    required this.engagementLevel,
    required this.returnAfterSilence,
    required this.readNoReply,
    required this.missedCheckin,
    required this.positiveMomentum,
    required this.instability,
    required this.recentInterventionNoResponse,
  });

  final String priorityLevel;
  final String recommendedAction;
  final String attentionState;
  final String attentionReason;
  final int silenceDays;
  final String lastKnownStatus;
  final String lastEventType;
  final DateTime? lastEventAt;
  final int consistencyStreak;
  final int daysSinceLastActivity;
  final int progressScore;
  final int engagementLevel;
  final bool returnAfterSilence;
  final bool readNoReply;
  final bool missedCheckin;
  final bool positiveMomentum;
  final bool instability;
  final bool recentInterventionNoResponse;

  Map<String, dynamic> toMetadata() {
    return <String, dynamic>{
      'priority_level': priorityLevel,
      'recommended_action': recommendedAction,
      'attention_state': attentionState,
      'attention_reason': attentionReason,
      'silence_days': silenceDays,
      'last_known_status': lastKnownStatus,
      'last_event_type': lastEventType,
      'last_event_at': lastEventAt?.toIso8601String(),
      'consistency_streak': consistencyStreak,
      'days_since_last_activity': daysSinceLastActivity,
      'progress_score': progressScore,
      'engagement_level': engagementLevel,
      'return_after_silence': returnAfterSilence,
      'read_no_reply': readNoReply,
      'missed_checkin': missedCheckin,
      'positive_momentum': positiveMomentum,
      'instability': instability,
      'recent_intervention_no_response': recentInterventionNoResponse,
    };
  }
}

/// Attribution chain for a coach intervention.
///
/// `correlationId` stays stable for the queue item. `causationId` points to the
/// source event that triggered the intervention (when known), so the chain can
/// be traced later without guessing.
class CoachInterventionAttribution {
  const CoachInterventionAttribution({
    required this.workqueueItemId,
    required this.correlationId,
    this.causationId,
    this.conversationId,
    this.messageId,
    this.sourceEventId,
  });

  factory CoachInterventionAttribution.forWorkqueue({
    required String workqueueItemId,
    String? sourceEventId,
    String? conversationId,
    String? messageId,
  }) {
    final String trimmedWorkqueueItemId = workqueueItemId.trim();
    return CoachInterventionAttribution(
      workqueueItemId: trimmedWorkqueueItemId,
      correlationId: trimmedWorkqueueItemId,
      causationId: sourceEventId?.trim().isNotEmpty == true ? sourceEventId!.trim() : null,
      conversationId: conversationId?.trim().isNotEmpty == true ? conversationId!.trim() : null,
      messageId: messageId?.trim().isNotEmpty == true ? messageId!.trim() : null,
      sourceEventId: sourceEventId?.trim().isNotEmpty == true ? sourceEventId!.trim() : null,
    );
  }

  final String workqueueItemId;
  final String correlationId;
  final String? causationId;
  final String? conversationId;
  final String? messageId;
  final String? sourceEventId;

  CoachInterventionAttribution copyWith({
    String? conversationId,
    String? messageId,
    String? causationId,
  }) {
    return CoachInterventionAttribution(
      workqueueItemId: workqueueItemId,
      correlationId: correlationId,
      causationId: causationId ?? this.causationId,
      conversationId: conversationId ?? this.conversationId,
      messageId: messageId ?? this.messageId,
      sourceEventId: sourceEventId,
    );
  }

  Map<String, dynamic> toMetadata({required String sourceScreen, required String trigger}) {
    return <String, dynamic>{
      'source_screen': sourceScreen,
      'trigger': trigger,
      'workqueue_item_id': workqueueItemId,
      'correlation_id': correlationId,
      'causation_id': causationId,
      'conversation_id': conversationId,
      'message_id': messageId,
      'source_event_id': sourceEventId,
    };
  }
}

/// Stable mapping from workqueue signals to an explainable intervention plan.
class CoachInterventionSemantics {
  const CoachInterventionSemantics({
    required this.behavioralIntent,
    required this.coachingPhase,
    required this.riskContext,
    required this.expectedResponseWindowHours,
    required this.tone,
    required this.followupStrategy,
    required this.pressureLevel,
    required this.interventionType,
    required this.messageType,
    required this.reason,
  });

  factory CoachInterventionSemantics.forPreset({
    required String presetKey,
    required CoachInterventionSignalSnapshot signals,
  }) {
    final String normalizedPreset = _normalizeKey(presetKey);
    final String normalizedAction = _normalizeKey(signals.recommendedAction);

    switch (normalizedPreset) {
      case 'micro_step':
        return CoachInterventionSemantics(
          behavioralIntent: 'reduce_friction',
          coachingPhase: _phaseForSignals(signals),
          riskContext: _riskContextForSignals(signals),
          expectedResponseWindowHours: _windowForSignals(signals, fallbackHours: 24),
          tone: 'practical',
          followupStrategy: 'single_nudge',
          pressureLevel: 'gentle',
          interventionType: 'micro_step',
          messageType: 'intervention',
          reason: 'Smallest possible next step to make the plan easier to start.',
        );
      case 'soft_checkin':
      default:
        final bool positive = signals.positiveMomentum && normalizedAction == 'celebrate_progress';
        return CoachInterventionSemantics(
          behavioralIntent: positive ? 'reinforce_progress' : 'restore_connection',
          coachingPhase: positive ? 'maintenance' : _phaseForSignals(signals),
          riskContext: _riskContextForSignals(signals),
          expectedResponseWindowHours: _windowForSignals(signals, fallbackHours: positive ? 48 : 24),
          tone: positive ? 'encouraging' : 'supportive',
          followupStrategy: positive ? 'observe' : 'single_nudge',
          pressureLevel: positive ? 'low' : 'low',
          interventionType: positive ? 'celebration' : 'soft_checkin',
          messageType: 'checkin_followup',
          reason: positive
              ? 'Stable momentum deserves reinforcement without extra pressure.'
              : 'Short, supportive outreach is the lowest-friction next step.',
        );
    }
  }

  final String behavioralIntent;
  final String coachingPhase;
  final String riskContext;
  final int expectedResponseWindowHours;
  final String tone;
  final String followupStrategy;
  final String pressureLevel;
  final String interventionType;
  final String messageType;
  final String reason;

  Map<String, dynamic> toMetadata({
    required CoachInterventionSignalSnapshot signals,
    required CoachInterventionAttribution attribution,
    required String sourceScreen,
    required String trigger,
    required String draft,
  }) {
    final Map<String, dynamic> attributionMetadata = attribution.toMetadata(
      sourceScreen: sourceScreen,
      trigger: trigger,
    );
    return <String, dynamic>{
      'semantic_contract_version': 1,
      'behavioral_intent': behavioralIntent,
      'coaching_phase': coachingPhase,
      'risk_context': riskContext,
      'expected_response_window_hours': expectedResponseWindowHours,
      'tone': tone,
      'followup_strategy': followupStrategy,
      'pressure_level': pressureLevel,
      'intervention_type': interventionType,
      'message_type': messageType,
      'reason': reason,
      'source_screen': sourceScreen,
      'trigger': trigger,
      'draft': draft,
      'workqueue_item_id': attribution.workqueueItemId,
      'correlation_id': attribution.correlationId,
      'causation_id': attribution.causationId,
      'conversation_id': attribution.conversationId,
      'message_id': attribution.messageId,
      'source_event_id': attribution.sourceEventId,
      'attribution': attributionMetadata,
      'signals': signals.toMetadata(),
    };
  }

  Map<String, dynamic> toCoachInterventionRow({
    required String coachId,
    required String userId,
    required CoachInterventionAttribution attribution,
    required String summary,
    required Map<String, dynamic> metadata,
    required String channel,
    required String status,
    required DateTime now,
  }) {
    return <String, dynamic>{
      'coach_id': coachId,
      'user_id': userId,
      'workqueue_item_id': attribution.workqueueItemId,
      'intervention_type': interventionType,
      'intervention_channel': channel,
      'status': status,
      'message_id': attribution.messageId,
      'conversation_id': attribution.conversationId,
      'trigger_event_id': attribution.sourceEventId,
      'correlation_id': attribution.correlationId,
      'causation_id': attribution.causationId,
      'summary': summary,
      'metadata': metadata,
      'delivered_at': now.toIso8601String(),
    };
  }
}

/// Derived interpretation of the latest intervention outcome.
///
/// The goal is to keep the chain explainable: recent intervention -> observed
/// signal(s) -> outcome label. The class does not infer mental state or hidden
/// intent.
class CoachInterventionOutcome {
  const CoachInterventionOutcome({
    required this.responseType,
    required this.label,
    required this.summary,
    required this.evidence,
    required this.attribution,
    required this.lastInterventionAt,
    required this.lastClientSignalAt,
    required this.expectedResponseWindowHours,
    required this.interventionCount,
  });

  factory CoachInterventionOutcome.none() {
    return const CoachInterventionOutcome(
      responseType: 'no_intervention',
      label: 'Интервенций пока нет',
      summary: 'Пока нет отправленных вмешательств, поэтому исход оценить нельзя.',
      evidence: <String>['Нет зафиксированных интервенций для этой пары.'],
      attribution: null,
      lastInterventionAt: null,
      lastClientSignalAt: null,
      expectedResponseWindowHours: 0,
      interventionCount: 0,
    );
  }

  static Future<CoachInterventionOutcome> load({
    required SupabaseClient client,
    required String coachId,
    required String userId,
  }) async {
    final String trimmedCoachId = coachId.trim();
    final String trimmedUserId = userId.trim();
    if (trimmedCoachId.isEmpty || trimmedUserId.isEmpty) {
      return CoachInterventionOutcome.none();
    }

    final List<dynamic> interventionRows = await client
        .from('coach_interventions')
        .select(
          'id, coach_id, user_id, workqueue_item_id, intervention_type, intervention_channel, status, message_id, conversation_id, trigger_event_id, correlation_id, causation_id, summary, metadata, created_at, delivered_at, acknowledged_at, responded_at',
        )
        .eq('coach_id', trimmedCoachId)
        .eq('user_id', trimmedUserId)
        .order('created_at', ascending: false)
        .limit(6);

    if (interventionRows.isEmpty) {
      return CoachInterventionOutcome.none();
    }

    final List<_CoachInterventionRow> interventions = interventionRows
        .map((dynamic rowData) => _CoachInterventionRow.fromMap(rowData as Map<String, dynamic>))
        .toList(growable: false);

    final _CoachInterventionRow latest = interventions.first;
    final String workqueueItemId = latest.workqueueItemId.trim().isNotEmpty ? latest.workqueueItemId.trim() : latest.id;
    final CoachInterventionAttribution attribution = CoachInterventionAttribution.forWorkqueue(
      workqueueItemId: workqueueItemId,
      sourceEventId: latest.triggerEventId,
      conversationId: latest.conversationId,
      messageId: latest.messageId,
    );
    final CoachInterventionSignalSnapshot? signalSnapshot = _signalsFromMetadata(latest.metadata);
    final int responseWindowHours = _windowFromMetadata(latest.metadata) ?? 24;

    final DateTime interventionAt = latest.deliveryTime ?? latest.respondedAt ?? latest.acknowledgedAt ?? latest.createdAt;
    final List<String> conversationIds = interventions
        .map((_CoachInterventionRow row) => row.conversationId)
        .whereType<String>()
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final Future<List<dynamic>> behaviorEventsFuture = client
        .from('behavior_events')
        .select('id, occurred_at, actor_type, event_family, event_type, correlation_id, causation_id, summary, metadata, source_table, source_id')
        .eq('primary_user_id', trimmedUserId)
        .order('occurred_at', ascending: false)
        .limit(30);

    final Future<List<dynamic>> taskActivityFuture = client
        .from('task_activity')
        .select('id, user_id, task_id, event_type, completed, skipped, created_at, updated_at, completed_at, metadata')
        .eq('user_id', trimmedUserId)
        .order('created_at', ascending: false)
        .limit(20);

    final Future<List<dynamic>> messagesFuture = conversationIds.isEmpty
        ? Future<List<dynamic>>.value(<dynamic>[])
        : client
            .from('messages')
            .select('id, conversation_id, sender_id, receiver_id, sender_role, message_type, content, text, metadata, created_at, read_at')
            .inFilter('conversation_id', conversationIds)
            .order('created_at', ascending: false)
            .limit(20);

    final List<dynamic> results = await Future.wait(<Future<dynamic>>[
      behaviorEventsFuture,
      taskActivityFuture,
      messagesFuture,
    ]);

    final List<_CoachBehaviorEvent> behaviorEvents = (results[0] as List<dynamic>)
        .map((dynamic rowData) => _CoachBehaviorEvent.fromBehaviorEvent(rowData as Map<String, dynamic>))
        .toList(growable: false);
    final List<_CoachTaskActivity> taskActivities = (results[1] as List<dynamic>)
        .map((dynamic rowData) => _CoachTaskActivity.fromMap(rowData as Map<String, dynamic>))
        .toList(growable: false);
    final List<_CoachMessage> messages = (results[2] as List<dynamic>)
        .map((dynamic rowData) => _CoachMessage.fromMap(rowData as Map<String, dynamic>))
        .toList(growable: false);

    final List<_OutcomeSignal> postSignals = <_OutcomeSignal>[];

    for (final _CoachMessage message in messages) {
      if (message.createdAt.isBefore(interventionAt)) {
        continue;
      }
      postSignals.add(
        _OutcomeSignal(
          time: message.createdAt,
          kind: 'message',
          label: message.senderRole == 'client' ? 'Сообщение клиента' : 'Сообщение коуча',
          detail: _shorten(_cleanText(message.content), 96),
          isClientSignal: message.senderRole == 'client',
          isReadOnly: false,
        ),
      );
    }

    for (final _CoachBehaviorEvent event in behaviorEvents) {
      if (event.occurredAt.isBefore(interventionAt)) {
        continue;
      }
      postSignals.add(
        _OutcomeSignal(
          time: event.occurredAt,
          kind: event.eventFamily,
          label: _labelForBehaviorEvent(event.eventFamily, event.eventType),
          detail: event.summary,
          isClientSignal: _isClientActor(event.actorType),
          isReadOnly: event.eventType == 'message_read',
        ),
      );
    }

    for (final _CoachTaskActivity task in taskActivities) {
      final DateTime? taskTime = task.occurredAt;
      if (taskTime == null || taskTime.isBefore(interventionAt)) {
        continue;
      }
      final bool completed = task.completed;
      postSignals.add(
        _OutcomeSignal(
          time: taskTime,
          kind: 'task',
          label: completed ? 'Задача завершена' : 'Задача изменена',
          detail: _taskActivityDetail(task),
          isClientSignal: completed,
          isReadOnly: false,
        ),
      );
    }

    postSignals.sort((_OutcomeSignal left, _OutcomeSignal right) => left.time.compareTo(right.time));

    final _OutcomeSignal? firstClientSignal = postSignals.cast<_OutcomeSignal?>().firstWhere(
          (_OutcomeSignal? signal) => signal != null && signal.isClientSignal,
          orElse: () => null,
        );
    final _OutcomeSignal? firstReplyMessage = postSignals.cast<_OutcomeSignal?>().firstWhere(
          (_OutcomeSignal? signal) =>
              signal != null && signal.kind == 'message' && signal.isClientSignal,
          orElse: () => null,
        );
    final _OutcomeSignal? firstTaskCompletion = postSignals.cast<_OutcomeSignal?>().firstWhere(
          (_OutcomeSignal? signal) => signal != null && signal.kind == 'task' && signal.isClientSignal,
          orElse: () => null,
        );
    final _OutcomeSignal? firstCheckin = postSignals.cast<_OutcomeSignal?>().firstWhere(
          (_OutcomeSignal? signal) => signal != null && signal.kind == 'checkin' && signal.isClientSignal,
          orElse: () => null,
        );
    final _OutcomeSignal? readOnlySignal = postSignals.cast<_OutcomeSignal?>().firstWhere(
          (_OutcomeSignal? signal) => signal != null && signal.isReadOnly,
          orElse: () => null,
        );

    final DateTime? lastClientSignalAt = firstClientSignal?.time;
    final DateTime? lastPreInterventionSignalAt = _latestPreInterventionSignalAt(
      behaviorEvents: behaviorEvents,
      taskActivities: taskActivities,
      messages: messages,
      interventionAt: interventionAt,
    );
    final int gapDays = _gapDaysBetween(lastPreInterventionSignalAt, firstClientSignal?.time);
    final int expectedWindowHours = responseWindowHours;
    final bool windowExpired = DateTime.now().difference(interventionAt).inHours >= expectedWindowHours;

    final List<String> evidence = <String>[];
    String responseType = 'no_response';
    String label = 'Ответа пока нет';
    String summary = windowExpired
        ? 'За прошедшее окно ответа не было.'
        : 'Интервенция отправлена; окно ответа еще открыто.';

    if (firstTaskCompletion != null) {
      responseType = 'task_completion_after_intervention';
      label = 'Задача завершена после интервенции';
      summary = 'После поддержки появилось завершение задачи — это самый сильный позитивный сигнал.';
      evidence.add('${_formatClock(firstTaskCompletion.time)} · ${firstTaskCompletion.label}');
      if (firstTaskCompletion.detail.isNotEmpty) {
        evidence.add(firstTaskCompletion.detail);
      }
    } else if (firstCheckin != null || firstReplyMessage != null) {
      final _OutcomeSignal chosenSignal = firstReplyMessage ?? firstCheckin!;
      final bool returnedAfterSilence = _shouldTreatAsReturnAfterSilence(
        signals: signalSnapshot,
        gapDays: gapDays,
      );
      if (returnedAfterSilence) {
        responseType = 'return_after_silence';
        label = 'Возврат после паузы';
        summary = 'После паузы появился новый сигнал — это признак возвращения к контакту.';
      } else if (firstReplyMessage != null && _isAcknowledgementOnly(firstReplyMessage.detail)) {
        responseType = 'acknowledged_only';
        label = 'Короткое подтверждение';
        summary = 'Ответ есть, но он короткий и без продолжения — лучше не усиливать давление.';
      } else if (firstReplyMessage != null) {
        responseType = 'meaningful_reply';
        label = 'Содержательный ответ';
        summary = 'Появился содержательный ответ после интервенции.';
      } else {
        responseType = 'return_after_silence';
        label = 'Возврат после паузы';
        summary = 'После интервенции появился чек-ин — это признак возвращения в контакт.';
      }

      evidence.add('${_formatClock(chosenSignal.time)} · ${chosenSignal.label}');
      if (chosenSignal.detail.isNotEmpty) {
        evidence.add(chosenSignal.detail);
      }
      if (gapDays > 0) {
        evidence.add('Пауза до сигнала: $gapDays ${_daysWord(gapDays)}.');
      }
    } else if (readOnlySignal != null) {
      responseType = interventions.length > 1 || (signalSnapshot?.recentInterventionNoResponse == true)
          ? 'repeated_avoidance'
          : 'no_response';
      label = responseType == 'repeated_avoidance' ? 'Повторное избегание' : 'Ответа пока нет';
      summary = responseType == 'repeated_avoidance'
          ? 'Сообщение было прочитано, но ответа не последовало; это уже повторяющийся паттерн.'
          : 'Сообщение было прочитано, но ответа пока нет.';
      evidence.add('${_formatClock(readOnlySignal.time)} · ${readOnlySignal.label}');
      if (readOnlySignal.detail.isNotEmpty) {
        evidence.add(readOnlySignal.detail);
      }
      if (interventions.length > 1) {
        evidence.add('Последовательность интервенций: ${interventions.length}.');
      }
    } else if (windowExpired && (interventions.length > 1 || signalSnapshot?.recentInterventionNoResponse == true)) {
      responseType = 'repeated_avoidance';
      label = 'Повторное избегание';
      summary = 'Несколько интервенций подряд не получили ответа в ожидаемом окне.';
      evidence.add('Интервенций за период: ${interventions.length}.');
      evidence.add('Ответов в окне ожидания не зафиксировано.');
    } else {
      evidence.add(windowExpired ? 'Окно ожидания ответа закрыто.' : 'Окно ожидания ответа еще открыто.');
      evidence.add('Ответа, чек-ина или завершения задачи после интервенции не было.');
    }

    final String? confidenceLabel = _confidenceLabelFromSignals(signalSnapshot, responseType);
    if (confidenceLabel != null && confidenceLabel.isNotEmpty) {
      evidence.add(confidenceLabel);
    }

    return CoachInterventionOutcome(
      responseType: responseType,
      label: label,
      summary: summary,
      evidence: evidence,
      attribution: attribution,
      lastInterventionAt: interventionAt,
      lastClientSignalAt: lastClientSignalAt,
      expectedResponseWindowHours: expectedWindowHours,
      interventionCount: interventions.length,
    );
  }

  final String responseType;
  final String label;
  final String summary;
  final List<String> evidence;
  final CoachInterventionAttribution? attribution;
  final DateTime? lastInterventionAt;
  final DateTime? lastClientSignalAt;
  final int expectedResponseWindowHours;
  final int interventionCount;
}

String _normalizeKey(String value) {
  return value.trim().toLowerCase();
}

String _cleanText(Object? value) {
  final String text = value?.toString().trim() ?? '';
  return text;
}

String _shorten(String text, int maxChars) {
  if (text.length <= maxChars) {
    return text;
  }
  return '${text.substring(0, maxChars).trimRight()}…';
}

String _formatClock(DateTime value) {
  final DateTime local = value.toLocal();
  final String hour = local.hour.toString().padLeft(2, '0');
  final String minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _daysWord(int days) {
  final int mod100 = days % 100;
  if (mod100 >= 11 && mod100 <= 14) {
    return 'дней';
  }
  switch (days % 10) {
    case 1:
      return 'день';
    case 2:
    case 3:
    case 4:
      return 'дня';
    default:
      return 'дней';
  }
}

String _phaseForSignals(CoachInterventionSignalSnapshot signals) {
  if (signals.returnAfterSilence) {
    return 'recovery';
  }
  if (signals.readNoReply || signals.missedCheckin) {
    return 're_engagement';
  }
  if (signals.instability) {
    return 'stabilization';
  }
  if (signals.positiveMomentum) {
    return 'maintenance';
  }
  return 'support';
}

String _riskContextForSignals(CoachInterventionSignalSnapshot signals) {
  if (signals.returnAfterSilence) {
    return 'return_after_silence';
  }
  if (signals.readNoReply) {
    return 'read_without_reply';
  }
  if (signals.missedCheckin) {
    return 'missed_checkin';
  }
  if (signals.recentInterventionNoResponse) {
    return 'post_intervention_followup';
  }
  if (signals.instability) {
    return 'instability';
  }
  if (signals.positiveMomentum) {
    return 'positive_momentum';
  }
  return 'stable';
}

int _windowForSignals(CoachInterventionSignalSnapshot signals, {required int fallbackHours}) {
  if (signals.returnAfterSilence) {
    return 48;
  }
  if (signals.recentInterventionNoResponse) {
    return 24;
  }
  if (signals.readNoReply || signals.missedCheckin || signals.instability) {
    return 24;
  }
  if (signals.positiveMomentum) {
    return 48;
  }
  return fallbackHours;
}

bool _shouldTreatAsReturnAfterSilence({
  required CoachInterventionSignalSnapshot? signals,
  required int gapDays,
}) {
  if (signals?.returnAfterSilence == true) {
    return true;
  }
  return gapDays >= 3;
}

bool _isAcknowledgementOnly(String text) {
  final String normalized = text.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }

  if (normalized.length > 24) {
    return false;
  }

  const List<String> acknowledgementTokens = <String>[
    'ok',
    'okay',
    'ок',
    'окей',
    'ага',
    'да',
    'понял',
    'поняла',
    'принято',
    'спасибо',
    'got it',
    'understood',
  ];

  for (final String token in acknowledgementTokens) {
    if (normalized == token || normalized.startsWith('$token ')) {
      return true;
    }
  }

  return normalized.split(RegExp(r'\s+')).length <= 3 && !normalized.contains('?');
}

String _taskActivityDetail(_CoachTaskActivity task) {
  final String title = _cleanText(task.taskTitle);
  if (task.completed) {
    return title.isNotEmpty
        ? 'Задача завершена: $title'
        : 'Задача завершена.';
  }
  if (task.skipped) {
    return title.isNotEmpty
        ? 'Задача пропущена: $title'
        : 'Задача пропущена.';
  }
  return title.isNotEmpty ? title : 'Изменение задачи без финального статуса.';
}

String _labelForBehaviorEvent(String eventFamily, String eventType) {
  switch (_normalizeKey(eventFamily)) {
    case 'message':
      switch (_normalizeKey(eventType)) {
        case 'message_read':
          return 'Сообщение прочитано';
        case 'message_sent':
          return 'Сообщение отправлено';
        default:
          return 'Сообщение';
      }
    case 'checkin':
      return 'Чек-ин';
    case 'task':
      switch (_normalizeKey(eventType)) {
        case 'task_completed':
          return 'Задача завершена';
        case 'task_skipped':
          return 'Задача пропущена';
        default:
          return 'Задача';
      }
    case 'intervention':
      switch (_normalizeKey(eventType)) {
        case 'intervention_responded':
          return 'Ответ на интервенцию';
        case 'intervention_created':
          return 'Интервенция';
        default:
          return 'Интервенция';
      }
    default:
      return 'Сигнал';
  }
}

bool _isClientActor(String? actorType) {
  final String normalized = _normalizeKey(actorType ?? '');
  return normalized == 'client';
}

int _gapDaysBetween(DateTime? left, DateTime? right) {
  if (left == null || right == null) {
    return 0;
  }
  final DateTime leftDay = _dateOnly(left);
  final DateTime rightDay = _dateOnly(right);
  final int days = rightDay.difference(leftDay).inDays;
  return days < 0 ? 0 : days;
}

DateTime _dateOnly(DateTime value) {
  final DateTime local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime? _latestPreInterventionSignalAt({
  required List<_CoachBehaviorEvent> behaviorEvents,
  required List<_CoachTaskActivity> taskActivities,
  required List<_CoachMessage> messages,
  required DateTime interventionAt,
}) {
  DateTime? latest;

  void consider(DateTime? candidate) {
    if (candidate == null || !candidate.isBefore(interventionAt)) {
      return;
    }
    if (latest == null || candidate.isAfter(latest!)) {
      latest = candidate;
    }
  }

  for (final _CoachMessage message in messages) {
    consider(message.createdAt);
  }
  for (final _CoachBehaviorEvent event in behaviorEvents) {
    consider(event.occurredAt);
  }
  for (final _CoachTaskActivity task in taskActivities) {
    consider(task.occurredAt);
  }

  return latest;
}

String? _confidenceLabelFromSignals(
  CoachInterventionSignalSnapshot? signals,
  String responseType,
) {
  if (signals == null) {
    return null;
  }

  switch (responseType) {
    case 'task_completion_after_intervention':
      return 'Сильный позитивный сигнал: завершение задачи.';
    case 'return_after_silence':
      return signals.returnAfterSilence
          ? 'Сигнал возврата подтвержден исходными данными.'
          : 'Сигнал возврата оценен по длительной паузе.';
    case 'meaningful_reply':
      return 'Содержательный ответ подтвержден текстом сообщения.';
    case 'acknowledged_only':
      return 'Ответ есть, но он короткий и без продолжения.';
    case 'repeated_avoidance':
      return 'Повторяющийся паттерн: сообщение читается, но ответ не следует.';
    default:
      return signals.recentInterventionNoResponse
          ? 'В метаданных уже отмечался недавний ответ без продолжения.'
          : null;
  }
}

CoachInterventionSignalSnapshot? _signalsFromMetadata(Map<String, dynamic> metadata) {
  final Object? rawSignals = metadata['signals'];
  if (rawSignals is! Map) {
    return null;
  }

  final Map<String, dynamic> signals = rawSignals.map((Object? key, Object? value) {
    return MapEntry(key?.toString() ?? '', value);
  });

  return CoachInterventionSignalSnapshot(
    priorityLevel: _stringValue(signals, 'priority_level', fallback: 'low'),
    recommendedAction: _stringValue(signals, 'recommended_action', fallback: 'no_action'),
    attentionState: _stringValue(signals, 'attention_state', fallback: 'low_concern'),
    attentionReason: _stringValue(signals, 'attention_reason'),
    silenceDays: _intValue(signals['silence_days']),
    lastKnownStatus: _stringValue(signals, 'last_known_status', fallback: 'onboarding'),
    lastEventType: _stringValue(signals, 'last_event_type'),
    lastEventAt: _dateTime(signals['last_event_at']),
    consistencyStreak: _intValue(signals['consistency_streak']),
    daysSinceLastActivity: _intValue(signals['days_since_last_activity']),
    progressScore: _intValue(signals['progress_score']),
    engagementLevel: _intValue(signals['engagement_level']),
    returnAfterSilence: _boolValue(signals['return_after_silence']),
    readNoReply: _boolValue(signals['read_no_reply']),
    missedCheckin: _boolValue(signals['missed_checkin']),
    positiveMomentum: _boolValue(signals['positive_momentum']),
    instability: _boolValue(signals['instability']),
    recentInterventionNoResponse: _boolValue(signals['recent_intervention_no_response']),
  );
}

int? _windowFromMetadata(Map<String, dynamic> metadata) {
  final Object? raw = metadata['expected_response_window_hours'];
  if (raw == null) {
    return null;
  }
  return _intValue(raw);
}

String _stringValue(Map<String, dynamic> row, String key, {String fallback = ''}) {
  final dynamic raw = row[key];
  final String text = raw?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
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

bool _boolValue(Object? value) {
  if (value is bool) {
    return value;
  }
  final String text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'yes' || text == 't';
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

class _CoachInterventionRow {
  const _CoachInterventionRow({
    required this.id,
    required this.workqueueItemId,
    required this.interventionType,
    required this.conversationId,
    required this.messageId,
    required this.triggerEventId,
    required this.correlationId,
    required this.causationId,
    required this.summary,
    required this.metadata,
    required this.createdAt,
    required this.deliveryTime,
    required this.acknowledgedAt,
    required this.respondedAt,
  });

  factory _CoachInterventionRow.fromMap(Map<String, dynamic> row) {
    return _CoachInterventionRow(
      id: _stringValue(row, 'id'),
      workqueueItemId: _stringValue(row, 'workqueue_item_id'),
      interventionType: _stringValue(row, 'intervention_type'),
      conversationId: _stringValue(row, 'conversation_id'),
      messageId: _stringValue(row, 'message_id'),
      triggerEventId: _stringValue(row, 'trigger_event_id'),
      correlationId: _stringValue(row, 'correlation_id'),
      causationId: _stringValue(row, 'causation_id'),
      summary: _stringValue(row, 'summary'),
      metadata: _jsonMap(row['metadata']),
      createdAt: _dateTime(row['created_at']) ?? DateTime.now(),
      deliveryTime: _dateTime(row['delivered_at']),
      acknowledgedAt: _dateTime(row['acknowledged_at']),
      respondedAt: _dateTime(row['responded_at']),
    );
  }

  final String id;
  final String workqueueItemId;
  final String interventionType;
  final String conversationId;
  final String messageId;
  final String triggerEventId;
  final String correlationId;
  final String causationId;
  final String summary;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime? deliveryTime;
  final DateTime? acknowledgedAt;
  final DateTime? respondedAt;
}

class _CoachBehaviorEvent {
  const _CoachBehaviorEvent({
    required this.occurredAt,
    required this.actorType,
    required this.eventFamily,
    required this.eventType,
    required this.summary,
    required this.metadata,
    required this.correlationId,
    required this.causationId,
  });

  factory _CoachBehaviorEvent.fromBehaviorEvent(Map<String, dynamic> row) {
    return _CoachBehaviorEvent(
      occurredAt: _dateTime(row['occurred_at']) ?? DateTime.now(),
      actorType: _stringValue(row, 'actor_type'),
      eventFamily: _stringValue(row, 'event_family'),
      eventType: _stringValue(row, 'event_type'),
      summary: _stringValue(row, 'summary'),
      metadata: _jsonMap(row['metadata']),
      correlationId: _stringValue(row, 'correlation_id'),
      causationId: _stringValue(row, 'causation_id'),
    );
  }

  final DateTime occurredAt;
  final String actorType;
  final String eventFamily;
  final String eventType;
  final String summary;
  final Map<String, dynamic> metadata;
  final String correlationId;
  final String causationId;
}

class _CoachTaskActivity {
  const _CoachTaskActivity({
    required this.occurredAt,
    required this.taskTitle,
    required this.eventType,
    required this.completed,
    required this.skipped,
  });

  factory _CoachTaskActivity.fromMap(Map<String, dynamic> row) {
    return _CoachTaskActivity(
      occurredAt: _dateTime(row['completed_at']) ?? _dateTime(row['updated_at']) ?? _dateTime(row['created_at']),
      taskTitle: _stringValue(row, 'task_title'),
      eventType: _stringValue(row, 'event_type'),
      completed: _boolValue(row['completed']),
      skipped: _boolValue(row['skipped']),
    );
  }

  final DateTime? occurredAt;
  final String taskTitle;
  final String eventType;
  final bool completed;
  final bool skipped;
}

class _CoachMessage {
  const _CoachMessage({
    required this.createdAt,
    required this.senderRole,
    required this.messageType,
    required this.content,
  });

  factory _CoachMessage.fromMap(Map<String, dynamic> row) {
    return _CoachMessage(
      createdAt: _dateTime(row['created_at']) ?? DateTime.now(),
      senderRole: _stringValue(row, 'sender_role', fallback: 'client'),
      messageType: _stringValue(row, 'message_type', fallback: 'text'),
      content: _stringValue(row, 'content').isNotEmpty
          ? _stringValue(row, 'content')
          : _stringValue(row, 'text'),
    );
  }

  final DateTime createdAt;
  final String senderRole;
  final String messageType;
  final String content;
}

class _OutcomeSignal {
  const _OutcomeSignal({
    required this.time,
    required this.kind,
    required this.label,
    required this.detail,
    required this.isClientSignal,
    required this.isReadOnly,
  });

  final DateTime time;
  final String kind;
  final String label;
  final String detail;
  final bool isClientSignal;
  final bool isReadOnly;
}
