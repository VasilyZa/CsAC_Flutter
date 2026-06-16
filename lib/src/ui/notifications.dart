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
    widget.state.addListener(_handleStateChanged);
  }

  @override
  void dispose() {
    widget.state.removeListener(_handleStateChanged);
    super.dispose();
  }

  void _handleStateChanged() {
    if (mounted) {
      setState(() {});
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
        trailing: CupertinoButton(
          padding: const EdgeInsets.all(6),
          minimumSize: Size.zero,
          onPressed: widget.state.refreshNotificationCounts,
          child: Icon(
            CupertinoIcons.refresh,
            size: 20,
            color: colors.primaryColor,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    ui.PointerDeviceKind.touch,
                    ui.PointerDeviceKind.mouse,
                    ui.PointerDeviceKind.stylus,
                    ui.PointerDeviceKind.invertedStylus,
                    ui.PointerDeviceKind.unknown,
                  },
                ),
                child: CsacListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  children: [
                    _NoticeSegment(
                      icon: CupertinoIcons.bell,
                      label: strings.text('Notices'),
                      badge: counts.notices,
                      selected: _selectedIndex == 0,
                      onTap: () => setState(() => _selectedIndex = 0),
                    ),
                    const SizedBox(width: 8),
                    _NoticeSegment(
                      icon: CupertinoIcons.at,
                      label: strings.text('Mentions'),
                      badge: counts.mentions + counts.replies,
                      selected: _selectedIndex == 1,
                      onTap: () => setState(() => _selectedIndex = 1),
                    ),
                    const SizedBox(width: 8),
                    _NoticeSegment(
                      icon: CupertinoIcons.person_badge_minus,
                      label: strings.text('Friend changes'),
                      badge: counts.friendChanges,
                      selected: _selectedIndex == 2,
                      onTap: () => setState(() => _selectedIndex = 2),
                    ),
                    const SizedBox(width: 8),
                    _NoticeSegment(
                      icon: CupertinoIcons.person_badge_plus,
                      label: strings.text('Friends'),
                      badge: counts.friendRequests,
                      selected: _selectedIndex == 3,
                      onTap: () => setState(() => _selectedIndex = 3),
                    ),
                    const SizedBox(width: 8),
                    _NoticeSegment(
                      icon: CupertinoIcons.group,
                      label: strings.text('Groups'),
                      badge: counts.groupApplications,
                      selected: _selectedIndex == 4,
                      onTap: () => setState(() => _selectedIndex = 4),
                    ),
                  ],
                ),
              ),
            ),
            Container(height: 0.5, color: colors.separator),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  NoticesPage(state: widget.state),
                  MentionNoticesPage(state: widget.state),
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

class _NoticeSegment extends StatelessWidget {
  const _NoticeSegment({
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
    return _CsacPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 160.ms,
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: colors.isDark ? 0.22 : 0.13)
              : colors.cardBackground,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? primary.withValues(alpha: 0.24)
                : colors.separator.withValues(alpha: 0.24),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? primary : colors.secondaryLabel,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? primary : colors.label,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 5),
              _NoticeBadge(count: badge, color: CupertinoColors.systemRed),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoticeBadge extends StatelessWidget {
  const _NoticeBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: CupertinoColors.white,
        ),
      ),
    );
  }
}

class _NoticePageHeader extends StatelessWidget {
  const _NoticePageHeader({
    required this.title,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.label,
              ),
            ),
          ),
          if (actionLabel != null && actionIcon != null)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              borderRadius: BorderRadius.circular(999),
              color: colors.tertiaryFill,
              disabledColor: colors.tertiaryFill.withValues(alpha: 0.55),
              onPressed: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(actionIcon, size: 14, color: colors.primaryColor),
                  const SizedBox(width: 5),
                  Text(
                    actionLabel!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NoticeListSection extends StatelessWidget {
  const _NoticeListSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 14),
      backgroundColor: const Color(0x00000000),
      children: children,
    );
  }
}

class _NoticeLeadingIcon extends StatelessWidget {
  const _NoticeLeadingIcon({
    required this.icon,
    this.accent,
    this.unread = false,
  });

  final IconData icon;
  final Color? accent;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final tint = accent ?? colors.secondaryLabel;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: unread ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: tint),
    );
  }
}

class _NoticeChevron extends StatelessWidget {
  const _NoticeChevron();

  @override
  Widget build(BuildContext context) {
    return Icon(
      CupertinoIcons.chevron_right,
      size: 14,
      color: CsacColors.of(context).tertiaryLabel,
    );
  }
}

