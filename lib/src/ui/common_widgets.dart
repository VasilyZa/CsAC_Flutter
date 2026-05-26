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
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: child);
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
