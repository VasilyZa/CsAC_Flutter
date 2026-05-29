part of '../../main.dart';

// ============================================================================
// 文字工具
// ============================================================================

String compactMessage(String text, {int max = 80}) {
  final value = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (value.length <= max) return value;
  return '${value.substring(0, max - 3)}...';
}

String formatVoiceDuration(int seconds) {
  final value = seconds <= 0 ? 0 : seconds;
  final minutes = value ~/ 60;
  final rest = value % 60;
  if (minutes <= 0) return '${rest}s';
  return '$minutes:${rest.toString().padLeft(2, '0')}';
}

List<double> voiceWaveformHeights(int seed, int count) {
  final base = seed <= 0 ? 17 : seed;
  return List<double>.generate(count, (index) {
    final value = (base * (index + 3) * 37 + index * index * 11) % 19;
    return 7 + value.toDouble();
  });
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}

// ============================================================================
// 设计系统 - CsacColors
// ============================================================================

class CsacColors {
  CsacColors._(this.brightness, this.primaryColor);

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

  // ── 背景层级 ──────────────────────────────────────────────
  Color get systemBackground =>
      isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

  Color get cardBackground =>
      isDark ? const Color(0xFF1C1C1E) : CupertinoColors.white;

  Color get elevatedBackground =>
      isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF9F9F9);

  Color get tertiaryBackground =>
      isDark ? const Color(0xFF3A3A3C) : const Color(0xFFEFEFF4);

  // ── 文字层级 ──────────────────────────────────────────────
  Color get label => isDark ? CupertinoColors.white : const Color(0xFF000000);

  Color get secondaryLabel =>
      isDark ? const Color(0x99EBEBF5) : const Color(0x993C3C43);

  Color get tertiaryLabel =>
      isDark ? const Color(0x4DEBEBF5) : const Color(0x4C3C3C43);

  Color get quaternaryLabel =>
      isDark ? const Color(0x2DEBEBF5) : const Color(0x2E3C3C43);

  // ── 分隔线 ────────────────────────────────────────────────
  Color get separator =>
      isDark ? const Color(0x5C545458) : const Color(0x4A3C3C43);

  Color get opaqueSeparator =>
      isDark ? const Color(0xFF38383A) : const Color(0xFFC6C6C8);

  // ── 填充色 ────────────────────────────────────────────────
  Color get fill => isDark ? const Color(0x5C787880) : const Color(0x33787880);

  Color get secondaryFill =>
      isDark ? const Color(0x52787880) : const Color(0x29787880);

  Color get tertiaryFill =>
      isDark ? const Color(0x3D787880) : const Color(0x1F767680);

  // ── 系统色 ────────────────────────────────────────────────
  Color get destructive => CupertinoColors.systemRed;
  Color get systemGreen => CupertinoColors.systemGreen;
  Color get systemOrange => CupertinoColors.systemOrange;
  Color get systemBlue => CupertinoColors.systemBlue;

  // ── 气泡色 ────────────────────────────────────────────────
  Color get myBubble => primaryColor;
  Color get otherBubble =>
      isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE9E9EB);
  Color get myBubbleText => CupertinoColors.white;
  Color get otherBubbleText => label;

  // ── 导航栏毛玻璃背景 ──────────────────────────────────────
  Color get navBarBackground =>
      isDark ? const Color(0xCC1C1C1E) : const Color(0xCCF9F9F9);

  // ── 悬浮胶囊导航栏 ────────────────────────────────────────
  Color get floatingTabBarBackground =>
      isDark ? const Color(0xE6242426) : const Color(0xE6FFFFFF);
}

const double _csacPageHorizontalPadding = 16;
const double _csacGroupedCornerRadius = 18;
const double _csacControlCornerRadius = 16;
const double _csacListMinHeight = 52;

const Duration _csacMotionFast = Duration(milliseconds: 150);
const Duration _csacMotionMedium = Duration(milliseconds: 240);
const Duration _csacPageMotion = Duration(milliseconds: 340);
const Duration _csacPageReverseMotion = Duration(milliseconds: 260);
const Curve _csacEaseOut = Curves.easeOutCubic;
const Curve _csacEaseInOut = Curves.easeInOutCubic;
const Curve _csacModernEase = Cubic(0.2, 0.0, 0, 1);