class _NoticeMarkReadButton extends StatelessWidget {
  const _NoticeMarkReadButton({required this.onPressed, required this.acting});

  final VoidCallback? onPressed;
  final bool acting;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    if (onPressed == null) {
      return const _NoticeChevron();
    }
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size.square(30),
      borderRadius: BorderRadius.circular(15),
      onPressed: acting ? null : onPressed,
      child: acting
          ? CupertinoActivityIndicator(radius: 8, color: colors.primaryColor)
          : Icon(
              CupertinoIcons.checkmark_circle,
              size: 22,
              color: colors.primaryColor,
            ),
    );
  }
}

class _NoticeActionPill extends StatelessWidget {
  const _NoticeActionPill({
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final accent = primary
        ? colors.primaryColor
        : CupertinoColors.destructiveRed.resolveFrom(context);
    final foreground = primary ? CupertinoColors.white : accent;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: loading ? null : onPressed,
      child: Container(
        constraints: const BoxConstraints(minHeight: 34),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: primary
              ? accent.withValues(alpha: loading ? 0.55 : 1)
              : accent.withValues(alpha: colors.isDark ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(17),
        ),
        child: loading
            ? CupertinoActivityIndicator(radius: 8, color: foreground)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 14, color: foreground),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ],
              ),
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
      final loaded = await widget.state.loadVisibleMentionNotices();
      if (!mounted) {
        return;
      }
      setState(() => bundle = loaded);
      widget.state.updateNotificationCounts(
        mentions: loaded.mentionCount,
        replies: loaded.replyCount,
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
      await widget.state.markMentionSummaryRead();
      if (!mounted) {
        return;
      }
      setState(() {
        bundle = bundle.copyWith(
          items: [for (final item in bundle.items) item.copyWith(isRead: true)],
          mentionCount: 0,
          replyCount: 0,
        );
      });
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

  Future<void> markOneRead(MentionNotice notice) async {
    setState(() => acting = true);
    try {
      await widget.state.markMentionNoticeRead(notice);
      if (!mounted) {
        return;
      }
      setState(() {
        final items = [
          for (final item in bundle.items)
            MentionNoticeStore.readKey(item) ==
                    MentionNoticeStore.readKey(notice)
                ? item.copyWith(isRead: true)
                : item,
        ];
        final unread = items.where((item) => !item.isRead);
        bundle = bundle.copyWith(
          items: items,
          mentionCount: unread.where((item) => !item.isReply).length,
          replyCount: unread.where((item) => item.isReply).length,
        );
      });
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

  Future<void> clearOne(MentionNotice notice) async {
    setState(() => acting = true);
    try {
      await widget.state.clearMentionNotice(notice);
      if (!mounted) {
        return;
      }
      final clearedKey = MentionNoticeStore.clearedKey(notice);
      setState(() {
        final items = [
          for (final item in bundle.items)
            if (MentionNoticeStore.clearedKey(item) != clearedKey) item,
        ];
        final unread = items.where((item) => !item.isRead);
        bundle = bundle.copyWith(
          items: items,
          mentionCount: unread.where((item) => !item.isReply).length,
          replyCount: unread.where((item) => item.isReply).length,
        );
      });
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

  Future<void> clearSummary() async {
    setState(() => acting = true);
    try {
      await widget.state.clearMentionSummary();
      if (mounted) {
        setState(() => bundle = const MentionNoticeBundle(items: []));
      }
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

  Future<void> openMention(MentionNotice notice) async {
    if (!notice.isRead) {
      await markOneRead(notice);
    }
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      CsacPageRoute<void>(
        builder: (_) => ChatScreen(
          state: widget.state,
          conversation: notice.conversation,
          focusMessageId: notice.message.id > 0 ? notice.message.id : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final unreadCount = bundle.mentionCount + bundle.replyCount;
    return CsacCustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: load),
        SliverList.list(
          children: [
            _NoticePageHeader(
              title: strings.format('{count} unread mentions or replies', {
                'count': unreadCount,
              }),
              actionLabel: strings.text('Mark all read'),
              actionIcon: CupertinoIcons.checkmark_seal,
              onAction: acting || unreadCount <= 0 ? null : markAllRead,
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CupertinoActivityIndicator()),
              ),
            if (error != null) _InlineError(message: error!, onRetry: load),
            if (!loading && bundle.items.isEmpty)
              if (unreadCount > 0)
                _MentionSummaryCard(bundle: bundle, onClear: clearSummary)
              else
                _EmptyPanel(message: strings.text('No mentions or replies.')),
            if (!loading && bundle.items.isNotEmpty)
              _NoticeListSection(
                children: [
                  for (final notice in bundle.items)
                    _MentionNoticeTile(
                      notice: notice,
                      acting: acting,
                      onTap: () => openMention(notice),
                      onMarkRead: notice.isRead
                          ? null
                          : () => markOneRead(notice),
                      onClear: () => clearOne(notice),
                    ),
                ],
              ),
            const SizedBox(height: 24),
          ],
        ),
      ],
    );
  }
}

class _MentionSummaryCard extends StatelessWidget {
  const _MentionSummaryCard({required this.bundle, required this.onClear});

  final MentionNoticeBundle bundle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return _NoticeListSection(
      children: [
        CupertinoListTile(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: _NoticeLeadingIcon(
            icon: CupertinoIcons.at,
            accent: colors.primaryColor,
            unread: true,
          ),
          title: Text(
            strings.text('Mention list unavailable'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.label,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  strings.format('@ me: {count}', {
                    'count': bundle.mentionCount,
                  }),
                  strings.format('Replies: {count}', {
                    'count': bundle.replyCount,
                  }),
                ].join(' | '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.secondaryLabel, fontSize: 13),
              ),
              const SizedBox(height: 3),
              Text(
                strings.text(
                  'The server returned counts only, so there is no message position to open yet.',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.secondaryLabel, fontSize: 13),
              ),
            ],
          ),
          trailing: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(30),
            borderRadius: BorderRadius.circular(15),
            onPressed: onClear,
            child: Icon(
              CupertinoIcons.clear_circled,
              size: 22,
              color: CupertinoColors.destructiveRed.resolveFrom(context),
            ),
          ),
        ),
      ],
    );
  }
}

class _MentionNoticeTile extends StatelessWidget {
  const _MentionNoticeTile({
    required this.notice,
    required this.acting,
    required this.onTap,
    this.onMarkRead,
    required this.onClear,
  });

