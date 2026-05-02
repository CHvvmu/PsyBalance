import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/navigation/app_route_observer.dart';
import '../../core/widgets/identity_avatar.dart';
import '../plan/active_plan_repository.dart';
import '../coach_panel/presentation/coach_route_args.dart';
import '../plan/plan_item_details_page.dart';

class ClientDashboardPage extends StatelessWidget {
  const ClientDashboardPage({
    super.key,
    required this.onOpenFood,
    required this.onOpenStress,
    required this.onOpenSleep,
    required this.onOpenSport,
    required this.onOpenPlan,
    required this.onOpenKnowledgeBase,
    required this.onOpenChat,
    required this.onAdd,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenFood;
  final VoidCallback onOpenStress;
  final VoidCallback onOpenSleep;
  final VoidCallback onOpenSport;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenKnowledgeBase;
  final VoidCallback onOpenChat;
  final VoidCallback onAdd;
  final Future<void> Function() onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return _BehavioralDashboardScreen(
      onOpenFood: onOpenFood,
      onOpenStress: onOpenStress,
      onOpenSleep: onOpenSleep,
      onOpenSport: onOpenSport,
      onOpenPlan: onOpenPlan,
      onOpenKnowledgeBase: onOpenKnowledgeBase,
      onOpenChat: onOpenChat,
      onAdd: onAdd,
      onOpenProfile: onOpenProfile,
    );
  }
}

class _MoodOption {
  const _MoodOption({
    required this.value,
    required this.emoji,
    required this.label,
  });

  final int value;
  final String emoji;
  final String label;
}

class _DashboardBehaviorStatusBadge extends StatefulWidget {
  const _DashboardBehaviorStatusBadge();

  @override
  State<_DashboardBehaviorStatusBadge> createState() => _DashboardBehaviorStatusBadgeState();
}

class _DashboardBehaviorStatusBadgeState extends State<_DashboardBehaviorStatusBadge> {
  final SupabaseClient _client = Supabase.instance.client;

  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final User? currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      return;
    }

