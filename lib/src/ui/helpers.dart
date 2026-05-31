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
        scale: enabled && pressed ? 0.985 : 1,
        duration: 150.ms,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: enabled && pressed ? 0.72 : 1,
          duration: 150.ms,
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
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
    final colors = CsacColors.of(context);
    return Padding(
      padding:
          margin ??
          const EdgeInsets.symmetric(
            horizontal: _csacPageHorizontalPadding,
            vertical: 7,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                header!.toUpperCase(),
                style: TextStyle(
                  color: colors.secondaryLabel,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.35,
                ),
              ),
            ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(_csacGroupedCornerRadius),
              border: Border.all(
                color: colors.separator.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Column(children: _separated(children, colors.separator)),
          ),
        ],
      ),
    );
  }

  static List<Widget> _separated(List<Widget> children, Color color) {
    final result = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i != children.length - 1) {
        result.add(
          Container(
            height: 0.5,
            margin: const EdgeInsets.only(left: 60),
            color: color.withValues(alpha: 0.55),
          ),
        );
      }
    }
    return result;
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
    return _CsacPressable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: _csacListMinHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor ?? colors.label,
                      fontSize: 16,
                      height: 1.18,
                    ),
                  ),
                  if (subtitle?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.secondaryLabel,
                          fontSize: 13,
                          height: 1.22,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: colors.tertiaryLabel,
              ),
            ],
          ],
        ),
      ),
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
        _CsacPressable(
          onTap: toggleExpanded,
          child: Container(
            constraints: const BoxConstraints(minHeight: _csacListMinHeight),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
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
