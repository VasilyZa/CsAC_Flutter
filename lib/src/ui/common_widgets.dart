part of '../../main.dart';

class CsacThemeBridge extends StatelessWidget {
  const CsacThemeBridge({
    super.key,
    required this.brightness,
    required this.seedColor,
    required this.fontStyle,
    required this.child,
  });

  final Brightness brightness;
  final Color seedColor;
  final CsacFontStyle fontStyle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return material.Theme(
      data: buildCsacTheme(brightness, seedColor, fontStyle).copyWith(
        platform: TargetPlatform.iOS,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: child,
    );
  }
}

class CsacToastHost extends StatefulWidget {
  const CsacToastHost({super.key, required this.child});

  final Widget child;

  static State<CsacToastHost> of(BuildContext context) {
    final state = context.findAncestorStateOfType<CsacToastHostState>();
    if (state == null) {
      throw StateError('No CsacToastHost found in context.');
    }
    return state;
  }

  static State<CsacToastHost>? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<CsacToastHostState>();
  }

  @override
  State<CsacToastHost> createState() => CsacToastHostState();
}

class CsacToastHostState extends State<CsacToastHost>
    with TickerProviderStateMixin {
  final entries = <_CsacToastEntry>[];
  int nextId = 0;

  CsacToastController showSnackBar(SnackBar snackBar) {
    final id = nextId++;
    final controller = AnimationController(duration: 220.ms, vsync: this);
    final entry = _CsacToastEntry(
      id: id,
      snackBar: snackBar,
      animation: controller,
    );
    setState(() => entries.add(entry));
    controller.forward();
    final visibleFor = snackBar.duration == Duration.zero
        ? const Duration(milliseconds: 1800)
        : snackBar.duration;
    entry.timer = Timer(visibleFor, () => removeToast(id));
    return CsacToastController(() => removeToast(id));
  }

  void removeToast(int id) {
    final index = entries.indexWhere((entry) => entry.id == id);
    if (index < 0) {
      return;
    }
    final entry = entries[index];
    entry.timer?.cancel();
    entry.animation.reverse().whenComplete(() {
      if (!mounted) {
        return;
      }
      setState(() => entries.removeWhere((item) => item.id == id));
      entry.animation.dispose();
    });
  }

  void hideCurrentSnackBar() {
    if (entries.isNotEmpty) {
      removeToast(entries.last.id);
    }
  }

  void removeCurrentSnackBar() => hideCurrentSnackBar();

  void clearSnackBars() {
    for (final entry in List<_CsacToastEntry>.from(entries)) {
      removeToast(entry.id);
    }
  }

  @override
  void dispose() {
    for (final entry in entries) {
      entry.timer?.cancel();
      entry.animation.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 12,
          right: 12,
          bottom: bottom + 14,
          child: IgnorePointer(
            ignoring: entries.isEmpty,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in entries.take(3))
                  _CsacToast(
                    entry: entry,
                    onDismiss: () => removeToast(entry.id),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CsacToastEntry {
  _CsacToastEntry({
    required this.id,
    required this.snackBar,
    required this.animation,
  });

  final int id;
  final SnackBar snackBar;
  final AnimationController animation;
  Timer? timer;
}

class CsacToastController {
  const CsacToastController(this.close);

  final VoidCallback close;
}

class _CsacToast extends StatelessWidget {
  const _CsacToast({required this.entry, required this.onDismiss});

  final _CsacToastEntry entry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final curved = CurvedAnimation(
      parent: entry.animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final content = entry.snackBar.content;
    final action = entry.snackBar.action;
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(curved),
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.inverseSurface.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colors.onInverseSurface.withValues(alpha: 0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: DefaultTextStyle.merge(
                          style: TextStyle(
                            color: colors.onInverseSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          child: content,
                        ),
                      ),
                      if (action != null) ...[
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(30, 30),
                          onPressed: () {
                            onDismiss();
                            action.onPressed();
                          },
                          child: Text(action.label),
                        ),
                      ],
                    ],
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

class ScaffoldMessenger {
  static CsacToastHostState of(BuildContext context) =>
      CsacToastHost.of(context) as CsacToastHostState;

  static CsacToastHostState? maybeOf(BuildContext context) =>
      CsacToastHost.maybeOf(context) as CsacToastHostState?;
}

typedef ScaffoldMessengerState = CsacToastHostState;

class SnackBar {
  const SnackBar({
    required this.content,
    this.action,
    this.duration = const Duration(milliseconds: 2600),
    this.backgroundColor,
    this.behavior,
    this.margin,
    this.padding,
    this.shape,
    this.elevation,
    this.showCloseIcon,
    this.width,
  });

  final Widget content;
  final SnackBarAction? action;
  final Duration duration;
  final Color? backgroundColor;
  final Object? behavior;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final ShapeBorder? shape;
  final double? elevation;
  final bool? showCloseIcon;
  final double? width;
}

class SnackBarAction extends StatelessWidget {
  const SnackBarAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.textColor,
    this.disabledTextColor,
    this.backgroundColor,
    this.disabledBackgroundColor,
  });

  final String label;
  final VoidCallback onPressed;
  final Color? textColor;
  final Color? disabledTextColor;
  final Color? backgroundColor;
  final Color? disabledBackgroundColor;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class Card extends StatelessWidget {
  const Card({
    super.key,
    this.color,
    this.shadowColor,
    this.surfaceTintColor,
    this.elevation,
    this.shape,
    this.margin,
    this.clipBehavior,
    this.child,
    this.borderOnForeground = true,
    this.semanticContainer = true,
  });

  final Color? color;
  final Color? shadowColor;
  final Color? surfaceTintColor;
  final double? elevation;
  final ShapeBorder? shape;
  final EdgeInsetsGeometry? margin;
  final Clip? clipBehavior;
  final Widget? child;
  final bool borderOnForeground;
  final bool semanticContainer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class ListTile extends StatelessWidget {
  const ListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.enabled = true,
    this.onTap,
    this.onLongPress,
    this.contentPadding,
    this.selected = false,
    this.selectedColor,
    this.selectedTileColor,
    this.tileColor,
    this.iconColor,
    this.textColor,
    this.dense,
    this.visualDensity,
    this.shape,
    this.isThreeLine,
    this.autofocus = false,
  });

  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final bool enabled;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? contentPadding;
  final bool selected;
  final Color? selectedColor;
  final Color? selectedTileColor;
  final Color? tileColor;
  final Color? iconColor;
  final Color? textColor;
  final bool? dense;
  final VisualDensity? visualDensity;
  final ShapeBorder? shape;
  final bool? isThreeLine;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = enabled
        ? (selected
              ? selectedColor ?? colors.primary
              : textColor ?? colors.onSurface)
        : colors.onSurface.withValues(alpha: 0.36);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      child: Container(
        color: selected ? selectedTileColor : tileColor,
        padding:
            contentPadding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (leading != null) ...[
              IconTheme(
                data: IconThemeData(
                  color: iconColor ?? colors.onSurfaceVariant,
                ),
                child: leading!,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: DefaultTextStyle(
                style: TextStyle(
                  color: foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null) title!,
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      DefaultTextStyle.merge(
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                        child: subtitle!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              IconTheme(
                data: IconThemeData(color: colors.onSurfaceVariant),
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FilledButton extends StatelessWidget {
  const FilledButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.padding,
    this.minimumSize,
    this.fixedSize,
    this.textStyle,
    this.shape,
  });

  const FilledButton.tonal({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.padding,
    this.minimumSize,
    this.fixedSize,
    this.textStyle,
    this.shape,
  });

  FilledButton.icon({
    super.key,
    required this.onPressed,
    Widget? icon,
    required Widget label,
    this.style,
    this.padding,
    this.minimumSize,
    this.fixedSize,
    this.textStyle,
    this.shape,
  }) : child = _ButtonIconLabel(icon: icon, label: label);

  FilledButton.tonalIcon({
    super.key,
    required this.onPressed,
    Widget? icon,
    required Widget label,
    this.style,
    this.padding,
    this.minimumSize,
    this.fixedSize,
    this.textStyle,
    this.shape,
  }) : child = _ButtonIconLabel(icon: icon, label: label);

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final EdgeInsetsGeometry? padding;
  final Size? minimumSize;
  final Size? fixedSize;
  final TextStyle? textStyle;
  final OutlinedBorder? shape;

  static ButtonStyle styleFrom({
    Color? backgroundColor,
    Color? foregroundColor,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    Size? fixedSize,
    TextStyle? textStyle,
    OutlinedBorder? shape,
  }) => ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(backgroundColor),
    foregroundColor: WidgetStatePropertyAll(foregroundColor),
    padding: WidgetStatePropertyAll(padding),
    minimumSize: WidgetStatePropertyAll(minimumSize),
    fixedSize: WidgetStatePropertyAll(fixedSize),
    textStyle: WidgetStatePropertyAll(textStyle),
    shape: WidgetStatePropertyAll(shape),
  );

  @override
  Widget build(BuildContext context) {
    final bg =
        style?.backgroundColor?.resolve({}) ??
        CupertinoTheme.of(context).primaryColor;
    final fg = style?.foregroundColor?.resolve({}) ?? CupertinoColors.white;
    return CupertinoButton.filled(
      onPressed: onPressed,
      color: bg,
      foregroundColor: fg,
      borderRadius: BorderRadius.circular(13),
      padding:
          padding ??
          style?.padding?.resolve({}) ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: child,
    );
  }
}

class OutlinedButton extends StatelessWidget {
  const OutlinedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });

  OutlinedButton.icon({
    super.key,
    required this.onPressed,
    Widget? icon,
    required Widget label,
    this.style,
  }) : child = _ButtonIconLabel(icon: icon, label: label);

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton.tinted(
      onPressed: onPressed,
      borderRadius: BorderRadius.circular(13),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: child,
    );
  }
}

class TextButton extends StatelessWidget {
  const TextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });

  TextButton.icon({
    super.key,
    required this.onPressed,
    Widget? icon,
    required Widget label,
    this.style,
  }) : child = _ButtonIconLabel(icon: icon, label: label);

  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  static ButtonStyle styleFrom({
    Color? foregroundColor,
    VisualDensity? visualDensity,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
  }) => ButtonStyle(
    foregroundColor: WidgetStatePropertyAll(foregroundColor),
    visualDensity: visualDensity,
    padding: WidgetStatePropertyAll(padding),
    minimumSize: WidgetStatePropertyAll(minimumSize),
  );

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      minimumSize: Size.zero,
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color:
              style?.foregroundColor?.resolve({}) ??
              CupertinoTheme.of(context).primaryColor,
        ),
        child: child,
      ),
    );
  }
}

