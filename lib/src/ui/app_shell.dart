part of '../../main.dart';

// ============================================================================
// 主题构建
// ============================================================================

CupertinoThemeData buildCupertinoTheme(Brightness brightness, Color seedColor) {
  final isDark = brightness == Brightness.dark;
  return CupertinoThemeData(
    brightness: brightness,
    primaryColor: seedColor,
    scaffoldBackgroundColor:
        isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7),
    barBackgroundColor:
        isDark ? const Color(0xCC1C1C1E) : const Color(0xCCF9F9F9),
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
              ? SplashScreen(status: state.restoreStatus)
              : state.user == null
              ? LoginScreen(state: state)
              : MainShell(state: state),
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
              child: const Icon(
                CupertinoIcons.chat_bubble_2_fill,
                size: 40,
                color: CupertinoColors.white,
              ),
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
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = context.strings.text('Username and password are required.'));
      return;
    }
    setState(() => _error = null);
    try {
      await widget.state.login(_username.text.trim(), _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _openRegister() async {
    setState(() => _error = null);
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(builder: (_) => RegisterScreen(state: widget.state)),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openServerSettings() async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => SettingsScreen(
          state: widget.state,
          initialDeveloperOptionsExpanded: true,
        ),
      ),
    );
    if (mounted) setState(() {});
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
                      child: const Icon(
                        CupertinoIcons.chat_bubble_2_fill,
                        size: 44,
                        color: CupertinoColors.white,
                      ),
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
                    style: TextStyle(fontSize: 15, color: colors.secondaryLabel),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.destructive.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.exclamationmark_circle, size: 15, color: colors.destructive),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(fontSize: 13, color: colors.destructive),
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
                            ? const CupertinoActivityIndicator(color: CupertinoColors.white)
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

                  // ── 注册按钮 ──
                  GestureDetector(
                    onTap: widget.state.loading ? null : _openRegister,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: colors.cardBackground,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.separator),
                      ),
                      child: Center(
                        child: Text(
                          strings.text('Create account'),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            color: primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── 服务器信息 ──
                  GestureDetector(
                    onTap: _openServerSettings,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.globe, size: 13, color: colors.tertiaryLabel),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            serverUrl,
                            style: TextStyle(fontSize: 12, color: colors.tertiaryLabel),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(CupertinoIcons.pencil, size: 11, color: colors.tertiaryLabel),
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
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String placeholder;
  final IconData icon;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return CupertinoTextField(
      controller: controller,
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
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() { _avatarBytes = bytes; _avatarFileName = picked.name; });
  }

  String? _validate() {
    final name = _username.text.trim();
    final nick = _nickname.text.trim();
    if (name.length < 3 || name.length > 32) return context.strings.text('Username must be 3-32 characters.');
    if (!RegExp(r'^[A-Za-z0-9_@.-]+$').hasMatch(name)) return context.strings.text('Username can only contain letters, numbers, _, @, ., and -.');
    if (nick.isEmpty) return context.strings.text('Please enter a nickname.');
    if (nick.length > 16) return context.strings.text('Nickname can be up to 16 characters.');
    if (_password.text.length < 6) return context.strings.text('Password must be at least 6 characters.');
    if (_password.text != _confirmPassword.text) return context.strings.text('Passwords do not match.');
    return null;
  }

  Future<void> _submit() async {
    final err = _validate();
    if (err != null) { setState(() => _error = err); return; }
    setState(() { _submitting = true; _error = null; });
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
                                    colors: [primary.withValues(alpha: 0.15), primary.withValues(alpha: 0.05)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            image: _avatarBytes != null
                                ? DecorationImage(image: MemoryImage(_avatarBytes!), fit: BoxFit.cover)
                                : null,
                          ),
                          child: _avatarBytes == null
                              ? Icon(CupertinoIcons.camera_fill, size: 32, color: primary)
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
                              border: Border.all(color: colors.systemBackground, width: 2),
                            ),
                            child: const Icon(CupertinoIcons.pencil, size: 13, color: CupertinoColors.white),
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
                    _CupertinoFormField(controller: _username, placeholder: strings.text('Username'), icon: CupertinoIcons.at, enabled: !_submitting, textInputAction: TextInputAction.next),
                    _CupertinoFormField(controller: _nickname, placeholder: strings.text('Nickname'), icon: CupertinoIcons.person, enabled: !_submitting, textInputAction: TextInputAction.next),
                    _CupertinoFormField(controller: _password, placeholder: strings.text('Password'), icon: CupertinoIcons.lock, obscureText: true, enabled: !_submitting, textInputAction: TextInputAction.next),
                    _CupertinoFormField(controller: _confirmPassword, placeholder: strings.text('Confirm password'), icon: CupertinoIcons.lock_rotation, obscureText: true, enabled: !_submitting, textInputAction: TextInputAction.done, onSubmitted: (_) => _submit()),
                  ],
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.destructive.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_error!, style: TextStyle(fontSize: 13, color: colors.destructive)),
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
                        BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Center(
                      child: _submitting
                          ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                          : Text(strings.text('Create account'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: CupertinoColors.white)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CupertinoButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  child: Text(strings.text('Back to login'), style: TextStyle(color: primary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
