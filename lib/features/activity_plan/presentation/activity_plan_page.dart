import 'package:flutter/material.dart';

class ActivityPlanPage extends StatefulWidget {
  const ActivityPlanPage({super.key, this.title = 'План активности'});

  final String title;

  @override
  State<ActivityPlanPage> createState() => _ActivityPlanPageState();
}

class _ActivityPlanPageState extends State<ActivityPlanPage> {
  final List<_PlanTask> _tasks = <_PlanTask>[
    const _PlanTask(
      title: 'Утренняя зарядка',
      subtitle: '15 минут, низкая интенсивность',
      done: true,
    ),
    const _PlanTask(
      title: 'Прогулка 8000 шагов',
      subtitle: 'Ежедневно, фиксация скриншотом',
      done: false,
    ),
    const _PlanTask(
      title: 'Медитация перед сном',
      subtitle: '10 минут в приложении',
      done: false,
    ),
  ];

  void _toggleTask(int index, bool done) {
    setState(() {
      _tasks[index] = _tasks[index].copyWith(done: done);
    });
  }

  void _savePlan() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('План обновлен')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Неделя 3: Формирование привычки',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ...List<Widget>.generate(_tasks.length, (int index) {
                final _PlanTask task = _tasks[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: index == _tasks.length - 1 ? 0 : 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                task.title,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(task.subtitle, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        Checkbox(
                          value: task.done,
                          onChanged: (bool? value) {
                            _toggleTask(index, value ?? false);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _tasks.add(
                      const _PlanTask(
                        title: 'Новая активность',
                        subtitle: 'Заполните детали',
                        done: false,
                      ),
                    );
                  });
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Добавить активность'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _savePlan,
                child: const Text('Сохранить изменения'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanTask {
  const _PlanTask({
    required this.title,
    required this.subtitle,
    required this.done,
  });

  final String title;
  final String subtitle;
  final bool done;

  _PlanTask copyWith({
    String? title,
    String? subtitle,
    bool? done,
  }) {
    return _PlanTask(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      done: done ?? this.done,
    );
  }
}

