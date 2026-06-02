part of '../../main.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  Widget build(BuildContext context) {
    final user = state.user;
    final counts = state.notificationCounts;
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('Me'))),
      backgroundColor: colors.systemBackground,
      body: SafeArea(
        child: _AdaptivePageFrame(
          maxWidth: 680,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              if (state.sessionExpired)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemYellow.withValues(
                        alpha: 0.15,
                      ),
                      borderRadius: BorderRadius.circular(
                        _csacControlCornerRadius,
                      ),
                      border: Border.all(
                        color: CupertinoColors.systemYellow.withValues(
                          alpha: 0.35,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.text(
                              'Session expired. Log in again to sync latest data.',
                            ),
                            style: TextStyle(color: colors.label, fontSize: 14),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: Size.zero,
                          onPressed: () => confirmLogout(context, state),
                          child: Text(strings.text('Login')),
                        ),
                      ],
                    ),
                  ),
                ),
              _CsacPressable(
                onTap: user == null
                    ? null
                    : () => Navigator.of(context).push(
                        CsacPageRoute<void>(
                          builder: (_) => AccountSettingsScreen(state: state),
                        ),
                      ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
                  decoration: BoxDecoration(
                    color: colors.cardBackground,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: colors.separator.withValues(alpha: 0.25),
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withValues(
                          alpha: colors.isDark ? 0 : 0.05,
                        ),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _Avatar(
                        url: user?.avatar ?? '',
                        fallback: CupertinoIcons.person_fill,
                        radius: 27,
                        name: user?.nickname ?? '',
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.nickname ?? strings.text('Not logged in'),
                              style: TextStyle(
                                color: colors.label,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (user?.username.isNotEmpty == true)
                                  '@${user!.username}',
                                if (user != null) 'UID ${user.uid}',
                                if (user?.onlineStatus.isNotEmpty == true)
                                  user!.onlineStatus,
                                if (user != null &&
                                    user.platformLabel != 'none')
                                  user.platformLabel,
                              ].join(' | '),
                              style: TextStyle(
                                color: colors.secondaryLabel,
                                fontSize: 13,
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
              ),
              const SizedBox(height: 12),
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  _CupertinoListTile(
                    title: strings.text('Unread notices'),
                    leading: const Icon(CupertinoIcons.bell),
                    trailing: _ProfileNotificationBadge(count: counts.notices),
                  ),
                  _CupertinoListTile(
                    title: strings.text('Mentions and replies'),
                    leading: const Icon(CupertinoIcons.at),
                    trailing: _ProfileNotificationBadge(
                      count: counts.mentions + counts.replies,
                    ),
                  ),
                  _CupertinoListTile(
                    title: strings.text('Friend changes'),
                    leading: const Icon(CupertinoIcons.person_2),
                    trailing: _ProfileNotificationBadge(
                      count: counts.friendChanges,
                    ),
                  ),
                  _CupertinoListTile(
                    title: strings.text('Friend requests'),
                    leading: const Icon(CupertinoIcons.person_add),
                    trailing: _ProfileNotificationBadge(
                      count: counts.friendRequests,
                    ),
                  ),
                  _CupertinoListTile(
                    title: strings.text('Group reviews'),
                    leading: const Icon(CupertinoIcons.group),
                    trailing: _ProfileNotificationBadge(
                      count: counts.groupApplications,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  _CupertinoListTile(
                    title: strings.text('Refresh all'),
                    leading: const Icon(CupertinoIcons.arrow_2_circlepath),
                    onTap: state.refreshHome,
                  ),
                  _CupertinoListTile(
                    title: strings.text('Settings'),
                    leading: const Icon(CupertinoIcons.settings),
                    onTap: () => Navigator.of(context).push(
                      CsacPageRoute<void>(
                        builder: (_) => SettingsScreen(state: state),
                      ),
                    ),
                  ),
                  _CupertinoListTile(
                    title: strings.text('Logout'),
                    leading: const Icon(CupertinoIcons.square_arrow_left),
                    titleColor: colors.destructive,
                    onTap: () => confirmLogout(context, state),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileNotificationBadge extends StatelessWidget {
  const _ProfileNotificationBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }
    return Badge(label: Text('$count'));
  }
}

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final imagePicker = ImagePicker();
  bool updatingNickname = false;
  bool updatingAvatar = false;
  bool updatingPassword = false;
  bool updatingPatAction = false;
  bool deletingAccount = false;

  Future<void> editNickname() async {
    final current = widget.state.user?.nickname ?? '';
    final nickname = await showDialog<String>(
      context: context,
      builder: (context) => _NicknameDialog(initialNickname: current),
    );
    if (nickname == null || !mounted) {
      return;
    }
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) {
      showSnack(context.strings.text('Please enter a nickname.'));
      return;
    }
    if (trimmed == current.trim()) {
      return;
    }
    setState(() => updatingNickname = true);
    try {
      await widget.state.updateNickname(trimmed);
      if (!mounted) {
        return;
      }
      showSnack(context.strings.text('Nickname updated.'));
      setState(() {});
    } catch (err) {
      if (mounted) {
        showSnack(
          context.strings.format('Update failed: {error}', {'error': err}),
        );
      }
    } finally {
      if (mounted) {
        setState(() => updatingNickname = false);
      }
    }
  }

  Future<void> changeAvatar() async {
    if (updatingAvatar) {
      return;
    }
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
    setState(() => updatingAvatar = true);
    try {
      await widget.state.updateAvatar(bytes, picked.name);
      if (!mounted) {
        return;
      }
      showSnack(context.strings.text('Avatar updated.'));
      setState(() {});
    } catch (err) {
      if (mounted) {
        showSnack(
          context.strings.format('Update failed: {error}', {'error': err}),
        );
      }
    } finally {
      if (mounted) {
        setState(() => updatingAvatar = false);
      }
    }
  }

  Future<void> changePassword() async {
    final result = await showDialog<_PasswordChange>(
      context: context,
      builder: (context) => const _PasswordChangeDialog(),
    );
    if (result == null || !mounted) {
      return;
    }
    if (result.oldPassword.isEmpty ||
        result.newPassword.isEmpty ||
        result.confirmPassword.isEmpty) {
      showSnack(context.strings.text('Please fill all password fields.'));
      return;
    }
    if (result.newPassword.length < 6) {
      showSnack(
        context.strings.text('New password must be at least 6 characters.'),
      );
      return;
    }
    if (result.newPassword != result.confirmPassword) {
      showSnack(context.strings.text('Passwords do not match.'));
      return;
    }
    setState(() => updatingPassword = true);
    try {
      await widget.state.updatePassword(
        result.oldPassword,
        result.newPassword,
        result.confirmPassword,
      );
      if (!mounted) {
        return;
      }
      showSnack(context.strings.text('Password updated.'));
    } catch (err) {
      if (mounted) {
        showSnack(
          context.strings.format('Update failed: {error}', {'error': err}),
        );
      }
    } finally {
      if (mounted) {
        setState(() => updatingPassword = false);
      }
    }
  }

  Future<void> editPatAction() async {
    final current = widget.state.user?.patAction ?? defaultPatAction;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => _PatActionDialog(initialAction: current),
    );
    if (action == null || !mounted) {
      return;
    }
    final trimmed = action.trim();
    if (trimmed.isEmpty) {
      showSnack(context.strings.text('Please enter a pat action.'));
      return;
    }
    if (trimmed == current.trim()) {
      return;
    }
    setState(() => updatingPatAction = true);
    try {
      await widget.state.updatePatAction(trimmed);
      if (!mounted) {
        return;
      }
      showSnack(context.strings.text('Pat action updated.'));
      setState(() {});
    } catch (err) {
      if (mounted) {
        showSnack(
          context.strings.format('Update failed: {error}', {'error': err}),
        );
      }
    } finally {
      if (mounted) {
        setState(() => updatingPatAction = false);
      }
    }
  }

  Future<void> deleteAccount() async {
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _DeleteAccountDialog(),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => deletingAccount = true);
    try {
      await widget.state.deleteAccount();
      if (!mounted) {
        return;
      }
      navigator.popUntil((route) => route.isFirst);
      messenger.showSnackBar(
        SnackBar(content: Text(strings.text('Account deleted.'))),
      );
    } catch (err) {
      if (mounted) {
        showSnack(
          context.strings.format('Delete failed: {error}', {'error': err}),
        );
      }
    } finally {
      if (mounted) {
        setState(() => deletingAccount = false);
      }
    }
  }

  void showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget progressOrChevron(bool loading) {
    if (!loading) {
      return const Icon(CupertinoIcons.chevron_right, size: 14);
    }
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.state.user;
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('Account settings'))),
      backgroundColor: colors.systemBackground,
      body: SafeArea(
        child: _AdaptivePageFrame(
          maxWidth: 680,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: colors.separator.withValues(alpha: 0.25),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    _Avatar(
                      url: user?.avatar ?? '',
                      fallback: CupertinoIcons.person_fill,
                      radius: 30,
                      name: user?.nickname ?? '',
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.nickname ?? strings.text('Not logged in'),
                            style: TextStyle(
                              color: colors.label,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (user?.username.isNotEmpty == true)
                                '@${user!.username}',
                              if (user != null) 'UID ${user.uid}',
                            ].join(' | '),
                            style: TextStyle(
                              color: colors.secondaryLabel,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  _CupertinoListTile(
                    title: strings.text('Change nickname'),
                    subtitle: user?.nickname ?? '',
                    leading: const Icon(CupertinoIcons.person_crop_circle),
                    trailing: progressOrChevron(updatingNickname),
                    onTap: updatingNickname ? null : editNickname,
                  ),
                  _CupertinoListTile(
                    title: strings.text('Change avatar'),
                    subtitle: strings.text('Choose a new profile image'),
                    leading: const Icon(CupertinoIcons.camera),
                    trailing: progressOrChevron(updatingAvatar),
                    onTap: updatingAvatar ? null : changeAvatar,
                  ),
                  _CupertinoListTile(
                    title: strings.text('Pat action'),
                    subtitle: user?.patAction ?? defaultPatAction,
                    leading: const Icon(CupertinoIcons.hand_raised),
                    trailing: progressOrChevron(updatingPatAction),
                    onTap: updatingPatAction ? null : editPatAction,
                  ),
                  _CupertinoListTile(
                    title: strings.text('Change password'),
                    subtitle: strings.text('Update your login password'),
                    leading: const Icon(CupertinoIcons.lock_rotation),
                    trailing: progressOrChevron(updatingPassword),
                    onTap: updatingPassword ? null : changePassword,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                header: strings.text('Danger zone'),
                children: [
                  _CupertinoListTile(
                    title: strings.text('Delete account'),
                    subtitle: strings.text(
                      'Permanently delete this account and owned groups.',
                    ),
                    leading: Icon(
                      CupertinoIcons.delete,
                      color: colors.destructive,
                    ),
                    titleColor: colors.destructive,
                    trailing: deletingAccount
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: deletingAccount ? null : deleteAccount,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordChange {
  const _PasswordChange(
    this.oldPassword,
    this.newPassword,
    this.confirmPassword,
  );

  final String oldPassword;
  final String newPassword;
  final String confirmPassword;
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController()..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final canDelete = controller.text.trim() == 'DELETE';
    return AlertDialog(
      title: Text(strings.text('Delete account?')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            strings.text(
              'This will permanently delete your account, messages and owned groups. This cannot be undone.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: strings.text('Type DELETE to confirm'),
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
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: canDelete ? () => Navigator.of(context).pop(true) : null,
          child: Text(strings.text('Delete account')),
        ),
      ],
    );
  }
}

class _NicknameDialog extends StatefulWidget {
  const _NicknameDialog({required this.initialNickname});

  final String initialNickname;

  @override
  State<_NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<_NicknameDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialNickname);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    Navigator.of(context).pop(controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AlertDialog(
      title: Text(strings.text('Change nickname')),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 16,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: strings.text('New nickname'),
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.text('Cancel')),
        ),
        FilledButton(onPressed: submit, child: Text(strings.text('Save'))),
      ],
    );
  }
}

class _PatActionDialog extends StatefulWidget {
  const _PatActionDialog({required this.initialAction});

  final String initialAction;

  @override
  State<_PatActionDialog> createState() => _PatActionDialogState();
}

class _PatActionDialogState extends State<_PatActionDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialAction);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    Navigator.of(context).pop(controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AlertDialog(
      title: Text(strings.text('Pat action')),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 16,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: strings.text('Pat action'),
          helperText: strings.text('Used in double-tap avatar pats'),
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.text('Cancel')),
        ),
        FilledButton(onPressed: submit, child: Text(strings.text('Save'))),
      ],
    );
  }
}

