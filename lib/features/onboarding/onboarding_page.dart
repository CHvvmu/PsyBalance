import 'package:flutter/material.dart';

import '../auth/auth_failure.dart';
import '../auth/auth_service.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    super.key,
    required this.authService,
    required this.onCompleted,
  });

  final AuthService authService;
  final VoidCallback onCompleted;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const List<_GoalOptionData> _goalOptions = <_GoalOptionData>[
    _GoalOptionData(
      title: 'Снижение веса',
      description: 'Хочу плавно и безвозвратно снизить вес через привычки.',
      icon: Icons.trending_down_rounded,
    ),
    _GoalOptionData(
      title: 'Энергия и тонус',
      description: 'Чувствовать себя бодрее и наладить отношения с едой.',
      icon: Icons.self_improvement_rounded,
    ),
    _GoalOptionData(
      title: 'Психологический комфорт',
      description: 'Перестать заедать стресс и найти баланс.',
      icon: Icons.psychology_rounded,
    ),
  ];

  static const List<_DifficultyOptionData> _difficultyOptions =
      <_DifficultyOptionData>[
    _DifficultyOptionData(label: 'Сон', icon: Icons.bed_rounded),
    _DifficultyOptionData(
      label: 'Стресс на работе',
      icon: Icons.work_outline_rounded,
    ),
    _DifficultyOptionData(
      label: 'Вечерние перекусы',
      icon: Icons.cookie_rounded,
    ),
    _DifficultyOptionData(
      label: 'Мало движения',
      icon: Icons.directions_walk_rounded,
    ),
    _DifficultyOptionData(label: 'Сладкое', icon: Icons.icecream_rounded),
  ];

  final TextEditingController _currentWeightController = TextEditingController();
  final TextEditingController _targetWeightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();

  int? _selectedGoalIndex;
  bool _isLoading = false;
  final Set<String> _selectedDifficulties = <String>{
    'Сон',
    'Вечерние перекусы',
  };

  @override
  void dispose() {
    _currentWeightController.dispose();
    _targetWeightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) {
      return;
    }

    if (!_canCompleteOnboarding) {
      _showError('Заполните все поля онбординга.');
      return;
    }

    final int selectedGoalIndex = _selectedGoalIndex!;

    final double? currentWeight = _parseWeight(_currentWeightController.text);
    if (currentWeight == null) {
      _showError('Введите корректный текущий вес');
      return;
    }

    final double? targetWeight = _parseWeight(_targetWeightController.text);
    if (targetWeight == null) {
      _showError('Введите корректный целевой вес');
      return;
    }

    final int? heightCm = _parseHeight(_heightController.text);
    if (heightCm == null) {
      _showError('Введите корректный рост');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.authService.completeOnboarding(
        goal: _goalOptions[selectedGoalIndex].title,
        currentWeightKg: currentWeight,
        targetWeightKg: targetWeight,
        heightCm: heightCm,
        difficulties: _selectedDifficulties.toList(),
      );

      widget.onCompleted();
    } on AuthFailure catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _skip() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final int fallbackGoalIndex = _selectedGoalIndex ?? 0;
      await widget.authService.completeOnboarding(
        goal: _goalOptions[fallbackGoalIndex].title,
      );
      widget.onCompleted();
    } on AuthFailure catch (e) {
      _showError(e.message);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  double? _parseWeight(String raw) {
    final String value = raw.trim().replaceAll(',', '.');
    if (value.isEmpty) {
      return null;
    }
    final double? parsed = double.tryParse(value);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  int? _parseHeight(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    final int? parsed = int.tryParse(value);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  bool get _canCompleteOnboarding {
    return _selectedGoalIndex != null &&
        _parseWeight(_currentWeightController.text) != null &&
        _parseWeight(_targetWeightController.text) != null &&
        _parseHeight(_heightController.text) != null &&
        _selectedDifficulties.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    const Color accent = Color(0xFFE8DCCB);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  IconButton(
                    onPressed: () {
                      final NavigatorState navigator = Navigator.of(context);
                      if (navigator.canPop()) {
                        navigator.pop();
                      }
                    },
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: colors.onSurface,
                      size: 24,
                    ),
                  ),
                  const _StepIndicator(current: 1, total: 3),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 28),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Давайте познакомимся',
                    style: textTheme.headlineMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Это поможет вашему тренеру составить идеальный план для устойчивого результата.',
                    style: textTheme.bodyLarge?.copyWith(color: textTheme.bodyMedium?.color),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Какая ваша главная цель?',
                    style: textTheme.titleLarge?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List<Widget>.generate(
                    _goalOptions.length,
                    (int index) => Padding(
                      padding: EdgeInsets.only(
                        bottom: index == _goalOptions.length - 1 ? 0 : 10,
                      ),
                      child: _GoalOptionTile(
                        data: _goalOptions[index],
                        selected: _selectedGoalIndex == index,
                        onTap: () {
                          setState(() {
                            _selectedGoalIndex = index;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Ваши параметры',
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _currentWeightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Текущий вес',
                              hintText: 'кг',
                              prefixIcon: Icon(Icons.scale_rounded),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _targetWeightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Целевой вес',
                              hintText: 'кг',
                              prefixIcon: Icon(Icons.flag_rounded),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _heightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Рост',
                        hintText: 'см',
                        prefixIcon: Icon(Icons.straight_rounded),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Что сейчас вызывает сложности?',
                    style: textTheme.titleMedium?.copyWith(color: colors.onSurface),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _difficultyOptions.map((option) {
                      final bool selected =
                          _selectedDifficulties.contains(option.label);
                      return FilterChip(
                        selected: selected,
                        onSelected: (bool value) {
                          setState(() {
                            if (value) {
                              _selectedDifficulties.add(option.label);
                            } else {
                              _selectedDifficulties.remove(option.label);
                            }
                          });
                        },
                        avatar: Icon(
                          option.icon,
                          size: 16,
                          color: selected ? colors.onPrimary : colors.onSurface,
                        ),
                        label: Text(option.label),
                        backgroundColor: colors.surface,
                        selectedColor: colors.primary,
                        checkmarkColor: colors.onPrimary,
                        labelStyle: textTheme.labelMedium?.copyWith(
                          color: selected ? colors.onPrimary : colors.onSurface,
                        ),
                        side: BorderSide(
                          color: selected ? colors.primary : theme.dividerColor,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading || !_canCompleteOnboarding ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Продолжить'),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _skip,
                  child: Text(
                    'Заполнить позже',
                    style: textTheme.labelLarge?.copyWith(
                      color: textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.info_outline_rounded,
                      color: colors.onSurface,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ваши данные защищены и будут видны только вашему тренеру.',
                        style: textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Row(
      children: List<Widget>.generate(total, (int index) {
        final bool active = (index + 1) == current;
        return Padding(
          padding: EdgeInsets.only(right: index == total - 1 ? 0 : 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: active ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? colors.primary : theme.dividerColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _GoalOptionTile extends StatelessWidget {
  const _GoalOptionTile({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _GoalOptionData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: 0.12)
              : colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? colors.primary : theme.dividerColor,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? colors.primary.withValues(alpha: 0.18)
                    : theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(data.icon, size: 20, color: colors.onSurface),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    data.title,
                    style: textTheme.labelLarge?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(data.description, style: textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalOptionData {
  const _GoalOptionData({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class _DifficultyOptionData {
  const _DifficultyOptionData({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

