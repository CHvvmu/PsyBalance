import 'dart:async';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/widgets/identity_avatar.dart';
import '../coach_panel/presentation/coach_route_args.dart';

class CoachChatPage extends StatefulWidget {
  const CoachChatPage({
    super.key,
    required this.peerName,
    required this.avatarUrl,
    required this.peerUserId,
    required this.behaviorUserId,
    this.initialDraft = '',
    this.onlineLabel = 'В сети',
  });

  final String peerName;
  final String avatarUrl;
  final String peerUserId;
  final String behaviorUserId;
  final String initialDraft;
  final String onlineLabel;

  @override
  State<CoachChatPage> createState() => _CoachChatPageState();
}

class _CoachChatPageState extends State<CoachChatPage> {
  static const String _appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '0.1.0+1',
  );

  final SupabaseClient _client = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();
  late final TextEditingController _messageController;
  final ScrollController _scrollController = ScrollController();

  RealtimeChannel? _messagesChannel;
  Timer? _refreshDebounce;

  bool _isBootstrapping = true;
  bool _isBehaviorLoading = true;
  bool _isLoadingMessages = false;
  bool _isSendingMessage = false;
  bool _isMarkingRead = false;

  int _bootstrapToken = 0;
  bool _reloadRequestedWhileLoading = false;
  bool _reloadRequestedMarkReadAfterLoad = false;
  String? _pendingSendRequestKey;
  String? _pendingSendDraft;
  String? _pendingSendAttachmentName;
  XFile? _selectedAttachmentFile;
  Uint8List? _selectedAttachmentBytes;
  int _sendRequestSequence = 0;

  String? _currentUserId;
  String? _conversationId;
  String? _conversationError;

  String _behaviorStatus = '';
  int? _consistencyStreak;
  DateTime? _lastCheckInAt;

  _ConversationData? _conversation;
  List<_ChatMessageRecord> _messages = <_ChatMessageRecord>[];

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: widget.initialDraft);
    _messageController.addListener(_handleComposerChanged);
    unawaited(_bootstrap());
  }

  @override
  void didUpdateWidget(covariant CoachChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.peerUserId.trim() != widget.peerUserId.trim() ||
        oldWidget.behaviorUserId.trim() != widget.behaviorUserId.trim()) {
      unawaited(_bootstrap());
    }
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleComposerChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _refreshDebounce?.cancel();
    unawaited(_disposeRealtimeChannel());
    super.dispose();
  }

  void _handleComposerChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  int? _toInt(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.round();
    }

    final String text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }

    return int.tryParse(text);
  }

  DateTime? _parseDateTime(Object? value) {
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

  Map<String, dynamic>? _singleRowFromRpc(dynamic result) {
    if (result is Map<String, dynamic>) {
      return result;
    }

    if (result is List<dynamic> && result.isNotEmpty) {
      final Object? first = result.first;
      if (first is Map<String, dynamic>) {
        return first;
      }
      if (first is Map) {
        return first.map((Object? key, Object? value) {
          return MapEntry(key?.toString() ?? '', value);
        });
      }
    }

    return null;
  }

  String _formatTime(DateTime value) {
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _relativeDayLabel(DateTime value) {
    final DateTime today = DateUtils.dateOnly(DateTime.now());
    final DateTime day = DateUtils.dateOnly(value);
    final int days = today.difference(day).inDays;

    if (days <= 0) {
      return 'сегодня';
    }

    if (days == 1) {
      return 'вчера';
    }

    final int mod100 = days % 100;
    if (mod100 >= 11 && mod100 <= 14) {
      return '$days дней назад';
    }

    switch (days % 10) {
      case 1:
        return '$days день назад';
      case 2:
      case 3:
      case 4:
        return '$days дня назад';
      default:
        return '$days дней назад';
    }
  }

  Map<String, dynamic> _messageMetadata({required String trigger}) {
    return <String, dynamic>{
      'source_screen': 'chat_page',
      'platform': 'mobile',
      'session_type': 'coach_chat',
      'app_version': _appVersion,
      'trigger': trigger,
      'conversation_id': _conversationId,
      'peer_user_id': widget.peerUserId.trim(),
      'behavior_user_id': widget.behaviorUserId.trim(),
    };
  }

  String _messageTypeLabel(String messageType) {
    switch (messageType) {
      case 'system':
        return 'Система';
      case 'intervention':
        return 'Интервенция';
      case 'reflection_prompt':
        return 'Вопрос для рефлексии';
      case 'coach_note':
        return 'Заметка коуча';
      case 'checkin_followup':
        return 'Фоллоу-ап';
      default:
        return '';
    }
  }

  bool _isCurrentUserMessage(_ChatMessageRecord message) {
    return _currentUserId != null && message.senderId == _currentUserId;
  }

  String _recentReplyLabel() {
    final _ConversationData? conversation = _conversation;
    final String? currentUserId = _currentUserId;
    if (conversation == null || currentUserId == null) {
      return 'Контекст ответа появится после загрузки диалога';
    }

    final DateTime? lastMessageAt = conversation.lastMessageAt;
    final String? lastSenderId = conversation.lastMessageSenderId?.trim();
    if (lastMessageAt == null || lastSenderId == null || lastSenderId.isEmpty) {
      return 'Недавний отклик пока не виден';
    }

    final int hours = DateTime.now().difference(lastMessageAt).inHours;
    if (lastSenderId != currentUserId) {
      if (hours <= 1) {
        return 'Клиент недавно ответил';
      }

      if (hours < 24) {
        return 'Клиент ответил $hoursч назад';
      }

      return 'Последний ответ клиента был ${_relativeDayLabel(lastMessageAt)}';
    }

    if (hours <= 6) {
      return 'После последнего сообщения ответ еще ожидается';
    }

    if (hours < 24) {
      return 'После последнего сообщения клиент пока молчит';
    }

    return 'Давно нет нового ответа клиента';
  }

  List<_QuickSuggestion> _quickSuggestions() {
    final DateTime? lastCheckInAt = _lastCheckInAt;
    final int? streak = _consistencyStreak;
    final _ConversationData? conversation = _conversation;
    final String? currentUserId = _currentUserId;
    final bool clientWasLastSender =
        conversation != null && currentUserId != null && conversation.lastMessageSenderId?.trim() == widget.peerUserId.trim();
    final bool coachWasLastSender =
        conversation != null && currentUserId != null && conversation.lastMessageSenderId?.trim() == currentUserId;
    final bool longSilence = conversation?.lastMessageAt != null &&
        DateTime.now().difference(conversation!.lastMessageAt!).inHours >= 24;
    final bool recentCheckIn = lastCheckInAt != null && DateTime.now().difference(lastCheckInAt).inHours < 36;
    final bool stableRhythm = (streak ?? 0) >= 3;

    if (clientWasLastSender) {
      return const <_QuickSuggestion>[
        _QuickSuggestion(
          label: 'Поддержать отклик',
          icon: Icons.reply_rounded,
          text: 'Спасибо за ответ. Хочу коротко поддержать ваш текущий шаг и уточнить, что сейчас помогает больше всего.',
        ),
        _QuickSuggestion(
          label: 'Уточнить следующий шаг',
          icon: Icons.alt_route_rounded,
          text: 'Вижу ваш отклик. Какой следующий небольшой шаг сейчас выглядит для вас реалистично?',
        ),
        _QuickSuggestion(
          label: 'Углубить рефлексию',
          icon: Icons.help_outline_rounded,
          text: 'Что в этом опыте оказалось для вас самым заметным или неожиданным?',
        ),
      ];
    }

    if (coachWasLastSender && longSilence) {
      return const <_QuickSuggestion>[
        _QuickSuggestion(
          label: 'Мягко вернуть контакт',
          icon: Icons.chat_bubble_outline_rounded,
          text: 'Хочу бережно вернуться к нашему контакту. Как вы сейчас, без необходимости отвечать подробно?',
        ),
        _QuickSuggestion(
          label: 'Снизить порог шага',
          icon: Icons.playlist_add_check_rounded,
          text: 'Если сейчас тяжело держать ритм, можно выбрать совсем маленький шаг на сегодня. Что было бы самым посильным?',
        ),
        _QuickSuggestion(
          label: 'Проверить нагрузку',
          icon: Icons.support_agent_rounded,
          text: 'Похоже, сейчас могло стать тише. Это скорее про усталость, перегрузку или просто не до чата?',
        ),
      ];
    }

    if (recentCheckIn || stableRhythm) {
      return const <_QuickSuggestion>[
        _QuickSuggestion(
          label: 'Поддержать ритм',
          icon: Icons.favorite_border_rounded,
          text: 'Похоже, ритм сейчас держится. Что помогает вам сохранять это движение?',
        ),
        _QuickSuggestion(
          label: 'Закрепить шаг',
          icon: Icons.task_alt_rounded,
          text: 'Хочу помочь закрепить текущий ритм. Какой следующий маленький шаг вы готовы удержать?',
        ),
        _QuickSuggestion(
          label: 'Проверить состояние',
          icon: Icons.chat_bubble_outline_rounded,
          text: 'Как вы себя чувствуете на фоне текущего ритма — стало устойчивее или пока волнами?',
        ),
      ];
    }

    return const <_QuickSuggestion>[
      _QuickSuggestion(
        label: 'Мягкий чек-ин',
        icon: Icons.chat_bubble_outline_rounded,
        text: 'Как вы себя чувствуете после сегодняшнего шага?',
      ),
      _QuickSuggestion(
        label: 'Нужна поддержка',
        icon: Icons.support_agent_rounded,
        text: 'Нужна поддержка, хочу уточнить один момент.',
      ),
      _QuickSuggestion(
        label: 'Есть вопрос',
        icon: Icons.help_outline_rounded,
        text: 'Есть вопрос по сегодняшнему шагу.',
      ),
    ];
  }

  Future<void> _bootstrap() async {
    final int bootstrapToken = ++_bootstrapToken;
    _currentUserId = _client.auth.currentUser?.id;

    if (mounted) {
      setState(() {
        _isBootstrapping = true;
        _conversationError = null;
        _conversation = null;
        _conversationId = null;
        _messages = <_ChatMessageRecord>[];
        _isLoadingMessages = false;
        _reloadRequestedWhileLoading = false;
        _reloadRequestedMarkReadAfterLoad = false;
        _pendingSendRequestKey = null;
        _pendingSendDraft = null;
        _pendingSendAttachmentName = null;
        _selectedAttachmentFile = null;
        _selectedAttachmentBytes = null;
      });
    }

    await _disposeRealtimeChannel();

    final String peerUserId = widget.peerUserId.trim();
    final String behaviorUserId = widget.behaviorUserId.trim();

    if (_currentUserId == null) {
      if (!mounted || bootstrapToken != _bootstrapToken) {
        return;
      }

      setState(() {
        _isBootstrapping = false;
        _conversationError = 'Чат доступен после входа в систему';
      });
      return;
    }

    if (peerUserId.isEmpty) {
      if (!mounted || bootstrapToken != _bootstrapToken) {
        return;
      }

      setState(() {
        _isBootstrapping = true;
      });
      return;
    }

    try {
      await Future.wait(<Future<void>>[
        _loadBehaviorContext(behaviorUserId, bootstrapToken),
        _loadConversationAndMessages(peerUserId, bootstrapToken),
      ]);
    } catch (error) {
      debugPrint('CHAT BOOTSTRAP ERROR: peerUserId=$peerUserId error=$error');
      if (mounted && bootstrapToken == _bootstrapToken) {
        setState(() {
          _conversationError = 'Чат пока недоступен';
        });
      }
    } finally {
      if (mounted && bootstrapToken == _bootstrapToken) {
        setState(() {
          _isBootstrapping = false;
        });
      }
    }
  }

  Future<void> _loadBehaviorContext(String behaviorUserId, int bootstrapToken) async {
    if (behaviorUserId.isEmpty) {
      if (!mounted || bootstrapToken != _bootstrapToken) {
        return;
      }

      setState(() {
        _isBehaviorLoading = false;
        _behaviorStatus = '';
        _consistencyStreak = null;
        _lastCheckInAt = null;
      });
      return;
    }

    try {
      final Future<Map<String, dynamic>?> userFuture = _client
          .from('users')
          .select('progress_status, consistency_streak')
          .eq('id', behaviorUserId)
          .maybeSingle();

      final Future<Map<String, dynamic>?> checkInFuture = _client
          .from('check_ins')
          .select('date, created_at')
          .eq('user_id', behaviorUserId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final List<Object?> results = await Future.wait(<Future<Object?>>[
        userFuture,
        checkInFuture,
      ]);

      if (!mounted || bootstrapToken != _bootstrapToken) {
        return;
      }

      final Map<String, dynamic>? userRow = results[0] as Map<String, dynamic>?;
      final Map<String, dynamic>? checkInRow = results[1] as Map<String, dynamic>?;

      setState(() {
        _isBehaviorLoading = false;
        _behaviorStatus = userRow?['progress_status']?.toString() ?? '';
        _consistencyStreak = _toInt(userRow?['consistency_streak']);
        _lastCheckInAt = _parseDateTime(checkInRow?['created_at']) ?? _parseDateTime(checkInRow?['date']);
      });
    } catch (error) {
      debugPrint('CHAT BEHAVIOR CONTEXT LOAD ERROR: behaviorUserId=$behaviorUserId error=$error');
      if (!mounted || bootstrapToken != _bootstrapToken) {
        return;
      }

      setState(() {
        _isBehaviorLoading = false;
        _behaviorStatus = '';
        _consistencyStreak = null;
        _lastCheckInAt = null;
      });
    }
  }

  Future<_ConversationData> _resolveConversation(String peerUserId) async {
    final dynamic result = await _client.rpc(
      'get_or_create_direct_conversation',
      params: <String, dynamic>{'p_peer_user_id': peerUserId},
    );

    final Map<String, dynamic>? row = _singleRowFromRpc(result);
    if (row == null) {
      throw StateError('Conversation RPC returned no data');
    }

    return _ConversationData.fromMap(row);
  }

  Future<void> _loadConversationAndMessages(String peerUserId, int bootstrapToken) async {
    final _ConversationData conversation = await _resolveConversation(peerUserId);

    if (!mounted || bootstrapToken != _bootstrapToken) {
      return;
    }

    setState(() {
      _conversation = conversation;
      _conversationId = conversation.id;
      _conversationError = null;
    });

    await _loadMessages(conversation.id, bootstrapToken, markReadAfterLoad: true);
    await _subscribeToConversation(conversation.id, bootstrapToken);
  }

  Future<void> _loadMessages(
    String conversationId,
    int bootstrapToken, {
    required bool markReadAfterLoad,
  }) async {
    if (bootstrapToken != _bootstrapToken) {
      return;
    }

    if (_isLoadingMessages) {
      _reloadRequestedWhileLoading = true;
      _reloadRequestedMarkReadAfterLoad =
          _reloadRequestedMarkReadAfterLoad || markReadAfterLoad;
      return;
    }

    _isLoadingMessages = true;

    try {
      final List<dynamic> rows = await _client
          .from('messages')
          .select(
            'id, conversation_id, sender_id, receiver_id, sender_role, message_type, content, metadata, read_at, edited_at, deleted_at, image_url, created_at',
          )
          .eq('conversation_id', conversationId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: true);

      if (!mounted || bootstrapToken != _bootstrapToken) {
        return;
      }

      final List<_ChatMessageRecord> nextMessages = rows
          .map((dynamic row) => _ChatMessageRecord.fromMap(row as Map<String, dynamic>))
          .toList(growable: false);
      final bool hasUnreadIncoming = markReadAfterLoad && nextMessages.any((_ChatMessageRecord message) {
        return message.senderId != _currentUserId && message.readAt == null;
      });

      setState(() {
        _messages = nextMessages;
        _conversationError = null;
      });

      _scrollToBottom();

      if (hasUnreadIncoming) {
        unawaited(_markConversationMessagesRead());
      }
    } catch (error) {
      debugPrint('CHAT MESSAGES LOAD ERROR: conversationId=$conversationId error=$error');
      if (mounted && bootstrapToken == _bootstrapToken) {
        setState(() {
          _conversationError = 'Не удалось загрузить переписку';
        });
      }
    } finally {
      _isLoadingMessages = false;

      if (_reloadRequestedWhileLoading && mounted) {
        final bool shouldMarkReadAfterLoad =
            _reloadRequestedMarkReadAfterLoad || markReadAfterLoad;
        _reloadRequestedWhileLoading = false;
        _reloadRequestedMarkReadAfterLoad = false;
        _scheduleRefresh(markReadAfterLoad: shouldMarkReadAfterLoad);
      }
    }
  }

  Future<void> _subscribeToConversation(String conversationId, int bootstrapToken) async {
    await _disposeRealtimeChannel();

    if (!mounted || bootstrapToken != _bootstrapToken) {
      return;
    }

    final RealtimeChannel channel = _client.channel('chat-conversation-$conversationId');
    _messagesChannel = channel;
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (payload) {
        if (!mounted || bootstrapToken != _bootstrapToken || _conversationId != conversationId) {
          return;
        }

        debugPrint(
          'CHAT REALTIME EVENT: conversationId=$conversationId eventType=${payload.eventType}',
        );
        _scheduleRefresh(markReadAfterLoad: true);
      },
    );

    channel.subscribe((status, error) {
      if (error != null) {
        debugPrint('CHAT REALTIME SUBSCRIBE ERROR: conversationId=$conversationId error=$error');
      }

      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint('CHAT REALTIME SUBSCRIBED: conversationId=$conversationId');
        if (mounted && bootstrapToken == _bootstrapToken && _conversationId == conversationId) {
          _scheduleRefresh(markReadAfterLoad: true);
        }
      }
    });
  }

  Future<void> _disposeRealtimeChannel() async {
    final RealtimeChannel? channel = _messagesChannel;
    _messagesChannel = null;

    if (channel == null) {
      return;
    }

    try {
      await channel.unsubscribe();
    } catch (error) {
      debugPrint('CHAT REALTIME UNSUBSCRIBE ERROR: $error');
    }

    try {
      await _client.removeChannel(channel);
    } catch (error) {
      debugPrint('CHAT REALTIME REMOVE CHANNEL ERROR: $error');
    }
  }

  void _scheduleRefresh({required bool markReadAfterLoad}) {
    final String? conversationId = _conversationId;
    final int bootstrapToken = _bootstrapToken;
    if (conversationId == null || conversationId.isEmpty) {
      return;
    }

    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 120), () {
      // Ignore delayed refreshes that belong to a previous bootstrap.
      if (!mounted || bootstrapToken != _bootstrapToken) {
        return;
      }

      unawaited(_loadMessages(conversationId, bootstrapToken, markReadAfterLoad: markReadAfterLoad));
    });
  }

  Future<void> _markConversationMessagesRead() async {
    final String? conversationId = _conversationId;
    if (conversationId == null || conversationId.isEmpty || _isMarkingRead) {
      return;
    }

    _isMarkingRead = true;

    try {
      await _client.rpc(
        'mark_conversation_messages_read',
        params: <String, dynamic>{'p_conversation_id': conversationId},
      );
    } catch (error) {
      debugPrint('CHAT MARK READ ERROR: conversationId=$conversationId error=$error');
    } finally {
      _isMarkingRead = false;
    }
  }

  Future<void> _sendMessage() async {
    final String content = _messageController.text.trim();
    final String? conversationId = _conversationId;
    final XFile? selectedAttachmentFile = _selectedAttachmentFile;
    final Uint8List? selectedAttachmentBytes = _selectedAttachmentBytes;

    if ((content.isEmpty && selectedAttachmentBytes == null) ||
        conversationId == null ||
        conversationId.isEmpty ||
        _isSendingMessage) {
      return;
    }

    final String draft = _messageController.text;
    final String? attachmentName = selectedAttachmentFile?.name.trim().toLowerCase();
    final bool shouldReusePendingRequestKey =
        _pendingSendRequestKey != null &&
        _pendingSendDraft == content &&
        _pendingSendAttachmentName == attachmentName;
    final String requestKey = shouldReusePendingRequestKey
        ? _pendingSendRequestKey!
        : 'chat:$conversationId:${DateTime.now().microsecondsSinceEpoch}:${_sendRequestSequence++}';
    _pendingSendRequestKey = requestKey;
    _pendingSendDraft = content;
    _pendingSendAttachmentName = attachmentName;

    setState(() {
      _isSendingMessage = true;
    });

    _messageController.clear();

    try {
      String? imageUrl;
      if (selectedAttachmentFile != null && selectedAttachmentBytes != null) {
        imageUrl = await _uploadChatImage(
          conversationId: conversationId,
          requestKey: requestKey,
          attachmentFile: selectedAttachmentFile,
          attachmentBytes: selectedAttachmentBytes,
        );
      }

      final dynamic result = await _client.rpc(
        'send_chat_message',
        params: <String, dynamic>{
          'p_conversation_id': conversationId,
          'p_content': content,
          'p_message_type': 'text',
          'p_metadata': _messageMetadata(trigger: 'manual_message'),
          'p_request_key': requestKey,
          'p_image_url': imageUrl,
        },
      );

      final Map<String, dynamic>? row = _singleRowFromRpc(result);
      if (row != null) {
        _pendingSendRequestKey = null;
        _pendingSendDraft = null;
        _pendingSendAttachmentName = null;
        if (mounted) {
          setState(() {
            _selectedAttachmentFile = null;
            _selectedAttachmentBytes = null;
          });
        }
        _scheduleRefresh(markReadAfterLoad: false);
      } else {
        unawaited(_loadMessages(conversationId, _bootstrapToken, markReadAfterLoad: false));
      }
    } catch (error) {
      debugPrint('CHAT SEND ERROR: conversationId=$conversationId error=$error');
      if (mounted) {
        _messageController.text = draft;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: draft.length),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось отправить сообщение с изображением')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingMessage = false;
        });
      }
    }
  }

  void _insertQuickText(String text) {
    _messageController.text = text;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  void _showAttachmentPlaceholder() {
    unawaited(_pickAttachmentImage());
  }

  String _buildChatImageStoragePath({
    required String conversationId,
    required String requestKey,
    required String fileName,
  }) {
    final String normalizedName = fileName.trim().isEmpty ? 'image.jpg' : fileName.trim().toLowerCase();
    final String safeName = normalizedName.replaceAll(RegExp(r'[^a-z0-9._-]'), '_');
    final String safeRequestKey = requestKey.toLowerCase().replaceAll(RegExp(r'[^a-z0-9:_-]'), '_');
    return '$conversationId/$safeRequestKey/$safeName';
  }

  Future<void> _pickAttachmentImage() async {
    if (_isSendingMessage) {
      return;
    }

    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
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
        _selectedAttachmentFile = pickedImage;
        _selectedAttachmentBytes = bytes;
      });
    } catch (error) {
      debugPrint('CHAT ATTACHMENT PICK ERROR: error=$error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось выбрать изображение')),
        );
      }
    }
  }

  void _removeSelectedAttachment() {
    if (_selectedAttachmentFile == null && _selectedAttachmentBytes == null) {
      return;
    }

    setState(() {
      _selectedAttachmentFile = null;
      _selectedAttachmentBytes = null;
    });
  }

  Future<String> _uploadChatImage({
    required String conversationId,
    required String requestKey,
    required XFile attachmentFile,
    required Uint8List attachmentBytes,
  }) async {
    final String storagePath = _buildChatImageStoragePath(
      conversationId: conversationId,
      requestKey: requestKey,
      fileName: attachmentFile.name,
    );
    final storage = _client.storage.from('chat_images');
    final String? currentUserId = _client.auth.currentUser?.id;
    final bool hasSession = _client.auth.currentSession != null;
    final String mimeType = attachmentFile.mimeType ?? 'image/jpeg';

    debugPrint(
      'CHAT IMAGE UPLOAD START: bucket=chat_images conversationId=$conversationId '
      'userId=$currentUserId hasSession=$hasSession path=$storagePath '
      'fileName=${attachmentFile.name} mimeType=$mimeType bytes=${attachmentBytes.length}',
    );

    try {
      await storage.uploadBinary(
        storagePath,
        attachmentBytes,
        fileOptions: FileOptions(
          contentType: mimeType,
          upsert: true,
        ),
      );
    } catch (error) {
      debugPrint(
        'CHAT IMAGE UPLOAD ERROR: bucket=chat_images conversationId=$conversationId '
        'userId=$currentUserId hasSession=$hasSession path=$storagePath '
        'fileName=${attachmentFile.name} mimeType=$mimeType bytes=${attachmentBytes.length} '
        'errorType=${error.runtimeType} error=$error',
      );
      rethrow;
    }

    final String publicUrl = storage.getPublicUrl(storagePath);
    debugPrint(
      'CHAT IMAGE UPLOAD SUCCESS: bucket=chat_images conversationId=$conversationId '
      'userId=$currentUserId path=$storagePath url=$publicUrl',
    );
    return publicUrl;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildBehaviorChip({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorStrip(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final BehaviorStatusPalette statusPalette = behaviorStatusPaletteFor(_behaviorStatus);
    final String statusLabel = behaviorStatusLabel(_behaviorStatus);
    final String streakLabel = (_consistencyStreak ?? 0) > 0
        ? '${_consistencyStreak ?? 0}-дневная серия'
        : 'Серия появится после первых шагов';
    final String checkInLabel = _lastCheckInAt == null
        ? 'Чек-ин появится после первых шагов'
        : 'Чек-ин: ${_relativeDayLabel(_lastCheckInAt!)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          _buildBehaviorChip(
            icon: Icons.verified_rounded,
            label: statusLabel,
            backgroundColor: statusPalette.background,
            borderColor: statusPalette.border,
            textColor: statusPalette.foreground,
          ),
          _buildBehaviorChip(
            icon: Icons.local_fire_department_rounded,
            label: streakLabel,
            backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.18),
            borderColor: theme.dividerColor,
            textColor: colors.onSurfaceVariant,
          ),
          _buildBehaviorChip(
            icon: Icons.event_available_rounded,
            label: checkInLabel,
            backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.18),
            borderColor: theme.dividerColor,
            textColor: colors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final String peerName = widget.peerName.trim().isEmpty ? 'Без имени' : widget.peerName.trim();
    final String subtitle = _recentReplyLabel();

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: colors.onSurface,
            ),
          ),
          IdentityAvatar(
            displayName: peerName,
            avatarUrl: widget.avatarUrl,
            size: 44,
            backgroundColor: colors.secondary.withValues(alpha: 0.18),
            textColor: colors.onSurface,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  peerName,
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: theme.dividerColor),
            ),
            child: Text(widget.onlineLabel, style: textTheme.labelSmall),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final Uint8List? selectedAttachmentBytes = _selectedAttachmentBytes;
    final String? selectedAttachmentName = _selectedAttachmentFile?.name;
    final List<_QuickSuggestion> quickSuggestions = _quickSuggestions();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + bottomInset),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          if (selectedAttachmentBytes != null) ...<Widget>[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      selectedAttachmentBytes,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Изображение готово к отправке',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (selectedAttachmentName != null && selectedAttachmentName.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            selectedAttachmentName.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isSendingMessage ? null : _removeSelectedAttachment,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (int index = 0; index < quickSuggestions.length; index++) ...<Widget>[
                  _ActionChip(
                    label: quickSuggestions[index].label,
                    icon: quickSuggestions[index].icon,
                    onTap: () => _insertQuickText(quickSuggestions[index].text),
                  ),
                  if (index != quickSuggestions.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _isSendingMessage || _conversationId == null ? null : _showAttachmentPlaceholder,
                  icon: Icon(
                    selectedAttachmentBytes == null ? Icons.add_rounded : Icons.image_rounded,
                    color: selectedAttachmentBytes == null ? textTheme.bodyMedium?.color : colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  enabled: !_isSendingMessage && !_isBootstrapping && _conversationId != null,
                  decoration: InputDecoration(
                    hintText: _conversationId == null ? 'Открываем диалог...' : 'Написать сообщение...',
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: colors.primary),
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _isSendingMessage || _conversationId == null
                      ? null
                      : (_messageController.text.trim().isEmpty && selectedAttachmentBytes == null)
                          ? null
                          : _sendMessage,
                  icon: _isSendingMessage
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(colors.onPrimary),
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          size: 20,
                          color: colors.onPrimary,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, {required String label}) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            label,
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

  Widget _buildErrorState(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.chat_bubble_outline_rounded, size: 36, color: colors.primary),
          const SizedBox(height: 12),
          Text(
            _conversationError ?? 'Переписка временно недоступна',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => unawaited(_bootstrap()),
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.forum_outlined, size: 36, color: colors.primary),
          const SizedBox(height: 12),
          Text(
            'Пока сообщений нет. Начните с короткого шага и зафиксируйте его здесь.',
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

  Widget _buildConversationList(BuildContext context) {
    if (_conversationError != null) {
      return _buildErrorState(context);
    }

    if (_isBootstrapping || (_isLoadingMessages && _messages.isEmpty)) {
      return _buildLoadingState(
        context,
        label: 'Синхронизируем переписку и поведенческий контекст...',
      );
    }

    if (_conversationId == null) {
      return _buildLoadingState(
        context,
        label: 'Открываем диалог...',
      );
    }

    if (_messages.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      itemCount: _messages.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Text('Сегодня', style: Theme.of(context).textTheme.labelSmall),
            ),
          );
        }

        final _ChatMessageRecord message = _messages[index - 1];
        return _ChatMessageTile(
          message: message,
          isCurrentUser: _isCurrentUserMessage(message),
          timeLabel: _formatTime(message.createdAt),
          messageTypeLabel: _messageTypeLabel(message.messageType),
          outcomeLabel: _outcomeLabelFor(message),
        );
      },
    );
  }

  String? _outcomeLabelFor(_ChatMessageRecord message) {
    if (!_isCurrentUserMessage(message) || message.messageType == 'system' || message.messageType == 'text') {
      return null;
    }

    if (message.readAt != null) {
      return 'Клиент открыл это сообщение';
    }

    final int hoursSince = DateTime.now().difference(message.createdAt).inHours;
    if (hoursSince >= 18) {
      return 'После этого сообщения пока нет подтвержденного отклика';
    }

    if (hoursSince >= 6) {
      return 'Сообщение доставлено, ответ еще ожидается';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildHeader(context),
            if (!_isBehaviorLoading) _buildBehaviorStrip(context),
            Expanded(child: _buildConversationList(context)),
            _buildComposer(context),
          ],
        ),
      ),
    );
  }
}

