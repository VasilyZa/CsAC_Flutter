part of '../../main.dart';

class NoticeCenterScreen extends StatelessWidget {
  const NoticeCenterScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  Widget build(BuildContext context) {
    final counts = state.notificationCounts;
    final strings = context.strings;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.text('Notices')),
          actions: [
            IconButton(
              tooltip: strings.text('Refresh'),
              onPressed: state.refreshNotificationCounts,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(
                icon: _TabBadgeIcon(
                  icon: Icons.notifications_none,
                  count: counts.notices,
                ),
                text: strings.text('Notices'),
              ),
              Tab(
                icon: _TabBadgeIcon(
                  icon: Icons.alternate_email,
                  count: counts.mentions + counts.replies,
                ),
                text: strings.text('Mentions'),
              ),
              Tab(
                icon: const Icon(Icons.person_remove_outlined),
                text: strings.text('Friend changes'),
              ),
              Tab(
                icon: _TabBadgeIcon(
                  icon: Icons.person_add_alt,
                  count: counts.friendRequests,
                ),
                text: strings.text('Friends'),
              ),
              Tab(
                icon: _TabBadgeIcon(
                  icon: Icons.group_add_outlined,
                  count: counts.groupApplications,
                ),
                text: strings.text('Groups'),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            NoticesPage(state: state),
            MentionsPage(state: state),
            FriendDeletedNoticesPage(state: state),
            FriendRequestsPage(state: state),
            GroupApplicationsPage(state: state),
          ],
        ),
      ),
    );
  }
}

class FriendDeletedNoticesPage extends StatefulWidget {
  const FriendDeletedNoticesPage({super.key, required this.state});

  final CsacAppState state;

  @override
  State<FriendDeletedNoticesPage> createState() =>
      _FriendDeletedNoticesPageState();
}

