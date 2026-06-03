part of '../../main.dart';

String compactMessage(String text, {int max = 80}) {
  final value = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (value.length <= max) {
    return value;
  }
  return '${value.substring(0, max - 3)}...';
}

double chatBubbleMaxWidth(BuildContext context, {bool showAvatar = false}) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final reservedWidth = showAvatar ? 64.0 : 24.0;
  final available = math.max(180.0, screenWidth - reservedWidth);
  return math.min(360.0, math.max(176.0, available * 0.72));
}

Color cupertinoChatBubbleDefaultColor(
  BuildContext context, {
  required bool mine,
}) {
  final colors = CsacColors.of(context);
  return mine
      ? CupertinoTheme.of(context).primaryColor
      : colors.tertiaryBackground;
}

Color cupertinoChatBubbleTextColor(BuildContext context, Color bubbleColor) {
  final solidColor = Color.alphaBlend(
    bubbleColor,
    CsacColors.of(context).systemBackground,
  );
  return CsacThemeData.estimateBrightnessForColor(solidColor) == Brightness.dark
      ? CupertinoColors.white
      : CupertinoColors.black;
}

String chatMessagePlainText(ChatMessage message, CsacStrings strings) {
  if (message.isRecalled) {
    return strings.text('[recalled]');
  }
  if (message.emojiAddress.isNotEmpty || message.messageType == 5) {
    final name = message.emojiAbbr.trim();
    return name.isEmpty
        ? strings.text('[emoji]')
        : strings.format('[emoji] {abbr}', {'abbr': name});
  }
  if (message.imageUrl.isNotEmpty && message.body.startsWith('[image]')) {
    return strings.text('[image]');
  }
  if (message.voiceUrl.isNotEmpty && message.body.startsWith('[voice]')) {
    return strings.text('[voice]');
  }
  if (message.fileUrl.isNotEmpty && message.body.startsWith('[file]')) {
    return strings.text('[file]');
  }
  return message.body;
}

String notificationTextForMessage(ChatMessage message, CsacStrings strings) {
  final text = chatMessagePlainText(message, strings).trim();
  if (text.isEmpty) {
    return strings.text('New message');
  }
  return compactMessage(text, max: 120);
}

String notificationTitleForConversation(
  Conversation conversation,
  ChatMessage? message,
) {
  if (conversation.type == ConversationType.group) {
    return conversation.name.trim().isEmpty ? 'CsAC' : conversation.name;
  }
  final sender = message?.sender.trim() ?? '';
  if (sender.isNotEmpty && !sender.startsWith('UID 0')) {
    return sender;
  }
  return conversation.name.trim().isEmpty ? 'CsAC' : conversation.name;
}

String notificationBodyForConversation(
  Conversation conversation,
  int newCount,
  ChatMessage? message,
  CsacStrings strings,
) {
  if (message != null) {
    final text = notificationTextForMessage(message, strings);
    if (conversation.type == ConversationType.group) {
      final sender = message.sender.trim();
      return sender.isEmpty || sender.startsWith('UID 0')
          ? text
          : '$sender: $text';
    }
    return text;
  }
  final subtitle = conversation.lastMessagePreview.trim().isNotEmpty
      ? conversation.lastMessagePreview.trim()
      : conversation.subtitle.trim();
  if (subtitle.isNotEmpty) {
    return compactMessage(subtitle, max: 120);
  }
  return strings.format('New messages: {count}', {'count': newCount});
}

ChatMessage? latestIncomingNotificationMessage(
  Conversation conversation,
  List<ChatMessage> messages, {
  required int currentUserId,
}) {
  final incoming = messages.where((message) {
    if (message.id <= 0) {
      return false;
    }
    if (currentUserId > 0 && message.senderId == currentUserId) {
      return false;
    }
    return conversation.type == ConversationType.group ||
        message.senderId == conversation.id ||
        message.senderId != 0;
  }).toList();
  if (incoming.isEmpty) {
    return null;
  }
  incoming.sort((a, b) => a.id.compareTo(b.id));
  return incoming.last;
}

int latestIncomingNotificationMessageId(
  Conversation conversation,
  List<ChatMessage> messages, {
  required int currentUserId,
}) {
  return latestIncomingNotificationMessage(
        conversation,
        messages,
        currentUserId: currentUserId,
      )?.id ??
      0;
}

