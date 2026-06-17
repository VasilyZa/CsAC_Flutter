part of '../../main.dart';

enum _AcopAuthMode { password, code, register }

enum _AcopSection { bots, admin, account }

enum _AcopBotDetailSection { scripts, logs, permissions }

class AcopLoginScreen extends StatefulWidget {
  const AcopLoginScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<AcopLoginScreen> createState() => _AcopLoginScreenState();
}

class _AcopLoginScreenState extends State<AcopLoginScreen> {
  late final TextEditingController serverUrl;
  final email = TextEditingController();
  final password = TextEditingController();
  final code = TextEditingController();
  final developerName = TextEditingController();
  final csacUsername = TextEditingController();
  final csacPassword = TextEditingController();
  Timer? codeTimer;
  _AcopAuthMode mode = _AcopAuthMode.password;
  bool savingServer = false;
  bool sendingCode = false;
  int codeResendRemaining = 0;
  String? message;
  String? error;

  @override
  void initState() {
    super.initState();
    serverUrl = TextEditingController(
      text: widget.state.preferences.acopServerUrl,
    );
  }

  @override
  void dispose() {
    codeTimer?.cancel();
    serverUrl.dispose();
    email.dispose();
    password.dispose();
    code.dispose();
    developerName.dispose();
    csacUsername.dispose();
    csacPassword.dispose();
    super.dispose();
  }

  bool get canSendCode => !sendingCode && codeResendRemaining <= 0;