  final MentionNotice notice;
  final bool acting;
  final VoidCallback onTap;
  final VoidCallback? onMarkRead;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final text = compactMessage(chatMessagePlainText(notice.message, strings));
    return CupertinoListTile(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leading: _NoticeLeadingIcon(
        icon: notice.isReply ? CupertinoIcons.reply : CupertinoIcons.at,
        accent: notice.isRead ? colors.secondaryLabel : colors.primaryColor,
        unread: !notice.isRead,
      ),
      title: Text(
        strings.text(notice.displayTitle),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 16,
          fontWeight: notice.isRead ? FontWeight.w500 : FontWeight.w700,
          color: colors.label,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              notice.conversation.name,
              if (notice.message.sender.isNotEmpty) notice.message.sender,
              if (notice.message.time.isNotEmpty) notice.message.time,
            ].join(' | '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: colors.secondaryLabel),
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: colors.label),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NoticeMarkReadButton(onPressed: onMarkRead, acting: acting),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(30),
            borderRadius: BorderRadius.circular(15),
            onPressed: acting ? null : onClear,
            child: Icon(
              CupertinoIcons.clear_circled,
              size: 22,
              color: CupertinoColors.destructiveRed.resolveFrom(context),
            ),
          ),
        ],
      ),
      onTap: onTap,
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
  List<FriendChangeNotice> notices = const <FriendChangeNotice>[];
  bool loading = true;
  bool acting = false;
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

  Future<void> markAllRead() async {
    setState(() => acting = true);
    try {
      await widget.state.markFriendChangeRead(readAll: true);
      if (!mounted) return;
      setState(() {
        notices = [for (final notice in notices) notice.copyWith(isRead: true)];
      });
      widget.state.updateNotificationCounts(friendChanges: 0);
    } catch (err) {
      if (mounted) setState(() => error = err.toString());
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  Future<void> markOneRead(FriendChangeNotice notice) async {
    setState(() => actingId = notice.uid);
    try {
      await widget.state.markFriendChangeRead(friendId: notice.uid);
      if (!mounted) return;
      setState(() {
        notices = [
          for (final item in notices)
            item.uid == notice.uid ? item.copyWith(isRead: true) : item,
        ];
      });
      widget.state.updateNotificationCounts(
        friendChanges: notices.where((notice) => !notice.isRead).length,
      );
    } catch (err) {
      if (mounted) setState(() => error = err.toString());
    } finally {
      if (mounted) setState(() => actingId = null);
    }
  }

  String noticeSummary(BuildContext context, FriendChangeNotice notice) {
    final strings = context.strings;
    if (notice.deletedByMe) {
      return strings.text('You removed this friend.');
    }
    if (notice.deletedByFriend) {
      return strings.text('This friend removed you.');
    }
    return strings.text('Friend relationship changed.');
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final unreadCount = notices.where((notice) => !notice.isRead).length;
    return CsacCustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: load),
        SliverList.list(
          children: [
            _NoticePageHeader(
              title: strings.format('{count} unread', {'count': unreadCount}),
              actionLabel: strings.text('Mark all read'),
              actionIcon: CupertinoIcons.checkmark_seal,
              onAction: acting || unreadCount <= 0 ? null : markAllRead,
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CupertinoActivityIndicator()),
              ),
            if (error != null) _InlineError(message: error!, onRetry: load),
            if (!loading && notices.isEmpty)
              _EmptyPanel(message: strings.text('No friend changes.')),
            if (!loading && notices.isNotEmpty)
              _NoticeListSection(
                children: [
                  for (final notice in notices)
                    _FriendChangeTile(
                      notice: notice,
                      summary: noticeSummary(context, notice),
                      acting: actingId == notice.uid,
                      onMarkRead: notice.isRead
                          ? null
                          : () => markOneRead(notice),
                      onOpenUser: notice.uid > 0
                          ? () => openUserProfile(
                              context,
                              widget.state,
                              notice.uid,
                            )
                          : null,
                    ),
                ],
              ),
            const SizedBox(height: 24),
          ],
        ),
      ],
    );
  }
}