class _PasswordChangeDialog extends StatefulWidget {
  const _PasswordChangeDialog();

  @override
  State<_PasswordChangeDialog> createState() => _PasswordChangeDialogState();
}

class _PasswordChangeDialogState extends State<_PasswordChangeDialog> {
  final oldPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmPassword = TextEditingController();

  @override
  void dispose() {
    oldPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  void submit() {
    Navigator.of(context).pop(
      _PasswordChange(oldPassword.text, newPassword.text, confirmPassword.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AlertDialog(
      title: Text(strings.text('Change password')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldPassword,
                obscureText: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: strings.text('Old password'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPassword,
                obscureText: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: strings.text('New password'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPassword,
                obscureText: true,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: strings.text('Confirm password'),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.text('Cancel')),
        ),
        FilledButton(onPressed: submit, child: Text(strings.text('Save'))),
      ],
    );
  }
}

class _ThemeColorOption {
  const _ThemeColorOption(this.label, this.color);

  final String label;
  final Color color;
}

class _CacheMetric {
  const _CacheMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;
}

class _ThemeColorDot extends StatelessWidget {
  const _ThemeColorDot({required this.color, this.selected = false});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 3 : 1,
        ),
      ),
      child: selected
          ? Icon(
              Icons.check,
              size: 16,
              color:
                  ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            )
          : null,
    );
  }
}

class _ThemeColorButton extends StatelessWidget {
  const _ThemeColorButton({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ThemeColorOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.strings.text(option.label),
      child: _CsacPressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: _ThemeColorDot(color: option.color, selected: selected),
        ),
      ),
    );
  }
}

class _FollowThemeColorButton extends StatelessWidget {
  const _FollowThemeColorButton({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: context.strings.text('Follow theme'),
      child: _CsacPressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.primaryContainer, colors.surfaceContainerHigh],
              ),
              border: Border.all(
                color: selected ? colors.primary : colors.outlineVariant,
                width: selected ? 3 : 1,
              ),
            ),
            child: selected
                ? Icon(Icons.check, size: 16, color: colors.onPrimaryContainer)
                : null,
          ),
        ),
      ),
    );
  }
}

class _ChatBubbleColorTrailing extends StatelessWidget {
  const _ChatBubbleColorTrailing({
    required this.colorValue,
    required this.fallback,
  });

  final int colorValue;
  final Color fallback;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ThemeColorDot(
          color: colorValue == defaultChatBubbleColorValue
              ? fallback
              : Color(colorValue),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.chevron_right),
      ],
    );
  }
}

class _ChatBubbleThemePreview extends StatelessWidget {
  const _ChatBubbleThemePreview({required this.preferences});

  final CsacPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.forum_outlined, color: colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                strings.text('Chat bubble theme'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _PreviewBubble(
          text: strings.text('Preview message'),
          mine: false,
          preferences: preferences,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: _PreviewBubble(
            text: strings.text('Preview message'),
            mine: true,
            preferences: preferences,
          ),
        ),
      ],
    );
  }
}

class _PreviewBubble extends StatelessWidget {
  const _PreviewBubble({
    required this.text,
    required this.mine,
    required this.preferences,
  });

  final String text;
  final bool mine;
  final CsacPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fallback = mine
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    final colorValue = mine
        ? preferences.ownChatBubbleColorValue
        : preferences.otherChatBubbleColorValue;
    final color =
        (colorValue == defaultChatBubbleColorValue
                ? fallback
                : Color(colorValue))
            .withValues(alpha: preferences.chatBubbleOpacity);
    final solidTextSource = Color.alphaBlend(
      color,
      theme.scaffoldBackgroundColor,
    );
    final textColor =
        ThemeData.estimateBrightnessForColor(solidTextSource) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: chatBubbleBorderRadius(
          preferences.chatBubbleCornerStyle,
          mine,
        ),
        border: Border.all(color: textColor.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(text, style: TextStyle(color: textColor)),
      ),
    );
  }
}

class _CacheMetricTile extends StatelessWidget {
  const _CacheMetricTile({required this.metric});

