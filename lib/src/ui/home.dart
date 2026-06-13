part of '../../main.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.state,
    this.navigatorKey,
    this.scaffoldMessengerKey,
  });

  final CsacAppState state;
  final GlobalKey<NavigatorState>? navigatorKey;
  final GlobalKey<CsacToastMessengerState>? scaffoldMessengerKey;

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
    final messenger = CsacToastMessenger.of(context);
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
      messenger.showToast(CsacToast(content: Text(message)));
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
        navigatorKey: widget.navigatorKey,
        scaffoldMessengerKey: widget.scaffoldMessengerKey,
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
      SpaceTimelineScreen(state: widget.state),
      NoticeCenterScreen(state: widget.state),
      ProfileScreen(state: widget.state),
    ];
    void selectTab(int value) {
      setState(() => index = value);
      if (value == 0) {
        widget.state.loadConversations();
      }
      if (value == 3) {
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
              icon: const Icon(CupertinoIcons.sparkles),
              activeIcon: const Icon(CupertinoIcons.sparkles),
              label: context.strings.text('Space'),
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
        CupertinoIcons.sparkles,
        CupertinoIcons.sparkles,
        context.strings.text('Space'),
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
    this.navigatorKey,
    this.scaffoldMessengerKey,
    this.embedded = false,
    this.selectedConversation,
    this.onConversationSelected,
  });

  final CsacAppState state;
  final GlobalKey<NavigatorState>? navigatorKey;
  final GlobalKey<CsacToastMessengerState>? scaffoldMessengerKey;
  final bool embedded;
  final Conversation? selectedConversation;
  final ValueChanged<Conversation>? onConversationSelected;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

enum _ConversationGroupFilter {
  all,
  important,
  friends,
  groups,
  archived,
  hidden,
}

class _ConversationScreenState extends State<ConversationScreen> {
  final search = TextEditingController();
  late final ScrollController conversationsScroll;
  Map<String, ConversationDraft> drafts = const <String, ConversationDraft>{};
  Map<String, ConversationLocalPreference> conversationPrefs =
      const <String, ConversationLocalPreference>{};
  List<Conversation>? heroLockedConversations;
  bool refreshing = false;
  _ConversationGroupFilter groupFilter = _ConversationGroupFilter.all;

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
      setState(() {
        conversationPrefs = loaded;
        if (groupFilter == _ConversationGroupFilter.archived &&
            !loaded.values.any((value) => value.archived)) {
          groupFilter = _ConversationGroupFilter.all;
        }
        if (groupFilter == _ConversationGroupFilter.hidden &&
            widget.state.hiddenGroupConversationIds.isEmpty) {
          groupFilter = _ConversationGroupFilter.all;
        }
      });
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
    final visible = searched.where(conversationInCurrentGroup).toList();
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

  bool conversationInCurrentGroup(Conversation conversation) {
    final pref = localPref(conversation);
    final hidden = widget.state.isConversationHidden(conversation);
    switch (groupFilter) {
      case _ConversationGroupFilter.all:
        return !pref.archived && !hidden;
      case _ConversationGroupFilter.important:
        return !pref.archived && !hidden && pref.pinned;
      case _ConversationGroupFilter.friends:
        return !pref.archived && conversation.type == ConversationType.private;
      case _ConversationGroupFilter.groups:
        return !pref.archived &&
            !hidden &&
            conversation.type == ConversationType.group;
      case _ConversationGroupFilter.archived:
        return pref.archived && !hidden;
      case _ConversationGroupFilter.hidden:
        return hidden;
    }
  }

  int groupCount(_ConversationGroupFilter filter) {
    return widget.state.conversations.where((conversation) {
      final pref = localPref(conversation);
      final hidden = widget.state.isConversationHidden(conversation);
      switch (filter) {
        case _ConversationGroupFilter.all:
          return !pref.archived && !hidden;
        case _ConversationGroupFilter.important:
          return !pref.archived && !hidden && pref.pinned;
        case _ConversationGroupFilter.friends:
          return !pref.archived &&
              conversation.type == ConversationType.private;
        case _ConversationGroupFilter.groups:
          return !pref.archived &&
              !hidden &&
              conversation.type == ConversationType.group;
        case _ConversationGroupFilter.archived:
          return pref.archived && !hidden;
        case _ConversationGroupFilter.hidden:
          return hidden;
      }
    }).length;
  }

