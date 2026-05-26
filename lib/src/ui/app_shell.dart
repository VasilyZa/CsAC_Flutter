part of '../../main.dart';

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
          ).text(appClientNameKey()),
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
          ),
          darkTheme: buildCsacTheme(
            Brightness.dark,
            Color(state.preferences.themeColorValue),
          ),
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

ThemeData buildCsacTheme(Brightness brightness, Color seedColor) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
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
              context.strings.text(appClientNameKey()),
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
                    strings.text(appClientNameKey()),
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
