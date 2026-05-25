import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import 'src/app_state.dart';
import 'src/l10n.dart';
import 'src/models.dart';
import 'src/preferences.dart';

void main() {
  runApp(const CsacMobileApp());
}

class CsacMobileApp extends StatefulWidget {
  const CsacMobileApp({super.key});

  @override
  State<CsacMobileApp> createState() => _CsacMobileAppState();
}

class _CsacMobileAppState extends State<CsacMobileApp> {
  late final CsacAppState state;

  @override
  void initState() {
    super.initState();
    state = CsacAppState()..initialize();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return MaterialApp(
          title: CsacStrings(
            localeForLanguage(state.preferences.language),
          ).text('CsAC Mobile'),
          debugShowCheckedModeBanner: false,
          locale: localeForLanguage(state.preferences.language),
          supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
          localizationsDelegates: const [
            CsacStringsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          theme: buildCsacTheme(Brightness.light),
          darkTheme: buildCsacTheme(Brightness.dark),
          themeMode: state.preferences.themeMode,
          home: state.bootstrapping
              ? SplashScreen(status: state.restoreStatus)
              : state.user == null
              ? LoginScreen(state: state)
              : MainShell(state: state),
        );
      },
    );
  }
}

ThemeData buildCsacTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: isDark ? const Color(0xff55c7ad) : const Color(0xff1f8a70),
    brightness: brightness,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    cardColor: scheme.surfaceContainerLow,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: scheme.surfaceTint,
      elevation: 0,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      modalBackgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        base.textTheme.labelMedium?.copyWith(color: scheme.onSurface),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: scheme.surfaceContainerHighest,
      selectedColor: scheme.secondaryContainer,
      labelStyle: TextStyle(color: scheme.onSurface),
      secondaryLabelStyle: TextStyle(color: scheme.onSecondaryContainer),
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      actionTextColor: scheme.inversePrimary,
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      subtitleTextStyle: base.textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
    ),
  );
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_rounded,
              size: 54,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              context.strings.text('CsAC Mobile'),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(status),
            const SizedBox(height: 18),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  String? error;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final name = username.text.trim();
    if (name.isEmpty || password.text.isEmpty) {
      setState(
        () =>
            error = context.strings.text('Username and password are required.'),
      );
      return;
    }
    try {
      await widget.state.login(name, password.text);
    } catch (err) {
      setState(() => error = err.toString());
    }
  }

  Future<void> openServerSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          state: widget.state,
          initialDeveloperOptionsExpanded: true,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final serverUrl = widget.state.preferences.serverUrl.trim().isEmpty
        ? strings.text('Default server')
        : widget.state.preferences.serverUrl.trim();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.forum_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.text('CsAC Mobile'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: username,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: strings.text('Username'),
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: password,
                    obscureText: true,
                    onSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      labelText: strings.text('Password'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: widget.state.loading ? null : submit,
                    icon: widget.state.loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(strings.text('Login')),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: openServerSettings,
                    icon: const Icon(Icons.developer_mode_outlined),
                    label: Text(strings.text('Developer options')),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.format('Current server: {server}', {
                      'server': serverUrl,
                    }),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
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

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final uid = TextEditingController();
  final message = TextEditingController(text: '请求添加你为好友');
  UserProfile? preview;
  bool sending = false;
  bool searching = false;
  String? error;

  @override
  void dispose() {
    uid.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> lookup() async {
    final target = int.tryParse(uid.text.trim()) ?? 0;
    if (target <= 0) {
      setState(() => error = context.strings.text('Enter a valid UID.'));
      return;
    }
    setState(() {
      searching = true;
      error = null;
      preview = null;
    });
    try {
      final loaded = await widget.state.loadUserProfile(target);
      if (!mounted) {
        return;
      }
      setState(() => preview = loaded);
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => searching = false);
      }
    }
  }

  Future<void> submit() async {
    final target = int.tryParse(uid.text.trim()) ?? 0;
    if (target <= 0) {
      setState(() => error = context.strings.text('Enter a valid UID.'));
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await widget.state.sendFriendRequest(target, message.text);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Friend request sent.'))),
      );
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.text('Add friend'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            TextField(
              controller: uid,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => lookup(),
              decoration: InputDecoration(
                labelText: context.strings.text('User UID'),
                prefixIcon: const Icon(Icons.tag),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: searching ? null : lookup,
              icon: searching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(context.strings.text('Lookup user')),
            ),
            if (preview != null) ...[
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                child: ListTile(
                  leading: _Avatar(
                    url: preview!.avatar,
                    fallback: Icons.person_rounded,
                  ),
                  title: Text(preview!.displayName),
                  subtitle: Text(
                    preview!.subtitle.isEmpty
                        ? 'UID ${preview!.uid}'
                        : preview!.subtitle,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: message,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.strings.text('Request message'),
                prefixIcon: const Icon(Icons.message_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: sending ? null : submit,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(context.strings.text('Send request')),
            ),
          ],
        ),
      ),
    );
  }
}

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final roomId = TextEditingController();
  final code = TextEditingController();
  final answer = TextEditingController();
  final search = TextEditingController();
  List<GroupProfile> publicGroups = const <GroupProfile>[];
  bool loading = true;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadPublicGroups();
  }

  @override
  void dispose() {
    roomId.dispose();
    code.dispose();
    answer.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> loadPublicGroups() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget.state.loadPublicGroups();
      if (!mounted) {
        return;
      }
      setState(() => publicGroups = loaded);
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

  Future<void> submit({int? groupId}) async {
    final target = groupId ?? int.tryParse(roomId.text.trim()) ?? 0;
    if (target <= 0) {
      setState(() => error = context.strings.text('Enter a valid room ID.'));
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await widget.state.applyJoinGroup(
        target,
        code: code.text,
        answer: answer.text,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Join request sent.'))),
      );
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  void useGroup(GroupProfile group) {
    roomId.text = '${group.id}';
    if (group.code.isNotEmpty) {
      code.text = group.code;
    }
    if (group.question.isNotEmpty) {
      answer.selection = TextSelection.collapsed(offset: answer.text.length);
    }
  }

  List<GroupProfile> filteredPublicGroups() {
    final query = search.text.trim().toLowerCase();
    if (query.isEmpty) {
      return publicGroups;
    }
    return publicGroups.where((group) {
      final target =
          '${group.id} ${group.name} ${group.subtitle} ${group.description} ${group.notice}'
              .toLowerCase();
      return target.contains(query);
    }).toList();
  }

  void openGroupDetail(GroupProfile group) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConversationDetailScreen(
          state: widget.state,
          conversation: Conversation(
            type: ConversationType.group,
            id: group.id,
            name: group.name,
            subtitle: group.subtitle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.strings.text('Join group')),
        actions: [
          IconButton(
            tooltip: context.strings.text('Refresh'),
            onPressed: loading ? null : loadPublicGroups,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadPublicGroups,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              TextField(
                controller: roomId,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.strings.text('Room ID'),
                  prefixIcon: const Icon(Icons.tag),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: code,
                decoration: InputDecoration(
                  labelText: context.strings.text('Invite code'),
                  prefixIcon: const Icon(Icons.key_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: answer,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: context.strings.text('Answer'),
                  prefixIcon: const Icon(Icons.question_answer_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: sending ? null : submit,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.group_add),
                label: Text(context.strings.text('Apply to join')),
              ),
              const SizedBox(height: 20),
              Text(
                context.strings.text('Public groups'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: context.strings.text('Search public groups'),
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              if (loading)
                const LinearProgressIndicator(minHeight: 2)
              else if (filteredPublicGroups().isEmpty)
                _EmptyPanel(message: context.strings.text('No public groups.'))
              else
                for (final group in filteredPublicGroups())
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.secondaryContainer,
                        child: Icon(
                          Icons.groups_rounded,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                        ),
                      ),
                      title: Text(group.name),
                      subtitle: Text(
                        [
                          context.strings.format('Room {id}', {'id': group.id}),
                          group.subtitle,
                          group.description,
                        ].where((part) => part.isNotEmpty).join(' | '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: TextButton(
                        onPressed: sending
                            ? null
                            : () {
                                useGroup(group);
                                submit(groupId: group.id);
                              },
                        child: Text(context.strings.text('Join')),
                      ),
                      onTap: () => useGroup(group),
                      onLongPress: () => openGroupDetail(group),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class MessageSearchScreen extends StatefulWidget {
  const MessageSearchScreen({
    super.key,
    required this.state,
    this.embedded = false,
  });

  final CsacAppState state;
  final bool embedded;

  @override
  State<MessageSearchScreen> createState() => _MessageSearchScreenState();
}

class _MessageSearchScreenState extends State<MessageSearchScreen> {
  final search = TextEditingController();
  SearchScope scope = SearchScope.all;
  List<MessageSearchResult> results = const <MessageSearchResult>[];
  bool loading = false;
  String? error;
  Timer? debounce;

  @override
  void initState() {
    super.initState();
    runSearch();
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  void scheduleSearch() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 250), runSearch);
  }

  Future<void> runSearch() async {
    setState(() {});
    final query = search.text.trim();
    if (query.isEmpty &&
        scope != SearchScope.image &&
        scope != SearchScope.essence) {
      setState(() {
        results = const <MessageSearchResult>[];
        loading = false;
        error = null;
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget.state.searchMessages(query, scope);
      if (!mounted) {
        return;
      }
      setState(() => results = loaded);
    } catch (err) {
      if (!mounted) {
        return;
      }
      setState(() => error = err.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void setScope(SearchScope value) {
    setState(() => scope = value);
    runSearch();
  }

  Future<void> openResult(MessageSearchResult result) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          state: widget.state,
          conversation: result.conversation,
          focusMessageId: result.message.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            controller: search,
            onChanged: (_) => scheduleSearch(),
            autofocus: true,
            decoration: InputDecoration(
              hintText: strings.text('Search cached messages'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: search.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: strings.text('Clear'),
                      onPressed: () {
                        search.clear();
                        runSearch();
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            children: [
              _ScopeChip(
                label: strings.text('All'),
                selected: scope == SearchScope.all,
                onSelected: () => setScope(SearchScope.all),
              ),
              _ScopeChip(
                label: strings.text('Friends'),
                selected: scope == SearchScope.private,
                onSelected: () => setScope(SearchScope.private),
              ),
              _ScopeChip(
                label: strings.text('Groups'),
                selected: scope == SearchScope.group,
                onSelected: () => setScope(SearchScope.group),
              ),
              _ScopeChip(
                label: strings.text('Images'),
                selected: scope == SearchScope.image,
                onSelected: () => setScope(SearchScope.image),
              ),
              _ScopeChip(
                label: strings.text('Essence'),
                selected: scope == SearchScope.essence,
                onSelected: () => setScope(SearchScope.essence),
              ),
            ],
          ),
        ),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if (error != null)
          MaterialBanner(
            content: Text(error!),
            actions: [
              TextButton(
                onPressed: () => setState(() => error = null),
                child: Text(strings.text('Dismiss')),
              ),
            ],
          ),
        Expanded(
          child: results.isEmpty
              ? _EmptyPanel(
                  message:
                      search.text.trim().isEmpty &&
                          scope != SearchScope.image &&
                          scope != SearchScope.essence
                      ? strings.text('Type to search cached messages.')
                      : strings.text('No matching messages.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final result = results[index];
                    return _SearchResultTile(
                      result: result,
                      onTap: () => openResult(result),
                    );
                  },
                ),
        ),
      ],
    );
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: Text(strings.text('Search messages'))),
      body: SafeArea(top: widget.embedded, child: body),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.result, required this.onTap});

  final MessageSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isGroup = result.conversation.type == ConversationType.group;
    final message = result.message;
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
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
          result.conversation.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${message.sender}${message.time.isEmpty ? '' : ' · ${message.time}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(result.snippet, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: message.imageUrl.isNotEmpty
            ? const Icon(Icons.image_outlined)
            : message.isEssence
            ? const Icon(Icons.star_outline)
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class NoticeCenterScreen extends StatelessWidget {
  const NoticeCenterScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  Widget build(BuildContext context) {
    final counts = state.notificationCounts;
    final strings = context.strings;
    return DefaultTabController(
      length: 3,
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
            FriendRequestsPage(state: state),
            GroupApplicationsPage(state: state),
          ],
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
    this.onAgree,
    this.onRefuse,
  });

  final FriendRequest request;
  final bool acting;
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
              trailing: _StatusChip(pending: request.pending),
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
    this.onPass,
    this.onRefuse,
  });

  final GroupApplication application;
  final bool acting;
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
              trailing: _StatusChip(pending: application.pending),
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

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  Widget build(BuildContext context) {
    final user = state.user;
    final counts = state.notificationCounts;
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('Me'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (state.sessionExpired)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MaterialBanner(
                  content: Text(
                    strings.text(
                      'Session expired. Log in again to sync latest data.',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: state.logout,
                      child: Text(strings.text('Login')),
                    ),
                  ],
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _Avatar(
                url: user?.avatar ?? '',
                fallback: Icons.person_rounded,
              ),
              title: Text(user?.nickname ?? strings.text('Not logged in')),
              subtitle: Text(
                [
                  if (user?.username.isNotEmpty == true) '@${user!.username}',
                  if (user != null) 'UID ${user.uid}',
                  if (user?.onlineStatus.isNotEmpty == true) user!.onlineStatus,
                ].join(' | '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: user == null
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AccountScreen(state: state),
                        ),
                      );
                    },
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_none),
                    title: Text(strings.text('Unread notices')),
                    trailing: Badge(label: Text('${counts.notices}')),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_add_alt),
                    title: Text(strings.text('Friend requests')),
                    trailing: Badge(label: Text('${counts.friendRequests}')),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.group_add_outlined),
                    title: Text(strings.text('Group reviews')),
                    trailing: Badge(label: Text('${counts.groupApplications}')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: state.refreshHome,
              icon: const Icon(Icons.sync),
              label: Text(strings.text('Refresh all')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: user == null
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AccountScreen(state: state),
                        ),
                      );
                    },
              icon: const Icon(Icons.manage_accounts_outlined),
              label: Text(strings.text('Account')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SettingsScreen(state: state),
                  ),
                );
              },
              icon: const Icon(Icons.settings_outlined),
              label: Text(strings.text('Settings')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: state.logout,
              icon: const Icon(Icons.logout),
              label: Text(strings.text('Logout')),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final imagePicker = ImagePicker();
  bool savingName = false;
  bool savingPassword = false;
  bool savingAvatar = false;
  bool deletingAccount = false;

  Future<void> editNickname() async {
    final strings = context.strings;
    final controller = TextEditingController(
      text: widget.state.user?.nickname ?? '',
    );
    final nickname = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('Change nickname')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 16,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: strings.text('Nickname')),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(strings.text('Save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nickname == null) {
      return;
    }
    if (nickname.isEmpty) {
      showSnack(strings.text('Nickname is required.'));
      return;
    }
    setState(() => savingName = true);
    try {
      await widget.state.updateNickname(nickname);
      if (mounted) {
        showSnack(strings.text('Nickname updated.'));
      }
    } catch (err) {
      if (mounted) {
        showSnack(strings.format('Update failed: {error}', {'error': err}));
      }
    } finally {
      if (mounted) {
        setState(() => savingName = false);
      }
    }
  }

  Future<void> changePassword() async {
    final strings = context.strings;
    final oldPassword = TextEditingController();
    final newPassword = TextEditingController();
    final confirmPassword = TextEditingController();
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('Change password')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPassword,
              autofocus: true,
              obscureText: true,
              decoration: InputDecoration(
                labelText: strings.text('Current password'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPassword,
              obscureText: true,
              decoration: InputDecoration(
                labelText: strings.text('New password'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPassword,
              obscureText: true,
              decoration: InputDecoration(
                labelText: strings.text('Confirm password'),
              ),
              onSubmitted: (_) => Navigator.of(
                context,
              ).pop([oldPassword.text, newPassword.text, confirmPassword.text]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop([oldPassword.text, newPassword.text, confirmPassword.text]),
            child: Text(strings.text('Save')),
          ),
        ],
      ),
    );
    oldPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
    if (values == null) {
      return;
    }
    if (values.any((value) => value.isEmpty)) {
      showSnack(strings.text('Please fill all password fields.'));
      return;
    }
    if (values[1] != values[2]) {
      showSnack(strings.text('Passwords do not match.'));
      return;
    }
    setState(() => savingPassword = true);
    try {
      await widget.state.updatePassword(
        oldPassword: values[0],
        newPassword: values[1],
        confirmPassword: values[2],
      );
      if (mounted) {
        showSnack(strings.text('Password updated.'));
      }
    } catch (err) {
      if (mounted) {
        showSnack(strings.format('Update failed: {error}', {'error': err}));
      }
    } finally {
      if (mounted) {
        setState(() => savingPassword = false);
      }
    }
  }

  Future<void> changeAvatar() async {
    final strings = context.strings;
    final picked = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => savingAvatar = true);
    try {
      await widget.state.updateAvatar(await picked.readAsBytes(), picked.name);
      if (mounted) {
        showSnack(strings.text('Avatar updated.'));
      }
    } catch (err) {
      if (mounted) {
        showSnack(strings.format('Update failed: {error}', {'error': err}));
      }
    } finally {
      if (mounted) {
        setState(() => savingAvatar = false);
      }
    }
  }

  Future<void> deleteAccount() async {
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('Delete account?')),
        content: Text(
          strings.text(
            'This permanently deletes your account, groups, messages, notifications and friend relationships.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.text('Delete account')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => deletingAccount = true);
    try {
      await widget.state.deleteAccount();
      if (!mounted) {
        return;
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (err) {
      if (mounted) {
        showSnack(strings.format('Delete failed: {error}', {'error': err}));
        setState(() => deletingAccount = false);
      }
    }
  }

  void showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.state.user;
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('Account'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _Avatar(
                      url: user?.avatar ?? '',
                      fallback: Icons.person_rounded,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.nickname ?? strings.text('Not logged in'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (user?.username.isNotEmpty == true)
                                '@${user!.username}',
                              if (user != null) 'UID ${user.uid}',
                            ].join(' | '),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(strings.text('Change nickname')),
                    subtitle: Text(user?.nickname ?? ''),
                    trailing: savingName
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: savingName ? null : editNickname,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.image_outlined),
                    title: Text(strings.text('Change avatar')),
                    trailing: savingAvatar
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: savingAvatar ? null : changeAvatar,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: Text(strings.text('Change password')),
                    trailing: savingPassword
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: savingPassword ? null : changePassword,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  strings.text('Delete account'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                subtitle: Text(strings.text('Permanently remove this account')),
                trailing: deletingAccount
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: deletingAccount ? null : deleteAccount,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.state,
    this.initialDeveloperOptionsExpanded = false,
  });

  final CsacAppState state;
  final bool initialDeveloperOptionsExpanded;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController serverUrl;
  bool clearing = false;
  bool refreshing = false;
  bool savingServer = false;
  late bool developerOptionsExpanded;

  @override
  void initState() {
    super.initState();
    serverUrl = TextEditingController(text: widget.state.preferences.serverUrl);
    developerOptionsExpanded = widget.initialDeveloperOptionsExpanded;
  }

  @override
  void dispose() {
    serverUrl.dispose();
    super.dispose();
  }

  String get themeLabel {
    final strings = context.strings;
    switch (widget.state.preferences.themeMode) {
      case ThemeMode.system:
        return strings.text('System');
      case ThemeMode.light:
        return strings.text('Light');
      case ThemeMode.dark:
        return strings.text('Dark');
    }
  }

  String get languageLabel {
    switch (widget.state.preferences.language) {
      case CsacLanguage.en:
        return 'English';
      case CsacLanguage.zh:
        return '中文';
    }
  }

  Future<void> refreshAll() async {
    setState(() => refreshing = true);
    try {
      await widget.state.refreshHome();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Refreshed.'))),
      );
    } catch (err) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.format('Refresh failed: {error}', {'error': err}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => refreshing = false);
      }
    }
  }

  Future<void> clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.strings.text('Clear local cache?')),
        content: Text(
          context.strings.text(
            'Cached conversations and message history on this device will be removed. Your login session will be kept.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.strings.text('Clear')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => clearing = true);
    try {
      await widget.state.clearLocalCache();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Local cache cleared.'))),
      );
    } catch (err) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.format('Clear cache failed: {error}', {
              'error': err,
            }),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => clearing = false);
      }
    }
  }

  Future<void> logoutToLogin() async {
    await widget.state.logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> saveServerUrl() async {
    setState(() => savingServer = true);
    try {
      final changed = await widget.state.updateServerUrl(serverUrl.text);
      if (!mounted) {
        return;
      }
      serverUrl.text = widget.state.preferences.serverUrl;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.text(
              changed
                  ? 'Server address saved. Please log in again.'
                  : 'Server address is unchanged.',
            ),
          ),
        ),
      );
      setState(() {});
    } on FormatException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.strings.text('Invalid server address.')),
        ),
      );
    } catch (err) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.format('Save failed: {error}', {'error': err}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => savingServer = false);
      }
    }
  }

  void resetServerUrl() {
    serverUrl.clear();
  }

  Future<void> chooseTheme() async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: widget.state.preferences.themeMode == ThemeMode.system
                  ? const Icon(Icons.check)
                  : const SizedBox(width: 24),
              title: Text(context.strings.text('System')),
              onTap: () => Navigator.of(context).pop(ThemeMode.system),
            ),
            ListTile(
              leading: widget.state.preferences.themeMode == ThemeMode.light
                  ? const Icon(Icons.check)
                  : const SizedBox(width: 24),
              title: Text(context.strings.text('Light')),
              onTap: () => Navigator.of(context).pop(ThemeMode.light),
            ),
            ListTile(
              leading: widget.state.preferences.themeMode == ThemeMode.dark
                  ? const Icon(Icons.check)
                  : const SizedBox(width: 24),
              title: Text(context.strings.text('Dark')),
              onTap: () => Navigator.of(context).pop(ThemeMode.dark),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await widget.state.updateThemeMode(selected);
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> chooseLanguage() async {
    final selected = await showModalBottomSheet<CsacLanguage>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: widget.state.preferences.language == CsacLanguage.en
                  ? const Icon(Icons.check)
                  : const SizedBox(width: 24),
              title: const Text('English'),
              onTap: () => Navigator.of(context).pop(CsacLanguage.en),
            ),
            ListTile(
              leading: widget.state.preferences.language == CsacLanguage.zh
                  ? const Icon(Icons.check)
                  : const SizedBox(width: 24),
              title: const Text('中文'),
              onTap: () => Navigator.of(context).pop(CsacLanguage.zh),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await widget.state.updateLanguage(selected);
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.state.user;
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('Settings'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(user?.nickname ?? strings.text('Not logged in')),
                subtitle: Text(
                  [
                    if (user?.username.isNotEmpty == true) '@${user!.username}',
                    if (user != null) 'UID ${user.uid}',
                  ].join(' | '),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.dark_mode_outlined),
                    title: Text(strings.text('Theme')),
                    subtitle: Text(themeLabel),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: chooseTheme,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.translate),
                    title: Text(strings.text('Language')),
                    subtitle: Text(languageLabel),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: chooseLanguage,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.sync),
                    title: Text(strings.text('Refresh app data')),
                    subtitle: Text(
                      strings.text('Reload conversations and counters'),
                    ),
                    trailing: refreshing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: refreshing ? null : refreshAll,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined),
                    title: Text(strings.text('Clear local cache')),
                    subtitle: Text(
                      strings.text(
                        'Remove cached conversations and message history',
                      ),
                    ),
                    trailing: clearing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: clearing ? null : clearCache,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: ExpansionTile(
                initiallyExpanded: developerOptionsExpanded,
                onExpansionChanged: (value) {
                  setState(() => developerOptionsExpanded = value);
                },
                leading: const Icon(Icons.developer_mode_outlined),
                title: Text(strings.text('Developer options')),
                subtitle: Text(
                  strings.format('Current server: {server}', {
                    'server': widget.state.preferences.serverUrl.trim().isEmpty
                        ? strings.text('Default server')
                        : widget.state.preferences.serverUrl.trim(),
                  }),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  TextField(
                    controller: serverUrl,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (!savingServer) {
                        saveServerUrl();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: strings.text('CsAC server address'),
                      hintText: '192.168.1.10:8080',
                      helperText: strings.text(
                        'Leave empty to use the default server.',
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 12,
                    overflowSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: savingServer ? null : resetServerUrl,
                        icon: const Icon(Icons.restart_alt),
                        label: Text(strings.text('Reset to default')),
                      ),
                      FilledButton.icon(
                        onPressed: savingServer ? null : saveServerUrl,
                        icon: savingServer
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(strings.text('Apply server')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.logout),
                title: Text(strings.text('Logout')),
                subtitle: Text(
                  strings.text('Clear session and return to login'),
                ),
                onTap: logoutToLogin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.fallback});

  final String url;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return CircleAvatar(child: Icon(fallback));
    }
    return CircleAvatar(backgroundImage: NetworkImage(url));
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.pending});

  final bool pending;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(context.strings.text(pending ? 'Pending' : 'Handled')),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: onRetry,
          child: Text(context.strings.text('Retry')),
        ),
      ],
    );
  }
}