  String emptyMessageForGroup(String query) {
    if (query.isNotEmpty) {
      return 'No matching conversations.';
    }
    switch (groupFilter) {
      case _ConversationGroupFilter.all:
        return 'No active conversations.';
      case _ConversationGroupFilter.important:
        return 'No important conversations.';
      case _ConversationGroupFilter.friends:
        return 'No friend conversations.';
      case _ConversationGroupFilter.groups:
        return 'No group conversations.';
      case _ConversationGroupFilter.archived:
        return 'No archived conversations.';
      case _ConversationGroupFilter.hidden:
        return 'No hidden conversations.';
    }
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
    final hidden = widget.state.isConversationHidden(conversation);
    final strings = context.strings;
    final selected = await showCsacActionSheet<String>(
      context: context,
      title: conversation.name,
      actions: [
        CsacActionSheetAction(
          value: 'pin',
          title: strings.text(
            pref.pinned ? 'Unpin conversation' : 'Pin conversation',
          ),
          icon: pref.pinned ? CupertinoIcons.pin_slash : CupertinoIcons.pin,
        ),
        CsacActionSheetAction(
          value: 'mute',
          title: strings.text(
            pref.muted ? 'Unmute conversation' : 'Mute conversation',
          ),
          icon: pref.muted
              ? CupertinoIcons.speaker_2
              : CupertinoIcons.speaker_slash,
        ),
        CsacActionSheetAction(
          value: 'archive',
          title: strings.text(
            pref.archived ? 'Unarchive conversation' : 'Archive conversation',
          ),
          icon: CupertinoIcons.archivebox,
          destructive: !pref.archived,
        ),
        if (conversation.type == ConversationType.group)
          CsacActionSheetAction(
            value: 'hide',
            title: strings.text(
              hidden ? 'Unhide conversation' : 'Hide conversation',
            ),
            icon: hidden ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
            destructive: !hidden,
          ),
      ],
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
      case 'hide':
        await widget.state.toggleHiddenConversation(conversation);
        if (mounted && groupFilter == _ConversationGroupFilter.hidden) {
          setState(() {});
        }
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
      case 'commands':
        final navigatorKey = widget.navigatorKey;
        final scaffoldMessengerKey = widget.scaffoldMessengerKey;
        if (navigatorKey != null && scaffoldMessengerKey != null) {
          await openCommandPaletteOverlay(
            context: context,
            state: widget.state,
            navigatorKey: navigatorKey,
            scaffoldMessengerKey: scaffoldMessengerKey,
          );
        }
        break;
      case 'logout':
        await confirmLogout(context, widget.state, popToRoot: false);
        break;
    }
    if (mounted &&
        action != 'refresh' &&
        action != 'searchMessages' &&
        action != 'commands' &&
        action != 'logout') {
      await refresh();
    }
  }