class _FriendDeletedNoticesPageState extends State<FriendDeletedNoticesPage> {
  List<FriendDeletedNotice> notices = const <FriendDeletedNotice>[];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget.state.loadDeletedFriendNotices();
      if (mounted) {
        setState(() => notices = loaded);
      }
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (error != null) _InlineError(message: error!, onRetry: load),
          if (!loading && notices.isEmpty)
            _EmptyPanel(message: strings.text('No friend changes.'))
          else
            for (final notice in notices)
              Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  leading: const Icon(Icons.person_remove_outlined),
                  title: Text(notice.nickname),
                  subtitle: Text(
                    [
                      if (notice.time.isNotEmpty) notice.time,
                      if (notice.content.isNotEmpty) notice.content,
                      if (notice.uid > 0) 'UID ${notice.uid}',
                    ].join(' | '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class MentionsPage extends StatefulWidget {
  const MentionsPage({super.key, required this.state});

  final CsacAppState state;

  @override
  State<MentionsPage> createState() => _MentionsPageState();
}

class _MentionsPageState extends State<MentionsPage> {
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.state.refreshMentionCounts();
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final counts = widget.state.notificationCounts;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (error != null) _InlineError(message: error!, onRetry: load),
          Card(
            elevation: 0,
            child: _RoundedInkClip(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.alternate_email),
                    title: Text(strings.text('Mentioned me')),
                    subtitle: Text(
                      strings.format('{count} unread', {
                        'count': counts.mentions,
                      }),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.reply_outlined),
                    title: Text(strings.text('Replied to me')),
                    subtitle: Text(
                      strings.format('{count} unread', {
                        'count': counts.replies,
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(strings.text('Mention list unavailable')),
              subtitle: Text(
                strings.text('Open related chats from the chat list.'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBadgeIcon extends StatelessWidget {
  const _TabBadgeIcon({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return _BadgeIcon(icon: icon, count: count);
  }
}

class NoticesPage extends StatefulWidget {
  const NoticesPage({super.key, required this.state});

  final CsacAppState state;

  @override
  State<NoticesPage> createState() => _NoticesPageState();
}

class _NoticesPageState extends State<NoticesPage> {
  List<CsacNotice> notices = const <CsacNotice>[];
  bool loading = true;
  bool acting = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget.state.loadNotices();
      if (!mounted) {
        return;
      }
      setState(() => notices = loaded);
      widget.state.updateNotificationCounts(
        notices: loaded.where((notice) => !notice.isRead).length,
      );
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> markAllRead() async {
    setState(() => acting = true);
    try {
      await widget.state.markNoticeRead(readAll: true);
      await load();
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => acting = false);
      }
    }
  }

  Future<void> markOneRead(CsacNotice notice) async {
    setState(() => acting = true);
    try {
      await widget.state.markNoticeRead(noticeId: notice.id);
      await load();
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => acting = false);
      }
    }
  }

  void openNotice(CsacNotice notice) {
    final strings = context.strings;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notice.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (notice.time.isNotEmpty)
                Text(
                  notice.time,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              if (notice.time.isNotEmpty) const SizedBox(height: 12),
              SelectableText(
                notice.content.isEmpty
                    ? strings.text('(empty)')
                    : notice.content,
              ),
              if (notice.link.isNotEmpty) ...[
                const SizedBox(height: 12),
                SelectableText(notice.link),
              ],
            ],
          ),
        ),
        actions: [
          if (notice.link.isNotEmpty)
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(notice.link),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new),
              label: Text(strings.text('Open')),
            ),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(
                  text:
                      '${notice.title}\n${notice.time}\n\n${notice.content}\n${notice.link}',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(strings.text('Notice copied'))),
              );
            },
            icon: const Icon(Icons.copy),
            label: Text(strings.text('Copy')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.text('Close')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.format('{count} unread', {
                    'count': notices.where((notice) => !notice.isRead).length,
                  }),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: acting || notices.isEmpty ? null : markAllRead,
                icon: const Icon(Icons.done_all),
                label: Text(strings.text('Mark all read')),
              ),
            ],
          ),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (error != null) _InlineError(message: error!, onRetry: load),
          if (!loading && notices.isEmpty)
            _EmptyPanel(message: strings.text('No notices.'))
          else
            for (final notice in notices)
              Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  onTap: () => openNotice(notice),
                  leading: Icon(
                    notice.isRead
                        ? Icons.mark_email_read_outlined
                        : Icons.mark_email_unread_outlined,
                  ),
                  title: Text(
                    notice.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: notice.isRead
                          ? FontWeight.w500
                          : FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(
                    [
                      if (notice.time.isNotEmpty) notice.time,
                      notice.content.replaceAll('\n', ' '),
                    ].join(' | '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: notice.isRead
                      ? const Icon(Icons.chevron_right)
                      : IconButton(
                          tooltip: strings.text('Mark read'),
                          onPressed: acting ? null : () => markOneRead(notice),
                          icon: const Icon(Icons.done),
                        ),
                ),
              ),
        ],
      ),
    );
  }
}

class FriendRequestsPage extends StatefulWidget {
  const FriendRequestsPage({super.key, required this.state});

  final CsacAppState state;

  @override
  State<FriendRequestsPage> createState() => _FriendRequestsPageState();
}

class _FriendRequestsPageState extends State<FriendRequestsPage> {
  List<FriendRequest> requests = const <FriendRequest>[];
  bool loading = true;
  int? actingId;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget.state.loadFriendRequests();
      if (!mounted) {
        return;
      }
      setState(() => requests = loaded);
      widget.state.updateNotificationCounts(
        friendRequests: loaded.where((request) => request.pending).length,
      );
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> handle(FriendRequest request, String action) async {
    setState(() => actingId = request.id);
    try {
      await widget.state.handleFriendRequest(request.id, action);
      await load();
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => actingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (error != null) _InlineError(message: error!, onRetry: load),
          if (!loading && requests.isEmpty)
            _EmptyPanel(message: strings.text('No friend requests.'))
          else
            for (final request in requests)
              _FriendRequestTile(
                request: request,
                acting: actingId == request.id,
                onOpenUser: () =>
                    openUserProfile(context, widget.state, request.fromUid),
                onAgree: request.pending
                    ? () => handle(request, 'agree')
                    : null,
                onRefuse: request.pending
                    ? () => handle(request, 'refuse')
                    : null,
              ),
        ],
      ),
    );
  }
}