CsacTimestampPattern timestampPatternForPreference(MessageTimeFormat format) {
  switch (format) {
    case MessageTimeFormat.slash:
      return CsacTimestampPattern.slash;
    case MessageTimeFormat.dash:
      return CsacTimestampPattern.dash;
    case MessageTimeFormat.compact:
      return CsacTimestampPattern.compact;
    case MessageTimeFormat.timeOnly:
      return CsacTimestampPattern.timeOnly;
  }
}

String displayMessageTime(ChatMessage message, CsacPreferences preferences) {
  return formatCsacTimestamp(
    message.timeSortValue > 0 ? message.timeSortValue : message.time,
    pattern: timestampPatternForPreference(preferences.messageTimeFormat),
  );
}

String messageTimeFormatLabelFor(
  BuildContext context,
  MessageTimeFormat format,
) {
  switch (format) {
    case MessageTimeFormat.slash:
      return context.strings.text('yyyy/mm/dd hh:mm:ss');
    case MessageTimeFormat.dash:
      return context.strings.text('yyyy-mm-dd hh:mm:ss');
    case MessageTimeFormat.compact:
      return context.strings.text('mm/dd hh:mm');
    case MessageTimeFormat.timeOnly:
      return context.strings.text('hh:mm:ss');
  }
}

String messageTimeFormatExampleFor(MessageTimeFormat format) {
  final sample = DateTime(2026, 5, 28, 21, 30, 15);
  switch (format) {
    case MessageTimeFormat.slash:
      return formatLocalDateTime(sample, separator: '/');
    case MessageTimeFormat.dash:
      return formatLocalDateTime(sample, separator: '-');
    case MessageTimeFormat.compact:
      return formatCompactLocalDateTime(sample);
    case MessageTimeFormat.timeOnly:
      return formatLocalTime(sample);
  }
}

String chatBubbleCornerStyleLabelFor(
  BuildContext context,
  ChatBubbleCornerStyle style,
) {
  switch (style) {
    case ChatBubbleCornerStyle.telegram:
      return context.strings.text('Telegram style');
    case ChatBubbleCornerStyle.ios:
      return context.strings.text('iOS style');
    case ChatBubbleCornerStyle.qq:
      return context.strings.text('QQ style');
  }
}

String fontStyleLabelFor(BuildContext context, CsacFontStyle style) {
  final strings = context.strings;
  switch (style) {
    case CsacFontStyle.system:
      return strings.text('Default system');
    case CsacFontStyle.serif:
      return strings.text('Serif');
    case CsacFontStyle.rounded:
      return strings.text('Rounded');
    case CsacFontStyle.monospace:
      return strings.text('Monospace');
  }
}

String fontStyleDescriptionFor(BuildContext context, CsacFontStyle style) {
  final strings = context.strings;
  switch (style) {
    case CsacFontStyle.system:
      return strings.text('Use the platform default font');
    case CsacFontStyle.serif:
      return strings.text('More book-like text');
    case CsacFontStyle.rounded:
      return strings.text('Softer iOS-style rounded text');
    case CsacFontStyle.monospace:
      return strings.text('Fixed-width terminal-like text');
  }
}

class CsacColors {
  const CsacColors._(this.brightness, this.primaryColor);

  factory CsacColors.of(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    return CsacColors._(
      theme.brightness ?? Brightness.light,
      theme.primaryColor,
    );
  }

  final Brightness brightness;
  final Color primaryColor;

  bool get isDark => brightness == Brightness.dark;
  Color get systemBackground =>
      isDark ? CupertinoColors.black : const Color(0xFFF2F2F7);
  Color get cardBackground =>
      isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white;
  Color get elevatedBackground =>
      isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF9F9FB);
  Color get tertiaryBackground =>
      isDark ? const Color(0xFF3A3A3C) : const Color(0xFFEFEFF4);
  Color get label => isDark ? CupertinoColors.white : CupertinoColors.black;
  Color get secondaryLabel =>
      isDark ? const Color(0x99EBEBF5) : const Color(0x993C3C43);
  Color get tertiaryLabel =>
      isDark ? const Color(0x4DEBEBF5) : const Color(0x4C3C3C43);
  Color get separator =>
      isDark ? const Color(0x5C545458) : const Color(0x4A3C3C43);
  Color get fill => isDark ? const Color(0x5C787880) : const Color(0x33787880);
  Color get tertiaryFill =>
      isDark ? const Color(0x3D787880) : const Color(0x1F787880);
  Color get destructive => CupertinoColors.systemRed;
  Color get navBarBackground =>
      isDark ? const Color(0xCC1C1C1E) : const Color(0xCCF9F9F9);
}

