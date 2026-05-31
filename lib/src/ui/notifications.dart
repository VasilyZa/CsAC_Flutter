part of '../../main.dart';

class NoticeCenterScreen extends StatefulWidget {
  const NoticeCenterScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<NoticeCenterScreen> createState() => _NoticeCenterScreenState();
}

class _NoticeCenterScreenState extends State<NoticeCenterScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final counts = widget.state.notificationCounts;
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final pages = [
      NoticesPage(state: widget.state),
      MentionNoticesPage(state: widget.state),
      FriendChangeNoticesPage(state: widget.state),
      FriendRequestsPage(state: widget.state),
      GroupApplicationsPage(state: widget.state),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.text('Notices')),
        actions: [
          IconButton(
            tooltip: strings.text('Refresh'),
            onPressed: widget.state.refreshNotificationCounts,
            icon: const Icon(CupertinoIcons.arrow_clockwise),
          ),
        ],
      ),
      backgroundColor: colors.systemBackground,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: index,
                onValueChanged: (value) {
                  if (value != null) {
                    setState(() => index = value);
                  }
                },
                children: {
                  0: _NoticeSegment(
                    icon: CupertinoIcons.bell,
                    count: counts.notices,
                    label: strings.text('Notices'),
                  ),
                  1: _NoticeSegment(
                    icon: CupertinoIcons.at,
                    count: counts.mentions,
                    label: strings.text('Mentions'),
                  ),
                  2: _NoticeSegment(
                    icon: CupertinoIcons.person_2,
                    count: counts.friendChanges,
                    label: strings.text('Friend changes'),
                  ),
                  3: _NoticeSegment(
                    icon: CupertinoIcons.person_add,
                    count: counts.friendRequests,
                    label: strings.text('Friends'),
                  ),
                  4: _NoticeSegment(
                    icon: CupertinoIcons.group,
                    count: counts.groupApplications,
                    label: strings.text('Groups'),
                  ),
                },
              ),
            ),
            Expanded(child: pages[index]),
          ],
        ),
      ),
    );
  }
}

class _NoticeSegment extends StatelessWidget {
  const _NoticeSegment({
    required this.icon,
    required this.count,
    required this.label,
  });

  final IconData icon;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _BadgeIcon(icon: icon, count: count, size: 16),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class MentionNoticesPage extends StatefulWidget {
  const MentionNoticesPage({super.key, required this.state});

  final CsacAppState state;

  @override
  State<MentionNoticesPage> createState() => _MentionNoticesPageState();
}

class _MentionNoticesPageState extends State<MentionNoticesPage> {
  MentionNoticeBundle bundle = const MentionNoticeBundle(items: []);
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
      final loaded = await widget.state.loadVisibleMentionNotices();
      if (!mounted) {
        return;
      }
      setState(() => bundle = loaded);
      widget.state.updateNotificationCounts(mentions: loaded.unreadCount);
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

  Future<void> openMention(MentionNotice notice) async {
    final navigator = Navigator.of(context);
    await widget.state.markMentionNoticeRead(notice);
    await navigator.push(
      CsacPageRoute<void>(
        builder: (_) => ChatScreen(
          state: widget.state,
          conversation: notice.conversation,
          focusMessageId: notice.message.id > 0 ? notice.message.id : null,
        ),
      ),
    );
    if (mounted) {
      load();
    }
  }

  Future<void> markRead(MentionNotice notice) async {
    await widget.state.markMentionNoticeRead(notice);
    await load();
  }

  Future<void> clearNotice(MentionNotice notice) async {
    await widget.state.clearMentionNotice(notice);
    await load();
  }

  Future<void> markSummaryRead() async {
    await widget.state.markMentionSummaryRead();
    await load();
  }

  Future<void> clearSummary() async {
    await widget.state.clearMentionSummary();
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          MediaQuery.paddingOf(context).bottom + 92,
        ),
        children: [
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (error != null) _InlineError(message: error!, onRetry: load),
          if (!loading && bundle.hasOnlySummary)
            _MotionListItem(
              child: _MentionSummaryCard(
                bundle: bundle,
                onMarkRead: markSummaryRead,
                onClear: clearSummary,
              ),
            )
          else if (!loading && bundle.items.isEmpty)
            _EmptyPanel(message: strings.text('No mentions or replies.'))
          else
            for (final entry in bundle.items.indexed)
              _MotionListItem(
                index: entry.$1,
                child: _MentionNoticeTile(
                  notice: entry.$2,
                  preferences: widget.state.preferences,
                  onTap: () => openMention(entry.$2),
                  onMarkRead: () => markRead(entry.$2),
                  onClear: () => clearNotice(entry.$2),
                ),
              ),
        ],
      ),
    );
  }
}

class _MentionNoticeTile extends StatelessWidget {
  const _MentionNoticeTile({
    required this.notice,
    required this.preferences,
    required this.onTap,
    required this.onMarkRead,
    required this.onClear,
  });