class _ButtonIconLabel extends StatelessWidget {
  const _ButtonIconLabel({required this.icon, required this.label});

  final Widget? icon;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    if (icon == null) {
      return label;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [icon!, const SizedBox(width: 7), label],
    );
  }
}

class IconButton extends StatelessWidget {
  const IconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
    this.color,
    this.iconSize,
    this.style,
    this.padding,
    this.visualDensity,
    this.minimumSize,
    this.fixedSize,
    this.textStyle,
    this.shape,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final String? tooltip;
  final Color? color;
  final double? iconSize;
  final ButtonStyle? style;
  final EdgeInsetsGeometry? padding;
  final VisualDensity? visualDensity;
  final Size? minimumSize;
  final Size? fixedSize;
  final TextStyle? textStyle;
  final OutlinedBorder? shape;

  static ButtonStyle styleFrom({
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    Size? fixedSize,
    OutlinedBorder? shape,
  }) => ButtonStyle(
    padding: WidgetStatePropertyAll(padding),
    minimumSize: WidgetStatePropertyAll(minimumSize),
    fixedSize: WidgetStatePropertyAll(fixedSize),
    shape: WidgetStatePropertyAll(shape),
  );

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      onPressed: onPressed,
      padding: padding ?? const EdgeInsets.all(8),
      minimumSize: Size.zero,
      child: IconTheme(
        data: IconThemeData(
          color: color ?? CupertinoTheme.of(context).primaryColor,
          size: iconSize ?? 22,
        ),
        child: icon,
      ),
    );
  }
}