  void startCodeCountdown() {
    codeTimer?.cancel();
    setState(() => codeResendRemaining = 60);
    codeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (codeResendRemaining <= 1) {
        timer.cancel();
        setState(() => codeResendRemaining = 0);
      } else {
        setState(() => codeResendRemaining--);
      }
    });
  }

  Future<void> saveServerIfNeeded() async {
    setState(() => savingServer = true);
    try {
      await widget.state.updateAcopServerUrl(serverUrl.text);
      if (mounted) {
        serverUrl.text = widget.state.preferences.acopServerUrl;
      }
    } finally {
      if (mounted) setState(() => savingServer = false);
    }
  }

  Future<void> sendCode() async {
    final targetEmail = email.text.trim();
    if (!_looksLikeEmail(targetEmail)) {
      setState(
        () => error = context.strings.text('Please enter a valid email.'),
      );
      return;
    }
    setState(() {
      sendingCode = true;
      message = null;
      error = null;
    });
    try {
      await saveServerIfNeeded();
      await widget.state.acopSendCode(
        targetEmail,
        mode == _AcopAuthMode.register ? 'register' : 'login',
      );
      if (!mounted) return;
      setState(() {
        message = context.strings.text('Code sent. It expires in 10 minutes.');
      });
      startCodeCountdown();
    } catch (err) {
      if (mounted) setState(() => error = err.toString());
    } finally {
      if (mounted) setState(() => sendingCode = false);
    }
  }

  bool validate() {
    final strings = context.strings;
    if (!_looksLikeEmail(email.text.trim())) {
      setState(() => error = strings.text('Please enter a valid email.'));
      return false;
    }
    if (mode != _AcopAuthMode.code && password.text.isEmpty) {
      setState(() => error = strings.text('Email and password are required.'));
      return false;
    }
    if (mode != _AcopAuthMode.password && code.text.trim().length != 6) {
      setState(() => error = strings.text('Please enter the 6-digit code.'));
      return false;
    }
    if (mode == _AcopAuthMode.register &&
        (developerName.text.trim().isEmpty ||
            csacUsername.text.trim().isEmpty ||
            csacPassword.text.isEmpty)) {
      setState(() => error = strings.text('Please fill all fields.'));
      return false;
    }
    return true;
  }

  Future<void> submit() async {
    if (widget.state.loading || savingServer || !validate()) return;
    setState(() {
      error = null;
      message = null;
    });
    try {
      await saveServerIfNeeded();
      switch (mode) {
        case _AcopAuthMode.password:
          await widget.state.acopLogin(email.text.trim(), password.text);
          break;
        case _AcopAuthMode.code:
          await widget.state.acopLoginByCode(email.text.trim(), code.text);
          break;
        case _AcopAuthMode.register:
          await widget.state.acopRegister(
            email: email.text.trim(),
            password: password.text,
            developerName: developerName.text.trim(),
            code: code.text.trim(),
            csacUsername: csacUsername.text.trim(),
            csacPassword: csacPassword.text,
          );
          break;
      }
    } catch (err) {
      if (mounted) setState(() => error = err.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final loading = widget.state.loading || savingServer;
    return CsacPageScaffold(
      backgroundColor: colors.systemBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 820;
            final horizontalPadding = isWide ? 32.0 : 16.0;
            final hero = _AcopLoginHero(isWide: isWide);
            final form = _AcopLoginFormCard(
              mode: mode,
              loading: loading,
              sendingCode: sendingCode,
              canSendCode: canSendCode,
              codeResendRemaining: codeResendRemaining,
              message: message,
              error: error,
              serverUrl: serverUrl,
              email: email,
              password: password,
              code: code,
              developerName: developerName,
              csacUsername: csacUsername,
              csacPassword: csacPassword,
              onModeChanged: (value) {
                if (loading) return;
                setState(() {
                  mode = value;
                  error = null;
                  message = null;
                });
              },
              onSendCode: sendCode,
              onSubmit: submit,
              onSwitchToChat: () =>
                  widget.state.switchClientMode(AppClientMode.csac),
            );
            return Center(
              child: CsacSingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: isWide ? 28 : 16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWide ? 980 : 520),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: hero),
                            const SizedBox(width: 28),
                            SizedBox(width: 440, child: form),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [hero, const SizedBox(height: 16), form],
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

class _AcopLoginHero extends StatelessWidget {
  const _AcopLoginHero({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return CsacCard(
      child: Padding(
        padding: EdgeInsets.all(isWide ? 30 : 22),
        child: Column(
          crossAxisAlignment: isWide
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: colors.primaryColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                CupertinoIcons.chevron_left_slash_chevron_right,
                size: 34,
                color: colors.primaryColor,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              strings.text('CsAC Open Platform'),
              textAlign: isWide ? TextAlign.left : TextAlign.center,
              style: TextStyle(
                fontSize: isWide ? 34 : 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
                color: colors.label,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.text('Independent developer platform mode'),
              textAlign: isWide ? TextAlign.left : TextAlign.center,
              style: TextStyle(
                color: colors.secondaryLabel,
                fontSize: 15,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            _AcopCapabilityRow(
              icon: CupertinoIcons.cube_box,
              title: strings.text('Bot management'),
              subtitle: strings.text(
                'Create bots, manage tokens and open scripts.',
              ),
            ),
            const SizedBox(height: 12),
            _AcopCapabilityRow(
              icon: CupertinoIcons.doc_text,
              title: strings.text('Scripts'),
              subtitle: strings.text(
                'Create, edit, toggle and test bot scripts.',
              ),
            ),
            const SizedBox(height: 12),
            _AcopCapabilityRow(
              icon: CupertinoIcons.shield,
              title: strings.text('Permissions'),
              subtitle: strings.text('Request notify/http permissions.'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcopCapabilityRow extends StatelessWidget {
  const _AcopCapabilityRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: colors.fill,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: colors.primaryColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.label,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: colors.secondaryLabel,
                  fontSize: 12.5,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AcopLoginFormCard extends StatelessWidget {
  const _AcopLoginFormCard({
    required this.mode,
    required this.loading,
    required this.sendingCode,
    required this.canSendCode,
    required this.codeResendRemaining,
    required this.serverUrl,
    required this.email,
    required this.password,
    required this.code,
    required this.developerName,
    required this.csacUsername,
    required this.csacPassword,
    required this.onModeChanged,
    required this.onSendCode,
    required this.onSubmit,
    required this.onSwitchToChat,
    this.message,
    this.error,
  });

  final _AcopAuthMode mode;
  final bool loading;
  final bool sendingCode;
  final bool canSendCode;
  final int codeResendRemaining;
  final String? message;
  final String? error;
  final TextEditingController serverUrl;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController code;
  final TextEditingController developerName;
  final TextEditingController csacUsername;
  final TextEditingController csacPassword;
  final ValueChanged<_AcopAuthMode> onModeChanged;
  final Future<void> Function() onSendCode;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onSwitchToChat;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return CsacCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 390;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CsacTextField(
                  controller: serverUrl,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: strings.text('ACOP server address'),
                    helperText: strings.text(
                      'Leave empty to use the default server.',
                    ),
                    prefixIcon: const Icon(CupertinoIcons.globe),
                  ),
                ),
                const SizedBox(height: 14),
                _AcopAuthModePicker(
                  mode: mode,
                  compact: compact,
                  enabled: !loading,
                  onChanged: onModeChanged,
                ),
                const SizedBox(height: 14),
                CsacTextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: strings.text('Email'),
                    prefixIcon: const Icon(CupertinoIcons.mail),
                  ),
                ),
                const SizedBox(height: 14),
                if (mode != _AcopAuthMode.code) ...[
                  CsacTextField(
                    controller: password,
                    obscureText: true,
                    textInputAction: mode == _AcopAuthMode.register
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onSubmitted: (_) => onSubmit(),
                    decoration: InputDecoration(
                      labelText: strings.text('Password'),
                      prefixIcon: const Icon(CupertinoIcons.lock),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (mode != _AcopAuthMode.password) ...[
                  compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _AcopCodeField(controller: code),
                            const SizedBox(height: 10),
                            _AcopSendCodeButton(
                              enabled: canSendCode && !loading && !sendingCode,
                              sending: sendingCode,
                              remaining: codeResendRemaining,
                              onPressed: onSendCode,
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(child: _AcopCodeField(controller: code)),
                            const SizedBox(width: 10),
                            _AcopSendCodeButton(
                              enabled: canSendCode && !loading && !sendingCode,
                              sending: sendingCode,
                              remaining: codeResendRemaining,
                              onPressed: onSendCode,
                            ),
                          ],
                        ),
                  const SizedBox(height: 14),
                ],
                if (mode == _AcopAuthMode.register) ...[
                  CsacTextField(
                    controller: developerName,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: strings.text('Developer name'),
                      prefixIcon: const Icon(CupertinoIcons.person),
                    ),
                  ),
                  const SizedBox(height: 14),
                  CsacTextField(
                    controller: csacUsername,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: strings.text('CsAC username'),
                      prefixIcon: const Icon(CupertinoIcons.person_crop_circle),
                    ),
                  ),
                  const SizedBox(height: 14),
                  CsacTextField(
                    controller: csacPassword,
                    obscureText: true,
                    onSubmitted: (_) => onSubmit(),
                    decoration: InputDecoration(
                      labelText: strings.text('CsAC password'),
                      prefixIcon: const Icon(CupertinoIcons.lock_shield),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (message != null) _AcopInlineMessage(message!),
                if (error != null) _AcopInlineMessage(error!, isError: true),
                CupertinoButton.filled(
                  onPressed: loading ? null : onSubmit,
                  child: loading
                      ? const CupertinoActivityIndicator()
                      : Text(
                          strings.text(
                            mode == _AcopAuthMode.register
                                ? 'Register'
                                : 'Login',
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                CupertinoButton(
                  onPressed: loading ? null : onSwitchToChat,
                  child: Text(strings.text('Switch to CsAC chat')),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AcopAuthModePicker extends StatelessWidget {
  const _AcopAuthModePicker({
    required this.mode,
    required this.compact,
    required this.enabled,
    required this.onChanged,
  });

  final _AcopAuthMode mode;
  final bool compact;
  final bool enabled;
  final ValueChanged<_AcopAuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final labels = <_AcopAuthMode, String>{
      _AcopAuthMode.password: strings.text('Password login'),
      _AcopAuthMode.code: strings.text('Code login'),
      _AcopAuthMode.register: strings.text('Register'),
    };
    if (!compact) {
      return CupertinoSlidingSegmentedControl<_AcopAuthMode>(
        groupValue: mode,
        children: {
          for (final entry in labels.entries)
            entry.key: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                entry.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        },
        onValueChanged: (value) {
          if (value != null && enabled) onChanged(value);
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in labels.entries) ...[
          _AcopModeButton(
            selected: mode == entry.key,
            enabled: enabled,
            label: entry.value,
            onTap: () => onChanged(entry.key),
          ),
          if (entry.key != labels.keys.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _AcopModeButton extends StatelessWidget {
  const _AcopModeButton({
    required this.selected,
    required this.enabled,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final bool enabled;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: selected
          ? colors.primaryColor.withValues(alpha: 0.16)
          : colors.fill,
      borderRadius: BorderRadius.circular(12),
      onPressed: enabled ? onTap : null,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? colors.primaryColor : colors.label,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _AcopCodeField extends StatelessWidget {
  const _AcopCodeField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return CsacTextField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 6,
      decoration: InputDecoration(
        labelText: context.strings.text('Email code'),
        prefixIcon: const Icon(CupertinoIcons.number),
      ),
    );
  }
}

class _AcopSendCodeButton extends StatelessWidget {
  const _AcopSendCodeButton({
    required this.enabled,
    required this.sending,
    required this.remaining,
    required this.onPressed,
  });

  final bool enabled;
  final bool sending;
  final int remaining;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: CsacColors.of(context).fill,
      onPressed: enabled ? onPressed : null,
      child: sending
          ? const CupertinoActivityIndicator()
          : Text(
              remaining > 0
                  ? strings.format('Resend in {seconds}s', {
                      'seconds': remaining,
                    })
                  : strings.text('Send code'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}

class AcopPlatformShell extends StatefulWidget {
  const AcopPlatformShell({super.key, required this.state});

  final CsacAppState state;

  @override
  State<AcopPlatformShell> createState() => _AcopPlatformShellState();
}

class _AcopPlatformShellState extends State<AcopPlatformShell> {
  late final TextEditingController serverUrl;
  _AcopSection section = _AcopSection.bots;
  List<AcopBot> bots = const <AcopBot>[];
  List<AcopBot> adminBots = const <AcopBot>[];
  bool loadingBots = false;
  bool loadingAdminBots = false;
  bool savingServer = false;
  String? botsError;
  String? adminError;

  @override
  void initState() {
    super.initState();
    serverUrl = TextEditingController(
      text: widget.state.preferences.acopServerUrl,
    );
    unawaited(refreshBots());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(showQuickEditNoticeIfNeeded());
    });
  }

  @override
  void dispose() {
    serverUrl.dispose();
    super.dispose();
  }

  void showToast(String message) {
    CsacToastMessenger.maybeOf(
      context,
    )?.showToast(CsacToast(content: Text(message)));
  }

  Future<void> refreshBots() async {
    if (loadingBots) return;
    setState(() {
      loadingBots = true;
      botsError = null;
    });
    try {
      final loaded = await widget.state.acopClient.listBots();
      if (mounted) setState(() => bots = loaded);
    } catch (err) {
      if (mounted) setState(() => botsError = err.toString());
    } finally {
      if (mounted) setState(() => loadingBots = false);
    }
  }

  Future<void> refreshAdminBots() async {
    if (loadingAdminBots) return;
    setState(() {
      loadingAdminBots = true;
      adminError = null;
    });
    try {
      final loaded = await widget.state.acopClient.listAdminBots();
      if (mounted) setState(() => adminBots = loaded);
    } catch (err) {
      if (mounted) setState(() => adminError = err.toString());
    } finally {
      if (mounted) setState(() => loadingAdminBots = false);
    }
  }

  Future<void> createBot() async {
    final draft = await _showAcopBotDialog(context);
    if (draft == null || !mounted) return;
    try {
      final created = await widget.state.acopClient.createBot(
        botName: draft.name,
        botDesc: draft.description,
      );
      await refreshBots();
      if (!mounted) return;
      if (created.botToken.isNotEmpty) {
        await _showAcopTokenDialog(context, created.botToken);
      } else {
        showToast(context.strings.text('Bot created.'));
      }
    } catch (err) {
      showToast(err.toString());
    }
  }

  Future<void> showQuickEditNoticeIfNeeded() async {
    if (await AcopQuickEditNoticeStore.isSeen()) return;
    await AcopQuickEditNoticeStore.markSeen();
    if (!mounted) return;
    await showCupertinoCsacDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(context.strings.text('ACOP quick edit mode')),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            context.strings.text(
              'This mode is only for quick editing. For more features, please use the website: https://acop.csac.chat/',
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.strings.text('Got it')),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              const url = 'https://acop.csac.chat/';
              final navigator = Navigator.of(dialogContext);
              final opened = await launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              );
              if (!opened) {
                await Clipboard.setData(const ClipboardData(text: url));
                if (mounted) showToast(context.strings.text('Link copied.'));
              }
              if (navigator.mounted) navigator.pop();
            },
            child: Text(context.strings.text('Open website')),
          ),
        ],
      ),
    );
  }

  Future<void> uploadAvatarForBot(AcopBot bot) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 5 * 1024 * 1024) {
      showToast(context.strings.text('Avatar cannot exceed 5MB.'));
      return;
    }
    try {
      await widget.state.acopClient.uploadBotAvatar(
        botId: bot.botId,
        bytes: bytes,
        filename: picked.name,
      );
      await refreshBots();
      if (!mounted) return;
      showToast(context.strings.text('Avatar uploaded.'));
    } catch (err) {
      showToast(err.toString());
    }
  }

  Future<void> editBot(AcopBot bot) async {
    final draft = await _showAcopBotDialog(context, bot: bot);
    if (draft == null || !mounted) return;
    try {
      await widget.state.acopClient.updateBot(
        botId: bot.botId,
        botName: draft.name,
        botDesc: draft.description,
      );
      await refreshBots();
      if (!mounted) return;
      showToast(context.strings.text('Saved.'));
    } catch (err) {
      showToast(err.toString());
    }
  }

  Future<void> resetBotToken(AcopBot bot) async {
    final confirmed = await _showAcopConfirmDialog(
      context,
      title: context.strings.text('Reset bot token?'),
      message: context.strings.text(
        'The old token will stop working after reset.',
      ),
      confirmLabel: context.strings.text('Reset token'),
    );
    if (confirmed != true || !mounted) return;
    try {
      final token = await widget.state.acopClient.resetBotToken(bot.botId);
      if (!mounted) return;
      await _showAcopTokenDialog(context, token);
    } catch (err) {
      showToast(err.toString());
    }
  }

  Future<void> deleteBot(AcopBot bot) async {
    final confirmed = await _showAcopConfirmDialog(
      context,
      title: context.strings.text('Delete bot?'),
      message: context.strings.format('Delete {name} permanently?', {
        'name': bot.botName,
      }),
      confirmLabel: context.strings.text('Delete'),
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.state.acopClient.deleteBot(bot.botId);
      await refreshBots();
      if (!mounted) return;
      showToast(context.strings.text('Deleted.'));
    } catch (err) {
      showToast(err.toString());
    }
  }

  Future<void> openBot(AcopBot bot) async {
    await Navigator.of(context).push(
      CsacPageRoute<void>(
        builder: (_) => AcopBotDetailScreen(state: widget.state, bot: bot),
      ),
    );
    if (mounted) await refreshBots();
  }

  Future<void> saveServer() async {
    setState(() => savingServer = true);
    try {
      final changed = await widget.state.updateAcopServerUrl(serverUrl.text);
      if (!mounted) return;
      serverUrl.text = widget.state.preferences.acopServerUrl;
      showToast(
        context.strings.text(
          changed
              ? 'ACOP server address saved. Please log in again.'
              : 'Server address is unchanged.',
        ),
      );
    } catch (err) {
      showToast(err.toString());
    } finally {
      if (mounted) setState(() => savingServer = false);
    }
  }

  Future<void> handlePermissionById() async {
    final draft = await _showAcopAdminPermissionDialog(context);
    if (draft == null || !mounted) return;
    try {
      await widget.state.acopClient.handlePermissionRequest(
        requestId: draft.requestId,
        action: draft.action,
        adminReply: draft.reply,
      );
      await refreshAdminBots();
      if (!mounted) return;
      showToast(context.strings.text('Permission request handled.'));
    } catch (err) {
      showToast(err.toString());
    }
  }

  Future<void> handlePermissionQuick(
    AcopPermissionRequest request,
    String action,
  ) async {
    try {
      await widget.state.acopClient.handlePermissionRequest(
        requestId: request.requestId,
        action: action,
        adminReply: action == 'approve'
            ? context.strings.text('Approved by admin.')
            : context.strings.text('Rejected by admin.'),
      );
      await refreshAdminBots();
      if (!mounted) return;
      showToast(context.strings.text('Permission request handled.'));
    } catch (err) {
      showToast(err.toString());
    }
  }

  void selectSection(_AcopSection value) {
    setState(() => section = value);
    if (value == _AcopSection.admin && adminBots.isEmpty && !loadingAdminBots) {
      unawaited(refreshAdminBots());
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 860;
    final page = switch (section) {
      _AcopSection.bots => _AcopBotsPage(
        apiClient: widget.state.acopClient,
        bots: bots,
        loading: loadingBots,
        error: botsError,
        onRefresh: refreshBots,
        onCreate: createBot,
        onOpen: openBot,
        onEdit: editBot,
        onUploadAvatar: uploadAvatarForBot,
        onResetToken: resetBotToken,
        onDelete: deleteBot,
      ),
      _AcopSection.admin => _AcopAdminPage(
        apiClient: widget.state.acopClient,
        bots: adminBots,
        loading: loadingAdminBots,
        error: adminError,
        onRefresh: refreshAdminBots,
        onHandlePermission: handlePermissionById,
        onHandleRequest: handlePermissionQuick,
      ),
      _AcopSection.account => _AcopAccountPage(
        state: widget.state,
        serverUrl: serverUrl,
        savingServer: savingServer,
        onSaveServer: saveServer,
        onResetServer: serverUrl.clear,
        onLogout: widget.state.acopLogout,
        onSwitchToChat: () => widget.state.switchClientMode(AppClientMode.csac),
      ),
    };
    return CsacPageScaffold(
      backgroundColor: colors.systemBackground,
      appBar: CsacNavigationBar(
        title: Text(strings.text('CsAC Open Platform')),
        actions: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: section == _AcopSection.admin
                ? refreshAdminBots
                : refreshBots,
            child: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: Row(
            key: ValueKey<bool>(isWide),
            children: [
              if (isWide)
                _AcopSidebar(section: section, onChanged: selectSection),
              Expanded(child: page),
            ],
          ),
        ),
      ),
      bottomNavigationBar: isWide
          ? null
          : CupertinoTabBar(
              currentIndex: _acopSectionIndex(section),
              onTap: (value) => selectSection(_acopSectionForIndex(value)),
              backgroundColor: CupertinoTheme.of(context).barBackgroundColor,
              activeColor: CupertinoTheme.of(context).primaryColor,
              inactiveColor: colors.secondaryLabel,
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(CupertinoIcons.cube_box),
                  activeIcon: const Icon(CupertinoIcons.cube_box_fill),
                  label: strings.text('Bots'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(CupertinoIcons.shield),
                  activeIcon: const Icon(CupertinoIcons.shield_fill),
                  label: strings.text('Admin'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(CupertinoIcons.person_crop_circle),
                  activeIcon: const Icon(
                    CupertinoIcons.person_crop_circle_fill,
                  ),
                  label: strings.text('Account'),
                ),
              ],
            ),
    );
  }
}

int _acopSectionIndex(_AcopSection section) {
  return switch (section) {
    _AcopSection.bots => 0,
    _AcopSection.admin => 1,
    _AcopSection.account => 2,
  };
}

_AcopSection _acopSectionForIndex(int index) {
  return switch (index) {
    1 => _AcopSection.admin,
    2 => _AcopSection.account,
    _ => _AcopSection.bots,
  };
}

class _AcopSidebar extends StatelessWidget {
  const _AcopSidebar({required this.section, required this.onChanged});

  final _AcopSection section;
  final ValueChanged<_AcopSection> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return Container(
      width: 196,
      decoration: BoxDecoration(
        color: colors.cardBackground,
        border: Border(right: BorderSide(color: colors.separator)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _AcopSidebarItem(
              selected: section == _AcopSection.bots,
              icon: CupertinoIcons.cube_box,
              label: strings.text('Bots'),
              onTap: () => onChanged(_AcopSection.bots),
            ),
            _AcopSidebarItem(
              selected: section == _AcopSection.admin,
              icon: CupertinoIcons.shield,
              label: strings.text('Admin'),
              onTap: () => onChanged(_AcopSection.admin),
            ),
            _AcopSidebarItem(
              selected: section == _AcopSection.account,
              icon: CupertinoIcons.person_crop_circle,
              label: strings.text('Account'),
              onTap: () => onChanged(_AcopSection.account),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcopSidebarItem extends StatelessWidget {
  const _AcopSidebarItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        color: selected ? colors.primaryColor.withValues(alpha: 0.14) : null,
        borderRadius: BorderRadius.circular(14),
        onPressed: onTap,
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? colors.primaryColor : colors.secondaryLabel,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: selected ? colors.primaryColor : colors.label,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcopBotsPage extends StatelessWidget {
  const _AcopBotsPage({
    required this.apiClient,
    required this.bots,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onCreate,
    required this.onOpen,
    required this.onEdit,
    required this.onUploadAvatar,
    required this.onResetToken,
    required this.onDelete,
  });

  final AcopApiClient apiClient;
  final List<AcopBot> bots;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onCreate;
  final Future<void> Function(AcopBot bot) onOpen;
  final Future<void> Function(AcopBot bot) onEdit;
  final Future<void> Function(AcopBot bot) onUploadAvatar;
  final Future<void> Function(AcopBot bot) onResetToken;
  final Future<void> Function(AcopBot bot) onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return _AcopRefreshList(
      onRefresh: onRefresh,
      children: [
        _AcopHeaderRow(
          title: strings.text('Bot management'),
          subtitle: strings.text(
            'Create bots, manage tokens and open scripts.',
          ),
          action: CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            onPressed: onCreate,
            child: Text(strings.text('Create bot')),
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Center(child: CupertinoActivityIndicator())
        else if (error != null)
          _AcopErrorPanel(message: error!, onRetry: onRefresh)
        else if (bots.isEmpty)
          _AcopEmptyPanel(message: strings.text('No bots yet.'))
        else
          CsacCard(
            child: Column(
              children: [
                for (var i = 0; i < bots.length; i++) ...[
                  if (i > 0) const CsacDivider(height: 1),
                  _AcopBotTile(
                    avatarUrl: apiClient.resolveAssetUrl(bots[i].botAvatar),
                    bot: bots[i],
                    onTap: () => onOpen(bots[i]),
                    onEdit: () => onEdit(bots[i]),
                    onUploadAvatar: () => onUploadAvatar(bots[i]),
                    onResetToken: () => onResetToken(bots[i]),
                    onDelete: () => onDelete(bots[i]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _AcopAdminPage extends StatelessWidget {
  const _AcopAdminPage({
    required this.apiClient,
    required this.bots,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onHandlePermission,
    required this.onHandleRequest,
  });

  final AcopApiClient apiClient;
  final List<AcopBot> bots;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onHandlePermission;
  final Future<void> Function(AcopPermissionRequest request, String action)
  onHandleRequest;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return _AcopRefreshList(
      onRefresh: onRefresh,
      children: [
        _AcopHeaderRow(
          title: strings.text('Admin tools'),
          subtitle: strings.text(
            'View all bots and handle permission requests.',
          ),
          action: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            color: CsacColors.of(context).fill,
            onPressed: onHandlePermission,
            child: Text(strings.text('Handle permission')),
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Center(child: CupertinoActivityIndicator())
        else if (error != null)
          _AcopErrorPanel(message: error!, onRetry: onRefresh)
        else if (bots.isEmpty)
          _AcopEmptyPanel(message: strings.text('No admin bot data.'))
        else
          CsacCard(
            child: Column(
              children: [
                for (var i = 0; i < bots.length; i++) ...[
                  if (i > 0) const CsacDivider(height: 1),
                  _AcopAdminBotTile(
                    bot: bots[i],
                    avatarUrl: apiClient.resolveAssetUrl(bots[i].botAvatar),
                    onHandleRequest: onHandleRequest,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _AcopAccountPage extends StatelessWidget {
  const _AcopAccountPage({
    required this.state,
    required this.serverUrl,
    required this.savingServer,
    required this.onSaveServer,
    required this.onResetServer,
    required this.onLogout,
    required this.onSwitchToChat,
  });

  final CsacAppState state;
  final TextEditingController serverUrl;
  final bool savingServer;
  final Future<void> Function() onSaveServer;
  final VoidCallback onResetServer;
  final Future<void> Function() onLogout;
  final Future<void> Function() onSwitchToChat;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final developer = state.acopDeveloper;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AcopHeaderRow(
                  title: strings.text('Developer account'),
                  subtitle: state.acopClient.baseUrl,
                ),
                const SizedBox(height: 12),
                CsacCard(
                  child: Column(
                    children: [
                      _AcopInfoTile(
                        icon: CupertinoIcons.person_badge_plus,
                        label:
                            developer?.devName ?? strings.text('Not logged in'),
                        value: developer?.email ?? '',
                      ),
                      const CsacDivider(height: 1),
                      _AcopInfoTile(
                        icon: CupertinoIcons.number,
                        label: strings.text('Developer ID'),
                        value: developer == null ? '-' : '${developer.devId}',
                      ),
                      const CsacDivider(height: 1),
                      _AcopInfoTile(
                        icon: CupertinoIcons.lock,
                        label: strings.text('API key'),
                        value: developer?.apiKey ?? '-',
                        copyable: developer?.apiKey.isNotEmpty == true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CsacCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CsacTextField(
                          controller: serverUrl,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => onSaveServer(),
                          decoration: InputDecoration(
                            labelText: strings.text('ACOP server address'),
                            helperText: strings.text(
                              'Leave empty to use the default server.',
                            ),
                            prefixIcon: const Icon(CupertinoIcons.globe),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              color: CsacColors.of(context).fill,
                              onPressed: savingServer ? null : onResetServer,
                              child: Text(strings.text('Reset to default')),
                            ),
                            CupertinoButton.filled(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              onPressed: savingServer ? null : onSaveServer,
                              child: savingServer
                                  ? const CupertinoActivityIndicator()
                                  : Text(strings.text('Apply server')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CsacCard(
                  child: Column(
                    children: [
                      _AcopActionTile(
                        icon: CupertinoIcons.chevron_left_slash_chevron_right,
                        title: strings.text('JavaScript guide'),
                        subtitle: strings.text('Open Bot script documentation'),
                        onTap: () => openAcopScriptGuide(context),
                      ),
                      const CsacDivider(height: 1),
                      _AcopSwitchTile(
                        value: state.preferences.showAcopBlockGeneratedCode,
                        onChanged: state.updateShowAcopBlockGeneratedCode,
                        icon: CupertinoIcons.rectangle_stack,
                        title: strings.text('Show generated block code'),
                        subtitle: strings.text(
                          'Display generated JavaScript beside the block editor',
                        ),
                      ),
                      const CsacDivider(height: 1),
                      _AcopActionTile(
                        icon: CupertinoIcons.chat_bubble_2,
                        title: strings.text('Switch to CsAC chat'),
                        subtitle: strings.text(
                          'Return to the normal chat client',
                        ),
                        onTap: onSwitchToChat,
                      ),
                      const CsacDivider(height: 1),
                      _AcopActionTile(
                        icon: CupertinoIcons.square_arrow_right,
                        title: strings.text('Logout'),
                        subtitle: strings.text('Clear ACOP session'),
                        destructive: true,
                        onTap: onLogout,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AcopBotTile extends StatelessWidget {
  const _AcopBotTile({
    required this.avatarUrl,
    required this.bot,
    required this.onTap,
    required this.onEdit,
    required this.onUploadAvatar,
    required this.onResetToken,
    required this.onDelete,
  });

  final String avatarUrl;
  final AcopBot bot;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onUploadAvatar;
  final VoidCallback onResetToken;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return _AcopSwipeTile(
      onTap: onTap,
      leading: _AcopBotAvatar(
        online: bot.isOnline,
        url: avatarUrl,
        name: bot.botName,
      ),
      title: bot.botName.isEmpty ? 'Bot #${bot.botId}' : bot.botName,
      subtitle: [
        'UID ${bot.uid}',
        strings.text(bot.isOnline ? 'Online' : 'Offline'),
        if (bot.botDesc.isNotEmpty) bot.botDesc,
      ].join(' | '),
      actions: [
        CupertinoContextMenuAction(
          onPressed: () {
            Navigator.of(context).pop();
            onEdit();
          },
          child: Text(strings.text('Edit')),
        ),
        CupertinoContextMenuAction(
          onPressed: () {
            Navigator.of(context).pop();
            onUploadAvatar();
          },
          child: Text(strings.text('Upload avatar')),
        ),
        CupertinoContextMenuAction(
          onPressed: () {
            Navigator.of(context).pop();
            onResetToken();
          },
          child: Text(strings.text('Reset token')),
        ),
        CupertinoContextMenuAction(
          isDestructiveAction: true,
          onPressed: () {
            Navigator.of(context).pop();
            onDelete();
          },
          child: Text(strings.text('Delete')),
        ),
      ],
    );
  }
}

class _AcopAdminBotTile extends StatelessWidget {
  const _AcopAdminBotTile({
    required this.bot,
    required this.avatarUrl,
    required this.onHandleRequest,
  });

  final AcopBot bot;
  final String avatarUrl;
  final Future<void> Function(AcopPermissionRequest request, String action)
  onHandleRequest;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final requests = bot.permissionRequests;
    final pending = requests.where((request) => request.status == 0).toList();
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AcopBotAvatar(
                online: bot.isOnline,
                url: avatarUrl,
                name: bot.botName,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bot.botName.isEmpty ? 'Bot #${bot.botId}' : bot.botName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        'UID ${bot.uid}',
                        if (bot.devName.isNotEmpty) bot.devName,
                        if (bot.email.isNotEmpty) bot.email,
                        'notify:${bot.canNotify == 1 ? 'on' : 'off'}',
                        'http:${bot.canHttp == 1 ? 'on' : 'off'}',
                      ].join(' | '),
                      style: TextStyle(
                        color: CsacColors.of(context).secondaryLabel,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (pending.isNotEmpty)
                _AcopPill(
                  label: strings.format('{count} pending', {
                    'count': pending.length,
                  }),
                ),
            ],
          ),
          if (requests.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final request in requests.take(3)) ...[
              if (request != requests.first) const SizedBox(height: 8),
              _AcopAdminPermissionRow(
                request: request,
                onApprove: request.status == 0
                    ? () => onHandleRequest(request, 'approve')
                    : null,
                onReject: request.status == 0
                    ? () => onHandleRequest(request, 'reject')
                    : null,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AcopAdminPermissionRow extends StatelessWidget {
  const _AcopAdminPermissionRow({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final AcopPermissionRequest request;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _AcopPill(label: '#${request.requestId}'),
              _AcopPill(
                label: _acopPermissionTypeLabel(context, request.permType),
              ),
              _AcopPill(
                label: _acopPermissionStatusLabel(context, request.status),
              ),
            ],
          ),
          if (request.reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(request.reason),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  request.createdAt.isEmpty
                      ? ''
                      : strings.format('Requested at {time}', {
                          'time': request.createdAt,
                        }),
                  style: TextStyle(fontSize: 12, color: colors.secondaryLabel),
                ),
              ),
              if (onReject != null) ...[
                CupertinoButton(
                  minimumSize: const Size(30, 30),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  color: colors.fill,
                  onPressed: onReject,
                  child: Text(strings.text('Reject')),
                ),
                const SizedBox(width: 8),
              ],
              if (onApprove != null)
                CupertinoButton.filled(
                  minimumSize: const Size(30, 30),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  onPressed: onApprove,
                  child: Text(strings.text('Approve')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AcopBotSummary extends StatelessWidget {
  const _AcopBotSummary({
    required this.bot,
    required this.avatarUrl,
    required this.uploadingAvatar,
    required this.onUploadAvatar,
    required this.onClearAvatar,
  });

  final AcopBot bot;
  final String avatarUrl;
  final bool uploadingAvatar;
  final Future<void> Function() onUploadAvatar;
  final Future<void> Function()? onClearAvatar;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final title = bot.botName.isEmpty ? 'Bot #${bot.botId}' : bot.botName;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final info = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.label,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  'Bot ID ${bot.botId}',
                  'UID ${bot.uid}',
                  strings.text(bot.isOnline ? 'Online' : 'Offline'),
                  if (bot.canNotify == 1) 'notify',
                  if (bot.canHttp == 1) 'http',
                ].join(' | '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.secondaryLabel, fontSize: 13),
              ),
              if (bot.botDesc.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  bot.botDesc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.secondaryLabel, fontSize: 13),
                ),
              ],
            ],
          ),
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: compact ? WrapAlignment.start : WrapAlignment.end,
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: colors.fill,
              onPressed: uploadingAvatar ? null : onUploadAvatar,
              child: uploadingAvatar
                  ? const CupertinoActivityIndicator()
                  : Text(strings.text('Upload avatar')),
            ),
            if (onClearAvatar != null)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: colors.fill,
                onPressed: uploadingAvatar ? null : onClearAvatar,
                child: Text(strings.text('Clear avatar')),
              ),
          ],
        );
        final top = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _AcopBotAvatar(
              online: bot.isOnline,
              url: avatarUrl,
              name: title,
              size: 58,
            ),
            const SizedBox(width: 12),
            info,
            if (!compact) ...[const SizedBox(width: 12), actions],
          ],
        );
        if (!compact) return top;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [top, const SizedBox(height: 10), actions],
        );
      },
    );
  }
}

class AcopBotDetailScreen extends StatefulWidget {
  const AcopBotDetailScreen({
    super.key,
    required this.state,
    required this.bot,
  });

  final CsacAppState state;
  final AcopBot bot;

  @override
  State<AcopBotDetailScreen> createState() => _AcopBotDetailScreenState();
}

class _AcopBotDetailScreenState extends State<AcopBotDetailScreen> {
  late AcopBot bot = widget.bot;
  _AcopBotDetailSection section = _AcopBotDetailSection.scripts;
  List<AcopScript> scripts = const <AcopScript>[];
  List<AcopLogEntry> logs = const <AcopLogEntry>[];
  List<AcopPermissionRequest> permissions = const <AcopPermissionRequest>[];
  bool loadingScripts = false;
  bool loadingLogs = false;
  bool loadingPermissions = false;
  bool uploadingAvatar = false;
  String logLevel = '';
  int logLimit = 50;
  String? scriptsError;
  String? logsError;
  String? permissionsError;

  @override
  void initState() {
    super.initState();
    unawaited(refreshAll());
  }

  void showToast(String message) {
    CsacToastMessenger.maybeOf(
      context,
    )?.showToast(CsacToast(content: Text(message)));
  }

  Future<void> refreshAll() async {
    await Future.wait([refreshScripts(), refreshLogs(), refreshPermissions()]);
    try {
      final loaded = await widget.state.acopClient.getBotInfo(bot.botId);
      if (mounted) setState(() => bot = loaded);
    } catch (_) {}
  }

  Future<void> refreshScripts() async {
    setState(() {
      loadingScripts = true;
      scriptsError = null;
    });
    try {
      final loaded = await widget.state.acopClient.listScripts(bot.botId);
      if (mounted) setState(() => scripts = loaded);
    } catch (err) {
      if (mounted) setState(() => scriptsError = err.toString());
    } finally {
      if (mounted) setState(() => loadingScripts = false);
    }
  }

  Future<void> refreshLogs() async {
    setState(() {
      loadingLogs = true;
      logsError = null;
    });
    try {
      final loaded = await widget.state.acopClient.listLogs(
        botId: bot.botId,
        level: logLevel,
        limit: logLimit,
      );
      if (mounted) setState(() => logs = loaded);
    } catch (err) {
      if (mounted) setState(() => logsError = err.toString());
    } finally {
      if (mounted) setState(() => loadingLogs = false);
    }
  }

  Future<void> refreshPermissions() async {
    setState(() {
      loadingPermissions = true;
      permissionsError = null;
    });
    try {
      final loaded = await widget.state.acopClient.listPermissionRequests(
        bot.botId,
      );
      if (mounted) setState(() => permissions = loaded);
    } catch (err) {
      if (mounted) setState(() => permissionsError = err.toString());
    } finally {
      if (mounted) setState(() => loadingPermissions = false);
    }
  }

  Future<void> createScript() async {
    final draft = await _showAcopScriptDialog(
      context,
      showGeneratedCode: widget.state.preferences.showAcopBlockGeneratedCode,
    );
    if (draft == null || !mounted) return;
    try {
      await widget.state.acopClient.createScript(
        botId: bot.botId,
        scriptName: draft.name,
        scriptContent: draft.content,
      );
      await refreshScripts();
      if (!mounted) return;
      showToast(context.strings.text('Script created.'));
    } catch (err) {
      showToast(err.toString());
    }
  }

  Future<void> editScript(AcopScript script) async {
    var loaded = script;
    if (loaded.scriptContent.isEmpty) {
      try {
        loaded = await widget.state.acopClient.getScript(script.scriptId);
      } catch (_) {}
    }
    if (!mounted) return;
    final draft = await _showAcopScriptDialog(
      context,
      script: loaded,
      showGeneratedCode: widget.state.preferences.showAcopBlockGeneratedCode,
    );
    if (draft == null || !mounted) return;
    try {
      await widget.state.acopClient.updateScript(
        scriptId: loaded.scriptId,
        scriptName: draft.name,
        scriptContent: draft.content,
      );
      await refreshScripts();
      if (!mounted) return;
      showToast(context.strings.text('Saved.'));
    } catch (err) {
      showToast(err.toString());
    }
  }

  Future<void> deleteScript(AcopScript script) async {
    final confirmed = await _showAcopConfirmDialog(
      context,
      title: context.strings.text('Delete script?'),
      message: context.strings.format('Delete {name} permanently?', {
        'name': script.scriptName,
      }),
      confirmLabel: context.strings.text('Delete'),
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.state.acopClient.deleteScript(script.scriptId);
      await refreshScripts();
      if (!mounted) return;
      showToast(context.strings.text('Deleted.'));
    } catch (err) {
      showToast(err.toString());
    }
  }

  Future<void> toggleScript(AcopScript script, bool enabled) async {
    try {
      await widget.state.acopClient.toggleScript(
        scriptId: script.scriptId,
        enabled: enabled,
      );
      await refreshScripts();
    } catch (err) {
      showToast(err.toString());
    }
  }

  Future<void> testScript(AcopScript script) async {
    var loaded = script;
    if (loaded.scriptContent.isEmpty) {
      try {
        loaded = await widget.state.acopClient.getScript(script.scriptId);
      } catch (_) {}
    }
    if (!mounted) return;
    final draft = await _showAcopTestEventDialog(context);
    if (draft == null || !mounted) return;
    try {
      final result = await widget.state.acopClient.testScript(
        scriptId: loaded.scriptId,
        eventType: draft.eventType,
        eventData: draft.eventData,
        scriptContent: loaded.scriptContent,
      );
      if (!mounted) return;
      await _showAcopJsonDialog(context, result);
    } catch (err) {
      showToast(err.toString());
    }
  }

  Future<void> requestPermission() async {
    final draft = await _showAcopPermissionDialog(context);
    if (draft == null || !mounted) return;
    try {
      await widget.state.acopClient.requestPermission(
        botId: bot.botId,
        permType: draft.type,
        reason: draft.reason,
      );
      await refreshPermissions();
      if (!mounted) return;
      showToast(context.strings.text('Permission requested.'));
    } catch (err) {
      showToast(err.toString());
    }
  }

  Future<void> uploadAvatar() async {
    if (uploadingAvatar) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 5 * 1024 * 1024) {
      showToast(context.strings.text('Avatar cannot exceed 5MB.'));
      return;
    }
    setState(() => uploadingAvatar = true);
    try {
      await widget.state.acopClient.uploadBotAvatar(
        botId: bot.botId,
        bytes: bytes,
        filename: picked.name,
      );
      final loaded = await widget.state.acopClient.getBotInfo(bot.botId);
      if (!mounted) return;
      setState(() => bot = loaded);
      showToast(context.strings.text('Avatar uploaded.'));
    } catch (err) {
      showToast(err.toString());
    } finally {
      if (mounted) setState(() => uploadingAvatar = false);
    }
  }

  Future<void> clearAvatar() async {
    if (uploadingAvatar) return;
    try {
      await widget.state.acopClient.updateBot(botId: bot.botId, botAvatar: '');
      final loaded = await widget.state.acopClient.getBotInfo(bot.botId);
      if (!mounted) return;
      setState(() => bot = loaded);
      showToast(context.strings.text('Avatar cleared.'));
    } catch (err) {
      showToast(err.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final title = bot.botName.isEmpty ? 'Bot #${bot.botId}' : bot.botName;
    final page = switch (section) {
      _AcopBotDetailSection.scripts => _AcopScriptsTab(
        scripts: scripts,
        loading: loadingScripts,
        error: scriptsError,
        onRefresh: refreshScripts,
        onCreate: createScript,
        onEdit: editScript,
        onDelete: deleteScript,
        onToggle: toggleScript,
        onTest: testScript,
      ),
      _AcopBotDetailSection.logs => _AcopLogsTab(
        logs: logs,
        loading: loadingLogs,
        error: logsError,
        level: logLevel,
        limit: logLimit,
        onLevelChanged: (value) {
          setState(() => logLevel = value);
          unawaited(refreshLogs());
        },
        onLimitChanged: (value) {
          setState(() => logLimit = value);
          unawaited(refreshLogs());
        },
        onRefresh: refreshLogs,
      ),
      _AcopBotDetailSection.permissions => _AcopPermissionsTab(
        permissions: permissions,
        loading: loadingPermissions,
        error: permissionsError,
        onRefresh: refreshPermissions,
        onRequest: requestPermission,
      ),
    };
    return CsacPageScaffold(
      backgroundColor: colors.systemBackground,
      appBar: CsacNavigationBar(
        title: Text(title),
        actions: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: refreshAll,
            child: const Icon(CupertinoIcons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: colors.cardBackground,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                children: [
                  _AcopBotSummary(
                    bot: bot,
                    avatarUrl: widget.state.acopClient.resolveAssetUrl(
                      bot.botAvatar,
                    ),
                    uploadingAvatar: uploadingAvatar,
                    onUploadAvatar: uploadAvatar,
                    onClearAvatar: bot.botAvatar.trim().isEmpty
                        ? null
                        : clearAvatar,
                  ),
                  const SizedBox(height: 12),
                  CupertinoSlidingSegmentedControl<_AcopBotDetailSection>(
                    groupValue: section,
                    children: {
                      _AcopBotDetailSection.scripts: Text(
                        strings.text('Scripts'),
                      ),
                      _AcopBotDetailSection.logs: Text(strings.text('Logs')),
                      _AcopBotDetailSection.permissions: Text(
                        strings.text('Permissions'),
                      ),
                    },
                    onValueChanged: (value) {
                      if (value != null) setState(() => section = value);
                    },
                  ),
                ],
              ),
            ),
            Expanded(child: page),
          ],
        ),
      ),
    );
  }
}

class _AcopScriptsTab extends StatelessWidget {
  const _AcopScriptsTab({
    required this.scripts,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onTest,
  });

  final List<AcopScript> scripts;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onCreate;
  final Future<void> Function(AcopScript script) onEdit;
  final Future<void> Function(AcopScript script) onDelete;
  final Future<void> Function(AcopScript script, bool enabled) onToggle;
  final Future<void> Function(AcopScript script) onTest;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return _AcopRefreshList(
      onRefresh: onRefresh,
      children: [
        _AcopHeaderRow(
          title: strings.text('Scripts'),
          subtitle: strings.text('Create, edit, toggle and test bot scripts.'),
          action: CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            onPressed: onCreate,
            child: Text(strings.text('Create script')),
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Center(child: CupertinoActivityIndicator())
        else if (error != null)
          _AcopErrorPanel(message: error!, onRetry: onRefresh)
        else if (scripts.isEmpty)
          _AcopEmptyPanel(message: strings.text('No scripts yet.'))
        else
          CsacCard(
            child: Column(
              children: [
                for (var i = 0; i < scripts.length; i++) ...[
                  if (i > 0) const CsacDivider(height: 1),
                  _AcopScriptTile(
                    script: scripts[i],
                    onEdit: () => onEdit(scripts[i]),
                    onDelete: () => onDelete(scripts[i]),
                    onTest: () => onTest(scripts[i]),
                    onToggle: (value) => onToggle(scripts[i], value),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _AcopLogsTab extends StatelessWidget {
  const _AcopLogsTab({
    required this.logs,
    required this.loading,
    required this.error,
    required this.level,
    required this.limit,
    required this.onLevelChanged,
    required this.onLimitChanged,
    required this.onRefresh,
  });

  final List<AcopLogEntry> logs;
  final bool loading;
  final String? error;
  final String level;
  final int limit;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<int> onLimitChanged;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return _AcopRefreshList(
      onRefresh: onRefresh,
      children: [
        _AcopHeaderRow(
          title: strings.text('Logs'),
          subtitle: strings.text('Runtime logs reported by the bot.'),
        ),
        const SizedBox(height: 10),
        CupertinoSlidingSegmentedControl<String>(
          groupValue: level,
          children: {
            '': Text(strings.text('All')),
            'log': Text(strings.text('Log')),
            'warn': Text(strings.text('Warn')),
            'error': Text(strings.text('Error')),
          },
          onValueChanged: (value) {
            if (value != null) onLevelChanged(value);
          },
        ),
        const SizedBox(height: 12),
        if (loading)
          const Center(child: CupertinoActivityIndicator())
        else if (error != null)
          _AcopErrorPanel(message: error!, onRetry: onRefresh)
        else if (logs.isEmpty)
          _AcopEmptyPanel(message: strings.text('No logs yet.'))
        else
          CsacCard(
            child: Column(
              children: [
                for (var i = 0; i < logs.length; i++) ...[
                  if (i > 0) const CsacDivider(height: 1),
                  _AcopLogTile(entry: logs[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _AcopPermissionsTab extends StatelessWidget {
  const _AcopPermissionsTab({
    required this.permissions,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onRequest,
  });

  final List<AcopPermissionRequest> permissions;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRequest;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return _AcopRefreshList(
      onRefresh: onRefresh,
      children: [
        _AcopHeaderRow(
          title: strings.text('Permissions'),
          subtitle: strings.text('Request notify/http permissions.'),
          action: CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            onPressed: onRequest,
            child: Text(strings.text('Request permission')),
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Center(child: CupertinoActivityIndicator())
        else if (error != null)
          _AcopErrorPanel(message: error!, onRetry: onRefresh)
        else if (permissions.isEmpty)
          _AcopEmptyPanel(message: strings.text('No permission requests.'))
        else
          CsacCard(
            child: Column(
              children: [
                for (var i = 0; i < permissions.length; i++) ...[
                  if (i > 0) const CsacDivider(height: 1),
                  _AcopPermissionTile(request: permissions[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _AcopScriptTile extends StatelessWidget {
  const _AcopScriptTile({
    required this.script,
    required this.onEdit,
    required this.onDelete,
    required this.onTest,
    required this.onToggle,
  });

  final AcopScript script;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTest;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    Future<void> showActions() async {
      final action = await showCsacActionSheet<String>(
        context: context,
        style: CsacActionSheetStyle.compactBlur,
        actions: [
          CsacActionSheetAction(
            value: 'edit',
            title: strings.text('Edit'),
            icon: CupertinoIcons.pencil,
          ),
          CsacActionSheetAction(
            value: 'test',
            title: strings.text('Test'),
            icon: CupertinoIcons.play_arrow,
          ),
          CsacActionSheetAction(
            value: 'delete',
            title: strings.text('Delete'),
            icon: CupertinoIcons.delete,
            destructive: true,
          ),
        ],
      );
      if (!context.mounted) return;
      switch (action) {
        case 'edit':
          onEdit();
          break;
        case 'test':
          onTest();
          break;
        case 'delete':
          onDelete();
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.doc_text,
            color: CsacColors.of(context).primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  script.scriptName.isEmpty
                      ? 'Script #${script.scriptId}'
                      : script.scriptName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    'ID ${script.scriptId}',
                    if (script.version > 0) 'v${script.version}',
                    if (script.updatedAt > 0)
                      context.strings.format('Updated {time}', {
                        'time': _acopTimestampLabel(script.updatedAt),
                      }),
                  ].join(' | '),
                  style: TextStyle(
                    fontSize: 13,
                    color: CsacColors.of(context).secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          CupertinoSwitch(value: script.isEnabled, onChanged: onToggle),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: showActions,
            child: const Icon(CupertinoIcons.ellipsis_circle),
          ),
        ],
      ),
    );
  }
}

class _AcopLogTile extends StatelessWidget {
  const _AcopLogTile({required this.entry});

  final AcopLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AcopPill(label: entry.level),
              const SizedBox(width: 8),
              if (entry.scriptId > 0) ...[
                _AcopPill(label: 'Script ${entry.scriptId}'),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  entry.createdAt,
                  style: TextStyle(fontSize: 12, color: colors.secondaryLabel),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(entry.message.isEmpty ? jsonEncode(entry.raw) : entry.message),
        ],
      ),
    );
  }
}

class _AcopPermissionTile extends StatelessWidget {
  const _AcopPermissionTile({required this.request});

  final AcopPermissionRequest request;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _AcopPill(
                label: _acopPermissionTypeLabel(context, request.permType),
              ),
              const SizedBox(width: 8),
              _AcopPill(
                label: _acopPermissionStatusLabel(context, request.status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(request.reason),
          if (request.createdAt.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              context.strings.format('Requested at {time}', {
                'time': request.createdAt,
              }),
              style: TextStyle(
                color: CsacColors.of(context).secondaryLabel,
                fontSize: 12,
              ),
            ),
          ],
          if (request.adminReply.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              request.adminReply,
              style: TextStyle(color: CsacColors.of(context).secondaryLabel),
            ),
          ],
        ],
      ),
    );
  }
}

class _AcopRefreshList extends StatelessWidget {
  const _AcopRefreshList({required this.onRefresh, required this.children});

  final Future<void> Function() onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: onRefresh),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AcopHeaderRow extends StatelessWidget {
  const _AcopHeaderRow({
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: colors.label,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: colors.secondaryLabel)),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520 || action == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              text,
              if (action != null) ...[
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: action!),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: text),
            const SizedBox(width: 12),
            action!,
          ],
        );
      },
    );
  }
}

class _AcopErrorPanel extends StatelessWidget {
  const _AcopErrorPanel({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return CsacCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(color: CsacColors.of(context).destructive),
            ),
            const SizedBox(height: 10),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: CsacColors.of(context).fill,
              onPressed: onRetry,
              child: Text(strings.text('Retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcopEmptyPanel extends StatelessWidget {
  const _AcopEmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return CsacCard(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Center(
          child: Text(
            message,
            style: TextStyle(color: CsacColors.of(context).secondaryLabel),
          ),
        ),
      ),
    );
  }
}

class _AcopSwipeTile extends StatelessWidget {
  const _AcopSwipeTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.actions = const <Widget>[],
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final child = CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onPressed: onTap,
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.label,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: colors.secondaryLabel),
                ),
              ],
            ),
          ),
          if (actions.isNotEmpty)
            CupertinoContextMenu(
              actions: actions,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(CupertinoIcons.ellipsis_circle),
              ),
            ),
        ],
      ),
    );
    return child;
  }
}

class _AcopBotAvatar extends StatelessWidget {
  const _AcopBotAvatar({
    required this.online,
    this.url = '',
    this.name = '',
    this.size = 42,
  });

  final bool online;
  final String url;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.32),
          child: Container(
            width: size,
            height: size,
            color: online
                ? colors.primaryColor.withValues(alpha: 0.14)
                : colors.fill,
            alignment: Alignment.center,
            child: url.trim().isEmpty
                ? Icon(
                    CupertinoIcons.cube_box,
                    color: online ? colors.primaryColor : colors.secondaryLabel,
                    size: size * 0.52,
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    errorBuilder: (_, _, _) => Icon(
                      CupertinoIcons.cube_box,
                      color: online
                          ? colors.primaryColor
                          : colors.secondaryLabel,
                      size: size * 0.52,
                    ),
                  ),
          ),
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: size * 0.26,
            height: size * 0.26,
            decoration: BoxDecoration(
              color: online
                  ? CupertinoColors.activeGreen
                  : colors.tertiaryLabel,
              shape: BoxShape.circle,
              border: Border.all(color: colors.cardBackground, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _BotBadge extends StatelessWidget {
  const _BotBadge({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: colors.primaryColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.strings.text('Bot'),
        style: TextStyle(
          color: colors.primaryColor,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AcopInfoTile extends StatelessWidget {
  const _AcopInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return _AcopActionTile(
      icon: icon,
      title: label,
      subtitle: value,
      onTap: copyable
          ? () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) {
                CsacToastMessenger.maybeOf(context)?.showToast(
                  CsacToast(content: Text(context.strings.text('Copied.'))),
                );
              }
            }
          : null,
    );
  }
}

class _AcopActionTile extends StatelessWidget {
  const _AcopActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final tint = destructive ? colors.destructive : colors.primaryColor;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon, color: tint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: destructive ? colors.destructive : colors.label,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.secondaryLabel,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AcopSwitchTile extends StatelessWidget {
  const _AcopSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onPressed: onChanged == null ? null : () => onChanged!(!value),
      child: Row(
        children: [
          Icon(icon, color: colors.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.label,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.secondaryLabel,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _AcopPill extends StatelessWidget {
  const _AcopPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _AcopInlineMessage extends StatelessWidget {
  const _AcopInlineMessage(this.message, {this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        message,
        style: TextStyle(
          color: isError ? colors.destructive : colors.primaryColor,
        ),
      ),
    );
  }
}

class _AcopBotDraft {
  const _AcopBotDraft(this.name, this.description);

  final String name;
  final String description;
}

class _AcopScriptDraft {
  const _AcopScriptDraft(this.name, this.content);

  final String name;
  final String content;
}

class _AcopPermissionDraft {
  const _AcopPermissionDraft(this.type, this.reason);

  final String type;
  final String reason;
}

class _AcopAdminPermissionDraft {
  const _AcopAdminPermissionDraft(this.requestId, this.action, this.reply);

  final int requestId;
  final String action;
  final String reply;
}

class _AcopTestEventDraft {
  const _AcopTestEventDraft(this.eventType, this.eventData);

  final String eventType;
  final String eventData;
}

Future<_AcopBotDraft?> _showAcopBotDialog(
  BuildContext context, {
  AcopBot? bot,
}) {
  final name = TextEditingController(text: bot?.botName ?? '');
  final desc = TextEditingController(text: bot?.botDesc ?? '');
  return showCupertinoCsacDialog<_AcopBotDraft>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(
        context.strings.text(bot == null ? 'Create bot' : 'Edit bot'),
      ),
      content: Column(
        children: [
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: name,
            placeholder: context.strings.text('Bot name'),
          ),
          const SizedBox(height: 10),
          CupertinoTextField(
            controller: desc,
            placeholder: context.strings.text('Description'),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(context.strings.text('Cancel')),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            Navigator.of(
              dialogContext,
            ).pop(_AcopBotDraft(name.text.trim(), desc.text.trim()));
          },
          child: Text(context.strings.text('Save')),
        ),
      ],
    ),
  ).whenComplete(() {
    name.dispose();
    desc.dispose();
  });
}

Future<_AcopScriptDraft?> _showAcopScriptDialog(
  BuildContext context, {
  AcopScript? script,
  bool showGeneratedCode = true,
}) {
  return Navigator.of(context).push<_AcopScriptDraft>(
    CsacPageRoute(
      fullscreenDialog: true,
      builder: (_) => _AcopScriptEditorPage(
        script: script,
        showGeneratedCode: showGeneratedCode,
      ),
    ),
  );
}

class _AcopScriptEditorPage extends StatefulWidget {
  const _AcopScriptEditorPage({this.script, required this.showGeneratedCode});

  final AcopScript? script;
  final bool showGeneratedCode;

  @override
  State<_AcopScriptEditorPage> createState() => _AcopScriptEditorPageState();
}

class _AcopScriptEditorPageState extends State<_AcopScriptEditorPage> {
  late final TextEditingController _nameCtrl;
  late final _AcopScriptCodeController _codeCtrl;
  late final String _initialName;
  late final String _initialContent;
  final _codeFocus = FocusNode();
  final _editorScroll = ScrollController();
  String? _error;
  int _lineCount = 1;
  int _cursorLine = 1;
  int _cursorColumn = 1;
  bool _allowPop = false;

  static const _editorBackground = Color(0xFF0D1117);
  static const _editorPanel = Color(0xFF161B22);
  static const _editorBorder = Color(0xFF30363D);
  static const _editorLineNumber = Color(0xFF6E7681);
  static const _editorText = Color(0xFFC9D1D9);
  static const _editorMutedText = Color(0xFF8B949E);
  static const _editorAccent = Color(0xFF58A6FF);
  static const _editorSuccess = Color(0xFF238636);
  static const _codeFontFamily = 'monospace';
  static const _codeFontFallback = <String>['Menlo', 'Consolas', 'Courier New'];
  static const _codeFontSize = 14.0;
  static const _codeLineHeight = 1.45;

  @override
  void initState() {
    super.initState();
    final script = widget.script;
    _initialName = script?.scriptName ?? '';
    _initialContent = script?.scriptContent.trim().isNotEmpty == true
        ? script!.scriptContent
        : _defaultAcopScriptContent();
    _nameCtrl = TextEditingController(text: _initialName);
    _codeCtrl = _AcopScriptCodeController(text: _initialContent);
    _nameCtrl.addListener(_handleChanged);
    _codeCtrl.addListener(_handleChanged);
    _handleChanged();
  }

  bool get _hasUnsavedChanges =>
      _nameCtrl.text != _initialName || _codeCtrl.text != _initialContent;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _codeFocus.dispose();
    _editorScroll.dispose();
    super.dispose();
  }

  void _handleChanged() {
    final text = _codeCtrl.text;
    final selectionOffset = _codeCtrl.selection.baseOffset;
    final safeOffset = selectionOffset < 0
        ? 0
        : math.min(selectionOffset, text.length);
    final beforeCursor = text.substring(0, safeOffset);
    final lastLineBreak = beforeCursor.lastIndexOf('\n');
    setState(() {
      _lineCount = _countScriptLines(text);
      _cursorLine = '\n'.allMatches(beforeCursor).length + 1;
      _cursorColumn = safeOffset - lastLineBreak;
      _error = null;
    });
  }

  void _insertExample() {
    final sample = _defaultAcopScriptContent();
    _codeCtrl.value = TextEditingValue(
      text: sample,
      selection: TextSelection.collapsed(offset: sample.length),
    );
    _codeFocus.requestFocus();
  }

  Future<void> _openBlockEditor() async {
    final draft = await Navigator.of(context).push<_AcopBlockDraft>(
      CsacPageRoute<_AcopBlockDraft>(
        fullscreenDialog: true,
        builder: (_) => _AcopBlockEditorScreen(
          initialCode: _codeCtrl.text,
          showGeneratedCode: widget.showGeneratedCode,
        ),
      ),
    );
    if (draft == null || !mounted) return;
    _codeCtrl.value = TextEditingValue(
      text: draft.code,
      selection: TextSelection.collapsed(offset: draft.code.length),
    );
    _codeFocus.requestFocus();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = context.strings.text('Script name is required.'));
      return;
    }
    _allowPop = true;
    Navigator.of(context).pop(_AcopScriptDraft(name, _codeCtrl.text));
  }

  Future<void> _handleClose() async {
    if (!_hasUnsavedChanges) {
      _allowPop = true;
      Navigator.of(context).pop();
      return;
    }
    final action = await _showAcopUnsavedChangesDialog(context);
    if (!mounted) return;
    switch (action) {
      case _AcopUnsavedExitAction.save:
        _save();
        break;
      case _AcopUnsavedExitAction.discard:
        _allowPop = true;
        Navigator.of(context).pop();
        break;
      case _AcopUnsavedExitAction.cancel:
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final isNew = widget.script == null;
    return PopScope(
      canPop: _allowPop || !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_handleClose());
      },
      child: CsacPageScaffold(
        backgroundColor: _editorBackground,
        appBar: CsacNavigationBar(
          backgroundColor: _editorPanel,
          foregroundColor: CupertinoColors.white,
          title: Text(strings.text(isNew ? 'Create script' : 'Edit script')),
          actions: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              color: _editorSuccess,
              borderRadius: BorderRadius.circular(8),
              onPressed: _save,
              child: Text(
                strings.text('Save'),
                style: const TextStyle(color: CupertinoColors.white),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopPanel(context),
              Expanded(child: _buildEditor(context)),
              _AcopScriptEditorStatusBar(
                line: _cursorLine,
                column: _cursorColumn,
                lines: _lineCount,
                chars: _codeCtrl.text.length,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopPanel(BuildContext context) {
    final strings = context.strings;
    return Container(
      color: _editorPanel,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final nameField = CupertinoTextField(
            controller: _nameCtrl,
            placeholder: strings.text('Script name'),
            style: const TextStyle(color: _editorText, fontSize: 15),
            placeholderStyle: const TextStyle(color: _editorMutedText),
            cursorColor: _editorAccent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: _editorBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _editorBorder),
            ),
          );
          final toolbar = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CupertinoButton(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(8),
                onPressed: _insertExample,
                child: Text(
                  strings.text('Insert test bot example'),
                  style: const TextStyle(color: _editorText, fontSize: 13),
                ),
              ),
              CupertinoButton(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(8),
                onPressed: _codeFocus.requestFocus,
                child: Text(
                  strings.text('Focus editor'),
                  style: const TextStyle(color: _editorText, fontSize: 13),
                ),
              ),
              CupertinoButton(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(8),
                onPressed: () => openAcopScriptGuide(context),
                child: Text(
                  strings.text('JavaScript guide'),
                  style: const TextStyle(color: _editorText, fontSize: 13),
                ),
              ),
              CupertinoButton(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(8),
                onPressed: _openBlockEditor,
                child: Text(
                  strings.text('JavaScript block editor'),
                  style: const TextStyle(color: _editorText, fontSize: 13),
                ),
              ),
            ],
          );
          final content = compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [nameField, const SizedBox(height: 10), toolbar],
                )
              : Row(
                  children: [
                    Expanded(child: nameField),
                    const SizedBox(width: 12),
                    toolbar,
                  ],
                );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              content,
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFF7B72),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    final minLines = _lineCount < 24 ? 24 : _lineCount + 1;
    final lineNumbers = List<String>.generate(
      _lineCount,
      (index) => '${index + 1}',
    ).join('\n');
    const codeStyle = TextStyle(
      color: _editorText,
      fontFamily: _codeFontFamily,
      fontFamilyFallback: _codeFontFallback,
      fontSize: _codeFontSize,
      height: _codeLineHeight,
    );
    return Container(
      color: _editorBackground,
      padding: const EdgeInsets.all(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _editorBackground,
            border: Border.all(color: _editorBorder),
          ),
          child: CupertinoScrollbar(
            controller: _editorScroll,
            child: SingleChildScrollView(
              controller: _editorScroll,
              padding: EdgeInsets.zero,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    constraints: const BoxConstraints(minHeight: 520),
                    padding: const EdgeInsets.fromLTRB(0, 14, 10, 14),
                    color: _editorPanel,
                    alignment: Alignment.topRight,
                    child: Text(
                      lineNumbers,
                      textAlign: TextAlign.right,
                      style: codeStyle.copyWith(color: _editorLineNumber),
                    ),
                  ),
                  Container(width: 1, color: _editorBorder),
                  Expanded(
                    child: CupertinoTextField(
                      controller: _codeCtrl,
                      focusNode: _codeFocus,
                      autofocus: true,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      minLines: minLines,
                      maxLines: null,
                      style: codeStyle,
                      cursorColor: _editorAccent,
                      padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                      decoration: const BoxDecoration(color: _editorBackground),
                      placeholder:
                          "bot.on('private.message', async (ctx) => {\n  await ctx.reply('hello')\n})",
                      placeholderStyle: codeStyle.copyWith(
                        color: _editorMutedText,
                      ),
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

class _AcopScriptEditorStatusBar extends StatelessWidget {
  const _AcopScriptEditorStatusBar({
    required this.line,
    required this.column,
    required this.lines,
    required this.chars,
  });

  final int line;
  final int column;
  final int lines;
  final int chars;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFF0969DA),
      child: DefaultTextStyle(
        style: const TextStyle(color: CupertinoColors.white, fontSize: 12),
        child: Row(
          children: [
            const Icon(
              CupertinoIcons.chevron_left_slash_chevron_right,
              size: 14,
              color: CupertinoColors.white,
            ),
            const SizedBox(width: 6),
            const Text('JavaScript'),
            const Spacer(),
            Text('Ln $line, Col $column'),
            const SizedBox(width: 14),
            Text('$lines lines'),
            const SizedBox(width: 14),
            Text('$chars chars'),
          ],
        ),
      ),
    );
  }
}

class _AcopScriptCodeController extends TextEditingController {
  _AcopScriptCodeController({super.text});

  static final _tokenPattern = RegExp(
    r'''//[^\n]*|/\*[\s\S]*?\*/|'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|`(?:\\.|[^`\\])*`|\b(?:await|async|break|case|catch|class|const|continue|default|delete|else|false|finally|for|function|if|in|let|new|null|return|switch|throw|true|try|typeof|undefined|var|while)\b|\b(?:bot|ctx|csac|logger|console|JSON|Math|Date|RegExp)\b|\b\d+(?:\.\d+)?\b''',
    multiLine: true,
  );

  static const _keywords = <String>{
    'await',
    'async',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'delete',
    'else',
    'false',
    'finally',
    'for',
    'function',
    'if',
    'in',
    'let',
    'new',
    'null',
    'return',
    'switch',
    'throw',
    'true',
    'try',
    'typeof',
    'undefined',
    'var',
    'while',
  };

  static const _platformObjects = <String>{
    'bot',
    'ctx',
    'csac',
    'logger',
    'console',
    'JSON',
    'Math',
    'Date',
    'RegExp',
  };

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    final source = text;
    if (source.isEmpty) return TextSpan(style: base, text: '');
    final spans = <TextSpan>[];
    var index = 0;
    for (final match in _tokenPattern.allMatches(source)) {
      if (match.start > index) {
        spans.add(TextSpan(text: source.substring(index, match.start)));
      }
      final token = source.substring(match.start, match.end);
      spans.add(TextSpan(text: token, style: _styleForToken(token, base)));
      index = match.end;
    }
    if (index < source.length) {
      spans.add(TextSpan(text: source.substring(index)));
    }
    return TextSpan(style: base, children: spans);
  }

  TextStyle _styleForToken(String token, TextStyle base) {
    if (token.startsWith('//') || token.startsWith('/*')) {
      return base.copyWith(color: const Color(0xFF8B949E));
    }
    if (token.startsWith("'") ||
        token.startsWith('"') ||
        token.startsWith('`')) {
      return base.copyWith(color: const Color(0xFFA5D6FF));
    }
    if (_keywords.contains(token)) {
      return base.copyWith(color: const Color(0xFFFF7B72));
    }
    if (_platformObjects.contains(token)) {
      return base.copyWith(color: const Color(0xFFD2A8FF));
    }
    if (RegExp(r'^\d').hasMatch(token)) {
      return base.copyWith(color: const Color(0xFF79C0FF));
    }
    return base;
  }
}

int _countScriptLines(String text) {
  if (text.isEmpty) return 1;
  return '\n'.allMatches(text).length + 1;
}

String _defaultAcopScriptContent() {
  return "bot.on('private.message', async (ctx) => {\n"
      "  if (ctx.text.trim() === '测试bot') {\n"
      "    await ctx.reply('bot正在运行')\n"
      "  }\n"
      "})\n\n"
      "bot.on('group.message', async (ctx) => {\n"
      "  if (ctx.text.includes('测试bot')) {\n"
      "    await ctx.reply(`bot正在运行，收到来自 \${ctx.sender.nickname || ctx.sender.uid} 的消息`)\n"
      "  }\n"
      "})\n";
}

Future<_AcopPermissionDraft?> _showAcopPermissionDialog(BuildContext context) {
  final reason = TextEditingController();
  var type = 'notify';
  return showCupertinoCsacDialog<_AcopPermissionDraft>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => CupertinoAlertDialog(
        title: Text(context.strings.text('Request permission')),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoSlidingSegmentedControl<String>(
              groupValue: type,
              children: {
                'notify': Text(context.strings.text('Notify')),
                'http': Text(context.strings.text('HTTP')),
              },
              onValueChanged: (value) {
                if (value != null) setState(() => type = value);
              },
            ),
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: reason,
              placeholder: context.strings.text('Reason'),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.strings.text('Cancel')),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              if (reason.text.trim().isEmpty) return;
              Navigator.of(
                dialogContext,
              ).pop(_AcopPermissionDraft(type, reason.text.trim()));
            },
            child: Text(context.strings.text('Submit')),
          ),
        ],
      ),
    ),
  ).whenComplete(reason.dispose);
}

Future<_AcopAdminPermissionDraft?> _showAcopAdminPermissionDialog(
  BuildContext context,
) {
  final requestId = TextEditingController();
  final reply = TextEditingController();
  var action = 'approve';
  return showCupertinoCsacDialog<_AcopAdminPermissionDraft>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => CupertinoAlertDialog(
        title: Text(context.strings.text('Handle permission')),
        content: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: requestId,
              keyboardType: TextInputType.number,
              placeholder: context.strings.text('Request ID'),
            ),
            const SizedBox(height: 10),
            CupertinoSlidingSegmentedControl<String>(
              groupValue: action,
              children: {
                'approve': Text(context.strings.text('Approve')),
                'reject': Text(context.strings.text('Reject')),
              },
              onValueChanged: (value) {
                if (value != null) setState(() => action = value);
              },
            ),
            const SizedBox(height: 10),
            CupertinoTextField(
              controller: reply,
              placeholder: context.strings.text('Reply'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.strings.text('Cancel')),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              final id = int.tryParse(requestId.text.trim());
              if (id == null || id <= 0) return;
              Navigator.of(
                dialogContext,
              ).pop(_AcopAdminPermissionDraft(id, action, reply.text.trim()));
            },
            child: Text(context.strings.text('Submit')),
          ),
        ],
      ),
    ),
  ).whenComplete(() {
    requestId.dispose();
    reply.dispose();
  });
}

Future<_AcopTestEventDraft?> _showAcopTestEventDialog(BuildContext context) {
  final eventType = TextEditingController(text: 'group_message');
  final eventData = TextEditingController(text: '{"content":"hello"}');
  return showCupertinoCsacDialog<_AcopTestEventDraft>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(context.strings.text('Test script')),
      content: Column(
        children: [
          const SizedBox(height: 12),
          CupertinoTextField(controller: eventType, placeholder: 'event_type'),
          const SizedBox(height: 10),
          CupertinoTextField(
            controller: eventData,
            placeholder: '{}',
            minLines: 5,
            maxLines: 8,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(context.strings.text('Cancel')),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(
            dialogContext,
          ).pop(_AcopTestEventDraft(eventType.text.trim(), eventData.text)),
          child: Text(context.strings.text('Test')),
        ),
      ],
    ),
  ).whenComplete(() {
    eventType.dispose();
    eventData.dispose();
  });
}

Future<bool?> _showAcopConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) {
  return showCupertinoCsacDialog<bool>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(context.strings.text('Cancel')),
        ),
        CupertinoDialogAction(
          isDestructiveAction: destructive,
          isDefaultAction: !destructive,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

Future<void> _showAcopTokenDialog(BuildContext context, String token) {
  return showCupertinoCsacDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(context.strings.text('Bot token')),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SelectableText(token),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: token));
            if (dialogContext.mounted) Navigator.of(dialogContext).pop();
          },
          child: Text(context.strings.text('Copy')),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(context.strings.text('Done')),
        ),
      ],
    ),
  );
}

Future<void> _showAcopJsonDialog(
  BuildContext context,
  Map<String, dynamic> value,
) {
  const encoder = JsonEncoder.withIndent('  ');
  return showCupertinoCsacDialog<void>(
    context: context,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(context.strings.text('Test result')),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SelectableText(
          encoder.convert(value),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(context.strings.text('Done')),
        ),
      ],
    ),
  );
}

bool _looksLikeEmail(String value) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
}

String _acopPermissionStatusLabel(BuildContext context, int status) {
  return switch (status) {
    1 => context.strings.text('Approved'),
    2 => context.strings.text('Rejected'),
    _ => context.strings.text('Pending'),
  };
}

String _acopPermissionTypeLabel(BuildContext context, String value) {
  return switch (value) {
    'notify' => context.strings.text('Notify'),
    'http' => context.strings.text('HTTP'),
    _ => value,
  };
}
