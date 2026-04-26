import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ignore_for_file: avoid_print

class AddClientPage extends StatefulWidget {
  const AddClientPage({super.key});

  @override
  State<AddClientPage> createState() => _AddClientPageState();
}

class _AddClientPageState extends State<AddClientPage> {
  final SupabaseClient _client = Supabase.instance.client;
  final TextEditingController _emailController = TextEditingController();

  bool isLoading = false;
  String? errorText;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (isLoading) {
      return;
    }

    final String email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        errorText = 'Введите email';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorText = null;
    });

    bool shouldClose = false;

    try {
      print('ADD CLIENT START: $email');

      final User? currentUser = _client.auth.currentUser;
      if (currentUser == null) {
        if (mounted) {
          setState(() {
            errorText = 'Не удалось определить текущего пользователя';
          });
        }
        return;
      }

      final Map<String, dynamic>? foundUser = await _client
          .from('users')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (foundUser == null) {
        if (mounted) {
          setState(() {
            errorText = 'Пользователь не найден';
          });
        }
        return;
      }

      final String userId = foundUser['id'].toString();
      print('USER FOUND: ${foundUser['id']}');

      final List<dynamic> existingClients = await _client
          .from('clients')
          .select()
          .eq('user_id', userId)
          .eq('coach_id', currentUser.id);

      if (existingClients.isNotEmpty) {
        if (mounted) {
          setState(() {
            errorText = 'Клиент уже добавлен';
          });
        }
        return;
      }

      await _client.from('clients').insert(<String, dynamic>{
        'user_id': userId,
        'coach_id': currentUser.id,
      });

      if (!mounted) {
        return;
      }

      print('CLIENT INSERT SUCCESS');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Клиент добавлен')),
      );
      shouldClose = true;
      Navigator.of(context).pop(true);
    } catch (e) {
      print('ADD CLIENT ERROR: $e');
      if (mounted) {
        setState(() {
          errorText = 'Не удалось добавить клиента';
        });
      }
    } finally {
      if (mounted && !shouldClose) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Добавить клиента'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (errorText != null) {
                    setState(() {
                      errorText = null;
                    });
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'example@mail.com',
                  errorText: errorText,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Добавить клиента',
                          style: textTheme.labelLarge,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