class Colors {
  const Colors._();

  static const transparent = Color(0x00000000);
  static const white = CupertinoColors.white;
  static const black = CupertinoColors.black;
  static const black12 = Color(0x1F000000);
  static const black26 = Color(0x42000000);
  static const black38 = Color(0x61000000);
  static const black45 = Color(0x73000000);
  static const black54 = Color(0x8A000000);
  static const black87 = Color(0xDD000000);
  static const white10 = Color(0x1AFFFFFF);
  static const white12 = Color(0x1FFFFFFF);
  static const white24 = Color(0x3DFFFFFF);
  static const white30 = Color(0x4DFFFFFF);
  static const white54 = Color(0x8AFFFFFF);
  static const white60 = Color(0x99FFFFFF);
  static const white70 = Color(0xB3FFFFFF);
  static const blue = CupertinoColors.systemBlue;
  static const green = CupertinoColors.systemGreen;
  static const orange = CupertinoColors.systemOrange;
  static const red = CupertinoColors.systemRed;
  static const grey = CupertinoColors.systemGrey;
  static const grey700 = Color(0xFF48484A);
  static const redAccent = Color(0xFFFF453A);
}

class CsacTheme {
  const CsacTheme({required this.colorScheme, required this.textTheme});

  factory CsacTheme.of(BuildContext context) {
    final colors = CsacColors.of(context);
    return CsacTheme(
      colorScheme: CsacColorScheme.from(colors),
      textTheme: CsacTextTheme.from(context, colors),
    );
  }

  final CsacColorScheme colorScheme;
  final CsacTextTheme textTheme;
}

class Theme {
  const Theme._();

  static CsacTheme of(BuildContext context) => CsacTheme.of(context);
}

class CsacThemeData {
  const CsacThemeData._();

  static Brightness estimateBrightnessForColor(Color color) {
    final relativeLuminance = color.computeLuminance();
    return ((relativeLuminance + 0.05) * (relativeLuminance + 0.05) > 0.15)
        ? Brightness.light
        : Brightness.dark;
  }
}

typedef ThemeData = CsacThemeData;

class CsacColorScheme {
  const CsacColorScheme({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.surface,
    required this.onSurface,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerLow,
    required this.surfaceContainerHighest,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.inversePrimary,
    required this.surfaceTint,
    required this.scrim,
    required this.shadow,
  });

  factory CsacColorScheme.from(CsacColors colors) {
    final primary = colors.primaryColor;
    return CsacColorScheme(
      primary: primary,
      onPrimary: CupertinoColors.white,
      primaryContainer: primary.withValues(alpha: colors.isDark ? 0.26 : 0.14),
      onPrimaryContainer: primary,
      secondary: CupertinoColors.systemIndigo,
      onSecondary: CupertinoColors.white,
      secondaryContainer: CupertinoColors.systemIndigo.withValues(alpha: 0.16),
      onSecondaryContainer: colors.label,
      tertiary: CupertinoColors.systemTeal,
      tertiaryContainer: CupertinoColors.systemTeal.withValues(alpha: 0.16),
      onTertiaryContainer: colors.label,
      surface: colors.systemBackground,
      onSurface: colors.label,
      surfaceContainer: colors.elevatedBackground,
      surfaceContainerHigh: colors.tertiaryBackground,
      surfaceContainerLow: colors.cardBackground,
      surfaceContainerHighest: colors.tertiaryBackground,
      onSurfaceVariant: colors.secondaryLabel,
      outline: colors.separator,
      outlineVariant: colors.separator.withValues(alpha: 0.7),
      error: colors.destructive,
      onError: CupertinoColors.white,
      errorContainer: colors.destructive.withValues(alpha: 0.14),
      onErrorContainer: colors.destructive,
      inverseSurface: colors.isDark
          ? CupertinoColors.white
          : CupertinoColors.black,
      onInverseSurface: colors.isDark
          ? CupertinoColors.black
          : CupertinoColors.white,
      inversePrimary: primary,
      surfaceTint: primary,
      scrim: CupertinoColors.black.withValues(alpha: 0.45),
      shadow: CupertinoColors.black,
    );
  }

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color surface;
  final Color onSurface;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerLow;
  final Color surfaceContainerHighest;
  final Color onSurfaceVariant;
  final Color outline;
  final Color outlineVariant;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color inverseSurface;
  final Color onInverseSurface;
  final Color inversePrimary;
  final Color surfaceTint;
  final Color scrim;
  final Color shadow;
}

