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

class _CheckInPageState extends State<CheckInPage> {
  final SupabaseClient _client = Supabase.instance.client;

  bool isLoading = false;
  double _stress = 5;
  double _energy = 5;
  double _sleep = 5;

  Future<void> _saveCheckIn() async {
    if (isLoading) {
      return;
    }

    final User? currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка сохранения')),
        );
      }
      return;
    }

    setState(() {
      isLoading = true;
    });

    debugPrint('CHECKIN SAVE START');

    bool saved = false;

    try {
      final int stress = _stress.round();
      final int energy = _energy.round();
      final int sleep = _sleep.round();

      if (stress < 1 || stress > 10 || energy < 1 || energy > 10 || sleep < 1 || sleep > 10) {
        throw const FormatException('Invalid slider values');
      }

      final String today = DateTime.now().toIso8601String().split('T').first;

      await _client.from('check_ins').insert(<String, dynamic>{
        'user_id': currentUser.id,
        'date': today,
        'stress': stress,
        'energy': energy,
        'sleep': sleep,
      });

      if (!mounted) {
        return;
      }

      debugPrint('CHECKIN SAVE SUCCESS');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Чекин сохранён')),
      );
      saved = true;
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('CHECKIN SAVE ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка сохранения')),
        );
      }
    } finally {
      if (mounted && !saved) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Чек-ин'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Как вы себя чувствуете сегодня?',
                style: textTheme.headlineSmall?.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: 20),
              _MetricCard(
                title: 'Стресс',
                value: _stress,
                description: '1 = спокойно, 10 = очень напряжённо',
                onChanged: isLoading
                    ? null
                    : (double value) {
                        setState(() {
                          _stress = value;
                        });
                      },
              ),
              const SizedBox(height: 16),
              _MetricCard(
                title: 'Энергия',
                value: _energy,
                description: '1 = нет сил, 10 = очень бодро',
                onChanged: isLoading
                    ? null
                    : (double value) {
                        setState(() {
                          _energy = value;
                        });
                      },
              ),
              const SizedBox(height: 16),
              _MetricCard(
                title: 'Сон',
                value: _sleep,
                description: '1 = очень плохо, 10 = отлично',
                onChanged: isLoading
                    ? null
                    : (double value) {
                        setState(() {
                          _sleep = value;
                        });
                      },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _saveCheckIn,
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.description,
    required this.onChanged,
  });

  final String title;
  final double value;
  final String description;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(color: colors.onSurface),
              ),
              Text(
                value.round().toString(),
                style: textTheme.titleMedium?.copyWith(color: colors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: textTheme.bodySmall),
          Slider(
            value: value,
            min: 1,
            max: 10,
            divisions: 9,
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
