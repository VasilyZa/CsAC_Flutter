part of '../../main.dart';

// ============================================================================
// 主题构建
// ============================================================================

CupertinoThemeData buildCupertinoTheme(Brightness brightness, Color seedColor) {
  final isDark = brightness == Brightness.dark;
  return CupertinoThemeData(
    brightness: brightness,
    primaryColor: seedColor,
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF000000)
        : const Color(0xFFF2F2F7),
    barBackgroundColor: isDark
        ? const Color(0xCC1C1C1E)
        : const Color(0xCCF9F9F9),
    textTheme: CupertinoTextThemeData(
      primaryColor: seedColor,
      textStyle: TextStyle(
        fontSize: 16,
        color: isDark ? CupertinoColors.white : CupertinoColors.black,
      ),
      navTitleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: isDark ? CupertinoColors.white : CupertinoColors.black,
      ),
      navLargeTitleTextStyle: TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: isDark ? CupertinoColors.white : CupertinoColors.black,
      ),
    ),
  );
}

Brightness resolvedBrightness(ThemeMode mode, BuildContext context) {
  switch (mode) {
    case ThemeMode.light:
      return Brightness.light;
    case ThemeMode.dark:
      return Brightness.dark;
    case ThemeMode.system:
      return MediaQuery.platformBrightnessOf(context);
  }
}

// ============================================================================
// 根应用
// ============================================================================

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
        final brightness = resolvedBrightness(
          state.preferences.themeMode,
          context,
        );
        return CupertinoApp(
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
          theme: buildCupertinoTheme(
            brightness,
            Color(state.preferences.themeColorValue),
          ),
          home: state.bootstrapping
              ? SplashScreen(
                  key: const ValueKey('splash'),
                  status: state.restoreStatus,
                )
              : state.user == null
              ? LoginScreen(key: const ValueKey('login'), state: state)
              : MainShell(key: const ValueKey('main'), state: state),
        );
      },
    );
  }
}