class ConversationDetailScreen extends StatefulWidget {
  const ConversationDetailScreen({
    super.key,
    required this.state,
    required this.conversation,
  });

  final CsacAppState state;
  final Conversation conversation;

  @override
  State<ConversationDetailScreen> createState() =>
      _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  UserProfile? user;
  GroupProfile? group;
  List<GroupMember> members = const <GroupMember>[];
  List<CommonGroup> commonGroups = const <CommonGroup>[];
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
      if (widget.conversation.type == ConversationType.private) {
        final loaded = await widget.state.loadUserProfile(
          widget.conversation.id,
        );
        if (!mounted) {
          return;
        }
        var groups = const <CommonGroup>[];
        if (loaded.isFriend) {
          try {
            groups = await widget.state.loadCommonGroups(loaded.uid);
          } catch (_) {}
        }
        if (!mounted) {
          return;
        }
        setState(() {
          user = loaded;
          commonGroups = groups;
        });
      } else {
        final results = await Future.wait<dynamic>([
          widget.state.loadGroupProfile(widget.conversation.id),
          widget.state.loadGroupMembers(widget.conversation.id),
        ]);
        if (!mounted) {
          return;
        }
        setState(() {
          group = results[0] as GroupProfile;
          members = results[1] as List<GroupMember>;
        });
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

  Future<void> addFriend(UserProfile profile) async {
    final controller = TextEditingController(text: '请求添加你为好友');
    final strings = context.strings;
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          strings.format('Add {name}', {'name': profile.displayName}),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: strings.text('Request message'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(strings.text('Send')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (message == null || !mounted) {
      return;
    }
    try {
      await widget.state.sendFriendRequest(profile.uid, message);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('Friend request sent.'))),
      );
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.format('Request failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    }
  }

  Future<void> joinGroup(GroupProfile profile) async {
    final code = TextEditingController(text: profile.code);
    final answer = TextEditingController();
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.format('Join {name}', {'name': profile.name})),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (profile.question.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(profile.question),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: code,
              decoration: InputDecoration(
                labelText: strings.text('Invite code'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: answer,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: strings.text('Answer'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.text('Apply')),
          ),
        ],
      ),
    );
    final codeText = code.text;
    final answerText = answer.text;
    code.dispose();
    answer.dispose();
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await widget.state.applyJoinGroup(
        profile.id,
        code: codeText,
        answer: answerText,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('Join request sent.'))),
      );
      await load();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.format('Join failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    }
  }

  Future<void> editRemark(UserProfile profile) async {
    final controller = TextEditingController(text: profile.remark);
    final strings = context.strings;
    final remark = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('Edit remark')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: strings.text('Remark'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(strings.text('Save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (remark == null || !mounted) {
      return;
    }
    try {
      await widget.state.updateFriendRemark(profile.uid, remark.trim());
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.text('Remark updated.'))));
      await load();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.format('Update failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    }
  }

  Future<void> deleteFriend(UserProfile profile) async {
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          strings.format('Delete {name}?', {'name': profile.displayName}),
        ),
        content: Text(
          strings.text('This friend will be removed from your list.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.text('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await widget.state.deleteFriend(profile.uid);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.text('Friend deleted.'))));
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.format('Delete failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    }
  }

  Future<void> blockFriend(UserProfile profile) async {
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          strings.format('Block {name}?', {'name': profile.displayName}),
        ),
        content: Text(strings.text('This friend will be blocked.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.text('Block')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await widget.state.blockFriend(profile.uid);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.text('Friend blocked.'))));
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.format('Block failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    }
  }

  Future<void> leaveGroup(GroupProfile profile) async {
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.format('Leave {name}?', {'name': profile.name})),
        content: Text(
          strings.text('This group will be removed from your chats.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.text('Leave')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await widget.state.leaveGroup(profile.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.text('Left group.'))));
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.format('Leave failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    }
  }

  Future<void> memberAction(GroupMember member, String action) async {
    final profile = group;
    if (profile == null) {
      return;
    }
    try {
      switch (action) {
        case 'mute10':
          await widget.state.muteGroupMember(profile.id, member.uid, 10);
          break;
        case 'unmute':
          await widget.state.muteGroupMember(profile.id, member.uid, 0);
          break;
        case 'kick':
          await widget.state.kickGroupMember(profile.id, member.uid);
          break;
        case 'admin':
          await widget.state.setGroupAdmin(profile.id, member.uid, true);
          break;
        case 'removeAdmin':
          await widget.state.setGroupAdmin(profile.id, member.uid, false);
          break;
      }
      if (!mounted) {
        return;
      }
      final strings = context.strings;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('Member action completed.'))),
      );
      await load();
    } catch (err) {
      if (mounted) {
        final strings = context.strings;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.format('Action failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    }
  }

  Future<void> showMemberActions(GroupMember member) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.volume_off_outlined),
              title: Text(context.strings.text('Mute 10 minutes')),
              onTap: () => Navigator.of(context).pop('mute10'),
            ),
            ListTile(
              leading: const Icon(Icons.volume_up_outlined),
              title: Text(context.strings.text('Unmute')),
              onTap: () => Navigator.of(context).pop('unmute'),
            ),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: Text(context.strings.text('Set admin')),
              onTap: () => Navigator.of(context).pop('admin'),
            ),
            ListTile(
              leading: const Icon(Icons.remove_moderator_outlined),
              title: Text(context.strings.text('Remove admin')),
              onTap: () => Navigator.of(context).pop('removeAdmin'),
            ),
            ListTile(
              leading: Icon(
                Icons.person_remove_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                context.strings.text('Kick member'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.of(context).pop('kick'),
            ),
          ],
        ),
      ),
    );
    if (action != null) {
      await memberAction(member, action);
    }
  }

  void copyText(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.strings.format('{label} copied.', {'label': label}),
        ),
      ),
    );
  }

  Widget infoRow(IconData icon, String title, String value) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: SelectableText(value),
    );
  }

  Widget buildUserProfile(UserProfile profile) {
    final strings = context.strings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _Avatar(url: profile.avatar, fallback: Icons.person_rounded),
          title: Text(profile.displayName),
          subtitle: Text(
            profile.subtitle.isEmpty ? 'UID ${profile.uid}' : profile.subtitle,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Column(
            children: [
              infoRow(Icons.tag, strings.text('UID'), '${profile.uid}'),
              infoRow(
                Icons.badge_outlined,
                strings.text('Username'),
                profile.username,
              ),
              infoRow(Icons.edit_note, strings.text('Remark'), profile.remark),
              infoRow(
                Icons.circle_outlined,
                strings.text('Online'),
                profile.onlineStatus,
              ),
            ],
          ),
        ),
        if (profile.isFriend) ...[
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_note),
                  title: Text(strings.text('Edit remark')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => editRemark(profile),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.person_remove_outlined,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    strings.text('Delete friend'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () => deleteFriend(profile),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.block,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    strings.text('Block friend'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () => blockFriend(profile),
                ),
              ],
            ),
          ),
        ],
        if (commonGroups.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            strings.text('Common groups'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final group in commonGroups)
            Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text(group.name),
                subtitle: group.subtitle.isEmpty ? null : Text(group.subtitle),
              ),
            ),
        ],
        if (!profile.isFriend && profile.canAddFriend) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => addFriend(profile),
            icon: const Icon(Icons.person_add_alt),
            label: Text(strings.text('Add friend')),
          ),
        ],
      ],
    );
  }

  Widget buildGroupProfile(GroupProfile profile) {
    final strings = context.strings;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: Icon(
                Icons.groups_rounded,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            title: Text(profile.name),
            subtitle: Text(
              profile.subtitle.isEmpty
                  ? strings.format('Room {id}', {'id': profile.id})
                  : profile.subtitle,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.tag),
                  title: Text(strings.text('Room ID')),
                  subtitle: SelectableText('${profile.id}'),
                  trailing: IconButton(
                    tooltip: strings.text('Copy room ID'),
                    onPressed: () =>
                        copyText(strings.text('Room ID'), '${profile.id}'),
                    icon: const Icon(Icons.copy),
                  ),
                ),
                infoRow(
                  Icons.info_outline,
                  strings.text('Description'),
                  profile.description,
                ),
                infoRow(
                  Icons.campaign_outlined,
                  strings.text('Notice'),
                  profile.notice,
                ),
                if (profile.inviteCode.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: Text(strings.text('Invite code')),
                    subtitle: SelectableText(profile.inviteCode),
                    trailing: IconButton(
                      tooltip: strings.text('Copy invite code'),
                      onPressed: () => copyText(
                        strings.text('Invite code'),
                        profile.inviteCode,
                      ),
                      icon: const Icon(Icons.copy),
                    ),
                  ),
                infoRow(
                  Icons.lock_outline,
                  strings.text('Fixed code'),
                  profile.code,
                ),
                infoRow(
                  Icons.question_answer_outlined,
                  strings.text('Question'),
                  profile.question,
                ),
              ],
            ),
          ),
          if (!profile.isInGroup) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => joinGroup(profile),
              icon: const Icon(Icons.group_add),
              label: Text(strings.text('Apply to join')),
            ),
          ] else ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => leaveGroup(profile),
              icon: const Icon(Icons.logout),
              label: Text(strings.text('Leave group')),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.text('Members'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text('${members.length}'),
            ],
          ),
          const SizedBox(height: 8),
          if (members.isEmpty)
            _EmptyPanel(message: strings.text('No members.'))
          else
            for (final member in members)
              Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: _Avatar(
                    url: member.avatar,
                    fallback: Icons.person_rounded,
                  ),
                  title: Text(member.name),
                  subtitle: member.subtitle.isEmpty
                      ? Text('UID ${member.uid}')
                      : Text(member.subtitle),
                  trailing: (profile.isAdmin || profile.isOwner)
                      ? IconButton(
                          tooltip: strings.text('Manage'),
                          onPressed: () => showMemberActions(member),
                          icon: const Icon(Icons.more_vert),
                        )
                      : null,
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.conversation.type == ConversationType.group
        ? context.strings.text('Group details')
        : context.strings.text('User details');
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: context.strings.text('Refresh'),
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? _InlineError(message: error!, onRetry: load)
            : widget.conversation.type == ConversationType.private
            ? buildUserProfile(user!)
            : buildGroupProfile(group!),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.state,
    required this.conversation,
    this.focusMessageId,
    this.embedded = false,
  });

  final CsacAppState state;
  final Conversation conversation;
  final int? focusMessageId;
  final bool embedded;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final imagePicker = ImagePicker();
  final itemKeys = <int, GlobalKey>{};
  final messages = <ChatMessage>[];
  final mentionTargets = <GroupMember>[];
  Timer? timer;
  ChatMessage? replyTarget;
  int refreshTicks = 0;
  bool loading = true;
  bool refreshing = false;
  bool sending = false;
  bool offline = false;
  String? error;

  @override
  void initState() {
    super.initState();
    widget.state.setActiveConversation(widget.conversation);
    widget.state.markConversationRead(widget.conversation);
    loadInitial();
    timer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => refresh(silent: true),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    if (widget.state.isActiveConversation(widget.conversation)) {
      widget.state.setActiveConversation(null);
    }
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> markCurrentConversationRead() async {
    final lastMsgId = messages.isEmpty ? 0 : messages.last.id;
    await widget.state.markConversationRead(
      widget.conversation,
      lastMsgId: lastMsgId,
    );
  }

  Future<void> loadInitial() async {
    setState(() {
      loading = true;
      error = null;
      offline = false;
    });
    try {
      final focusId = widget.focusMessageId;
      final cached = focusId == null
          ? await widget.state.loadCachedMessages(widget.conversation)
          : await widget.state.loadCachedMessagesAround(
              widget.conversation,
              focusId,
            );
      if (!mounted) {
        return;
      }
      setState(() {
        messages
          ..clear()
          ..addAll(cached);
        loading = cached.isEmpty;
      });
      if (cached.isNotEmpty) {
        scrollAfterLoad();
      }
      final loaded = cached.isEmpty
          ? await widget.state.loadMessagesFromNetwork(widget.conversation)
          : await widget.state.syncMessages(
              widget.conversation,
              afterId: cached.last.id,
            );
      if (!mounted) {
        return;
      }
      setState(() {
        messages
          ..clear()
          ..addAll(mergeChatMessages(cached, loaded));
        offline = false;
      });
      await markCurrentConversationRead();
      scrollAfterLoad();
    } catch (err) {
      if (!mounted) {
        return;
      }
      setState(() {
        offline = messages.isNotEmpty;
        error = messages.isEmpty
            ? err.toString()
            : context.strings.format('Offline cache: {error}', {'error': err});
      });
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> reloadConversationFromNetwork({bool showLoading = false}) async {
    if (!mounted) {
      return;
    }
    if (showLoading) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final loaded = await widget.state.reloadMessagesFromNetwork(
        widget.conversation,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        messages
          ..clear()
          ..addAll(loaded);
        offline = false;
      });
      await markCurrentConversationRead();
      scrollAfterLoad();
    } catch (err) {
      if (mounted) {
        setState(() {
          error = err.toString();
          offline = messages.isNotEmpty;
        });
      }
    } finally {
      if (showLoading && mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> refresh({bool silent = false}) async {
    if (!mounted || refreshing) {
      return;
    }
    refreshing = true;
    try {
      refreshTicks += 1;
      if (silent && refreshTicks % 8 == 0) {
        final loaded = await widget.state.reloadMessagesFromNetwork(
          widget.conversation,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          messages
            ..clear()
            ..addAll(loaded);
          offline = false;
        });
        await markCurrentConversationRead();
        return;
      }
      final afterId = messages.isEmpty ? 0 : messages.last.id;
      final loaded = await widget.state.syncMessages(
        widget.conversation,
        afterId: afterId,
      );
      if (loaded.isEmpty) {
        if (offline && mounted) {
          setState(() => offline = false);
        }
        return;
      }
      final merged = mergeChatMessages(messages, loaded);
      setState(() {
        messages
          ..clear()
          ..addAll(merged);
        offline = false;
      });
      await markCurrentConversationRead();
      if (widget.focusMessageId == null) {
        scrollToEnd();
      }
    } catch (err) {
      if (!mounted) {
        return;
      }
      if (!silent) {
        setState(() => error = err.toString());
      }
      if (mounted) {
        setState(() => offline = messages.isNotEmpty);
      }
    } finally {
      refreshing = false;
    }
  }

  Future<void> send() async {
    final text = input.text.trim();
    if (text.isEmpty || sending) {
      return;
    }
    setState(() => sending = true);
    try {
      await widget.state.client.sendMessage(
        widget.conversation,
        text,
        replyTo: replyTarget?.id ?? 0,
        mentionUids: mentionTargets.map((member) => member.uid).toList(),
      );
      input.clear();
      clearComposeTargets();
      await widget.state.markConversationRead(widget.conversation);
      await refresh(silent: true);
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  Future<void> pickAndSendImage() async {
    if (sending) {
      return;
    }
    final picked = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (picked == null || !mounted) {
      return;
    }
    final bytes = await picked.readAsBytes();
    if (!mounted) {
      return;
    }
    final caption = await showDialog<String>(
      context: context,
      builder: (context) =>
          _ImageCaptionDialog(fileName: picked.name, bytes: bytes),
    );
    if (caption == null) {
      return;
    }
    setState(() => sending = true);
    try {
      await widget.state.client.sendImageMessage(
        widget.conversation,
        bytes,
        picked.name,
        caption: caption.trim(),
        replyTo: replyTarget?.id ?? 0,
        mentionUids: mentionTargets.map((member) => member.uid).toList(),
      );
      clearComposeTargets();
      await widget.state.markConversationRead(widget.conversation);
      await refresh(silent: true);
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  void clearComposeTargets() {
    if (!mounted) {
      return;
    }
    setState(() {
      replyTarget = null;
      mentionTargets.clear();
    });
  }

  void setReplyTarget(ChatMessage message) {
    setState(() => replyTarget = message);
  }

  Future<void> chooseMentionTargets() async {
    if (widget.conversation.type != ConversationType.group) {
      return;
    }
    try {
      final members = await widget.state.loadGroupMembers(
        widget.conversation.id,
      );
      if (!mounted) {
        return;
      }
      final selected = await showModalBottomSheet<List<GroupMember>>(
        context: context,
        showDragHandle: true,
        builder: (context) => _MentionPickerSheet(
          members: members,
          selectedUids: mentionTargets.map((member) => member.uid).toSet(),
        ),
      );
      if (selected == null || !mounted) {
        return;
      }
      setState(() {
        mentionTargets
          ..clear()
          ..addAll(selected);
      });
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    }
  }

  void replaceMessageLocally(ChatMessage replacement) {
    final index = messages.indexWhere(
      (message) => message.id == replacement.id,
    );
    if (index < 0) {
      return;
    }
    setState(() => messages[index] = replacement);
  }

  Future<void> recallMessage(ChatMessage message) async {
    final recalledBody = context.strings.text('[recalled]');
    try {
      await widget.state.recallMessage(widget.conversation, message.id);
      final recalled = message.copyWith(
        body: recalledBody,
        imageUrl: '',
        canRecall: false,
        isRecalled: true,
      );
      replaceMessageLocally(recalled);
      await widget.state.cache.saveMessages(widget.conversation, [recalled]);
      await reloadConversationFromNetwork();
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    }
  }

  Future<void> toggleEssence(ChatMessage message) async {
    if (widget.conversation.type != ConversationType.group) {
      return;
    }
    try {
      await widget.state.toggleEssence(widget.conversation.id, message.id);
      final updated = message.copyWith(isEssence: !message.isEssence);
      replaceMessageLocally(updated);
      await widget.state.cache.saveMessages(widget.conversation, [updated]);
      await reloadConversationFromNetwork();
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    }
  }

  Future<void> openEssenceList() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EssenceMessagesScreen(
          state: widget.state,
          conversation: widget.conversation,
        ),
      ),
    );
  }

  Future<void> showMessageActions(ChatMessage message, bool mine) async {
    final action = await showModalBottomSheet<_MessageAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => _MessageActionSheet(
        message: message,
        canRecall: message.canRecall || mine,
        canEssence: widget.conversation.type == ConversationType.group,
      ),
    );
    if (action == null || !mounted) {
      return;
    }
    switch (action) {
      case _MessageAction.copyText:
        Clipboard.setData(
          ClipboardData(
            text:
                '#${message.id} ${message.sender}\n${message.time}\n\n${message.body}',
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.text('Message copied'))),
        );
        break;
      case _MessageAction.copyImage:
        Clipboard.setData(ClipboardData(text: message.imageUrl));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.text('Image link copied'))),
        );
        break;
      case _MessageAction.openImage:
        showImagePreview(context, message.imageUrl);
        break;
      case _MessageAction.downloadImage:
        await downloadImage(context, message.imageUrl);
        break;
      case _MessageAction.reply:
        setReplyTarget(message);
        break;
      case _MessageAction.recall:
        await recallMessage(message);
        break;
      case _MessageAction.essence:
        await toggleEssence(message);
        break;
    }
  }

  void scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) {
        return;
      }
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void scrollAfterLoad() {
    final focusId = widget.focusMessageId;
    if (focusId == null) {
      scrollToEnd();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyContext = itemKeys[focusId]?.currentContext;
      if (keyContext == null) {
        scrollToEnd();
        return;
      }
      Scrollable.ensureVisible(
        keyContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        alignment: 0.42,
      );
    });
  }

  void scrollToMessage(int messageId) {
    final keyContext = itemKeys[messageId]?.currentContext;
    if (keyContext == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.text('Referenced message is not loaded.'),
          ),
        ),
      );
      return;
    }
    Scrollable.ensureVisible(
      keyContext,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      alignment: 0.42,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(
          widget.conversation.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (offline)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.cloud_off_outlined),
            ),
          IconButton(
            tooltip: context.strings.text('Refresh'),
            onPressed: () => reloadConversationFromNetwork(showLoading: true),
            icon: const Icon(Icons.refresh),
          ),
          if (widget.conversation.type == ConversationType.group)
            IconButton(
              tooltip: context.strings.text('Essence'),
              onPressed: openEssenceList,
              icon: const Icon(Icons.star_outline),
            ),
          IconButton(
            tooltip: context.strings.text('Details'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ConversationDetailScreen(
                    state: widget.state,
                    conversation: widget.conversation,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          if (error != null)
            MaterialBanner(
              content: Text(error!),
              actions: [
                TextButton(
                  onPressed: () => setState(() => error = null),
                  child: Text(context.strings.text('Dismiss')),
                ),
              ],
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? _EmptyPanel(message: context.strings.text('No messages.'))
                : ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final mine = widget.state.user?.uid == message.senderId;
                      final replyMessage = messages
                          .where((item) => item.id == message.replyTo)
                          .cast<ChatMessage?>()
                          .firstOrNull;
                      return _MessageBubble(
                        key: itemKeys.putIfAbsent(
                          message.id,
                          () => GlobalKey(),
                        ),
                        message: message,
                        replyMessage: replyMessage,
                        mine: mine,
                        focused: widget.focusMessageId == message.id,
                        onLongPress: () => showMessageActions(message, mine),
                        onReplyTap: message.replyTo > 0
                            ? () => scrollToMessage(message.replyTo)
                            : null,
                        onImageTap: message.imageUrl.isEmpty
                            ? null
                            : () => showImagePreview(context, message.imageUrl),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (replyTarget != null || mentionTargets.isNotEmpty)
                    _ComposeTargetsBar(
                      replyTarget: replyTarget,
                      mentions: mentionTargets,
                      onClearReply: () => setState(() => replyTarget = null),
                      onClearMentions: () =>
                          setState(() => mentionTargets.clear()),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: input,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => send(),
                          decoration: InputDecoration(
                            hintText: context.strings.text('Message'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (widget.conversation.type == ConversationType.group)
                        IconButton.filledTonal(
                          tooltip: context.strings.text('Mention'),
                          onPressed: sending ? null : chooseMentionTargets,
                          icon: const Icon(Icons.alternate_email),
                        ),
                      if (widget.conversation.type == ConversationType.group)
                        const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: context.strings.text('Image'),
                        onPressed: sending ? null : pickAndSendImage,
                        icon: const Icon(Icons.image_outlined),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: sending ? null : send,
                        child: sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    this.replyMessage,
    required this.mine,
    this.focused = false,
    this.onLongPress,
    this.onReplyTap,
    this.onImageTap,
  });

  final ChatMessage message;
  final ChatMessage? replyMessage;
  final bool mine;
  final bool focused;
  final VoidCallback? onLongPress;
  final VoidCallback? onReplyTap;
  final VoidCallback? onImageTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = mine
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    final textColor = mine ? colors.onPrimaryContainer : colors.onSurface;
    final secondaryTextColor = mine
        ? colors.onPrimaryContainer.withValues(alpha: 0.72)
        : colors.onSurfaceVariant;
    final replyColor = mine
        ? colors.primary.withValues(alpha: 0.12)
        : colors.surfaceContainerHigh;
    final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: align,
          children: [
            Text(
              '${message.sender}${message.time.isEmpty ? '' : ' · ${message.time}'}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: focused
                      ? colors.primary
                      : mine
                      ? colors.primaryContainer
                      : colors.outlineVariant,
                  width: focused ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.replyTo > 0) ...[
                    InkWell(
                      onTap: onReplyTap,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: replyColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          replyMessage == null
                              ? strings.format('Reply #{id}', {
                                  'id': message.replyTo,
                                })
                              : strings.format('Reply {sender}: {message}', {
                                  'sender': replyMessage!.sender,
                                  'message': compactMessage(replyMessage!.body),
                                }),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: secondaryTextColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (message.isMentioned || message.isEssence) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (message.isMentioned)
                          Chip(
                            avatar: const Icon(Icons.alternate_email, size: 16),
                            label: Text(strings.text('Mentioned')),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (message.isEssence)
                          Chip(
                            avatar: const Icon(Icons.star, size: 16),
                            label: Text(strings.text('Essence')),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (message.imageUrl.isNotEmpty) ...[
                    _MessageImage(url: message.imageUrl, onTap: onImageTap),
                    if (message.body.isNotEmpty &&
                        !message.body.startsWith('[image]'))
                      const SizedBox(height: 8),
                  ],
                  if (message.body.isNotEmpty &&
                      !message.body.startsWith('[image]'))
                    Text(message.body, style: TextStyle(color: textColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MessageAction {
  copyText,
  copyImage,
  openImage,
  downloadImage,
  reply,
  recall,
  essence,
}

class _MessageActionSheet extends StatelessWidget {
  const _MessageActionSheet({
    required this.message,
    required this.canRecall,
    required this.canEssence,
  });

  final ChatMessage message;
  final bool canRecall;
  final bool canEssence;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.reply),
            title: Text(strings.text('Reply')),
            subtitle: Text('#${message.id} ${message.sender}'),
            onTap: () => Navigator.of(context).pop(_MessageAction.reply),
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: Text(strings.text('Copy text')),
            onTap: () => Navigator.of(context).pop(_MessageAction.copyText),
          ),
          if (message.imageUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(strings.text('Copy image link')),
              onTap: () => Navigator.of(context).pop(_MessageAction.copyImage),
            ),
          if (message.imageUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text(strings.text('Open image')),
              onTap: () => Navigator.of(context).pop(_MessageAction.openImage),
            ),
          if (message.imageUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(strings.text('Download image')),
              onTap: () =>
                  Navigator.of(context).pop(_MessageAction.downloadImage),
            ),
          if (canRecall)
            ListTile(
              leading: const Icon(Icons.undo),
              title: Text(strings.text('Recall')),
              onTap: () => Navigator.of(context).pop(_MessageAction.recall),
            ),
          if (canEssence)
            ListTile(
              leading: Icon(
                message.isEssence ? Icons.star : Icons.star_outline,
              ),
              title: Text(
                strings.text(
                  message.isEssence ? 'Remove essence' : 'Set essence',
                ),
              ),
              onTap: () => Navigator.of(context).pop(_MessageAction.essence),
            ),
        ],
      ),
    );
  }
}

class _ComposeTargetsBar extends StatelessWidget {
  const _ComposeTargetsBar({
    required this.replyTarget,
    required this.mentions,
    required this.onClearReply,
    required this.onClearMentions,
  });

  final ChatMessage? replyTarget;
  final List<GroupMember> mentions;
  final VoidCallback onClearReply;
  final VoidCallback onClearMentions;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          if (replyTarget != null)
            InputChip(
              avatar: const Icon(Icons.reply, size: 18),
              label: Text(
                strings.format('Reply #{id}: {sender}', {
                  'id': replyTarget!.id,
                  'sender': replyTarget!.sender,
                }),
                overflow: TextOverflow.ellipsis,
              ),
              onDeleted: onClearReply,
            ),
          if (mentions.isNotEmpty)
            InputChip(
              avatar: const Icon(Icons.alternate_email, size: 18),
              label: Text(
                mentions.length == 1
                    ? '@${mentions.first.name}'
                    : strings.format('@ {count} members', {
                        'count': mentions.length,
                      }),
              ),
              onDeleted: onClearMentions,
            ),
        ],
      ),
    );
  }
}

class _MentionPickerSheet extends StatefulWidget {
  const _MentionPickerSheet({
    required this.members,
    required this.selectedUids,
  });

  final List<GroupMember> members;
  final Set<int> selectedUids;

  @override
  State<_MentionPickerSheet> createState() => _MentionPickerSheetState();
}

class _MentionPickerSheetState extends State<_MentionPickerSheet> {
  late final Set<int> selected = Set<int>.from(widget.selectedUids);

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SafeArea(
      child: SizedBox(
        height: 520,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.text('Mention members'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (selected.length == widget.members.length) {
                          selected.clear();
                        } else {
                          selected
                            ..clear()
                            ..addAll(
                              widget.members.map((member) => member.uid),
                            );
                        }
                      });
                    },
                    child: Text(strings.text('Toggle all')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.members.isEmpty
                  ? _EmptyPanel(message: strings.text('No members.'))
                  : ListView.builder(
                      itemCount: widget.members.length,
                      itemBuilder: (context, index) {
                        final member = widget.members[index];
                        final checked = selected.contains(member.uid);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (_) {
                            setState(() {
                              if (checked) {
                                selected.remove(member.uid);
                              } else {
                                selected.add(member.uid);
                              }
                            });
                          },
                          secondary: _Avatar(
                            url: member.avatar,
                            fallback: Icons.person_rounded,
                          ),
                          title: Text(member.name),
                          subtitle: member.subtitle.isEmpty
                              ? null
                              : Text(member.subtitle),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Text(
                    strings.format('{count} selected', {
                      'count': selected.length,
                    }),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text(strings.text('Cancel')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        widget.members
                            .where((member) => selected.contains(member.uid))
                            .toList(),
                      );
                    },
                    child: Text(strings.text('Done')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EssenceMessagesScreen extends StatefulWidget {
  const EssenceMessagesScreen({
    super.key,
    required this.state,
    required this.conversation,
  });

  final CsacAppState state;
  final Conversation conversation;

  @override
  State<EssenceMessagesScreen> createState() => _EssenceMessagesScreenState();
}

class _EssenceMessagesScreenState extends State<EssenceMessagesScreen> {
  List<ChatMessage> messages = const <ChatMessage>[];
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
      final loaded = await widget.state.loadEssenceMessages(
        widget.conversation.id,
      );
      if (!mounted) {
        return;
      }
      setState(() => messages = loaded.reversed.toList());
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

  Future<void> openMessage(ChatMessage message) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          state: widget.state,
          conversation: widget.conversation,
          focusMessageId: message.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.strings.text('Essence messages')),
        actions: [
          IconButton(
            tooltip: context.strings.text('Refresh'),
            onPressed: load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            if (loading) const LinearProgressIndicator(minHeight: 2),
            if (error != null) _InlineError(message: error!, onRetry: load),
            if (!loading && messages.isEmpty)
              _EmptyPanel(message: context.strings.text('No essence messages.'))
            else
              for (final message in messages)
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: ListTile(
                    onTap: () => openMessage(message),
                    leading: const Icon(Icons.star_outline),
                    title: Text(
                      message.sender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        if (message.time.isNotEmpty) message.time,
                        message.body,
                      ].join(' | '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _MessageImage extends StatelessWidget {
  const _MessageImage({required this.url, this.onTap});

  final String url;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 260,
          height: 180,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 260,
              height: 120,
              color: colors.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Icon(
                Icons.broken_image_outlined,
                size: 42,
                color: colors.onSurfaceVariant,
              ),
            );
          },
          loadingBuilder: (context, child, progress) {
            if (progress == null) {
              return child;
            }
            return Container(
              width: 260,
              height: 120,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(strokeWidth: 2),
            );
          },
        ),
      ),
    );
  }
}

class _ImageCaptionDialog extends StatefulWidget {
  const _ImageCaptionDialog({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;

  @override
  State<_ImageCaptionDialog> createState() => _ImageCaptionDialogState();
}

class _ImageCaptionDialogState extends State<_ImageCaptionDialog> {
  final caption = TextEditingController();

  @override
  void dispose() {
    caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(
        strings.format('Send image: {fileName}', {'fileName': widget.fileName}),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 260,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: colors.surfaceContainerHighest,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.memory(
              widget.bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                Icons.image_outlined,
                size: 48,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: caption,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: strings.text('Caption'),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(strings.text('Cancel')),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(caption.text),
          icon: const Icon(Icons.send),
          label: Text(strings.text('Send')),
        ),
      ],
    );
  }
}

void showImagePreview(BuildContext context, String url) {
  final strings = context.strings;
  showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.7,
                  maxScale: 5,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      size: 64,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: strings.text('Copy link'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(strings.text('Image link copied')),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: strings.text('Open'),
                      onPressed: () => launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: strings.text('Download'),
                      onPressed: () => downloadImage(context, url),
                      icon: const Icon(Icons.download_outlined),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> downloadImage(BuildContext context, String url) async {
  final strings = context.strings;
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final uri = Uri.parse(url);
    final ext = normalizedImageExtension(uri.path);
    final fileName = 'csac_${DateTime.now().millisecondsSinceEpoch}$ext';
    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(label: strings.text('Images'), extensions: imageExtensions),
      ],
    );
    if (location == null) {
      return;
    }
    var path = location.path;
    if (p.extension(path).isEmpty) {
      final activeExt = location.activeFilter?.extensions?.firstOrNull;
      path = '$path.${activeExt ?? ext.replaceFirst('.', '')}';
    }
    final imageFile = XFile.fromData(
      response.bodyBytes,
      name: p.basename(path),
      mimeType: mimeTypeForExtension(p.extension(path)),
    );
    await imageFile.saveTo(path);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.format('Saved to {path}', {'path': path})),
      ),
    );
  } catch (err) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          strings.format('Download failed: {error}', {'error': err}),
        ),
      ),
    );
  }
}

const imageExtensions = <String>['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];

String normalizedImageExtension(String path) {
  final ext = p.extension(path).toLowerCase();
  if (ext.isEmpty) {
    return '.jpg';
  }
  final bare = ext.replaceFirst('.', '');
  if (imageExtensions.contains(bare)) {
    return ext;
  }
  return '.jpg';
}

String mimeTypeForExtension(String extension) {
  switch (extension.toLowerCase().replaceFirst('.', '')) {
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'bmp':
      return 'image/bmp';
    case 'jpg':
    case 'jpeg':
    default:
      return 'image/jpeg';
  }
}

String compactMessage(String text, {int max = 80}) {
  final value = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (value.length <= max) {
    return value;
  }
  return '${value.substring(0, max - 3)}...';
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}
