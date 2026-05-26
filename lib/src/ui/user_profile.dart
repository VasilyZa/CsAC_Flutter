part of '../../main.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.state,
    required this.uid,
    this.group,
    this.member,
  });

  final CsacAppState state;
  final int uid;
  final GroupProfile? group;
  final GroupMember? member;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserProfile? profile;
  List<CommonGroup> commonGroups = const <CommonGroup>[];
  bool loading = true;
  bool acting = false;
  String? error;

  bool get isSelf => widget.state.user?.uid == widget.uid;

  bool get canManageMember {
    final group = widget.group;
    final member = widget.member;
    if (group == null || member == null || isSelf || member.isOwner) {
      return false;
    }
    return group.isOwner || group.isAdmin;
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget.state.loadUserProfile(widget.uid);
      var groups = const <CommonGroup>[];
      if (loaded.isFriend) {
        try {
          groups = await widget.state.loadCommonGroups(loaded.uid);
        } catch (_) {}
      }
      if (!mounted) {
        return;
      }
      setState(() {
        profile = loaded;
        commonGroups = groups;
      });
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> runAction(Future<void> Function() action, String success) async {
    setState(() => acting = true);
    try {
      await action();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings.text(success))));
      await load();
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
        setState(() => acting = false);
      }
    }
  }

  Future<void> addFriend(UserProfile target) async {
    final controller = TextEditingController(text: '请求添加你为好友');
    final strings = context.strings;
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.format('Add {name}', {'name': target.displayName})),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: strings.text('Request message'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(strings.text('Send')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (message == null || !mounted) {
      return;
    }
    await runAction(
      () => widget.state.sendFriendRequest(target.uid, message),
      'Friend request sent.',
    );
  }

  Future<void> editRemark(UserProfile target) async {
    final controller = TextEditingController(text: target.remark);
    final strings = context.strings;
    final remark = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('Edit remark')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: strings.text('Remark'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
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
    if (remark == null || !mounted) {
      return;
    }
    await runAction(
      () => widget.state.updateFriendRemark(target.uid, remark.trim()),
      'Remark updated.',
    );
  }

  Future<bool> confirm(String title, String message, String action) async {
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.text(action)),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> deleteFriend(UserProfile target) async {
    final strings = context.strings;
    final ok = await confirm(
      strings.format('Delete {name}?', {'name': target.displayName}),
      strings.text('This friend will be removed from your list.'),
      'Delete',
    );
    if (!ok || !mounted) {
      return;
    }
    await runAction(
      () => widget.state.deleteFriend(target.uid),
      'Friend deleted.',
    );
  }

  Future<void> blockFriend(UserProfile target) async {
    final strings = context.strings;
    final ok = await confirm(
      strings.format('Block {name}?', {'name': target.displayName}),
      strings.text('This friend will be blocked.'),
      'Block',
    );
    if (!ok || !mounted) {
      return;
    }
    await runAction(
      () => widget.state.blockFriend(target.uid),
      'Friend blocked.',
    );
  }

  Future<void> recoverFriend(UserProfile target) async {
    await runAction(
      () => widget.state.recoverFriend(target.uid),
      'Friend recovered.',
    );
  }

  Future<void> memberAction(String action) async {
    final group = widget.group;
    final member = widget.member;
    if (group == null || member == null) {
      return;
    }
    await runAction(() async {
      switch (action) {
        case 'mute10':
          await widget.state.muteGroupMember(group.id, member.uid, 10);
          break;
        case 'unmute':
          await widget.state.muteGroupMember(group.id, member.uid, 0);
          break;
        case 'kick':
          await widget.state.kickGroupMember(group.id, member.uid);
          break;
        case 'admin':
          await widget.state.setGroupAdmin(group.id, member.uid, true);
          break;
        case 'removeAdmin':
          await widget.state.setGroupAdmin(group.id, member.uid, false);
          break;
      }
    }, 'Member action completed.');
  }

  void copyValue(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.strings.format('{label} copied.', {'label': label}),
        ),
      ),
    );
  }

  void openPrivateChat(UserProfile target) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          state: widget.state,
          conversation: Conversation(
            type: ConversationType.private,
            id: target.uid,
            name: target.displayName,
            subtitle: target.subtitle,
          ),
        ),
      ),
    );
  }

  void openCommonGroup(CommonGroup group) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          state: widget.state,
          conversation: Conversation(
            type: ConversationType.group,
            id: group.id,
            name: group.name,
            subtitle: group.subtitle,
          ),
        ),
      ),
    );
  }

  Widget infoRow(IconData icon, String title, String value) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: SelectableText(value),
      trailing: IconButton(
        tooltip: context.strings.text('Copy'),
        onPressed: () => copyValue(title, value),
        icon: const Icon(Icons.copy),
      ),
    );
  }

  Widget actionTile({
    required IconData icon,
    required String title,
    required VoidCallback? onTap,
    Color? color,
  }) {
    return ListTile(
      enabled: onTap != null && !acting,
      leading: Icon(icon, color: color),
      title: Text(title, style: color == null ? null : TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap == null || acting ? null : onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    final loaded = profile;
    final member = widget.member;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.text('User profile')),
        actions: [
          IconButton(
            tooltip: strings.text('Refresh'),
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? _InlineError(message: error!, onRetry: load)
            : loaded == null
            ? _EmptyPanel(message: strings.text('User not found.'))
            : RefreshIndicator(
                onRefresh: load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _Avatar(
                        url: loaded.avatar,
                        fallback: Icons.person_rounded,
                      ),
                      title: Text(loaded.displayName),
                      subtitle: Text(
                        loaded.subtitle.isEmpty
                            ? 'UID ${loaded.uid}'
                            : loaded.subtitle,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      child: Column(
                        children: [
                          infoRow(
                            Icons.tag,
                            strings.text('UID'),
                            '${loaded.uid}',
                          ),
                          infoRow(
                            Icons.badge_outlined,
                            strings.text('Username'),
                            loaded.username,
                          ),
                          infoRow(
                            Icons.person_outline,
                            strings.text('Nickname'),
                            loaded.nickname,
                          ),
                          infoRow(
                            Icons.edit_note,
                            strings.text('Remark'),
                            loaded.remark,
                          ),
                          infoRow(
                            Icons.circle_outlined,
                            strings.text('Online'),
                            loaded.onlineStatus,
                          ),
                          if (member != null)
                            infoRow(
                              Icons.admin_panel_settings_outlined,
                              strings.text('Group role'),
                              member.roleLabel,
                            ),
                        ],
                      ),
                    ),
                    if (!isSelf) ...[
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0,
                        child: Column(
                          children: [
                            if (loaded.isFriend)
                              actionTile(
                                icon: Icons.chat_bubble_outline,
                                title: strings.text('Open private chat'),
                                onTap: () => openPrivateChat(loaded),
                              ),
                            if (loaded.isFriend) const Divider(height: 1),
                            if (loaded.isFriend)
                              actionTile(
                                icon: Icons.edit_note,
                                title: strings.text('Edit remark'),
                                onTap: () => editRemark(loaded),
                              ),
                            if (loaded.isFriend) const Divider(height: 1),
                            if (!loaded.isFriend && loaded.canAddFriend)
                              actionTile(
                                icon: Icons.person_add_alt,
                                title: strings.text('Add friend'),
                                onTap: () => addFriend(loaded),
                              ),
                            if (!loaded.isFriend && !loaded.canAddFriend)
                              actionTile(
                                icon: Icons.person_add_disabled_outlined,
                                title: strings.text('Cannot add friend'),
                                onTap: null,
                              ),
                            if (!loaded.isFriend) const Divider(height: 1),
                            if (!loaded.isFriend && !loaded.canAddFriend)
                              actionTile(
                                icon: Icons.restore,
                                title: strings.text('Recover friend'),
                                onTap: () => recoverFriend(loaded),
                              ),
                            if (!loaded.isFriend && !loaded.canAddFriend)
                              const Divider(height: 1),
                            actionTile(
                              icon: Icons.person_remove_outlined,
                              title: strings.text('Delete friend'),
                              color: colors.error,
                              onTap: loaded.isFriend
                                  ? () => deleteFriend(loaded)
                                  : null,
                            ),
                            const Divider(height: 1),
                            actionTile(
                              icon: Icons.block,
                              title: strings.text('Block friend'),
                              color: colors.error,
                              onTap: loaded.isFriend
                                  ? () => blockFriend(loaded)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (canManageMember) ...[
                      const SizedBox(height: 20),
                      Text(
                        strings.text('Group member actions'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 0,
                        child: Column(
                          children: [
                            actionTile(
                              icon: Icons.volume_off_outlined,
                              title: strings.text('Mute 10 minutes'),
                              onTap: () => memberAction('mute10'),
                            ),
                            const Divider(height: 1),
                            actionTile(
                              icon: Icons.volume_up_outlined,
                              title: strings.text('Unmute'),
                              onTap: () => memberAction('unmute'),
                            ),
                            const Divider(height: 1),
                            actionTile(
                              icon: Icons.admin_panel_settings_outlined,
                              title: strings.text('Set admin'),
                              onTap: () => memberAction('admin'),
                            ),
                            const Divider(height: 1),
                            actionTile(
                              icon: Icons.remove_moderator_outlined,
                              title: strings.text('Remove admin'),
                              onTap: () => memberAction('removeAdmin'),
                            ),
                            const Divider(height: 1),
                            actionTile(
                              icon: Icons.person_remove_outlined,
                              title: strings.text('Kick member'),
                              color: colors.error,
                              onTap: () => memberAction('kick'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (commonGroups.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        strings.text('Common groups'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      for (final group in commonGroups)
                        Card(
                          elevation: 0,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: const Icon(Icons.groups_outlined),
                            title: Text(group.name),
                            subtitle: group.subtitle.isEmpty
                                ? null
                                : Text(group.subtitle),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => openCommonGroup(group),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
