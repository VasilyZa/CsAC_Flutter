part of '../../main.dart';

class NoticeCenterScreen extends StatefulWidget {
  const NoticeCenterScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<NoticeCenterScreen> createState() => _NoticeCenterScreenState();
}

class _NoticeCenterScreenState extends State<NoticeCenterScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChanged);
    // 进入通知中心时，清除当前默认 tab 的红点
    _clearBadgeForTab(_selectedIndex);
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _clearBadgeForTab(int tabIndex) {
    switch (tabIndex) {
      case 0:
        widget.state.dismissBadges({'notices'});
        widget.state.updateNotificationCounts(notices: 0);
        break;
      case 1:
        widget.state.dismissBadges({'mentions', 'replies'});
        widget.state.updateNotificationCounts(mentions: 0, replies: 0);
        break;
      case 3:
        widget.state.dismissBadges({'friendRequests'});
        widget.state.updateNotificationCounts(friendRequests: 0);
        break;
      case 4:
        widget.state.dismissBadges({'groupApplications'});
        widget.state.updateNotificationCounts(groupApplications: 0);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = widget.state.notificationCounts;
    final strings = context.strings;
    final colors = CsacColors.of(context);

    return CupertinoPageScaffold(
      backgroundColor: colors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(strings.text('Notices')),
        backgroundColor: colors.navBarBackground,
        border: null,
        trailing: GestureDetector(
          onTap: widget.state.refreshNotificationCounts,
          child: Icon(CupertinoIcons.refresh, size: 20, color: colors.primaryColor),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── 滚动式胶囊 Tab 选择器 ──
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                children: [
                  _NoticeTab(
                    icon: CupertinoIcons.bell,
                    label: strings.text('Notices'),
                    badge: counts.notices,
                    selected: _selectedIndex == 0,
                    onTap: () { setState(() => _selectedIndex = 0); _clearBadgeForTab(0); },
                  ),
                  _NoticeTab(
                    icon: CupertinoIcons.at,
                    label: strings.text('Mentions'),
                    badge: counts.mentions + counts.replies,
                    selected: _selectedIndex == 1,
                    onTap: () { setState(() => _selectedIndex = 1); _clearBadgeForTab(1); },
                  ),
                  _NoticeTab(
                    icon: CupertinoIcons.person_badge_minus,
                    label: strings.text('Friend changes'),
                    badge: 0,
                    selected: _selectedIndex == 2,
                    onTap: () { setState(() => _selectedIndex = 2); _clearBadgeForTab(2); },
                  ),
                  _NoticeTab(
                    icon: CupertinoIcons.person_badge_plus,
                    label: strings.text('Friends'),
                    badge: counts.friendRequests,
                    selected: _selectedIndex == 3,
                    onTap: () { setState(() => _selectedIndex = 3); _clearBadgeForTab(3); },
                  ),
                  _NoticeTab(
                    icon: CupertinoIcons.group,
                    label: strings.text('Groups'),
                    badge: counts.groupApplications,
                    selected: _selectedIndex == 4,
                    onTap: () { setState(() => _selectedIndex = 4); _clearBadgeForTab(4); },
                  ),
                ],
              ),
            ),
            // ── 分隔线 ──
            Container(height: 0.5, color: colors.separator),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  NoticesPage(state: widget.state),
                  MentionsPage(state: widget.state),
                  FriendDeletedNoticesPage(state: widget.state),
                  FriendRequestsPage(state: widget.state),
                  GroupApplicationsPage(state: widget.state),
                ],
              ),
            ),
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
    final colors = CsacColors.of(context);
    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: load),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CupertinoActivityIndicator()),
                ),
              if (error != null) _InlineError(message: error!, onRetry: load),
              if (!loading && notices.isEmpty)
                _EmptyPanel(message: strings.text('No friend changes.'))
              else
                for (final notice in notices)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _CupertinoListTile(
                      leading: const Icon(
                        CupertinoIcons.person_badge_minus,
                        size: 24,
                      ),
                      title: notice.nickname,
                      subtitle: [
                        if (notice.time.isNotEmpty) notice.time,
                        if (notice.content.isNotEmpty) notice.content,
                        if (notice.uid > 0) 'UID ${notice.uid}',
                      ].join(' | '),
                    ),
                  ),
            ]),
          ),
        ),
      ],
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
    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: load),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CupertinoActivityIndicator()),
                ),
              if (error != null) _InlineError(message: error!, onRetry: load),
              _CupertinoGroupedCard(
                margin: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.at, size: 22),
                    title: strings.text('Mentioned me'),
                    subtitle: strings.format('{count} unread', {
                      'count': counts.mentions,
                    }),
                  ),
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.reply, size: 22),
                    title: strings.text('Replied to me'),
                    subtitle: strings.format('{count} unread', {
                      'count': counts.replies,
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CupertinoGroupedCard(
                margin: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.info, size: 22),
                    title: strings.text('Mention list unavailable'),
                    subtitle:
                        strings.text('Open related chats from the chat list.'),
                  ),
                ],
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

// ── 通知页胶囊 Tab 按钮 ──────────────────────────────────────────────────────