  Future<void> showHomeActions() async {
    final strings = context.strings;
    final action = await showCsacActionSheet<String>(
      context: context,
      actions: [
        CsacActionSheetAction(
          value: 'refresh',
          title: strings.text('Refresh'),
          icon: CupertinoIcons.arrow_clockwise,
        ),
        CsacActionSheetAction(
          value: 'addFriend',
          title: strings.text('Add friend'),
          icon: CupertinoIcons.person_add,
        ),
        CsacActionSheetAction(
          value: 'joinGroup',
          title: strings.text('Join group'),
          icon: CupertinoIcons.group,
        ),
        CsacActionSheetAction(
          value: 'createGroup',
          title: strings.text('Create group'),
          icon: CupertinoIcons.plus_circle,
        ),
        CsacActionSheetAction(
          value: 'searchMessages',
          title: strings.text('Search messages'),
          icon: CupertinoIcons.search,
        ),
        if (widget.navigatorKey != null && widget.scaffoldMessengerKey != null)
          CsacActionSheetAction(
            value: 'commands',
            title: strings.text('Commands'),
            icon: CupertinoIcons.chevron_left_slash_chevron_right,
          ),
        CsacActionSheetAction(
          value: 'logout',
          title: strings.text('Logout'),
          icon: CupertinoIcons.square_arrow_right,
          destructive: true,
        ),
      ],
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
    final pinnedConversations = conversations
        .where((conversation) => localPref(conversation).pinned)
        .toList();
    final regularConversations = conversations
        .where((conversation) => !localPref(conversation).pinned)
        .toList();
    final bottomPadding = widget.embedded ? 24.0 : 24.0;
    final groupFilters = <_ConversationGroupFilter>[
      _ConversationGroupFilter.all,
      _ConversationGroupFilter.important,
      _ConversationGroupFilter.friends,
      _ConversationGroupFilter.groups,
      _ConversationGroupFilter.archived,
      _ConversationGroupFilter.hidden,
    ];
    Future<void> openConversation(Conversation conversation) async {
      if (widget.onConversationSelected != null) {
        widget.onConversationSelected!(conversation);
        unawaited(loadDrafts());
        return;
      }
      setState(
        () => heroLockedConversations = List<Conversation>.of(
          widget.state.conversations,
        ),
      );
      final route = CsacPageRoute<void>(
        builder: (_) =>
            ChatScreen(state: widget.state, conversation: conversation),
      );
      await Navigator.of(context).push(route);
      await route.completed;
      if (mounted) {
        setState(() => heroLockedConversations = null);
        unawaited(refresh());
      }
    }

    Widget conversationTile(Conversation conversation) {
      final index = conversations.indexOf(conversation);
      return _MotionListItem(
        index: index < 0 ? 0 : index,
        child: _ConversationTile(
          conversation: conversation,
          draft: drafts[draftKey(conversation)],
          preference: localPref(conversation),
          subtitleMode: widget.state.preferences.conversationSubtitleMode,
          selected:
              widget.selectedConversation?.type == conversation.type &&
              widget.selectedConversation?.id == conversation.id,
          onLongPress: () => showConversationActions(conversation),
          onTap: () => unawaited(openConversation(conversation)),
        ),
      );
    }

    Widget conversationSection(String title, List<Conversation> items) {
      return _ChatListSection(
        header: title,
        children: [
          for (final conversation in items) conversationTile(conversation),
        ],
      );
    }

    final content = CsacCustomScrollView(
      controller: conversationsScroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: refresh),
        SliverToBoxAdapter(
          child: _ConversationListHeader(
            user: user,
            offline: widget.state.offlineMode,
            refreshing: refreshing,
            onAddFriend: () => openHomeAction('addFriend'),
            onJoinGroup: () => openHomeAction('joinGroup'),
            onCreateGroup: () => openHomeAction('createGroup'),
            onMore: showHomeActions,
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _CupertinoSearchField(
              controller: search,
              placeholder: strings.text('Search conversations'),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 46,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  ui.PointerDeviceKind.touch,
                  ui.PointerDeviceKind.mouse,
                  ui.PointerDeviceKind.trackpad,
                  ui.PointerDeviceKind.stylus,
                  ui.PointerDeviceKind.unknown,
                },
              ),
              child: CsacListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                itemCount: groupFilters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = groupFilters[index];
                  return _ConversationFilterPill(
                    icon: _conversationGroupIcon(filter),
                    label: strings.format(_conversationGroupLabel(filter), {
                      'count': groupCount(filter),
                    }),
                    selected: groupFilter == filter,
                    onTap: () => setState(() => groupFilter = filter),
                  );
                },
              ),
            ),
          ),
        ),
        if (widget.state.conversations.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _EmptyPanel(
                message: strings.text('No conversations yet.'),
              ),
            ),
          )
        else if (conversations.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: _EmptyPanel(
                message: strings.text(emptyMessageForGroup(query)),
              ),
            ),
          )
        else ...[
          if (groupFilter == _ConversationGroupFilter.all &&
              pinnedConversations.isNotEmpty)
            SliverToBoxAdapter(
              child: conversationSection(
                strings.text('Pinned'),
                pinnedConversations,
              ),
            ),
          if (groupFilter == _ConversationGroupFilter.all &&
              regularConversations.isNotEmpty)
            SliverToBoxAdapter(
              child: conversationSection(
                strings.text('Chats'),
                regularConversations,
              ),
            ),
          if (groupFilter != _ConversationGroupFilter.all)
            SliverToBoxAdapter(
              child: conversationSection(
                strings.text(_conversationGroupSectionLabel(groupFilter)),
                conversations,
              ),
            ),
        ],
        SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
      ],
    );
    return CupertinoPageScaffold(
      backgroundColor: colors.systemBackground,
      child: SafeArea(top: true, bottom: false, child: content),
    );
  }
}

