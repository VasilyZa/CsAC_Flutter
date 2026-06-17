part of '../../main.dart';

Future<void> showVersionUpdateDialog(
  BuildContext context,
  VersionUpdateInfo result,
) async {
  final strings = context.strings;
  await showCupertinoCsacDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(strings.text('New version available')),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: CsacSingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  strings.format('Current version: {version}', {
                    'version': result.displayCurrentVersion,
                  }),
                ),
                const SizedBox(height: 6),
                Text(
                  strings.format('Latest version: {version}', {
                    'version': result.displayLatestVersion,
                  }),
                ),
                if (result.publishedAt != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    strings.format('Published at: {time}', {
                      'time': formatLocalDateTime(
                        result.publishedAt!.toLocal(),
                      ),
                    }),
                  ),
                ],
                if (result.releaseNotes.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    strings.text('Release notes'),
                    style: Theme.of(dialogContext).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  MarkdownBody(
                    data: result.releaseNotes.trim(),
                    selectable: true,
                    onTapLink: (text, href, title) {
                      if (href == null || href.trim().isEmpty) {
                        return;
                      }
                      unawaited(
                        launchUrl(
                          Uri.parse(href.trim()),
                          mode: LaunchMode.externalApplication,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              unawaited(openVersionUpdateRelease(context, result));
            },
            icon: const Icon(Icons.open_in_new),
            label: Text(strings.text('Open release')),
          ),
        ],
      );
    },
  );
}

Future<void> openVersionUpdateRelease(
  BuildContext context,
  VersionUpdateInfo result,
) async {
  final url = result.releaseUrl.trim().isEmpty
      ? 'https://github.com/VasilyZa/CsAC_Flutter/releases/latest'
      : result.releaseUrl.trim();
  final opened = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!opened && context.mounted) {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      CsacToastMessenger.of(context).showToast(
        CsacToast(content: Text(context.strings.text('Release link copied.'))),
      );
    }
  }
}

class CsacMobileApp extends StatefulWidget {
  const CsacMobileApp({super.key});

  @override
  State<CsacMobileApp> createState() => _CsacMobileAppState();
}