class _FriendChangeTile extends StatelessWidget {
  const _FriendChangeTile({
    required this.notice,
    required this.summary,
    required this.acting,
    this.onMarkRead,
    this.onOpenUser,
  });

  final FriendChangeNotice notice;
  final String summary;
  final bool acting;
  final VoidCallback? onMarkRead;
  final VoidCallback? onOpenUser;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final subtitle = [
      if (notice.username.isNotEmpty) '@${notice.username}',
      if (notice.uid > 0) 'UID ${notice.uid}',
      summary,
      if (notice.time.isNotEmpty) notice.time,
    ].join(' | ');
    final content = notice.content.trim();
    return CupertinoListTile(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      leading: _Avatar(
        url: notice.avatar,
        fallback: CupertinoIcons.person_solid,
        name: notice.displayName,
        radius: 20,
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              notice.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.label,
                fontSize: 16,
                fontWeight: notice.isRead ? FontWeight.w500 : FontWeight.w700,
              ),
            ),
          ),
          if (notice.isBot) ...[
            const SizedBox(width: 6),
            const _BotBadge(compact: true),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: colors.secondaryLabel),
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: colors.label),
            ),
          ],
        ],
      ),
      trailing: _NoticeMarkReadButton(onPressed: onMarkRead, acting: acting),
      onTap: onOpenUser,
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
      if (!mounted) {
        return;
      }
      setState(() {
        notices = [for (final notice in notices) notice.copyWith(isRead: true)];
      });
      widget.state.updateNotificationCounts(notices: 0);
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
      if (!mounted) {
        return;
      }
      setState(() {
        notices = [
          for (final item in notices)
            item.id == notice.id ? item.copyWith(isRead: true) : item,
        ];
      });
      widget.state.updateNotificationCounts(
        notices: notices.where((notice) => !notice.isRead).length,
      );
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
    final pageContext = context;
    final strings = context.strings;
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(notice.title),
        content: CsacSingleChildScrollView(
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
              Navigator.of(dialogContext).pop();
              CsacToastMessenger.of(pageContext).showToast(
                CsacToast(content: Text(strings.text('Notice copied'))),
              );
            },
            child: Text(strings.text('Copy')),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
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
    final unreadCount = notices.where((notice) => !notice.isRead).length;
    return CsacCustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: load),
        SliverList.list(
          children: [
            _NoticePageHeader(
              title: strings.format('{count} unread', {'count': unreadCount}),
              actionLabel: strings.text('Mark all read'),
              actionIcon: CupertinoIcons.checkmark_seal,
              onAction: acting || unreadCount <= 0 ? null : markAllRead,
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CupertinoActivityIndicator()),
              ),
            if (error != null) _InlineError(message: error!, onRetry: load),
            if (!loading && notices.isEmpty)
              _EmptyPanel(message: strings.text('No notices.')),
            if (!loading && notices.isNotEmpty)
              _NoticeListSection(
                children: [
                  for (final notice in notices)
                    CupertinoListTile(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      leading: _NoticeLeadingIcon(
                        icon: notice.isRead
                            ? CupertinoIcons.envelope_open
                            : CupertinoIcons.envelope_badge,
                        accent: notice.isRead
                            ? colors.secondaryLabel
                            : colors.primaryColor,
                        unread: !notice.isRead,
                      ),
                      title: Text(
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
                      subtitle: Text(
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
                      trailing: _NoticeMarkReadButton(
                        onPressed: notice.isRead
                            ? null
                            : () => markOneRead(notice),
                        acting: acting,
                      ),
                      onTap: () => openNotice(notice),
                    ),
                ],
              ),
            const SizedBox(height: 24),
          ],
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
    return CsacCustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: load),
        SliverList.list(
          children: [
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CupertinoActivityIndicator()),
              ),
            if (error != null) _InlineError(message: error!, onRetry: load),
            if (!loading && requests.isEmpty)
              _EmptyPanel(message: strings.text('No friend requests.')),
            if (!loading && requests.isNotEmpty)
              _NoticeListSection(
                children: [
                  for (final request in requests)
                    _FriendRequestTile(
                      request: request,
                      acting: actingId == request.id,
                      onOpenUser: () => openUserProfile(
                        context,
                        widget.state,
                        request.fromUid,
                      ),
                      onAgree: request.pending
                          ? () => handle(request, 'agree')
                          : null,
                      onRefuse: request.pending
                          ? () => handle(request, 'refuse')
                          : null,
                    ),
                ],
              ),
            const SizedBox(height: 24),
          ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CupertinoListTile(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
          leading: _Avatar(
            url: request.avatar,
            fallback: CupertinoIcons.person_solid,
            name: request.nickname,
            radius: 20,
          ),
          title: Text(
            request.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.label,
            ),
          ),
          subtitle: Text(
            [
              if (request.username.isNotEmpty) '@${request.username}',
              'UID ${request.fromUid}',
              if (request.createTime.isNotEmpty) request.createTime,
            ].join(' | '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: colors.secondaryLabel),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusChip(pending: request.pending),
              const SizedBox(width: 4),
              const _NoticeChevron(),
            ],
          ),
          onTap: onOpenUser,
        ),
        if (request.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              request.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: colors.label),
            ),
          ),
        if (request.pending)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _NoticeActionPill(
                  label: strings.text('Refuse'),
                  onPressed: onRefuse,
                  loading: false,
                ),
                const SizedBox(width: 8),
                _NoticeActionPill(
                  label: strings.text('Agree'),
                  icon: CupertinoIcons.checkmark_alt,
                  primary: true,
                  onPressed: onAgree,
                  loading: acting,
                ),
              ],
            ),
          ),
      ],
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
    return CsacCustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: load),
        SliverList.list(
          children: [
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CupertinoActivityIndicator()),
              ),
            if (error != null) _InlineError(message: error!, onRetry: load),
            if (!loading && applications.isEmpty)
              _EmptyPanel(message: strings.text('No group applications.')),
            if (!loading && applications.isNotEmpty)
              _NoticeListSection(
                children: [
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
            const SizedBox(height: 24),
          ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CupertinoListTile(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
          leading: _Avatar(
            url: application.avatar,
            fallback: CupertinoIcons.person_solid,
            name: application.nickname,
            radius: 20,
          ),
          title: Text(
            application.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colors.label,
            ),
          ),
          subtitle: Text(
            [
              if (application.username.isNotEmpty) '@${application.username}',
              'UID ${application.uid}',
              if (application.roomName.isNotEmpty)
                strings.format('Group: {name}', {'name': application.roomName}),
              if (application.createTime.isNotEmpty) application.createTime,
            ].join(' | '),
            style: TextStyle(fontSize: 13, color: colors.secondaryLabel),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusChip(pending: application.pending),
              const SizedBox(width: 4),
              const _NoticeChevron(),
            ],
          ),
          onTap: onOpenUser,
        ),
        if (message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: colors.label),
            ),
          ),
        if (application.pending)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _NoticeActionPill(
                  label: strings.text('Refuse'),
                  onPressed: onRefuse,
                ),
                const SizedBox(width: 8),
                _NoticeActionPill(
                  label: strings.text('Pass'),
                  icon: CupertinoIcons.checkmark_alt,
                  primary: true,
                  onPressed: onPass,
                  loading: acting,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