    try {
      final Map<String, dynamic>? row = await _client
          .from('users')
          .select('progress_status')
          .eq('id', currentUser.id)
          .maybeSingle();

      if (!mounted) {
        return;
      }

      setState(() {
        _status = row?['progress_status']?.toString() ?? '';
      });
    } catch (error) {
      debugPrint('DASHBOARD STATUS LOAD ERROR: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BehaviorStatusPalette palette = behaviorStatusPaletteFor(_status);
    final String label = behaviorStatusLabel(_status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.verified_rounded,
            size: 14,
            color: palette.foreground,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BehavioralDashboardScreen extends StatelessWidget {
  const _BehavioralDashboardScreen({
    required this.onOpenFood,
    required this.onOpenStress,
    required this.onOpenSleep,
    required this.onOpenSport,
    required this.onOpenPlan,
    required this.onOpenKnowledgeBase,
    required this.onOpenChat,
    required this.onAdd,
    required this.onOpenProfile,
  });

  final VoidCallback onOpenFood;
  final VoidCallback onOpenStress;
  final VoidCallback onOpenSleep;
  final VoidCallback onOpenSport;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenKnowledgeBase;
  final VoidCallback onOpenChat;
  final VoidCallback onAdd;
  final Future<void> Function() onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    const Color success = Color(0xFF43A047);
    const Color accent = Color(0xFFE8DCCB);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Мягкий ежедневный ритм',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const _DashboardBehaviorStatusBadge(),
                    ],
                  ),
                  _DashboardProfileAvatar(
                    onOpenProfile: onOpenProfile,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _DailyCheckInSection(),
              const SizedBox(height: 20),
              Text(
                'Быстрые действия',
                style: textTheme.titleMedium?.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.photo_camera_rounded,
                      label: 'Еда',
                      backgroundColor: colors.primary.withValues(alpha: 0.2),
                      foregroundColor: colors.primary,
                      onTap: onOpenFood,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.self_improvement_rounded,
                      label: 'Стресс',
                      backgroundColor: colors.secondary.withValues(alpha: 0.2),
                      foregroundColor: colors.secondary,
                      onTap: onOpenStress,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.bed_rounded,
                      label: 'Сон',
                      backgroundColor: accent.withValues(alpha: 0.4),
                      foregroundColor: colors.onSurface,
                      onTap: onOpenSleep,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionButton(
                      icon: Icons.fitness_center_rounded,
                      label: 'Спорт',
                      backgroundColor: success.withValues(alpha: 0.2),
                      foregroundColor: success,
                      onTap: onOpenSport,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _DailyPlanSection(
                onOpenLegacyPlan: onOpenPlan,
                onOpenKnowledgeBase: onOpenKnowledgeBase,
              ),
              const SizedBox(height: 24),
              _CoachSupportSection(onOpenChat: onOpenChat),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FloatingActionButton.extended(
                  heroTag: 'clientDashboardAdd',
                  onPressed: onAdd,
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Добавить'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardProfileAvatar extends StatefulWidget {
  const _DashboardProfileAvatar({required this.onOpenProfile});

  final Future<void> Function() onOpenProfile;

  @override
  State<_DashboardProfileAvatar> createState() => _DashboardProfileAvatarState();
}

class _DashboardProfileAvatarState extends State<_DashboardProfileAvatar>
    with RouteAware {
  String _displayName = 'Без имени';
  String _avatarUrl = '';
  PageRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    _loadProfileAvatar();
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
    _loadProfileAvatar();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _loadProfileAvatar() async {
    final User? currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _displayName = 'Без имени';
        _avatarUrl = '';
      });
      return;
    }

    debugPrint('DASHBOARD AVATAR LOAD START: userId=${currentUser.id}');

    Map<String, dynamic>? row;
    try {
      row = await Supabase.instance.client
          .from('users')
          .select('full_name, avatar_url')
          .eq('id', currentUser.id)
          .maybeSingle();
      debugPrint('DASHBOARD AVATAR LOAD ROW: userId=${currentUser.id} hasRow=${row != null}');
    } on PostgrestException catch (error) {
      debugPrint(
        'DASHBOARD AVATAR LOAD ERROR: query=users.select(full_name, avatar_url) '
        'userId=${currentUser.id} message=${error.message} details=${error.details} hint=${error.hint}',
      );
    } catch (error) {
      debugPrint(
        'DASHBOARD AVATAR LOAD ERROR: query=users.select(full_name, avatar_url) '
        'userId=${currentUser.id} error=$error',
      );
    }

    final Map<String, dynamic>? metadata = currentUser.userMetadata;
    final String rowFullName = row?['full_name']?.toString().trim() ?? '';
    final String rowAvatarUrl = row?['avatar_url']?.toString().trim() ?? '';
    final String metadataFullName = metadata?['full_name']?.toString().trim() ?? '';
    final String metadataAvatarUrl = metadata?['avatar_url']?.toString().trim() ?? '';

    if (!mounted) {
      return;
    }

    setState(() {
      _displayName = rowFullName.isNotEmpty
          ? rowFullName
          : (metadataFullName.isNotEmpty ? metadataFullName : 'Без имени');
      _avatarUrl = rowAvatarUrl.isNotEmpty ? rowAvatarUrl : metadataAvatarUrl;
    });

    debugPrint(
      'DASHBOARD AVATAR LOAD SUCCESS: userId=${currentUser.id} '
      'displayName=$_displayName hasAvatar=${_avatarUrl.trim().isNotEmpty}',
    );
  }

  Future<void> _handleTap() async {
    await widget.onOpenProfile();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(999),
      child: IdentityAvatar(
        displayName: _displayName,
        avatarUrl: _avatarUrl,
        size: 52,
        backgroundColor: colors.primary.withValues(alpha: 0.14),
        borderColor: theme.dividerColor,
        borderWidth: 1.2,
        textColor: colors.primary,
      ),
    );
  }
}

class _DailyCheckInSection extends StatefulWidget {
  const _DailyCheckInSection();

  @override
  State<_DailyCheckInSection> createState() => _DailyCheckInSectionState();
}

class _DailyCheckInSectionState extends State<_DailyCheckInSection> {
  static const List<_MoodOption> _moodOptions = <_MoodOption>[
    _MoodOption(value: 1, emoji: '🙂', label: 'Хорошо'),
    _MoodOption(value: 2, emoji: '😐', label: 'Нормально'),
    _MoodOption(value: 3, emoji: '😔', label: 'Устал(а)'),
    _MoodOption(value: 4, emoji: '😤', label: 'Стресс'),
    _MoodOption(value: 5, emoji: '😴', label: 'Нет энергии'),
  ];

  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _checkInId;
  DateTime? _createdAt;
  int? _selectedMood;
  double _stressLevel = 5;
  double _energyLevel = 5;

  @override
  void initState() {
    super.initState();
    _loadTodayCheckIn();
  }

  String _todayKey() {
    return DateUtils.dateOnly(DateTime.now()).toIso8601String().split('T').first;
  }

  int? _toInt(Object? value) {
    if (value == null) {
      return null;
    }

    return int.tryParse(value.toString());
  }

  double _toLevel(Object? value, double fallback) {
    final int? parsed = _toInt(value);
    return parsed?.toDouble() ?? fallback;
  }

  String _formatTime(DateTime value) {
    final DateTime local = value.toLocal();
    final String hours = local.hour.toString().padLeft(2, '0');
    final String minutes = local.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  Future<void> _loadTodayCheckIn() async {
    final User? currentUser = _client.auth.currentUser;

    if (currentUser == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Отметка за сегодня пока недоступна';
        _checkInId = null;
        _createdAt = null;
        _selectedMood = null;
        _stressLevel = 5;
        _energyLevel = 5;
      });
      return;
    }

    try {
      final Map<String, dynamic>? row = await _client
          .from('check_ins')
          .select('id, mood, stress, energy, created_at')
          .eq('user_id', currentUser.id)
          .eq('date', _todayKey())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (!mounted) {
        return;
      }

      if (row == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
          _checkInId = null;
          _createdAt = null;
          _selectedMood = null;
          _stressLevel = 5;
          _energyLevel = 5;
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _checkInId = row['id']?.toString();
        _createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal();
        _selectedMood = _toInt(row['mood']);
        _stressLevel = _toLevel(row['stress'], 5);
        _energyLevel = _toLevel(row['energy'], 5);
      });
    } catch (error) {
      debugPrint('CHECK-IN LOAD ERROR: $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Отметка за сегодня пока недоступна';
        _checkInId = null;
        _createdAt = null;
        _selectedMood = null;
        _stressLevel = 5;
        _energyLevel = 5;
      });
    }
  }

  Future<void> _saveCheckIn() async {
    final User? currentUser = _client.auth.currentUser;
    if (currentUser == null || _selectedMood == null || _isSaving) {
      return;
    }

    final bool hadExistingCheckIn = _checkInId != null;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final String today = _todayKey();
      final Map<String, dynamic> payload = <String, dynamic>{
        'user_id': currentUser.id,
        'date': today,
        'mood': _selectedMood,
        'stress': _stressLevel.round(),
        'energy': _energyLevel.round(),
      };

      final Map<String, dynamic> savedRow = await _client
          .from('check_ins')
          .upsert(
            payload,
            onConflict: 'user_id,date',
          )
          .select('id, mood, stress, energy, created_at')
          .single();

      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _checkInId = savedRow['id']?.toString();
        _selectedMood = _toInt(savedRow['mood']) ?? _selectedMood;
        _stressLevel = _toLevel(savedRow['stress'], _stressLevel);
        _energyLevel = _toLevel(savedRow['energy'], _energyLevel);
        _createdAt = DateTime.tryParse(savedRow['created_at']?.toString() ?? '')?.toLocal() ?? _createdAt;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(hadExistingCheckIn ? 'Check-in обновлён' : 'Check-in сохранён')),
      );
    } catch (error) {
      debugPrint('CHECK-IN SAVE ERROR: $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _errorMessage = 'Не получилось сохранить отметку';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не получилось сохранить отметку')),
      );
    }
  }

  Widget _buildErrorBanner(ThemeData theme, ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: colors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage ?? 'Отметка за сегодня пока недоступна',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: _isLoading ? null : _loadTodayCheckIn,
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodChip(
    _MoodOption option,
    ThemeData theme,
    ColorScheme colors,
  ) {
    final bool selected = _selectedMood == option.value;

    return ChoiceChip(
      label: Text('${option.emoji} ${option.label}'),
      selected: selected,
      onSelected: (_isLoading || _isSaving)
          ? null
          : (_) {
              setState(() {
                _selectedMood = option.value;
              });
            },
      selectedColor: colors.primary.withValues(alpha: 0.14),
      backgroundColor: colors.surface,
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: selected ? colors.primary : colors.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      side: BorderSide(
        color: selected ? colors.primary : theme.dividerColor,
      ),
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final String statusText = _checkInId == null
        ? 'Короткий check-in поможет отслеживать ваше состояние'
        : 'Сегодня уже есть check-in. Можно обновить его, если что-то изменилось.';

    final String buttonLabel = _checkInId == null ? 'Сохранить check-in' : 'Обновить check-in';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.favorite_rounded,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Как вы себя чувствуете сегодня?',
                      style: textTheme.titleLarge?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      statusText,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    if (_createdAt != null && _checkInId != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        'Сохранено сегодня в ${_formatTime(_createdAt!)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...<Widget>[
            if (_errorMessage != null) ...<Widget>[
              _buildErrorBanner(theme, colors),
              const SizedBox(height: 12),
            ],
            Text(
              'Настроение',
              style: textTheme.labelLarge?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _moodOptions
                  .map((_MoodOption option) => _buildMoodChip(option, theme, colors))
                  .toList(),
            ),
            const SizedBox(height: 18),
            Text(
              'Дополнительно',
              style: textTheme.labelLarge?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Стресс и энергия — необязательно.',
              style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            _CheckInSlider(
              label: 'Стресс',
              value: _stressLevel,
              description: 'Меньше — спокойнее, больше — напряжённее',
              onChanged: _isSaving
                  ? null
                  : (double value) {
                      setState(() {
                        _stressLevel = value;
                      });
                    },
            ),
            const SizedBox(height: 12),
            _CheckInSlider(
              label: 'Энергия',
              value: _energyLevel,
              description: 'Меньше — усталость, больше — бодрость',
              onChanged: _isSaving
                  ? null
                  : (double value) {
                      setState(() {
                        _energyLevel = value;
                      });
                    },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isSaving || _selectedMood == null) ? null : _saveCheckIn,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(buttonLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckInSlider extends StatelessWidget {
  const _CheckInSlider({
    required this.label,
    required this.value,
    required this.description,
    required this.onChanged,
  });

  final String label;
  final double value;
  final String description;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${value.round()}/10',
              style: textTheme.labelMedium?.copyWith(color: colors.onSurface),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: 10,
          divisions: 10,
          label: value.round().toString(),
          onChanged: onChanged,
        ),
        Text(
          description,
          style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _DailyPlanSection extends StatefulWidget {
  const _DailyPlanSection({
    required this.onOpenLegacyPlan,
    required this.onOpenKnowledgeBase,
  });

  final VoidCallback onOpenLegacyPlan;
  final VoidCallback onOpenKnowledgeBase;

  @override
  State<_DailyPlanSection> createState() => _DailyPlanSectionState();
}

class _DailyPlanSectionState extends State<_DailyPlanSection> with RouteAware {
  final SupabaseClient _client = Supabase.instance.client;
  PageRoute<dynamic>? _route;

  bool _isLoading = true;
  String? _errorMessage;
  String? _planId;
  String? _weekStartLabel;
  List<PlanItemData> _items = <PlanItemData>[];

  @override
  void initState() {
    super.initState();
    _loadPlan();
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
    if (_suppressNextPopReload) {
      debugPrint('PLAN LOAD POP SKIP: source=dashboard-plan-section reason=detail_return_handled_locally');
      return;
    }

    debugPrint('PLAN LOAD POP NEXT: source=dashboard-plan-section reload_requested=true');
    _loadPlan();
  }

  @override
  void dispose() {
    if (_route != null) {
      appRouteObserver.unsubscribe(this);
    }

    super.dispose();
  }

  bool _suppressNextPopReload = false;

  Future<void> _loadPlan() async {
    final User? currentUser = _client.auth.currentUser;
    debugPrint('PLAN LOAD START');

    if (currentUser == null) {
      debugPrint('PLAN LOAD ERROR: current user is null');
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'План появится после первых шагов';
        _planId = null;
        _weekStartLabel = null;
        _items = <PlanItemData>[];
      });
      return;
    }

    try {
      final Map<String, dynamic>? planRow = await loadOrCreateActivePlanRow(
        client: _client,
        userId: currentUser.id,
        sourceLabel: 'dashboard-plan-section',
      );

      if (planRow == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoading = false;
          _errorMessage = null;
          _planId = null;
          _weekStartLabel = null;
          _items = <PlanItemData>[];
        });
        return;
      }

      final String planId = planRow['id']?.toString() ?? '';
      final String weekStartLabel = _formatWeekStart(planRow['week_start']?.toString());

      final List<Map<String, dynamic>> rows = await loadActivePlanItemRows(
        client: _client,
        planId: planId,
        sourceLabel: 'dashboard-plan-section',
      );

      final List<PlanItemData> items = rows
          .map((Map<String, dynamic> rowData) => PlanItemData.fromMap(rowData))
          .toList()
        ..sort((PlanItemData left, PlanItemData right) {
          final DateTime? leftCreated = left.createdAt;
          final DateTime? rightCreated = right.createdAt;

          if (leftCreated == null && rightCreated == null) {
            return 0;
          }
          if (leftCreated == null) {
            return 1;
          }
          if (rightCreated == null) {
            return -1;
          }
          return leftCreated.compareTo(rightCreated);
        });

      if (items.isEmpty) {
        debugPrint('PLAN LOAD EMPTY: plan_id=$planId items=0');
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoading = false;
          _errorMessage = null;
          _planId = planId;
          _weekStartLabel = weekStartLabel;
          _items = <PlanItemData>[];
        });
        return;
      }

      debugPrint('PLAN LOAD SUCCESS: plan_id=$planId items=${items.length}');
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _planId = planId;
        _weekStartLabel = weekStartLabel;
        _items = items;
      });
    } catch (error) {
      debugPrint('PLAN LOAD ERROR: $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'План пока недоступен';
        _items = <PlanItemData>[];
        _planId = null;
        _weekStartLabel = null;
      });
    }
  }

  Future<void> _openItemDetails(PlanItemData item) async {
    _suppressNextPopReload = true;

    try {
      final bool? changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => PlanItemDetailsPage(item: item),
        ),
      );

      if (changed == true && mounted) {
        await _loadPlan();
      }
    } finally {
      _suppressNextPopReload = false;
    }
  }

  String _formatWeekStart(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '';
    }

    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return '';
    }

    final DateTime normalized = DateUtils.dateOnly(parsed);
    final String day = normalized.day.toString().padLeft(2, '0');
    final String month = normalized.month.toString().padLeft(2, '0');
    return '$day.$month.${normalized.year}';
  }

  Color _statusBackground(String status, ColorScheme colors) {
    switch (status) {
      case 'in_progress':
        return colors.secondary.withValues(alpha: 0.2);
      case 'done':
        return const Color(0xFF43A047).withValues(alpha: 0.16);
      default:
        return colors.primary.withValues(alpha: 0.18);
    }
  }

  Color _statusForeground(String status, ColorScheme colors) {
    switch (status) {
      case 'in_progress':
        return colors.secondary;
      case 'done':
        return const Color(0xFF43A047);
      default:
        return colors.primary;
    }
  }

  Widget _buildItemCard(PlanItemData item, ThemeData theme, ColorScheme colors) {
    final String normalizedStatus = item.normalizedStatus;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _openItemDetails(item),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    item.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _statusBackground(normalizedStatus, colors),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.statusLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: _statusForeground(normalizedStatus, colors),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colors) {
    final String message = _planId == null
        ? 'План появится после первых шагов'
        : 'Пока здесь тихо. Добавьте небольшой шаг, чтобы начать ритм.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.event_note_rounded,
            size: 36,
            color: colors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme, ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: colors.error,
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'План пока недоступен',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _loadPlan,
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'План на сегодня',
                    style: theme.textTheme.titleMedium?.copyWith(color: colors.onSurface),
                  ),
                  if (_weekStartLabel != null && _weekStartLabel!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      'Неделя от $_weekStartLabel',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              TextButton(
                onPressed: widget.onOpenLegacyPlan,
                child: Text(
                  'См. всё',
                  style: theme.textTheme.labelLarge?.copyWith(color: colors.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoading)
            _buildLoadingState(theme, colors)
          else if (_errorMessage != null)
            _buildErrorState(theme, colors)
          else if (_items.isEmpty)
            _buildEmptyState(theme, colors)
          else
            Column(
              children: _items
                  .map((PlanItemData item) => _buildItemCard(item, theme, colors))
                  .toList(),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: widget.onOpenKnowledgeBase,
            icon: const Icon(Icons.menu_book_rounded),
            label: const Text('Открыть базу знаний'),
          ),
        ],
      ),
    );
  }
}

