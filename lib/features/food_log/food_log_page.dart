import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FoodLogPage extends StatefulWidget {
  const FoodLogPage({super.key});

  @override
  State<FoodLogPage> createState() => _FoodLogPageState();
}

class _FoodLogPageState extends State<FoodLogPage> {
  final TextEditingController _notesController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  SupabaseClient get _client => Supabase.instance.client;

  List<_FoodLogEntry> _foodLogs = <_FoodLogEntry>[];
  XFile? _selectedImageFile;
  Uint8List? _selectedImageBytes;
  String _selectedMealType = 'breakfast';
  bool _hasPhoto = false;
  bool _isLoadingLogs = false;
  bool _isUploading = false;

  static const List<String> _mealTypes = <String>[
    'breakfast',
    'lunch',
    'dinner',
    'snack',
  ];

  static const Map<String, String> _mealTypeLabels = <String, String>{
    'breakfast': 'Завтрак',
    'lunch': 'Обед',
    'dinner': 'Ужин',
    'snack': 'Перекус',
  };

  bool get _canUseCamera {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFoodLogs();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _log(String message) {
    // ignore: avoid_print
    print(message);
  }

  String _mealTypeLabel(String mealType) {
    return _mealTypeLabels[mealType] ?? mealType;
  }

  String _formatCreatedAt(DateTime createdAt) {
    final DateTime local = createdAt.toLocal();
    final DateTime now = DateTime.now();
    final String hours = local.hour.toString().padLeft(2, '0');
    final String minutes = local.minute.toString().padLeft(2, '0');

    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return 'Сегодня, $hours:$minutes';
    }

    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year}, $hours:$minutes';
  }

  String _buildFoodImageStoragePath(String userId) {
    return '$userId/${DateTime.now().microsecondsSinceEpoch}.jpg';
  }

  Future<User?> _resolveCurrentUser() async {
    Session? session = _client.auth.currentSession;
    User? currentUser = session?.user ?? _client.auth.currentUser;

    if (currentUser == null) {
      _log('FOOD AUTH REFRESH START');
      try {
        final AuthResponse response = await _client.auth.refreshSession();
        session = response.session ?? session;
        currentUser = session?.user ?? _client.auth.currentUser;
      } catch (error) {
        _log('FOOD AUTH REFRESH ERROR: $error');
      }
    }

    _log('FOOD AUTH SESSION EXISTS: ${session != null}');
    _log('FOOD AUTH USER ID: ${currentUser?.id ?? 'null'}');

    return currentUser;
  }

  Future<void> _loadFoodLogs() async {
    final User? currentUser = await _resolveCurrentUser();
    if (currentUser == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _foodLogs = <_FoodLogEntry>[];
        _isLoadingLogs = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingLogs = true;
      });
    }

    try {
      final List<dynamic> rows = await _client
          .from('food_logs')
          .select('user_id, image_url, meal_type, notes, created_at')
          .eq('user_id', currentUser.id)
          .order('created_at', ascending: false);

      final List<_FoodLogEntry> entries = rows.map((dynamic rowData) {
        final Map<String, dynamic> row = rowData as Map<String, dynamic>;
        return _FoodLogEntry(
          imageUrl: row['image_url']?.toString() ?? '',
          mealType: row['meal_type']?.toString() ?? 'breakfast',
          notes: row['notes']?.toString() ?? '',
          createdAt:
              DateTime.tryParse(row['created_at']?.toString() ?? '') ??
              DateTime.now(),
        );
      }).where((_FoodLogEntry entry) => entry.imageUrl.isNotEmpty).toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _foodLogs = entries;
      });
    } catch (error) {
      _log('FOOD LOG LOAD ERROR: $error');
      _showSnackBar('Не удалось загрузить записи');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLogs = false;
        });
      }
    }
  }

  Future<void> _showPhotoSourceSheet() async {
    if (_isUploading) {
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
                  'Добавить фото',
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
      await _pickImage(source);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      _log('FOOD IMAGE PICK START: source=${source.name}');

      final XFile? pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (pickedImage == null) {
        _log('FOOD IMAGE PICK CANCELLED');
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
        _selectedImageFile = pickedImage;
        _selectedImageBytes = bytes;
        _hasPhoto = true;
      });

      _log('FOOD IMAGE PICK SUCCESS: name=${pickedImage.name}, bytes=${bytes.length}');
    } catch (error) {
      _log('FOOD IMAGE PICK ERROR: $error');
      _showSnackBar('Не удалось выбрать фото');
    }
  }

  Future<String> _uploadFoodImage({
    required String userId,
    required String storagePath,
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    _log(
      'FOOD UPLOAD START: user_id=$userId, path=$storagePath, meal_type=$_selectedMealType',
    );

    final storage = _client.storage.from('food_images');
    try {
      _log('FOOD STORAGE UPLOAD CALL: userId=$userId, path=$storagePath');
      await storage.uploadBinary(
        storagePath,
        imageBytes,
        fileOptions: FileOptions(
          contentType: mimeType,
        ),
      );
    } catch (error) {
      _log('FOOD STORAGE UPLOAD ERROR: userId=$userId, path=$storagePath, error=$error');
      rethrow;
    }

    final String publicUrl = storage.getPublicUrl(storagePath);
    _log('FOOD UPLOAD SUCCESS: path=$storagePath, url=$publicUrl');
    return publicUrl;
  }

  Future<void> _saveFoodLog() async {
    final User? currentUser = await _resolveCurrentUser();
    if (currentUser == null) {
      _showSnackBar('Сначала войдите в аккаунт');
      return;
    }

    if (_selectedImageBytes == null || _selectedImageFile == null) {
      _showSnackBar('Сначала выберите фото');
      return;
    }

    if (_isUploading) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    final String userId = currentUser.id;
    final String notes = _notesController.text.trim();
    final String storagePath = _buildFoodImageStoragePath(userId);
    _log('FOOD UPLOAD PATH VALIDATION: $storagePath');

    try {
      _log('FOOD UPLOAD USER ID: $userId');
      _log('FOOD UPLOAD PATH: $storagePath');
      final String publicUrl = await _uploadFoodImage(
        userId: userId,
        storagePath: storagePath,
        imageBytes: _selectedImageBytes!,
        mimeType: _selectedImageFile?.mimeType ?? 'image/jpeg',
      );

      _log(
        'FOOD DB INSERT START: userId=$userId, path=$storagePath, notesLength=${notes.length}',
      );

      await _client.from('food_logs').insert(<String, dynamic>{
        'user_id': userId,
        'image_url': publicUrl,
        'meal_type': _selectedMealType,
        'notes': notes.isEmpty ? null : notes,
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedImageFile = null;
        _selectedImageBytes = null;
        _hasPhoto = false;
        _notesController.clear();
      });

      await _loadFoodLogs();

      if (!mounted) {
        return;
      }

      _showSnackBar('Фото сохранено');
    } catch (error) {
      _log('FOOD UPLOAD ERROR: userId=$userId, path=$storagePath, error=$error');
      if (mounted) {
        _showSnackBar('Не удалось сохранить фото');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
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
                    'Фотодневник еды',
                    style: textTheme.titleLarge?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                height: 240,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.dividerColor, width: 2),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (_hasPhoto && _selectedImageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.memory(
                          _selectedImageBytes!,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.photo_camera_rounded,
                            size: 38,
                            color: textTheme.bodyMedium?.color,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Нажмите, чтобы добавить фото',
                            style: textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ElevatedButton.icon(
                          onPressed: _isUploading ? null : _showPhotoSourceSheet,
                          icon: const Icon(Icons.add_a_photo_rounded),
                          label: const Text('Добавить фото'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _mealTypes.map((String mealType) {
                    final bool selected = mealType == _selectedMealType;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_mealTypeLabel(mealType)),
                        selected: selected,
                        onSelected: (bool value) {
                          if (!value || _isUploading) {
                            return;
                          }

                          setState(() {
                            _selectedMealType = mealType;
                          });
                        },
                        selectedColor: colors.primary,
                        backgroundColor: colors.surface,
                        labelStyle: textTheme.labelMedium?.copyWith(
                          color: selected ? colors.onPrimary : colors.onSurface,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Заметки',
                style: textTheme.titleMedium?.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'Опишите прием пищи и уровень сытости...',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isUploading ? null : _saveFoodLog,
                child: _isUploading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colors.onPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('Сохранение...'),
                        ],
                      )
                    : const Text('Сохранить'),
              ),
              const SizedBox(height: 18),
              Text(
                'Ваши записи',
                style: textTheme.titleMedium?.copyWith(color: colors.onSurface),
              ),
              const SizedBox(height: 8),
              if (_isLoadingLogs)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_foodLogs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Text(
                    'Пока нет записей. Добавьте первое фото.',
                    style: textTheme.bodyMedium,
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _foodLogs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final _FoodLogEntry entry = _foodLogs[index];
                    return _FoodEntryTile(
                      mealType: _mealTypeLabel(entry.mealType),
                      imageUrl: entry.imageUrl,
                      notes: entry.notes,
                      time: _formatCreatedAt(entry.createdAt),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodLogEntry {
  const _FoodLogEntry({
    required this.imageUrl,
    required this.mealType,
    required this.notes,
    required this.createdAt,
  });

  final String imageUrl;
  final String mealType;
  final String notes;
  final DateTime createdAt;
}

class _FoodEntryTile extends StatelessWidget {
  const _FoodEntryTile({
    required this.mealType,
    required this.imageUrl,
    required this.notes,
    required this.time,
  });

  final String mealType;
  final String imageUrl;
  final String notes;
  final String time;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 52,
              height: 52,
              color: colors.primary.withValues(alpha: 0.14),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Icon(
                    Icons.restaurant_rounded,
                    color: colors.primary,
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(mealType, style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                if (notes.isNotEmpty) ...<Widget>[
                  Text(
                    notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                ],
                Text(time, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
        ],
      ),
    );
  }
}