class Chip extends StatelessWidget {
  const Chip({
    super.key,
    required this.label,
    this.avatar,
    this.backgroundColor,
    this.value,
    this.labelStyle,
    this.visualDensity,
    this.side,
  });

  final Widget label;
  final Widget? avatar;
  final Color? backgroundColor;
  final Object? value;
  final TextStyle? labelStyle;
  final VisualDensity? visualDensity;
  final BorderSide? side;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: side?.color ?? colors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (avatar != null) ...[avatar!, const SizedBox(width: 5)],
          DefaultTextStyle.merge(
            style: labelStyle ?? const TextStyle(fontSize: 13),
            child: label,
          ),
        ],
      ),
    );
  }
}

class InputChip extends StatelessWidget {
  const InputChip({
    super.key,
    required this.label,
    this.avatar,
    this.onDeleted,
  });

  final Widget label;
  final Widget? avatar;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: avatar,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: label),
          if (onDeleted != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onDeleted,
              child: const Icon(CupertinoIcons.xmark_circle_fill, size: 16),
            ),
          ],
        ],
      ),
    );
  }
}

class Badge extends StatelessWidget {
  const Badge({
    super.key,
    required this.label,
    this.child,
    this.backgroundColor,
    this.textColor,
  });

  final Widget label;
  final Widget? child;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final badge = Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color:
            backgroundColor ?? CupertinoColors.systemRed.resolveFrom(context),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: DefaultTextStyle.merge(
        style: TextStyle(
          color: textColor ?? colors.onError,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
        child: label,
      ),
    );
    if (child == null) {
      return badge;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child!,
        Positioned(right: -8, top: -7, child: badge),
      ],
    );
  }
}

class CircularProgressIndicator extends StatelessWidget {
  const CircularProgressIndicator({super.key, this.strokeWidth, this.color});

  final double? strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      CupertinoActivityIndicator(color: color);
}

class LinearProgressIndicator extends StatelessWidget {
  const LinearProgressIndicator({
    super.key,
    this.minHeight,
    this.borderRadius,
    this.value,
    this.backgroundColor,
  });

  final double? minHeight;
  final BorderRadiusGeometry? borderRadius;
  final double? value;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (value != null) {
      return Container(
        height: minHeight ?? 4,
        decoration: BoxDecoration(
          color: backgroundColor ?? colors.surfaceContainerHighest,
          borderRadius: borderRadius ?? BorderRadius.circular(999),
        ),
        clipBehavior: Clip.antiAlias,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value!.clamp(0, 1).toDouble(),
          child: Container(color: colors.primary),
        ),
      );
    }
    return SizedBox(
      height: minHeight ?? 3,
      child: const CupertinoActivityIndicator(radius: 8),
    );
  }
}

class Divider extends StatelessWidget {
  const Divider({super.key, this.height, this.thickness, this.color});

  final double? height;
  final double? thickness;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? 1,
      alignment: Alignment.center,
      child: Container(
        height: thickness ?? 0.5,
        color: color ?? CupertinoColors.separator.resolveFrom(context),
      ),
    );
  }
}

class VerticalDivider extends StatelessWidget {
  const VerticalDivider({super.key, this.width, this.thickness, this.color});

  final double? width;
  final double? thickness;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? 1,
      child: Center(
        child: Container(
          width: thickness ?? 0.5,
          color: color ?? CupertinoColors.separator.resolveFrom(context),
        ),
      ),
    );
  }
}

class CsacScrollBehavior extends CupertinoScrollBehavior {
  const CsacScrollBehavior();
}

class ButtonSegment<T> {
  const ButtonSegment({required this.value, required this.label, this.icon});

  final T value;
  final Widget label;
  final Widget? icon;
}

class SegmentedButton<T extends Object> extends StatelessWidget {
  const SegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
  });

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<T>(
      groupValue: selected.isEmpty ? null : selected.first,
      children: {
        for (final segment in segments)
          segment.value: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: segment.label,
          ),
      },
      onValueChanged: (value) {
        if (value != null) {
          onSelectionChanged({value});
        }
      },
    );
  }
}

