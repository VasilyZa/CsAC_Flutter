part of '../../main.dart';

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.fallback});

  final String url;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return CircleAvatar(child: Icon(fallback));
    }
    return CircleAvatar(backgroundImage: NetworkImage(url));
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
  final submitted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: reason,
              minLines: 3,
              maxLines: 5,
              maxLength: 300,
              decoration: InputDecoration(
                labelText: strings.text('Report reason'),
                helperText: strings.text('At least 10 characters'),
                border: const OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: anonymous,
              title: Text(strings.text('Submit anonymously')),
              onChanged: submitting
                  ? null
                  : (value) => setState(() => anonymous = value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: submitting ? null : () => Navigator.of(context).pop(),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: submitting
                ? null
                : () async {
                    final text = reason.text.trim();
                    if (text.length < 10) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            strings.text(
                              'Report reason must be at least 10 characters.',
                            ),
                          ),
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
                      if (context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    } catch (err) {
                      if (context.mounted) {
                        setState(() => submitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              strings.format('Submit failed: {error}', {
                                'error': err,
                              }),
                            ),
                          ),
                        );
                      }
                    }
                  },
            child: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(strings.text('Submit')),
          ),
        ],
      ),
    ),
  );
  reason.dispose();
  if (submitted == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.text('Report submitted.'))));
  }
}

Future<void> showBugReportDialog({
  required BuildContext context,
  required CsacAppState state,
}) async {
  final strings = context.strings;
  final title = TextEditingController();
  final description = TextEditingController();
  var submitting = false;
  final submitted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(strings.text('Feedback Bug')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              maxLength: 60,
              decoration: InputDecoration(
                labelText: strings.text('Title'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: description,
              minLines: 4,
              maxLines: 6,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: strings.text('Detailed description'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: submitting ? null : () => Navigator.of(context).pop(),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: submitting
                ? null
                : () async {
                    final titleText = title.text.trim();
                    final descriptionText = description.text.trim();
                    if (titleText.isEmpty || descriptionText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            strings.text('Please fill all feedback fields.'),
                          ),
                        ),
                      );
                      return;
                    }
                    setState(() => submitting = true);
                    try {
                      await state.client.submitBugReport(
                        title: titleText,
                        description: descriptionText,
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop(true);
                      }
                    } catch (err) {
                      if (context.mounted) {
                        setState(() => submitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              strings.format('Submit failed: {error}', {
                                'error': err,
                              }),
                            ),
                          ),
                        );
                      }
                    }
                  },
            child: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(strings.text('Submit')),
          ),
        ],
      ),
    ),
  );
  title.dispose();
  description.dispose();
  if (submitted == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.text('Feedback submitted.'))),
    );
  }
}

Future<void> openUserProfile(
  BuildContext context,
  CsacAppState state,
  int uid, {
  GroupProfile? group,
  GroupMember? member,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => UserProfileScreen(
        state: state,
        uid: uid,
        group: group,
        member: member,
      ),
    ),
  );
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