class _ConversationData {
  const _ConversationData({
    required this.id,
    required this.clientId,
    required this.coachId,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageSenderId,
  });

  final String id;
  final String clientId;
  final String coachId;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? lastMessageSenderId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory _ConversationData.fromMap(Map<String, dynamic> row) {
    return _ConversationData(
      id: row['id']?.toString() ?? '',
      clientId: row['client_id']?.toString() ?? '',
      coachId: row['coach_id']?.toString() ?? '',
      lastMessageAt: DateTime.tryParse(row['last_message_at']?.toString() ?? ''),
      lastMessagePreview: row['last_message_preview']?.toString().trim(),
      lastMessageSenderId: row['last_message_sender_id']?.toString().trim(),
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
    );
  }
}

class _ChatMessageRecord {
  const _ChatMessageRecord({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.senderRole,
    required this.messageType,
    required this.content,
    required this.metadata,
    required this.createdAt,
    this.readAt,
    this.editedAt,
    this.deletedAt,
    this.imageUrl,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String senderRole;
  final String messageType;
  final String content;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String? imageUrl;

  factory _ChatMessageRecord.fromMap(Map<String, dynamic> row) {
    final String normalizedContent = row['content']?.toString().trim().isNotEmpty == true
        ? row['content'].toString().trim()
        : row['text']?.toString().trim() ?? '';
    final String? normalizedImageUrl = row['image_url']?.toString().trim().isNotEmpty == true
        ? row['image_url'].toString().trim()
        : null;

    return _ChatMessageRecord(
      id: row['id']?.toString() ?? '',
      conversationId: row['conversation_id']?.toString() ?? '',
      senderId: row['sender_id']?.toString() ?? '',
      receiverId: row['receiver_id']?.toString() ?? '',
      senderRole: row['sender_role']?.toString().trim().toLowerCase() ?? 'client',
      messageType: row['message_type']?.toString().trim().toLowerCase() ?? 'text',
      content: normalizedContent,
      metadata: row['metadata'] is Map ? Map<String, dynamic>.from(row['metadata'] as Map) : <String, dynamic>{},
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
      readAt: DateTime.tryParse(row['read_at']?.toString() ?? ''),
      editedAt: DateTime.tryParse(row['edited_at']?.toString() ?? ''),
      deletedAt: DateTime.tryParse(row['deleted_at']?.toString() ?? ''),
      imageUrl: normalizedImageUrl,
    );
  }
}

class _QuickSuggestion {
  const _QuickSuggestion({
    required this.label,
    required this.icon,
    required this.text,
  });

  final String label;
  final IconData icon;
  final String text;
}

class _ChatMessageTile extends StatelessWidget {
  const _ChatMessageTile({
    required this.message,
    required this.isCurrentUser,
    required this.timeLabel,
    required this.messageTypeLabel,
    this.outcomeLabel,
  });

  final _ChatMessageRecord message;
  final bool isCurrentUser;
  final String timeLabel;
  final String messageTypeLabel;
  final String? outcomeLabel;

  _MessagePalette _palette(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    switch (message.messageType) {
      case 'system':
        return _MessagePalette(
          background: colors.surfaceContainerHighest.withValues(alpha: 0.7),
          border: theme.dividerColor,
          foreground: colors.onSurfaceVariant,
          labelBackground: colors.surfaceContainerHighest,
          labelForeground: colors.onSurfaceVariant,
        );
      case 'intervention':
        return _MessagePalette(
          background: colors.secondaryContainer,
          border: colors.secondary.withValues(alpha: 0.18),
          foreground: colors.onSecondaryContainer,
          labelBackground: colors.secondary.withValues(alpha: 0.12),
          labelForeground: colors.secondary,
        );
      case 'reflection_prompt':
        return _MessagePalette(
          background: colors.tertiaryContainer,
          border: colors.tertiary.withValues(alpha: 0.18),
          foreground: colors.onTertiaryContainer,
          labelBackground: colors.tertiary.withValues(alpha: 0.12),
          labelForeground: colors.tertiary,
        );
      case 'coach_note':
        return _MessagePalette(
          background: colors.primaryContainer,
          border: colors.primary.withValues(alpha: 0.18),
          foreground: colors.onPrimaryContainer,
          labelBackground: colors.primary.withValues(alpha: 0.12),
          labelForeground: colors.primary,
        );
      case 'checkin_followup':
        return _MessagePalette(
          background: colors.secondaryContainer.withValues(alpha: 0.86),
          border: colors.secondary.withValues(alpha: 0.18),
          foreground: colors.onSecondaryContainer,
          labelBackground: colors.secondary.withValues(alpha: 0.12),
          labelForeground: colors.secondary,
        );
      default:
        if (isCurrentUser) {
          return _MessagePalette(
            background: colors.primary.withValues(alpha: 0.14),
            border: colors.primary.withValues(alpha: 0.22),
            foreground: colors.onSurface,
            labelBackground: colors.primary.withValues(alpha: 0.12),
            labelForeground: colors.primary,
          );
        }

        return _MessagePalette(
          background: colors.surface,
          border: theme.dividerColor,
          foreground: colors.onSurface,
          labelBackground: colors.surfaceContainerHighest.withValues(alpha: 0.18),
          labelForeground: colors.onSurfaceVariant,
        );
    }
  }

  Widget _buildImage(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    final String? imageUrl = message.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl,
        width: 220,
        height: 140,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 220,
          height: 140,
          color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
          alignment: Alignment.center,
          child: Icon(Icons.image_not_supported_outlined, color: colors.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, _MessagePalette palette) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final bool hasImage = message.imageUrl != null && message.imageUrl!.trim().isNotEmpty;
    final bool hasText = message.content.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (messageTypeLabel.isNotEmpty && message.messageType != 'text' && message.messageType != 'system') ...<Widget>[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: palette.labelBackground,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              messageTypeLabel,
              style: textTheme.labelSmall?.copyWith(
                color: palette.labelForeground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        if (message.messageType == 'system') ...<Widget>[
          Text(
            message.content,
            style: textTheme.bodyMedium?.copyWith(color: palette.foreground),
            textAlign: TextAlign.center,
          ),
        ] else ...<Widget>[
          if (hasImage) ...<Widget>[
            _buildImage(context),
            if (hasText) const SizedBox(height: 8),
          ],
          if (hasText)
            Text(
              message.content,
              style: textTheme.bodyMedium?.copyWith(color: palette.foreground),
            ),
        ],
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              timeLabel,
              style: textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            if (isCurrentUser && message.messageType != 'system') ...<Widget>[
              const SizedBox(width: 8),
              Text(
                message.readAt == null ? 'Доставлено' : 'Прочитано',
                style: textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
            if (message.editedAt != null) ...<Widget>[
              const SizedBox(width: 8),
              Text(
                'изменено',
                style: textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
        if (outcomeLabel != null && outcomeLabel!.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: palette.labelBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              outcomeLabel!,
              style: textTheme.labelSmall?.copyWith(
                color: palette.labelForeground,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final _MessagePalette palette = _palette(context);

    if (message.messageType == 'system') {
      return Align(
        alignment: Alignment.center,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.border),
          ),
          child: _buildContent(context, palette),
        ),
      );
    }

    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.border),
        ),
        child: _buildContent(context, palette),
      ),
    );
  }
}

class _MessagePalette {
  const _MessagePalette({
    required this.background,
    required this.border,
    required this.foreground,
    required this.labelBackground,
    required this.labelForeground,
  });

  final Color background;
  final Color border;
  final Color foreground;
  final Color labelBackground;
  final Color labelForeground;
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 16, color: colors.onSurface),
      label: Text(label),
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: theme.dividerColor),
      ),
    );
  }
}