class Icons {
  static const forum_rounded = CupertinoIcons.chat_bubble_text_fill;
  static const chat_bubble_outline = CupertinoIcons.chat_bubble;
  static const chat_bubble = CupertinoIcons.chat_bubble_fill;
  static const person_outline = CupertinoIcons.person;
  static const person = CupertinoIcons.person_solid;
  static const person_rounded = CupertinoIcons.person_solid;
  static const groups_outlined = CupertinoIcons.group;
  static const groups_rounded = CupertinoIcons.group_solid;
  static const group_add = CupertinoIcons.person_add;
  static const group_add_outlined = CupertinoIcons.person_add;
  static const group_add_alt = CupertinoIcons.person_add;
  static const person_add_alt = CupertinoIcons.person_add;
  static const person_add_alt_1_outlined = CupertinoIcons.person_add;
  static const person_add_disabled_outlined =
      CupertinoIcons.person_crop_circle_badge_xmark;
  static const person_remove_outlined =
      CupertinoIcons.person_crop_circle_badge_minus;
  static const manage_search = CupertinoIcons.search;
  static const manage_search_outlined = CupertinoIcons.search;
  static const notifications_none = CupertinoIcons.bell;
  static const notifications = CupertinoIcons.bell_fill;
  static const notifications_active_outlined = CupertinoIcons.bell_fill;
  static const notifications_off_outlined = CupertinoIcons.bell_slash;
  static const refresh = CupertinoIcons.arrow_clockwise;
  static const search = CupertinoIcons.search;
  static const close = CupertinoIcons.xmark;
  static const clear = CupertinoIcons.xmark;
  static const add = CupertinoIcons.plus;
  static const add_circle_outline = CupertinoIcons.plus_circle;
  static const add_home_work_outlined = CupertinoIcons.house;
  static const add_photo_alternate_outlined = CupertinoIcons.photo;
  static const copy = CupertinoIcons.doc_on_doc;
  static const tag = CupertinoIcons.tag;
  static const info_outline = CupertinoIcons.info;
  static const campaign_outlined = CupertinoIcons.speaker_2;
  static const key_outlined = CupertinoIcons.lock;
  static const lock_outline = CupertinoIcons.lock;
  static const lock_reset = CupertinoIcons.lock_rotation;
  static const lock_reset_outlined = CupertinoIcons.lock_rotation;
  static const lock_rounded = CupertinoIcons.lock_fill;
  static const lock_open_outlined = CupertinoIcons.lock_open;
  static const question_answer_outlined = CupertinoIcons.chat_bubble_2;
  static const admin_panel_settings_outlined = CupertinoIcons.shield;
  static const logout = CupertinoIcons.square_arrow_right;
  static const login = CupertinoIcons.square_arrow_left;
  static const developer_mode_outlined =
      CupertinoIcons.chevron_left_slash_chevron_right;
  static const perm_media_outlined = CupertinoIcons.photo_on_rectangle;
  static const flag_outlined = CupertinoIcons.flag;
  static const more_vert = CupertinoIcons.ellipsis_vertical;
  static const more_horiz = CupertinoIcons.ellipsis;
  static const chevron_right = CupertinoIcons.chevron_right;
  static const chevron_right_rounded = CupertinoIcons.chevron_right;
  static const push_pin = CupertinoIcons.pin_fill;
  static const push_pin_outlined = CupertinoIcons.pin;
  static const inbox_outlined = CupertinoIcons.tray;
  static const archive_outlined = CupertinoIcons.archivebox;
  static const unarchive_outlined = CupertinoIcons.archivebox_fill;
  static const cloud_off_outlined = CupertinoIcons.wifi_slash;
  static const military_tech_outlined = CupertinoIcons.rosette;
  static const volume_off_outlined = CupertinoIcons.speaker_slash;
  static const volume_up_outlined = CupertinoIcons.speaker_2;
  static const remove_moderator_outlined = CupertinoIcons.shield_slash;
  static const delete_forever_outlined = CupertinoIcons.delete;
  static const delete_outline = CupertinoIcons.delete;
  static const restore_from_trash_outlined =
      CupertinoIcons.arrow_counterclockwise;
  static const restore = CupertinoIcons.arrow_counterclockwise;
  static const edit_note = CupertinoIcons.pencil;
  static const tune = CupertinoIcons.slider_horizontal_3;
  static const block = CupertinoIcons.nosign;
  static const badge_outlined = CupertinoIcons.person_crop_square;
  static const circle_outlined = CupertinoIcons.circle;
  static const workspace_premium_outlined = CupertinoIcons.star_circle;
  static const account_circle_outlined = CupertinoIcons.person_crop_circle;
  static const account_tree_outlined = CupertinoIcons.rectangle_stack;
  static const add_a_photo_outlined = CupertinoIcons.camera;
  static const alternate_email = CupertinoIcons.at;
  static const api_outlined = CupertinoIcons.chevron_left_slash_chevron_right;
  static const apps_outlined = CupertinoIcons.app;
  static const article_outlined = CupertinoIcons.doc_text;
  static const auto_delete_outlined = CupertinoIcons.delete;
  static const battery_saver_outlined = CupertinoIcons.battery_25;
  static const build_outlined = CupertinoIcons.hammer;
  static const check = CupertinoIcons.check_mark;
  static const check_circle = CupertinoIcons.check_mark_circled_solid;
  static const check_circle_outline = CupertinoIcons.check_mark_circled;
  static const check_rounded = CupertinoIcons.check_mark;
  static const checklist = CupertinoIcons.checkmark_alt;
  static const cleaning_services_outlined = CupertinoIcons.sparkles;
  static const code = CupertinoIcons.chevron_left_slash_chevron_right;
  static const dark_mode_outlined = CupertinoIcons.moon;
  static const description_outlined = CupertinoIcons.doc_text;
  static const dns_outlined = CupertinoIcons.globe;
  static const done = CupertinoIcons.check_mark;
  static const done_all = CupertinoIcons.check_mark_circled;
  static const download_outlined = CupertinoIcons.arrow_down_circle;
  static const draw_outlined = CupertinoIcons.pencil_outline;
  static const brush = CupertinoIcons.paintbrush;
  static const emoji_emotions_outlined = CupertinoIcons.smiley;
  static const error_outline = CupertinoIcons.exclamationmark_circle;
  static const event_repeat_outlined = CupertinoIcons.calendar;
  static const feedback_outlined = CupertinoIcons.chat_bubble_text;
  static const fingerprint = CupertinoIcons.lab_flask;
  static const forward_outlined = CupertinoIcons.arrowshape_turn_up_right;
  static const graphic_eq_rounded = CupertinoIcons.waveform;
  static const image_outlined = CupertinoIcons.photo;
  static const insert_drive_file_outlined = CupertinoIcons.doc;
  static const ios_share_outlined = CupertinoIcons.square_arrow_up;
  static const keyboard_arrow_down = CupertinoIcons.chevron_down;
  static const keyboard_return_rounded = CupertinoIcons.return_icon;
  static const light_mode_outlined = CupertinoIcons.sun_max;
  static const link = CupertinoIcons.link;
  static const manage_accounts_outlined = CupertinoIcons.person_2;
  static const mark_chat_unread_outlined = CupertinoIcons.chat_bubble_text;
  static const mark_email_read_outlined = CupertinoIcons.envelope_open;
  static const mark_email_unread_outlined = CupertinoIcons.mail;
  static const message_outlined = CupertinoIcons.chat_bubble_text;
  static const mic = CupertinoIcons.mic;
  static const mic_none = CupertinoIcons.mic;
  static const mic_none_outlined = CupertinoIcons.mic;
  static const mic_off = CupertinoIcons.mic_off;
  static const motion_photos_off_outlined = CupertinoIcons.circle;
  static const network_check_outlined =
      CupertinoIcons.antenna_radiowaves_left_right;
  static const notes_outlined = CupertinoIcons.text_alignleft;
  static const numbers_outlined = CupertinoIcons.number;
  static const opacity = CupertinoIcons.drop;
  static const open_in_new = CupertinoIcons.arrow_up_right_square;
  static const palette_outlined = CupertinoIcons.paintbrush;
  static const pause_rounded = CupertinoIcons.pause_fill;
  static const people_outline = CupertinoIcons.person_2;
  static const photo_camera_outlined = CupertinoIcons.camera;
  static const pin_outlined = CupertinoIcons.pin;
  static const play_arrow = CupertinoIcons.play_arrow;
  static const play_arrow_rounded = CupertinoIcons.play_arrow_solid;
  static const public_outlined = CupertinoIcons.globe;
  static const radio_button_unchecked = CupertinoIcons.circle;
  static const reply = CupertinoIcons.reply;
  static const reply_outlined = CupertinoIcons.reply;
  static const restart_alt = CupertinoIcons.restart;
  static const rounded_corner = CupertinoIcons.rectangle;
  static const save_outlined = CupertinoIcons.tray_arrow_down;
  static const schedule_outlined = CupertinoIcons.clock;
  static const send = CupertinoIcons.paperplane;
  static const send_rounded = CupertinoIcons.paperplane_fill;
  static const settings_outlined = CupertinoIcons.gear;
  static const sort = CupertinoIcons.sort_down;
  static const speed_outlined = CupertinoIcons.speedometer;
  static const star = CupertinoIcons.star_fill;
  static const star_outline = CupertinoIcons.star;
  static const stop_circle_outlined = CupertinoIcons.stop_circle;
  static const swap_horiz = CupertinoIcons.arrow_right_arrow_left;
  static const swipe_left_alt_outlined = CupertinoIcons.arrow_left;
  static const sync = CupertinoIcons.arrow_2_circlepath;
  static const terminal_rounded =
      CupertinoIcons.chevron_left_slash_chevron_right;
  static const text_fields = CupertinoIcons.textformat;
  static const tips_and_updates_outlined = CupertinoIcons.lightbulb;
  static const touch_app_outlined = CupertinoIcons.hand_point_left;
  static const audio_file_outlined = CupertinoIcons.waveform;
  static const brightness_auto_outlined = CupertinoIcons.brightness;
  static const undo = CupertinoIcons.arrow_uturn_left;
  static const backspace_outlined = CupertinoIcons.delete_left;
  static const broken_image_outlined = CupertinoIcons.exclamationmark_triangle;
  static const forum_outlined = CupertinoIcons.chat_bubble_text;
  static const translate = CupertinoIcons.globe;
  static const update = CupertinoIcons.arrow_down_circle;
  static const wallpaper_outlined = CupertinoIcons.photo_fill;
  static const waving_hand_outlined = CupertinoIcons.hand_raised;
}

