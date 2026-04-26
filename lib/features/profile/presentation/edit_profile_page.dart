import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ignore_for_file: avoid_print

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({
    super.key,
    this.openAvatarPickerOnStart = false,
  });

  final bool openAvatarPickerOnStart;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const List<String> _goalOptions = <String>[
    'Снизить стресс',
    'Улучшить сон',
    'Повысить энергию',
    'Похудеть',
  ];

  static const List<String> _genderOptions = <String>[
    'Мужской',
    'Женский',
    'Другое',
  ];

  static const List<String> _activityOptions = <String>[
    'Низкая',
    'Средняя',
    'Высокая',
  ];

  final SupabaseClient _client = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _foodPreferencesController = TextEditingController();

  bool isLoading = false;
  String? _currentUserId;
  String? _currentAvatarUrl;
  bool _supportsAvatarUrlColumn = false;
  Uint8List? _selectedAvatarBytes;
  String? _selectedGender;
  String? _selectedGoal;
  String? _selectedActivityLevel;
  DateTime? _selectedBirthDate;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    if (widget.openAvatarPickerOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showAvatarSourceSheet();
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _foodPreferencesController.dispose();
    super.dispose();
  }

  bool get _canUseCamera {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _loadProfile() async {
    final User? currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      return;
    }

    print('PROFILE LOAD START');

    try {
      final Map<String, dynamic>? row = await _client
          .from('users')
          .select()
          .eq('id', currentUser.id)
          .maybeSingle();

      if (!mounted || row == null) {
        return;
      }

      setState(() {
        _currentUserId = currentUser.id;
        _nameController.text = row['full_name']?.toString() ?? row['name']?.toString() ?? '';
        _selectedBirthDate = _parseDateTime(row['birth_date']?.toString());
        _birthDateController.text = _selectedBirthDate == null ? '' : _formatDate(_selectedBirthDate!);
        _heightController.text = row['height_cm']?.toString() ?? '';
        _weightController.text = row['weight_kg']?.toString() ?? '';
        _foodPreferencesController.text = row['food_preferences']?.toString() ?? '';
        _supportsAvatarUrlColumn = row.containsKey('avatar_url');
        final String rowAvatarUrl = row['avatar_url']?.toString() ?? '';
        final String metadataAvatarUrl = currentUser.userMetadata?['avatar_url']?.toString() ?? '';
        _currentAvatarUrl = rowAvatarUrl.isNotEmpty ? rowAvatarUrl : metadataAvatarUrl;
        _selectedGoal = _normalizeValue(row['goal']?.toString(), _goalOptions);
        _selectedGender = _normalizeValue(row['gender']?.toString(), _genderOptions);
        _selectedActivityLevel = _normalizeValue(
          row['activity_level']?.toString(),
          _activityOptions,
        );
      });

      print('PROFILE LOAD SUCCESS');
    } catch (e) {
      print('PROFILE LOAD ERROR: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (isLoading) {
      return;
    }

    final User? currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      _showSnackBar('Ошибка сохранения');
      return;
    }

    final String fullName = _nameController.text.trim();
    final String heightInput = _heightController.text.trim();
    final String weightInput = _weightController.text.trim();

    if (fullName.isEmpty) {
      _showSnackBar('Укажите полное имя');
      return;
    }

    if (heightInput.isNotEmpty && _parseInt(heightInput) == null) {
      _showSnackBar('Укажите корректный рост');
      return;
    }

    if (weightInput.isNotEmpty && _parseInt(weightInput) == null) {
      _showSnackBar('Укажите корректный вес');
      return;
    }

    setState(() {
      isLoading = true;
    });

    print('PROFILE SAVE START');

    try {
      final String? userId = _currentUserId ?? _client.auth.currentUser?.id;
      if (userId == null) {
        _showSnackBar('Ошибка сохранения');
        return;
      }

      final Map<String, dynamic> payload = <String, dynamic>{
        'full_name': fullName,
        'gender': _selectedGender,
        'birth_date': _selectedBirthDate == null ? null : _formatDateForStorage(_selectedBirthDate!),
        'height_cm': _parseInt(heightInput),
        'weight_kg': _parseInt(weightInput),
        'goal': _selectedGoal,
        'activity_level': _selectedActivityLevel,
        'food_preferences': _foodPreferencesController.text.trim(),
      };

      await _client.from('users').update(payload).eq('id', userId);

      if (!mounted) {
        return;
      }

      print('PROFILE SAVE SUCCESS');
      _showSnackBar('Профиль сохранён');
      Navigator.of(context).pop(true);
    } catch (e) {
      print('PROFILE UPDATE ERROR: $e');
      if (mounted) {
        _showSnackBar('Ошибка сохранения');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  int? _parseInt(String value) {
    if (value.isEmpty) {
      return null;
    }

    return int.tryParse(value);
  }

  String _buildAvatarStoragePath(String userId) {
    return '$userId/avatar_${DateTime.now().microsecondsSinceEpoch}.jpg';
  }

  Widget _buildAvatarFallback(ColorScheme colors) {
    return Container(
      color: colors.primary.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: 52,
        color: colors.onSurface,
      ),
    );
  }

  Widget _buildAvatarPreview(ThemeData theme) {
    final ColorScheme colors = theme.colorScheme;
    final String? avatarUrl = _selectedAvatarBytes == null ? _currentAvatarUrl?.trim() : null;

    final Widget avatarContent = _selectedAvatarBytes != null
        ? Image.memory(
            _selectedAvatarBytes!,
            fit: BoxFit.cover,
          )
        : (avatarUrl != null && avatarUrl.isNotEmpty)
            ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (BuildContext context, Object _, StackTrace? __) {
                  return _buildAvatarFallback(colors);
                },
              )
            : _buildAvatarFallback(colors);

    return Center(
      child: GestureDetector(
        onTap: isLoading ? null : _showAvatarSourceSheet,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: <Widget>[
            Container(
              width: 120,
              height: 120,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surface,
                border: Border.all(color: colors.surface, width: 4),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(
                child: SizedBox.expand(
                  child: avatarContent,
                ),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.scaffoldBackgroundColor,
                  width: 2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.edit_rounded,
                size: 18,
                color: colors.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAvatarSourceSheet() async {
    if (isLoading) {
      return;
    }

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        final ColorScheme colors = theme.colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Изменить аватар',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (_canUseCamera)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.photo_camera_rounded,
                      color: colors.onSurface,
                    ),
                    title: const Text('Сделать фото'),
                    onTap: () {
                      Navigator.of(sheetContext).pop(ImageSource.camera);
                    },
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.photo_library_rounded,
                    color: colors.onSurface,
                  ),
                  title: const Text('Выбрать из галереи'),
                  onTap: () {
                    Navigator.of(sheetContext).pop(ImageSource.gallery);
                  },
                ),
                if (!_canUseCamera) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Камера недоступна в веб-версии.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );

    if (source != null) {
      await _pickAvatar(source);
    }
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedImage == null) {
        return;
      }

      final Uint8List bytes = await pickedImage.readAsBytes();
      if (bytes.isEmpty) {
        throw Exception('Selected image is empty');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedAvatarBytes = bytes;
      });

      final User? currentUser = _client.auth.currentUser;
      final String? userId = _currentUserId ?? currentUser?.id;
      if (userId == null) {
        _showSnackBar('Не удалось сохранить аватар');
        return;
      }

      final String avatarUrl = await _uploadAvatarImage(
        storagePath: _buildAvatarStoragePath(userId),
        imageBytes: bytes,
        mimeType: pickedImage.mimeType ?? 'image/jpeg',
      );

      await _persistAvatarUrl(userId, avatarUrl);

      if (!mounted) {
        return;
      }

      setState(() {
        _currentAvatarUrl = avatarUrl;
        _selectedAvatarBytes = null;
      });
    } catch (e) {
      print('AVATAR PICK ERROR: $e');
      if (mounted) {
        _showSnackBar('Не удалось выбрать аватар');
      }
    }
  }

  Future<String> _uploadAvatarImage({
    required String storagePath,
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    final storage = _client.storage.from('food_images');

    await storage.uploadBinary(
      storagePath,
      imageBytes,
      fileOptions: FileOptions(
        contentType: mimeType,
      ),
    );

    final String publicUrl = storage.getPublicUrl(storagePath);
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _persistAvatarUrl(String userId, String avatarUrl) async {
    if (_supportsAvatarUrlColumn) {
      try {
        await _client.from('users').update(<String, dynamic>{
          'avatar_url': avatarUrl,
        }).eq('id', userId);
        return;
      } catch (e) {
        print('PROFILE AVATAR DB ERROR: $e');
      }
    }

    try {
      await _client.auth.updateUser(
        UserAttributes(
          data: <String, dynamic>{
            'avatar_url': avatarUrl,
          },
        ),
      );
    } catch (e) {
      print('PROFILE AVATAR METADATA ERROR: $e');
    }
  }

  Future<void> _pickBirthDate() async {
    if (isLoading) {
      return;
    }

    final DateTime firstDate = DateUtils.dateOnly(DateTime(1900));
    final DateTime lastDate = DateUtils.dateOnly(DateTime.now());
    final DateTime initialDate = _selectedBirthDate == null
        ? lastDate
        : DateUtils.dateOnly(_selectedBirthDate!);
    final DateTime safeInitialDate = initialDate.isBefore(firstDate)
        ? firstDate
        : initialDate.isAfter(lastDate)
            ? lastDate
            : initialDate;

    final DateTime? picked = await showDatePicker(
      context: context,
      locale: const Locale('ru'),
      initialDate: safeInitialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedBirthDate = DateUtils.dateOnly(picked);
      _birthDateController.text = _formatDate(_selectedBirthDate!);
    });
  }

  DateTime? _parseDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }

    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return null;
    }

    return DateUtils.dateOnly(parsed);
  }

  String _formatDate(DateTime date) {
    final DateTime normalized = DateUtils.dateOnly(date);
    final String day = normalized.day.toString().padLeft(2, '0');
    final String month = normalized.month.toString().padLeft(2, '0');
    return '$day.$month.${normalized.year}';
  }

  String _formatDateForStorage(DateTime date) {
    return DateUtils.dateOnly(date).toIso8601String().split('T').first;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _normalizeValue(String? value, List<String> options) {
    if (value == null) {
      return null;
    }

    return options.contains(value) ? value : null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final ColorScheme colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать профиль'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildAvatarPreview(theme),
              const SizedBox(height: 24),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Полное имя',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey<String>('gender:${_selectedGender ?? 'none'}'),
                initialValue: _selectedGender,
                style: textTheme.bodyLarge?.copyWith(color: colors.onSurface),
                decoration: const InputDecoration(
                  labelText: 'Пол',
                ),
                items: _genderOptions
                    .map(
                      (String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: isLoading
                    ? null
                    : (String? value) {
                        setState(() {
                          _selectedGender = value;
                        });
                      },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _birthDateController,
                readOnly: true,
                onTap: _pickBirthDate,
                decoration: const InputDecoration(
                  labelText: 'Дата рождения',
                  hintText: 'Выберите дату',
                  suffixIcon: Icon(Icons.calendar_month_rounded),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Рост, см',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Вес, кг',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey<String>('goal:${_selectedGoal ?? 'none'}'),
                initialValue: _selectedGoal,
                style: textTheme.bodyLarge?.copyWith(color: colors.onSurface),
                decoration: const InputDecoration(
                  labelText: 'Цель',
                ),
                items: _goalOptions
                    .map(
                      (String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: isLoading ? null : (String? value) {
                  setState(() {
                    _selectedGoal = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey<String>('activity:${_selectedActivityLevel ?? 'none'}'),
                initialValue: _selectedActivityLevel,
                style: textTheme.bodyLarge?.copyWith(color: colors.onSurface),
                decoration: const InputDecoration(
                  labelText: 'Уровень активности',
                ),
                items: _activityOptions
                    .map(
                      (String value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
                onChanged: isLoading
                    ? null
                    : (String? value) {
                        setState(() {
                          _selectedActivityLevel = value;
                        });
                      },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _foodPreferencesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Пищевые предпочтения',
                  hintText: 'Аллергии / ограничения',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _saveProfile,
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Сохранить',
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
