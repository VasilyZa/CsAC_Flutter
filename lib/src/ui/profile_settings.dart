part of '../../main.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.state});

  final CsacAppState state;

  Future<void> _logout(BuildContext context) async {
    await state.logout();
    if (context.mounted) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = state.notificationCounts;
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return CupertinoPageScaffold(
      backgroundColor: colors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(strings.text('Me')),
        backgroundColor: colors.navBarBackground,
        border: null,
      ),
      child: SafeArea(
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
                          alpha: 0.4,
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
                            style: TextStyle(fontSize: 14, color: colors.label),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minSize: 0,
                          onPressed: () => _logout(context),
                          child: Text(strings.text('Login')),
                        ),
                      ],
                    ),
                  ),
                ),
              _ProfileHeroCard(state: state),
              const SizedBox(height: 12),
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.bell, size: 22),
                    title: strings.text('Unread notices'),
                    trailing: _badgeCount(counts.notices, colors),
                  ),
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.person_add, size: 22),
                    title: strings.text('Friend requests'),
                    trailing: _badgeCount(counts.friendRequests, colors),
                  ),
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.group, size: 22),
                    title: strings.text('Group reviews'),
                    trailing: _badgeCount(counts.groupApplications, colors),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  _CupertinoListTile(
                    leading: const Icon(
                      CupertinoIcons.arrow_2_circlepath,
                      size: 22,
                    ),
                    title: strings.text('Refresh all'),
                    onTap: state.refreshHome,
                  ),
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.settings, size: 22),
                    title: strings.text('Settings'),
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => SettingsScreen(state: state),
                        ),
                      );
                    },
                  ),
                  _CupertinoListTile(
                    leading: const Icon(
                      CupertinoIcons.square_arrow_left,
                      size: 22,
                    ),
                    title: strings.text('Logout'),
                    titleColor: colors.destructive,
                    onTap: () => _logout(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _badgeCount(int count, CsacColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: count > 0
            ? CupertinoColors.systemRed
            : colors.elevatedBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: count > 0 ? CupertinoColors.white : colors.secondaryLabel,
        ),
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.state});

  final CsacAppState state;

  @override
  Widget build(BuildContext context) {
    final user = state.user;
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: user == null
          ? null
          : () {
              Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => AccountSettingsScreen(state: state),
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colors.separator.withValues(alpha: 0.28),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(
                alpha: colors.isDark ? 0.18 : 0.06,
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
              size: 64,
              name: user?.nickname ?? user?.username ?? '',
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.nickname ?? strings.text('Not logged in'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: colors.label,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (user?.username.isNotEmpty == true)
                        '@${user!.username}',
                      if (user != null) 'UID ${user.uid}',
                      if (user?.onlineStatus.isNotEmpty == true)
                        user!.onlineStatus,
                    ].join(' | '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.secondaryLabel,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            if (user != null)
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

  Future<void> editNickname() async {
    final current = widget.state.user?.nickname ?? '';
    final controller = TextEditingController(text: current);
    final strings = context.strings;
    final nickname = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(strings.text('Change nickname')),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            autofocus: true,
            maxLength: 16,
            textInputAction: TextInputAction.done,
            placeholder: strings.text('New nickname'),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.text('Cancel')),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(strings.text('Save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nickname == null || !mounted) return;
    final trimmed = nickname.trim();
    if (trimmed.isEmpty) {
      _showCupertinoToast(
        context,
        context.strings.text('Please enter a nickname.'),
      );
      return;
    }
    if (trimmed == current.trim()) return;
    setState(() => updatingNickname = true);
    try {
      await widget.state.updateNickname(trimmed);
      if (!mounted) return;
      _showCupertinoToast(context, context.strings.text('Nickname updated.'));
      setState(() {});
    } catch (err) {
      if (mounted) {
        _showCupertinoToast(
          context,
          context.strings.format('Update failed: {error}', {'error': err}),
        );
      }
    } finally {
      if (mounted) setState(() => updatingNickname = false);
    }
  }

  Future<void> changeAvatar() async {
    if (updatingAvatar) return;
    final picked = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => updatingAvatar = true);
    try {
      await widget.state.updateAvatar(bytes, picked.name);
      if (!mounted) return;
      _showCupertinoToast(context, context.strings.text('Avatar updated.'));
      setState(() {});
    } catch (err) {
      if (mounted) {
        _showCupertinoToast(
          context,
          context.strings.format('Update failed: {error}', {'error': err}),
        );
      }
    } finally {
      if (mounted) setState(() => updatingAvatar = false);
    }
  }

  Future<void> changePassword() async {
    final oldPassword = TextEditingController();
    final newPassword = TextEditingController();
    final confirmPassword = TextEditingController();
    final strings = context.strings;
    final result = await showCupertinoDialog<_PasswordChange>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(strings.text('Change password')),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: oldPassword,
                obscureText: true,
                textInputAction: TextInputAction.next,
                placeholder: strings.text('Old password'),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: newPassword,
                obscureText: true,
                textInputAction: TextInputAction.next,
                placeholder: strings.text('New password'),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: confirmPassword,
                obscureText: true,
                textInputAction: TextInputAction.done,
                placeholder: strings.text('Confirm password'),
                onSubmitted: (_) => Navigator.of(context).pop(
                  _PasswordChange(
                    oldPassword.text,
                    newPassword.text,
                    confirmPassword.text,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.text('Cancel')),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(
              _PasswordChange(
                oldPassword.text,
                newPassword.text,
                confirmPassword.text,
              ),
            ),
            child: Text(strings.text('Save')),
          ),
        ],
      ),
    );
    oldPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
    if (result == null || !mounted) return;
    if (result.oldPassword.isEmpty ||
        result.newPassword.isEmpty ||
        result.confirmPassword.isEmpty) {
      _showCupertinoToast(
        context,
        context.strings.text('Please fill all password fields.'),
      );
      return;
    }
    if (result.newPassword.length < 6) {
      _showCupertinoToast(
        context,
        context.strings.text('New password must be at least 6 characters.'),
      );
      return;
    }
    if (result.newPassword != result.confirmPassword) {
      _showCupertinoToast(
        context,
        context.strings.text('Passwords do not match.'),
      );
      return;
    }
    setState(() => updatingPassword = true);
    try {
      await widget.state.updatePassword(
        result.oldPassword,
        result.newPassword,
        result.confirmPassword,
      );
      if (!mounted) return;
      _showCupertinoToast(context, context.strings.text('Password updated.'));
    } catch (err) {
      if (mounted) {
        _showCupertinoToast(
          context,
          context.strings.format('Update failed: {error}', {'error': err}),
        );
      }
    } finally {
      if (mounted) setState(() => updatingPassword = false);
    }
  }

  Widget _progressOrChevron(bool loading, CsacColors colors) {
    if (!loading) {
      return Icon(
        CupertinoIcons.chevron_right,
        size: 16,
        color: colors.tertiaryLabel,
      );
    }
    return const CupertinoActivityIndicator(radius: 10);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.state.user;
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(strings.text('Account settings')),
      ),
      child: SafeArea(
        child: _AdaptivePageFrame(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        _Avatar(
                          url: user?.avatar ?? '',
                          fallback: CupertinoIcons.person_fill,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.nickname ?? strings.text('Not logged in'),
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: colors.label,
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
                                  fontSize: 14,
                                  color: colors.secondaryLabel,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  _CupertinoListTile(
                    leading: const Icon(
                      CupertinoIcons.person_crop_circle,
                      size: 22,
                    ),
                    title: strings.text('Change nickname'),
                    subtitle: user?.nickname ?? '',
                    trailing: _progressOrChevron(updatingNickname, colors),
                    onTap: updatingNickname ? null : editNickname,
                  ),
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.camera, size: 22),
                    title: strings.text('Change avatar'),
                    subtitle: strings.text('Choose a new profile image'),
                    trailing: _progressOrChevron(updatingAvatar, colors),
                    onTap: updatingAvatar ? null : changeAvatar,
                  ),
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.lock_rotation, size: 22),
                    title: strings.text('Change password'),
                    subtitle: strings.text('Update your login password'),
                    trailing: _progressOrChevron(updatingPassword, colors),
                    onTap: updatingPassword ? null : changePassword,
                  ),
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.shield, size: 22),
                    title: strings.text('Account security'),
                    subtitle: strings.text(
                      'Password upgrade and account deletion',
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) =>
                              AccountSecurityScreen(state: widget.state),
                        ),
                      );
                    },
                  ),
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.ant, size: 22),
                    title: strings.text('Feedback Bug'),
                    subtitle: strings.text('Send feedback to admins'),
                    onTap: () => showBugReportDialog(
                      context: context,
                      state: widget.state,
                    ),
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

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  bool upgrading = false;
  bool deleting = false;

  Future<void> upgradePassword() async {
    final oldPassword = TextEditingController();
    final newPassword = TextEditingController();
    final confirmPassword = TextEditingController();
    final strings = context.strings;
    final result = await showCupertinoDialog<_PasswordChange>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(strings.text('Upgrade password')),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CupertinoTextField(
                controller: oldPassword,
                obscureText: true,
                textInputAction: TextInputAction.next,
                placeholder: strings.text('Old password'),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: newPassword,
                obscureText: true,
                textInputAction: TextInputAction.next,
                placeholder: strings.text('New password'),
              ),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: confirmPassword,
                obscureText: true,
                placeholder: strings.text('Confirm password'),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.text('Cancel')),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(
              _PasswordChange(
                oldPassword.text,
                newPassword.text,
                confirmPassword.text,
              ),
            ),
            child: Text(strings.text('Save')),
          ),
        ],
      ),
    );
    oldPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
    if (result == null || !mounted) return;
    if (result.newPassword.isEmpty || result.confirmPassword.isEmpty) {
      _showCupertinoToast(
        context,
        context.strings.text('Please fill all password fields.'),
      );
      return;
    }
    if (result.newPassword.length < 6) {
      _showCupertinoToast(
        context,
        context.strings.text('New password must be at least 6 characters.'),
      );
      return;
    }
    if (result.newPassword != result.confirmPassword) {
      _showCupertinoToast(
        context,
        context.strings.text('Passwords do not match.'),
      );
      return;
    }
    setState(() => upgrading = true);
    try {
      await widget.state.upgradePassword(
        result.oldPassword,
        result.newPassword,
        result.confirmPassword,
      );
      if (mounted) {
        _showCupertinoToast(
          context,
          context.strings.text('Password upgraded.'),
        );
      }
    } catch (err) {
      if (mounted) {
        _showCupertinoToast(
          context,
          context.strings.format('Update failed: {error}', {'error': err}),
        );
      }
    } finally {
      if (mounted) setState(() => upgrading = false);
    }
  }

  Future<void> deleteAccount() async {
    final strings = context.strings;
    final first = await _showCupertinoConfirm(
      context,
      title: strings.text('Delete account?'),
      message: strings.text('Account deletion cannot be recovered.'),
      confirmText: 'Continue',
      isDestructive: true,
    );
    if (!first || !mounted) return;
    final confirm = TextEditingController();
    final second = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: Text(strings.text('Confirm account deletion')),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.text('Type DELETE to confirm permanent deletion.')),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: confirm,
                placeholder: strings.text('Confirmation text'),
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.text('Cancel')),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () =>
                Navigator.of(context).pop(confirm.text == 'DELETE'),
            child: Text(strings.text('Delete account')),
          ),
        ],
      ),
    );
    confirm.dispose();
    if (second != true || !mounted) {
      if (second == false && mounted) {
        _showCupertinoToast(
          context,
          context.strings.text('Confirmation text did not match.'),
        );
      }
      return;
    }
    setState(() => deleting = true);
    try {
      await widget.state.deleteAccount();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (err) {
      if (mounted) {
        setState(() => deleting = false);
        _showCupertinoToast(
          context,
          context.strings.format('Delete failed: {error}', {'error': err}),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(strings.text('Account security')),
      ),
      child: SafeArea(
        child: _AdaptivePageFrame(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.lock, size: 22),
                    title: strings.text('Upgrade password'),
                    subtitle: strings.text('Use the newer password API'),
                    trailing: upgrading
                        ? const CupertinoActivityIndicator(radius: 10)
                        : Icon(
                            CupertinoIcons.chevron_right,
                            size: 16,
                            color: colors.tertiaryLabel,
                          ),
                    onTap: upgrading || deleting ? null : upgradePassword,
                  ),
                  _CupertinoListTile(
                    leading: Icon(
                      CupertinoIcons.delete,
                      size: 22,
                      color: CupertinoColors.systemRed,
                    ),
                    title: strings.text('Delete account'),
                    titleColor: CupertinoColors.systemRed,
                    subtitle: strings.text(
                      'Permanently delete this account and local data',
                    ),
                    trailing: deleting
                        ? const CupertinoActivityIndicator(radius: 10)
                        : Icon(
                            CupertinoIcons.chevron_right,
                            size: 16,
                            color: colors.tertiaryLabel,
                          ),
                    onTap: upgrading || deleting ? null : deleteAccount,
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

class _ThemeColorOption {
  const _ThemeColorOption(this.label, this.color);

  final String label;
  final Color color;
}

class _ThemeColorDot extends StatelessWidget {
  const _ThemeColorDot({required this.color, this.selected = false});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? colors.primaryColor : colors.separator,
          width: selected ? 3 : 1,
        ),
      ),
      child: selected
          ? Icon(
              CupertinoIcons.checkmark,
              size: 14,
              color: _estimateBrightness(color) == Brightness.dark
                  ? CupertinoColors.white
                  : CupertinoColors.black,
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
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: _ThemeColorDot(color: option.color, selected: selected),
      ),
    );
  }
}