// ============================================================================
// 启动屏
// ============================================================================

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    return CupertinoPageScaffold(
      backgroundColor: colors.systemBackground,
      child: Center(
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
              context.strings.text(appClientNameKey()),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: colors.label,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              status,
              style: TextStyle(fontSize: 14, color: colors.secondaryLabel),
            ),
            const SizedBox(height: 24),
            CupertinoActivityIndicator(radius: 12, color: primary),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 登录页
// ============================================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});
  final CsacAppState state;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  List<LoginAccountRecord> _accounts = const <LoginAccountRecord>[];
  bool _loadingAccounts = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    final loaded = await widget.state.loadLoginAccounts();
    if (!mounted) return;
    setState(() {
      _accounts = loaded;
      _loadingAccounts = false;
    });
  }

  Future<void> _selectAccount(LoginAccountRecord account) async {
    if (account.hasSession) {
      setState(() => _error = null);
      try {
        await widget.state.loginWithSavedSession(account);
        if (mounted) await _loadAccounts();
        return;
      } catch (_) {
        if (!mounted) return;
        await _loadAccounts();
        setState(
          () => _error = context.strings.text(
            'Saved session expired. Please enter password.',
          ),
        );
      }
    }
    _username.text = account.username.trim().isEmpty
        ? '${account.uid}'
        : account.username.trim();
    _password.clear();
    setState(() => _error = null);
    _passwordFocus.requestFocus();
  }

  Future<void> _removeAccount(LoginAccountRecord account) async {
    await widget.state.removeLoginAccount(account);
    await _loadAccounts();
  }

  Future<void> _submit() async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(
        () => _error = context.strings.text(
          'Username and password are required.',
        ),
      );
      return;
    }
    setState(() => _error = null);
    try {
      await widget.state.login(_username.text.trim(), _password.text);
      if (mounted) await _loadAccounts();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _openRegister() async {
    setState(() => _error = null);
    await _csacPush<void>(context, (_) => RegisterScreen(state: widget.state));
    if (mounted) await _loadAccounts();
  }

  Future<void> _openServerSettings() async {
    await _csacPush<void>(
      context,
      (_) => SettingsScreen(
        state: widget.state,
        initialDeveloperOptionsExpanded: true,
      ),
    );
    if (mounted) {
      await _loadAccounts();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    final serverUrl = widget.state.preferences.serverUrl.trim().isEmpty
        ? strings.text('Default server')
        : widget.state.preferences.serverUrl.trim();

    return CupertinoPageScaffold(
      backgroundColor: colors.systemBackground,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── App 图标 ──
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
                    strings.text(appClientNameKey()),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: colors.label,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.text('Sign in to continue'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: colors.secondaryLabel,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ── 输入框组 ──
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      color: colors.cardBackground,
                      child: Column(
                        children: [
                          _LoginField(
                            controller: _username,
                            placeholder: strings.text('Username'),
                            icon: CupertinoIcons.person,
                            textInputAction: TextInputAction.next,
                          ),
                          Container(height: 0.5, color: colors.separator),
                          _LoginField(
                            controller: _password,
                            focusNode: _passwordFocus,
                            placeholder: strings.text('Password'),
                            icon: CupertinoIcons.lock,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── 错误提示 ──
                  if (_error != null) ...[
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
                              _error!,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.destructive,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ── 登录按钮 ──
                  GestureDetector(
                    onTap: widget.state.loading ? null : _submit,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: widget.state.loading
                              ? [colors.tertiaryFill, colors.tertiaryFill]
                              : [primary, primary.withValues(alpha: 0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: widget.state.loading
                            ? []
                            : [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Center(
                        child: widget.state.loading
                            ? const CupertinoActivityIndicator(
                                color: CupertinoColors.white,
                              )
                            : Text(
                                strings.text('Login'),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_loadingAccounts)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CupertinoActivityIndicator(radius: 10),
                      ),
                    )
                  else
                    _RecentAccountsPanel(
                      accounts: _accounts.take(3).toList(),
                      onSelect: _selectAccount,
                      onRemove: _removeAccount,
                      onAdd: widget.state.loading ? null : _openRegister,
                    ),
                  const SizedBox(height: 24),

                  // ── 服务器信息 ──
                  GestureDetector(
                    onTap: _openServerSettings,
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
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.tertiaryLabel,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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

/// 登录页专用输入框行
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
      style: TextStyle(fontSize: 16, color: CsacColors.of(context).label),
      placeholderStyle: TextStyle(fontSize: 16, color: colors.tertiaryLabel),
    );
  }
}

class _RecentAccountsPanel extends StatelessWidget {
  const _RecentAccountsPanel({
    required this.accounts,
    required this.onSelect,
    this.onRemove,
    this.onAdd,
    this.currentUid,
    this.title,
  });

  final List<LoginAccountRecord> accounts;
  final ValueChanged<LoginAccountRecord> onSelect;
  final ValueChanged<LoginAccountRecord>? onRemove;
  final VoidCallback? onAdd;
  final int? currentUid;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            strings.text(title ?? 'Recent accounts'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.secondaryLabel,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: colors.cardBackground,
              border: Border.all(
                color: colors.separator.withValues(alpha: 0.35),
                width: 0.5,
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < accounts.length; i++) ...[
                  _RecentAccountTile(
                    account: accounts[i],
                    current:
                        currentUid != null && accounts[i].uid == currentUid,
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
    ).csacCardEnter(delayMs: 40);
  }
}

class _RecentAccountTile extends StatelessWidget {
  const _RecentAccountTile({
    required this.account,
    this.current = false,
    required this.onSelect,
    this.onRemove,
  });

  final LoginAccountRecord account;
  final bool current;
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
              fallback: CupertinoIcons.person_fill,
              size: 38,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.label,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      account.subtitle,
                      if (account.hasSession) strings.text('Saved session'),
                      if (current) strings.text('Current'),
                    ].where((part) => part.trim().isNotEmpty).join(' | '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.secondaryLabel,
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
                  size: 19,
                  color: colors.tertiaryLabel,
                ),
              )
            else
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: colors.tertiaryLabel,
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
                size: 20,
                color: colors.primaryColor,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.label,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    strings.text('Sign in or create another account'),
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              size: 16,
              color: colors.tertiaryLabel,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 注册页
// ============================================================================

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.state});
  final CsacAppState state;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _imagePicker = ImagePicker();
  final _username = TextEditingController();
  final _nickname = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  Uint8List? _avatarBytes;
  String? _avatarFileName;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _username.dispose();
    _nickname.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _chooseAvatar() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _avatarBytes = bytes;
      _avatarFileName = picked.name;
    });
  }

  String? _validate() {
    final name = _username.text.trim();
    final nick = _nickname.text.trim();
    if (name.length < 3 || name.length > 32) {
      return context.strings.text('Username must be 3-32 characters.');
    }
    if (!RegExp(r'^[A-Za-z0-9_@.-]+$').hasMatch(name)) {
      return context.strings.text(
        'Username can only contain letters, numbers, _, @, ., and -.',
      );
    }
    if (nick.isEmpty) return context.strings.text('Please enter a nickname.');
    if (nick.length > 16) {
      return context.strings.text('Nickname can be up to 16 characters.');
    }
    if (_password.text.length < 6) {
      return context.strings.text('Password must be at least 6 characters.');
    }
    if (_password.text != _confirmPassword.text) {
      return context.strings.text('Passwords do not match.');
    }
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.state.register(
        username: _username.text.trim(),
        nickname: _nickname.text.trim(),
        password: _password.text,
        confirmPassword: _confirmPassword.text,
        avatarBytes: _avatarBytes,
        avatarFileName: _avatarFileName,
      );
      if (!mounted) return;
      _showCupertinoToast(context, context.strings.text('Account created.'));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;

    return CupertinoPageScaffold(
      backgroundColor: colors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(strings.text('Register account')),
        backgroundColor: colors.navBarBackground,
        border: null,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 头像选择 ──
                Center(
                  child: GestureDetector(
                    onTap: _submitting ? null : _chooseAvatar,
                    child: Stack(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: _avatarBytes == null
                                ? LinearGradient(
                                    colors: [
                                      primary.withValues(alpha: 0.15),
                                      primary.withValues(alpha: 0.05),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            image: _avatarBytes != null
                                ? DecorationImage(
                                    image: MemoryImage(_avatarBytes!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _avatarBytes == null
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

                // ── 表单 ──
                _CupertinoGroupedCard(
                  margin: EdgeInsets.zero,
                  children: [
                    _CupertinoFormField(
                      controller: _username,
                      placeholder: strings.text('Username'),
                      icon: CupertinoIcons.at,
                      enabled: !_submitting,
                      textInputAction: TextInputAction.next,
                    ),
                    _CupertinoFormField(
                      controller: _nickname,
                      placeholder: strings.text('Nickname'),
                      icon: CupertinoIcons.person,
                      enabled: !_submitting,
                      textInputAction: TextInputAction.next,
                    ),
                    _CupertinoFormField(
                      controller: _password,
                      placeholder: strings.text('Password'),
                      icon: CupertinoIcons.lock,
                      obscureText: true,
                      enabled: !_submitting,
                      textInputAction: TextInputAction.next,
                    ),
                    _CupertinoFormField(
                      controller: _confirmPassword,
                      placeholder: strings.text('Confirm password'),
                      icon: CupertinoIcons.lock_rotation,
                      obscureText: true,
                      enabled: !_submitting,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                  ],
                ),

                if (_error != null) ...[
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
                      _error!,
                      style: TextStyle(fontSize: 13, color: colors.destructive),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                GestureDetector(
                  onTap: _submitting ? null : _submit,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primary, primary.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _submitting
                          ? const CupertinoActivityIndicator(
                              color: CupertinoColors.white,
                            )
                          : Text(
                              strings.text('Create account'),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.white,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CupertinoButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  child: Text(
                    strings.text('Back to login'),
                    style: TextStyle(color: primary),
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