class CsacTextTheme {
  const CsacTextTheme({
    required this.displaySmall,
    required this.headlineSmall,
    required this.titleLarge,
    required this.titleMedium,
    required this.titleSmall,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.labelSmall,
  });

  factory CsacTextTheme.from(BuildContext context, CsacColors colors) {
    final base = CupertinoTheme.of(
      context,
    ).textTheme.textStyle.copyWith(color: colors.label);
    return CsacTextTheme(
      displaySmall: base.copyWith(fontSize: 34, fontWeight: FontWeight.w700),
      headlineSmall: base.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
      titleLarge: base.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
      titleMedium: base.copyWith(fontSize: 17, fontWeight: FontWeight.w600),
      titleSmall: base.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      bodyLarge: base.copyWith(fontSize: 17, fontWeight: FontWeight.w400),
      bodyMedium: base.copyWith(fontSize: 15, fontWeight: FontWeight.w400),
      bodySmall: base.copyWith(fontSize: 13, color: colors.secondaryLabel),
      labelLarge: base.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      labelMedium: base.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      labelSmall: base.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
    );
  }

  final TextStyle? displaySmall;
  final TextStyle? headlineSmall;
  final TextStyle? titleLarge;
  final TextStyle? titleMedium;
  final TextStyle? titleSmall;
  final TextStyle? bodyLarge;
  final TextStyle? bodyMedium;
  final TextStyle? bodySmall;
  final TextStyle? labelLarge;
  final TextStyle? labelMedium;
  final TextStyle? labelSmall;
}

class _AppIconImage extends StatelessWidget {
  const _AppIconImage({this.size = 40, this.borderRadius});