  final _CacheMetric metric;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 168,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(metric.icon, size: 20, color: colors.primary),
              const SizedBox(height: 10),
              Text(
                metric.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                metric.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                metric.detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _csacAppName = 'CsAC';
const _csacAppBranch = 'XiaoBai';
const _csacSourceUrl = 'https://github.com/VasilyZa/CsAC_Flutter.git';

class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  int versionTapCount = 0;
  DateTime? lastVersionTap;
  bool updatingDebugMode = false;

  Future<void> copySourceUrl(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final copiedText = context.strings.text('Source link copied.');
    await Clipboard.setData(const ClipboardData(text: _csacSourceUrl));
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(copiedText)));
    }
  }

  Future<void> openSourceUrl(BuildContext context) async {
    final url = Uri.parse(_csacSourceUrl);
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      await copySourceUrl(context);
    }
  }

  void handleVersionTap(BuildContext context) {
    final now = DateTime.now();
    final previous = lastVersionTap;
    if (previous == null ||
        now.difference(previous) > const Duration(seconds: 2)) {
      versionTapCount = 0;
    }
    lastVersionTap = now;
    versionTapCount++;
    if (versionTapCount >= 5) {
      versionTapCount = 0;
      unawaited(showDebugKeyDialog(context));
    }
  }

  Future<void> showDebugKeyDialog(BuildContext context) async {
    final strings = context.strings;
    final key = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('Debug mode')),
        content: TextField(
          controller: key,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(
            labelText: strings.text('Access key'),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(key.text),
            child: Text(strings.text('Activate')),
          ),
        ],
      ),
    );
    key.dispose();
    if (value == null || value.trim().isEmpty || !mounted) {
      return;
    }
    await setDebugMode(
      () => widget.state.activateDebugMode(value.trim()),
      strings.text('Debug mode activated.'),
    );
  }

  Future<void> setDebugMode(
    Future<void> Function() action,
    String success,
  ) async {
    setState(() => updatingDebugMode = true);
    try {
      await action();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.strings.format('Action failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => updatingDebugMode = false);
      }
    }
  }

  Future<void> deactivateDebugMode() async {
    await setDebugMode(
      widget.state.deactivateDebugMode,
      context.strings.text('Debug mode deactivated.'),
    );
  }

  Widget infoTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: SelectableText(value),
      trailing: trailing,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('App information'))),
      body: SafeArea(
        child: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final packageInfo = snapshot.data;
            final version = packageInfo?.version ?? '-';
            final buildNumber = packageInfo?.buildNumber ?? '-';
            final debugMode = widget.state.debugMode;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const _AppIconImage(size: 44, borderRadius: 11),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _csacAppName,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                strings.text('Third-party CsAC client'),
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
                  child: _RoundedInkClip(
                    child: Column(
                      children: [
                        infoTile(
                          context,
                          icon: Icons.apps_outlined,
                          title: strings.text('App name'),
                          value: _csacAppName,
                        ),
                        const Divider(height: 1),
                        infoTile(
                          context,
                          icon: Icons.account_tree_outlined,
                          title: strings.text('Branch'),
                          value: _csacAppBranch,
                        ),
                        const Divider(height: 1),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => handleVersionTap(context),
                          child: infoTile(
                            context,
                            icon: Icons.numbers_outlined,
                            title: strings.text('Version'),
                            value: version,
                          ),
                        ),
                        const Divider(height: 1),
                        infoTile(
                          context,
                          icon: Icons.build_outlined,
                          title: strings.text('Build number'),
                          value: buildNumber,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (debugMode) ...[
                  Card(
                    elevation: 0,
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: ListTile(
                      leading: updatingDebugMode
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.admin_panel_settings_outlined),
                      title: Text(strings.text('Debug mode active')),
                      subtitle: Text(
                        strings.text(
                          'Privileged management tools are enabled.',
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: updatingDebugMode
                            ? null
                            : deactivateDebugMode,
                        child: Text(strings.text('Deactivate')),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Card(
                  elevation: 0,
                  child: _RoundedInkClip(
                    child: Column(
                      children: [
                        infoTile(
                          context,
                          icon: Icons.code,
                          title: strings.text('Source code'),
                          value: _csacSourceUrl,
                          trailing: const Icon(Icons.open_in_new),
                          onTap: () => openSourceUrl(context),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.copy),
                          title: Text(strings.text('Copy source link')),
                          onTap: () => copySourceUrl(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AppInfoSubtitle extends StatelessWidget {
  const _AppInfoSubtitle();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final packageInfo = snapshot.data;
        final version = packageInfo == null
            ? '-'
            : VersionUpdateChecker.displayVersion(
                '${packageInfo.version}+${packageInfo.buildNumber}',
              );
        return Text('CsAC $version | $_csacAppBranch');
      },
    );
  }
}

class OpenSourceLicensesScreen extends StatefulWidget {
  const OpenSourceLicensesScreen({super.key});

  @override
  State<OpenSourceLicensesScreen> createState() =>
      _OpenSourceLicensesScreenState();
}

class _OpenSourceLicensesScreenState extends State<OpenSourceLicensesScreen> {
  late final Future<List<_LicenseNotice>> licenses = loadLicenses();

  Future<List<_LicenseNotice>> loadLicenses() async {
    final licensesByPackage = <String, Set<String>>{};
    await for (final entry in LicenseRegistry.licenses) {
      final packages = entry.packages
          .map((package) => package.trim())
          .where((package) => package.isNotEmpty)
          .toSet();
      final body = entry.paragraphs
          .map((paragraph) => paragraph.text.trimRight())
          .where((text) => text.trim().isNotEmpty)
          .join('\n\n');
      if (body.trim().isEmpty) {
        continue;
      }
      final packageNames = packages.isEmpty
          ? const <String>{'Unknown package'}
          : packages;
      for (final package in packageNames) {
        licensesByPackage.putIfAbsent(package, () => <String>{}).add(body);
      }
    }
    final notices = licensesByPackage.entries.map((entry) {
      return _LicenseNotice(
        packages: <String>[entry.key],
        body: entry.value.join('\n\n----------\n\n'),
      );
    }).toList();
    notices.sort((a, b) => a.title.compareTo(b.title));
    return notices;
  }

  Future<void> copyLicense(_LicenseNotice license) async {
    await Clipboard.setData(
      ClipboardData(text: '${license.title}\n\n${license.body}'),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('License copied.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('Open-source licenses'))),
      body: SafeArea(
        child: FutureBuilder<List<_LicenseNotice>>(
          future: licenses,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(strings.text('Loading licenses...')),
                  ],
                ),
              );
            }
            if (snapshot.hasError) {
              return _InlineError(
                message: snapshot.error.toString(),
                onRetry: () => setState(() {}),
              );
            }
            final items = snapshot.data ?? const <_LicenseNotice>[];
            if (items.isEmpty) {
              return _EmptyPanel(message: strings.text('No licenses found.'));
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    strings.format('{count} license notices', {
                      'count': items.length,
                    }),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final license in items)
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: _RoundedInkClip(
                      child: _CupertinoExpansionTile(
                        title: Text(license.title),
                        subtitle: Text(
                          strings.format('{count} packages', {
                            'count': license.packages.length,
                          }),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => copyLicense(license),
                              icon: const Icon(Icons.copy),
                              label: Text(strings.text('Copy')),
                            ),
                          ),
                          SelectableText(license.body),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AppLogsScreen extends StatefulWidget {
  const AppLogsScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<AppLogsScreen> createState() => _AppLogsScreenState();
}

class _AppLogsScreenState extends State<AppLogsScreen> {
  late Future<List<AppLogFile>> logs = widget.state.loadAppLogFiles();

  String formatLogBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    const units = <String>['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit += 1;
    }
    final decimals = value >= 10 || unit == 0 ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${units[unit]}';
  }

  void refreshLogs() {
    setState(() => logs = widget.state.loadAppLogFiles());
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.text('App logs')),
        actions: [
          IconButton(
            tooltip: strings.text('Refresh'),
            onPressed: refreshLogs,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<AppLogFile>>(
          future: logs,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _InlineError(
                message: snapshot.error.toString(),
                onRetry: refreshLogs,
              );
            }
            final items = snapshot.data ?? const <AppLogFile>[];
            if (items.isEmpty) {
              return _EmptyPanel(message: strings.text('No app logs found.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final log = items[index];
                return Card(
                  elevation: 0,
                  child: _RoundedInkClip(
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(log.name),
                      subtitle: Text(
                        '${formatLogBytes(log.bytes)} | ${formatLocalDateTime(log.modified)}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          CsacPageRoute<void>(
                            builder: (_) => AppLogDetailScreen(
                              state: widget.state,
                              log: log,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class AppLogDetailScreen extends StatefulWidget {
  const AppLogDetailScreen({super.key, required this.state, required this.log});

  final CsacAppState state;
  final AppLogFile log;

  @override
  State<AppLogDetailScreen> createState() => _AppLogDetailScreenState();
}

class _AppLogDetailScreenState extends State<AppLogDetailScreen> {
  late Future<String> content = widget.state.readAppLogFile(widget.log);

  void refreshLog() {
    setState(() => content = widget.state.readAppLogFile(widget.log));
  }

  Future<void> copyLog(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Log copied.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.log.name),
        actions: [
          IconButton(
            tooltip: strings.text('Refresh'),
            onPressed: refreshLog,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: content,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _InlineError(
                message: snapshot.error.toString(),
                onRetry: refreshLog,
              );
            }
            final text = snapshot.data ?? '';
            if (text.isEmpty) {
              return _EmptyPanel(message: strings.text('This log is empty.'));
            }
            final csacColors = CsacColors.of(context);
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
                  decoration: BoxDecoration(
                    color: csacColors.cardBackground,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: csacColors.separator.withValues(alpha: 0.34),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: CupertinoTheme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SelectableText(
                              widget.log.path,
                              style: TextStyle(
                                color: csacColors.label,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              strings.text(
                                'Showing the latest part of this log.',
                              ),
                              style: TextStyle(
                                color: csacColors.secondaryLabel,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.all(8),
                        minimumSize: Size.zero,
                        onPressed: () => copyLog(text),
                        child: const Icon(Icons.copy, size: 21),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SelectableText(
                      text,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class NetworkDiagnosticsScreen extends StatefulWidget {
  const NetworkDiagnosticsScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<NetworkDiagnosticsScreen> createState() =>
      _NetworkDiagnosticsScreenState();
}

class _NetworkDiagnosticsScreenState extends State<NetworkDiagnosticsScreen> {
  late Future<NetworkDiagnosticReport> report = widget.state
      .runNetworkDiagnostics();

  void rerun() {
    setState(() => report = widget.state.runNetworkDiagnostics());
  }

  Future<void> copyReport(NetworkDiagnosticReport value) async {
    final buffer = StringBuffer()
      ..writeln('Server: ${value.serverUrl}')
      ..writeln('Origin: ${value.originUrl}')
      ..writeln('Started: ${formatLocalDateTime(value.startedAt)}')
      ..writeln('Total: ${value.totalMs} ms')
      ..writeln();
    for (final check in value.checks) {
      buffer.writeln(
        '[${check.ok ? 'OK' : 'FAIL'}] ${check.name} '
        '${check.elapsedMs} ms ${check.detail}',
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.strings.text('Diagnostic report copied.')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.text('Connection diagnostics')),
        actions: [
          IconButton(
            tooltip: strings.text('Run again'),
            onPressed: rerun,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<NetworkDiagnosticReport>(
          future: report,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(strings.text('Running diagnostics...')),
                  ],
                ),
              );
            }
            if (snapshot.hasError) {
              return _InlineError(
                message: snapshot.error.toString(),
                onRetry: rerun,
              );
            }
            final value = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: value.passed
                              ? colors.primaryContainer
                              : colors.errorContainer,
                          child: Icon(
                            value.passed
                                ? Icons.check_rounded
                                : Icons.error_outline,
                            color: value.passed
                                ? colors.onPrimaryContainer
                                : colors.onErrorContainer,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.text(
                                  value.passed
                                      ? 'Connection looks good'
                                      : 'Connection has issues',
                                ),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                strings.format('Total latency: {ms} ms', {
                                  'ms': value.totalMs,
                                }),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: strings.text('Copy'),
                          onPressed: () => copyReport(value),
                          icon: const Icon(Icons.copy),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  child: _RoundedInkClip(
                    child: Column(
                      children: [
                        _DiagnosticInfoTile(
                          icon: Icons.dns_outlined,
                          label: strings.text('Server'),
                          value: value.serverUrl,
                        ),
                        const Divider(height: 1),
                        _DiagnosticInfoTile(
                          icon: Icons.public_outlined,
                          label: strings.text('Image origin'),
                          value: value.originUrl,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final check in value.checks)
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        check.ok
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: check.ok ? colors.primary : colors.error,
                      ),
                      title: Text(strings.text(check.name)),
                      subtitle: SelectableText(
                        check.detail.isEmpty ? '-' : check.detail,
                      ),
                      trailing: Text('${check.elapsedMs} ms'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DiagnosticInfoTile extends StatelessWidget {
  const _DiagnosticInfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: SelectableText(value),
    );
  }
}

enum ApiDocMethod { get, post }

class ApiDocParam {
  const ApiDocParam({
    required this.name,
    required this.description,
    this.required = false,
    this.example = '',
  });

  final String name;
  final String description;
  final bool required;
  final String example;
}

class ApiDocEndpoint {
  const ApiDocEndpoint({
    required this.group,
    required this.route,
    required this.method,
    required this.summary,
    required this.description,
    this.params = const <ApiDocParam>[],
  });

  final String group;
  final String route;
  final ApiDocMethod method;
  final String summary;
  final String description;
  final List<ApiDocParam> params;

  String get methodLabel => method == ApiDocMethod.post ? 'POST' : 'GET';
}

const apiDocEndpoints = <ApiDocEndpoint>[
  ApiDocEndpoint(
    group: 'Auth',
    route: 'auth/login',
    method: ApiDocMethod.post,
    summary: 'Login',
    description: 'Log in with username and password.',
    params: [
      ApiDocParam(name: 'username', description: 'Username', required: true),
      ApiDocParam(name: 'pwd', description: 'Password', required: true),
      ApiDocParam(
        name: 'platform',
        description: 'Client identifier: client-branch-version',
        required: true,
        example: 'flutter-xiaobai-1.3.4',
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Auth',
    route: 'auth/register',
    method: ApiDocMethod.post,
    summary: 'Register account',
    description: 'Create a new user account.',
    params: [
      ApiDocParam(name: 'username', description: 'Username', required: true),
      ApiDocParam(name: 'nickname', description: 'Nickname', required: true),
      ApiDocParam(name: 'pwd', description: 'Password', required: true),
      ApiDocParam(
        name: 'confirm_pwd',
        description: 'Confirm password',
        required: true,
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Auth',
    route: 'auth/logout',
    method: ApiDocMethod.post,
    summary: 'Logout',
    description: 'Clear the current server session.',
  ),
  ApiDocEndpoint(
    group: 'User',
    route: 'user/get_info',
    method: ApiDocMethod.get,
    summary: 'Get user profile',
    description: 'Get current user profile, or another user by uid.',
    params: [ApiDocParam(name: 'uid', description: 'Target user UID')],
  ),
  ApiDocEndpoint(
    group: 'User',
    route: 'user/update_profile',
    method: ApiDocMethod.post,
    summary: 'Update profile',
    description: 'Update nickname, privacy, pat action or profile fields.',
    params: [
      ApiDocParam(
        name: 'action',
        description: 'nickname / privacy / pat_action',
        required: true,
        example: 'nickname',
      ),
      ApiDocParam(name: 'nickname', description: 'New nickname'),
      ApiDocParam(name: 'pat_action', description: 'Pat action text'),
      ApiDocParam(name: 'allow_auto_join', description: '0 or 1'),
    ],
  ),
  ApiDocEndpoint(
    group: 'User',
    route: 'user/upgrade_password',
    method: ApiDocMethod.post,
    summary: 'Upgrade password hash',
    description:
        'Change password for an account still using the old hash flow.',
    params: [
      ApiDocParam(
        name: 'old_password',
        description: 'Current password',
        required: true,
      ),
      ApiDocParam(
        name: 'new_password',
        description: 'New password',
        required: true,
      ),
      ApiDocParam(
        name: 'confirm_password',
        description: 'Confirm new password',
        required: true,
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'User',
    route: 'user/delete_account',
    method: ApiDocMethod.post,
    summary: 'Delete account',
    description: 'Permanently delete the current account and owned groups.',
  ),
  ApiDocEndpoint(
    group: 'User',
    route: 'user/get_friends',
    method: ApiDocMethod.get,
    summary: 'Friend list',
    description: 'Return accepted friends for current user.',
  ),
  ApiDocEndpoint(
    group: 'User',
    route: 'user/get_groups',
    method: ApiDocMethod.get,
    summary: 'Joined groups',
    description: 'Return groups joined by current user.',
  ),
  ApiDocEndpoint(
    group: 'User',
    route: 'user/get_notifications',
    method: ApiDocMethod.get,
    summary: 'Notification counters',
    description:
        'Return unread notice, friend request and deleted-friend counts.',
  ),
  ApiDocEndpoint(
    group: 'User',
    route: 'user/get_notice_list',
    method: ApiDocMethod.get,
    summary: 'Notice list',
    description: 'Return system notices for the current user.',
  ),
  ApiDocEndpoint(
    group: 'User',
    route: 'user/mark_notice_read',
    method: ApiDocMethod.post,
    summary: 'Mark notices read',
    description:
        'Mark one notice as read, or all notices when read_all is true.',
    params: [
      ApiDocParam(name: 'notice_id', description: 'Notice ID'),
      ApiDocParam(name: 'read_all', description: '0 or 1', example: '1'),
    ],
  ),
  ApiDocEndpoint(
    group: 'User',
    route: 'user/get_created_groups',
    method: ApiDocMethod.get,
    summary: 'Created groups',
    description: 'Return public groups created by a user.',
    params: [ApiDocParam(name: 'uid', description: 'Target user UID')],
  ),
  ApiDocEndpoint(
    group: 'Friend',
    route: 'friend/send_request',
    method: ApiDocMethod.post,
    summary: 'Send friend request',
    description: 'Request to add a user as friend.',
    params: [
      ApiDocParam(name: 'friend_id', description: 'Target UID', required: true),
      ApiDocParam(name: 'message', description: 'Request message'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Friend',
    route: 'friend/handle_request',
    method: ApiDocMethod.post,
    summary: 'Handle friend request',
    description: 'Accept or reject a friend request.',
    params: [
      ApiDocParam(
        name: 'request_id',
        description: 'Friend request ID',
        required: true,
      ),
      ApiDocParam(
        name: 'action',
        description: 'agree or reject',
        required: true,
        example: 'agree',
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Friend',
    route: 'friend/update_remark',
    method: ApiDocMethod.post,
    summary: 'Update friend remark',
    description: 'Set remark for a friend.',
    params: [
      ApiDocParam(name: 'friend_id', description: 'Friend UID', required: true),
      ApiDocParam(name: 'remark', description: 'Remark text'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Friend',
    route: 'friend/delete_friend',
    method: ApiDocMethod.post,
    summary: 'Delete friend',
    description: 'Remove a friend relation.',
    params: [
      ApiDocParam(name: 'friend_id', description: 'Friend UID', required: true),
    ],
  ),
  ApiDocEndpoint(
    group: 'Friend',
    route: 'friend/block_friend',
    method: ApiDocMethod.post,
    summary: 'Block friend',
    description: 'Block an existing friend relation.',
    params: [
      ApiDocParam(name: 'friend_id', description: 'Friend UID', required: true),
    ],
  ),
  ApiDocEndpoint(
    group: 'Friend',
    route: 'friend/recover_friend',
    method: ApiDocMethod.post,
    summary: 'Recover friend',
    description: 'Recover a deleted friend directly or send a recover request.',
    params: [
      ApiDocParam(name: 'friend_id', description: 'Friend UID', required: true),
      ApiDocParam(name: 'direct', description: '0 or 1'),
      ApiDocParam(name: 'message', description: 'Recover request message'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Friend',
    route: 'friend/get_common_groups',
    method: ApiDocMethod.get,
    summary: 'Common groups',
    description: 'List common groups with a friend.',
    params: [
      ApiDocParam(name: 'friend_id', description: 'Friend UID', required: true),
    ],
  ),
  ApiDocEndpoint(
    group: 'Friend',
    route: 'friend/get_deleted_notices',
    method: ApiDocMethod.get,
    summary: 'Deleted friend notices',
    description: 'Return recently deleted friend relation notices.',
  ),
  ApiDocEndpoint(
    group: 'Friend',
    route: 'friend/get_friend_requests',
    method: ApiDocMethod.get,
    summary: 'Pending friend requests',
    description: 'Return pending friend requests for the current user.',
  ),
  ApiDocEndpoint(
    group: 'Group',
    route: 'group/get_public_list',
    method: ApiDocMethod.get,
    summary: 'Public groups',
    description: 'List public groups.',
  ),
  ApiDocEndpoint(
    group: 'Group',
    route: 'group/get_group_view_info',
    method: ApiDocMethod.get,
    summary: 'Group profile',
    description: 'Get group profile and membership state.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Group',
    route: 'group/get_members',
    method: ApiDocMethod.get,
    summary: 'Group members',
    description: 'List members in a group.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Group',
    route: 'group/get_applications',
    method: ApiDocMethod.get,
    summary: 'Join applications',
    description: 'List pending join applications for a group.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Group',
    route: 'group/create',
    method: ApiDocMethod.post,
    summary: 'Create group',
    description: 'Create a new group.',
    params: [
      ApiDocParam(name: 'room_name', description: 'Group name', required: true),
      ApiDocParam(name: 'description', description: 'Group description'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Group',
    route: 'group/apply_join',
    method: ApiDocMethod.post,
    summary: 'Apply to join group',
    description: 'Send a join request or join by invite code.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
      ApiDocParam(name: 'code', description: 'Invite code if required'),
      ApiDocParam(name: 'answer', description: 'Join question answer'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Group',
    route: 'group/handle_apply',
    method: ApiDocMethod.post,
    summary: 'Handle join application',
    description: 'Approve or refuse a pending group join application.',
    params: [
      ApiDocParam(
        name: 'apply_id',
        description: 'Application ID',
        required: true,
      ),
      ApiDocParam(
        name: 'action',
        description: 'pass or refuse',
        required: true,
        example: 'pass',
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Group',
    route: 'group/invite_member',
    method: ApiDocMethod.post,
    summary: 'Invite member',
    description: 'Invite a user into a group.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
      ApiDocParam(
        name: 'target_uid',
        description: 'Target UID',
        required: true,
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Group',
    route: 'group/edit_info',
    method: ApiDocMethod.post,
    summary: 'Edit group info',
    description:
        'Update group name, intro, notice or avatar URL. File avatar upload is not supported by this debugger.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
      ApiDocParam(
        name: 'action',
        description: 'name / intro / notice / avatar',
        example: 'name',
      ),
      ApiDocParam(name: 'value', description: 'Value used with action'),
      ApiDocParam(name: 'room_name', description: 'Group name'),
      ApiDocParam(name: 'intro', description: 'Group intro'),
      ApiDocParam(name: 'notice', description: 'Group notice'),
      ApiDocParam(name: 'avatar', description: 'Avatar URL'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Group',
    route: 'group/update_settings',
    method: ApiDocMethod.post,
    summary: 'Update group settings',
    description: 'Update join mode, invite permissions and group visibility.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
      ApiDocParam(name: 'join_type', description: '1-4'),
      ApiDocParam(name: 'fixed_code', description: 'Fixed invite code'),
      ApiDocParam(name: 'question', description: 'Join question'),
      ApiDocParam(name: 'answer', description: 'Join answer'),
      ApiDocParam(name: 'show_in_list', description: '0 or 1'),
      ApiDocParam(name: 'allow_invite', description: '0 or 1'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Group',
    route: 'group/reset_invite_code',
    method: ApiDocMethod.post,
    summary: 'Reset invite code',
    description: 'Generate a new group invite code.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Group',
    route: 'group/transfer',
    method: ApiDocMethod.post,
    summary: 'Transfer group owner',
    description: 'Send a group ownership transfer request.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
      ApiDocParam(
        name: 'target_uid',
        description: 'New owner UID',
        required: true,
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Group',
    route: 'group/disband',
    method: ApiDocMethod.post,
    summary: 'Disband group',
    description: 'Mark a group as disbanded.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Group',
    route: 'group/leave',
    method: ApiDocMethod.post,
    summary: 'Leave group',
    description: 'Leave a joined group. Owners must transfer or disband first.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Group',
    route: 'group/mute_member',
    method: ApiDocMethod.post,
    summary: 'Mute member',
    description: 'Mute or unmute a group member.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
      ApiDocParam(
        name: 'target_uid',
        description: 'Target UID',
        required: true,
      ),
      ApiDocParam(
        name: 'action',
        description: 'mute or unmute',
        required: true,
        example: 'mute',
      ),
      ApiDocParam(name: 'minutes', description: '1-43200 when muting'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Group',
    route: 'group/kick_member',
    method: ApiDocMethod.post,
    summary: 'Kick member',
    description: 'Remove a member from a group.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
      ApiDocParam(
        name: 'target_uid',
        description: 'Target UID',
        required: true,
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Group',
    route: 'group/set_admin',
    method: ApiDocMethod.post,
    summary: 'Set admin',
    description: 'Grant or revoke group admin permission.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
      ApiDocParam(
        name: 'target_uid',
        description: 'Target UID',
        required: true,
      ),
      ApiDocParam(
        name: 'action',
        description: 'set or remove',
        required: true,
        example: 'set',
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Group',
    route: 'group/set_member_title',
    method: ApiDocMethod.post,
    summary: 'Set member title',
    description: 'Set custom group title and level for a member.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
      ApiDocParam(
        name: 'target_uid',
        description: 'Target UID',
        required: true,
      ),
      ApiDocParam(name: 'title', description: 'Member title'),
      ApiDocParam(name: 'level', description: 'Member level 1-100'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Message',
    route: 'message/get_group_msg',
    method: ApiDocMethod.get,
    summary: 'Group messages',
    description: 'Load group messages with pagination.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
      ApiDocParam(name: 'before_id', description: 'Load messages before ID'),
      ApiDocParam(name: 'after_id', description: 'Load messages after ID'),
      ApiDocParam(name: 'limit', description: '20-200', example: '80'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Message',
    route: 'message/get_private_msg',
    method: ApiDocMethod.get,
    summary: 'Private messages',
    description: 'Load private messages with pagination.',
    params: [
      ApiDocParam(name: 'friend_id', description: 'Friend UID', required: true),
      ApiDocParam(name: 'last_id', description: 'Alias for after_id'),
      ApiDocParam(name: 'before_id', description: 'Load messages before ID'),
      ApiDocParam(name: 'after_id', description: 'Load messages after ID'),
      ApiDocParam(name: 'limit', description: '20-200', example: '80'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Message',
    route: 'message/send_group_msg',
    method: ApiDocMethod.post,
    summary: 'Send group message',
    description:
        'Send a text message to a group. File upload is not supported by this debugger.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
      ApiDocParam(name: 'content', description: 'Message text', required: true),
      ApiDocParam(name: 'reply_to', description: 'Reply message ID'),
      ApiDocParam(name: 'mention_uids', description: 'Comma separated UIDs'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Message',
    route: 'message/send_private_msg',
    method: ApiDocMethod.post,
    summary: 'Send private message',
    description:
        'Send a text message to a friend. File upload is not supported by this debugger.',
    params: [
      ApiDocParam(name: 'friend_id', description: 'Friend UID', required: true),
      ApiDocParam(name: 'content', description: 'Message text', required: true),
      ApiDocParam(name: 'reply_to', description: 'Reply message ID'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Message',
    route: 'message/send_voice_msg',
    method: ApiDocMethod.post,
    summary: 'Send voice message',
    description:
        'Send a voice message. File upload is not supported by this debugger.',
    params: [
      ApiDocParam(name: 'room_id', description: 'Group room ID'),
      ApiDocParam(name: 'friend_id', description: 'Private friend UID'),
      ApiDocParam(name: 'duration', description: 'Duration in seconds'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Message',
    route: 'message/mark_read',
    method: ApiDocMethod.post,
    summary: 'Mark read',
    description: 'Mark private chat read or update group last read position.',
    params: [
      ApiDocParam(name: 'friend_id', description: 'Private friend UID'),
      ApiDocParam(name: 'room_id', description: 'Group room ID'),
      ApiDocParam(name: 'last_msg_id', description: 'Group last read message'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Message',
    route: 'message/send_pat_msg',
    method: ApiDocMethod.post,
    summary: 'Send pat',
    description: 'Send a pat system message in group chat.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
      ApiDocParam(
        name: 'target_uid',
        description: 'Target UID',
        required: true,
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Message',
    route: 'message/recall_msg',
    method: ApiDocMethod.post,
    summary: 'Recall message',
    description: 'Recall a group or private message.',
    params: [
      ApiDocParam(name: 'msg_id', description: 'Message ID', required: true),
      ApiDocParam(name: 'room_id', description: 'Group room ID'),
      ApiDocParam(name: 'type', description: 'group or private'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Message',
    route: 'message/get_mentions',
    method: ApiDocMethod.get,
    summary: 'Mention counters',
    description:
        'Return group mention and reply counters for the current user.',
  ),
  ApiDocEndpoint(
    group: 'Essence',
    route: 'essence/get_essence',
    method: ApiDocMethod.get,
    summary: 'Essence messages',
    description: 'Load group essence messages.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Essence',
    route: 'essence/get_essence_stats',
    method: ApiDocMethod.get,
    summary: 'Essence stats',
    description: 'Load essence statistics for a group.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
      ApiDocParam(name: 'type', description: 'today / week / month / all'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Essence',
    route: 'essence/set_essence',
    method: ApiDocMethod.post,
    summary: 'Toggle essence',
    description: 'Set or unset a group message as essence.',
    params: [
      ApiDocParam(
        name: 'room_id',
        description: 'Group room ID',
        required: true,
      ),
      ApiDocParam(name: 'msg_id', description: 'Message ID', required: true),
    ],
  ),
  ApiDocEndpoint(
    group: 'Report',
    route: 'report/submit_report',
    method: ApiDocMethod.post,
    summary: 'Submit report',
    description: 'Report a user or group.',
    params: [
      ApiDocParam(
        name: 'type',
        description: 'user or group',
        required: true,
        example: 'user',
      ),
      ApiDocParam(name: 'uid', description: 'Reported user UID'),
      ApiDocParam(name: 'rid', description: 'Reported group room ID'),
      ApiDocParam(
        name: 'reason',
        description: 'At least 10 characters',
        required: true,
      ),
      ApiDocParam(name: 'anonymous', description: '0 or 1'),
      ApiDocParam(name: 'nickname', description: 'Reported user nickname'),
      ApiDocParam(name: 'username', description: 'Reported username'),
      ApiDocParam(name: 'room_name', description: 'Reported group name'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Admin',
    route: 'admin/generate_token',
    method: ApiDocMethod.post,
    summary: 'Generate admin token',
    description: 'Generate a short-lived admin token. Admin only.',
  ),
  ApiDocEndpoint(
    group: 'Admin',
    route: 'admin/admin_ban',
    method: ApiDocMethod.get,
    summary: 'Ban list',
    description:
        'List currently banned users and groups. Admin token required.',
    params: [
      ApiDocParam(name: 'token', description: 'Admin token', required: true),
    ],
  ),
  ApiDocEndpoint(
    group: 'Admin',
    route: 'admin/admin_ban',
    method: ApiDocMethod.post,
    summary: 'Manage bans',
    description: 'Ban or unban users and groups. Admin token required.',
    params: [
      ApiDocParam(name: 'token', description: 'Admin token', required: true),
      ApiDocParam(
        name: 'action',
        description: 'ban_user / unban_user / ban_room / unban_room',
        required: true,
        example: 'ban_user',
      ),
      ApiDocParam(name: 'user_id', description: 'User ID for user ban actions'),
      ApiDocParam(
        name: 'room_id',
        description: 'Room ID for group ban actions',
      ),
      ApiDocParam(name: 'ban_days', description: 'Ban duration in days'),
      ApiDocParam(name: 'ban_reason', description: 'Ban reason'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Utility',
    route: 'utils/upload_image',
    method: ApiDocMethod.post,
    summary: 'Upload image',
    description:
        'Upload an image file. Multipart file upload is not supported by this debugger.',
    params: [
      ApiDocParam(name: 'image', description: 'Multipart file field name'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Utility',
    route: 'utils/upload_voice',
    method: ApiDocMethod.post,
    summary: 'Upload voice',
    description:
        'Upload a voice file. Multipart file upload is not supported by this debugger.',
    params: [
      ApiDocParam(name: 'voice', description: 'Multipart file field name'),
    ],
  ),
  ApiDocEndpoint(
    group: 'Feedback',
    route: 'bug_report',
    method: ApiDocMethod.post,
    summary: 'Bug report',
    description: 'Submit app feedback to administrators.',
    params: [
      ApiDocParam(name: 'title', description: 'Feedback title', required: true),
      ApiDocParam(
        name: 'description',
        description: 'Feedback description',
        required: true,
      ),
    ],
  ),
  ApiDocEndpoint(
    group: 'Utility',
    route: 'test',
    method: ApiDocMethod.get,
    summary: 'API health test',
    description: 'Simple API/database health check.',
  ),
];

class ApiExplorerScreen extends StatefulWidget {
  const ApiExplorerScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<ApiExplorerScreen> createState() => _ApiExplorerScreenState();
}

class _ApiExplorerScreenState extends State<ApiExplorerScreen> {
  late final TextEditingController search;
  final route = TextEditingController();
  final paramControllers = <String, TextEditingController>{};
  ApiDocEndpoint selected = apiDocEndpoints.first;
  ApiDebugResponse? response;
  String? error;
  bool running = false;

  @override
  void initState() {
    super.initState();
    search = TextEditingController()..addListener(() => setState(() {}));
    applyEndpoint(selected, notify: false);
  }

  @override
  void dispose() {
    search.dispose();
    route.dispose();
    for (final controller in paramControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<ApiDocEndpoint> get filteredEndpoints {
    final query = search.text.trim().toLowerCase();
    if (query.isEmpty) {
      return apiDocEndpoints;
    }
    return apiDocEndpoints.where((endpoint) {
      return endpoint.route.toLowerCase().contains(query) ||
          endpoint.group.toLowerCase().contains(query) ||
          endpoint.summary.toLowerCase().contains(query) ||
          endpoint.description.toLowerCase().contains(query) ||
          endpoint.params.any(
            (param) =>
                param.name.toLowerCase().contains(query) ||
                param.description.toLowerCase().contains(query),
          );
    }).toList();
  }

  void selectEndpoint(ApiDocEndpoint endpoint) {
    applyEndpoint(endpoint);
  }

  void applyEndpoint(ApiDocEndpoint endpoint, {bool notify = true}) {
    selected = endpoint;
    route.text = endpoint.route;
    final existingValues = <String, String>{
      for (final entry in paramControllers.entries) entry.key: entry.value.text,
    };
    for (final controller in paramControllers.values) {
      controller.dispose();
    }
    paramControllers
      ..clear()
      ..addEntries(
        endpoint.params.map(
          (param) => MapEntry(
            param.name,
            TextEditingController(
              text: existingValues[param.name] ?? param.example,
            ),
          ),
        ),
      );
    response = null;
    error = null;
    if (notify && mounted) {
      setState(() {});
    }
  }

  Map<String, String> requestValues() {
    return <String, String>{
      for (final entry in paramControllers.entries)
        if (entry.value.text.trim().isNotEmpty)
          entry.key: entry.value.text.trim(),
    };
  }

  Future<void> runSelectedEndpoint() async {
    if (running) {
      return;
    }
    setState(() {
      running = true;
      error = null;
      response = null;
    });
    try {
      final result = await widget.state.runApiDebugRequest(
        method: selected.methodLabel,
        route: route.text.trim(),
        values: requestValues(),
      );
      if (mounted) {
        setState(() => response = result);
      }
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => running = false);
      }
    }
  }

  Future<void> copyResult() async {
    final text = response?.prettyBody ?? error ?? '';
    if (text.trim().isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings.text('Copied.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    final endpoints = filteredEndpoints;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.text('API explorer')),
        actions: [
          IconButton(
            tooltip: strings.text('Copy'),
            onPressed: response == null && error == null ? null : copyResult,
            icon: const Icon(Icons.copy),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 860;
            final list = _ApiEndpointList(
              search: search,
              endpoints: endpoints,
              selected: selected,
              onSelect: selectEndpoint,
            );
            final detail = _ApiEndpointDetail(
              endpoint: selected,
              route: route,
              paramControllers: paramControllers,
              running: running,
              response: response,
              error: error,
              onRun: runSelectedEndpoint,
              onCopy: copyResult,
            );
            if (wide) {
              return Row(
                children: [
                  SizedBox(width: 340, child: list),
                  VerticalDivider(width: 1, color: colors.outlineVariant),
                  Expanded(child: detail),
                ],
              );
            }
            return Column(
              children: [
                SizedBox(height: 260, child: list),
                Divider(height: 1, color: colors.outlineVariant),
                Expanded(child: detail),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ApiEndpointList extends StatelessWidget {
  const _ApiEndpointList({
    required this.search,
    required this.endpoints,
    required this.selected,
    required this.onSelect,
  });

  final TextEditingController search;
  final List<ApiDocEndpoint> endpoints;
  final ApiDocEndpoint selected;
  final ValueChanged<ApiDocEndpoint> onSelect;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: strings.text('Search API endpoints'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: endpoints.isEmpty
              ? _EmptyPanel(message: strings.text('No matching API.'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  itemCount: endpoints.length,
                  itemBuilder: (context, index) {
                    final endpoint = endpoints[index];
                    final active =
                        endpoint.route == selected.route &&
                        endpoint.method == selected.method;
                    return Card(
                      elevation: 0,
                      color: active
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: ListTile(
                        dense: true,
                        leading: _ApiMethodBadge(method: endpoint.methodLabel),
                        title: Text(endpoint.route),
                        subtitle: Text(
                          '${endpoint.group} · ${endpoint.summary}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: active,
                        onTap: () => onSelect(endpoint),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ApiEndpointDetail extends StatelessWidget {
  const _ApiEndpointDetail({
    required this.endpoint,
    required this.route,
    required this.paramControllers,
    required this.running,
    required this.response,
    required this.error,
    required this.onRun,
    required this.onCopy,
  });

  final ApiDocEndpoint endpoint;
  final TextEditingController route;
  final Map<String, TextEditingController> paramControllers;
  final bool running;
  final ApiDebugResponse? response;
  final String? error;
  final VoidCallback onRun;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _ApiMethodBadge(method: endpoint.methodLabel),
                    Chip(label: Text(endpoint.group)),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(
                  endpoint.route,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  endpoint.summary,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  endpoint.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.text('Run online'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: route,
                  decoration: InputDecoration(
                    labelText: strings.text('Route'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                if (endpoint.params.isEmpty)
                  Text(
                    strings.text('No parameters.'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  )
                else
                  for (final param in endpoint.params) ...[
                    TextField(
                      controller: paramControllers[param.name],
                      decoration: InputDecoration(
                        labelText: '${param.name}${param.required ? ' *' : ''}',
                        helperText: param.description,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                OverflowBar(
                  alignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.icon(
                      onPressed: running ? null : onRun,
                      icon: running
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(strings.text('Run request')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _ApiResultPanel(
              response: response,
              error: error,
              onCopy: onCopy,
            ),
          ),
        ),
      ],
    );
  }
}

class _ApiMethodBadge extends StatelessWidget {
  const _ApiMethodBadge({required this.method});

  final String method;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final post = method == 'POST';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: post ? colors.tertiaryContainer : colors.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          method,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: post
                ? colors.onTertiaryContainer
                : colors.onSecondaryContainer,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ApiResultPanel extends StatelessWidget {
  const _ApiResultPanel({
    required this.response,
    required this.error,
    required this.onCopy,
  });

  final ApiDebugResponse? response;
  final String? error;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    final text =
        response?.prettyBody ?? error ?? strings.text('No response yet.');
    final hasResult = response != null || error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                strings.text('Response'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (response != null)
              Chip(
                label: Text(
                  '${response!.statusCode} · ${response!.elapsedMs} ms',
                ),
              ),
            IconButton(
              tooltip: strings.text('Copy'),
              onPressed: hasResult ? onCopy : null,
              icon: const Icon(Icons.copy),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SelectableText(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.35,
                  color: error == null ? null : colors.error,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LicenseNotice {
  const _LicenseNotice({required this.packages, required this.body});

  final List<String> packages;
  final String body;

  String get title =>
      packages.isEmpty ? 'Unknown package' : packages.join(', ');
}

class _PinPromptDialog extends StatefulWidget {
  const _PinPromptDialog({
    required this.title,
    required this.label,
    required this.confirm,
  });

  final String title;
  final String label;
  final bool confirm;

  @override
  State<_PinPromptDialog> createState() => _PinPromptDialogState();
}

class _PinPromptDialogState extends State<_PinPromptDialog> {
  String pin = '';
  String pinConfirm = '';
  String? localError;
  bool confirming = false;

  String get activePin => confirming ? pinConfirm : pin;

  void updateActivePin(String value) {
    setState(() {
      if (confirming) {
        pinConfirm = value;
      } else {
        pin = value;
      }
      localError = null;
    });
    if (value.length >= 8) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && activePin.length >= 8) {
          submit();
        }
      });
    }
  }

  bool validateFirstPin() {
    if (AppLockPin.isValid(pin)) {
      return true;
    }
    setState(() {
      localError = context.strings.text('PIN must be 4-8 digits.');
    });
    return false;
  }

  void moveToConfirm() {
    if (!validateFirstPin()) {
      return;
    }
    setState(() {
      confirming = true;
      pinConfirm = '';
      localError = null;
    });
  }

  void submit() {
    if (widget.confirm && !confirming) {
      moveToConfirm();
      return;
    }
    if (!validateFirstPin()) {
      return;
    }
    if (widget.confirm && pin != pinConfirm) {
      setState(() {
        localError = context.strings.text('PINs do not match.');
        pinConfirm = '';
      });
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final activeLabel = widget.confirm && confirming
        ? strings.text('Confirm PIN')
        : strings.text(widget.label);
    return AlertDialog(
      title: Text(strings.text(widget.title)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PinEntryPad(
              value: activePin,
              onChanged: updateActivePin,
              label: activeLabel,
              helperText: strings.text(
                widget.confirm && confirming ? 'Enter PIN again' : '4-8 digits',
              ),
            ),
            if (localError != null) ...[
              const SizedBox(height: 12),
              Text(
                localError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.text('Cancel')),
        ),
        if (widget.confirm && confirming)
          TextButton(
            onPressed: () {
              setState(() {
                confirming = false;
                pinConfirm = '';
                localError = null;
              });
            },
            child: Text(strings.text('Back')),
          ),
        FilledButton(
          onPressed: AppLockPin.isValid(activePin) ? submit : null,
          child: Text(
            strings.text(widget.confirm && !confirming ? 'Next' : 'Save'),
          ),
        ),
      ],
    );
  }
}

class _BugReportDraft {
  const _BugReportDraft({required this.title, required this.description});

  final String title;
  final String description;
}

class _BugReportDialog extends StatefulWidget {
  const _BugReportDialog();

  @override
  State<_BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<_BugReportDialog> {
  final title = TextEditingController();
  final description = TextEditingController();

  @override
  void initState() {
    super.initState();
    title.addListener(() => setState(() {}));
    description.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  void submit() {
    Navigator.of(
      context,
    ).pop(_BugReportDraft(title: title.text, description: description.text));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final canSubmit =
        title.text.trim().isNotEmpty && description.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(strings.text('Report a problem')),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: strings.text('Feedback title'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: description,
              minLines: 4,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: strings.text('Feedback description'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.text('Cancel')),
        ),
        FilledButton(
          onPressed: canSubmit ? submit : null,
          child: Text(strings.text('Submit feedback')),
        ),
      ],
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.state,
    this.initialDeveloperOptionsExpanded = false,
    this.initialCategoryIndex,
  });

  final CsacAppState state;
  final bool initialDeveloperOptionsExpanded;
  final int? initialCategoryIndex;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

enum _SettingsCategory { account, appearance, data, security, about, developer }

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController serverUrl;
  late final TextEditingController settingsSearch;
  late final ScrollController settingsScroll;
  bool clearing = false;
  bool refreshing = false;
  bool savingServer = false;
  bool loadingPerformanceStats = false;
  bool clearingPerformanceCaches = false;
  bool enablingLowPerformanceMode = false;
  bool submittingBugReport = false;
  bool checkingVersionUpdate = false;
  PerformanceCacheStats? performanceStats;
  late bool developerOptionsExpanded;
  _SettingsCategory? activeCategory;

  static const themeColorOptions = <_ThemeColorOption>[
    _ThemeColorOption('Emerald', Color(0xff1f8a70)),
    _ThemeColorOption('Blue', Color(0xff2563eb)),
    _ThemeColorOption('Violet', Color(0xff7c3aed)),
    _ThemeColorOption('Rose', Color(0xffe11d48)),
    _ThemeColorOption('Orange', Color(0xffea580c)),
    _ThemeColorOption('Teal', Color(0xff0f766e)),
    _ThemeColorOption('Indigo', Color(0xff4f46e5)),
    _ThemeColorOption('Slate', Color(0xff475569)),
  ];

  static const chatBubbleColorOptions = <_ThemeColorOption>[
    _ThemeColorOption('Emerald', Color(0xff1f8a70)),
    _ThemeColorOption('Blue', Color(0xff2563eb)),
    _ThemeColorOption('Teal', Color(0xff0f766e)),
    _ThemeColorOption('Indigo', Color(0xff4f46e5)),
    _ThemeColorOption('Violet', Color(0xff7c3aed)),
    _ThemeColorOption('Rose', Color(0xffe11d48)),
    _ThemeColorOption('Orange', Color(0xffea580c)),
    _ThemeColorOption('Slate', Color(0xff475569)),
    _ThemeColorOption('Mint', Color(0xff99f6e4)),
    _ThemeColorOption('Sky', Color(0xffbfdbfe)),
    _ThemeColorOption('Lavender', Color(0xffddd6fe)),
    _ThemeColorOption('Sand', Color(0xfffde68a)),
  ];

  @override
  void initState() {
    super.initState();
    settingsScroll = ScrollController();
    serverUrl = TextEditingController(text: widget.state.preferences.serverUrl);
    settingsSearch = TextEditingController()..addListener(handleSearchChanged);
    activeCategory = initialSettingsCategory();
    developerOptionsExpanded =
        widget.initialDeveloperOptionsExpanded ||
        activeCategory == _SettingsCategory.developer;
    unawaited(loadPerformanceStats());
  }

  @override
  void dispose() {
    settingsSearch.removeListener(handleSearchChanged);
    settingsSearch.dispose();
    serverUrl.dispose();
    settingsScroll.dispose();
    super.dispose();
  }

  void handleSearchChanged() {
    setState(() {});
  }

  _SettingsCategory? initialSettingsCategory() {
    final index = widget.initialCategoryIndex;
    if (index == null ||
        index < 0 ||
        index >= _SettingsCategory.values.length) {
      return widget.initialDeveloperOptionsExpanded
          ? _SettingsCategory.developer
          : null;
    }
    return _SettingsCategory.values[index];
  }

  bool settingMatches(String query, Iterable<String> keywords) {
    if (query.isEmpty) {
      return true;
    }
    final lowerQuery = query.toLowerCase();
    final strings = context.strings;
    return keywords.any((keyword) {
      final translated = strings.text(keyword).toLowerCase();
      return keyword.toLowerCase().contains(lowerQuery) ||
          translated.contains(lowerQuery);
    });
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

  String get fontStyleLabel {
    return fontStyleLabelFor(context, widget.state.preferences.fontStyle);
  }

  String get themeColorLabel {
    final selected = themeColorOptions.firstWhere(
      (option) =>
          option.color.toARGB32() == widget.state.preferences.themeColorValue,
      orElse: () => themeColorOptions.first,
    );
    return context.strings.text(selected.label);
  }

  String get conversationSortLabel {
    final strings = context.strings;
    switch (widget.state.preferences.conversationSortMode) {
      case ConversationSortMode.latest:
        return strings.text('Latest message');
      case ConversationSortMode.type:
        return strings.text('Conversation type');
    }
  }

  String get messageTimeFormatLabel {
    return messageTimeFormatLabelFor(
      context,
      widget.state.preferences.messageTimeFormat,
    );
  }

  String get chatBubbleCornerStyleLabel {
    return chatBubbleCornerStyleLabelFor(
      context,
      widget.state.preferences.chatBubbleCornerStyle,
    );
  }

  String chatBubbleColorLabel(int colorValue) {
    if (colorValue == defaultChatBubbleColorValue) {
      return context.strings.text('Follow theme');
    }
    final selected = chatBubbleColorOptions.firstWhere(
      (option) => option.color.toARGB32() == colorValue,
      orElse: () => _ThemeColorOption('Custom', Color(colorValue)),
    );
    return context.strings.text(selected.label);
  }

  String get chatBubbleOpacityLabel {
    final percent = (widget.state.preferences.chatBubbleOpacity * 100).round();
    return '$percent%';
  }

  String get chatBackgroundLabel {
    return widget.state.preferences.chatBackgroundPath.trim().isEmpty
        ? context.strings.text('Default background')
        : context.strings.text('Custom background');
  }

  String formatCacheBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    const units = <String>['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit += 1;
    }
    final decimals = value >= 10 || unit == 0 ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${units[unit]}';
  }

  List<_CacheMetric> performanceMetrics(PerformanceCacheStats stats) {
    final strings = context.strings;
    return [
      _CacheMetric(
        icon: Icons.forum_outlined,
        label: strings.text('Message cache'),
        value: formatCacheBytes(stats.messageCacheBytes),
        detail: strings.format(
          '{messages} messages, {conversations} conversations',
          {
            'messages': stats.messageCount,
            'conversations': stats.conversationCount,
          },
        ),
      ),
      _CacheMetric(
        icon: Icons.image_outlined,
        label: strings.text('Image cache'),
        value: formatCacheBytes(stats.imageCacheBytes),
        detail: strings.format('{count} cached image entries', {
          'count': stats.imageCacheEntries,
        }),
      ),
      _CacheMetric(
        icon: Icons.article_outlined,
        label: strings.text('Log files'),
        value: formatCacheBytes(stats.logBytes),
        detail: strings.text('Local diagnostic files'),
      ),
    ];
  }

  Future<void> loadPerformanceStats({bool showError = false}) async {
    if (!mounted || loadingPerformanceStats) {
      return;
    }
    setState(() => loadingPerformanceStats = true);
    try {
      final stats = await widget.state.loadPerformanceCacheStats();
      if (mounted) {
        setState(() => performanceStats = stats);
      }
    } catch (err) {
      if (!mounted || !showError) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.format('Load cache stats failed: {error}', {
              'error': err,
            }),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => loadingPerformanceStats = false);
      }
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
      await loadPerformanceStats();
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

  Future<void> clearPerformanceCaches() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.strings.text('Clear performance caches?')),
        content: Text(
          context.strings.text(
            'Message cache, image cache and log files will be removed. Your login session will be kept.',
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
    setState(() => clearingPerformanceCaches = true);
    try {
      await widget.state.clearPerformanceCaches();
      await loadPerformanceStats();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.strings.text('Performance caches cleared.')),
        ),
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
        setState(() => clearingPerformanceCaches = false);
      }
    }
  }

  Future<void> enableLowPerformanceMode() async {
    setState(() => enablingLowPerformanceMode = true);
    try {
      await widget.state.enableLowPerformanceMode();
      await loadPerformanceStats();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.strings.text('Low performance mode enabled.')),
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
        setState(() => enablingLowPerformanceMode = false);
      }
    }
  }

  Future<void> submitBugReport() async {
    final result = await showDialog<_BugReportDraft>(
      context: context,
      builder: (context) => const _BugReportDialog(),
    );
    if (result == null || !mounted) {
      return;
    }
    if (result.title.trim().isEmpty || result.description.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.text('Title and description are required.'),
          ),
        ),
      );
      return;
    }
    setState(() => submittingBugReport = true);
    try {
      await widget.state.submitBugReport(
        title: result.title,
        description: result.description,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Feedback submitted.'))),
      );
    } catch (err) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.format('Submit failed: {error}', {'error': err}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => submittingBugReport = false);
      }
    }
  }

  Future<void> checkVersionUpdateManually() async {
    if (checkingVersionUpdate) {
      return;
    }
    setState(() => checkingVersionUpdate = true);
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final checker = VersionUpdateChecker();
      VersionUpdateInfo result;
      try {
        result = await checker.check(
          currentVersion: VersionUpdateChecker.displayVersion(
            '${packageInfo.version}+${packageInfo.buildNumber}',
          ),
          timeout: const Duration(seconds: 8),
        );
      } finally {
        checker.close();
      }
      if (!mounted) {
        return;
      }
      if (result.hasUpdate) {
        await showVersionUpdateDialog(context, result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.text('Already up to date.'))),
        );
      }
    } catch (err, stackTrace) {
      if (kDebugMode) {
        debugPrint('CsAC manual GitHub update check failed: $err');
        debugPrintStack(stackTrace: stackTrace);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.strings.format('Check update failed: {error}', {
                'error': err,
              }),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => checkingVersionUpdate = false);
      }
    }
  }

  Future<void> logoutToLogin() async {
    await confirmLogout(context, widget.state);
  }

  Future<String?> promptPin({
    required String title,
    required String label,
    bool confirm = false,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) =>
          _PinPromptDialog(title: title, label: label, confirm: confirm),
    );
  }

  Future<bool> confirmCurrentAppLockPin() async {
    final pin = await promptPin(
      title: 'Enter current PIN',
      label: 'Current PIN',
    );
    if (pin == null) {
      return false;
    }
    if (widget.state.verifyAppLockPin(pin)) {
      return true;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Incorrect PIN.'))),
      );
    }
    return false;
  }

  Future<void> enableAppLock() async {
    final pin = await promptPin(
      title: 'Set app lock PIN',
      label: 'PIN',
      confirm: true,
    );
    if (pin == null || !mounted) {
      return;
    }
    await widget.state.enableAppLock(pin: pin, biometricEnabled: false);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('App lock enabled.'))),
      );
    }
  }

  Future<void> changeAppLockPin() async {
    if (!await confirmCurrentAppLockPin() || !mounted) {
      return;
    }
    final pin = await promptPin(
      title: 'Change app lock PIN',
      label: 'New PIN',
      confirm: true,
    );
    if (pin == null || !mounted) {
      return;
    }
    await widget.state.enableAppLock(
      pin: pin,
      biometricEnabled: widget.state.preferences.appLockBiometricEnabled,
    );
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('PIN updated.'))),
      );
    }
  }

  Future<void> disableAppLock() async {
    if (!await confirmCurrentAppLockPin() || !mounted) {
      return;
    }
    await widget.state.disableAppLock();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('App lock disabled.'))),
      );
    }
  }

  Future<void> openAppLockSettings() async {
    if (!widget.state.preferences.effectiveAppLockEnabled) {
      await enableAppLock();
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: _RoundedInkClip(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (supportsLocalAuth) ...[
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: Text(context.strings.text('Biometric unlock')),
                  subtitle: Text(
                    context.strings.text(
                      'Use device biometrics when available',
                    ),
                  ),
                  value: widget.state.preferences.appLockBiometricEnabled,
                  onChanged: (value) => Navigator.of(
                    context,
                  ).pop(value ? 'biometricOn' : 'biometricOff'),
                ),
                const Divider(height: 1),
              ],
              ListTile(
                leading: const Icon(Icons.pin_outlined),
                title: Text(context.strings.text('Change PIN')),
                onTap: () => Navigator.of(context).pop('changePin'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock_open_outlined),
                title: Text(context.strings.text('Disable app lock')),
                onTap: () => Navigator.of(context).pop('disable'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case 'biometricOn':
      case 'biometricOff':
        await widget.state.updateAppLockBiometric(action == 'biometricOn');
        if (mounted) {
          setState(() {});
        }
        break;
      case 'changePin':
        await changeAppLockPin();
        break;
      case 'disable':
        await disableAppLock();
        break;
    }
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
        child: _RoundedInkClip(
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
      ),
    );
    if (selected != null) {
      await widget.state.updateThemeMode(selected);
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> chooseThemeColor() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: _RoundedInkClip(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.strings.text('Theme color'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final option in themeColorOptions)
                        _ThemeColorButton(
                          option: option,
                          selected:
                              option.color.toARGB32() ==
                              widget.state.preferences.themeColorValue,
                          onTap: () => Navigator.of(
                            context,
                          ).pop(option.color.toARGB32()),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (selected != null) {
      await widget.state.updateThemeColor(selected);
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
        child: _RoundedInkClip(
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
      ),
    );
    if (selected != null) {
      await widget.state.updateLanguage(selected);
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> chooseFontStyle() async {
    final selected = await showModalBottomSheet<CsacFontStyle>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: _RoundedInkClip(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final style in CsacFontStyle.values)
                ListTile(
                  leading: widget.state.preferences.fontStyle == style
                      ? const Icon(Icons.check)
                      : const SizedBox(width: 24),
                  title: Text(
                    fontStyleLabelFor(context, style),
                    style: TextStyle(
                      fontFamily: fontFamilyForStyle(style),
                      fontFamilyFallback: fontFamilyFallbackForStyle(style),
                    ),
                  ),
                  subtitle: Text(
                    fontStyleDescriptionFor(context, style),
                    style: TextStyle(
                      fontFamily: fontFamilyForStyle(style),
                      fontFamilyFallback: fontFamilyFallbackForStyle(style),
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(style),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      await widget.state.updateFontStyle(selected);
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> chooseConversationSortMode() async {
    final selected = await showModalBottomSheet<ConversationSortMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: _RoundedInkClip(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading:
                    widget.state.preferences.conversationSortMode ==
                        ConversationSortMode.latest
                    ? const Icon(Icons.check)
                    : const SizedBox(width: 24),
                title: Text(context.strings.text('Latest message')),
                subtitle: Text(
                  context.strings.text('Show chats with recent activity first'),
                ),
                onTap: () =>
                    Navigator.of(context).pop(ConversationSortMode.latest),
              ),
              ListTile(
                leading:
                    widget.state.preferences.conversationSortMode ==
                        ConversationSortMode.type
                    ? const Icon(Icons.check)
                    : const SizedBox(width: 24),
                title: Text(context.strings.text('Conversation type')),
                subtitle: Text(
                  context.strings.text('Group friends and groups separately'),
                ),
                onTap: () =>
                    Navigator.of(context).pop(ConversationSortMode.type),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      await widget.state.updateConversationSortMode(selected);
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> chooseMessageTimeFormat() async {
    final selected = await showModalBottomSheet<MessageTimeFormat>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: _RoundedInkClip(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final format in MessageTimeFormat.values)
                ListTile(
                  leading: widget.state.preferences.messageTimeFormat == format
                      ? const Icon(Icons.check)
                      : const SizedBox(width: 24),
                  title: Text(messageTimeFormatLabelFor(context, format)),
                  subtitle: Text(messageTimeFormatExampleFor(format)),
                  onTap: () => Navigator.of(context).pop(format),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      await widget.state.updateMessageTimeFormat(selected);
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> chooseChatBubbleCornerStyle() async {
    final selected = await showModalBottomSheet<ChatBubbleCornerStyle>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: _RoundedInkClip(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final style in ChatBubbleCornerStyle.values)
                ListTile(
                  leading:
                      widget.state.preferences.chatBubbleCornerStyle == style
                      ? const Icon(Icons.check)
                      : const SizedBox(width: 24),
                  title: Text(chatBubbleCornerStyleLabelFor(context, style)),
                  onTap: () => Navigator.of(context).pop(style),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      await widget.state.updateChatBubbleCornerStyle(selected);
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> chooseChatBubbleColor({required bool mine}) async {
    final title = mine ? 'Own bubble color' : 'Other bubble color';
    final current = mine
        ? widget.state.preferences.ownChatBubbleColorValue
        : widget.state.preferences.otherChatBubbleColorValue;
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: _RoundedInkClip(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.strings.text(title),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _FollowThemeColorButton(
                        selected: current == defaultChatBubbleColorValue,
                        onTap: () => Navigator.of(
                          context,
                        ).pop(defaultChatBubbleColorValue),
                      ),
                      for (final option in chatBubbleColorOptions)
                        _ThemeColorButton(
                          option: option,
                          selected: option.color.toARGB32() == current,
                          onTap: () => Navigator.of(
                            context,
                          ).pop(option.color.toARGB32()),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (selected != null) {
      if (mine) {
        await widget.state.updateOwnChatBubbleColor(selected);
      } else {
        await widget.state.updateOtherChatBubbleColor(selected);
      }
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> updateChatBubbleOpacity(double value) async {
    await widget.state.updateChatBubbleOpacity(value);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> chooseChatBackground() async {
    if (isWebPlatform) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.text(
              'Chat background files are not supported on Web.',
            ),
          ),
        ),
      );
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: _RoundedInkClip(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(context.strings.text('Choose background image')),
                onTap: () => Navigator.of(context).pop('choose'),
              ),
              if (widget.state.preferences.chatBackgroundPath.trim().isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(context.strings.text('Reset background')),
                  onTap: () => Navigator.of(context).pop('reset'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == 'reset') {
      await widget.state.updateChatBackgroundPath('');
      if (mounted) {
        setState(() {});
      }
      return;
    }
    final picked = await openFile(
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(
          label: context.strings.text('Images'),
          extensions: imageExtensions,
        ),
      ],
    );
    if (!mounted || picked == null) {
      return;
    }
    try {
      final path = await persistChatBackground(picked);
      await widget.state.updateChatBackgroundPath(path);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.strings.text('Chat background saved.')),
          ),
        );
      }
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
    }
  }

  void openSettingsCategory(_SettingsCategory category) {
    settingsSearch.clear();
    Navigator.of(context).push(
      CsacPageRoute<void>(
        builder: (_) => SettingsScreen(
          state: widget.state,
          initialCategoryIndex: category.index,
          initialDeveloperOptionsExpanded:
              category == _SettingsCategory.developer,
        ),
      ),
    );
  }

  String settingsCategoryTitle(_SettingsCategory category) {
    final strings = context.strings;
    return switch (category) {
      _SettingsCategory.account => strings.text('Account and session'),
      _SettingsCategory.appearance => strings.text('Appearance and chat'),
      _SettingsCategory.data => strings.text('Data and notifications'),
      _SettingsCategory.security => strings.text('Privacy and security'),
      _SettingsCategory.about => strings.text('About and feedback'),
      _SettingsCategory.developer => strings.text('Developer tools'),
    };
  }

  String settingsCategorySubtitle(_SettingsCategory category) {
    final strings = context.strings;
    return switch (category) {
      _SettingsCategory.account => strings.text(
        'Profile, account details and sign out',
      ),
      _SettingsCategory.appearance => strings.text(
        'Theme, typography, bubbles and chat behavior',
      ),
      _SettingsCategory.data => strings.text(
        'Cache, diagnostics, refresh and local alerts',
      ),
      _SettingsCategory.security => strings.text('PIN lock and device unlock'),
      _SettingsCategory.about => strings.text(
        'Version, licenses, updates and feedback',
      ),
      _SettingsCategory.developer => strings.text(
        'Server address and API explorer',
      ),
    };
  }

  IconData settingsCategoryIcon(_SettingsCategory category) {
    return switch (category) {
      _SettingsCategory.account => Icons.person_outline,
      _SettingsCategory.appearance => Icons.palette_outlined,
      _SettingsCategory.data => Icons.speed_outlined,
      _SettingsCategory.security => Icons.lock_outline,
      _SettingsCategory.about => Icons.info_outline,
      _SettingsCategory.developer => Icons.developer_mode_outlined,
    };
  }

  Widget settingsCategoryIndex() {
    final categories = _SettingsCategory.values;
    return Card(
      elevation: 0,
      child: _RoundedInkClip(
        child: Column(
          children: [
            for (final entry in categories.indexed) ...[
              ListTile(
                leading: Icon(settingsCategoryIcon(entry.$2)),
                title: Text(settingsCategoryTitle(entry.$2)),
                subtitle: Text(settingsCategorySubtitle(entry.$2)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openSettingsCategory(entry.$2),
              ),
              if (entry.$1 != categories.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.state.user;
    final strings = context.strings;
    final query = settingsSearch.text.trim().toLowerCase();
    final category = query.isEmpty ? activeCategory : null;
    final showCategoryIndex = query.isEmpty && category == null;
    final showAccount = category != null
        ? category == _SettingsCategory.account
        : !showCategoryIndex &&
              settingMatches(query, [
                'Account settings',
                'Username',
                'Nickname',
                'Avatar',
                'UID',
                'Profile',
              ]);
    final showInfo = category != null
        ? category == _SettingsCategory.about
        : !showCategoryIndex &&
              settingMatches(query, [
                'App information',
                'Open-source licenses',
                'Version',
                'Version updates',
                'Check for updates',
                'Automatic update checks',
                'Release notes',
                'Source code',
                'License',
              ]);
    final showFeedback = category != null
        ? category == _SettingsCategory.about
        : !showCategoryIndex &&
              settingMatches(query, [
                'Feedback',
                'Report a problem',
                'Bug report',
                'Problem',
                'Submit feedback',
              ]);
    final showAppearance = category != null
        ? category == _SettingsCategory.appearance
        : !showCategoryIndex &&
              settingMatches(query, [
                'Theme',
                'Theme color',
                'Language',
                'Font style',
                'Font',
                'Typography',
                'Conversation sorting',
                'Message time format',
                'Chat bubble theme',
                'Own bubble color',
                'Other bubble color',
                'Bubble corner style',
                'Bubble opacity',
                'Chat background',
                'Background',
                'Show chat avatars',
                'Avatar',
                'Double tap avatar pat',
                'Pat',
                'Group member level',
                'Level',
                'Reduce motion',
                'Animation',
                'Motion',
              ]);
    final showLock = category != null
        ? category == _SettingsCategory.security
        : !showCategoryIndex &&
              settingMatches(query, ['App lock', 'PIN', 'Security']);
    final showData = category != null
        ? category == _SettingsCategory.data
        : !showCategoryIndex &&
              settingMatches(query, [
                'Refresh app data',
                'Connection diagnostics',
                'Network diagnostics',
                'Server latency',
                'API availability',
                'Login status',
                'Image domain',
                'Clear local cache',
                'Performance and cache',
                'Message cache',
                'Image cache',
                'Log files',
                'App logs',
                'View app logs',
                'Diagnostics',
                'System notifications',
                'Local notifications',
                'New message alerts',
                'Low performance mode',
                'Cache',
                'Cached conversations and message history',
              ]);
    final showDeveloper = category != null
        ? category == _SettingsCategory.developer
        : !showCategoryIndex &&
              settingMatches(query, [
                'Developer options',
                'CsAC server address',
                'API explorer',
                'API documentation',
                'Run online',
                'Endpoint',
                'Route',
                'Server',
                'Default server',
              ]);
    final showLogout = category != null
        ? category == _SettingsCategory.account
        : !showCategoryIndex &&
              settingMatches(query, [
                'Logout',
                'Clear session and return to login',
                'Session',
              ]);
    final hasMatches =
        showAccount ||
        showInfo ||
        showFeedback ||
        showAppearance ||
        showLock ||
        showData ||
        showDeveloper ||
        showLogout;
    final colors = CsacColors.of(context);
    final title = category == null
        ? strings.text('Settings')
        : settingsCategoryTitle(category);
    final connectionProtocol = widget.state.connectionProtocol.trim();
    final connectionProtocolLabel = connectionProtocol.isEmpty
        ? strings.text('Unknown')
        : connectionProtocol;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      backgroundColor: colors.systemBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final settingsList = SingleChildScrollView(
              controller: settingsScroll,
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: settingsSearch,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: strings.text('Search settings'),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: strings.text('Clear'),
                                onPressed: settingsSearch.clear,
                                icon: const Icon(Icons.close),
                              ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (showCategoryIndex) ...[
                      settingsCategoryIndex(),
                      const SizedBox(height: 12),
                    ],
                    if (showAccount) ...[
                      Card(
                        elevation: 0,
                        child: _RoundedInkClip(
                          child: ListTile(
                            leading: _Avatar(
                              url: user?.avatar ?? '',
                              fallback: Icons.person_rounded,
                              name: user?.nickname ?? '',
                            ),
                            title: Text(
                              user?.nickname ?? strings.text('Not logged in'),
                            ),
                            subtitle: Text(
                              [
                                if (user?.username.isNotEmpty == true)
                                  '@${user!.username}',
                                if (user != null) 'UID ${user.uid}',
                              ].join(' | '),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: user == null
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      CsacPageRoute<void>(
                                        builder: (_) => AccountSettingsScreen(
                                          state: widget.state,
                                        ),
                                      ),
                                    );
                                  },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showInfo) ...[
                      Card(
                        elevation: 0,
                        child: _RoundedInkClip(
                          child: Column(
                            children: [
                              ListTile(
                                leading: const _AppIconImage(
                                  size: 28,
                                  borderRadius: 7,
                                ),
                                title: Text(strings.text('App information')),
                                subtitle: const _AppInfoSubtitle(),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.of(context).push(
                                    CsacPageRoute<void>(
                                      builder: (_) =>
                                          AppInfoScreen(state: widget.state),
                                    ),
                                  );
                                },
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                secondary: const Icon(
                                  Icons.event_repeat_outlined,
                                ),
                                title: Text(
                                  strings.text('Automatic update checks'),
                                ),
                                subtitle: Text(
                                  strings.text(
                                    'Silently check GitHub Releases once on startup',
                                  ),
                                ),
                                value: widget
                                    .state
                                    .preferences
                                    .autoCheckVersionUpdates,
                                onChanged:
                                    widget.state.updateAutoCheckVersionUpdates,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.update),
                                title: Text(strings.text('Check for updates')),
                                subtitle: Text(
                                  strings.text(
                                    'Check the latest GitHub Release manually',
                                  ),
                                ),
                                trailing: checkingVersionUpdate
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.chevron_right),
                                onTap: checkingVersionUpdate
                                    ? null
                                    : checkVersionUpdateManually,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.article_outlined),
                                title: Text(
                                  strings.text('Open-source licenses'),
                                ),
                                subtitle: Text(
                                  strings.text(
                                    'View licenses for included libraries',
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.of(context).push(
                                    CsacPageRoute<void>(
                                      builder: (_) =>
                                          const OpenSourceLicensesScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showFeedback) ...[
                      Card(
                        elevation: 0,
                        child: _RoundedInkClip(
                          child: ListTile(
                            leading: const Icon(Icons.feedback_outlined),
                            title: Text(strings.text('Report a problem')),
                            subtitle: Text(
                              strings.text(
                                'Send app feedback to administrators',
                              ),
                            ),
                            trailing: submittingBugReport
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.chevron_right),
                            onTap: submittingBugReport ? null : submitBugReport,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showAppearance) ...[
                      Card(
                        elevation: 0,
                        child: _RoundedInkClip(
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
                                leading: const Icon(Icons.palette_outlined),
                                title: Text(strings.text('Theme color')),
                                subtitle: Text(themeColorLabel),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _ThemeColorDot(
                                      color: Color(
                                        widget
                                            .state
                                            .preferences
                                            .themeColorValue,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.chevron_right),
                                  ],
                                ),
                                onTap: chooseThemeColor,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.translate),
                                title: Text(strings.text('Language')),
                                subtitle: Text(languageLabel),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: chooseLanguage,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.text_fields),
                                title: Text(strings.text('Font style')),
                                subtitle: Text(fontStyleLabel),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: chooseFontStyle,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.sort),
                                title: Text(
                                  strings.text('Conversation sorting'),
                                ),
                                subtitle: Text(conversationSortLabel),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: chooseConversationSortMode,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.schedule_outlined),
                                title: Text(
                                  strings.text('Message time format'),
                                ),
                                subtitle: Text(messageTimeFormatLabel),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: chooseMessageTimeFormat,
                              ),
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  12,
                                ),
                                child: _ChatBubbleThemePreview(
                                  preferences: widget.state.preferences,
                                ),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.chat_bubble_outline),
                                title: Text(strings.text('Own bubble color')),
                                subtitle: Text(
                                  chatBubbleColorLabel(
                                    widget
                                        .state
                                        .preferences
                                        .ownChatBubbleColorValue,
                                  ),
                                ),
                                trailing: _ChatBubbleColorTrailing(
                                  colorValue: widget
                                      .state
                                      .preferences
                                      .ownChatBubbleColorValue,
                                  fallback: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                ),
                                onTap: () => chooseChatBubbleColor(mine: true),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.chat_bubble_outline),
                                title: Text(strings.text('Other bubble color')),
                                subtitle: Text(
                                  chatBubbleColorLabel(
                                    widget
                                        .state
                                        .preferences
                                        .otherChatBubbleColorValue,
                                  ),
                                ),
                                trailing: _ChatBubbleColorTrailing(
                                  colorValue: widget
                                      .state
                                      .preferences
                                      .otherChatBubbleColorValue,
                                  fallback: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                ),
                                onTap: () => chooseChatBubbleColor(mine: false),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.rounded_corner),
                                title: Text(
                                  strings.text('Bubble corner style'),
                                ),
                                subtitle: Text(chatBubbleCornerStyleLabel),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: chooseChatBubbleCornerStyle,
                              ),
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.opacity),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(strings.text('Bubble opacity')),
                                          Text(
                                            chatBubbleOpacityLabel,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                          CupertinoSlider(
                                            value: widget
                                                .state
                                                .preferences
                                                .chatBubbleOpacity,
                                            min: 0.45,
                                            max: 1,
                                            divisions: 11,
                                            onChanged: updateChatBubbleOpacity,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.wallpaper_outlined),
                                title: Text(strings.text('Chat background')),
                                subtitle: Text(chatBackgroundLabel),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: chooseChatBackground,
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                secondary: const Icon(
                                  Icons.account_circle_outlined,
                                ),
                                title: Text(strings.text('Show chat avatars')),
                                subtitle: Text(
                                  strings.text(
                                    'Display sender avatars beside message bubbles',
                                  ),
                                ),
                                value: widget.state.preferences.showChatAvatars,
                                onChanged: widget.state.updateShowChatAvatars,
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                secondary: const Icon(
                                  Icons.waving_hand_outlined,
                                ),
                                title: Text(
                                  strings.text('Double tap avatar pat'),
                                ),
                                subtitle: Text(
                                  strings.text(
                                    'Double tap a group member avatar to send a pat',
                                  ),
                                ),
                                value: widget.state.preferences.enablePat,
                                onChanged: widget.state.updateEnablePat,
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                secondary: const Icon(
                                  Icons.military_tech_outlined,
                                ),
                                title: Text(
                                  strings.text('Show group member level'),
                                ),
                                subtitle: Text(
                                  strings.text(
                                    'Display member level beside names in group chats',
                                  ),
                                ),
                                value: widget
                                    .state
                                    .preferences
                                    .showGroupMemberLevel,
                                onChanged:
                                    widget.state.updateShowGroupMemberLevel,
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                secondary: const Icon(
                                  Icons.motion_photos_off_outlined,
                                ),
                                title: Text(strings.text('Reduce motion')),
                                subtitle: Text(
                                  strings.text(
                                    'Use simpler transitions and fewer decorative animations',
                                  ),
                                ),
                                value: widget.state.preferences.reduceMotion,
                                onChanged: widget.state.updateReduceMotion,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showLock) ...[
                      Card(
                        elevation: 0,
                        child: _RoundedInkClip(
                          child: ListTile(
                            leading: const Icon(Icons.lock_outline),
                            title: Text(strings.text('App lock')),
                            subtitle: Text(
                              widget.state.preferences.effectiveAppLockEnabled
                                  ? strings.text(
                                      'PIN required when returning to CsAC',
                                    )
                                  : strings.text('Off'),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: openAppLockSettings,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showData) ...[
                      Card(
                        elevation: 0,
                        child: _RoundedInkClip(
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  12,
                                  10,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.speed_outlined,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            strings.text(
                                              'Performance and cache',
                                            ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            performanceStats == null
                                                ? strings.text(
                                                    'Measure local storage and memory cache',
                                                  )
                                                : strings.format(
                                                    'Total cache: {size}',
                                                    {
                                                      'size': formatCacheBytes(
                                                        performanceStats!
                                                            .totalBytes,
                                                      ),
                                                    },
                                                  ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: strings.text('Refresh'),
                                      onPressed: loadingPerformanceStats
                                          ? null
                                          : () => loadPerformanceStats(
                                              showError: true,
                                            ),
                                      icon: loadingPerformanceStats
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.refresh),
                                    ),
                                  ],
                                ),
                              ),
                              if (performanceStats == null)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    12,
                                  ),
                                  child: LinearProgressIndicator(
                                    minHeight: 2,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    12,
                                  ),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final metric in performanceMetrics(
                                        performanceStats!,
                                      ))
                                        _CacheMetricTile(metric: metric),
                                    ],
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  14,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: enablingLowPerformanceMode
                                          ? null
                                          : enableLowPerformanceMode,
                                      icon: enablingLowPerformanceMode
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.battery_saver_outlined,
                                            ),
                                      label: Text(
                                        strings.text('Low performance mode'),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    FilledButton.icon(
                                      onPressed: clearingPerformanceCaches
                                          ? null
                                          : clearPerformanceCaches,
                                      icon: clearingPerformanceCaches
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.auto_delete_outlined,
                                            ),
                                      label: Text(
                                        strings.text(
                                          'Clear performance caches',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.sync),
                                title: Text(strings.text('Refresh app data')),
                                subtitle: Text(
                                  strings.text(
                                    'Reload conversations and counters',
                                  ),
                                ),
                                trailing: refreshing
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.chevron_right),
                                onTap: refreshing ? null : refreshAll,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(
                                  Icons.network_check_outlined,
                                ),
                                title: Text(
                                  strings.text('Connection protocol'),
                                ),
                                subtitle: Text(
                                  strings.text('Current HTTP protocol'),
                                ),
                                trailing: Text(connectionProtocolLabel),
                              ),
                              const Divider(height: 1),
                              SwitchListTile(
                                secondary: const Icon(
                                  Icons.notifications_active_outlined,
                                ),
                                title: Text(
                                  strings.text('System notifications'),
                                ),
                                subtitle: Text(
                                  strings.text(
                                    'Show local system alerts for new messages',
                                  ),
                                ),
                                value: widget
                                    .state
                                    .preferences
                                    .localSystemNotificationsEnabled,
                                onChanged:
                                    widget.state.updateLocalSystemNotifications,
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(
                                  Icons.network_check_outlined,
                                ),
                                title: Text(
                                  strings.text('Connection diagnostics'),
                                ),
                                subtitle: Text(
                                  strings.text(
                                    'Test server latency, API, login and image domain',
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.of(context).push(
                                    CsacPageRoute<void>(
                                      builder: (_) => NetworkDiagnosticsScreen(
                                        state: widget.state,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.article_outlined),
                                title: Text(strings.text('App logs')),
                                subtitle: Text(
                                  strings.text('View local diagnostic logs'),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.of(context).push(
                                    CsacPageRoute<void>(
                                      builder: (_) =>
                                          AppLogsScreen(state: widget.state),
                                    ),
                                  );
                                },
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(
                                  Icons.cleaning_services_outlined,
                                ),
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
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.chevron_right),
                                onTap: clearing ? null : clearCache,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showDeveloper) ...[
                      Card(
                        elevation: 0,
                        child: _RoundedInkClip(
                          child: _CupertinoExpansionTile(
                            initiallyExpanded: developerOptionsExpanded,
                            onExpansionChanged: (value) {
                              setState(() => developerOptionsExpanded = value);
                            },
                            leading: const Icon(Icons.developer_mode_outlined),
                            title: Text(strings.text('Developer options')),
                            subtitle: Text(
                              strings.format('Current server: {server}', {
                                'server':
                                    widget.state.preferences.serverUrl
                                        .trim()
                                        .isEmpty
                                    ? strings.text('Default server')
                                    : widget.state.preferences.serverUrl.trim(),
                              }),
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              16,
                            ),
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
                                  labelText: strings.text(
                                    'CsAC server address',
                                  ),
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
                                    onPressed: savingServer
                                        ? null
                                        : resetServerUrl,
                                    icon: const Icon(Icons.restart_alt),
                                    label: Text(
                                      strings.text('Reset to default'),
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: savingServer
                                        ? null
                                        : saveServerUrl,
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
                              const SizedBox(height: 12),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.api_outlined),
                                title: Text(strings.text('API explorer')),
                                subtitle: Text(
                                  strings.text(
                                    'Search API docs, inspect parameters and run requests',
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.of(context).push(
                                    CsacPageRoute<void>(
                                      builder: (_) => ApiExplorerScreen(
                                        state: widget.state,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (showLogout) ...[
                      Card(
                        elevation: 0,
                        child: _RoundedInkClip(
                          child: ListTile(
                            leading: const Icon(Icons.logout),
                            title: Text(strings.text('Logout')),
                            subtitle: Text(
                              strings.text('Clear session and return to login'),
                            ),
                            onTap: logoutToLogin,
                          ),
                        ),
                      ),
                    ],
                    if (!showCategoryIndex && !hasMatches)
                      _EmptyPanel(
                        message: strings.text('No matching settings.'),
                      ),
                  ],
                ),
              ),
            );
            if (constraints.maxWidth < 700) {
              return settingsList;
            }
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 720,
                height: constraints.maxHeight,
                child: settingsList,
              ),
            );
          },
        ),
      ),
    );
  }
}