  final MentionNotice notice;
  final CsacPreferences preferences;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final time = displayMessageTime(notice.message, preferences);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: _RoundedInkClip(
        child: ListTile(
          onTap: onTap,
          leading: Icon(
            notice.isReply ? Icons.reply_outlined : Icons.alternate_email,
          ),
          title: Text(
            notice.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: notice.isRead ? FontWeight.w500 : FontWeight.w800,
            ),
          ),
          subtitle: Text(
            [
              notice.conversation.name,
              if (notice.message.sender.isNotEmpty) notice.message.sender,
              if (time.isNotEmpty) time,
              notice.message.body.replaceAll('\n', ' '),
            ].where((part) => part.trim().isNotEmpty).join(' | '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Wrap(
            spacing: 4,
            children: [
              if (!notice.isRead)
                IconButton(
                  tooltip: context.strings.text('Mark read'),
                  onPressed: onMarkRead,
                  icon: const Icon(Icons.done),
                ),
              IconButton(
                tooltip: context.strings.text('Clear'),
                onPressed: onClear,
                icon: const Icon(Icons.clear),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _MentionSummaryCard extends StatelessWidget {
  const _MentionSummaryCard({
    required this.bundle,
    required this.onMarkRead,
    required this.onClear,
  });

  final MentionNoticeBundle bundle;
  final VoidCallback onMarkRead;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.alternate_email,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.text('Mentions and replies'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Badge(label: Text('${bundle.unreadCount}')),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.alternate_email, size: 18),
                  label: Text(
                    strings.format('@ me: {count}', {
                      'count': bundle.mentionCount,
                    }),
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.reply_outlined, size: 18),
                  label: Text(
                    strings.format('Replies: {count}', {
                      'count': bundle.replyCount,
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              strings.text(
                'The server returned counts only, so there is no message position to open yet.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onMarkRead,
                  icon: const Icon(Icons.done),
                  label: Text(strings.text('Mark read')),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear),
                  label: Text(strings.text('Clear')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FriendChangeNoticesPage extends StatefulWidget {
  const FriendChangeNoticesPage({super.key, required this.state});

  final CsacAppState state;

  @override
  State<FriendChangeNoticesPage> createState() =>
      _FriendChangeNoticesPageState();
}

class _FriendChangeNoticesPageState extends State<FriendChangeNoticesPage> {
  List<FriendChangeNotice> notices = const <FriendChangeNotice>[];
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
      final loaded = await widget.state.loadFriendChangeNotices();
      if (!mounted) {
        return;
      }
      setState(() => notices = loaded);
      widget.state.updateNotificationCounts(
        friendChanges: loaded.where((notice) => !notice.isRead).length,
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

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          MediaQuery.paddingOf(context).bottom + 92,
        ),
        children: [
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (error != null) _InlineError(message: error!, onRetry: load),
          if (!loading && notices.isEmpty)
            _EmptyPanel(message: strings.text('No friend changes.'))
          else
            for (final entry in notices.indexed)
              _MotionListItem(
                index: entry.$1,
                child: Card(
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: _RoundedInkClip(
                    child: ListTile(
                      onTap: entry.$2.uid > 0
                          ? () => openUserProfile(
                              context,
                              widget.state,
                              entry.$2.uid,
                            )
                          : null,
                      leading: _Avatar(
                        url: entry.$2.avatar,
                        fallback: Icons.manage_accounts_outlined,
                      ),
                      title: Text(
                        entry.$2.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: entry.$2.isRead
                              ? FontWeight.w500
                              : FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (entry.$2.username.isNotEmpty)
                            '@${entry.$2.username}',
                          if (entry.$2.kind.isNotEmpty) entry.$2.kind,
                          if (entry.$2.time.isNotEmpty) entry.$2.time,
                          entry.$2.content.replaceAll('\n', ' '),
                        ].where((part) => part.trim().isNotEmpty).join(' | '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: entry.$2.uid > 0
                          ? const Icon(Icons.chevron_right)
                          : null,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
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
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          MediaQuery.paddingOf(context).bottom + 92,
        ),
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
            for (final entry in notices.indexed)
              _MotionListItem(
                index: entry.$1,
                child: Card(
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: _RoundedInkClip(
                    child: ListTile(
                      onTap: () => openNotice(entry.$2),
                      leading: Icon(
                        entry.$2.isRead
                            ? Icons.mark_email_read_outlined
                            : Icons.mark_email_unread_outlined,
                      ),
                      title: Text(
                        entry.$2.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: entry.$2.isRead
                              ? FontWeight.w500
                              : FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (entry.$2.time.isNotEmpty) entry.$2.time,
                          entry.$2.content.replaceAll('\n', ' '),
                        ].join(' | '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: entry.$2.isRead
                          ? const Icon(Icons.chevron_right)
                          : IconButton(
                              tooltip: strings.text('Mark read'),
                              onPressed: acting
                                  ? null
                                  : () => markOneRead(entry.$2),
                              icon: const Icon(Icons.done),
                            ),
                    ),
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
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          MediaQuery.paddingOf(context).bottom + 92,
        ),
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
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          MediaQuery.paddingOf(context).bottom + 92,
        ),
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