PageRoute<T> _csacPageRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: _csacPageMotion,
    reverseTransitionDuration: _csacPageReverseMotion,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final enter = CurvedAnimation(
        parent: animation,
        curve: _csacModernEase,
        reverseCurve: Curves.easeInCubic,
      );
      final exit = CurvedAnimation(
        parent: secondaryAnimation,
        curve: _csacEaseOut,
      );
      return FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0.96).animate(exit),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(enter),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.035, 0.012),
              end: Offset.zero,
            ).animate(enter),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.992, end: 1).animate(enter),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

Future<T?> _csacPush<T>(BuildContext context, WidgetBuilder builder) {
  return Navigator.of(context).push<T>(_csacPageRoute<T>(builder));
}

PageRoute<T> _csacConversationRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 230),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final enter = CurvedAnimation(
        parent: animation,
        curve: _csacModernEase,
        reverseCurve: Curves.easeInCubic,
      );
      final exit = CurvedAnimation(
        parent: secondaryAnimation,
        curve: _csacEaseOut,
        reverseCurve: _csacEaseOut,
      );
      final incoming = FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(enter),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(enter),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(enter),
            child: child,
          ),
        ),
      );
      return FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0.94).animate(exit),
        child: incoming,
      );
    },
  );
}

Future<T?> _csacPushConversation<T>(
  BuildContext context,
  WidgetBuilder builder,
) {
  return Navigator.of(context).push<T>(_csacConversationRoute<T>(builder));
}

extension _CsacMotionWidget on Widget {
  Widget csacCardEnter({int delayMs = 0, double y = 5}) {
    return animate(delay: Duration(milliseconds: delayMs))
        .fadeIn(duration: _csacMotionMedium, curve: _csacEaseOut)
        .slideY(
          begin: y / 100,
          end: 0,
          duration: _csacMotionMedium,
          curve: _csacModernEase,
        )
        .scale(
          begin: const Offset(0.992, 0.992),
          end: const Offset(1, 1),
          duration: _csacMotionMedium,
          curve: _csacModernEase,
        );
  }

  Widget csacPopupEnter({int delayMs = 0}) {
    return animate(delay: Duration(milliseconds: delayMs))
        .fadeIn(duration: _csacMotionMedium, curve: _csacEaseOut)
        .scale(
          begin: const Offset(0.975, 0.975),
          end: const Offset(1, 1),
          duration: _csacMotionMedium,
          curve: _csacModernEase,
        );
  }
}

class _CsacBlurredPopup extends StatelessWidget {
  const _CsacBlurredPopup({required this.child, this.borderRadius = 24});

  final Widget child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: child,
      ),
    );
  }
}

