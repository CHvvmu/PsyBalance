import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

DateTime _currentWeekStart([DateTime? reference]) {
  final DateTime value = reference ?? DateTime.now();
  final DateTime localDate = DateTime(value.year, value.month, value.day);
  return localDate.subtract(Duration(days: localDate.weekday - 1));
}

String _dateKey(DateTime value) {
  final String day = value.day.toString().padLeft(2, '0');
  final String month = value.month.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _errorSummary(PostgrestException error) {
  return <Object?>[error.message, error.details, error.hint]
      .whereType<String>()
      .where((String value) => value.trim().isNotEmpty)
      .join(' | ');
}

Map<String, dynamic>? _singleRowFromRpc(dynamic result) {
  if (result is Map<String, dynamic>) {
    return result;
  }

  if (result is List<dynamic> && result.isNotEmpty && result.first is Map<String, dynamic>) {
    return result.first as Map<String, dynamic>;
  }

  return null;
}

bool _isMissingArchivedAtColumn(PostgrestException error) {
  final String combined = _errorSummary(error).toLowerCase();
  return combined.contains('archived_at') &&
      (combined.contains('does not exist') || combined.contains('undefined column'));
}

Future<Map<String, dynamic>?> loadOrCreateActivePlanRow({
  required SupabaseClient client,
  required String userId,
  String sourceLabel = 'active-plan',
}) async {
  final String trimmedUserId = userId.trim();
  if (trimmedUserId.isEmpty) {
    debugPrint('ACTIVE PLAN LOAD SKIP: source=$sourceLabel reason=empty_user_id');
    return null;
  }

  final DateTime weekStart = _currentWeekStart();
  final DateTime nextWeekStart = weekStart.add(const Duration(days: 7));
  final String weekStartKey = _dateKey(weekStart);
  final String nextWeekStartKey = _dateKey(nextWeekStart);

  debugPrint(
    'ACTIVE PLAN LOAD START: source=$sourceLabel userId=$trimmedUserId weekStart=$weekStartKey nextWeekStart=$nextWeekStartKey',
  );

  try {
    final Map<String, dynamic>? row = await client
        .from('plans')
        .select('id, user_id, week_start, created_at')
        .eq('user_id', trimmedUserId)
        .gte('week_start', weekStartKey)
        .lt('week_start', nextWeekStartKey)
        .order('week_start', ascending: true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row != null) {
      debugPrint(
        'ACTIVE PLAN LOAD FOUND: source=$sourceLabel userId=$trimmedUserId planId=${row['id']} weekStart=${row['week_start']}',
      );
      return row;
    }

    debugPrint(
      'ACTIVE PLAN LOAD MISS: source=$sourceLabel userId=$trimmedUserId weekStart=$weekStartKey bootstrap_requested=true',
    );
  } on PostgrestException catch (error) {
    debugPrint(
      'ACTIVE PLAN LOAD QUERY ERROR: source=$sourceLabel userId=$trimmedUserId message=${error.message} details=${error.details} hint=${error.hint}',
    );
  } catch (error) {
    debugPrint('ACTIVE PLAN LOAD QUERY ERROR: source=$sourceLabel userId=$trimmedUserId error=$error');
  }

  try {
    final dynamic result = await client.rpc(
      'get_or_create_active_plan',
      params: <String, dynamic>{
        'p_user_id': trimmedUserId,
        'p_week_start': weekStartKey,
      },
    );

    final Map<String, dynamic>? row = _singleRowFromRpc(result);
    if (row != null) {
      debugPrint(
        'ACTIVE PLAN BOOTSTRAP RESULT: source=$sourceLabel userId=$trimmedUserId planId=${row['id']} weekStart=${row['week_start']}',
      );
    } else {
      debugPrint(
        'ACTIVE PLAN BOOTSTRAP EMPTY: source=$sourceLabel userId=$trimmedUserId weekStart=$weekStartKey',
      );
    }

    return row;
  } on PostgrestException catch (error) {
    debugPrint(
      'ACTIVE PLAN BOOTSTRAP ERROR: source=$sourceLabel userId=$trimmedUserId message=${error.message} details=${error.details} hint=${error.hint}',
    );
    rethrow;
  } catch (error) {
    debugPrint('ACTIVE PLAN BOOTSTRAP ERROR: source=$sourceLabel userId=$trimmedUserId error=$error');
    rethrow;
  }
}

Future<List<Map<String, dynamic>>> loadActivePlanItemRows({
  required SupabaseClient client,
  required String planId,
  String sourceLabel = 'active-plan',
}) async {
  final String trimmedPlanId = planId.trim();
  if (trimmedPlanId.isEmpty) {
    debugPrint('ACTIVE PLAN ITEMS LOAD SKIP: source=$sourceLabel reason=empty_plan_id');
    return <Map<String, dynamic>>[];
  }

  debugPrint('ACTIVE PLAN ITEMS LOAD START: source=$sourceLabel planId=$trimmedPlanId');

  try {
    final List<dynamic> rows = await client
        .from('plan_items')
        .select('id, plan_id, title, description, status, created_at, updated_at, scheduled_at, task_category')
        .isFilter('archived_at', null)
        .eq('plan_id', trimmedPlanId);

    final List<Map<String, dynamic>> items = rows.cast<Map<String, dynamic>>();
    debugPrint(
      'ACTIVE PLAN ITEMS LOAD SUCCESS: source=$sourceLabel planId=$trimmedPlanId count=${items.length}',
    );
    return items;
  } on PostgrestException catch (error) {
    if (_isMissingArchivedAtColumn(error)) {
      debugPrint(
        'ACTIVE PLAN ITEMS LOAD FALLBACK: source=$sourceLabel planId=$trimmedPlanId archived_at_missing=true',
      );

      final List<dynamic> rows = await client
          .from('plan_items')
          .select('id, plan_id, title, description, status, created_at, updated_at, scheduled_at, task_category')
          .eq('plan_id', trimmedPlanId);

      final List<Map<String, dynamic>> items = rows.cast<Map<String, dynamic>>();
      debugPrint(
        'ACTIVE PLAN ITEMS LOAD SUCCESS: source=$sourceLabel planId=$trimmedPlanId count=${items.length}',
      );
      return items;
    }

    debugPrint(
      'ACTIVE PLAN ITEMS LOAD ERROR: source=$sourceLabel planId=$trimmedPlanId message=${error.message} details=${error.details} hint=${error.hint}',
    );
    rethrow;
  } catch (error) {
    debugPrint('ACTIVE PLAN ITEMS LOAD ERROR: source=$sourceLabel planId=$trimmedPlanId error=$error');
    rethrow;
  }
}

Future<List<Map<String, dynamic>>> loadPlanItemsForClient({
  required SupabaseClient client,
  required String userId,
  String sourceLabel = 'active-plan',
}) async {
  final Map<String, dynamic>? planRow = await loadOrCreateActivePlanRow(
    client: client,
    userId: userId,
    sourceLabel: sourceLabel,
  );

  final String planId = planRow?['id']?.toString().trim() ?? '';
  if (planId.isEmpty) {
    return <Map<String, dynamic>>[];
  }

  return loadActivePlanItemRows(
    client: client,
    planId: planId,
    sourceLabel: sourceLabel,
  );
}

Future<Map<String, dynamic>?> loadPlanItemRowById({
  required SupabaseClient client,
  required String itemId,
  String sourceLabel = 'plan-item',
}) async {
  final String trimmedItemId = itemId.trim();
  if (trimmedItemId.isEmpty) {
    debugPrint('PLAN ITEM LOAD SKIP: source=$sourceLabel reason=empty_item_id');
    return null;
  }

  debugPrint('PLAN ITEM LOAD START: source=$sourceLabel itemId=$trimmedItemId');

  try {
    final Map<String, dynamic>? row = await client
        .from('plan_items')
        .select('id, plan_id, title, status, created_at, updated_at, scheduled_at, task_category')
        .isFilter('archived_at', null)
        .eq('id', trimmedItemId)
        .maybeSingle();

    debugPrint(
      'PLAN ITEM LOAD SUCCESS: source=$sourceLabel itemId=$trimmedItemId hasRow=${row != null}',
    );
    return row;
  } on PostgrestException catch (error) {
    if (_isMissingArchivedAtColumn(error)) {
      debugPrint(
        'PLAN ITEM LOAD FALLBACK: source=$sourceLabel itemId=$trimmedItemId archived_at_missing=true',
      );

      final Map<String, dynamic>? row = await client
          .from('plan_items')
          .select('id, plan_id, title, status, created_at, updated_at, scheduled_at, task_category')
          .eq('id', trimmedItemId)
          .maybeSingle();

      debugPrint(
        'PLAN ITEM LOAD SUCCESS: source=$sourceLabel itemId=$trimmedItemId hasRow=${row != null}',
      );
      return row;
    }

    debugPrint(
      'PLAN ITEM LOAD ERROR: source=$sourceLabel itemId=$trimmedItemId message=${error.message} details=${error.details} hint=${error.hint}',
    );
    rethrow;
  } catch (error) {
    debugPrint('PLAN ITEM LOAD ERROR: source=$sourceLabel itemId=$trimmedItemId error=$error');
    rethrow;
  }
}
