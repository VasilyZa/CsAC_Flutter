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
      _showCupertinoToast(context, context.strings.text(success));
      await load();
    } catch (err) {
      if (mounted) {
        _showCupertinoToast(
          context,
          context.strings.format('Action failed: {error}', {'error': err}),
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
    final message = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(strings.format('Add {name}', {'name': target.displayName})),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            maxLines: 3,
            placeholder: strings.text('Request message'),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(strings.text('Cancel')),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
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
    final remark = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(strings.text('Edit remark')),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: controller,
            placeholder: strings.text('Remark'),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(null),
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
    if (remark == null || !mounted) {
      return;
    }
    await runAction(
      () => widget.state.updateFriendRemark(target.uid, remark.trim()),
      'Remark updated.',
    );
  }

  Future<bool> confirm(String title, String message, String action) async {
    return _showCupertinoConfirm(
      context,
      title: title,
      message: message,
      confirmText: context.strings.text(action),
      isDestructive: true,
    );
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
    _showCupertinoToast(
      context,
      context.strings.format('{label} copied.', {'label': label}),
    );
  }

  void openPrivateChat(UserProfile target) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
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
      CupertinoPageRoute<void>(
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
    final colors = CsacColors.of(context);
    return _CupertinoListTile(
      leading: Icon(icon, size: 20, color: colors.secondaryLabel),
      title: title,
      subtitle: value,
      trailing: GestureDetector(
        onTap: () => copyValue(title, value),
        child: Icon(
          CupertinoIcons.doc_on_doc,
          size: 18,
          color: colors.tertiaryLabel,
        ),
      ),
    );
  }

  Widget actionTile({
    required IconData icon,
    required String title,
    required VoidCallback? onTap,
    Color? color,
  }) {
    final enabled = onTap != null && !acting;
    final colors = CsacColors.of(context);
    return _CupertinoListTile(
      leading: Icon(
        icon,
        size: 20,
        color: enabled ? (color ?? colors.label) : colors.tertiaryLabel,
      ),
      title: title,
      titleColor: enabled ? color : colors.tertiaryLabel,
      onTap: enabled ? onTap : null,
    );
  }

  Future<void> reportUser(UserProfile profile) {
    return showReportDialog(
      context: context,
      state: widget.state,
      type: 'user',
      title: context.strings.text('Report user'),
      uid: profile.uid,
      nickname: profile.displayName,
      username: profile.username,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final loaded = profile;
    final member = widget.member;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(border: null, backgroundColor: CsacColors.of(context).navBarBackground,
        middle: Text(strings.text('User profile')),
        trailing: GestureDetector(
          onTap: loading ? null : load,
          child: Icon(
            CupertinoIcons.refresh,
            size: 22,
            color: loading
                ? colors.tertiaryLabel
                : CupertinoTheme.of(context).primaryColor,
          ),
        ),
      ),
      child: SafeArea(
        child: loading
            ? const Center(child: CupertinoActivityIndicator())
            : error != null
                ? _InlineError(message: error!, onRetry: load)
                : loaded == null
                    ? _EmptyPanel(message: strings.text('User not found.'))
                    : CustomScrollView(
                        slivers: [
                          CupertinoSliverRefreshControl(onRefresh: load),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        _Avatar(
                                          url: loaded.avatar,
                                          fallback: CupertinoIcons.person_solid,
                                          size: 56,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                loaded.displayName,
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                loaded.subtitle.isEmpty
                                                    ? 'UID ${loaded.uid}'
                                                    : loaded.subtitle,
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
                                  const SizedBox(height: 12),

                                  // Info section
                                  _CupertinoGroupedCard(
                                    children: [
                                      infoRow(
                                        CupertinoIcons.number,
                                        strings.text('UID'),
                                        '${loaded.uid}',
                                      ),
                                      infoRow(
                                        CupertinoIcons.at,
                                        strings.text('Username'),
                                        loaded.username,
                                      ),
                                      infoRow(
                                        CupertinoIcons.person,
                                        strings.text('Nickname'),
                                        loaded.nickname,
                                      ),
                                      infoRow(
                                        CupertinoIcons.pencil,
                                        strings.text('Remark'),
                                        loaded.remark,
                                      ),
                                      infoRow(
                                        CupertinoIcons.circle,
                                        strings.text('Online'),
                                        loaded.onlineStatus,
                                      ),
                                      if (member != null)
                                        infoRow(
                                          CupertinoIcons.shield,
                                          strings.text('Group role'),
                                          member.roleLabel,
                                        ),
                                    ].where((w) => w is! SizedBox).toList(),
                                  ),

                                  // Actions section
                                  if (!isSelf) ...[
                                    const SizedBox(height: 6),
                                    _CupertinoGroupedCard(
                                      children: [
                                        if (loaded.isFriend)
                                          actionTile(
                                            icon: CupertinoIcons.chat_bubble,
                                            title: strings.text('Open private chat'),
                                            onTap: () => openPrivateChat(loaded),
                                          ),
                                        if (loaded.isFriend)
                                          actionTile(
                                            icon: CupertinoIcons.pencil,
                                            title: strings.text('Edit remark'),
                                            onTap: () => editRemark(loaded),
                                          ),
                                        if (!loaded.isFriend && loaded.canAddFriend)
                                          actionTile(
                                            icon: CupertinoIcons.person_add,
                                            title: strings.text('Add friend'),
                                            onTap: () => addFriend(loaded),
                                          ),
                                        if (!loaded.isFriend && !loaded.canAddFriend)
                                          actionTile(
                                            icon: CupertinoIcons.person_add,
                                            title: strings.text('Cannot add friend'),
                                            onTap: null,
                                          ),
                                        if (!loaded.isFriend && !loaded.canAddFriend)
                                          actionTile(
                                            icon: CupertinoIcons.arrow_counterclockwise,
                                            title: strings.text('Recover friend'),
                                            onTap: () => recoverFriend(loaded),
                                          ),
                                        actionTile(
                                          icon: CupertinoIcons.person_badge_minus,
                                          title: strings.text('Delete friend'),
                                          color: CupertinoColors.destructiveRed,
                                          onTap: loaded.isFriend
                                              ? () => deleteFriend(loaded)
                                              : null,
                                        ),
                                        actionTile(
                                          icon: CupertinoIcons.nosign,
                                          title: strings.text('Block friend'),
                                          color: CupertinoColors.destructiveRed,
                                          onTap: loaded.isFriend
                                              ? () => blockFriend(loaded)
                                              : null,
                                        ),
                                        actionTile(
                                          icon: CupertinoIcons.flag,
                                          title: strings.text('Report user'),
                                          color: CupertinoColors.destructiveRed,
                                          onTap: () => reportUser(loaded),
                                        ),
                                      ],
                                    ),
                                  ],

                                  // Group member actions
                                  if (canManageMember) ...[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16, 20, 16, 6,
                                      ),
                                      child: Text(
                                        strings.text('Group member actions'),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: colors.secondaryLabel,
                                        ),
                                      ),
                                    ),
                                    _CupertinoGroupedCard(
                                      children: [
                                        actionTile(
                                          icon: CupertinoIcons.speaker_slash,
                                          title: strings.text('Mute 10 minutes'),
                                          onTap: () => memberAction('mute10'),
                                        ),
                                        actionTile(
                                          icon: CupertinoIcons.speaker_2,
                                          title: strings.text('Unmute'),
                                          onTap: () => memberAction('unmute'),
                                        ),
                                        actionTile(
                                          icon: CupertinoIcons.shield,
                                          title: strings.text('Set admin'),
                                          onTap: () => memberAction('admin'),
                                        ),
                                        actionTile(
                                          icon: CupertinoIcons.shield_slash,
                                          title: strings.text('Remove admin'),
                                          onTap: () => memberAction('removeAdmin'),
                                        ),
                                        actionTile(
                                          icon: CupertinoIcons.person_badge_minus,
                                          title: strings.text('Kick member'),
                                          color: CupertinoColors.destructiveRed,
                                          onTap: () => memberAction('kick'),
                                        ),
                                      ],
                                    ),
                                  ],

                                  // Common groups
                                  if (commonGroups.isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16, 20, 16, 6,
                                      ),
                                      child: Text(
                                        strings.text('Common groups'),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: colors.secondaryLabel,
                                        ),
                                      ),
                                    ),
                                    _CupertinoGroupedCard(
                                      children: [
                                        for (final group in commonGroups)
                                          _CupertinoListTile(
                                            leading: Icon(
                                              CupertinoIcons.group,
                                              size: 20,
                                              color: colors.secondaryLabel,
                                            ),
                                            title: group.name,
                                            subtitle: group.subtitle.isEmpty
                                                ? null
                                                : group.subtitle,
                                            onTap: () => openCommonGroup(group),
                                          ),
                                      ],
                                    ),
                                  ],
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
