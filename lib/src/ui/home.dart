part of '../../main.dart';

// ============================================================================
// MainShell — root shell with timer, state listener, wide/narrow layout
// ============================================================================

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.state});

  final CsacAppState state;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  int lastUnreadChats = 0;
  Conversation? selectedConversation;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    lastUnreadChats = totalUnreadChats();
    widget.state.addListener(_onStateChanged);
    timer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => refreshHomeWithHint(),
    );
  }

  int totalUnreadChats() {
    return widget.state.conversations.fold<int>(
      0,
      (total, conversation) => total + conversation.unreadCount,
    );
  }

  Future<void> refreshHomeWithHint() async {
    final strings = context.strings;
    final beforeUnread = {
      for (final conversation in widget.state.conversations)
        _conversationKey(conversation): conversation.unreadCount,
    };
    try {
      await widget.state.refreshHome();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final currentConversation =
        selectedConversation ?? widget.state.activeConversation;
    if (currentConversation != null) {
      final selected = currentConversation;
      final latestSelected = widget.state.conversations
          .where(
            (conversation) =>
                conversation.type == selected.type &&
                conversation.id == selected.id,
          )
          .firstOrNull;
      if (latestSelected != null) {
        if (selectedConversation != null) {
          selectedConversation = latestSelected.copyWith(unreadCount: 0);
        }
        await widget.state.markConversationRead(
          latestSelected,
          syncServer: false,
        );
      }
    }
    final after = totalUnreadChats();
    if (after > lastUnreadChats) {
      final message = strings.format('New messages: {count}', {
        'count': after - lastUnreadChats,
      });
      if (mounted) {
        _showCupertinoToast(context, message);
      }
    }
    await showSystemNotifications(beforeUnread);
    lastUnreadChats = after;
  }

  Future<void> showSystemNotifications(Map<String, int> beforeUnread) async {
    for (final conversation in widget.state.conversations) {
      if (widget.state.isConversationMuted(conversation) ||
          widget.state.isActiveConversation(conversation)) {
        continue;
      }
      final before = beforeUnread[_conversationKey(conversation)] ?? 0;
      final delta = conversation.unreadCount - before;
      if (delta <= 0) continue;
      await widget.state.notifications.showMessageNotification(
        conversation: conversation,
        unreadDelta: delta,
      );
    }
  }

  String _conversationKey(Conversation conversation) {
    return '${conversation.type.name}:${conversation.id}';
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    timer?.cancel();
    widget.state.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onTabTap(int value) {
    setState(() => index = value);
    if (value == 0) widget.state.loadConversations();
    if (value == 2) widget.state.refreshNotificationCounts();
  }

  @override
  Widget build(BuildContext context) {
    final unreadChats = totalUnreadChats();
    final noticeCount = widget.state.notificationCounts.total;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final strings = context.strings;
    final colors = CsacColors.of(context);

    final pages = <Widget>[
      ConversationScreen(
        state: widget.state,
        embedded: true,
        selectedConversation: selectedConversation,
        onConversationSelected: wide
            ? (conversation) {
                widget.state.markConversationRead(conversation);
                widget.state.setActiveConversation(conversation);
                setState(
                  () => selectedConversation = conversation.copyWith(
                    unreadCount: 0,
                  ),
                );
                lastUnreadChats = totalUnreadChats();
              }
            : null,
      ),
      MessageSearchScreen(state: widget.state, embedded: true),
      NoticeCenterScreen(state: widget.state),
      ProfileScreen(state: widget.state),
    ];

    // ── Wide layout: frosted glass sidebar ──────────────────────────────────
    if (wide) {
      return CupertinoPageScaffold(
        child: SafeArea(
          child: Row(
            children: [
              _WideSidebar(
                selectedIndex: index,
                unreadChats: unreadChats,
                noticeCount: noticeCount,
                onDestinationSelected: _onTabTap,
              ),
              Container(width: 0.5, color: colors.separator),
              Expanded(
                child: index == 0
                    ? _WideChatLayout(
                        state: widget.state,
                        conversations: pages[0],
                        selectedConversation: selectedConversation,
                      )
                    : pages[index],
              ),
            ],
          ),
        ),
      );
    }

    // ── Narrow layout: floating capsule tab bar ──────────────────────────────
    final tabItems = [
      _FloatingTabItem(
        icon: CupertinoIcons.chat_bubble,
        activeIcon: CupertinoIcons.chat_bubble_fill,
        label: strings.text('Chats'),
        badge: unreadChats,
      ),
      _FloatingTabItem(
        icon: CupertinoIcons.search,
        activeIcon: CupertinoIcons.search,
        label: strings.text('Search'),
      ),
      _FloatingTabItem(
        icon: CupertinoIcons.bell,
        activeIcon: CupertinoIcons.bell_fill,
        label: strings.text('Notices'),
        badge: noticeCount,
      ),
      _FloatingTabItem(
        icon: CupertinoIcons.person,
        activeIcon: CupertinoIcons.person_fill,
        label: strings.text('Me'),
      ),
    ];

    return CupertinoPageScaffold(
      backgroundColor: colors.systemBackground,
      child: Stack(
        children: [
          // Page content — bottom padding accounts for tab bar + safe area
          IndexedStack(
            index: index,
            children: pages,
          ),
          // Floating tab bar overlaid at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom,
            child: _FloatingTabBar(
              selectedIndex: index,
              items: tabItems,
              onTap: _onTabTap,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Wide sidebar — 72px frosted glass with icon + label per tab
// ============================================================================

class _WideSidebar extends StatelessWidget {
  const _WideSidebar({
    required this.selectedIndex,
    required this.unreadChats,
    required this.noticeCount,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final int unreadChats;
  final int noticeCount;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    final strings = context.strings;

    final items = [
      _SidebarItem(
        icon: CupertinoIcons.chat_bubble,
        activeIcon: CupertinoIcons.chat_bubble_fill,
        label: strings.text('Chats'),
        badge: unreadChats,
      ),
      _SidebarItem(
        icon: CupertinoIcons.search,
        activeIcon: CupertinoIcons.search,
        label: strings.text('Search'),
        badge: 0,
      ),
      _SidebarItem(
        icon: CupertinoIcons.bell,
        activeIcon: CupertinoIcons.bell_fill,
        label: strings.text('Notices'),
        badge: noticeCount,
      ),
      _SidebarItem(
        icon: CupertinoIcons.person,
        activeIcon: CupertinoIcons.person_fill,
        label: strings.text('Me'),
        badge: 0,
      ),
    ];

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 72,
          color: colors.cardBackground.withValues(alpha: 0.85),
          child: Column(
            children: [
              // App logo
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 16),
                child: Icon(
                  CupertinoIcons.chat_bubble_2_fill,
                  color: primary,
                  size: 26,
                ),
              ),
              // Nav items
              ...List.generate(items.length, (i) {
                final item = items[i];
                final selected = i == selectedIndex;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onDestinationSelected(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    width: 72,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BadgeIcon(
                          icon: selected ? item.activeIcon : item.icon,
                          count: item.badge,
                          color: selected ? primary : colors.secondaryLabel,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: selected ? primary : colors.secondaryLabel,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItem {
  const _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.badge,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
}

// ============================================================================
// Wide chat layout — conversation list + chat panel side by side
// ============================================================================

class _WideChatLayout extends StatelessWidget {
  const _WideChatLayout({
    required this.state,
    required this.conversations,
    required this.selectedConversation,
  });

  final CsacAppState state;
  final Widget conversations;
  final Conversation? selectedConversation;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final selected = selectedConversation;
    return Row(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 320, maxWidth: 430),
          child: conversations,
        ),
        Container(width: 0.5, color: colors.separator),
        Expanded(
          child: selected == null
              ? const _WideEmptyChatPlaceholder()
              : ChatScreen(
                  key: ValueKey('${selected.type.name}:${selected.id}'),
                  state: state,
                  conversation: selected,
                  embedded: true,
                ),
        ),
      ],
    );
  }
}

// ============================================================================
// Placeholder shown in wide layout when no conversation is selected
// ============================================================================

class _WideEmptyChatPlaceholder extends StatelessWidget {
  const _WideEmptyChatPlaceholder();

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
              CupertinoIcons.chat_bubble_2,
              size: 56,
              color: colors.tertiaryLabel,
            ),
            const SizedBox(height: 14),
            Text(
              context.strings.text('Select a conversation'),
              style: TextStyle(
                fontSize: 17,
                color: colors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Conversation list screen
// ============================================================================

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.state,
    this.embedded = false,
    this.selectedConversation,
    this.onConversationSelected,
  });

  final CsacAppState state;
  final bool embedded;
  final Conversation? selectedConversation;
  final ValueChanged<Conversation>? onConversationSelected;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final search = TextEditingController();
  bool refreshing = false;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() => refreshing = true);
    try {
      await widget.state.loadConversations();
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  List<Conversation> get _filtered {
    final query = search.text.trim().toLowerCase();
    if (query.isEmpty) return widget.state.conversations;
    return widget.state.conversations.where((c) {
      final target =
          '${c.name} ${c.subtitle} ${c.searchText}'.toLowerCase();
      return target.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final conversations = _filtered;

    // Bottom padding: floating tab bar (56) + safe area bottom + 12 gap ≈ 80
    final bottomPadding =
        MediaQuery.of(context).padding.bottom + 56 + 12 + 12;

    final content = CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: refresh),

        // ── Large title + action buttons ──────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    strings.text('消息'),
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: colors.label,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                if (widget.state.offlineMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colors.secondaryFill,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.wifi_slash,
                            size: 13,
                            color: colors.secondaryLabel,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            strings.text('Offline'),
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.secondaryLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Add friend
                CupertinoButton(
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(36, 36),
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => AddFriendScreen(state: widget.state),
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.person_add,
                    size: 20,
                    color: colors.primaryColor,
                  ),
                ),
                // Join group
                CupertinoButton(
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(36, 36),
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => JoinGroupScreen(state: widget.state),
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.person_2_alt,
                    size: 20,
                    color: colors.primaryColor,
                  ),
                ),
                // Create group
                CupertinoButton(
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(36, 36),
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => CreateGroupScreen(state: widget.state),
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.plus_bubble,
                    size: 20,
                    color: colors.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Search field ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: CupertinoSearchTextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              placeholder: strings.text('Search conversations'),
              onSuffixTap: () {
                search.clear();
                setState(() {});
              },
            ),
          ),
        ),

        // ── Conversation list ─────────────────────────────────────────────
        if (widget.state.conversations.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyPanel(
              message: strings.text('No conversations yet.'),
            ),
          )
        else if (conversations.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyPanel(
              message: strings.text('No matching conversations.'),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
            sliver: SliverToBoxAdapter(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: colors.cardBackground,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _buildTileList(conversations, colors),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return CupertinoPageScaffold(
      backgroundColor: colors.systemBackground,
      child: SafeArea(
        bottom: false,
        child: content,
      ),
    );
  }

  List<Widget> _buildTileList(
    List<Conversation> conversations,
    CsacColors colors,
  ) {
    final result = <Widget>[];
    for (var i = 0; i < conversations.length; i++) {
      final conversation = conversations[i];
      result.add(
        _ConversationTile(
          conversation: conversation,
          muted: widget.state.isConversationMuted(conversation),
          selected: widget.selectedConversation?.type == conversation.type &&
              widget.selectedConversation?.id == conversation.id,
          onLongPress: () => _showConversationActions(conversation),
          onTap: () async {
            if (widget.onConversationSelected != null) {
              widget.onConversationSelected!(conversation);
              return;
            }
            await Navigator.of(context).push(
              CupertinoPageRoute<void>(
                builder: (_) => ChatScreen(
                  state: widget.state,
                  conversation: conversation,
                ),
              ),
            );
            if (mounted) refresh();
          },
        ),
      );
      if (i < conversations.length - 1) {
        result.add(
          Container(
            height: 0.5,
            margin: const EdgeInsets.only(left: 72),
            color: colors.separator,
          ),
        );
      }
    }
    return result;
  }

  Future<void> _showConversationActions(Conversation conversation) async {
    final strings = context.strings;
    final muted = widget.state.isConversationMuted(conversation);

    final action = await showCupertinoModalPopup<_ConversationAction>(
      context: context,
      builder: (context) => _ConversationActionSheet(
        conversation: conversation,
        muted: muted,
      ),
    );
    if (action == null || !mounted) return;
    try {
      switch (action) {
        case _ConversationAction.markRead:
          await widget.state.markConversationRead(conversation);
          if (mounted) {
            _showCupertinoToast(
              context,
              strings.text('Conversation marked read.'),
            );
          }
          break;
        case _ConversationAction.markUnread:
          await widget.state.markConversationUnread(conversation);
          if (mounted) {
            _showCupertinoToast(
              context,
              strings.text('Conversation marked unread.'),
            );
          }
          break;
        case _ConversationAction.clearCache:
          await widget.state.clearConversationLocalCache(conversation);
          if (mounted) {
            _showCupertinoToast(
              context,
              strings.text('Conversation cache cleared.'),
            );
          }
          break;
        case _ConversationAction.toggleMute:
          final nowMuted = !widget.state.isConversationMuted(conversation);
          await widget.state.setConversationMuted(conversation, nowMuted);
          if (mounted) {
            _showCupertinoToast(
              context,
              strings.text(
                nowMuted
                    ? 'Do not disturb enabled.'
                    : 'Do not disturb disabled.',
              ),
            );
          }
          break;
      }
    } catch (err) {
      if (mounted) {
        setState(() {});
        _showCupertinoToast(
          context,
          strings.format('Action failed: {error}', {'error': err}),
        );
      }
    }
  }
}

// ============================================================================
// Conversation tile — flat row inside grouped card
// ============================================================================

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.onLongPress,
    required this.muted,
    this.selected = false,
  });

  final Conversation conversation;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool muted;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isGroup = conversation.type == ConversationType.group;
    final colors = CsacColors.of(context);
    final strings = context.strings;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: selected
            ? colors.primaryColor.withValues(alpha: 0.10)
            : colors.cardBackground,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            // Avatar with gradient fallback
            _Avatar(
              url: conversation.avatar,
              fallback: isGroup
                  ? CupertinoIcons.person_2_fill
                  : CupertinoIcons.person_fill,
              size: 44,
              name: conversation.name,
            ),
            const SizedBox(width: 12),
            // Name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    conversation.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.label,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    conversation.subtitle.isEmpty
                        ? strings.text(
                            isGroup ? 'Group chat' : 'Private chat',
                          )
                        : conversation.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Right side: unread badge OR muted icon
            if (muted)
              Icon(
                CupertinoIcons.bell_slash_fill,
                size: 15,
                color: colors.tertiaryLabel,
              )
            else if (conversation.unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 20),
                child: Text(
                  conversation.unreadCount > 99
                      ? '99+'
                      : '${conversation.unreadCount}',
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Conversation action sheet
// ============================================================================

enum _ConversationAction { markRead, markUnread, clearCache, toggleMute }

class _ConversationActionSheet extends StatelessWidget {
  const _ConversationActionSheet({
    required this.conversation,
    required this.muted,
  });

  final Conversation conversation;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return CupertinoActionSheet(
      title: Text(
        conversation.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () =>
              Navigator.of(context).pop(_ConversationAction.toggleMute),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                muted ? CupertinoIcons.bell : CupertinoIcons.bell_slash,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                strings.text(
                  muted
                      ? 'Disable do not disturb'
                      : 'Enable do not disturb',
                ),
              ),
            ],
          ),
        ),
        CupertinoActionSheetAction(
          onPressed: () =>
              Navigator.of(context).pop(_ConversationAction.markRead),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.checkmark_alt, size: 20),
              const SizedBox(width: 8),
              Text(strings.text('Mark read')),
            ],
          ),
        ),
        CupertinoActionSheetAction(
          onPressed: () =>
              Navigator.of(context).pop(_ConversationAction.markUnread),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.envelope_badge, size: 20),
              const SizedBox(width: 8),
              Text(strings.text('Mark unread')),
            ],
          ),
        ),
        CupertinoActionSheetAction(
          onPressed: () =>
              Navigator.of(context).pop(_ConversationAction.clearCache),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.trash, size: 20),
              const SizedBox(width: 8),
              Text(strings.text('Clear local cache')),
            ],
          ),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        isDefaultAction: true,
        onPressed: () => Navigator.of(context).pop(),
        child: Text(strings.text('Cancel')),
      ),
    );
  }
}
