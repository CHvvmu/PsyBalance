import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key});

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class DailyCheckInPage extends CheckInPage {
  const DailyCheckInPage({super.key});
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

class _CheckInPageState extends State<CheckInPage> {
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
        _errorMessage = 'Не удалось загрузить check-in';
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
        _errorMessage = 'Не удалось загрузить check-in';
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
      final Map<String, dynamic> payload = <String, dynamic>{
        'user_id': currentUser.id,
        'date': _todayKey(),
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

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      debugPrint('CHECK-IN SAVE ERROR: $error');
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
        _errorMessage = 'Не удалось сохранить check-in';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить check-in')),
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
              _errorMessage ?? 'Не удалось загрузить check-in',
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

  Widget _buildSliderCard(
    BuildContext context,
    String label,
    double value,
    String description,
    ValueChanged<double>? onChanged,
  ) {
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final String statusText = _checkInId == null
        ? 'Короткий check-in поможет отслеживать ваше состояние'
        : 'Сегодня уже есть check-in. Можно обновить его, если что-то изменилось.';

    final String buttonLabel = _checkInId == null ? 'Сохранить check-in' : 'Обновить check-in';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Чек-ин'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
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
                  _buildSliderCard(
                    context,
                    'Стресс',
                    _stressLevel,
                    'Меньше — спокойнее, больше — напряжённее',
                    _isSaving
                        ? null
                        : (double value) {
                            setState(() {
                              _stressLevel = value;
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  _buildSliderCard(
                    context,
                    'Энергия',
                    _energyLevel,
                    'Меньше — усталость, больше — бодрость',
                    _isSaving
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
          ),
        ),
      ),
    );
  }
}
