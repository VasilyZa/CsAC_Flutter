part of '../../main.dart';

Future<void> showVersionUpdateDialog(
  BuildContext context,
  VersionUpdateInfo result,
) async {
  final strings = context.strings;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(strings.text('New version available')),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
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
                  SelectableText(result.releaseNotes.trim()),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Release link copied.'))),
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
  final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Conversation>? notificationTapSub;
  bool locked = false;
  bool wasBackgrounded = false;
  bool appLockSessionUnlocked = false;
  bool appLockStateSeen = false;
  bool lastCanUseAppLock = false;
  bool startupUpdateCheckStarted = false;
  int appLockUserId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state = CsacAppState();
    state.addListener(handleStateChanged);
    unawaited(state.initialize());
    unawaited(localNotifications.initialize());
    notificationTapSub = localNotifications.taps.listen(openNotificationChat);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      maybeCheckForUpdatesOnStartup();
    });
  }

  @override
  void dispose() {
    state.removeListener(handleStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    notificationTapSub?.cancel();
    updateChecker.close();
    super.dispose();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.hidden ||
        lifecycleState == AppLifecycleState.inactive) {
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
      lockIfNeeded();
    }
  }

  void handleStateChanged() {
    maybeCheckForUpdatesOnStartup();
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

  void maybeCheckForUpdatesOnStartup() {
    if (startupUpdateCheckStarted ||
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
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              strings.format('New version available: {version}', {
                'version': result.displayLatestVersion,
              }),
            ),
            action: SnackBarAction(
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
        final appTitle = CsacStrings(
          localeForLanguage(state.preferences.language),
        ).text('CsAC Mobile');
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
            return _DesktopCommandPaletteHost(
              state: state,
              navigatorKey: navigatorKey,
              scaffoldMessengerKey: scaffoldMessengerKey,
              enabled:
                  isDesktopPlatform &&
                  !locked &&
                  !state.bootstrapping &&
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
                      : state.user == null
                      ? LoginScreen(
                          key: const ValueKey<String>('login'),
                          state: state,
                        )
                      : MainShell(
                          key: const ValueKey<String>('main'),
                          state: state,
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

ThemeData buildCsacTheme(
  Brightness brightness,
  Color seedColor,
  CsacFontStyle fontStyle,
) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  final fontFamily = fontFamilyForStyle(fontStyle);
  final fontFamilyFallback = fontFamilyFallbackForStyle(fontStyle);
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
  );
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    cardColor: scheme.surfaceContainerLow,
    cardTheme: CardThemeData(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
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
    return Scaffold(
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

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  final passwordFocus = FocusNode();
  List<LoginAccountRecord> accounts = const <LoginAccountRecord>[];
  bool loadingAccounts = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadAccounts();
  }

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    passwordFocus.dispose();
    super.dispose();
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
      if (mounted) {
        await loadAccounts();
      }
    } catch (err) {
      setState(() => error = err.toString());
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

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    final serverUrl = widget.state.preferences.serverUrl.trim().isEmpty
        ? strings.text('Default server')
        : widget.state.preferences.serverUrl.trim();
    return Scaffold(
      backgroundColor: colors.systemBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      color: colors.cardBackground,
                      child: Column(
                        children: [
                          _LoginField(
                            controller: username,
                            placeholder: strings.text('Username'),
                            icon: CupertinoIcons.person,
                            textInputAction: TextInputAction.next,
                          ),
                          Container(height: 0.5, color: colors.separator),
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
                    label: strings.text('Login'),
                    loading: widget.state.loading,
                    onTap: submit,
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
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  XFile? avatar;
  Uint8List? avatarBytes;
  bool submitting = false;
  String? error;

  @override
  void dispose() {
    username.dispose();
    nickname.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> chooseAvatar() async {
    final picked = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(
          label: context.strings.text('Images'),
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
    if (username.text.trim().isEmpty ||
        nickname.text.trim().isEmpty ||
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
        password: password.text,
        confirmPassword: confirmPassword.text,
        avatarBytes: avatarBytes,
        avatarFileName: avatar?.name ?? '',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.text('Account created.'))));
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

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    return Scaffold(
      backgroundColor: colors.systemBackground,
      appBar: AppBar(title: Text(strings.text('Register account'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
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
                    onTap: submit,
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

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.placeholder,
    required this.icon,
    this.focusNode,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final FocusNode? focusNode;
  final bool obscureText;
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
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final bool obscureText;
  final bool enabled;
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    return _CsacPressable(
      onTap: loading ? null : onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: loading
                ? [colors.tertiaryFill, colors.tertiaryFill]
                : [primary, primary.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: loading
              ? []
              : [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
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
