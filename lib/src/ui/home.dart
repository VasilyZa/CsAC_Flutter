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
    lastUnreadChats = totalUnreadChats();
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
    final messenger = ScaffoldMessenger.of(context);
    final beforeUnread = <String, int>{
      for (final conversation in widget.state.conversations)
        '${conversation.type.name}:${conversation.id}':
            conversation.unreadCount,
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
      if (widget.state.isActiveConversation(conversation)) {
        continue;
      }
      final key = '${conversation.type.name}:${conversation.id}';
      final previous = beforeUnread[key] ?? 0;
      final delta = conversation.unreadCount - previous;
      if (delta > 0) {
        await CsacLocalNotificationService.instance
            .showConversationNotification(
              conversation: conversation,
              newCount: delta,
            );
      }
    }
  }

  @override
  void dispose() {
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
      shell = CupertinoPageScaffold(
        backgroundColor: colors.systemBackground,
        child: Stack(
          children: [
            Positioned.fill(
              child: _BottomTabSwitcher(index: index, children: pages),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 8),
                child: _FloatingTabBar(
                  index: index,
                  unreadChats: unreadChats,
                  noticeCount: noticeCount,
                  onChanged: selectTab,
                ),
              ),
            ),
          ],
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

class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({
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
    final strings = context.strings;
    final items = [
      (
        CupertinoIcons.chat_bubble,
        CupertinoIcons.chat_bubble_fill,
        strings.text('Chats'),
        unreadChats,
      ),
      (CupertinoIcons.search, CupertinoIcons.search, strings.text('Search'), 0),
      (
        CupertinoIcons.bell,
        CupertinoIcons.bell_fill,
        strings.text('Notices'),
        noticeCount,
      ),
      (
        CupertinoIcons.person,
        CupertinoIcons.person_fill,
        strings.text('Me'),
        0,
      ),
    ];
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 398),
          child: _LiquidGlassTabBarSurface(
            child: Row(
              children: [
                for (final item in items.indexed)
                  Expanded(
                    child: _FloatingTabButton(
                      selected: index == item.$1,
                      icon: item.$2.$1,
                      activeIcon: item.$2.$2,
                      label: item.$2.$3,
                      badge: item.$2.$4,
                      onTap: () => onChanged(item.$1),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassTabBarSurface extends StatelessWidget {
  const _LiquidGlassTabBarSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    final radius = BorderRadius.circular(30);
    final glassTint = colors.isDark
        ? const Color(0xFF121216).withValues(alpha: 0.50)
        : CupertinoColors.white.withValues(alpha: 0.42);
    final edgeHighlight = CupertinoColors.white.withValues(
      alpha: colors.isDark ? 0.22 : 0.68,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(
              alpha: colors.isDark ? 0.42 : 0.16,
            ),
            blurRadius: 32,
            spreadRadius: -8,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: primary.withValues(alpha: colors.isDark ? 0.18 : 0.10),
            blurRadius: 28,
            spreadRadius: -12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 34, sigmaY: 34),
          child: SizedBox(
            height: 60,
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: glassTint,
                      borderRadius: radius,
                      border: Border.all(
                        color: colors.separator.withValues(alpha: 0.18),
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          edgeHighlight,
                          CupertinoColors.white.withValues(alpha: 0.10),
                          primary.withValues(
                            alpha: colors.isDark ? 0.12 : 0.08,
                          ),
                          colors.cardBackground.withValues(
                            alpha: colors.isDark ? 0.08 : 0.16,
                          ),
                        ],
                        stops: const [0, 0.28, 0.62, 1],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      gradient: RadialGradient(
                        center: const Alignment(-0.78, -0.92),
                        radius: 1.0,
                        colors: [
                          CupertinoColors.white.withValues(
                            alpha: colors.isDark ? 0.18 : 0.48,
                          ),
                          CupertinoColors.white.withValues(alpha: 0.00),
                        ],
                        stops: const [0, 0.72],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: edgeHighlight.withValues(alpha: 0.72),
                        width: 0.6,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingTabButton extends StatelessWidget {
  const _FloatingTabButton({
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
    final primary = CupertinoTheme.of(context).primaryColor;
    final colors = CsacColors.of(context);
    return _CsacPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 220.ms,
        curve: Curves.easeOutCubic,
        height: 46,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(23),
          border: selected
              ? Border.all(
                  color: CupertinoColors.white.withValues(
                    alpha: colors.isDark ? 0.22 : 0.54,
                  ),
                  width: 0.5,
                )
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: primary.withValues(
                      alpha: colors.isDark ? 0.18 : 0.10,
                    ),
                    blurRadius: 18,
                    spreadRadius: -8,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: selected ? 18 : 0.001,
              sigmaY: selected ? 18 : 0.001,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          CupertinoColors.white.withValues(
                            alpha: colors.isDark ? 0.12 : 0.38,
                          ),
                          primary.withValues(
                            alpha: colors.isDark ? 0.10 : 0.08,
                          ),
                          CupertinoColors.white.withValues(alpha: 0.04),
                        ],
                      )
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _BadgeIcon(
                    icon: selected ? activeIcon : icon,
                    count: badge,
                    color: selected ? primary : colors.secondaryLabel,
                    size: 21,
                  ),
                  AnimatedSize(
                    duration: 180.ms,
                    curve: Curves.easeOutCubic,
                    child: selected
                        ? Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: TextStyle(
                                color: primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomTabSwitcherState extends State<_BottomTabSwitcher>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return _FocusableTabPage(
      active: true,
      child: KeyedSubtree(
        key: ValueKey<int>(widget.index),
        child: widget.children[widget.index],
      ),
    );
  }
}

class _FocusableTabPage extends StatelessWidget {
  const _FocusableTabPage({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      canRequestFocus: active,
      descendantsAreFocusable: active,
      descendantsAreTraversable: active,
      child: child,
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
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: _RoundedInkClip(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  pref.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                ),
                title: Text(
                  context.strings.text(
                    pref.pinned ? 'Unpin conversation' : 'Pin conversation',
                  ),
                ),
                onTap: () => Navigator.of(context).pop('pin'),
              ),
              ListTile(
                leading: Icon(
                  pref.muted
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                ),
                title: Text(
                  context.strings.text(
                    pref.muted ? 'Unmute conversation' : 'Mute conversation',
                  ),
                ),
                onTap: () => Navigator.of(context).pop('mute'),
              ),
              ListTile(
                leading: Icon(
                  pref.archived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                title: Text(
                  context.strings.text(
                    pref.archived
                        ? 'Unarchive conversation'
                        : 'Archive conversation',
                  ),
                ),
                onTap: () => Navigator.of(context).pop('archive'),
              ),
            ],
          ),
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
    final bottomPadding = widget.embedded
        ? 24.0
        : MediaQuery.paddingOf(context).bottom + 92;
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
            child: TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: strings.text('Search conversations'),
                prefixIcon: const Icon(CupertinoIcons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: strings.text('Clear'),
                        onPressed: () {
                          search.clear();
                          setState(() {});
                        },
                        icon: const Icon(CupertinoIcons.xmark_circle_fill),
                      ),
                border: const OutlineInputBorder(),
              ),
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
    this.selected = false,
  });

  final Conversation conversation;
  final ConversationDraft? draft;
  final ConversationLocalPreference preference;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isGroup = conversation.type == ConversationType.group;
    final colors = Theme.of(context).colorScheme;
    final draft = this.draft;
    final hasDraft = draft != null && draft.hasContent;
    final fallbackSubtitle = conversation.subtitle.isEmpty
        ? context.strings.text(isGroup ? 'Group chat' : 'Private chat')
        : conversation.subtitle;
    final subtitleText = hasDraft
        ? context.strings.format('Draft: {text}', {
            'text': compactDraftText(draft.previewText, max: 72),
          })
        : fallbackSubtitle;
    return GestureDetector(
      onSecondaryTap: onLongPress,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 5),
        color: selected ? colors.secondaryContainer : null,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: _RoundedInkClip(
          child: ListTile(
            selected: selected,
            selectedColor: colors.onSecondaryContainer,
            selectedTileColor: colors.secondaryContainer,
            onTap: onTap,
            onLongPress: onLongPress,
            leading: _ConversationAvatarHero(
              conversation: conversation,
              radius: 22,
            ),
            title: Row(
              children: [
                if (preference.pinned) ...[
                  Icon(Icons.push_pin, size: 15, color: colors.primary),
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
            subtitle: Text(
              subtitleText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: hasDraft ? TextStyle(color: colors.primary) : null,
            ),
            trailing: conversation.unreadCount > 0
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (preference.muted) ...[
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 18,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Badge(
                        backgroundColor: preference.muted
                            ? colors.surfaceContainerHighest
                            : null,
                        textColor: preference.muted
                            ? colors.onSurfaceVariant
                            : null,
                        label: Text('${conversation.unreadCount}'),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (preference.muted)
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 18,
                          color: colors.onSurfaceVariant,
                        ),
                      if (preference.archived) ...[
                        if (preference.muted) const SizedBox(width: 8),
                        Icon(
                          Icons.archive_outlined,
                          size: 18,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
