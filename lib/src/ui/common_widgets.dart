part of '../../main.dart';

Future<void> showReportDialog({
  required BuildContext context,
  required CsacAppState state,
  required String type,
  required String title,
  int uid = 0,
  int rid = 0,
  int messageId = 0,
  String nickname = '',
  String username = '',
  String roomName = '',
}) async {
  final strings = context.strings;
  final reason = TextEditingController();
  var anonymous = true;
  var submitting = false;
  final submitted = await showCupertinoDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final colors = CsacColors.of(context);
        return CupertinoAlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: reason,
                minLines: 3,
                maxLines: 5,
                maxLength: 300,
                placeholder: strings.text('Report reason'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.tertiaryBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                strings.text('At least 10 characters'),
                style: TextStyle(fontSize: 12, color: colors.secondaryLabel),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    strings.text('Submit anonymously'),
                    style: TextStyle(fontSize: 14, color: colors.label),
                  ),
                  CupertinoSwitch(
                    value: anonymous,
                    onChanged: submitting
                        ? null
                        : (value) => setState(() => anonymous = value),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: submitting ? null : () => Navigator.of(context).pop(),
              child: Text(strings.text('Cancel')),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: submitting
                  ? null
                  : () async {
                      final text = reason.text.trim();
                      if (text.length < 10) {
                        _showCupertinoToast(
                          context,
                          strings.text(
                            'Report reason must be at least 10 characters.',
                          ),
                        );
                        return;
                      }
                      setState(() => submitting = true);
                      try {
                        await state.client.submitReport(
                          type: type,
                          reason: text,
                          anonymous: anonymous,
                          uid: uid,
                          rid: rid,
                          messageId: messageId,
                          nickname: nickname,
                          username: username,
                          roomName: roomName,
                        );
                        if (context.mounted) Navigator.of(context).pop(true);
                      } catch (err) {
                        if (context.mounted) {
                          setState(() => submitting = false);
                          _showCupertinoToast(
                            context,
                            strings.format('Submit failed: {error}', {
                              'error': err,
                            }),
                          );
                        }
                      }
                    },
              child: submitting
                  ? const CupertinoActivityIndicator()
                  : Text(strings.text('Submit')),
            ),
          ],
        );
      },
    ),
  );
  reason.dispose();
  if (submitted == true && context.mounted) {
    _showCupertinoToast(context, strings.text('Report submitted.'));
  }
}

Future<void> showBugReportDialog({
  required BuildContext context,
  required CsacAppState state,
}) async {
  final strings = context.strings;
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  var submitting = false;
  final submitted = await showCupertinoDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final colors = CsacColors.of(context);
        return CupertinoAlertDialog(
          title: Text(strings.text('Feedback Bug')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: titleCtrl,
                maxLength: 60,
                placeholder: strings.text('Title'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.tertiaryBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: descCtrl,
                minLines: 4,
                maxLines: 6,
                maxLength: 500,
                placeholder: strings.text('Detailed description'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.tertiaryBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: submitting ? null : () => Navigator.of(context).pop(),
              child: Text(strings.text('Cancel')),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: submitting
                  ? null
                  : () async {
                      final t = titleCtrl.text.trim();
                      final d = descCtrl.text.trim();
                      if (t.isEmpty || d.isEmpty) {
                        _showCupertinoToast(
                          context,
                          strings.text('Please fill all feedback fields.'),
                        );
                        return;
                      }
                      setState(() => submitting = true);
                      try {
                        await state.client.submitBugReport(
                          title: t,
                          description: d,
                        );
                        if (context.mounted) Navigator.of(context).pop(true);
                      } catch (err) {
                        if (context.mounted) {
                          setState(() => submitting = false);
                          _showCupertinoToast(
                            context,
                            strings.format('Submit failed: {error}', {
                              'error': err,
                            }),
                          );
                        }
                      }
                    },
              child: submitting
                  ? const CupertinoActivityIndicator()
                  : Text(strings.text('Submit')),
            ),
          ],
        );
      },
    ),
  );
  titleCtrl.dispose();
  descCtrl.dispose();
  if (submitted == true && context.mounted) {
    _showCupertinoToast(context, strings.text('Feedback submitted.'));
  }
}

Future<void> openUserProfile(
  BuildContext context,
  CsacAppState state,
  int uid, {
  GroupProfile? group,
  GroupMember? member,
}) {
  return _csacPush<void>(
    context,
    (_) =>
        UserProfileScreen(state: state, uid: uid, group: group, member: member),
  );
}

String _conversationHeroKey(Conversation conversation, String slot) {
  return 'csac-conversation-$slot-${conversation.type.name}-${conversation.id}';
}

class _CsacContextRectTween extends RectTween {
  _CsacContextRectTween({super.begin, super.end});

  @override
  Rect? lerp(double t) {
    return Rect.lerp(begin, end, _csacModernEase.transform(t));
  }
}

class _ConversationSurfaceHero extends StatelessWidget {
  const _ConversationSurfaceHero({
    required this.conversation,
    required this.child,
    this.enabled = true,
  });

  final Conversation conversation;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    return Hero(
      tag: _conversationHeroKey(conversation, 'surface'),
      createRectTween: (begin, end) =>
          _CsacContextRectTween(begin: begin, end: end),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

class _ConversationAvatarHero extends StatelessWidget {
  const _ConversationAvatarHero({required this.conversation, this.size = 44});

  final Conversation conversation;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isGroup = conversation.type == ConversationType.group;
    final avatar = _Avatar(
      url: conversation.avatar,
      fallback: isGroup
          ? CupertinoIcons.person_2_fill
          : CupertinoIcons.person_fill,
      size: size,
      name: conversation.name,
    );
    return Hero(
      tag: _conversationHeroKey(conversation, 'avatar'),
      createRectTween: (begin, end) =>
          _CsacContextRectTween(begin: begin, end: end),
      child: SizedBox.square(
        dimension: size,
        child: Material(type: MaterialType.transparency, child: avatar),
      ),
    );
  }
}

class _CsacHeroText extends StatelessWidget {
  const _CsacHeroText({
    required this.tag,
    required this.child,
    this.enabled = true,
  });

  final Object tag;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }
    return Hero(
      tag: tag,
      createRectTween: (begin, end) =>
          _CsacContextRectTween(begin: begin, end: end),
      placeholderBuilder: (context, heroSize, child) =>
          SizedBox(width: heroSize.width, height: heroSize.height),
      flightShuttleBuilder:
          (context, animation, direction, fromContext, toContext) {
            final shuttle = direction == HeroFlightDirection.push
                ? toContext.widget
                : fromContext.widget;
            return Material(type: MaterialType.transparency, child: shuttle);
          },
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

class _ConversationTitleHero extends StatelessWidget {
  const _ConversationTitleHero({
    required this.conversation,
    required this.style,
    this.enabled = true,
  });

  final Conversation conversation;
  final TextStyle style;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return _CsacHeroText(
      tag: _conversationHeroKey(conversation, 'title'),
      enabled: enabled,
      child: Text(
        conversation.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}