class _CsacMobileAppState extends State<CsacMobileApp>
    with WidgetsBindingObserver {
  late final CsacAppState state;
  final updateChecker = VersionUpdateChecker();
  final localNotifications = CsacLocalNotificationService.instance;
  final backgroundRefreshChannel = const MethodChannel(
    'com.xiaobai.csac/background_refresh',
  );
  final scaffoldMessengerKey = GlobalKey<CsacToastMessengerState>();
  final navigatorKey = GlobalKey<NavigatorState>();
  final mainShellKey = GlobalKey<_MainShellState>();
  StreamSubscription<Conversation>? notificationTapSub;
  StreamSubscription<Uri>? deepLinkSub;
  Uri? pendingDeepLink;
  bool locked = false;
  bool wasBackgrounded = false;
  bool appLockSessionUnlocked = false;
  bool appLockStateSeen = false;
  bool lastCanUseAppLock = false;
  bool startupUpdateCheckStarted = false;
  bool localNotificationPermissionPrimed = false;
  int appLockUserId = 0;

  Map<String, int> unreadSnapshot() {
    return <String, int>{
      for (final conversation in state.conversations)
        conversationKey(conversation): conversation.unreadCount,
    };
  }

  String conversationKey(Conversation conversation) {
    return '${conversation.type.name}:${conversation.id}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state = CsacAppState();
    state.addListener(handleStateChanged);
    backgroundRefreshChannel.setMethodCallHandler(handleBackgroundRefreshCall);
    unawaited(state.initialize());
    unawaited(localNotifications.initialize());
    unawaited(initializeDeepLinks());
    notificationTapSub = localNotifications.taps.listen(openNotificationChat);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      maybeCheckForUpdatesOnStartup();
    });
  }

  @override
  void dispose() {
    state.removeListener(handleStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    backgroundRefreshChannel.setMethodCallHandler(null);
    notificationTapSub?.cancel();
    deepLinkSub?.cancel();
    updateChecker.close();
    super.dispose();
  }

  Future<void> initializeDeepLinks() async {
    try {
      final links = AppLinks();
      final initial = await links.getInitialLink();
      if (initial != null) {
        handleDeepLink(initial);
      }
      deepLinkSub = links.uriLinkStream.listen(
        handleDeepLink,
        onError: (Object error) {
          if (kDebugMode) {
            debugPrint('CsAC deep link stream failed: $error');
          }
        },
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('CsAC deep link initialization failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  void handleDeepLink(Uri uri) {
    if (!isCsacDeepLink(uri)) {
      return;
    }
    pendingDeepLink = uri;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(consumePendingDeepLink());
    });
  }

  Future<void> consumePendingDeepLink() async {
    final uri = pendingDeepLink;
    if (uri == null || state.bootstrapping) {
      return;
    }
    final target = parseCsacDeepLink(uri);
    if (!target.isSupported) {
      pendingDeepLink = null;
      showDeepLinkToast('Unsupported CsAC link.');
      return;
    }
    if (state.user == null || state.needsEmailVerification || locked) {
      return;
    }
    final handled = await mainShellKey.currentState?.openDeepLinkTarget(target);
    if (handled == null) {
      return;
    }
    pendingDeepLink = null;
    if (!handled) {
      showDeepLinkToast('Unable to open CsAC link.');
    }
  }

  void showDeepLinkToast(String message) {
    final context = navigatorKey.currentContext;
    final strings = context == null
        ? CsacStrings(localeForLanguage(state.preferences.language))
        : CsacStrings.of(context);
    scaffoldMessengerKey.currentState?.showToast(
      CsacToast(content: Text(strings.text(message))),
    );
  }

  Future<void> openNotificationChat(Conversation tapped) async {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted || state.user == null) {
      return;
    }
    final conversation = state.conversations
        .where((item) => item.type == tapped.type && item.id == tapped.id)
        .firstOrNull;
    if (conversation == null) {
      return;
    }
    if (state.isActiveConversation(conversation)) {
      return;
    }
    await navigatorKey.currentState?.push(
      CsacPageRoute<void>(
        builder: (_) => ChatScreen(
          state: state,
          conversation: conversation.copyWith(unreadCount: 0),
        ),
      ),
    );
  }

  Future<dynamic> handleBackgroundRefreshCall(MethodCall call) async {
    if (call.method != 'performBackgroundFetch') {
      throw MissingPluginException('Unknown method ${call.method}');
    }
    if (state.user == null || state.bootstrapping) {
      return false;
    }
    final wasForeground = state.appInForeground;
    state.setAppInForeground(false);
    final beforeUnread = unreadSnapshot();
    try {
      await state.refreshHome();
      final newCount = await showNewMessageNotificationsFromSnapshot(
        beforeUnread,
      );
      return newCount > 0;
    } catch (_) {
      return false;
    } finally {
      state.setAppInForeground(wasForeground);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.hidden ||
        lifecycleState == AppLifecycleState.inactive) {
      state.setAppInForeground(false);
      wasBackgrounded = true;
      if (canUseAppLock()) {
        appLockSessionUnlocked = false;
        if (!locked && mounted) {
          setState(() => locked = true);
        }
      }
      return;
    }
    if (lifecycleState == AppLifecycleState.resumed && wasBackgrounded) {
      wasBackgrounded = false;
      unawaited(refreshAfterResume());
      lockIfNeeded();
      return;
    }
    if (lifecycleState == AppLifecycleState.resumed) {
      state.setAppInForeground(true);
    }
  }

  Future<void> refreshAfterResume() async {
    if (state.user == null || state.bootstrapping) {
      state.setAppInForeground(true);
      return;
    }
    final beforeUnread = unreadSnapshot();
    try {
      await state.refreshHome();
      await showNewMessageNotificationsFromSnapshot(beforeUnread);
    } catch (_) {
      // Resume refresh should not interrupt unlock or normal foregrounding.
    } finally {
      state.setAppInForeground(true);
    }
  }

  Future<int> showNewMessageNotificationsFromSnapshot(
    Map<String, int> beforeUnread,
  ) async {
    if (!state.preferences.localSystemNotificationsEnabled) {
      return 0;
    }
    var newCount = 0;
    for (final conversation in state.conversations) {
      if (state.isVisibleActiveConversation(conversation)) {
        continue;
      }
      final previous = beforeUnread[conversationKey(conversation)] ?? 0;
      final delta = conversation.unreadCount - previous;
      if (delta <= 0) {
        continue;
      }
      newCount += delta;
      final latestMessage = await latestNotificationMessage(conversation);
      await localNotifications.showConversationNotification(
        conversation: conversation,
        newCount: delta,
        title: notificationTitleForConversation(conversation, latestMessage),
        body: notificationBodyForConversation(
          conversation,
          delta,
          latestMessage,
          CsacStrings(localeForLanguage(state.preferences.language)),
        ),
      );
    }
    return newCount;
  }

  Future<ChatMessage?> latestNotificationMessage(
    Conversation conversation,
  ) async {
    if (conversation.type == ConversationType.group) {
      final cached = await state.loadCachedMessages(conversation);
      final afterId = cached.isEmpty ? 0 : cached.last.id;
      final previousIncomingId = latestIncomingNotificationMessageId(
        conversation,
        cached,
        currentUserId: state.user?.uid ?? 0,
      );
      final loaded = await state.syncMessages(conversation, afterId: afterId);
      final latestIncoming = latestIncomingNotificationMessage(
        conversation,
        loaded,
        currentUserId: state.user?.uid ?? 0,
      );
      if (latestIncoming != null && latestIncoming.id > previousIncomingId) {
        return latestIncoming;
      }
      return null;
    }
    final cached = await state.loadCachedMessages(conversation);
    return latestIncomingNotificationMessage(
      conversation,
      cached,
      currentUserId: state.user?.uid ?? 0,
    );
  }

  void handleStateChanged() {
    maybeCheckForUpdatesOnStartup();
    maybePrimeLocalNotificationPermission();
    if (pendingDeepLink != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(consumePendingDeepLink());
      });
    }
    final userId = state.user?.uid ?? 0;
    if (userId != appLockUserId) {
      appLockUserId = userId;
      appLockSessionUnlocked = false;
    }
    if (!canUseAppLock()) {
      if (locked) {
        setState(() => locked = false);
      }
      appLockSessionUnlocked = false;
      if (!state.bootstrapping && state.user != null) {
        appLockStateSeen = true;
      }
      lastCanUseAppLock = false;
      return;
    }
    if (!lastCanUseAppLock) {
      if (appLockStateSeen) {
        appLockSessionUnlocked = true;
      }
      appLockStateSeen = true;
      lastCanUseAppLock = true;
    }
    if (!locked && !appLockSessionUnlocked) {
      setState(() => locked = true);
    }
  }

  void maybePrimeLocalNotificationPermission() {
    if (localNotificationPermissionPrimed ||
        state.bootstrapping ||
        !state.preferences.localSystemNotificationsEnabled) {
      return;
    }
    localNotificationPermissionPrimed = true;
    unawaited(localNotifications.ensurePermissions());
  }

  void maybeCheckForUpdatesOnStartup() {
    if (startupUpdateCheckStarted ||
        !supportsVersionUpdateChecks ||
        state.bootstrapping ||
        !state.preferences.autoCheckVersionUpdates) {
      return;
    }
    startupUpdateCheckStarted = true;
    unawaited(checkForUpdatesSilently());
  }

  Future<void> checkForUpdatesSilently() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final result = await updateChecker.check(
        currentVersion: VersionUpdateChecker.displayVersion(
          '${packageInfo.version}+${packageInfo.buildNumber}',
        ),
      );
      if (!mounted || !result.hasUpdate) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final strings = CsacStrings(
          localeForLanguage(state.preferences.language),
        );
        final messenger = scaffoldMessengerKey.currentState;
        messenger?.showToast(
          CsacToast(
            content: Text(
              strings.format('New version available: {version}', {
                'version': result.displayLatestVersion,
              }),
            ),
            action: CsacToastAction(
              label: strings.text('View'),
              onPressed: () => unawaited(showStartupUpdateDialog(result)),
            ),
          ),
        );
      });
    } catch (err, stackTrace) {
      logUpdateCheckFailure(err, stackTrace);
      // Startup update checks are intentionally silent on network/API failure.
    }
  }

  Future<void> showStartupUpdateDialog(VersionUpdateInfo result) async {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }
    await showVersionUpdateDialog(context, result);
  }

  void logUpdateCheckFailure(Object error, StackTrace stackTrace) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('CsAC GitHub update check failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  bool canUseAppLock() {
    return !state.bootstrapping &&
        state.user != null &&
        state.preferences.effectiveAppLockEnabled;
  }

  void lockIfNeeded() {
    if (!mounted || locked || !canUseAppLock()) {
      return;
    }
    appLockSessionUnlocked = false;
    setState(() => locked = true);
  }

  void unlock() {
    if (!mounted) {
      return;
    }
    appLockSessionUnlocked = true;
    appLockUserId = state.user?.uid ?? 0;
    setState(() => locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final strings = CsacStrings(
          localeForLanguage(state.preferences.language),
        );
        final appTitle = strings.text(
          isDesktopPlatform ? 'CsAC Desktop' : 'CsAC Mobile',
        );
        final platformBrightness = MediaQuery.maybePlatformBrightnessOf(
          context,
        );
        final effectiveBrightness = switch (state.preferences.themeMode) {
          ThemeMode.light => Brightness.light,
          ThemeMode.dark => Brightness.dark,
          ThemeMode.system => platformBrightness ?? Brightness.light,
        };
        final seedColor = Color(state.preferences.themeColorValue);
        return CupertinoApp(
          title: appTitle,
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          locale: localeForLanguage(state.preferences.language),
          supportedLocales: const [Locale('en'), Locale('zh', 'CN')],
          localizationsDelegates: const [
            CsacStringsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          scrollBehavior: const CsacScrollBehavior(),
          theme: buildCsacCupertinoTheme(
            effectiveBrightness,
            seedColor,
            state.preferences.fontStyle,
          ),
          builder: (context, child) {
            final appContent = _ActionSheetPreference(
              style: state.preferences.actionSheetStyle,
              child: _DesktopCommandPaletteHost(
                state: state,
                navigatorKey: navigatorKey,
                scaffoldMessengerKey: scaffoldMessengerKey,
                enabled:
                    isDesktopPlatform &&
                    !locked &&
                    !state.bootstrapping &&
                    !state.isAcopMode &&
                    state.user != null,
                child: CsacThemeBridge(
                  brightness: effectiveBrightness,
                  seedColor: seedColor,
                  fontStyle: state.preferences.fontStyle,
                  child: CsacToastHost(
                    key: scaffoldMessengerKey,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            );
            return _CupertinoDesktopWindowFrame(
              title: appTitle,
              child: appContent,
            );
          },
          home: _MotionPreference(
            reduceMotion: state.preferences.reduceMotion,
            child: Stack(
              children: [
                _StartupTransition(
                  child: state.bootstrapping
                      ? SplashScreen(
                          key: const ValueKey<String>('bootstrap'),
                          status: state.restoreStatus,
                        )
                      : state.isAcopMode
                      ? state.hasAcopDeveloper
                            ? AcopPlatformShell(
                                key: const ValueKey<String>('acop-shell'),
                                state: state,
                              )
                            : AcopLoginScreen(
                                key: const ValueKey<String>('acop-login'),
                                state: state,
                              )
                      : state.user == null
                      ? LoginScreen(
                          key: const ValueKey<String>('login'),
                          state: state,
                        )
                      : state.needsEmailVerification
                      ? EmailVerificationRequiredScreen(
                          key: const ValueKey<String>('email-verification'),
                          state: state,
                        )
                      : MainShell(
                          key: mainShellKey,
                          state: state,
                          navigatorKey: navigatorKey,
                          scaffoldMessengerKey: scaffoldMessengerKey,
                        ),
                ),
                if (locked && state.user != null)
                  Positioned.fill(
                    child: AppLockScreen(state: state, onUnlocked: unlock),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StartupTransition extends StatelessWidget {
  const _StartupTransition({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = _MotionPreference.reduceOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : 360.ms,
      reverseDuration: reduceMotion ? Duration.zero : 240.ms,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        if (reduceMotion) {
          return child;
        }
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final slide =
            Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
        final scale = Tween<double>(begin: 0.985, end: 1).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(scale: scale, child: child),
          ),
        );
      },
      child: child,
    );
  }
}

class _CupertinoDesktopWindowFrame extends StatelessWidget {
  const _CupertinoDesktopWindowFrame({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!supportsCustomDesktopWindowChrome) {
      return child;
    }
    return buildDesktopWindowStateListener(
      builder: (context, frameState) {
        final colors = CsacColors.of(context);
        final expanded = frameState.isExpanded;
        final radius = expanded ? 0.0 : 12.0;
        final borderColor =
            (frameState.isFocused
                    ? CupertinoTheme.of(context).primaryColor
                    : colors.separator)
                .withValues(alpha: frameState.isFocused ? 0.36 : 0.28);
        final window = DecoratedBox(
          decoration: BoxDecoration(
            color: colors.systemBackground,
            borderRadius: BorderRadius.circular(radius),
            border: expanded
                ? null
                : Border.all(color: borderColor, width: 0.8),
            boxShadow: [
              if (!expanded)
                BoxShadow(
                  color: CupertinoColors.black.withValues(
                    alpha: colors.isDark ? 0.40 : 0.16,
                  ),
                  blurRadius: frameState.isFocused ? 28 : 18,
                  offset: const Offset(0, 12),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Column(
              children: [
                _CupertinoDesktopTitleBar(
                  title: title,
                  isMaximized: frameState.isMaximized,
                  isFocused: frameState.isFocused,
                  expanded: expanded,
                ),
                Expanded(
                  child: ClipRect(
                    child: ColoredBox(
                      color: colors.systemBackground,
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        return buildDesktopWindowResizeFrame(enabled: !expanded, child: window);
      },
    );
  }
}

class _CupertinoDesktopTitleBar extends StatelessWidget {
  const _CupertinoDesktopTitleBar({
    required this.title,
    required this.isMaximized,
    required this.isFocused,
    required this.expanded,
  });

  final String title;
  final bool isMaximized;
  final bool isFocused;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    final bar = DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          primary.withValues(alpha: isFocused ? 0.04 : 0.0),
          colors.systemBackground,
        ),
        border: Border(
          bottom: BorderSide(
            color: colors.separator.withValues(alpha: 0.28),
            width: 0.5,
          ),
        ),
      ),
      child: SizedBox(
        height: 46,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: expanded ? 12 : 14,
            end: 8,
          ),
          child: Row(
            children: [
              _CupertinoWindowControlButton(
                tooltip: 'Close',
                label: 'x',
                color: CupertinoColors.systemRed.resolveFrom(context),
                onPressed: () => unawaited(closeDesktopWindow()),
              ),
              _CupertinoWindowControlButton(
                tooltip: 'Minimize',
                label: '-',
                color: CupertinoColors.systemYellow.resolveFrom(context),
                onPressed: () => unawaited(minimizeDesktopWindow()),
              ),
              _CupertinoWindowControlButton(
                tooltip: isMaximized ? 'Restore' : 'Maximize',
                label: '+',
                color: CupertinoColors.systemGreen.resolveFrom(context),
                onPressed: () => unawaited(toggleMaximizeDesktopWindow()),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: buildDesktopWindowMoveArea(
                  child: Row(
                    children: [
                      Icon(
                        CupertinoIcons.chat_bubble_2_fill,
                        size: 16,
                        color: isFocused ? primary : colors.secondaryLabel,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isFocused
                                ? colors.label
                                : colors.secondaryLabel,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return bar;
  }
}

class _CupertinoWindowControlButton extends StatefulWidget {
  const _CupertinoWindowControlButton({
    required this.tooltip,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String tooltip;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_CupertinoWindowControlButton> createState() =>
      _CupertinoWindowControlButtonState();
}

class _CupertinoWindowControlButtonState
    extends State<_CupertinoWindowControlButton> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => hovering = true),
        onExit: (_) => setState(() => hovering = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: Container(
                width: 13,
                height: 13,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: hovering ? 1 : 0.86),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: CupertinoColors.black.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                ),
                child: AnimatedOpacity(
                  opacity: hovering ? 1 : 0,
                  duration: 100.ms,
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      color: CupertinoColors.black,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

CupertinoThemeData buildCsacCupertinoTheme(
  Brightness brightness,
  Color seedColor,
  CsacFontStyle fontStyle,
) {
  final isDark = brightness == Brightness.dark;
  final fontFamily = fontFamilyForStyle(fontStyle);
  final fontFamilyFallback = fontFamilyFallbackForStyle(fontStyle);
  final baseText = TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    color: CupertinoColors.label,
    fontSize: 17,
    letterSpacing: -0.22,
  );
  return CupertinoThemeData(
    brightness: brightness,
    primaryColor: seedColor,
    primaryContrastingColor: CupertinoColors.white,
    scaffoldBackgroundColor: isDark
        ? CupertinoColors.black
        : const Color(0xFFF2F2F7),
    barBackgroundColor: isDark
        ? const Color(0xCC1C1C1E)
        : const Color(0xCCF9F9F9),
    textTheme: CupertinoTextThemeData(
      primaryColor: seedColor,
      textStyle: baseText,
      actionTextStyle: baseText.copyWith(color: seedColor),
      navActionTextStyle: baseText.copyWith(color: seedColor, fontSize: 17),
      navTitleTextStyle: baseText.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 17,
      ),
      navLargeTitleTextStyle: baseText.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 34,
        letterSpacing: -0.7,
      ),
      tabLabelTextStyle: baseText.copyWith(fontSize: 11),
    ),
  );
}

String? fontFamilyForStyle(CsacFontStyle style) {
  switch (style) {
    case CsacFontStyle.system:
      return null;
    case CsacFontStyle.serif:
      return isApplePlatform ? 'Times New Roman' : 'serif';
    case CsacFontStyle.rounded:
      return isApplePlatform ? 'SF Pro Rounded' : null;
    case CsacFontStyle.monospace:
      return isApplePlatform ? 'Menlo' : 'monospace';
  }
}

List<String>? fontFamilyFallbackForStyle(CsacFontStyle style) {
  switch (style) {
    case CsacFontStyle.system:
      return null;
    case CsacFontStyle.serif:
      return const <String>[
        'Times New Roman',
        'Songti SC',
        'Noto Serif CJK SC',
        'serif',
      ];
    case CsacFontStyle.rounded:
      return const <String>[
        'SF Pro Rounded',
        'PingFang SC',
        'Microsoft YaHei UI',
        'Roboto',
        'sans-serif',
      ];
    case CsacFontStyle.monospace:
      return const <String>['Menlo', 'Cascadia Mono', 'Consolas', 'monospace'];
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    return CsacPageScaffold(
      backgroundColor: colors.systemBackground,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, primary.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const _AppIconImage(size: 80, borderRadius: 20),
            ),
            const SizedBox(height: 24),
            Text(
              context.strings.text('CsAC Mobile'),
              style: TextStyle(
                color: colors.label,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              status,
              style: TextStyle(color: colors.secondaryLabel, fontSize: 14),
            ),
            const SizedBox(height: 24),
            CupertinoActivityIndicator(radius: 12, color: primary),
          ],
        ),
      ),
    );
  }
}

enum _LoginMode { usernamePassword, emailPassword, emailCode }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController();
  final email = TextEditingController();
  final emailCode = TextEditingController();
  final password = TextEditingController();
  final passwordFocus = FocusNode();
  List<LoginAccountRecord> accounts = const <LoginAccountRecord>[];
  _LoginMode loginMode = _LoginMode.usernamePassword;
  bool loadingAccounts = true;
  bool sendingLoginCode = false;
  int resendSeconds = 0;
  Timer? resendTimer;
  String? error;

  @override
  void initState() {
    super.initState();
    loadAccounts();
  }

  @override
  void dispose() {
    username.dispose();
    email.dispose();
    emailCode.dispose();
    password.dispose();
    passwordFocus.dispose();
    resendTimer?.cancel();
    super.dispose();
  }

  String loginModeLabel(CsacStrings strings, _LoginMode mode) {
    return switch (mode) {
      _LoginMode.usernamePassword => strings.text('Username'),
      _LoginMode.emailPassword => strings.text('Email password'),
      _LoginMode.emailCode => strings.text('Email code'),
    };
  }

  void startResendTimer(int seconds) {
    resendTimer?.cancel();
    setState(() => resendSeconds = seconds <= 0 ? 60 : seconds);
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (resendSeconds <= 1) {
        timer.cancel();
        setState(() => resendSeconds = 0);
      } else {
        setState(() => resendSeconds -= 1);
      }
    });
  }

  Future<void> loadAccounts() async {
    final loaded = await widget.state.loadLoginAccounts();
    if (!mounted) {
      return;
    }
    setState(() {
      accounts = loaded;
      loadingAccounts = false;
    });
  }

  Future<void> selectAccount(LoginAccountRecord account) async {
    if (account.hasSession) {
      setState(() => error = null);
      try {
        await widget.state.loginWithSavedSession(account);
        if (mounted) {
          await loadAccounts();
        }
        return;
      } catch (_) {
        if (mounted) {
          await loadAccounts();
          setState(
            () => error = context.strings.text(
              'Saved session expired. Please enter password.',
            ),
          );
        }
      }
    }
    username.text = account.username.trim().isEmpty
        ? '${account.uid}'
        : account.username.trim();
    password.clear();
    setState(() => error = null);
    passwordFocus.requestFocus();
  }

  Future<void> removeAccount(LoginAccountRecord account) async {
    await widget.state.removeLoginAccount(account);
    await loadAccounts();
  }

  Future<void> submit() async {
    final strings = context.strings;
    final name = username.text.trim();
    final emailText = email.text.trim();
    final code = emailCode.text.trim();
    final needsPassword = loginMode != _LoginMode.emailCode;
    final missingCredential = switch (loginMode) {
      _LoginMode.usernamePassword => name.isEmpty,
      _LoginMode.emailPassword => emailText.isEmpty,
      _LoginMode.emailCode => emailText.isEmpty || code.isEmpty,
    };
    if (missingCredential || (needsPassword && password.text.isEmpty)) {
      setState(() => error = strings.text('Please fill all fields.'));
      return;
    }
    try {
      switch (loginMode) {
        case _LoginMode.usernamePassword:
          await widget.state.login(name, password.text);
          break;
        case _LoginMode.emailPassword:
          await widget.state.loginByEmail(emailText, password.text);
          break;
        case _LoginMode.emailCode:
          await widget.state.loginByEmailCode(emailText, code);
          break;
      }
      if (mounted) {
        await loadAccounts();
      }
    } catch (err) {
      setState(() => error = err.toString());
    }
  }

  Future<void> sendLoginCode() async {
    final strings = context.strings;
    if (email.text.trim().isEmpty) {
      setState(() => error = strings.text('Please enter your email.'));
      return;
    }
    setState(() {
      sendingLoginCode = true;
      error = null;
    });
    try {
      final response = await widget.state.sendLoginEmailCode(email.text);
      if (!mounted) {
        return;
      }
      CsacToastMessenger.of(
        context,
      ).showToast(CsacToast(content: Text(strings.text('Code sent.'))));
      startResendTimer(response.resendAfter);
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => sendingLoginCode = false);
      }
    }
  }

  Future<void> openServerSettings() async {
    await Navigator.of(context).push(
      CsacPageRoute<void>(
        builder: (_) => SettingsScreen(
          state: widget.state,
          initialDeveloperOptionsExpanded: true,
        ),
      ),
    );
    if (mounted) {
      await loadAccounts();
      setState(() {});
    }
  }

  Future<void> openRegister() async {
    await Navigator.of(context).push(
      CsacPageRoute<void>(builder: (_) => RegisterScreen(state: widget.state)),
    );
  }

  Future<void> openAccountRestore() async {
    await Navigator.of(context).push(
      CsacPageRoute<void>(
        builder: (_) => AccountRestoreScreen(state: widget.state),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    final serverUrl = widget.state.preferences.serverUrl.trim().isEmpty
        ? strings.text('Default server')
        : widget.state.preferences.serverUrl.trim();
    return CsacPageScaffold(
      backgroundColor: colors.systemBackground,
      body: SafeArea(
        child: Center(
          child: CsacSingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primary, primary.withValues(alpha: 0.65)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.35),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const _AppIconImage(size: 88, borderRadius: 22),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    strings.text('CsAC Mobile'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.label,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.text('Sign in to continue'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.secondaryLabel,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 36),
                  CupertinoSlidingSegmentedControl<_LoginMode>(
                    groupValue: loginMode,
                    children: {
                      for (final mode in _LoginMode.values)
                        mode: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(loginModeLabel(strings, mode)),
                        ),
                    },
                    onValueChanged: (value) {
                      if (value == null || widget.state.loading) {
                        return;
                      }
                      setState(() {
                        loginMode = value;
                        error = null;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      color: colors.cardBackground,
                      child: Column(
                        children: [
                          if (loginMode == _LoginMode.usernamePassword)
                            _LoginField(
                              controller: username,
                              placeholder: strings.text('Username'),
                              icon: CupertinoIcons.person,
                              textInputAction: TextInputAction.next,
                            )
                          else
                            _LoginField(
                              controller: email,
                              placeholder: strings.text('Email'),
                              icon: CupertinoIcons.mail,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                            ),
                          Container(height: 0.5, color: colors.separator),
                          if (loginMode == _LoginMode.emailCode)
                            _LoginField(
                              controller: emailCode,
                              placeholder: strings.text('Email login code'),
                              icon: CupertinoIcons.number,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => submit(),
                            )
                          else
                            _LoginField(
                              controller: password,
                              focusNode: passwordFocus,
                              placeholder: strings.text('Password'),
                              icon: CupertinoIcons.lock,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => submit(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (loginMode == _LoginMode.emailCode) ...[
                    const SizedBox(height: 10),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: resendSeconds > 0 || sendingLoginCode
                          ? null
                          : sendLoginCode,
                      child: sendingLoginCode
                          ? CupertinoActivityIndicator(
                              radius: 9,
                              color: colors.primaryColor,
                            )
                          : Text(
                              resendSeconds > 0
                                  ? strings.format('Resend in {seconds}s', {
                                      'seconds': resendSeconds,
                                    })
                                  : strings.text('Send login code'),
                            ),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.destructive.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.exclamationmark_circle,
                            size: 15,
                            color: colors.destructive,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              error!,
                              style: TextStyle(
                                color: colors.destructive,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _AuthPrimaryButton(
                    label: strings.text(
                      loginMode == _LoginMode.emailCode
                          ? 'Login with code'
                          : 'Login',
                    ),
                    loading: widget.state.loading,
                    onTap: submit,
                  ),
                  const SizedBox(height: 6),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: widget.state.loading ? null : openAccountRestore,
                    child: Text(strings.text('Restore deleted account')),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: widget.state.loading
                        ? null
                        : () =>
                              widget.state.switchClientMode(AppClientMode.acop),
                    child: Text(strings.text('CsAC Open Platform')),
                  ),
                  const SizedBox(height: 12),
                  if (loadingAccounts)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CupertinoActivityIndicator(radius: 10),
                      ),
                    )
                  else
                    _RecentAccountsPanel(
                      accounts: accounts.take(3).toList(),
                      onSelect: selectAccount,
                      onRemove: removeAccount,
                      onAdd: widget.state.loading ? null : openRegister,
                    ),
                  const SizedBox(height: 24),
                  _CsacPressable(
                    onTap: openServerSettings,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.globe,
                          size: 13,
                          color: colors.tertiaryLabel,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            serverUrl,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.tertiaryLabel,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          CupertinoIcons.pencil,
                          size: 11,
                          color: colors.tertiaryLabel,
                        ),
                      ],
                    ),
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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final username = TextEditingController();
  final nickname = TextEditingController();
  final email = TextEditingController();
  final emailCode = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  XFile? avatar;
  Uint8List? avatarBytes;
  bool submitting = false;
  bool sendingCode = false;
  bool acceptedAgreements = false;
  int resendSeconds = 0;
  Timer? resendTimer;
  String? error;

  @override
  void dispose() {
    username.dispose();
    nickname.dispose();
    email.dispose();
    emailCode.dispose();
    password.dispose();
    confirmPassword.dispose();
    resendTimer?.cancel();
    super.dispose();
  }

  Future<void> sendEmailCode() async {
    final strings = context.strings;
    if (!acceptedAgreements) {
      setState(
        () => error = strings.text(
          'Please read and agree to the User Agreement and Privacy Policy.',
        ),
      );
      return;
    }
    if (email.text.trim().isEmpty) {
      setState(() => error = strings.text('Please enter your email.'));
      return;
    }
    setState(() {
      sendingCode = true;
      error = null;
    });
    try {
      final response = await widget.state.sendRegisterEmailCode(email.text);
      if (!mounted) {
        return;
      }
      CsacToastMessenger.of(
        context,
      ).showToast(CsacToast(content: Text(strings.text('Code sent.'))));
      setState(() => resendSeconds = response.resendAfter);
      resendTimer?.cancel();
      resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (resendSeconds <= 1) {
          timer.cancel();
          setState(() => resendSeconds = 0);
        } else {
          setState(() => resendSeconds -= 1);
        }
      });
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => sendingCode = false);
      }
    }
  }

  Future<void> chooseAvatar() async {
    final strings = context.strings;
    final picked = isMobilePlatform
        ? await pickImageForMobileGallery()
        : await openFile(
            acceptedTypeGroups: <XTypeGroup>[
              XTypeGroup(
                label: strings.text('Images'),
                extensions: imageExtensions,
              ),
            ],
          );
    if (picked != null && mounted) {
      final bytes = await picked.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        avatar = picked;
        avatarBytes = bytes;
      });
    }
  }

  Future<void> submit() async {
    final strings = context.strings;
    if (!acceptedAgreements) {
      setState(
        () => error = strings.text(
          'Please read and agree to the User Agreement and Privacy Policy.',
        ),
      );
      return;
    }
    if (username.text.trim().isEmpty ||
        nickname.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        emailCode.text.trim().isEmpty ||
        password.text.isEmpty ||
        confirmPassword.text.isEmpty) {
      setState(() => error = strings.text('Please fill all fields.'));
      return;
    }
    if (password.text.length < 6) {
      setState(
        () =>
            error = strings.text('New password must be at least 6 characters.'),
      );
      return;
    }
    if (password.text != confirmPassword.text) {
      setState(() => error = strings.text('Passwords do not match.'));
      return;
    }
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await widget.state.register(
        username: username.text,
        nickname: nickname.text,
        email: email.text,
        emailCode: emailCode.text,
        password: password.text,
        confirmPassword: confirmPassword.text,
        avatarBytes: avatarBytes,
        avatarFileName: avatar?.name ?? '',
      );
      if (!mounted) {
        return;
      }
      CsacToastMessenger.of(
        context,
      ).showToast(CsacToast(content: Text(strings.text('Account created.'))));
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  void openAgreementDocument(String title, String assetPath) {
    Navigator.of(context).push(
      CsacPageRoute<void>(
        builder: (_) => AgreementDocumentScreen(
          title: context.strings.text(title),
          assetPath: assetPath,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    return CsacPageScaffold(
      backgroundColor: colors.systemBackground,
      appBar: CsacNavigationBar(title: Text(strings.text('Register account'))),
      body: SafeArea(
        child: Center(
          child: CsacSingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: _CsacPressable(
                      onTap: submitting ? null : chooseAvatar,
                      child: Stack(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: avatarBytes == null
                                  ? LinearGradient(
                                      colors: [
                                        primary.withValues(alpha: 0.15),
                                        primary.withValues(alpha: 0.05),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              image: avatarBytes == null
                                  ? null
                                  : DecorationImage(
                                      image: MemoryImage(avatarBytes!),
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            child: avatarBytes == null
                                ? Icon(
                                    CupertinoIcons.camera_fill,
                                    size: 32,
                                    color: primary,
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colors.systemBackground,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                CupertinoIcons.pencil,
                                size: 13,
                                color: CupertinoColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _CupertinoGroupedCard(
                    margin: EdgeInsets.zero,
                    children: [
                      _CupertinoFormField(
                        controller: username,
                        placeholder: strings.text('Username'),
                        icon: CupertinoIcons.at,
                        enabled: !submitting,
                        textInputAction: TextInputAction.next,
                      ),
                      _CupertinoFormField(
                        controller: nickname,
                        placeholder: strings.text('Nickname'),
                        icon: CupertinoIcons.person,
                        enabled: !submitting,
                        textInputAction: TextInputAction.next,
                      ),
                      _CupertinoFormField(
                        controller: email,
                        placeholder: strings.text('Email'),
                        icon: CupertinoIcons.mail,
                        enabled: !submitting,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      _CupertinoFormField(
                        controller: emailCode,
                        placeholder: strings.text('Email verification code'),
                        icon: CupertinoIcons.number,
                        enabled: !submitting,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                      ),
                      _CupertinoFormField(
                        controller: password,
                        placeholder: strings.text('Password'),
                        icon: CupertinoIcons.lock,
                        obscureText: true,
                        enabled: !submitting,
                        textInputAction: TextInputAction.next,
                      ),
                      _CupertinoFormField(
                        controller: confirmPassword,
                        placeholder: strings.text('Confirm password'),
                        icon: CupertinoIcons.lock_rotation,
                        obscureText: true,
                        enabled: !submitting,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => submit(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _RegisterAgreementConsent(
                    accepted: acceptedAgreements,
                    enabled: !submitting && !sendingCode,
                    onChanged: (value) =>
                        setState(() => acceptedAgreements = value),
                    onOpenUserAgreement: () => openAgreementDocument(
                      'User Agreement',
                      'docs/用户协议.txt',
                    ),
                    onOpenPrivacyPolicy: () => openAgreementDocument(
                      'Privacy Policy',
                      'docs/隐私政策.txt',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AuthPrimaryButton(
                    label: resendSeconds > 0
                        ? strings.format('Resend in {seconds}s', {
                            'seconds': resendSeconds,
                          })
                        : strings.text('Send code'),
                    loading: sendingCode,
                    onTap: acceptedAgreements && resendSeconds <= 0
                        ? sendEmailCode
                        : null,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.destructive.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: colors.destructive,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _AuthPrimaryButton(
                    label: strings.text('Create account'),
                    loading: submitting,
                    onTap: acceptedAgreements ? submit : null,
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    onPressed: submitting ? null : () => Navigator.pop(context),
                    child: Text(strings.text('Back to login')),
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

class _RegisterAgreementConsent extends StatelessWidget {
  const _RegisterAgreementConsent({
    required this.accepted,
    required this.enabled,
    required this.onChanged,
    required this.onOpenUserAgreement,
    required this.onOpenPrivacyPolicy,
  });

  final bool accepted;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenUserAgreement;
  final VoidCallback onOpenPrivacyPolicy;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    return _CsacPressable(
      onTap: enabled ? () => onChanged(!accepted) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: _csacPressFeedbackDuration,
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: accepted ? primary : colors.cardBackground,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: accepted
                    ? primary
                    : colors.separator.withValues(alpha: 0.65),
                width: 1,
              ),
            ),
            child: accepted
                ? const Icon(
                    CupertinoIcons.check_mark,
                    size: 15,
                    color: CupertinoColors.white,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  strings.text('I have read and agree to'),
                  style: TextStyle(color: colors.secondaryLabel, fontSize: 13),
                ),
                const SizedBox(width: 4),
                _AgreementLink(
                  label: strings.text('User Agreement'),
                  onTap: onOpenUserAgreement,
                ),
                const SizedBox(width: 4),
                Text(
                  strings.text('and'),
                  style: TextStyle(color: colors.secondaryLabel, fontSize: 13),
                ),
                const SizedBox(width: 4),
                _AgreementLink(
                  label: strings.text('Privacy Policy'),
                  onTap: onOpenPrivacyPolicy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgreementLink extends StatelessWidget {
  const _AgreementLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = CupertinoTheme.of(context).primaryColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: primary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class AgreementDocumentScreen extends StatelessWidget {
  const AgreementDocumentScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  final String title;
  final String assetPath;

  Future<String> loadDocument() async {
    final raw = await rootBundle.loadString(assetPath);
    return raw.replaceFirst(RegExp(r'^\uFEFF'), '').trimRight();
  }

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final strings = context.strings;
    return CsacPageScaffold(
      backgroundColor: colors.systemBackground,
      appBar: CsacNavigationBar(title: Text(title)),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: loadDocument(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CupertinoActivityIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    strings.text('Unable to load document.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.secondaryLabel),
                  ),
                ),
              );
            }
            return CsacSingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: _AdaptivePageFrame(
                maxWidth: 720,
                child: Text(
                  snapshot.data ?? '',
                  style: TextStyle(
                    color: colors.label,
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class EmailVerificationRequiredScreen extends StatefulWidget {
  const EmailVerificationRequiredScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<EmailVerificationRequiredScreen> createState() =>
      _EmailVerificationRequiredScreenState();
}

class _EmailVerificationRequiredScreenState
    extends State<EmailVerificationRequiredScreen> {
  final email = TextEditingController();
  final emailCode = TextEditingController();
  bool sendingCode = false;
  bool verifying = false;
  int resendSeconds = 0;
  Timer? resendTimer;
  String? error;

  @override
  void dispose() {
    email.dispose();
    emailCode.dispose();
    resendTimer?.cancel();
    super.dispose();
  }

  Future<void> sendEmailCode() async {
    final strings = context.strings;
    if (email.text.trim().isEmpty) {
      setState(() => error = strings.text('Please enter your email.'));
      return;
    }
    setState(() {
      sendingCode = true;
      error = null;
    });
    try {
      final response = await widget.state.sendEmailBindCode(email.text);
      if (!mounted) {
        return;
      }
      CsacToastMessenger.of(
        context,
      ).showToast(CsacToast(content: Text(strings.text('Code sent.'))));
      setState(() => resendSeconds = response.resendAfter);
      resendTimer?.cancel();
      resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (resendSeconds <= 1) {
          timer.cancel();
          setState(() => resendSeconds = 0);
        } else {
          setState(() => resendSeconds -= 1);
        }
      });
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => sendingCode = false);
      }
    }
  }

  Future<void> verify() async {
    final strings = context.strings;
    if (email.text.trim().isEmpty || emailCode.text.trim().isEmpty) {
      setState(() => error = strings.text('Please fill all fields.'));
      return;
    }
    setState(() {
      verifying = true;
      error = null;
    });
    try {
      await widget.state.verifyEmailBindCode(
        email: email.text,
        emailCode: emailCode.text,
      );
      if (!mounted) {
        return;
      }
      CsacToastMessenger.of(
        context,
      ).showToast(CsacToast(content: Text(strings.text('Email verified.'))));
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => verifying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return CsacPageScaffold(
      backgroundColor: colors.systemBackground,
      appBar: CsacNavigationBar(
        title: Text(strings.text('Email verification')),
      ),
      body: SafeArea(
        child: Center(
          child: CsacSingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    CupertinoIcons.mail_solid,
                    size: 52,
                    color: CupertinoTheme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.text('Verify your email to continue'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.label,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.text(
                      'Existing accounts must verify an email before using CsAC.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.secondaryLabel),
                  ),
                  const SizedBox(height: 24),
                  _CupertinoGroupedCard(
                    margin: EdgeInsets.zero,
                    children: [
                      _CupertinoFormField(
                        controller: email,
                        placeholder: strings.text('Email'),
                        icon: CupertinoIcons.mail,
                        enabled: !verifying,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      _CupertinoFormField(
                        controller: emailCode,
                        placeholder: strings.text('Email verification code'),
                        icon: CupertinoIcons.number,
                        enabled: !verifying,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => verify(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _AuthPrimaryButton(
                    label: resendSeconds > 0
                        ? strings.format('Resend in {seconds}s', {
                            'seconds': resendSeconds,
                          })
                        : strings.text('Send code'),
                    loading: sendingCode,
                    onTap: resendSeconds > 0 ? null : sendEmailCode,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.destructive),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _AuthPrimaryButton(
                    label: strings.text('Verify email'),
                    loading: verifying,
                    onTap: verify,
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    onPressed: verifying
                        ? null
                        : () => widget.state.logout(keepLoginRecord: false),
                    child: Text(strings.text('Sign out')),
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

class AccountRestoreScreen extends StatefulWidget {
  const AccountRestoreScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<AccountRestoreScreen> createState() => _AccountRestoreScreenState();
}

class _AccountRestoreScreenState extends State<AccountRestoreScreen> {
  final email = TextEditingController();
  final token = TextEditingController();
  bool requesting = false;
  bool restoring = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    token.dispose();
    super.dispose();
  }

  Future<void> requestRestore() async {
    final strings = context.strings;
    if (email.text.trim().isEmpty) {
      setState(() => error = strings.text('Please enter your email.'));
      return;
    }
    setState(() {
      requesting = true;
      error = null;
    });
    try {
      await widget.state.requestAccountRestore(email.text);
      if (!mounted) {
        return;
      }
      CsacToastMessenger.of(context).showToast(
        CsacToast(content: Text(strings.text('Restore email sent.'))),
      );
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => requesting = false);
      }
    }
  }

  Future<void> restore() async {
    final strings = context.strings;
    if (email.text.trim().isEmpty || token.text.trim().isEmpty) {
      setState(() => error = strings.text('Please fill all fields.'));
      return;
    }
    setState(() {
      restoring = true;
      error = null;
    });
    try {
      await widget.state.restoreAccount(
        email: email.text,
        restoreToken: token.text,
      );
      if (!mounted) {
        return;
      }
      CsacToastMessenger.of(
        context,
      ).showToast(CsacToast(content: Text(strings.text('Account restored.'))));
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => restoring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return CsacPageScaffold(
      backgroundColor: colors.systemBackground,
      appBar: CsacNavigationBar(
        title: Text(strings.text('Restore deleted account')),
      ),
      body: SafeArea(
        child: Center(
          child: CsacSingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    CupertinoIcons.arrow_counterclockwise_circle_fill,
                    size: 56,
                    color: CupertinoTheme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.text('Restore a deleted account'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.label,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.text(
                      'Accounts in the 14-day cooling period can be restored with an email token.',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.secondaryLabel),
                  ),
                  const SizedBox(height: 24),
                  _CupertinoGroupedCard(
                    margin: EdgeInsets.zero,
                    children: [
                      _CupertinoFormField(
                        controller: email,
                        placeholder: strings.text('Email'),
                        icon: CupertinoIcons.mail,
                        enabled: !restoring,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      _CupertinoFormField(
                        controller: token,
                        placeholder: strings.text('Restore token'),
                        icon: CupertinoIcons.number,
                        enabled: !restoring,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => restore(),
                      ),
                    ],
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.destructive),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _AuthPrimaryButton(
                    label: strings.text('Send restore email'),
                    loading: requesting,
                    onTap: requesting || restoring ? null : requestRestore,
                  ),
                  const SizedBox(height: 12),
                  _AuthPrimaryButton(
                    label: strings.text('Restore account'),
                    loading: restoring,
                    onTap: requesting || restoring ? null : restore,
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

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.placeholder,
    required this.icon,
    this.focusNode,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final FocusNode? focusNode;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return CupertinoTextField(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      prefix: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Icon(icon, size: 18, color: colors.secondaryLabel),
      ),
      padding: const EdgeInsets.fromLTRB(10, 16, 16, 16),
      decoration: const BoxDecoration(),
      style: TextStyle(fontSize: 16, color: colors.label),
      placeholderStyle: TextStyle(fontSize: 16, color: colors.tertiaryLabel),
    );
  }
}

class _CupertinoFormField extends StatelessWidget {
  const _CupertinoFormField({
    required this.controller,
    required this.placeholder,
    required this.icon,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final bool obscureText;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return CupertinoTextField(
      controller: controller,
      enabled: enabled,
      placeholder: placeholder,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      prefix: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Icon(icon, size: 18, color: colors.secondaryLabel),
      ),
      padding: const EdgeInsets.fromLTRB(10, 15, 16, 15),
      decoration: const BoxDecoration(),
      style: TextStyle(fontSize: 16, color: colors.label),
      placeholderStyle: TextStyle(fontSize: 16, color: colors.tertiaryLabel),
    );
  }
}

class _AuthPrimaryButton extends StatelessWidget {
  const _AuthPrimaryButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final String label;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    final enabled = onTap != null && !loading;
    return _CsacPressable(
      onTap: loading ? null : onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: enabled
                ? [primary, primary.withValues(alpha: 0.8)]
                : [colors.tertiaryFill, colors.tertiaryFill],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: loading
            ? const CupertinoActivityIndicator(color: CupertinoColors.white)
            : Text(
                label,
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _RecentAccountsPanel extends StatelessWidget {
  const _RecentAccountsPanel({
    required this.accounts,
    required this.onSelect,
    this.onRemove,
    this.onAdd,
  });

  final List<LoginAccountRecord> accounts;
  final ValueChanged<LoginAccountRecord> onSelect;
  final ValueChanged<LoginAccountRecord>? onRemove;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return _MotionPane(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              strings.text('Recent accounts'),
              style: TextStyle(
                color: colors.secondaryLabel,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colors.separator.withValues(alpha: 0.35),
                width: 0.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                children: [
                  for (var i = 0; i < accounts.length; i++) ...[
                    _RecentAccountTile(
                      account: accounts[i],
                      onSelect: () => onSelect(accounts[i]),
                      onRemove: onRemove == null
                          ? null
                          : () => onRemove!(accounts[i]),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 64),
                      child: Container(height: 0.5, color: colors.separator),
                    ),
                  ],
                  _AccountAddTile(onTap: onAdd),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentAccountTile extends StatelessWidget {
  const _RecentAccountTile({
    required this.account,
    required this.onSelect,
    this.onRemove,
  });

  final LoginAccountRecord account;
  final VoidCallback onSelect;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final strings = context.strings;
    return _CsacPressable(
      onTap: onSelect,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Row(
          children: [
            _Avatar(
              url: account.avatar,
              fallback: Icons.person_rounded,
              radius: 19,
              name: account.displayName,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.label,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      account.subtitle,
                      if (account.hasSession) strings.text('Saved session'),
                    ].where((part) => part.trim().isNotEmpty).join(' | '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.secondaryLabel,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                minimumSize: Size.zero,
                onPressed: onRemove,
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  color: colors.tertiaryLabel,
                  size: 19,
                ),
              )
            else
              Icon(
                CupertinoIcons.chevron_right,
                color: colors.tertiaryLabel,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}

class _AccountAddTile extends StatelessWidget {
  const _AccountAddTile({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final strings = context.strings;
    return _CsacPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.primaryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.person_add,
                color: colors.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.text('Add account'),
                    style: TextStyle(
                      color: colors.label,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    strings.text('Sign in or create another account'),
                    style: TextStyle(
                      color: colors.secondaryLabel,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: colors.tertiaryLabel,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