class _NoticeTab extends StatelessWidget {
  const _NoticeTab({
    required this.icon,
    required this.label,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        decoration: BoxDecoration(
          color: selected ? primary : colors.tertiaryFill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? CupertinoColors.white : colors.secondaryLabel,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? CupertinoColors.white : colors.secondaryLabel,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? CupertinoColors.white.withValues(alpha: 0.3)
                      : CupertinoColors.systemRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? CupertinoColors.white : CupertinoColors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
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
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(notice.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (notice.time.isNotEmpty)
                Text(
                  notice.time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              if (notice.time.isNotEmpty) const SizedBox(height: 12),
              Text(
                notice.content.isEmpty
                    ? strings.text('(empty)')
                    : notice.content,
                textAlign: TextAlign.left,
              ),
              if (notice.link.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  notice.link,
                  style: const TextStyle(
                    color: CupertinoColors.activeBlue,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (notice.link.isNotEmpty)
            CupertinoDialogAction(
              onPressed: () => launchUrl(
                Uri.parse(notice.link),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(strings.text('Open')),
            ),
          CupertinoDialogAction(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(
                  text:
                      '${notice.title}\n${notice.time}\n\n${notice.content}\n${notice.link}',
                ),
              );
              Navigator.of(context).pop();
              _showCupertinoToast(context, strings.text('Notice copied'));
            },
            child: Text(strings.text('Copy')),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
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
    final colors = CsacColors.of(context);
    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: load),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.format('{count} unread', {
                        'count':
                            notices.where((notice) => !notice.isRead).length,
                      }),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colors.label,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: acting || notices.isEmpty ? null : markAllRead,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.checkmark_seal,
                            size: 14,
                            color: CupertinoTheme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            strings.text('Mark all read'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: CupertinoTheme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CupertinoActivityIndicator()),
                ),
              if (error != null) _InlineError(message: error!, onRetry: load),
              if (!loading && notices.isEmpty)
                _EmptyPanel(message: strings.text('No notices.'))
              else
                for (final notice in notices)
                  GestureDetector(
                    onTap: () => openNotice(notice),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      decoration: BoxDecoration(
                        color: colors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              notice.isRead
                                  ? CupertinoIcons.envelope_open
                                  : CupertinoIcons.envelope_badge,
                              size: 24,
                              color: notice.isRead
                                  ? colors.secondaryLabel
                                  : colors.primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notice.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: notice.isRead
                                          ? FontWeight.w500
                                          : FontWeight.w700,
                                      color: colors.label,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [
                                      if (notice.time.isNotEmpty) notice.time,
                                      notice.content.replaceAll('\n', ' '),
                                    ].join(' | '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colors.secondaryLabel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (notice.isRead)
                              Icon(
                                CupertinoIcons.chevron_right,
                                size: 16,
                                color: colors.tertiaryLabel,
                              )
                            else
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                minSize: 28,
                                onPressed:
                                    acting ? null : () => markOneRead(notice),
                                child: const Icon(
                                  CupertinoIcons.checkmark_circle,
                                  size: 22,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
            ]),
          ),
        ),
      ],
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
    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: load),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CupertinoActivityIndicator()),
                ),
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
            ]),
          ),
        ),
      ],
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
    final colors = CsacColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpenUser,
              child: Row(
                children: [
                  _Avatar(
                    url: request.avatar,
                    fallback: CupertinoIcons.person_solid,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.nickname,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.label,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (request.username.isNotEmpty)
                              '@${request.username}',
                            'UID ${request.fromUid}',
                            if (request.createTime.isNotEmpty)
                              request.createTime,
                          ].join(' | '),
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.secondaryLabel,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(pending: request.pending),
                  const SizedBox(width: 4),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: colors.tertiaryLabel,
                  ),
                ],
              ),
            ),
            if (request.content.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                request.content,
                style: TextStyle(fontSize: 14, color: colors.label),
              ),
            ],
            if (request.pending) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: acting ? null : onRefuse,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: CupertinoColors.destructiveRed.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        strings.text('Refuse'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: CupertinoColors.destructiveRed,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: acting ? null : onAgree,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: acting
                            ? CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.5)
                            : CupertinoTheme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: acting
                          ? const CupertinoActivityIndicator(
                              radius: 8,
                              color: CupertinoColors.white,
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  CupertinoIcons.checkmark_alt,
                                  size: 14,
                                  color: CupertinoColors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  strings.text('Agree'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
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
    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: load),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CupertinoActivityIndicator()),
                ),
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
            ]),
          ),
        ),
      ],
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
    final colors = CsacColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpenUser,
              child: Row(
                children: [
                  _Avatar(
                    url: application.avatar,
                    fallback: CupertinoIcons.person_solid,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          application.nickname,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colors.label,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (application.username.isNotEmpty)
                              '@${application.username}',
                            'UID ${application.uid}',
                            if (application.roomName.isNotEmpty)
                              strings.format('Group: {name}', {
                                'name': application.roomName,
                              }),
                            if (application.createTime.isNotEmpty)
                              application.createTime,
                          ].join(' | '),
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.secondaryLabel,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(pending: application.pending),
                  const SizedBox(width: 4),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: colors.tertiaryLabel,
                  ),
                ],
              ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(fontSize: 14, color: colors.label),
              ),
            ],
            if (application.pending) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: acting ? null : onRefuse,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: CupertinoColors.destructiveRed.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        strings.text('Refuse'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: CupertinoColors.destructiveRed,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: acting ? null : onPass,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: acting
                            ? CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.5)
                            : CupertinoTheme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: acting
                          ? const CupertinoActivityIndicator(
                              radius: 8,
                              color: CupertinoColors.white,
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  CupertinoIcons.checkmark_alt,
                                  size: 14,
                                  color: CupertinoColors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  strings.text('Pass'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: CupertinoColors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
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
