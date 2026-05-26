part of '../../main.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  Widget build(BuildContext context) {
    final user = state.user;
    final counts = state.notificationCounts;
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('Me'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (state.sessionExpired)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MaterialBanner(
                  content: Text(
                    strings.text(
                      'Session expired. Log in again to sync latest data.',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: state.logout,
                      child: Text(strings.text('Login')),
                    ),
                  ],
                ),
              ),
            Card(
              elevation: 0,
              child: _RoundedInkClip(
                child: ListTile(
                  leading: _Avatar(
                    url: user?.avatar ?? '',
                    fallback: Icons.person_rounded,
                  ),
                  title: Text(user?.nickname ?? strings.text('Not logged in')),
                  subtitle: Text(
                    [
                      if (user?.username.isNotEmpty == true)
                        '@${user!.username}',
                      if (user != null) 'UID ${user.uid}',
                      if (user?.onlineStatus.isNotEmpty == true)
                        user!.onlineStatus,
                    ].join(' | '),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: user == null
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  AccountSettingsScreen(state: state),
                            ),
                          );
                        },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.notifications_none),
                    title: Text(strings.text('Unread notices')),
                    trailing: Badge(label: Text('${counts.notices}')),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_add_alt),
                    title: Text(strings.text('Friend requests')),
                    trailing: Badge(label: Text('${counts.friendRequests}')),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.group_add_outlined),
                    title: Text(strings.text('Group reviews')),
                    trailing: Badge(label: Text('${counts.groupApplications}')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: state.refreshHome,
              icon: const Icon(Icons.sync),
              label: Text(strings.text('Refresh all')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SettingsScreen(state: state),
                  ),
                );
              },
              icon: const Icon(Icons.settings_outlined),
              label: Text(strings.text('Settings')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: state.logout,
              icon: const Icon(Icons.logout),
              label: Text(strings.text('Logout')),
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
    final nickname = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
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
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(strings.text('Save')),
          ),
        ],
      ),
    );
    controller.dispose();
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
    final oldPassword = TextEditingController();
    final newPassword = TextEditingController();
    final confirmPassword = TextEditingController();
    final strings = context.strings;
    final result = await showDialog<_PasswordChange>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('Change password')),
        content: SizedBox(
          width: 420,
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
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

  void showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget progressOrChevron(bool loading) {
    if (!loading) {
      return const Icon(Icons.chevron_right);
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
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('Account settings'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _Avatar(
                      url: user?.avatar ?? '',
                      fallback: Icons.person_rounded,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.nickname ?? strings.text('Not logged in'),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (user?.username.isNotEmpty == true)
                                '@${user!.username}',
                              if (user != null) 'UID ${user.uid}',
                            ].join(' | '),
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
                    ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: Text(strings.text('Change nickname')),
                      subtitle: Text(user?.nickname ?? ''),
                      trailing: progressOrChevron(updatingNickname),
                      onTap: updatingNickname ? null : editNickname,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.add_a_photo_outlined),
                      title: Text(strings.text('Change avatar')),
                      subtitle: Text(
                        strings.text('Choose a new profile image'),
                      ),
                      trailing: progressOrChevron(updatingAvatar),
                      onTap: updatingAvatar ? null : changeAvatar,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock_reset_outlined),
                      title: Text(strings.text('Change password')),
                      subtitle: Text(
                        strings.text('Update your login password'),
                      ),
                      trailing: progressOrChevron(updatingPassword),
                      onTap: updatingPassword ? null : changePassword,
                    ),
                  ],
                ),
              ),
            ),
          ],
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
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: _ThemeColorDot(color: option.color, selected: selected),
        ),
      ),
    );
  }
}

const _csacAppName = 'CsAC';
const _csacAppBranch = 'XiaoBai';
const _csacAppVersion = '1.0.0-18';
const _csacAppBuild = '18';
const _csacSourceUrl = 'https://github.com/VasilyZa/CsAC_Flutter';

class AppInfoScreen extends StatelessWidget {
  const AppInfoScreen({super.key});

  Future<void> copySourceUrl(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _csacSourceUrl));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Source link copied.'))),
      );
    }
  }

  Future<void> openSourceUrl(BuildContext context) async {
    final url = Uri.parse(_csacSourceUrl);
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      await copySourceUrl(context);
    }
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.chat_bubble_outline,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
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
                    infoTile(
                      context,
                      icon: Icons.numbers_outlined,
                      title: strings.text('Version'),
                      value: _csacAppVersion,
                    ),
                    const Divider(height: 1),
                    infoTile(
                      context,
                      icon: Icons.build_outlined,
                      title: strings.text('Build number'),
                      value: _csacAppBuild,
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
                      child: ExpansionTile(
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

  Future<void> logoutToLogin() async {
    await widget.state.logout();
    if (!mounted) {
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.strings.text('Theme color'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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

  @override
  Widget build(BuildContext context) {
    final user = widget.state.user;
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('Settings'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Card(
              elevation: 0,
              child: _RoundedInkClip(
                child: ListTile(
                  leading: _Avatar(
                    url: user?.avatar ?? '',
                    fallback: Icons.person_rounded,
                  ),
                  title: Text(user?.nickname ?? strings.text('Not logged in')),
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
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  AccountSettingsScreen(state: widget.state),
                            ),
                          );
                        },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: _RoundedInkClip(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(strings.text('App information')),
                      subtitle: const Text(
                        '$_csacAppName $_csacAppVersion | $_csacAppBranch',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const AppInfoScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.article_outlined),
                      title: Text(strings.text('Open-source licenses')),
                      subtitle: Text(
                        strings.text('View licenses for included libraries'),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const OpenSourceLicensesScreen(),
                          ),
                        );
                      },
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
                              widget.state.preferences.themeColorValue,
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
                    ListTile(
                      leading: const Icon(Icons.sync),
                      title: Text(strings.text('Refresh app data')),
                      subtitle: Text(
                        strings.text('Reload conversations and counters'),
                      ),
                      trailing: refreshing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: refreshing ? null : refreshAll,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.cleaning_services_outlined),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: clearing ? null : clearCache,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: _RoundedInkClip(
                child: ExpansionTile(
                  initiallyExpanded: developerOptionsExpanded,
                  onExpansionChanged: (value) {
                    setState(() => developerOptionsExpanded = value);
                  },
                  leading: const Icon(Icons.developer_mode_outlined),
                  title: Text(strings.text('Developer options')),
                  subtitle: Text(
                    strings.format('Current server: {server}', {
                      'server':
                          widget.state.preferences.serverUrl.trim().isEmpty
                          ? strings.text('Default server')
                          : widget.state.preferences.serverUrl.trim(),
                    }),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                        labelText: strings.text('CsAC server address'),
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
                          onPressed: savingServer ? null : resetServerUrl,
                          icon: const Icon(Icons.restart_alt),
                          label: Text(strings.text('Reset to default')),
                        ),
                        FilledButton.icon(
                          onPressed: savingServer ? null : saveServerUrl,
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
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
        ),
      ),
    );
  }
}
