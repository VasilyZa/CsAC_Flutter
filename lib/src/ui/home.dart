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
    }
    lastUnreadChats = after;
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
    if (wide) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: (value) {
                  setState(() => index = value);
                  if (value == 0) {
                    widget.state.loadConversations();
                  }
                  if (value == 2) {
                    widget.state.refreshNotificationCounts();
                  }
                },
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 18),
                  child: Icon(
                    Icons.forum_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                destinations: [
                  NavigationRailDestination(
                    icon: _BadgeIcon(
                      icon: Icons.chat_bubble_outline,
                      count: unreadChats,
                    ),
                    selectedIcon: _BadgeIcon(
                      icon: Icons.chat_bubble,
                      count: unreadChats,
                    ),
                    label: Text(context.strings.text('Chats')),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.manage_search_outlined),
                    selectedIcon: const Icon(Icons.manage_search),
                    label: Text(context.strings.text('Search')),
                  ),
                  NavigationRailDestination(
                    icon: _BadgeIcon(
                      icon: Icons.notifications_none,
                      count: noticeCount,
                    ),
                    selectedIcon: _BadgeIcon(
                      icon: Icons.notifications,
                      count: noticeCount,
                    ),
                    label: Text(context.strings.text('Notices')),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.person_outline),
                    selectedIcon: const Icon(Icons.person),
                    label: Text(context.strings.text('Me')),
                  ),
                ],
              ),
              const VerticalDivider(width: 1),
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
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) {
          setState(() => index = value);
          if (value == 0) {
            widget.state.loadConversations();
          }
          if (value == 2) {
            widget.state.refreshNotificationCounts();
          }
        },
        destinations: [
          NavigationDestination(
            icon: _BadgeIcon(
              icon: Icons.chat_bubble_outline,
              count: unreadChats,
            ),
            selectedIcon: _BadgeIcon(
              icon: Icons.chat_bubble,
              count: unreadChats,
            ),
            label: context.strings.text('Chats'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.manage_search_outlined),
            selectedIcon: const Icon(Icons.manage_search),
            label: context.strings.text('Search'),
          ),
          NavigationDestination(
            icon: _BadgeIcon(
              icon: Icons.notifications_none,
              count: noticeCount,
            ),
            selectedIcon: _BadgeIcon(
              icon: Icons.notifications,
              count: noticeCount,
            ),
            label: context.strings.text('Notices'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: context.strings.text('Me'),
          ),
        ],
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
        const VerticalDivider(width: 1),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              context.strings.text('Select a conversation'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    final child = Icon(icon);
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
      if (mounted) {
        setState(() => refreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.state.user;
    final strings = context.strings;
    final query = search.text.trim().toLowerCase();
    final conversations = query.isEmpty
        ? widget.state.conversations
        : widget.state.conversations.where((conversation) {
            final target =
                '${conversation.name} ${conversation.subtitle} ${conversation.searchText}'
                    .toLowerCase();
            return target.contains(query);
          }).toList();
    final content = RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    user == null
                        ? strings.text('Not logged in')
                        : '${user.nickname} / UID ${user.uid}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.state.offlineMode)
                  Chip(
                    avatar: const Icon(Icons.cloud_off_outlined, size: 18),
                    label: Text(strings.text('Offline')),
                  ),
                IconButton.filledTonal(
                  tooltip: strings.text('Add friend'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AddFriendScreen(state: widget.state),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_add_alt),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: strings.text('Join group'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => JoinGroupScreen(state: widget.state),
                      ),
                    );
                  },
                  icon: const Icon(Icons.group_add_outlined),
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
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: strings.text('Clear'),
                        onPressed: () {
                          search.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          if (widget.state.conversations.isEmpty)
            _EmptyPanel(message: strings.text('No conversations yet.'))
          else if (conversations.isEmpty)
            _EmptyPanel(message: strings.text('No matching conversations.'))
          else
            for (final conversation in conversations)
              _ConversationTile(
                conversation: conversation,
                selected:
                    widget.selectedConversation?.type == conversation.type &&
                    widget.selectedConversation?.id == conversation.id,
                onTap: () async {
                  if (widget.onConversationSelected != null) {
                    widget.onConversationSelected!(conversation);
                    return;
                  }
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ChatScreen(
                        state: widget.state,
                        conversation: conversation,
                      ),
                    ),
                  );
                  if (mounted) {
                    refresh();
                  }
                },
              ),
        ],
      ),
    );
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('CsAC'),
              actions: [
                IconButton(
                  tooltip: strings.text('Refresh'),
                  onPressed: refreshing ? null : refresh,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: strings.text('Search messages'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            MessageSearchScreen(state: widget.state),
                      ),
                    );
                  },
                  icon: const Icon(Icons.manage_search),
                ),
                IconButton(
                  tooltip: strings.text('Logout'),
                  onPressed: widget.state.logout,
                  icon: const Icon(Icons.logout),
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
    this.selected = false,
  });

  final Conversation conversation;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isGroup = conversation.type == ConversationType.group;
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      color: selected ? colors.secondaryContainer : null,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        selected: selected,
        selectedColor: colors.onSecondaryContainer,
        selectedTileColor: colors.secondaryContainer,
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: isGroup
              ? colors.secondaryContainer
              : colors.primaryContainer,
          child: Icon(
            isGroup ? Icons.groups_rounded : Icons.person_rounded,
            color: isGroup
                ? colors.onSecondaryContainer
                : colors.onPrimaryContainer,
          ),
        ),
        title: Text(
          conversation.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          conversation.subtitle.isEmpty
              ? context.strings.text(isGroup ? 'Group chat' : 'Private chat')
              : conversation.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: conversation.unreadCount > 0
            ? Badge(label: Text('${conversation.unreadCount}'))
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