class _CsacPressable extends StatefulWidget {
  const _CsacPressable({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.985,
    this.opacity = 0.72,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final double opacity;

  @override
  State<_CsacPressable> createState() => _CsacPressableState();
}

class _CsacPressableState extends State<_CsacPressable> {
  bool pressed = false;

  void setPressed(bool value) {
    if (pressed == value ||
        (widget.onTap == null && widget.onLongPress == null)) {
      return;
    }
    setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: (_) => setPressed(true),
      onTapUp: (_) => setPressed(false),
      onTapCancel: () => setPressed(false),
      child: AnimatedScale(
        scale: pressed ? widget.scale : 1,
        duration: _csacMotionFast,
        curve: _csacEaseOut,
        child: AnimatedOpacity(
          opacity: enabled && pressed ? widget.opacity : 1,
          duration: _csacMotionFast,
          curve: _csacEaseOut,
          child: widget.child,
        ),
      ),
    );
  }
}

class _AdaptivePageFrame extends StatelessWidget {
  const _AdaptivePageFrame({required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 700) {
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

// ============================================================================
// 通用组件
// ============================================================================

/// 空状态面板
class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.bubble_left_bubble_right,
              size: 48,
              color: colors.tertiaryLabel,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: colors.secondaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// iOS 风格分组卡片（自动插入分隔线）
class _CupertinoGroupedCard extends StatelessWidget {
  const _CupertinoGroupedCard({
    required this.children,
    this.margin,
    this.header,
    this.footer,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? margin;
  final String? header;
  final String? footer;

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
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: colors.secondaryLabel,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(_csacGroupedCornerRadius),
              border: Border.all(
                color: colors.separator.withValues(alpha: 0.30),
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _withSeparators(children, colors.separator),
            ),
          ).csacCardEnter(),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 6),
              child: Text(
                footer!,
                style: TextStyle(fontSize: 13, color: colors.secondaryLabel),
              ),
            ),
        ],
      ),
    );
  }

  static List<Widget> _withSeparators(List<Widget> items, Color color) {
    if (items.length <= 1) return items;
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) {
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

/// iOS 风格列表行
class _CupertinoListTile extends StatelessWidget {
  const _CupertinoListTile({
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.titleWeight,
    this.showChevron = true,
  });

  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final FontWeight? titleWeight;
  final bool showChevron;

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
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.18,
                      color: titleColor ?? colors.label,
                      fontWeight: titleWeight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.22,
                          color: colors.secondaryLabel,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else if (onTap != null && showChevron) ...[
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

/// 表单输入框
class _CupertinoFormField extends StatelessWidget {
  const _CupertinoFormField({
    required this.controller,
    required this.placeholder,
    this.icon,
    this.obscureText = false,
    this.enabled = true,
    this.textInputAction,
    this.keyboardType,
    this.maxLines = 1,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String placeholder;
  final IconData? icon;
  final bool obscureText;
  final bool enabled;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final int maxLines;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      obscureText: obscureText,
      enabled: enabled,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      prefix: icon == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Icon(icon, size: 18, color: colors.secondaryLabel),
            ),
      padding: EdgeInsets.fromLTRB(icon != null ? 8 : 14, 13, 14, 13),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(_csacControlCornerRadius),
      ),
      style: TextStyle(fontSize: 16, color: colors.label),
      placeholderStyle: TextStyle(fontSize: 16, color: colors.tertiaryLabel),
    );
  }
}

/// 内联错误提示
class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: colors.destructive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_circle,
            size: 16,
            color: colors.destructive,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: colors.destructive),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            onPressed: onRetry,
            child: Text(
              context.strings.text('Retry'),
              style: TextStyle(fontSize: 13, color: colors.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// 确认对话框
Future<bool> _showCupertinoConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmText = 'Confirm',
  bool isDestructive = false,
}) async {
  final strings = context.strings;
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: message != null
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(message),
            )
          : null,
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(strings.text('Cancel')),
        ),
        CupertinoDialogAction(
          isDestructiveAction: isDestructive,
          isDefaultAction: !isDestructive,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(strings.text(confirmText)),
        ),
      ],
    ),
  );
  return result == true;
}