class _ConversationListHeader extends StatelessWidget {
  const _ConversationListHeader({
    required this.user,
    required this.offline,
    required this.refreshing,
    required this.onAddFriend,
    required this.onJoinGroup,
    required this.onCreateGroup,
    required this.onMore,
  });

  final CsacUser? user;
  final bool offline;
  final bool refreshing;
  final VoidCallback onAddFriend;
  final VoidCallback onJoinGroup;
  final VoidCallback onCreateGroup;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final strings = context.strings;
    final user = this.user;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.text('Chats'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.label,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                if (user != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    '${user.nickname} / UID ${user.uid}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.secondaryLabel,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (offline) ...[
            _ConversationOfflinePill(label: strings.text('Offline')),
            const SizedBox(width: 8),
          ],
          _ConversationHeaderButton(
            icon: CupertinoIcons.person_add,
            label: strings.text('Add friend'),
            onPressed: onAddFriend,
          ),
          const SizedBox(width: 6),
          _ConversationHeaderButton(
            icon: CupertinoIcons.person_2,
            label: strings.text('Join group'),
            onPressed: onJoinGroup,
          ),
          const SizedBox(width: 6),
          _ConversationHeaderButton(
            icon: CupertinoIcons.plus_bubble,
            label: strings.text('Create group'),
            onPressed: onCreateGroup,
          ),
          const SizedBox(width: 6),
          _ConversationHeaderButton(
            icon: CupertinoIcons.ellipsis,
            label: strings.text('More'),
            onPressed: onMore,
            loading: refreshing,
          ),
        ],
      ),
    );
  }
}

class _ConversationHeaderButton extends StatelessWidget {
  const _ConversationHeaderButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Semantics(
      button: true,
      label: label,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(34),
        borderRadius: BorderRadius.circular(17),
        color: colors.tertiaryFill,
        onPressed: loading ? null : onPressed,
        child: loading
            ? CupertinoActivityIndicator(
                radius: 8.5,
                color: colors.primaryColor,
              )
            : Icon(icon, size: 18, color: colors.primaryColor),
      ),
    );
  }
}