class AlertDialog extends StatelessWidget {
  const AlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.scrollable = false,
    this.insetPadding,
    this.contentPadding,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final bool scrollable;
  final EdgeInsetsGeometry? insetPadding;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: title,
      content: content == null
          ? null
          : Padding(
              padding: contentPadding ?? EdgeInsets.zero,
              child: CsacThemeBridge(
                brightness: CupertinoTheme.brightnessOf(context),
                seedColor: CupertinoTheme.of(context).primaryColor,
                fontStyle: CsacFontStyle.system,
                child: content!,
              ),
            ),
      actions: [
        for (final action in actions ?? const <Widget>[])
          CupertinoDialogAction(child: action),
      ],
    );
  }
}

class TextField extends StatelessWidget {
  const TextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration = const InputDecoration(),
    this.keyboardType,
    this.textInputAction,
    this.style,
    this.textAlign = TextAlign.start,
    this.readOnly = false,
    this.autofocus = false,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.enabled,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool readOnly;
  final bool autofocus;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final bool? enabled;

  @override
  Widget build(BuildContext context) {
    final label = decoration.labelText;
    final helper = decoration.helperText;
    final hint = decoration.hintText ?? decoration.labelText;
    final field = CupertinoTextField(
      controller: controller,
      focusNode: focusNode,
      placeholder: hint,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: style,
      textAlign: textAlign,
      readOnly: readOnly,
      autofocus: autofocus,
      obscureText: obscureText,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      inputFormatters: inputFormatters,
      enabled: enabled ?? decoration.enabled,
      prefix: decoration.prefixIcon == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: 10),
              child: decoration.prefixIcon,
            ),
      suffix: decoration.suffixIcon == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: 6),
              child: decoration.suffixIcon,
            ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
        ),
      ),
    );
    if (label == null && helper == null) {
      return field;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 5),
            child: Text(
              label,
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        field,
        if (helper != null) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              helper,
              style: TextStyle(
                color: CupertinoColors.tertiaryLabel.resolveFrom(context),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class SwitchListTile extends StatelessWidget {
  const SwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.contentPadding,
    this.secondary,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final EdgeInsetsGeometry? contentPadding;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: contentPadding,
      leading: secondary,
      title: title,
      subtitle: subtitle,
      trailing: CupertinoSwitch(value: value, onChanged: onChanged),
    );
  }
}

