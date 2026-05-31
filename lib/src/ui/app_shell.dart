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
      ? 'https://github.com/Leonmmcoset/csac-terminal/releases/latest'
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
  final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  final navigatorKey = GlobalKey<NavigatorState>();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      maybeCheckForUpdatesOnStartup();
    });
  }

  @override
  void dispose() {
    state.removeListener(handleStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    updateChecker.close();
    super.dispose();
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
        currentVersion: '${packageInfo.version}+${packageInfo.buildNumber}'
            .trim(),
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
        return MaterialApp(
          title: CsacStrings(
            localeForLanguage(state.preferences.language),
          ).text('CsAC Mobile'),
          scaffoldMessengerKey: scaffoldMessengerKey,
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
          theme: buildCsacTheme(
            Brightness.light,
            Color(state.preferences.themeColorValue),
            state.preferences.fontStyle,
          ),
          darkTheme: buildCsacTheme(
            Brightness.dark,
            Color(state.preferences.themeColorValue),
            state.preferences.fontStyle,
          ),
          themeMode: state.preferences.themeMode,
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

String? fontFamilyForStyle(CsacFontStyle style) {
  switch (style) {
    case CsacFontStyle.system:
      return null;
    case CsacFontStyle.serif:
      return Platform.isIOS || Platform.isMacOS ? 'Times New Roman' : 'serif';
    case CsacFontStyle.rounded:
      return Platform.isIOS || Platform.isMacOS ? 'SF Pro Rounded' : null;
    case CsacFontStyle.monospace:
      return Platform.isIOS || Platform.isMacOS ? 'Menlo' : 'monospace';
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
      MaterialPageRoute<void>(
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
      MaterialPageRoute<void>(
        builder: (_) => RegisterScreen(state: widget.state),
      ),
    );
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
                    focusNode: passwordFocus,
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
                  const SizedBox(height: 10),
                  if (loadingAccounts)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (accounts.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        strings.text('Recent accounts'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final account in accounts.take(3))
                      Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: _RoundedInkClip(
                          child: ListTile(
                            leading: _Avatar(
                              url: account.avatar,
                              fallback: Icons.person_rounded,
                              radius: 20,
                            ),
                            title: Text(
                              account.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                account.subtitle,
                                if (account.hasSession)
                                  strings.text('Saved session'),
                              ].join(' | '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              tooltip: strings.text('Remove login record'),
                              onPressed: () => removeAccount(account),
                              icon: const Icon(Icons.close),
                            ),
                            onTap: () => selectAccount(account),
                          ),
                        ),
                      ),
                    const SizedBox(height: 2),
                  ],
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: widget.state.loading ? null : openRegister,
                    icon: const Icon(Icons.person_add_alt),
                    label: Text(strings.text('Register account')),
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
      setState(() => avatar = picked);
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
      final selectedAvatar = avatar;
      final avatarBytes = selectedAvatar == null
          ? null
          : await selectedAvatar.readAsBytes();
      await widget.state.register(
        username: username.text,
        nickname: nickname.text,
        password: password.text,
        confirmPassword: confirmPassword.text,
        avatarBytes: avatarBytes,
        avatarFileName: selectedAvatar?.name ?? '',
      );
      if (!mounted) {
        return;
      }
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
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('Register account'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            TextField(
              controller: username,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: strings.text('Username'),
                helperText: strings.text('3-32 letters, numbers, _@.-'),
                prefixIcon: const Icon(Icons.person_outline),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nickname,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: strings.text('Nickname'),
                prefixIcon: const Icon(Icons.badge_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: strings.text('Password'),
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPassword,
              obscureText: true,
              onSubmitted: (_) => submit(),
              decoration: InputDecoration(
                labelText: strings.text('Confirm password'),
                prefixIcon: const Icon(Icons.lock_reset),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: submitting ? null : chooseAvatar,
              icon: const Icon(Icons.image_outlined),
              label: Text(
                avatar == null
                    ? strings.text('Choose avatar')
                    : strings.format('Selected: {name}', {
                        'name': avatar!.name,
                      }),
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
              onPressed: submitting ? null : submit,
              icon: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt),
              label: Text(strings.text('Register')),
            ),
          ],
        ),
      ),
    );
  }
}