const _csacAppName = 'CsAC';
const _csacAppBranch = 'XiaoBai';
const _csacAppVersion = '1.1.6-37';
const _csacAppBuild = '37';
const _csacSourceUrl = 'https://github.com/VasilyZa/CsAC_Flutter';

Brightness _estimateBrightness(Color color) {
  final relativeLuminance =
      0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
  return relativeLuminance > 0.5 ? Brightness.light : Brightness.dark;
}

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  Future<void> copySourceUrl(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _csacSourceUrl));
    if (context.mounted) {
      _showCupertinoToast(context, context.strings.text('Source link copied.'));
    }
  }

  Future<void> openSourceUrl(BuildContext context) async {
    final url = Uri.parse(_csacSourceUrl);
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      await copySourceUrl(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(strings.text('App information')),
      ),
      child: SafeArea(
        child: _AdaptivePageFrame(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const _AppIconImage(size: 40, borderRadius: 10),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _csacAppName,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: colors.label,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                strings.text('Third-party CsAC client'),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.secondaryLabel,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  _CupertinoListTile(
                    leading: const _AppIconImage(size: 24, borderRadius: 6),
                    title: strings.text('App name'),
                    subtitle: _csacAppName,
                  ),
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.arrow_branch, size: 22),
                    title: strings.text('Branch'),
                    subtitle: _csacAppBranch,
                  ),
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.number, size: 22),
                    title: strings.text('Version'),
                    subtitle: _csacAppVersion,
                  ),
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.hammer, size: 22),
                    title: strings.text('Build number'),
                    subtitle: _csacAppBuild,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  _CupertinoListTile(
                    leading: const Icon(
                      CupertinoIcons.chevron_left_slash_chevron_right,
                      size: 22,
                    ),
                    title: strings.text('Source code'),
                    subtitle: _csacSourceUrl,
                    trailing: Icon(
                      CupertinoIcons.arrow_up_right_square,
                      size: 18,
                      color: colors.tertiaryLabel,
                    ),
                    onTap: () => openSourceUrl(context),
                  ),
                  _CupertinoListTile(
                    leading: const Icon(
                      CupertinoIcons.doc_on_clipboard,
                      size: 22,
                    ),
                    title: strings.text('Copy source link'),
                    onTap: () => copySourceUrl(context),
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

class OpenSourceLicensesScreen extends StatefulWidget {
  const OpenSourceLicensesScreen({super.key});

  @override
  State<OpenSourceLicensesScreen> createState() =>
      _OpenSourceLicensesScreenState();
}

class _OpenSourceLicensesScreenState extends State<OpenSourceLicensesScreen> {
  late final Future<List<_LicenseNotice>> licenses = loadLicenses();
  final Set<int> _expandedIndices = {};

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
      if (body.trim().isEmpty) continue;
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
      _showCupertinoToast(context, context.strings.text('License copied.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(strings.text('Open-source licenses')),
      ),
      child: SafeArea(
        child: FutureBuilder<List<_LicenseNotice>>(
          future: licenses,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CupertinoActivityIndicator(radius: 14),
                    const SizedBox(height: 16),
                    Text(
                      strings.text('Loading licenses...'),
                      style: TextStyle(color: colors.secondaryLabel),
                    ),
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
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: items.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                    child: Text(
                      strings.format('{count} license notices', {
                        'count': items.length,
                      }),
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.secondaryLabel,
                      ),
                    ),
                  );
                }
                final licenseIndex = index - 1;
                final license = items[licenseIndex];
                final isExpanded = _expandedIndices.contains(licenseIndex);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedIndices.remove(licenseIndex);
                              } else {
                                _expandedIndices.add(licenseIndex);
                              }
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        license.title,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: colors.label,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        strings.format('{count} packages', {
                                          'count': license.packages.length,
                                        }),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: colors.secondaryLabel,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isExpanded
                                      ? CupertinoIcons.chevron_up
                                      : CupertinoIcons.chevron_down,
                                  size: 16,
                                  color: colors.tertiaryLabel,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isExpanded) ...[
                          Container(height: 0.5, color: colors.separator),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                minSize: 0,
                                onPressed: () => copyLicense(license),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      CupertinoIcons.doc_on_clipboard,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      strings.text('Copy'),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                            child: Text(
                              license.body,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.secondaryLabel,
                              ),
                            ),
                          ),
                        ],
                      ],
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