class _AdaptiveSheetAction<T> {
  const _AdaptiveSheetAction({
    required this.value,
    required this.label,
    this.icon,
    this.destructive = false,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool destructive;
}

Future<T?> _showAdaptiveActionSheet<T>(
  BuildContext context, {
  required String title,
  required List<_AdaptiveSheetAction<T>> actions,
}) {
  final wide = MediaQuery.sizeOf(context).width >= 700;
  final strings = context.strings;
  if (!wide) {
    return showCupertinoModalPopup<T>(
      context: context,
      builder: (context) => _CsacBlurredPopup(
        child: CupertinoActionSheet(
          title: Text(title),
          actions: [
            for (final action in actions)
              CupertinoActionSheetAction(
                isDestructiveAction: action.destructive,
                onPressed: () => Navigator.of(context).pop(action.value),
                child: Text(strings.text(action.label)),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.text('Cancel')),
          ),
        ),
      ).csacPopupEnter(),
    );
  }
  return showCupertinoDialog<T>(
    context: context,
    builder: (context) =>
        _AdaptiveDesktopActionPanel<T>(title: title, actions: actions),
  );
}

class _AdaptiveDesktopActionPanel<T> extends StatelessWidget {
  const _AdaptiveDesktopActionPanel({
    required this.title,
    required this.actions,
  });

  final String title;
  final List<_AdaptiveSheetAction<T>> actions;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final strings = context.strings;
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: 360,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            decoration: BoxDecoration(
              color: colors.navBarBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colors.separator.withValues(alpha: 0.35),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withValues(
                    alpha: colors.isDark ? 0.36 : 0.12,
                  ),
                  blurRadius: 36,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.label,
                    ),
                  ),
                ),
                for (final action in actions)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: () => Navigator.of(context).pop(action.value),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: colors.cardBackground.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          if (action.icon != null) ...[
                            Icon(
                              action.icon,
                              size: 19,
                              color: action.destructive
                                  ? colors.destructive
                                  : colors.primaryColor,
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Text(
                              strings.text(action.label),
                              style: TextStyle(
                                fontSize: 15,
                                color: action.destructive
                                    ? colors.destructive
                                    : colors.label,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 徽章图标
class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({
    required this.icon,
    required this.count,
    this.color,
    this.size = 24,
  });
  final IconData icon;
  final int count;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final child = Icon(icon, color: color, size: size);
    if (count <= 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -7,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: CupertinoColors.systemRed,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: CupertinoColors.systemBackground,
                width: 1.5,
              ),
            ),
            constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Toast 提示
// ============================================================================

void _showCupertinoToast(BuildContext context, String message) {
  final overlay = Navigator.of(context, rootNavigator: true).overlay;
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _ToastWidget(
      message: message,
      onDismiss: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    final curve = CurvedAnimation(parent: _ctrl, curve: _csacEaseOut);
    _opacity = curve;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(curve);
    _scale = Tween<double>(begin: 0.97, end: 1).animate(curve);
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) _ctrl.reverse().then((_) => widget.onDismiss());
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).viewInsets.bottom + 72,
      left: 48,
      right: 48,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: FadeTransition(
            opacity: _opacity,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xE0000000),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 悬浮胶囊导航栏（移动端）
// ============================================================================

class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({
    required this.selectedIndex,
    required this.items,
    required this.onTap,
  });

  final int selectedIndex;
  final List<_FloatingTabItem> items;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: colors.floatingTabBarBackground,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: colors.separator.withValues(alpha: 0.6),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: List.generate(items.length, (i) {
                final item = items[i];
                final selected = i == selectedIndex;
                return Expanded(
                  child: _CsacPressable(
                    onTap: () => onTap(i),
                    scale: 0.94,
                    opacity: 0.84,
                    child: AnimatedContainer(
                      duration: _csacMotionFast,
                      curve: _csacEaseInOut,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _BadgeIcon(
                            icon: selected ? item.activeIcon : item.icon,
                            count: item.badge,
                            color: selected
                                ? colors.primaryColor
                                : colors.secondaryLabel,
                            size: 22,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: selected
                                  ? colors.primaryColor
                                  : colors.secondaryLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingTabItem {
  const _FloatingTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge = 0,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
}

// ============================================================================
// 大圆角方形头像（带渐变背景）
// ============================================================================

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.fallback,
    this.size = 44,
    this.name = '',
  });

  final String url;
  final IconData fallback;
  final double size;
  final String name;

  // 根据名字哈希取一个低饱和度的纯色，iOS 联系人风格
  static const _palette = <Color>[
    Color(0xFF3478F6), // 蓝
    Color(0xFF34C759), // 绿
    Color(0xFFFF9500), // 橙
    Color(0xFFFF3B30), // 红
    Color(0xFFAF52DE), // 紫
    Color(0xFF5AC8FA), // 浅蓝
    Color(0xFFFF2D55), // 粉红
    Color(0xFF4CD964), // 浅绿
  ];

  Color _bgColor() {
    if (name.isEmpty) return _palette[0];
    final idx = name.codeUnits.fold(0, (a, b) => a + b) % _palette.length;
    return _palette[idx];
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _buildFallback();
    if (url.isNotEmpty) {
      return SizedBox.square(
        dimension: size,
        child: ClipOval(
          child: Image.network(
            url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : fallback,
          ),
        ),
      );
    }
    return fallback;
  }

  Widget _buildFallback() {
    final bg = _bgColor();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: initial.isNotEmpty
          ? Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
              ),
            )
          : Icon(fallback, size: size * 0.5, color: CupertinoColors.white),
    );
  }
}

// ============================================================================
// 状态标签
// ============================================================================

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.pending});
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: pending
            ? colors.primaryColor.withValues(alpha: 0.12)
            : colors.tertiaryFill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        context.strings.text(pending ? 'Pending' : 'Handled'),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: pending ? colors.primaryColor : colors.secondaryLabel,
        ),
      ),
    );
  }
}