enum ListTileControlAffinity { leading, trailing, platform }

class RefreshIndicator extends StatelessWidget {
  const RefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class Scaffold extends StatelessWidget {
  const Scaffold({
    super.key,
    this.appBar,
    this.body,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final bodyChild = body ?? const SizedBox.shrink();
    final content = bottomNavigationBar == null
        ? bodyChild
        : Column(
            children: [
              Expanded(child: bodyChild),
              bottomNavigationBar!,
            ],
          );
    if (appBar is AppBar) {
      final bar = appBar! as AppBar;
      return CupertinoPageScaffold(
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset ?? true,
        navigationBar: bar.toNavigationBar(context),
        child: content,
      );
    }
    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset ?? true,
      child: content,
    );
  }
}

class AppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppBar({
    super.key,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.title,
    this.actions,
    this.bottom,
    this.backgroundColor,
    this.foregroundColor,
    this.titleSpacing,
    this.centerTitle,
  });

  final Widget? leading;
  final bool automaticallyImplyLeading;
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? titleSpacing;
  final bool? centerTitle;

  CupertinoNavigationBar toNavigationBar(BuildContext context) {
    return CupertinoNavigationBar(
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      middle: title,
      transitionBetweenRoutes: false,
      trailing: actions == null || actions!.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: actions!),
      backgroundColor:
          backgroundColor ?? CupertinoTheme.of(context).barBackgroundColor,
      border: Border(
        bottom: BorderSide(
          color: CupertinoColors.separator.resolveFrom(context),
          width: 0,
        ),
      ),
      bottom: bottom,
    );
  }

  @override
  Widget build(BuildContext context) => toNavigationBar(context);

  @override
  Size get preferredSize => Size.fromHeight(
    kMinInteractiveDimensionCupertino + (bottom?.preferredSize.height ?? 0),
  );
}

class CsacPageRoute<T> extends CupertinoPageRoute<T> {
  CsacPageRoute({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
    super.allowSnapshotting,
  });
}

Future<T?> showDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  bool? requestFocus,
}) {
  return showCupertinoDialog<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    barrierLabel: barrierLabel,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    requestFocus: requestFocus,
  );
}