class _CoachSupportData {
  const _CoachSupportData({
    required this.displayName,
    required this.avatarUrl,
  });

  final String displayName;
  final String avatarUrl;
}

class _CoachSupportSection extends StatefulWidget {
  const _CoachSupportSection({required this.onOpenChat});

  final VoidCallback onOpenChat;

  @override
  State<_CoachSupportSection> createState() => _CoachSupportSectionState();
}

class _CoachSupportSectionState extends State<_CoachSupportSection> {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;
  _CoachSupportData? _coach;

  @override
  void initState() {
    super.initState();
    _loadCoach();
  }

  String _readText(Map<String, dynamic> row, String key) {
    final dynamic raw = row[key];
    if (raw == null) {
      return '';
    }

    return raw.toString().trim();
  }

  String _displayName(Map<String, dynamic> row) {
    final String fullName = _readText(row, 'full_name');
    return fullName.isNotEmpty ? fullName : 'Без имени';
  }

  Future<void> _loadCoach() async {
    final User? currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Связь с тренером появится после подключения';
        _coach = null;
      });
      return;
    }

    debugPrint('COACH SUPPORT LOAD START: userId=${currentUser.id}');

    try {
      final Map<String, dynamic>? clientRow = await _client
          .from('clients')
          .select('coach_id, created_at')
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      debugPrint(
        'COACH SUPPORT RELATIONSHIP LOADED: userId=${currentUser.id} hasRow=${clientRow != null}',
      );

      final String coachId = clientRow?['coach_id']?.toString().trim() ?? '';
      if (coachId.isEmpty) {
        debugPrint('COACH SUPPORT RELATIONSHIP EMPTY: userId=${currentUser.id}');
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoading = false;
          _errorMessage = null;
          _coach = null;
        });
        return;
      }

      debugPrint('COACH SUPPORT COACH RESOLVED: userId=${currentUser.id} coachId=$coachId');

      final Map<String, dynamic>? coachRow = await _client
          .from('users')
          .select('id, full_name, avatar_url')
          .eq('id', coachId)
          .maybeSingle();

      debugPrint(
        'COACH SUPPORT PROFILE LOADED: coachId=$coachId hasRow=${coachRow != null}',
      );

      if (!mounted) {
        return;
      }

      if (coachRow == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
          _coach = null;
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = null;
        _coach = _CoachSupportData(
          displayName: _displayName(coachRow),
          avatarUrl: _readText(coachRow, 'avatar_url'),
        );
      });

      debugPrint(
        'COACH SUPPORT LOAD SUCCESS: userId=${currentUser.id} '
        'coachId=$coachId displayName=${_coach?.displayName}',
      );
    } catch (error) {
      if (error is PostgrestException) {
        debugPrint(
          'COACH SUPPORT LOAD ERROR: message=${error.message} details=${error.details} hint=${error.hint}',
        );
      } else {
        debugPrint('COACH SUPPORT LOAD ERROR: $error');
      }
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Не получилось показать связь с тренером';
        _coach = null;
      });
    }
  }

  Widget _buildAvatar(ThemeData theme, ColorScheme colors) {
    final _CoachSupportData? coach = _coach;
    return IdentityAvatar(
      displayName: coach?.displayName ?? 'Без имени',
      avatarUrl: coach?.avatarUrl ?? '',
      size: 50,
      backgroundColor: colors.secondary.withValues(alpha: 0.18),
      textColor: colors.secondary,
    );
  }

  Widget _buildCard(ThemeData theme, ColorScheme colors) {
    final TextTheme textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: <Widget>[
          _buildAvatar(theme, colors),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (_coach != null) ...<Widget>[
                  Text(
                    'Ваш тренер',
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _coach!.displayName,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'На связи с 9:00 до 21:00',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ] else if (_errorMessage != null) ...<Widget>[
                  Text(
                    'Тренер PsyBalance',
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _errorMessage!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ] else ...<Widget>[
                  Text(
                    'Тренер PsyBalance',
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Мы покажем здесь связь, когда она появится.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_coach != null)
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: widget.onOpenChat,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                      color: colors.onSurface,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Чат',
                      style: textTheme.labelMedium?.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_errorMessage != null)
            TextButton(
              onPressed: _loadCoach,
              child: const Text('Повторить'),
            ),
        ],
      ),
    );
  }

  Widget _buildLoading(ThemeData theme, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.secondary.withValues(alpha: 0.2)),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    if (_isLoading) {
      return _buildLoading(theme, colors);
    }

    return _buildCard(theme, colors);
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: <Widget>[
            Icon(icon, color: foregroundColor, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: textTheme.labelMedium?.copyWith(color: foregroundColor),
            ),
          ],
        ),
      ),
    );
  }
}
