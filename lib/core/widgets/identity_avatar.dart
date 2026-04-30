import 'package:flutter/material.dart';

class IdentityAvatar extends StatelessWidget {
  const IdentityAvatar({
    super.key,
    required this.displayName,
    required this.avatarUrl,
    required this.size,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0,
    this.textColor,
  });

  final String displayName;
  final String avatarUrl;
  final double size;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final Color? textColor;

  String _initials(String value) {
    final List<String> parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'БИ';
    }

    final StringBuffer buffer = StringBuffer();
    for (final String part in parts.take(2)) {
      final String trimmed = part.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      final int firstRune = trimmed.runes.first;
      buffer.write(String.fromCharCode(firstRune).toUpperCase());
    }

    final String initials = buffer.toString().trim();
    return initials.isEmpty ? 'БИ' : initials;
  }

  Widget _buildAvatarFace(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String initials = _initials(displayName.isEmpty ? 'Без имени' : displayName);

    final Widget fallback = Container(
      width: size,
      height: size,
      color: backgroundColor ?? const Color(0xFFE8E2D9),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: theme.textTheme.labelMedium?.copyWith(
          color: textColor ?? colors.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final String trimmedAvatarUrl = avatarUrl.trim();
    if (trimmedAvatarUrl.isEmpty) {
      return fallback;
    }

    return ClipOval(
      child: Image.network(
        trimmedAvatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget avatar = _buildAvatarFace(context);

    if (borderWidth <= 0 || borderColor == null) {
      return SizedBox(width: size, height: size, child: avatar);
    }

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor!, width: borderWidth),
      ),
      child: avatar,
    );
  }
}