Future<T?> showModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  bool useSafeArea = false,
  Color? backgroundColor,
  String? barrierLabel,
  Color? barrierColor,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  bool? requestFocus,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: isDismissible,
    barrierColor: barrierColor ?? kCupertinoModalBarrierColor,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    requestFocus: requestFocus,
    builder: (popupContext) {
      final child = CsacThemeBridge(
        brightness: CupertinoTheme.brightnessOf(popupContext),
        seedColor: CupertinoTheme.of(popupContext).primaryColor,
        fontStyle: CsacFontStyle.system,
        child: builder(popupContext),
      );
      return CupertinoPopupSurface(
        isSurfacePainted: true,
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: constraints ?? const BoxConstraints(maxHeight: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showDragHandle == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Container(
                      width: 38,
                      height: 5,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey3.resolveFrom(
                          popupContext,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _MotionPreference extends InheritedWidget {
  const _MotionPreference({required this.reduceMotion, required super.child});

  final bool reduceMotion;

  static bool reduceOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_MotionPreference>()
            ?.reduceMotion ??
        false;
  }

  @override
  bool updateShouldNotify(_MotionPreference oldWidget) {
    return reduceMotion != oldWidget.reduceMotion;
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.url,
    required this.fallback,
    this.radius,
    this.heroTag,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String url;
  final IconData fallback;
  final double? radius;
  final Object? heroTag;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final size = (radius ?? 20) * 2;
    final avatar = ClipOval(
      child: Container(
        width: size,
        height: size,
        color:
            backgroundColor ??
            CupertinoColors.secondarySystemFill.resolveFrom(context),
        child: url.isEmpty
            ? Icon(fallback, color: foregroundColor, size: size * 0.56)
            : Image.network(url, fit: BoxFit.cover),
      ),
    );
    if (heroTag == null || _MotionPreference.reduceOf(context)) {
      return avatar;
    }
    return Hero(tag: heroTag!, child: avatar);
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText({
    required this.tag,
    required this.child,
    this.enabled = true,
  });

  final Object tag;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || _MotionPreference.reduceOf(context)) {
      return child;
    }
    final textStyle = DefaultTextStyle.of(context);
    final heroChild = IconTheme(
      data: IconTheme.of(context),
      child: DefaultTextStyle(
        style: textStyle.style,
        textAlign: textStyle.textAlign,
        softWrap: textStyle.softWrap,
        overflow: textStyle.overflow,
        maxLines: textStyle.maxLines,
        child: child,
      ),
    );
    return Hero(tag: tag, child: heroChild);
  }
}

String conversationAvatarHeroTag(Conversation conversation) {
  return 'conversation-avatar:${conversation.type.name}:${conversation.id}';
}

String conversationTitleHeroTag(Conversation conversation) {
  return 'conversation-title:${conversation.type.name}:${conversation.id}';
}

String userAvatarHeroTag(int uid, [String? scope]) {
  if (scope == null || scope.isEmpty) {
    return 'user-avatar:$uid';
  }
  return 'user-avatar:$scope:$uid';
}

class _ConversationTitleHero extends StatelessWidget {
  const _ConversationTitleHero({
    required this.conversation,
    this.enabled = true,
  });

  final Conversation conversation;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _HeroText(
      tag: conversationTitleHeroTag(conversation),
      enabled: enabled,
      child: Text(
        conversation.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ConversationAvatarHero extends StatelessWidget {
  const _ConversationAvatarHero({
    required this.conversation,
    this.enabled = true,
    this.radius = 18,
  });

  final Conversation conversation;
  final bool enabled;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isGroup = conversation.type == ConversationType.group;
    return _Avatar(
      url: conversation.avatar,
      fallback: isGroup ? Icons.groups_rounded : Icons.person_rounded,
      radius: radius,
      heroTag: enabled ? conversationAvatarHeroTag(conversation) : null,
      backgroundColor: isGroup
          ? colors.secondaryContainer
          : colors.primaryContainer,
      foregroundColor: isGroup
          ? colors.onSecondaryContainer
          : colors.onPrimaryContainer,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.pending});

  final bool pending;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(context.strings.text(pending ? 'Pending' : 'Handled')),
    );
  }
}

class _RoundedInkClip extends StatelessWidget {
  const _RoundedInkClip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(borderRadius: BorderRadius.circular(14), child: child);
  }
}

void _hidePlatformTextInput() {
  hidePlatformTextInput();
}

class _PinEntryPad extends StatelessWidget {
  const _PinEntryPad({
    required this.value,
    required this.onChanged,
    this.label = '',
    this.helperText = '',
    this.leadingIcon,
    this.leadingTooltip = '',
    this.onLeadingPressed,
  });

  static const maxLength = 8;

  final String value;
  final ValueChanged<String> onChanged;
  final String label;
  final String helperText;
  final IconData? leadingIcon;
  final String leadingTooltip;
  final VoidCallback? onLeadingPressed;

  void appendDigit(String digit) {
    if (value.length >= maxLength) {
      return;
    }
    HapticFeedback.selectionClick();
    onChanged('$value$digit');
  }

  void backspace() {
    if (value.isEmpty) {
      return;
    }
    HapticFeedback.selectionClick();
    onChanged(value.substring(0, value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
        ],
        Semantics(
          label: label,
          value: '${value.length} / $maxLength',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < maxLength; index++) ...[
                AnimatedContainer(
                  duration: 150.ms,
                  curve: Curves.easeOutCubic,
                  width: index < value.length ? 12 : 9,
                  height: index < value.length ? 12 : 9,
                  decoration: BoxDecoration(
                    color: index < value.length
                        ? colors.primary
                        : colors.outlineVariant,
                    shape: BoxShape.circle,
                  ),
                ),
                if (index != maxLength - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        if (helperText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            helperText,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 18),
        _PinKeypadRows(
          leading: leadingIcon == null
              ? const _PinKeypadPlaceholder()
              : _PinIconButton(
                  tooltip: leadingTooltip,
                  onPressed: onLeadingPressed,
                  icon: Icon(leadingIcon),
                ),
          trailing: _PinIconButton(
            tooltip: context.strings.text('Delete'),
            onPressed: value.isEmpty ? null : backspace,
            icon: const Icon(Icons.backspace_outlined),
          ),
          digitBuilder: (digit) =>
              _PinDigitButton(digit: digit, onTap: () => appendDigit(digit)),
        ),
      ],
    );
  }
}

class _PinKeypadRows extends StatelessWidget {
  const _PinKeypadRows({
    required this.leading,
    required this.trailing,
    required this.digitBuilder,
  });

  final Widget leading;
  final Widget trailing;
  final Widget Function(String digit) digitBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PinKeypadRow(children: ['1', '2', '3'].map(digitBuilder).toList()),
        const SizedBox(height: 10),
        _PinKeypadRow(children: ['4', '5', '6'].map(digitBuilder).toList()),
        const SizedBox(height: 10),
        _PinKeypadRow(children: ['7', '8', '9'].map(digitBuilder).toList()),
        const SizedBox(height: 10),
        _PinKeypadRow(children: [leading, digitBuilder('0'), trailing]),
      ],
    );
  }
}

class _PinKeypadRow extends StatelessWidget {
  const _PinKeypadRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            Expanded(child: children[index]),
            if (index != children.length - 1) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _PinKeypadPlaceholder extends StatelessWidget {
  const _PinKeypadPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(child: SizedBox.square(dimension: 58));
  }
}