class _LicenseNotice {
  const _LicenseNotice({required this.packages, required this.body});

  final List<String> packages;
  final String body;

  String get title =>
      packages.isEmpty ? 'Unknown package' : packages.join(', ');
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

  String get themeColorLabel {
    final selected = themeColorOptions.firstWhere(
      (option) =>
          option.color.toARGB32() == widget.state.preferences.themeColorValue,
      orElse: () => themeColorOptions.first,
    );
    return context.strings.text(selected.label);
  }

  Future<void> refreshAll() async {
    setState(() => refreshing = true);
    try {
      await widget.state.refreshHome();
      if (!mounted) return;
      _showCupertinoToast(context, context.strings.text('Refreshed.'));
    } catch (err) {
      if (!mounted) return;
      _showCupertinoToast(
        context,
        context.strings.format('Refresh failed: {error}', {'error': err}),
      );
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  Future<void> clearCache() async {
    final strings = context.strings;
    final confirmed = await _showCupertinoConfirm(
      context,
      title: strings.text('Clear local cache?'),
      message: strings.text(
        'Cached conversations and message history on this device will be removed. Your login session will be kept.',
      ),
      confirmText: 'Clear',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => clearing = true);
    try {
      await widget.state.clearLocalCache();
      if (!mounted) return;
      _showCupertinoToast(
        context,
        context.strings.text('Local cache cleared.'),
      );
    } catch (err) {
      if (!mounted) return;
      _showCupertinoToast(
        context,
        context.strings.format('Clear cache failed: {error}', {'error': err}),
      );
    } finally {
      if (mounted) setState(() => clearing = false);
    }
  }

  Future<void> logoutToLogin() async {
    await widget.state.logout();
    if (!mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil((route) => route.isFirst);
  }

  Future<void> saveServerUrl() async {
    setState(() => savingServer = true);
    try {
      final changed = await widget.state.updateServerUrl(serverUrl.text);
      if (!mounted) return;
      serverUrl.text = widget.state.preferences.serverUrl;
      _showCupertinoToast(
        context,
        context.strings.text(
          changed
              ? 'Server address saved. Please log in again.'
              : 'Server address is unchanged.',
        ),
      );
      setState(() {});
    } on FormatException {
      if (!mounted) return;
      _showCupertinoToast(
        context,
        context.strings.text('Invalid server address.'),
      );
    } catch (err) {
      if (!mounted) return;
      _showCupertinoToast(
        context,
        context.strings.format('Save failed: {error}', {'error': err}),
      );
    } finally {
      if (mounted) setState(() => savingServer = false);
    }
  }

  void resetServerUrl() {
    serverUrl.clear();
  }

  Future<void> chooseTheme() async {
    final strings = context.strings;
    final selected = await _showAdaptiveActionSheet<ThemeMode>(
      context,
      title: strings.text('Theme'),
      actions: [
        _AdaptiveSheetAction(
          value: ThemeMode.system,
          label: strings.text('System'),
          icon: CupertinoIcons.device_phone_portrait,
        ),
        _AdaptiveSheetAction(
          value: ThemeMode.light,
          label: strings.text('Light'),
          icon: CupertinoIcons.sun_max,
        ),
        _AdaptiveSheetAction(
          value: ThemeMode.dark,
          label: strings.text('Dark'),
          icon: CupertinoIcons.moon,
        ),
      ],
    );
    if (selected != null) {
      await widget.state.updateThemeMode(selected);
      if (mounted) setState(() {});
    }
  }

  Future<void> chooseThemeColor() async {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final content = Container(
      width: wide ? 380 : null,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: BoxDecoration(
        color: wide ? colors.navBarBackground : colors.cardBackground,
        borderRadius: BorderRadius.circular(wide ? 24 : 16),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.separator,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              strings.text('Theme color'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.label,
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
                    onTap: () =>
                        Navigator.of(context).pop(option.color.toARGB32()),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    final selected = wide
        ? await showCupertinoDialog<int>(
            context: context,
            builder: (context) => Center(child: content),
          )
        : await showCupertinoModalPopup<int>(
            context: context,
            builder: (context) => content,
          );
    if (selected != null) {
      await widget.state.updateThemeColor(selected);
      if (mounted) setState(() {});
    }
  }

  Future<void> chooseLanguage() async {
    final strings = context.strings;
    final selected = await _showAdaptiveActionSheet<CsacLanguage>(
      context,
      title: strings.text('Language'),
      actions: const [
        _AdaptiveSheetAction(
          value: CsacLanguage.en,
          label: 'English',
          icon: CupertinoIcons.textformat,
        ),
        _AdaptiveSheetAction(
          value: CsacLanguage.zh,
          label: '中文',
          icon: CupertinoIcons.textformat,
        ),
      ],
    );
    if (selected != null) {
      await widget.state.updateLanguage(selected);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.state.user;
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(strings.text('Settings')),
      ),
      child: SafeArea(
        child: _AdaptivePageFrame(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  _CupertinoListTile(
                    leading: _Avatar(
                      url: user?.avatar ?? '',
                      fallback: CupertinoIcons.person_fill,
                    ),
                    title: user?.nickname ?? strings.text('Not logged in'),
                    subtitle: [
                      if (user?.username.isNotEmpty == true)
                        '@${user!.username}',
                      if (user != null) 'UID ${user.uid}',
                    ].join(' | '),
                    onTap: user == null
                        ? null
                        : () {
                            Navigator.of(context).push(
                              CupertinoPageRoute<void>(
                                builder: (_) =>
                                    AccountSettingsScreen(state: widget.state),
                              ),
                            );
                          },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.info, size: 22),
                    title: strings.text('App information'),
                    subtitle:
                        '$_csacAppName $_csacAppVersion | $_csacAppBranch',
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => const AppInfoScreen(),
                        ),
                      );
                    },
                  ),
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.doc_text, size: 22),
                    title: strings.text('Open-source licenses'),
                    subtitle: strings.text(
                      'View licenses for included libraries',
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => const OpenSourceLicensesScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.moon, size: 22),
                    title: strings.text('Theme'),
                    subtitle: themeLabel,
                    onTap: chooseTheme,
                  ),
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.paintbrush, size: 22),
                    title: strings.text('Theme color'),
                    subtitle: themeColorLabel,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ThemeColorDot(
                          color: Color(
                            widget.state.preferences.themeColorValue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          CupertinoIcons.chevron_right,
                          size: 16,
                          color: colors.tertiaryLabel,
                        ),
                      ],
                    ),
                    onTap: chooseThemeColor,
                  ),
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.globe, size: 22),
                    title: strings.text('Language'),
                    subtitle: languageLabel,
                    onTap: chooseLanguage,
                  ),
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.text_bubble, size: 22),
                    title: strings.text('Chat options'),
                    subtitle: strings.text(
                      'Timestamps, bubbles, and input behavior',
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) =>
                              ChatOptionsScreen(state: widget.state),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  _CupertinoListTile(
                    leading: const Icon(
                      CupertinoIcons.arrow_2_circlepath,
                      size: 22,
                    ),
                    title: strings.text('Refresh app data'),
                    subtitle: strings.text('Reload conversations and counters'),
                    trailing: refreshing
                        ? const CupertinoActivityIndicator(radius: 10)
                        : Icon(
                            CupertinoIcons.chevron_right,
                            size: 16,
                            color: colors.tertiaryLabel,
                          ),
                    onTap: refreshing ? null : refreshAll,
                  ),
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.trash, size: 22),
                    title: strings.text('Clear local cache'),
                    subtitle: strings.text(
                      'Remove cached conversations and message history',
                    ),
                    trailing: clearing
                        ? const CupertinoActivityIndicator(radius: 10)
                        : Icon(
                            CupertinoIcons.chevron_right,
                            size: 16,
                            color: colors.tertiaryLabel,
                          ),
                    onTap: clearing ? null : clearCache,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(
                        () => developerOptionsExpanded =
                            !developerOptionsExpanded,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.wrench, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strings.text('Developer options'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: colors.label,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  strings.format('Current server: {server}', {
                                    'server':
                                        widget.state.preferences.serverUrl
                                            .trim()
                                            .isEmpty
                                        ? strings.text('Default server')
                                        : widget.state.preferences.serverUrl
                                              .trim(),
                                  }),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colors.secondaryLabel,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            developerOptionsExpanded
                                ? CupertinoIcons.chevron_up
                                : CupertinoIcons.chevron_down,
                            size: 16,
                            color: colors.tertiaryLabel,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (developerOptionsExpanded)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          _CupertinoFormField(
                            controller: serverUrl,
                            placeholder: '192.168.1.10:8080',
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!savingServer) saveServerUrl();
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            strings.text(
                              'Leave empty to use the default server.',
                            ),
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.tertiaryLabel,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              CupertinoButton(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                onPressed: savingServer ? null : resetServerUrl,
                                child: Text(
                                  strings.text('Reset to default'),
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                              const SizedBox(width: 8),
                              CupertinoButton.filled(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                onPressed: savingServer ? null : saveServerUrl,
                                child: savingServer
                                    ? const CupertinoActivityIndicator(
                                        radius: 9,
                                        color: CupertinoColors.white,
                                      )
                                    : Text(
                                        strings.text('Apply server'),
                                        style: const TextStyle(fontSize: 15),
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  _CupertinoListTile(
                    leading: const Icon(
                      CupertinoIcons.square_arrow_left,
                      size: 22,
                    ),
                    title: strings.text('Logout'),
                    subtitle: strings.text('Clear session and return to login'),
                    onTap: logoutToLogin,
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

class ChatOptionsScreen extends StatelessWidget {
  const ChatOptionsScreen({super.key, required this.state});

  final CsacAppState state;

  Future<void> update(CsacChatPreferences chat) {
    return state.updateChatPreferences(chat);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final chat = state.preferences.chat;
    return CupertinoPageScaffold(
      backgroundColor: colors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(strings.text('Chat options')),
        backgroundColor: colors.navBarBackground,
        border: null,
      ),
      child: SafeArea(
        child: _AdaptivePageFrame(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  _ChatOptionSwitchTile(
                    icon: CupertinoIcons.clock,
                    title: strings.text('Show seconds in timestamps'),
                    subtitle: strings.text(
                      'Display chat times as HH:mm:ss when possible',
                    ),
                    value: chat.showSeconds,
                    onChanged: (value) =>
                        update(chat.copyWith(showSeconds: value)),
                  ),
                  _ChatOptionSwitchTile(
                    icon: CupertinoIcons.rectangle_compress_vertical,
                    title: strings.text('Compact message bubbles'),
                    subtitle: strings.text(
                      'Reduce message spacing for denser conversations',
                    ),
                    value: chat.compactBubbles,
                    onChanged: (value) =>
                        update(chat.copyWith(compactBubbles: value)),
                  ),
                  _ChatOptionSwitchTile(
                    icon: CupertinoIcons.person_crop_circle,
                    title: strings.text('Show sender names'),
                    subtitle: strings.text(
                      'Show the sender line above each message',
                    ),
                    value: chat.showSenderName,
                    onChanged: (value) =>
                        update(chat.copyWith(showSenderName: value)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  _ChatOptionSwitchTile(
                    icon: CupertinoIcons.keyboard_chevron_compact_down,
                    title: strings.text('Tap background to dismiss keyboard'),
                    subtitle: strings.text(
                      'Tap the chat area to fold away the keyboard',
                    ),
                    value: chat.tapToDismissKeyboard,
                    onChanged: (value) =>
                        update(chat.copyWith(tapToDismissKeyboard: value)),
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

class _ChatOptionSwitchTile extends StatelessWidget {
  const _ChatOptionSwitchTile({
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
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: colors.label),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 16, color: colors.label),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: colors.secondaryLabel),
                ),
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
