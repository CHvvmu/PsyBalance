import 'package:flutter/material.dart';

class CoachChatPage extends StatefulWidget {
  const CoachChatPage({
    super.key,
    required this.peerName,
    required this.avatarUrl,
    this.onlineLabel = 'В сети',
  });

  final String peerName;
  final String avatarUrl;
  final String onlineLabel;

  @override
  State<CoachChatPage> createState() => _CoachChatPageState();
}

class _CoachChatPageState extends State<CoachChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final List<_ChatMessage> _messages = <_ChatMessage>[
    const _ChatMessage(
      text:
          'Доброе утро, Анна! Посмотрел ваш фотодневник за вчера. Отличный выбор белков на ужин.',
      time: '09:15',
      isSent: false,
    ),
    const _ChatMessage(
      text: 'Как ваше самочувствие сегодня? Удалось выспаться?',
      time: '09:16',
      isSent: false,
    ),
    const _ChatMessage(
      text:
          'Доброе утро! Да, легла пораньше, чувствую себя бодрее. Вот мой завтрак сегодня:',
      time: '09:45',
      isSent: true,
      imageUrl:
          'https://dimg.dreamflow.cloud/v1/image/healthy+breakfast+bowl+with+avocado+and+eggs',
    ),
    const _ChatMessage(
      text:
          'Завтрак выглядит сбалансированным. Добавьте чуть больше зелени, если есть возможность. Это поможет с чувством сытости до обеда.',
      time: '10:05',
      isSent: false,
    ),
    const _ChatMessage(
      text: 'Поняла, спасибо! Сейчас как раз иду в магазин, куплю шпинат.',
      time: '10:12',
      isSent: true,
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _insertQuickText(String text) {
    _messageController.text = text;
    _messageController.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageController.text.length),
    );
  }

  void _sendMessage() {
    final String text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    final TimeOfDay now = TimeOfDay.now();
    final String minutes = now.minute.toString().padLeft(2, '0');
    final String time = '${now.hour}:$minutes';

    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          time: time,
          isSent: true,
        ),
      );
      _messageController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendPhotoStub() {
    final TimeOfDay now = TimeOfDay.now();
    final String minutes = now.minute.toString().padLeft(2, '0');
    final String time = '${now.hour}:$minutes';

    setState(() {
      _messages.add(
        _ChatMessage(
          text: 'Отправила фото завтрака',
          time: time,
          isSent: true,
          imageUrl:
              'https://dimg.dreamflow.cloud/v1/image/healthy+breakfast+bowl+with+avocado+and+eggs',
        ),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
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
                  _HeaderAvatar(imageUrl: widget.avatarUrl, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.peerName,
                          style: textTheme.titleMedium?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: <Widget>[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(widget.onlineLabel, style: textTheme.labelSmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Видеозвонок будет доступен позже.'),
                        ),
                      );
                    },
                    icon: Icon(Icons.videocam_rounded, color: textTheme.bodyMedium?.color),
                  ),
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Информация о чате.')),
                      );
                    },
                    icon: Icon(
                      Icons.info_outline_rounded,
                      color: textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.all(24),
                children: <Widget>[
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Text('Сегодня', style: textTheme.labelSmall),
                    ),
                  ),
                  ..._messages.map((message) => _ChatBubble(message: message)),
                ],
              ),
            ),
            AnimatedContainer(
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: <Widget>[
                        _ActionChip(
                          label: 'Отправила фото',
                          icon: Icons.photo_camera_rounded,
                          onTap: _sendPhotoStub,
                        ),
                        const SizedBox(width: 8),
                        _ActionChip(
                          label: 'Есть вопрос',
                          icon: Icons.help_outline_rounded,
                          onTap: () => _insertQuickText('Есть вопрос по плану на сегодня.'),
                        ),
                        const SizedBox(width: 8),
                        _ActionChip(
                          label: 'Все сделала!',
                          icon: Icons.check_circle_outline_rounded,
                          onTap: () => _insertQuickText('Все сделала!'),
                        ),
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
                          onPressed: _sendPhotoStub,
                          icon: Icon(
                            Icons.add_rounded,
                            color: textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Написать сообщение...',
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
                          onPressed: _sendMessage,
                          icon: Icon(
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
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({required this.imageUrl, required this.size});

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
            alignment: Alignment.center,
            child: Icon(
              Icons.person_rounded,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
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

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final Color bubbleColor = message.isSent
        ? colors.primary.withValues(alpha: 0.14)
        : colors.surface;

    return Align(
      alignment: message.isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: message.isSent ? colors.primary.withValues(alpha: 0.22) : theme.dividerColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (message.imageUrl != null) ...<Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  message.imageUrl!,
                  width: 220,
                  height: 140,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 220,
                    height: 140,
                    color: theme.scaffoldBackgroundColor,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              message.text,
              style: textTheme.bodyMedium?.copyWith(color: colors.onSurface),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(message.time, style: textTheme.labelSmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.time,
    required this.isSent,
    this.imageUrl,
  });

  final String text;
  final String time;
  final bool isSent;
  final String? imageUrl;
}