class _PinIconButton extends StatelessWidget {
  const _PinIconButton({
    required this.tooltip,
    required this.icon,
    this.onPressed,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Center(
      child: SizedBox.square(
        dimension: 58,
        child: Semantics(
          label: tooltip,
          button: true,
          child: _CsacPressable(
            onTap: onPressed,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.fill.withValues(alpha: 0.46),
              ),
              alignment: Alignment.center,
              child: IconTheme(
                data: IconThemeData(color: colors.label, size: 22),
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinDigitButton extends StatelessWidget {
  const _PinDigitButton({required this.digit, required this.onTap});

  final String digit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Center(
      child: SizedBox.square(
        dimension: 58,
        child: _CsacPressable(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.fill.withValues(alpha: 0.46),
            ),
            alignment: Alignment.center,
            child: Text(
              digit,
              style: TextStyle(
                color: colors.label,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MotionListItem extends StatelessWidget {
  const _MotionListItem({required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (_MotionPreference.reduceOf(context)) {
      return child;
    }
    final delay = Duration(milliseconds: math.min(index * 26, 220).toInt());
    return child
        .animate(delay: delay)
        .fadeIn(duration: 180.ms, curve: Curves.easeOutCubic)
        .slideY(
          begin: 0.055,
          end: 0,
          duration: 260.ms,
          curve: Curves.easeOutCubic,
        )
        .scale(
          begin: const Offset(0.985, 0.985),
          end: const Offset(1, 1),
          duration: 300.ms,
          curve: Curves.easeOutBack,
        );
  }
}

class _MotionPane extends StatelessWidget {
  const _MotionPane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (_MotionPreference.reduceOf(context)) {
      return child;
    }
    return child
        .animate()
        .fadeIn(duration: 180.ms, curve: Curves.easeOutCubic)
        .slideY(
          begin: 0.035,
          end: 0,
          duration: 260.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

ScrollController _desktopSmoothScrollController() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.linux ||
    TargetPlatform.macOS => _DesktopSmoothScrollController(),
    TargetPlatform.android ||
    TargetPlatform.fuchsia ||
    TargetPlatform.iOS => ScrollController(),
  };
}

class _DesktopSmoothScrollController extends ScrollController {
  _DesktopSmoothScrollController()
    : super(debugLabel: 'DesktopSmoothScrollController');

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return _DesktopSmoothScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }
}

class _DesktopSmoothScrollPosition extends ScrollPositionWithSingleContext {
  _DesktopSmoothScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  static const _duration = Duration(milliseconds: 145);
  static const _multiplier = 0.92;

  double? _wheelTarget;

  @override
  void pointerScroll(double delta) {
    if (delta == 0 ||
        !hasPixels ||
        minScrollExtent.isInfinite ||
        maxScrollExtent.isInfinite) {
      _wheelTarget = null;
      super.pointerScroll(delta);
      return;
    }
    final base = _wheelTarget ?? pixels;
    final target = (base + delta * _multiplier)
        .clamp(minScrollExtent, maxScrollExtent)
        .toDouble();
    if (target == pixels) {
      _wheelTarget = null;
      goBallistic(0);
      return;
    }
    _wheelTarget = target;
    updateUserScrollDirection(
      -delta > 0 ? ScrollDirection.forward : ScrollDirection.reverse,
    );
    animateTo(
      target,
      duration: _duration,
      curve: Curves.easeOutCubic,
    ).whenComplete(() {
      final currentTarget = _wheelTarget;
      if (currentTarget != null &&
          (currentTarget - target).abs() < precisionErrorTolerance) {
        _wheelTarget = null;
      }
    });
  }
}

Future<void> openUserProfile(
  BuildContext context,
  CsacAppState state,
  int uid, {
  GroupProfile? group,
  GroupMember? member,
  Object? avatarHeroTag,
}) {
  return Navigator.of(context).push(
    CsacPageRoute<void>(
      builder: (_) => UserProfileScreen(
        state: state,
        uid: uid,
        group: group,
        member: member,
        avatarHeroTag: avatarHeroTag,
      ),
    ),
  );
}

Future<void> confirmLogout(
  BuildContext context,
  CsacAppState state, {
  bool popToRoot = true,
}) async {
  var keepLoginRecord = true;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.strings.text('Sign out')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.strings.text(
                  'Choose whether this device should keep a passwordless login shortcut for this account.',
                ),
              ),
              const SizedBox(height: 12),
              _DialogCheckRow(
                value: keepLoginRecord,
                onChanged: (value) {
                  setState(() => keepLoginRecord = value);
                },
                title: context.strings.text(
                  'Keep passwordless login on this device',
                ),
                subtitle: context.strings.text(
                  'This stores the session cookie for quick login, but never stores your password.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.strings.text('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.strings.text('Sign out')),
            ),
          ],
        ),
      );
    },
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  await state.logout(keepLoginRecord: keepLoginRecord);
  if (!context.mounted || !popToRoot) {
    return;
  }
  Navigator.of(context).popUntil((route) => route.isFirst);
}

class _DialogCheckRow extends StatelessWidget {
  const _DialogCheckRow({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final bool value;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return _CsacPressable(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              value
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.circle,
              color: value
                  ? CupertinoTheme.of(context).primaryColor
                  : colors.tertiaryLabel,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.label,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: colors.secondaryLabel,
                      fontSize: 12,
                      height: 1.2,
                    ),
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed
            .resolveFrom(context)
            .withValues(alpha: colors.isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CupertinoColors.systemRed
              .resolveFrom(context)
              .withValues(alpha: 0.18),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_circle,
            color: CupertinoColors.systemRed.resolveFrom(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.label, fontSize: 14),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            onPressed: onRetry,
            child: Text(context.strings.text('Retry')),
          ),
        ],
      ),
    );
  }
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.state,
    required this.type,
    required this.targetId,
    required this.targetName,
  });

  final CsacAppState state;
  final String type;
  final int targetId;
  final String targetName;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final reason = TextEditingController();
  bool anonymous = false;
  bool submitting = false;
  String? error;

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (reason.text.trim().length < 10) {
      setState(
        () => error = context.strings.text(
          'Reason must be at least 10 characters.',
        ),
      );
      return;
    }
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await widget.state.submitReport(
        type: widget.type,
        targetId: widget.targetId,
        targetName: widget.targetName,
        reason: reason.text,
        anonymous: anonymous,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Report submitted.'))),
      );
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('Report'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                widget.type == 'group'
                    ? Icons.groups_outlined
                    : Icons.person_outline,
              ),
              title: Text(widget.targetName),
              subtitle: Text('${widget.type} #${widget.targetId}'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: strings.text('Report reason'),
                helperText: strings.text('At least 10 characters.'),
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: anonymous,
              onChanged: (value) => setState(() => anonymous = value),
              title: Text(strings.text('Anonymous report')),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: submitting ? null : submit,
              icon: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.flag_outlined),
              label: Text(strings.text('Submit report')),
            ),
          ],
        ),
      ),
    );
  }
}
