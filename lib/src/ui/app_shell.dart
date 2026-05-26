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

  Future<void> openRegister() async {
    error = null;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RegisterScreen(state: widget.state),
      ),
    );
    if (mounted) {
      setState(() {});
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
                    onPressed: widget.state.loading ? null : openRegister,
                    icon: const Icon(Icons.person_add_alt),
                    label: Text(strings.text('Create account')),
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
  final imagePicker = ImagePicker();
  final username = TextEditingController();
  final nickname = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final usernameFocus = FocusNode();
  final nicknameFocus = FocusNode();
  final passwordFocus = FocusNode();
  final confirmPasswordFocus = FocusNode();
  Uint8List? avatarBytes;
  String? avatarFileName;
  String? error;
  bool submitting = false;

  @override
  void dispose() {
    username.dispose();
    nickname.dispose();
    password.dispose();
    confirmPassword.dispose();
    usernameFocus.dispose();
    nicknameFocus.dispose();
    passwordFocus.dispose();
    confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> chooseAvatar() async {
    final picked = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null || !mounted) {
      return;
    }
    final bytes = await picked.readAsBytes();
    if (!mounted) {
      return;
    }
    setState(() {
      avatarBytes = bytes;
      avatarFileName = picked.name;
      error = null;
    });
  }

  String? validate() {
    final name = username.text.trim();
    final nick = nickname.text.trim();
    final usernamePattern = RegExp(r'^[A-Za-z0-9_@.-]+$');
    if (name.length < 3 || name.length > 32) {
      return context.strings.text('Username must be 3-32 characters.');
    }
    if (!usernamePattern.hasMatch(name)) {
      return context.strings.text(
        'Username can only contain letters, numbers, _, @, ., and -.',
      );
    }
    if (nick.isEmpty) {
      return context.strings.text('Please enter a nickname.');
    }
    if (nick.length > 16) {
      return context.strings.text('Nickname can be up to 16 characters.');
    }
    if (password.text.length < 6) {
      return context.strings.text('Password must be at least 6 characters.');
    }
    if (password.text != confirmPassword.text) {
      return context.strings.text('Passwords do not match.');
    }
    return null;
  }

  Future<void> submit() async {
    final validationError = validate();
    if (validationError != null) {
      setState(() => error = validationError);
      return;
    }
    setState(() {
      submitting = true;
      error = null;
    });
    try {
      await widget.state.register(
        username: username.text.trim(),
        nickname: nickname.text.trim(),
        password: password.text,
        confirmPassword: confirmPassword.text,
        avatarBytes: avatarBytes,
        avatarFileName: avatarFileName,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Account created.'))),
      );
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('Register account'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: scheme.primaryContainer,
                          backgroundImage: avatarBytes == null
                              ? null
                              : MemoryImage(avatarBytes!),
                          child: avatarBytes == null
                              ? Icon(
                                  Icons.person_add_alt_rounded,
                                  size: 42,
                                  color: scheme.onPrimaryContainer,
                                )
                              : null,
                        ),
                        IconButton.filledTonal(
                          onPressed: submitting ? null : chooseAvatar,
                          icon: const Icon(Icons.photo_camera_outlined),
                          tooltip: strings.text(
                            avatarBytes == null
                                ? 'Choose avatar'
                                : 'Change avatar',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    strings.text(
                      avatarBytes == null
                          ? 'Skip avatar for now'
                          : 'Avatar selected',
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: username,
                    focusNode: usernameFocus,
                    enabled: !submitting,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: strings.text('Username'),
                      prefixIcon: const Icon(Icons.alternate_email),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => nicknameFocus.requestFocus(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nickname,
                    focusNode: nicknameFocus,
                    enabled: !submitting,
                    maxLength: 16,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: strings.text('Nickname'),
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => passwordFocus.requestFocus(),
                  ),
                  const SizedBox(height: 2),
                  TextField(
                    controller: password,
                    focusNode: passwordFocus,
                    enabled: !submitting,
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: strings.text('Password'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => confirmPasswordFocus.requestFocus(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: confirmPassword,
                    focusNode: confirmPasswordFocus,
                    enabled: !submitting,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: strings.text('Confirm password'),
                      prefixIcon: const Icon(Icons.lock_reset),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => submit(),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    Text(error!, style: TextStyle(color: scheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: submitting ? null : submit,
                    icon: submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt),
                    label: Text(strings.text('Create account')),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
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
