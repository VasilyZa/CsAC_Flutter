part of '../../main.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.state,
    required this.uid,
    this.group,
    this.member,
    this.avatarHeroTag,
  });

  final CsacAppState state;
  final int uid;
  final GroupProfile? group;
  final GroupMember? member;
  final Object? avatarHeroTag;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  static const _profileHeaderExpandedHeight = 286.0;

  UserProfile? profile;
  List<CommonGroup> commonGroups = const <CommonGroup>[];
  List<GroupProfile> createdGroups = const <GroupProfile>[];
  late final ScrollController profileScroll;
  Timer? profileHeaderSnapTimer;
  bool loading = true;
  bool acting = false;
  String? error;

  bool get isSelf => widget.state.user?.uid == widget.uid;

  bool get canManageMember {
    if (widget.state.debugMode) {
      return true;
    }
    final group = widget.group;
    final member = widget.member;
    if (group == null || member == null || isSelf || member.isOwner) {
      return false;
    }
    return group.isOwner || group.isAdmin;
  }

  bool get canDebugManageUser => widget.state.debugMode && !isSelf;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(handleStateChanged);
    profileScroll = _desktopSmoothScrollController();
    load();
  }

  @override
  void dispose() {
    widget.state.removeListener(handleStateChanged);
    profileHeaderSnapTimer?.cancel();
    profileScroll.dispose();
    super.dispose();
  }

  void handleStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool handleProfileScrollEnd(ScrollEndNotification notification) {
    if (notification.depth == 0 && profile != null) {
      scheduleProfileHeaderSnap();
    }
    return false;
  }

  void scheduleProfileHeaderSnap() {
    profileHeaderSnapTimer?.cancel();
    profileHeaderSnapTimer = Timer(const Duration(milliseconds: 70), () {
      if (mounted) {
        snapProfileHeader();
      }
    });
  }

  void snapProfileHeader() {
    if (!profileScroll.hasClients || profile == null) {
      return;
    }
    final position = profileScroll.position;
    final maxSnapOffset = math.min(
      _profileHeaderExpandedHeight - kToolbarHeight,
      position.maxScrollExtent,
    );
    if (maxSnapOffset <= 0) {
      return;
    }
    final current = position.pixels.clamp(0.0, maxSnapOffset).toDouble();
    if (current <= 2 || current >= maxSnapOffset - 2) {
      return;
    }
    final progress = current / maxSnapOffset;
    final target = progress < 0.48 ? 0.0 : maxSnapOffset;
    if ((position.pixels - target).abs() < 1) {
      return;
    }
    if (_MotionPreference.reduceOf(context)) {
      position.jumpTo(target);
      return;
    }
    position.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Widget buildProfileScrollView({
    required List<Widget> slivers,
    ScrollPhysics? physics,
  }) {
    return NotificationListener<ScrollEndNotification>(
      onNotification: handleProfileScrollEnd,
      child: CustomScrollView(
        controller: profileScroll,
        physics: physics,
        slivers: slivers,
      ),
    );
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
      var created = const <GroupProfile>[];
      try {
        created = await widget.state.loadCreatedGroups(loaded.uid);
      } catch (_) {}
      if (!mounted) {
        return;
      }
      setState(() {
        profile = loaded;
        commonGroups = groups;
        createdGroups = created;
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

  Future<void> banUser(UserProfile target) async {
    final strings = context.strings;
    final ok = await confirm(
      strings.format('Ban {name}?', {'name': target.displayName}),
      strings.text('This user will be banned from the service.'),
      'Ban',
    );
    if (!ok || !mounted) {
      return;
    }
    await runAction(() => widget.state.banUser(target.uid), 'User banned.');
  }

  Future<void> unbanUser(UserProfile target) async {
    await runAction(() => widget.state.unbanUser(target.uid), 'User unbanned.');
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

  Future<void> editMemberTitle() async {
    final group = widget.group;
    final member = widget.member;
    if (group == null || member == null) {
      return;
    }
    final result = await showDialog<_MemberTitleChange>(
      context: context,
      builder: (context) =>
          _MemberTitleDialog(member: member, debugMode: widget.state.debugMode),
    );
    if (result == null || !mounted) {
      return;
    }
    if (result.title.runes.length > 16) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.text('Member title must be at most 16 characters.'),
          ),
        ),
      );
      return;
    }
    if (result.level < 1 || (!widget.state.debugMode && result.level > 100)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.text('Level must be between 1 and 100.'),
          ),
        ),
      );
      return;
    }
    await runAction(
      () => widget.state.setGroupMemberTitle(
        group.id,
        member.uid,
        title: result.title,
        level: result.level,
      ),
      'Member title updated.',
    );
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
      CsacPageRoute<void>(
        builder: (_) => ChatScreen(
          state: widget.state,
          conversation: Conversation(
            type: ConversationType.private,
            id: target.uid,
            name: target.displayName,
            avatar: target.avatar,
            subtitle: target.subtitle,
          ),
        ),
      ),
    );
  }

  void openCommonGroup(CommonGroup group) {
    Navigator.of(context).push(
      CsacPageRoute<void>(
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

  void openCreatedGroup(GroupProfile group) {
    Navigator.of(context).push(
      CsacPageRoute<void>(
        builder: (_) => ConversationDetailScreen(
          state: widget.state,
          conversation: Conversation(
            type: ConversationType.group,
            id: group.id,
            name: group.name,
            avatar: group.avatar,
            subtitle: group.subtitle,
          ),
        ),
      ),
    );
  }

  void openReport(UserProfile target) {
    Navigator.of(context).push(
      CsacPageRoute<void>(
        builder: (_) => ReportScreen(
          state: widget.state,
          type: 'user',
          targetId: target.uid,
          targetName: target.displayName,
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
      body: loading
          ? buildProfileScrollView(
              slivers: [
                _UserProfileHeaderSliver(
                  title: strings.text('User profile'),
                  loading: loading,
                  onRefresh: null,
                ),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            )
          : error != null
          ? buildProfileScrollView(
              slivers: [
                _UserProfileHeaderSliver(
                  title: strings.text('User profile'),
                  loading: loading,
                  onRefresh: load,
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _InlineError(message: error!, onRetry: load),
                ),
              ],
            )
          : loaded == null
          ? buildProfileScrollView(
              slivers: [
                _UserProfileHeaderSliver(
                  title: strings.text('User profile'),
                  loading: loading,
                  onRefresh: load,
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyPanel(message: strings.text('User not found.')),
                ),
              ],
            )
          : RefreshIndicator(
              onRefresh: load,
              child: buildProfileScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _UserProfileHeaderSliver(
                    title: loaded.displayName,
                    profile: loaded,
                    avatarHeroTag: widget.avatarHeroTag,
                    loading: loading,
                    onRefresh: load,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    sliver: SliverList.list(
                      children: [
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
                              infoRow(
                                Icons.info_outline,
                                strings.text('Client'),
                                loaded.platform,
                              ),
                              if (member != null)
                                infoRow(
                                  Icons.admin_panel_settings_outlined,
                                  strings.text('Group role'),
                                  member.roleLabel,
                                ),
                              if (member != null && member.memberLevel > 0)
                                infoRow(
                                  Icons.military_tech_outlined,
                                  strings.text('Member level'),
                                  'Lv.${member.memberLevel}',
                                ),
                              if (member != null &&
                                  member.memberTitle.isNotEmpty)
                                infoRow(
                                  Icons.workspace_premium_outlined,
                                  strings.text('Member title'),
                                  member.memberTitle,
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
                                const Divider(height: 1),
                                actionTile(
                                  icon: Icons.flag_outlined,
                                  title: strings.text('Report user'),
                                  color: colors.error,
                                  onTap: () => openReport(loaded),
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
                                  icon: Icons.military_tech_outlined,
                                  title: strings.text('Set member title'),
                                  onTap: editMemberTitle,
                                ),
                                const Divider(height: 1),
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
                        if (canDebugManageUser) ...[
                          const SizedBox(height: 20),
                          Text(
                            strings.text('Debug management actions'),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            elevation: 0,
                            child: Column(
                              children: [
                                actionTile(
                                  icon: Icons.block,
                                  title: strings.text('Ban user'),
                                  color: colors.error,
                                  onTap: () => banUser(loaded),
                                ),
                                const Divider(height: 1),
                                actionTile(
                                  icon: Icons.restore_from_trash_outlined,
                                  title: strings.text('Unban user'),
                                  onTap: () => unbanUser(loaded),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (createdGroups.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text(
                            strings.text(
                              isSelf
                                  ? 'Created groups'
                                  : 'Created public groups',
                            ),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          for (final group in createdGroups)
                            Card(
                              elevation: 0,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: _RoundedInkClip(
                                child: ListTile(
                                  leading: _Avatar(
                                    url: group.avatar,
                                    fallback: Icons.groups_rounded,
                                    name: group.name,
                                    backgroundColor: colors.secondaryContainer,
                                    foregroundColor:
                                        colors.onSecondaryContainer,
                                  ),
                                  title: Text(group.name),
                                  subtitle: Text(
                                    group.subtitle.isEmpty
                                        ? strings.format('Room {id}', {
                                            'id': group.id,
                                          })
                                        : group.subtitle,
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => openCreatedGroup(group),
                                ),
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
                ],
              ),
            ),
    );
  }
}

class _UserProfileHeaderSliver extends StatelessWidget {
  const _UserProfileHeaderSliver({
    required this.title,
    this.profile,
    this.avatarHeroTag,
    required this.loading,
    required this.onRefresh,
  });

  final String title;
  final UserProfile? profile;
  final Object? avatarHeroTag;
  final bool loading;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    final loaded = profile;
    final hasProfile = loaded != null;
    final expandedHeight = hasProfile ? 286.0 : 112.0;
    return SliverAppBar(
      pinned: true,
      stretch: !_MotionPreference.reduceOf(context),
      expandedHeight: expandedHeight,
      backgroundColor: hasProfile ? colors.primary : colors.surface,
      foregroundColor: hasProfile ? Colors.white : colors.onSurface,
      title: hasProfile ? const SizedBox.shrink() : Text(title),
      titleSpacing: hasProfile ? 0 : null,
      actions: [
        IconButton(
          tooltip: strings.text('Refresh'),
          onPressed: loading || onRefresh == null
              ? null
              : () => unawaited(onRefresh!()),
          icon: const Icon(Icons.refresh),
        ),
      ],
      flexibleSpace: hasProfile
          ? _UserProfileHeaderSpace(
              title: title,
              profile: loaded,
              avatarHeroTag: avatarHeroTag,
              expandedHeight: expandedHeight,
            )
          : null,
    );
  }
}

class _UserProfileHeaderSpace extends StatelessWidget {
  const _UserProfileHeaderSpace({
    required this.title,
    required this.profile,
    required this.avatarHeroTag,
    required this.expandedHeight,
  });

  final String title;
  final UserProfile profile;
  final Object? avatarHeroTag;
  final double expandedHeight;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final reduceMotion = _MotionPreference.reduceOf(context);
    final colors = Theme.of(context).colorScheme;
    final subtitle = profile.subtitle.isEmpty
        ? 'UID ${profile.uid}'
        : profile.subtitle;
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = topPadding + kToolbarHeight;
        final expansion = _unit(
          (constraints.maxHeight - minHeight) / (expandedHeight - minHeight),
        );
        final collapse = 1 - expansion;
        final avatarShrink = reduceMotion
            ? collapse
            : _profileHeaderInterval(
                collapse,
                begin: 0.04,
                end: 0.92,
                curve: Curves.easeInOutCubic,
              );
        final avatarMove = reduceMotion
            ? collapse
            : _profileHeaderInterval(
                collapse,
                begin: 0.02,
                end: 0.98,
                curve: Curves.easeInOutCubic,
              );
        final textMove = reduceMotion
            ? collapse
            : _profileHeaderInterval(
                collapse,
                begin: 0.08,
                end: 0.96,
                curve: Curves.easeInOutCubic,
              );
        final textScale = reduceMotion
            ? collapse
            : _profileHeaderInterval(
                collapse,
                begin: 0,
                end: 0.84,
                curve: Curves.easeOutCubic,
              );
        final subtitleOpacity = reduceMotion
            ? expansion
            : 1 -
                  _profileHeaderInterval(
                    collapse,
                    begin: 0.10,
                    end: 0.52,
                    curve: Curves.easeOutCubic,
                  );
        final avatarRadius = ui.lerpDouble(52, 17, avatarShrink)!;
        final collapsedLeft = Navigator.of(context).canPop() ? 56.0 : 20.0;
        const expandedLeft = 20.0;
        final avatarLeft = ui.lerpDouble(
          expandedLeft,
          collapsedLeft,
          avatarMove,
        )!;
        final collapsedCenterY = topPadding + kToolbarHeight / 2;
        final expandedCenterY = expandedHeight - 78;
        final avatarCenterY = ui.lerpDouble(
          expandedCenterY,
          collapsedCenterY,
          avatarMove,
        )!;
        final avatarTop = avatarCenterY - avatarRadius;
        final collapsedTitleLeft = collapsedLeft + 34 + 12;
        const expandedTitleLeft = expandedLeft + 104 + 18;
        final titleLeft = ui.lerpDouble(
          expandedTitleLeft,
          collapsedTitleLeft,
          textMove,
        )!;
        final collapsedTitleTop = topPadding + (kToolbarHeight - 24) / 2;
        final expandedTitleTop = expandedCenterY - 28;
        final titleTop = ui.lerpDouble(
          expandedTitleTop,
          collapsedTitleTop,
          textMove,
        )!;
        final titleWidth = math.max(
          96.0,
          constraints.maxWidth - titleLeft - 58,
        );
        final titleScale = ui.lerpDouble(1.22, 1.0, textScale)!;
        return Stack(
          fit: StackFit.expand,
          children: [
            _ProfileHeaderBackdrop(profile: profile),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.18),
                    colors.primary.withValues(alpha: 0.50),
                    Colors.black.withValues(alpha: 0.58),
                  ],
                  stops: const [0, 0.48, 1],
                ),
              ),
            ),
            Positioned(
              left: avatarLeft,
              top: avatarTop,
              child: _Avatar(
                url: profile.avatar,
                fallback: Icons.person_rounded,
                radius: avatarRadius,
                heroTag: avatarHeroTag,
                name: title,
                backgroundColor: Colors.white.withValues(alpha: 0.24),
                foregroundColor: Colors.white,
              ),
            ),
            Positioned(
              left: titleLeft,
              top: titleTop,
              width: titleWidth,
              child: Transform.scale(
                scale: titleScale,
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        shadows: const [
                          Shadow(
                            blurRadius: 12,
                            color: Colors.black45,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    IgnorePointer(
                      child: Opacity(
                        opacity: subtitleOpacity,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.84),
                                  shadows: const [
                                    Shadow(
                                      blurRadius: 10,
                                      color: Colors.black38,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

double _unit(double value) {
  return value.clamp(0.0, 1.0).toDouble();
}

double _profileHeaderCurve(double value, Curve curve) {
  return curve.transform(_unit(value));
}

double _profileHeaderInterval(
  double value, {
  required double begin,
  required double end,
  required Curve curve,
}) {
  if (end <= begin) {
    return _profileHeaderCurve(value, curve);
  }
  return curve.transform(_unit((value - begin) / (end - begin)));
}

class _ProfileHeaderBackdrop extends StatelessWidget {
  const _ProfileHeaderBackdrop({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.tertiary, colors.secondary],
        ),
      ),
    );
    if (profile.avatar.isEmpty) {
      return fallback;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        fallback,
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Transform.scale(
            scale: 1.08,
            child: Image.network(
              profile.avatar,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ),
      ],
    );
  }
}