class _FriendRequestTile extends StatelessWidget {
  const _FriendRequestTile({
    required this.request,
    required this.acting,
    this.onOpenUser,
    this.onAgree,
    this.onRefuse,
  });

  final FriendRequest request;
  final bool acting;
  final VoidCallback? onOpenUser;
  final VoidCallback? onAgree;
  final VoidCallback? onRefuse;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: onOpenUser,
              leading: _Avatar(
                url: request.avatar,
                fallback: Icons.person_rounded,
              ),
              title: Text(request.nickname),
              subtitle: Text(
                [
                  if (request.username.isNotEmpty) '@${request.username}',
                  'UID ${request.fromUid}',
                  if (request.createTime.isNotEmpty) request.createTime,
                ].join(' | '),
              ),
              trailing: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusChip(pending: request.pending),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            if (request.content.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(request.content),
            ],
            if (request.pending) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: acting ? null : onRefuse,
                    child: Text(strings.text('Refuse')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: acting ? null : onAgree,
                    icon: acting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(strings.text('Agree')),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class GroupApplicationsPage extends StatefulWidget {
  const GroupApplicationsPage({super.key, required this.state});

  final CsacAppState state;

  @override
  State<GroupApplicationsPage> createState() => _GroupApplicationsPageState();
}

class _GroupApplicationsPageState extends State<GroupApplicationsPage> {
  List<GroupApplication> applications = const <GroupApplication>[];
  bool loading = true;
  int? actingId;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget.state.loadGroupApplications();
      if (!mounted) {
        return;
      }
      setState(() => applications = loaded);
      widget.state.updateNotificationCounts(
        groupApplications: loaded
            .where((application) => application.pending)
            .length,
      );
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> handle(GroupApplication application, String action) async {
    setState(() => actingId = application.id);
    try {
      await widget.state.handleGroupApplication(application.id, action);
      await load();
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => actingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        children: [
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (error != null) _InlineError(message: error!, onRetry: load),
          if (!loading && applications.isEmpty)
            _EmptyPanel(message: strings.text('No group applications.'))
          else
            for (final application in applications)
              _GroupApplicationTile(
                application: application,
                acting: actingId == application.id,
                onOpenUser: () async {
                  GroupProfile? group;
                  if (application.roomId > 0) {
                    try {
                      group = await widget.state.loadGroupProfile(
                        application.roomId,
                      );
                    } catch (_) {}
                  }
                  if (!context.mounted) {
                    return;
                  }
                  await openUserProfile(
                    context,
                    widget.state,
                    application.uid,
                    group: group,
                  );
                },
                onPass: application.pending
                    ? () => handle(application, 'pass')
                    : null,
                onRefuse: application.pending
                    ? () => handle(application, 'refuse')
                    : null,
              ),
        ],
      ),
    );
  }
}

class _GroupApplicationTile extends StatelessWidget {
  const _GroupApplicationTile({
    required this.application,
    required this.acting,
    this.onOpenUser,
    this.onPass,
    this.onRefuse,
  });

  final GroupApplication application;
  final bool acting;
  final VoidCallback? onOpenUser;
  final VoidCallback? onPass;
  final VoidCallback? onRefuse;

  @override
  Widget build(BuildContext context) {
    final message = application.content.isEmpty
        ? application.answer
        : application.content;
    final strings = context.strings;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: onOpenUser,
              leading: _Avatar(
                url: application.avatar,
                fallback: Icons.person_rounded,
              ),
              title: Text(application.nickname),
              subtitle: Text(
                [
                  if (application.username.isNotEmpty)
                    '@${application.username}',
                  'UID ${application.uid}',
                  if (application.roomName.isNotEmpty)
                    strings.format('Group: {name}', {
                      'name': application.roomName,
                    }),
                  if (application.createTime.isNotEmpty) application.createTime,
                ].join(' | '),
              ),
              trailing: Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _StatusChip(pending: application.pending),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(message),
            ],
            if (application.pending) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: acting ? null : onRefuse,
                    child: Text(strings.text('Refuse')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: acting ? null : onPass,
                    icon: acting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(strings.text('Pass')),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
