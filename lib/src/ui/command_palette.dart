part of '../../main.dart';

class _DesktopCommandPaletteHost extends StatefulWidget {
  const _DesktopCommandPaletteHost({
    required this.state,
    required this.navigatorKey,
    required this.scaffoldMessengerKey,
    required this.enabled,
    required this.child,
  });

  final CsacAppState state;
  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<CsacToastMessengerState> scaffoldMessengerKey;
  final bool enabled;
  final Widget child;

  @override
  State<_DesktopCommandPaletteHost> createState() =>
      _DesktopCommandPaletteHostState();
}

class _DesktopCommandPaletteHostState
    extends State<_DesktopCommandPaletteHost> {
  bool openingPalette = false;

  Future<void> openPalette() async {
    if (!widget.enabled || openingPalette) {
      return;
    }
    final navigator = widget.navigatorKey.currentState;
    final overlayContext = navigator?.overlay?.context;
    if (navigator == null || overlayContext == null) {
      return;
    }
    setState(() => openingPalette = true);
    try {
      await showGeneralDialog<void>(
        context: overlayContext,
        barrierDismissible: true,
        barrierLabel: context.strings.text('Dismiss'),
        barrierColor: Colors.transparent,
        transitionDuration: Duration.zero,
        pageBuilder: (dialogContext, _, _) {
          return _CommandPaletteOverlay(
            state: widget.state,
            navigatorKey: widget.navigatorKey,
            scaffoldMessengerKey: widget.scaffoldMessengerKey,
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => openingPalette = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(
        LogicalKeyboardKey.keyP,
        control: true,
        shift: true,
      ): openPalette,
      const SingleActivator(LogicalKeyboardKey.keyP, meta: true, shift: true):
          openPalette,
    };
    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        canRequestFocus: widget.enabled,
        child: widget.child,
      ),
    );
  }
}

class _CommandPaletteOverlay extends StatefulWidget {
  const _CommandPaletteOverlay({
    required this.state,
    required this.navigatorKey,
    required this.scaffoldMessengerKey,
  });

  final CsacAppState state;
  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<CsacToastMessengerState> scaffoldMessengerKey;

  @override
  State<_CommandPaletteOverlay> createState() => _CommandPaletteOverlayState();
}

class _CommandPaletteOverlayState extends State<_CommandPaletteOverlay> {
  late final TextEditingController search;
  late final FocusNode focusNode;
  late final ScrollController actionsScroll;
  Map<String, CommandPaletteUsage> usage =
      const <String, CommandPaletteUsage>{};
  bool running = false;
  String query = '';

  @override
  void initState() {
    super.initState();
    search = TextEditingController();
    focusNode = FocusNode();
    actionsScroll = _desktopSmoothScrollController();
    unawaited(loadUsage());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    search.dispose();
    focusNode.dispose();
    actionsScroll.dispose();
    super.dispose();
  }

  Future<void> loadUsage() async {
    final loaded = await CommandPaletteUsageStore.loadAll();
    if (mounted) {
      setState(() => usage = loaded);
    }
  }

  List<_CommandPaletteAction> actions(BuildContext context) {
    final strings = context.strings;
    final active = widget.state.activeConversation;
    return [
      _CommandPaletteAction(
        id: 'settings',
        icon: Icons.settings_outlined,
        title: strings.text('Settings'),
        subtitle: strings.text('Open app settings'),
        keywords: const ['settings', 'setting', 'preferences', '设置'],
        run: (context) =>
            openRoute(SettingsScreen(state: widget.state), context),
      ),
      _CommandPaletteAction(
        id: 'search_messages',
        icon: Icons.manage_search,
        title: strings.text('Search messages'),
        subtitle: strings.text('Search cached messages'),
        keywords: const ['search', 'messages', 'history', '搜索', '消息'],
        run: (context) =>
            openRoute(MessageSearchScreen(state: widget.state), context),
      ),
      _CommandPaletteAction(
        id: 'clear_local_cache',
        icon: Icons.cleaning_services_outlined,
        title: strings.text('Clear local cache'),
        subtitle: strings.text(
          'Remove cached conversations and message history',
        ),
        keywords: const ['clear', 'cache', 'clean', '缓存', '清理'],
        run: clearLocalCache,
      ),
      _CommandPaletteAction(
        id: 'theme_light',
        icon: Icons.light_mode_outlined,
        title: strings.text('Switch to light theme'),
        subtitle: strings.text('Theme'),
        keywords: const ['theme', 'light', '浅色', '主题'],
        run: (context) => switchTheme(ThemeMode.light, context),
      ),
      _CommandPaletteAction(
        id: 'theme_dark',
        icon: Icons.dark_mode_outlined,
        title: strings.text('Switch to dark theme'),
        subtitle: strings.text('Theme'),
        keywords: const ['theme', 'dark', '深色', '主题'],
        run: (context) => switchTheme(ThemeMode.dark, context),
      ),
      _CommandPaletteAction(
        id: 'theme_system',
        icon: Icons.brightness_auto_outlined,
        title: strings.text('Follow system theme'),
        subtitle: strings.text('Theme'),
        keywords: const ['theme', 'system', 'auto', '系统', '主题'],
        run: (context) => switchTheme(ThemeMode.system, context),
      ),
      _CommandPaletteAction(
        id: 'refresh_conversations',
        icon: Icons.sync,
        title: strings.text('Refresh conversations'),
        subtitle: strings.text('Chats'),
        keywords: const ['refresh', 'reload', 'sync', '刷新', '同步'],
        run: refreshConversations,
      ),
      _CommandPaletteAction(
        id: 'add_friend',
        icon: Icons.person_add_alt,
        title: strings.text('Add friend'),
        subtitle: strings.text('User UID'),
        keywords: const ['friend', 'add', 'uid', '好友', '添加'],
        run: (context) =>
            openRoute(AddFriendScreen(state: widget.state), context),
      ),
      _CommandPaletteAction(
        id: 'join_group',
        icon: Icons.group_add_outlined,
        title: strings.text('Join group'),
        subtitle: strings.text('Room ID'),
        keywords: const ['group', 'join', 'room', '群', '加入'],
        run: (context) =>
            openRoute(JoinGroupScreen(state: widget.state), context),
      ),
      _CommandPaletteAction(
        id: 'create_group',
        icon: Icons.add_home_work_outlined,
        title: strings.text('Create group'),
        subtitle: strings.text('Group chat'),
        keywords: const ['group', 'create', 'room', '群', '创建'],
        run: (context) =>
            openRoute(CreateGroupScreen(state: widget.state), context),
      ),
      _CommandPaletteAction(
        id: 'api_explorer',
        icon: Icons.api_outlined,
        title: strings.text('API explorer'),
        subtitle: '/api',
        keywords: const ['api', '/api', '接口', '文档'],
        run: (context) =>
            openRoute(ApiExplorerScreen(state: widget.state), context),
      ),
      _CommandPaletteAction(
        id: 'app_logs',
        icon: Icons.article_outlined,
        title: strings.text('App logs'),
        subtitle: '/log',
        keywords: const ['log', '/log', 'logs', '日志'],
        run: (context) =>
            openRoute(AppLogsScreen(state: widget.state), context),
      ),
      _CommandPaletteAction(
        id: 'network_diagnostics',
        icon: Icons.network_check_outlined,
        title: strings.text('Connection diagnostics'),
        subtitle: '/diag',
        keywords: const ['diag', '/diag', 'network', 'diagnostics', '诊断', '网络'],
        run: (context) =>
            openRoute(NetworkDiagnosticsScreen(state: widget.state), context),
      ),
      if (active != null)
        _CommandPaletteAction(
          id: 'active_details:${active.type.name}:${active.id}',
          icon: active.type == ConversationType.group
              ? Icons.groups_outlined
              : Icons.person_outline,
          title: strings.format('Open {name} details', {'name': active.name}),
          subtitle: strings.text(
            active.type == ConversationType.group
                ? 'Group chat'
                : 'Private chat',
          ),
          keywords: ['details', 'profile', 'group', '资料', '群资料', active.name],
          run: (context) => openConversationDetails(active, context),
        ),
    ];
  }

  List<_CommandPaletteAction> filteredActions(
    BuildContext context,
    String value,
  ) {
    final normalized = value.trim().toLowerCase();
    final all = actions(context);
    if (normalized.startsWith('@')) {
      return contactActions(context, normalized.substring(1));
    }
    if (normalized.startsWith('#')) {
      return groupActions(context, normalized.substring(1));
    }
    if (normalized.startsWith('/')) {
      return prefixActions(context, normalized);
    }
    if (normalized.isEmpty) {
      return sortedActions(all);
    }
    return sortedActions(
      all.where((action) => action.matches(normalized)).toList(),
    );
  }

  List<_CommandPaletteAction> prefixActions(
    BuildContext context,
    String value,
  ) {
    final slashCommands = actions(context)
        .where(
          (action) => action.keywords.any((keyword) => keyword.startsWith('/')),
        )
        .toList();
    return sortedActions(
      slashCommands.where((action) => action.matches(value)).toList(),
    );
  }

  List<_CommandPaletteAction> contactActions(
    BuildContext context,
    String value,
  ) {
    final strings = context.strings;
    final query = value.trim().toLowerCase();
    final conversations = widget.state.conversations.where(
      (conversation) => conversation.type == ConversationType.private,
    );
    final byName = conversations
        .where((conversation) {
          if (query.isEmpty) {
            return true;
          }
          return [
            conversation.name,
            conversation.subtitle,
            conversation.searchText,
            '${conversation.id}',
          ].join(' ').toLowerCase().contains(query);
        })
        .map((conversation) {
          return _CommandPaletteAction(
            id: 'open_user:${conversation.id}',
            icon: Icons.person_outline,
            title: '@${conversation.name}',
            subtitle: strings.format('Open {name} profile', {
              'name': conversation.name,
            }),
            keywords: [
              '@${conversation.name}',
              conversation.name,
              conversation.subtitle,
              conversation.searchText,
              '${conversation.id}',
            ],
            run: (context) => openConversationDetails(conversation, context),
          );
        })
        .toList();
    final uid = int.tryParse(query);
    if (uid != null &&
        uid > 0 &&
        !byName.any((action) => action.id == 'open_user:$uid')) {
      byName.insert(
        0,
        _CommandPaletteAction(
          id: 'open_user:$uid',
          icon: Icons.tag,
          title: '@UID $uid',
          subtitle: strings.text('Open user profile by UID'),
          keywords: ['@$uid', '$uid', 'uid'],
          run: (context) => openUserProfileByUid(uid, context),
        ),
      );
    }
    return sortedActions(byName);
  }

  List<_CommandPaletteAction> groupActions(BuildContext context, String value) {
    final strings = context.strings;
    final query = value.trim().toLowerCase();
    final actions = widget.state.conversations
        .where((conversation) => conversation.type == ConversationType.group)
        .where((conversation) {
          if (query.isEmpty) {
            return true;
          }
          return [
            conversation.name,
            conversation.subtitle,
            conversation.searchText,
            '${conversation.id}',
          ].join(' ').toLowerCase().contains(query);
        })
        .map(
          (conversation) => _CommandPaletteAction(
            id: 'open_group:${conversation.id}',
            icon: Icons.groups_outlined,
            title: '#${conversation.name}',
            subtitle: strings.format('Open {name} chat', {
              'name': conversation.name,
            }),
            keywords: [
              '#${conversation.name}',
              conversation.name,
              conversation.subtitle,
              conversation.searchText,
              '${conversation.id}',
            ],
            run: (context) => openChat(conversation, context),
          ),
        )
        .toList();
    return sortedActions(actions);
  }

  List<_CommandPaletteAction> sortedActions(List<_CommandPaletteAction> input) {
    final result = input.toList();
    result.sort((a, b) {
      final aUsage = usage[a.id];
      final bUsage = usage[b.id];
      final aUsed = aUsage != null;
      final bUsed = bUsage != null;
      if (aUsed != bUsed) {
        return aUsed ? -1 : 1;
      }
      if (aUsage != null && bUsage != null) {
        final count = bUsage.count.compareTo(aUsage.count);
        if (count != 0) {
          return count;
        }
        return bUsage.lastUsedAt.compareTo(aUsage.lastUsedAt);
      }
      return 0;
    });
    return result;
  }

  Future<void> runAction(_CommandPaletteAction action) async {
    if (running) {
      return;
    }
    final navigator = widget.navigatorKey.currentState;
    final messenger = widget.scaffoldMessengerKey.currentState;
    final strings = context.strings;
    setState(() => running = true);
    Navigator.of(context).pop();
    try {
      await CommandPaletteUsageStore.record(action.id);
      await action.run(
        _CommandPaletteActionContext(
          navigator: navigator,
          messenger: messenger,
          strings: strings,
        ),
      );
    } catch (err) {
      messenger?.showToast(
        CsacToast(
          content: Text(
            strings.format('Command failed: {error}', {'error': err}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => running = false);
      }
    }
  }

  Future<void> openRoute(
    Widget screen,
    _CommandPaletteActionContext context,
  ) async {
    if (context.navigator == null) {
      return;
    }
    await context.navigator!.push(CsacPageRoute<void>(builder: (_) => screen));
  }

  Future<void> clearLocalCache(_CommandPaletteActionContext context) async {
    final navigator = context.navigator;
    if (navigator == null) {
      return;
    }
    final confirmed = await showCupertinoCsacDialog<bool>(
      context: navigator.context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.strings.text('Clear local cache?')),
        content: Text(
          context.strings.text(
            'Cached conversations and message history on this device will be removed. Your login session will be kept.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.strings.text('Clear')),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await widget.state.clearLocalCache();
    context.messenger?.showToast(
      CsacToast(content: Text(context.strings.text('Local cache cleared.'))),
    );
  }

  Future<void> switchTheme(
    ThemeMode mode,
    _CommandPaletteActionContext context,
  ) async {
    await widget.state.updateThemeMode(mode);
    context.messenger?.showToast(
      CsacToast(content: Text(context.strings.text('Theme updated.'))),
    );
  }

  Future<void> refreshConversations(
    _CommandPaletteActionContext context,
  ) async {
    await widget.state.refreshHome();
    context.messenger?.showToast(
      CsacToast(content: Text(context.strings.text('Refreshed.'))),
    );
  }

  Future<void> openConversationDetails(
    Conversation conversation,
    _CommandPaletteActionContext context,
  ) async {
    final navigator = context.navigator;
    if (navigator == null) {
      return;
    }
    if (conversation.type == ConversationType.private) {
      await navigator.push(
        CsacPageRoute<void>(
          builder: (_) => UserProfileScreen(
            state: widget.state,
            uid: conversation.id,
            avatarHeroTag: conversationAvatarHeroTag(conversation),
          ),
        ),
      );
      return;
    }
    await openRoute(
      ConversationDetailScreen(state: widget.state, conversation: conversation),
      context,
    );
  }

  Future<void> openUserProfileByUid(
    int uid,
    _CommandPaletteActionContext context,
  ) async {
    final navigator = context.navigator;
    if (navigator == null) {
      return;
    }
    await navigator.push(
      CsacPageRoute<void>(
        builder: (_) => UserProfileScreen(state: widget.state, uid: uid),
      ),
    );
  }

  Future<void> openChat(
    Conversation conversation,
    _CommandPaletteActionContext context,
  ) async {
    final navigator = context.navigator;
    if (navigator == null) {
      return;
    }
    await navigator.push(
      CsacPageRoute<void>(
        builder: (_) =>
            ChatScreen(state: widget.state, conversation: conversation),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final csacColors = CsacColors.of(context);
    final reduceMotion = _MotionPreference.reduceOf(context);
    final matches = filteredActions(context, query);
    final panel = ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: csacColors.cardBackground.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: csacColors.separator.withValues(alpha: 0.32),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 660, maxHeight: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: Row(
                    children: [
                      Icon(Icons.terminal_rounded, color: colors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CsacTextField(
                          controller: search,
                          focusNode: focusNode,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          onChanged: (value) => setState(() => query = value),
                          onSubmitted: (_) {
                            if (matches.isNotEmpty) {
                              unawaited(runAction(matches.first));
                            }
                          },
                          decoration: InputDecoration(
                            hintText: context.strings.text('Type a command'),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                          ),
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: 12),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            'Esc',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                CsacDivider(height: 1, color: colors.outlineVariant),
                Flexible(
                  child: matches.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(28),
                          child: Text(
                            context.strings.text('No matching commands.'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        )
                      : CsacListView.separated(
                          controller: actionsScroll,
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: matches.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 2),
                          itemBuilder: (context, index) {
                            final action = matches[index];
                            return _CommandPaletteTile(
                              action: action,
                              usage: usage[action.id],
                              autofocus: index == 0,
                              onTap: () => unawaited(runAction(action)),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).pop();
        },
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: ColoredBox(color: colors.scrim.withValues(alpha: 0.42)),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: reduceMotion
                      ? panel
                      : panel
                            .animate()
                            .fadeIn(
                              duration: 140.ms,
                              curve: Curves.easeOutCubic,
                            )
                            .slideY(
                              begin: -0.025,
                              end: 0,
                              duration: 220.ms,
                              curve: Curves.easeOutCubic,
                            )
                            .scale(
                              begin: const Offset(0.985, 0.985),
                              end: const Offset(1, 1),
                              duration: 240.ms,
                              curve: Curves.easeOutCubic,
                            ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandPaletteTile extends StatelessWidget {
  const _CommandPaletteTile({
    required this.action,
    required this.onTap,
    this.usage,
    this.autofocus = false,
  });

  final _CommandPaletteAction action;
  final VoidCallback onTap;
  final CommandPaletteUsage? usage;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Focus(
        autofocus: autofocus,
        child: _CsacPressable(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: colors.fill.withValues(alpha: 0.18),
            ),
            child: Row(
              children: [
                Icon(
                  action.icon,
                  color: CupertinoTheme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        action.title,
                        style: TextStyle(
                          color: colors.label,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        action.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.secondaryLabel,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _CommandPaletteTileTrailing(usage: usage),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommandPaletteTileTrailing extends StatelessWidget {
  const _CommandPaletteTileTrailing({required this.usage});

  final CommandPaletteUsage? usage;

  @override
  Widget build(BuildContext context) {
    final usage = this.usage;
    if (usage == null) {
      return const Icon(Icons.keyboard_return_rounded);
    }
    final colors = Theme.of(context).colorScheme;
    final strings = context.strings;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            usage.count > 1
                ? strings.format('Used {count} times', {'count': usage.count})
                : strings.text('Recent'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSecondaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.keyboard_return_rounded),
      ],
    );
  }
}

class _CommandPaletteAction {
  const _CommandPaletteAction({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.keywords,
    required this.run,
  });

  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final Iterable<String> keywords;
  final Future<void> Function(_CommandPaletteActionContext context) run;

  bool matches(String query) {
    final target = <String>[
      title,
      subtitle,
      ...keywords,
    ].join(' ').toLowerCase();
    return target.contains(query);
  }
}

class _CommandPaletteActionContext {
  const _CommandPaletteActionContext({
    required this.navigator,
    required this.messenger,
    required this.strings,
  });

  final NavigatorState? navigator;
  final CsacToastMessengerState? messenger;
  final CsacStrings strings;
}