  final double size;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? size * 0.22),
      child: Image.asset(
        'assets/icons/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

const double _csacPageHorizontalPadding = 16;
const double _csacGroupedCornerRadius = 18;
const double _csacControlCornerRadius = 16;
const double _csacListMinHeight = 52;
const Duration _csacPressFeedbackDuration = Duration(milliseconds: 120);
const Duration _csacListHighlightDuration = Duration(milliseconds: 110);

class _AdaptivePageFrame extends StatelessWidget {
  const _AdaptivePageFrame({required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 700) {
      return child;
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

class _CsacPressable extends StatefulWidget {
  const _CsacPressable({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_CsacPressable> createState() => _CsacPressableState();
}

class _CsacPressableState extends State<_CsacPressable> {
  bool pressed = false;

  void setPressed(bool value) {
    if (pressed == value || widget.onTap == null) {
      return;
    }
    setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setPressed(true),
      onTapUp: (_) => setPressed(false),
      onTapCancel: () => setPressed(false),
      child: AnimatedScale(
        scale: enabled && pressed ? 0.992 : 1,
        duration: _csacPressFeedbackDuration,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: enabled && pressed ? 0.84 : 1,
          duration: _csacPressFeedbackDuration,
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

class _CupertinoListPressable extends StatefulWidget {
  const _CupertinoListPressable({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;

  @override
  State<_CupertinoListPressable> createState() =>
      _CupertinoListPressableState();
}

class _CupertinoListPressableState extends State<_CupertinoListPressable> {
  bool pressed = false;

  void setPressed(bool value) {
    if (pressed == value || !enabled) {
      return;
    }
    setState(() => pressed = value);
  }

  bool get enabled =>
      widget.onTap != null ||
      widget.onLongPress != null ||
      widget.onSecondaryTap != null;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onLongPressEnd: (_) => setPressed(false),
      onLongPressCancel: () => setPressed(false),
      onSecondaryTap: widget.onSecondaryTap,
      onTapDown: (_) => setPressed(true),
      onTapUp: (_) => setPressed(false),
      onTapCancel: () => setPressed(false),
      child: Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: enabled && pressed ? 1 : 0,
                duration: _csacListHighlightDuration,
                curve: Curves.easeOutCubic,
                child: ColoredBox(color: colors.fill),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CupertinoSearchField extends StatelessWidget {
  const _CupertinoSearchField({
    required this.controller,
    required this.placeholder,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  void clear() {
    controller.clear();
    onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      onChanged: onChanged,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      prefix: Padding(
        padding: const EdgeInsets.only(left: 10, right: 6),
        child: Icon(
          CupertinoIcons.search,
          size: 18,
          color: colors.tertiaryLabel,
        ),
      ),
      suffix: controller.text.isEmpty
          ? null
          : CupertinoButton(
              padding: const EdgeInsets.only(left: 4, right: 8),
              minimumSize: Size.zero,
              onPressed: clear,
              child: Icon(
                CupertinoIcons.xmark_circle_fill,
                size: 18,
                color: colors.tertiaryLabel,
              ),
            ),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 9),
      placeholderStyle: TextStyle(color: colors.tertiaryLabel, fontSize: 16),
      style: TextStyle(color: colors.label, fontSize: 16),
      cursorColor: colors.primaryColor,
      decoration: BoxDecoration(
        color: colors.tertiaryFill,
        borderRadius: BorderRadius.circular(_csacControlCornerRadius),
      ),
    );
  }
}

class _CupertinoGroupedCard extends StatelessWidget {
  const _CupertinoGroupedCard({
    required this.children,
    this.margin,
    this.header,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? margin;
  final String? header;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          margin ??
          const EdgeInsets.symmetric(
            horizontal: _csacPageHorizontalPadding,
            vertical: 7,
          ),
      child: CupertinoListSection.insetGrouped(
        margin: EdgeInsets.zero,
        header: header == null ? null : Text(header!.toUpperCase()),
        backgroundColor: Colors.transparent,
        children: children,
      ),
    );
  }
}

class _CupertinoListTile extends StatelessWidget {
  const _CupertinoListTile({
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  final String title;
  final Widget? leading;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return CupertinoListTile(
      leading: leading == null
          ? null
          : IconTheme.merge(
              data: IconThemeData(color: colors.secondaryLabel, size: 22),
              child: leading!,
            ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: titleColor ?? colors.label),
      ),
      subtitle: subtitle?.isNotEmpty == true
          ? Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.secondaryLabel),
            )
          : null,
      trailing:
          trailing ??
          (onTap == null
              ? null
              : Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: colors.tertiaryLabel,
                )),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: onTap,
    );
  }
}

class _CupertinoExpansionTile extends StatefulWidget {
  const _CupertinoExpansionTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.children = const [],
    this.childrenPadding = EdgeInsets.zero,
    this.initiallyExpanded = false,
    this.onExpansionChanged,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final List<Widget> children;
  final EdgeInsetsGeometry childrenPadding;
  final bool initiallyExpanded;
  final ValueChanged<bool>? onExpansionChanged;

  @override
  State<_CupertinoExpansionTile> createState() =>
      _CupertinoExpansionTileState();
}

class _CupertinoExpansionTileState extends State<_CupertinoExpansionTile> {
  late bool expanded = widget.initiallyExpanded;

  void toggleExpanded() {
    setState(() => expanded = !expanded);
    widget.onExpansionChanged?.call(expanded);
  }

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CupertinoListPressable(
          onTap: toggleExpanded,
          child: Container(
            constraints: const BoxConstraints(minHeight: _csacListMinHeight),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (widget.leading != null) ...[
                  IconTheme.merge(
                    data: IconThemeData(color: colors.secondaryLabel, size: 22),
                    child: widget.leading!,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DefaultTextStyle.merge(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.label,
                          fontSize: 16,
                          height: 1.18,
                        ),
                        child: widget.title,
                      ),
                      if (widget.subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: DefaultTextStyle.merge(
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.secondaryLabel,
                              fontSize: 13,
                              height: 1.22,
                            ),
                            child: widget.subtitle!,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    CupertinoIcons.chevron_right,
                    size: 14,
                    color: colors.tertiaryLabel,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: widget.childrenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            ),
          ),
          crossFadeState: expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
          sizeCurve: Curves.easeOutCubic,
        ),
      ],
    );
  }
}

String pickedImageFileName(XFile picked, ImageSource source) {
  final name = picked.name.trim();
  final extension = p.extension(name).toLowerCase();
  if (name.isNotEmpty && extension.isNotEmpty) {
    return name;
  }
  final fallbackExtension = extension.isEmpty ? '.jpg' : extension;
  final prefix = source == ImageSource.camera ? 'csac_photo' : 'csac_image';
  return '${prefix}_${DateTime.now().millisecondsSinceEpoch}$fallbackExtension';
}

Future<String> persistChatBackground(XFile picked) async {
  return persistChatBackgroundFile(picked);
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}