class _ConversationOfflinePill extends StatelessWidget {
  const _ConversationOfflinePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final accent = CupertinoColors.systemOrange.resolveFrom(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 86),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: colors.isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.wifi_slash, size: 13, color: accent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _conversationGroupLabel(_ConversationGroupFilter filter) {
  switch (filter) {
    case _ConversationGroupFilter.all:
      return 'All conversations ({count})';
    case _ConversationGroupFilter.important:
      return 'Important ({count})';
    case _ConversationGroupFilter.friends:
      return 'Friends ({count})';
    case _ConversationGroupFilter.groups:
      return 'Groups ({count})';
    case _ConversationGroupFilter.archived:
      return 'Archived ({count})';
    case _ConversationGroupFilter.hidden:
      return 'Hidden ({count})';
  }
}

String _conversationGroupSectionLabel(_ConversationGroupFilter filter) {
  switch (filter) {
    case _ConversationGroupFilter.all:
      return 'Chats';
    case _ConversationGroupFilter.important:
      return 'Important';
    case _ConversationGroupFilter.friends:
      return 'Friends';
    case _ConversationGroupFilter.groups:
      return 'Groups';
    case _ConversationGroupFilter.archived:
      return 'Archived';
    case _ConversationGroupFilter.hidden:
      return 'Hidden';
  }
}

IconData _conversationGroupIcon(_ConversationGroupFilter filter) {
  switch (filter) {
    case _ConversationGroupFilter.all:
      return CupertinoIcons.tray;
    case _ConversationGroupFilter.important:
      return CupertinoIcons.pin;
    case _ConversationGroupFilter.friends:
      return CupertinoIcons.person;
    case _ConversationGroupFilter.groups:
      return CupertinoIcons.group;
    case _ConversationGroupFilter.archived:
      return CupertinoIcons.archivebox;
    case _ConversationGroupFilter.hidden:
      return CupertinoIcons.eye_slash;
  }
}

class _ConversationFilterPill extends StatelessWidget {
  const _ConversationFilterPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
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
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? primary : colors.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _conversationPreviewTime(Conversation conversation) {
  final timestamp = conversation.lastMessageAt;
  if (timestamp <= 0) {
    return '';
  }
  final value = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
  final now = DateTime.now();
  String two(int number) => number.toString().padLeft(2, '0');
  final sameDay =
      value.year == now.year &&
      value.month == now.month &&
      value.day == now.day;
  if (sameDay) {
    return '${two(value.hour)}:${two(value.minute)}';
  }
  if (value.year == now.year) {
    return '${two(value.month)}/${two(value.day)}';
  }
  return '${value.year}/${two(value.month)}/${two(value.day)}';
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
    final tileColor = selected
        ? primary.withValues(alpha: colors.isDark ? 0.18 : 0.10)
        : colors.cardBackground;
    return _ChatListTile(
      selected: selected,
      title: Row(
        children: [
          if (preference.pinned) ...[
            Icon(CupertinoIcons.pin_fill, size: 13, color: primary),
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
      subtitle: Text(subtitleText),
      subtitleColor: hasDraft ? primary : colors.secondaryLabel,
      subtitleFontWeight: hasDraft ? FontWeight.w600 : FontWeight.w400,
      backgroundColor: tileColor,
      leading: _ConversationAvatarHero(conversation: conversation, radius: 25),
      trailing: _ConversationTileTrailing(
        previewTime: _conversationPreviewTime(conversation),
        unreadCount: conversation.unreadCount,
        muted: preference.muted,
        archived: preference.archived,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onLongPress,
    );
  }
}

class _ConversationTileTrailing extends StatelessWidget {
  const _ConversationTileTrailing({
    required this.previewTime,
    required this.unreadCount,
    required this.muted,
    required this.archived,
  });

  final String previewTime;
  final int unreadCount;
  final bool muted;
  final bool archived;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final indicators = <Widget>[];
    if (muted) {
      indicators.add(
        Icon(CupertinoIcons.bell_slash, size: 16, color: colors.tertiaryLabel),
      );
    }
    if (archived) {
      indicators.add(
        Icon(CupertinoIcons.archivebox, size: 16, color: colors.tertiaryLabel),
      );
    }
    if (unreadCount > 0) {
      indicators.add(
        _ConversationUnreadBadge(count: unreadCount, muted: muted),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (previewTime.isNotEmpty)
                Text(
                  previewTime,
                  style: TextStyle(
                    color: colors.tertiaryLabel,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              if (previewTime.isNotEmpty) const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_right,
                size: 13,
                color: colors.tertiaryLabel,
              ),
            ],
          ),
          if (indicators.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in indicators.indexed) ...[
                  if (entry.$1 > 0) const SizedBox(width: 7),
                  entry.$2,
                ],
              ],
            ),
          ],
        ],
      ),
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
