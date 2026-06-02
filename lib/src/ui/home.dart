part of '../../main.dart';

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
    widget.state.addListener(handleStateChanged);
    lastUnreadChats = totalUnreadChats();
    timer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => refreshHomeWithHint(),
    );
  }

  void handleStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  int totalUnreadChats() {
    return widget.state.conversations.fold<int>(
      0,
      (total, conversation) => total + conversation.unreadCount,
    );
  }

  String conversationKey(Conversation conversation) {
    return '${conversation.type.name}:${conversation.id}';
  }

  int newUnreadDelta(Map<String, int> beforeUnread) {
    var total = 0;
    for (final conversation in widget.state.conversations) {
      if (widget.state.isVisibleActiveConversation(conversation)) {
        continue;
      }
      final previous = beforeUnread[conversationKey(conversation)] ?? 0;
      final delta = conversation.unreadCount - previous;
      if (delta > 0) {
        total += delta;
      }
    }
    return total;
  }

  Future<void> refreshHomeWithHint() async {
    final strings = context.strings;
    final messenger = ScaffoldMessenger.of(context);
    final beforeUnread = <String, int>{
      for (final conversation in widget.state.conversations)
        conversationKey(conversation): conversation.unreadCount,
    };
    try {
      await widget.state.refreshHome();
    } catch (_) {
      return;
    }
    if (!mounted) {
      return;
    }
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
        if (widget.state.appInForeground) {
          await widget.state.markConversationRead(
            latestSelected,
            syncServer: false,
          );
        }
      }
    }
    final newCount = newUnreadDelta(beforeUnread);
    final after = totalUnreadChats();
    if (newCount > 0) {
      final message = strings.format('New messages: {count}', {
        'count': newCount,
      });
      messenger.showSnackBar(SnackBar(content: Text(message)));
      await showNewMessageNotifications(beforeUnread);
    }
    lastUnreadChats = after;
  }

  Future<void> showNewMessageNotifications(
    Map<String, int> beforeUnread,
  ) async {
    if (!widget.state.preferences.localSystemNotificationsEnabled) {
      return;
    }
    for (final conversation in widget.state.conversations) {
      if (widget.state.isVisibleActiveConversation(conversation)) {
        continue;
      }
      final key = conversationKey(conversation);
      final previous = beforeUnread[key] ?? 0;
      final delta = conversation.unreadCount - previous;
      if (delta > 0) {
        final latestMessage = await latestNotificationMessage(conversation);
        if (!mounted) {
          return;
        }
        await CsacLocalNotificationService.instance
            .showConversationNotification(
              conversation: conversation,
              newCount: delta,
              title: notificationTitleForConversation(
                conversation,
                latestMessage,
              ),
              body: notificationBodyForConversation(
                conversation,
                delta,
                latestMessage,
                context.strings,
              ),
            );
      }
    }
  }

  Future<ChatMessage?> latestNotificationMessage(
    Conversation conversation,
  ) async {
    if (conversation.type == ConversationType.group) {
      final cached = await widget.state.loadCachedMessages(conversation);
      final afterId = cached.isEmpty ? 0 : cached.last.id;
      final previousIncomingId = latestIncomingNotificationMessageId(
        conversation,
        cached,
        currentUserId: widget.state.user?.uid ?? 0,
      );
      final loaded = await widget.state.syncMessages(
        conversation,
        afterId: afterId,
      );
      final latestIncoming = latestIncomingNotificationMessage(
        conversation,
        loaded,
        currentUserId: widget.state.user?.uid ?? 0,
      );
      if (latestIncoming != null && latestIncoming.id > previousIncomingId) {
        return latestIncoming;
      }
      return null;
    }
    final cached = await widget.state.loadCachedMessages(conversation);
    return latestIncomingNotificationMessage(
      conversation,
      cached,
      currentUserId: widget.state.user?.uid ?? 0,
    );
  }

  @override
  void dispose() {
    widget.state.removeListener(handleStateChanged);
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unreadChats = totalUnreadChats();
    final noticeCount = widget.state.notificationCounts.total;
    final wide = MediaQuery.sizeOf(context).width >= 900;
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
    void selectTab(int value) {
      setState(() => index = value);
      if (value == 0) {
        widget.state.loadConversations();
      }
      if (value == 2) {
        widget.state.refreshNotificationCounts();
      }
    }

    Widget shell;
    if (wide) {
      shell = CupertinoPageScaffold(
        backgroundColor: colors.systemBackground,
        child: SafeArea(
          child: Row(
            children: [
              _CupertinoSideRail(
                index: index,
                unreadChats: unreadChats,
                noticeCount: noticeCount,
                onChanged: selectTab,
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
    } else {
      shell = CupertinoTabScaffold(
        tabBar: CupertinoTabBar(
          currentIndex: index,
          onTap: selectTab,
          backgroundColor: CupertinoTheme.of(context).barBackgroundColor,
          activeColor: CupertinoTheme.of(context).primaryColor,
          inactiveColor: colors.secondaryLabel,
          items: [
            BottomNavigationBarItem(
              icon: _TabBadgeIcon(
                icon: CupertinoIcons.chat_bubble_2,
                count: unreadChats,
              ),
              activeIcon: _TabBadgeIcon(
                icon: CupertinoIcons.chat_bubble_2_fill,
                count: unreadChats,
              ),
              label: context.strings.text('Chats'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.search),
              activeIcon: const Icon(CupertinoIcons.search_circle_fill),
              label: context.strings.text('Search'),
            ),
            BottomNavigationBarItem(
              icon: _TabBadgeIcon(
                icon: CupertinoIcons.bell,
                count: noticeCount,
              ),
              activeIcon: _TabBadgeIcon(
                icon: CupertinoIcons.bell_fill,
                count: noticeCount,
              ),
              label: context.strings.text('Notices'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.person),
              activeIcon: const Icon(CupertinoIcons.person_fill),
              label: context.strings.text('Me'),
            ),
          ],
        ),
        tabBuilder: (context, tabIndex) => _FocusableTabPage(
          active: index == tabIndex,
          child: pages[tabIndex],
        ),
      );
    }
    return shell;
  }
}

class _BottomTabSwitcher extends StatefulWidget {
  const _BottomTabSwitcher({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_BottomTabSwitcher> createState() => _BottomTabSwitcherState();
}

class _CupertinoSideRail extends StatelessWidget {
  const _CupertinoSideRail({
    required this.index,
    required this.unreadChats,
    required this.noticeCount,
    required this.onChanged,
  });

  final int index;
  final int unreadChats;
  final int noticeCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final items = [
      (
        CupertinoIcons.chat_bubble_2,
        CupertinoIcons.chat_bubble_2_fill,
        context.strings.text('Chats'),
        unreadChats,
      ),
      (
        CupertinoIcons.search,
        CupertinoIcons.search_circle_fill,
        context.strings.text('Search'),
        0,
      ),
      (
        CupertinoIcons.bell,
        CupertinoIcons.bell_fill,
        context.strings.text('Notices'),
        noticeCount,
      ),
      (
        CupertinoIcons.person,
        CupertinoIcons.person_solid,
        context.strings.text('Me'),
        0,
      ),
    ];
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 72,
          color: colors.cardBackground.withValues(alpha: 0.86),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 16),
                child: const _AppIconImage(size: 34, borderRadius: 9),
              ),
              for (final item in items.indexed)
                _SideRailItem(
                  selected: index == item.$1,
                  icon: item.$2.$1,
                  activeIcon: item.$2.$2,
                  label: item.$2.$3,
                  badge: item.$2.$4,
                  onTap: () => onChanged(item.$1),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideRailItem extends StatelessWidget {
  const _SideRailItem({
    required this.selected,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.badge,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    return _CsacPressable(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BadgeIcon(
                icon: selected ? activeIcon : icon,
                count: badge,
                color: selected ? primary : colors.secondaryLabel,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? primary : colors.secondaryLabel,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
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
    final label = count > 99 ? '99+' : '$count';
    return SizedBox(
      width: 30,
      height: 26,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(icon),
          if (count > 0)
            Positioned(
              top: -3,
              right: -6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed.resolveFrom(context),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
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

class _BottomTabSwitcherState extends State<_BottomTabSwitcher> {
  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: [
        for (final entry in widget.children.indexed)
          _FocusableTabPage(active: widget.index == entry.$1, child: entry.$2),
      ],
    );
  }
}

class _FocusableTabPage extends StatelessWidget {
  const _FocusableTabPage({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: active,
      child: FocusScope(
        canRequestFocus: active,
        descendantsAreFocusable: active,
        descendantsAreTraversable: active,
        child: child,
      ),
    );
  }
}

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
    final selected = selectedConversation;
    return Row(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 320, maxWidth: 430),
          child: conversations,
        ),
        Container(width: 0.5, color: CsacColors.of(context).separator),
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
              CupertinoIcons.bubble_left_bubble_right,
              size: 56,
              color: colors.tertiaryLabel,
            ),
            const SizedBox(height: 14),
            Text(
              context.strings.text('Select a conversation'),
              style: TextStyle(color: colors.secondaryLabel, fontSize: 17),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({
    required this.icon,
    required this.count,
    this.color,
    this.size,
  });

  final IconData icon;
  final int count;
  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final child = Icon(icon, color: color, size: size);
    if (count <= 0) {
      return child;
    }
    return Badge(label: Text(count > 99 ? '99+' : '$count'), child: child);
  }
}

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
  late final ScrollController conversationsScroll;
  Map<String, ConversationDraft> drafts = const <String, ConversationDraft>{};
  Map<String, ConversationLocalPreference> conversationPrefs =
      const <String, ConversationLocalPreference>{};
  List<Conversation>? heroLockedConversations;
  bool refreshing = false;

  @override
  void initState() {
    super.initState();
    conversationsScroll = _desktopSmoothScrollController();
    ConversationDraftStore.changes.addListener(handleDraftsChanged);
    ConversationPreferenceStore.changes.addListener(handlePreferencesChanged);
    unawaited(loadDrafts());
    unawaited(loadConversationPrefs());
  }

  @override
  void dispose() {
    ConversationDraftStore.changes.removeListener(handleDraftsChanged);
    ConversationPreferenceStore.changes.removeListener(
      handlePreferencesChanged,
    );
    conversationsScroll.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() => refreshing = true);
    try {
      await widget.state.loadConversations();
      await loadDrafts();
      await loadConversationPrefs();
    } finally {
      if (mounted) {
        setState(() => refreshing = false);
      }
    }
  }

  Future<void> loadDrafts() async {
    final loaded = await ConversationDraftStore.loadAll();
    if (mounted) {
      setState(() => drafts = loaded);
    }
  }

  void handleDraftsChanged() {
    unawaited(loadDrafts());
  }

  Future<void> loadConversationPrefs() async {
    final loaded = await ConversationPreferenceStore.loadAll();
    if (mounted) {
      setState(() => conversationPrefs = loaded);
    }
  }

  void handlePreferencesChanged() {
    unawaited(loadConversationPrefs());
  }

  String draftKey(Conversation conversation) {
    return ConversationPreferenceStore.keyFor(conversation);
  }

  ConversationLocalPreference localPref(Conversation conversation) {
    return conversationPrefs[draftKey(conversation)] ??
        ConversationLocalPreference.defaults;
  }

  List<Conversation> visibleConversations(String query) {
    final source = heroLockedConversations ?? widget.state.conversations;
    final searched = query.isEmpty
        ? source
        : source.where((conversation) {
            final target =
                '${conversation.name} ${conversation.subtitle} ${conversation.searchText}'
                    .toLowerCase();
            return target.contains(query);
          }).toList();
    final visible = searched.where((conversation) {
      return !localPref(conversation).archived;
    }).toList();
    visible.sort((a, b) {
      final aPref = localPref(a);
      final bPref = localPref(b);
      if (aPref.pinned != bPref.pinned) {
        return aPref.pinned ? -1 : 1;
      }
      return searched.indexOf(a).compareTo(searched.indexOf(b));
    });
    return visible;
  }

  Future<void> updateLocalPreference(
    Conversation conversation,
    ConversationLocalPreference Function(ConversationLocalPreference current)
    change,
  ) async {
    await widget.state.updateConversationLocalPreference(conversation, change);
    await loadConversationPrefs();
  }

  Future<void> showConversationActions(Conversation conversation) async {
    final pref = localPref(conversation);
    final strings = context.strings;
    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(conversation.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('pin'),
            child: Text(
              strings.text(
                pref.pinned ? 'Unpin conversation' : 'Pin conversation',
              ),
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('mute'),
            child: Text(
              strings.text(
                pref.muted ? 'Unmute conversation' : 'Mute conversation',
              ),
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: !pref.archived,
            onPressed: () => Navigator.of(context).pop('archive'),
            child: Text(
              strings.text(
                pref.archived
                    ? 'Unarchive conversation'
                    : 'Archive conversation',
              ),
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.text('Cancel')),
        ),
      ),
    );
    if (!mounted || selected == null) {
      return;
    }
    switch (selected) {
      case 'pin':
        await updateLocalPreference(
          conversation,
          (current) => current.copyWith(pinned: !current.pinned),
        );
        break;
      case 'mute':
        await updateLocalPreference(
          conversation,
          (current) => current.copyWith(muted: !current.muted),
        );
        break;
      case 'archive':
        await updateLocalPreference(
          conversation,
          (current) => current.copyWith(
            archived: !current.archived,
            pinned: current.archived ? current.pinned : false,
          ),
        );
        break;
    }
  }

  Future<void> openHomeAction(String action) async {
    switch (action) {
      case 'refresh':
        await refresh();
        break;
      case 'addFriend':
        await Navigator.of(context).push(
          CsacPageRoute<void>(
            builder: (_) => AddFriendScreen(state: widget.state),
          ),
        );
        break;
      case 'joinGroup':
        await Navigator.of(context).push(
          CsacPageRoute<void>(
            builder: (_) => JoinGroupScreen(state: widget.state),
          ),
        );
        break;
      case 'createGroup':
        await Navigator.of(context).push(
          CsacPageRoute<void>(
            builder: (_) => CreateGroupScreen(state: widget.state),
          ),
        );
        break;
      case 'searchMessages':
        await Navigator.of(context).push(
          CsacPageRoute<void>(
            builder: (_) => MessageSearchScreen(state: widget.state),
          ),
        );
        break;
      case 'logout':
        await confirmLogout(context, widget.state, popToRoot: false);
        break;
    }
    if (mounted &&
        action != 'refresh' &&
        action != 'searchMessages' &&
        action != 'logout') {
      await refresh();
    }
  }

  Future<void> showHomeActions() async {
    final strings = context.strings;
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('refresh'),
            child: Text(strings.text('Refresh')),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('addFriend'),
            child: Text(strings.text('Add friend')),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('joinGroup'),
            child: Text(strings.text('Join group')),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('createGroup'),
            child: Text(strings.text('Create group')),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('searchMessages'),
            child: Text(strings.text('Search messages')),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop('logout'),
            child: Text(strings.text('Logout')),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.text('Cancel')),
        ),
      ),
    );
    if (action != null && mounted) {
      await openHomeAction(action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.state.user;
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final query = search.text.trim().toLowerCase();
    final conversations = visibleConversations(query);
    final bottomPadding = widget.embedded ? 24.0 : 24.0;
    final content = RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        controller: conversationsScroll,
        padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.text('Chats'),
                        style: TextStyle(
                          color: colors.label,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                        ),
                      ),
                      if (user != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${user.nickname} / UID ${user.uid}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.secondaryLabel,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.state.offlineMode)
                  Chip(
                    avatar: const Icon(CupertinoIcons.wifi_slash, size: 18),
                    label: Text(strings.text('Offline')),
                  ),
                CupertinoButton(
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(36, 36),
                  onPressed: () => openHomeAction('addFriend'),
                  child: Icon(
                    CupertinoIcons.person_add,
                    color: colors.primaryColor,
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(36, 36),
                  onPressed: () => openHomeAction('joinGroup'),
                  child: Icon(
                    CupertinoIcons.person_2,
                    color: colors.primaryColor,
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(36, 36),
                  onPressed: () => openHomeAction('createGroup'),
                  child: Icon(
                    CupertinoIcons.plus_bubble,
                    color: colors.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: _CupertinoSearchField(
              controller: search,
              placeholder: strings.text('Search conversations'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (widget.state.conversations.isEmpty)
            _EmptyPanel(message: strings.text('No conversations yet.'))
          else if (conversations.isEmpty)
            _EmptyPanel(
              message: strings.text(
                query.isEmpty
                    ? 'No active conversations.'
                    : 'No matching conversations.',
              ),
            )
          else
            for (final entry in conversations.indexed)
              _MotionListItem(
                index: entry.$1,
                child: _ConversationTile(
                  conversation: entry.$2,
                  draft: drafts[draftKey(entry.$2)],
                  preference: localPref(entry.$2),
                  subtitleMode:
                      widget.state.preferences.conversationSubtitleMode,
                  selected:
                      widget.selectedConversation?.type == entry.$2.type &&
                      widget.selectedConversation?.id == entry.$2.id,
                  onLongPress: () => showConversationActions(entry.$2),
                  onTap: () async {
                    if (widget.onConversationSelected != null) {
                      widget.onConversationSelected!(entry.$2);
                      unawaited(loadDrafts());
                      return;
                    }
                    setState(
                      () => heroLockedConversations = List<Conversation>.of(
                        widget.state.conversations,
                      ),
                    );
                    final route = CsacPageRoute<void>(
                      builder: (_) => ChatScreen(
                        state: widget.state,
                        conversation: entry.$2,
                      ),
                    );
                    await Navigator.of(context).push(route);
                    await route.completed;
                    if (mounted) {
                      setState(() => heroLockedConversations = null);
                      unawaited(refresh());
                    }
                  },
                ),
              ),
        ],
      ),
    );
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(strings.text('CsAC Mobile')),
              actions: [
                IconButton(
                  tooltip: strings.text('More'),
                  onPressed: showHomeActions,
                  icon: const Icon(CupertinoIcons.ellipsis_circle),
                ),
              ],
            ),
      body: SafeArea(top: widget.embedded, child: content),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.onLongPress,
    this.draft,
    this.preference = ConversationLocalPreference.defaults,
    this.subtitleMode = ConversationSubtitleMode.recentMessage,
    this.selected = false,
  });

  final Conversation conversation;
  final ConversationDraft? draft;
  final ConversationLocalPreference preference;
  final ConversationSubtitleMode subtitleMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isGroup = conversation.type == ConversationType.group;
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    final draft = this.draft;
    final hasDraft = draft != null && draft.hasContent;
    final fallbackSubtitle = conversation.subtitle.isEmpty
        ? context.strings.text(isGroup ? 'Group chat' : 'Private chat')
        : conversation.subtitle;
    final preferredSubtitle = switch (subtitleMode) {
      ConversationSubtitleMode.recentMessage =>
        conversation.lastMessagePreview.trim().isNotEmpty
            ? conversation.lastMessagePreview.trim()
            : fallbackSubtitle,
      ConversationSubtitleMode.status =>
        conversation.statusSubtitle.trim().isNotEmpty
            ? conversation.statusSubtitle.trim()
            : fallbackSubtitle,
    };
    final subtitleText = hasDraft
        ? context.strings.format('Draft: {text}', {
            'text': compactDraftText(draft.previewText, max: 72),
          })
        : preferredSubtitle;
    final backgroundColor = selected
        ? primary.withValues(alpha: colors.isDark ? 0.18 : 0.10)
        : colors.cardBackground;
    final borderColor = selected
        ? primary.withValues(alpha: colors.isDark ? 0.34 : 0.24)
        : colors.separator.withValues(alpha: 0.24);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(_csacControlCornerRadius),
        border: Border.all(color: borderColor, width: 0.5),
      ),
      child: _CupertinoListPressable(
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              _ConversationAvatarHero(conversation: conversation, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        color: selected ? primary : colors.label,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.18,
                      ),
                      child: Row(
                        children: [
                          if (preference.pinned) ...[
                            Icon(
                              CupertinoIcons.pin_fill,
                              size: 13,
                              color: primary,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: _ConversationTitleHero(
                              conversation: conversation,
                              enabled: !selected,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasDraft ? primary : colors.secondaryLabel,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _ConversationTileTrailing(
                unreadCount: conversation.unreadCount,
                muted: preference.muted,
                archived: preference.archived,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationTileTrailing extends StatelessWidget {
  const _ConversationTileTrailing({
    required this.unreadCount,
    required this.muted,
    required this.archived,
  });

  final int unreadCount;
  final bool muted;
  final bool archived;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    if (unreadCount > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (muted) ...[
            Icon(
              CupertinoIcons.bell_slash,
              size: 17,
              color: colors.tertiaryLabel,
            ),
            const SizedBox(width: 8),
          ],
          _ConversationUnreadBadge(count: unreadCount, muted: muted),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (muted) ...[
          Icon(
            CupertinoIcons.bell_slash,
            size: 17,
            color: colors.tertiaryLabel,
          ),
          const SizedBox(width: 8),
        ],
        if (archived) ...[
          Icon(
            CupertinoIcons.archivebox,
            size: 17,
            color: colors.tertiaryLabel,
          ),
          const SizedBox(width: 8),
        ],
        Icon(
          CupertinoIcons.chevron_right,
          size: 14,
          color: colors.tertiaryLabel,
        ),
      ],
    );
  }
}

class _ConversationUnreadBadge extends StatelessWidget {
  const _ConversationUnreadBadge({required this.count, required this.muted});

  final int count;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted
            ? colors.tertiaryFill
            : CupertinoColors.systemRed.resolveFrom(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: muted ? colors.secondaryLabel : CupertinoColors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
