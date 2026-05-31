part of '../../main.dart';

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
    final avatar = url.isEmpty
        ? CircleAvatar(
            radius: radius,
            backgroundColor: backgroundColor,
            child: Icon(fallback, color: foregroundColor),
          )
        : CircleAvatar(radius: radius, backgroundImage: NetworkImage(url));
    if (heroTag == null || _MotionPreference.reduceOf(context)) {
      return avatar;
    }
    return Hero(
      tag: heroTag!,
      child: Material(type: MaterialType.transparency, child: avatar),
    );
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
    return Hero(
      tag: tag,
      child: Material(type: MaterialType.transparency, child: child),
    );
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
      visualDensity: VisualDensity.compact,
    );
  }
}

class _RoundedInkClip extends StatelessWidget {
  const _RoundedInkClip({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(12),
      child: child,
    );
  }
}

void _hidePlatformTextInput() {
  FocusManager.instance.primaryFocus?.unfocus();
  if (Platform.isIOS || Platform.isAndroid) {
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
  }
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
    return Center(
      child: SizedBox.square(
        dimension: 58,
        child: IconButton.filledTonal(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: icon,
          style: IconButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(58),
            fixedSize: const Size.square(58),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: const CircleBorder(),
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
    return Center(
      child: SizedBox.square(
        dimension: 58,
        child: FilledButton.tonal(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(58),
            fixedSize: const Size.square(58),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            shape: const CircleBorder(),
          ),
          child: Text(digit),
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
    if (delta == 0 || !hasPixels) {
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
    MaterialPageRoute<void>(
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
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: keepLoginRecord,
                onChanged: (value) {
                  setState(() => keepLoginRecord = value ?? true);
                },
                title: Text(
                  context.strings.text(
                    'Keep passwordless login on this device',
                  ),
                ),
                subtitle: Text(
                  context.strings.text(
                    'This stores the session cookie for quick login, but never stores your password.',
                  ),
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

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: onRetry,
          child: Text(context.strings.text('Retry')),
        ),
      ],
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
