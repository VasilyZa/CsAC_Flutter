part of '../../main.dart';

class ConversationDetailScreen extends StatefulWidget {
  const ConversationDetailScreen({
    super.key,
    required this.state,
    required this.conversation,
  });

  final CsacAppState state;
  final Conversation conversation;

  @override
  State<ConversationDetailScreen> createState() =>
      _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  UserProfile? user;
  GroupProfile? group;
  List<GroupMember> members = const <GroupMember>[];
  List<CommonGroup> commonGroups = const <CommonGroup>[];
  bool loading = true;
  bool acting = false;
  String? error;

  GroupMember? get currentGroupMember {
    final currentUid = widget.state.user?.uid;
    if (currentUid == null) {
      return null;
    }
    return members.where((member) => member.uid == currentUid).firstOrNull;
  }

  bool get canManageCurrentGroup {
    final profile = group;
    final currentUid = widget.state.user?.uid;
    return (profile?.isOwner ?? false) ||
        (profile?.ownerUid != 0 && profile?.ownerUid == currentUid) ||
        (profile?.isAdmin ?? false) ||
        (profile?.hasAdminRole ?? false) ||
        (currentGroupMember?.hasAdminRole ?? false);
  }

  bool get currentUserIsGroupOwner {
    final profile = group;
    final currentUid = widget.state.user?.uid;
    return (profile?.isOwner ?? false) ||
        (profile?.ownerUid != 0 && profile?.ownerUid == currentUid) ||
        (profile?.hasOwnerRole ?? false) ||
        (currentGroupMember?.hasOwnerRole ?? false);
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
      if (widget.conversation.type == ConversationType.private) {
        final loaded = await widget.state.loadUserProfile(
          widget.conversation.id,
        );
        if (!mounted) {
          return;
        }
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
          user = loaded;
          commonGroups = groups;
        });
      } else {
        final results = await Future.wait<dynamic>([
          widget.state.loadGroupProfile(widget.conversation.id),
          widget.state.loadGroupMembers(widget.conversation.id),
        ]);
        if (!mounted) {
          return;
        }
        setState(() {
          group = results[0] as GroupProfile;
          members = results[1] as List<GroupMember>;
        });
      }
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

  Future<void> addFriend(UserProfile profile) async {
    final controller = TextEditingController(text: '请求添加你为好友');
    final strings = context.strings;
    final message = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          strings.format('Add {name}', {'name': profile.displayName}),
        ),
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
    try {
      await widget.state.sendFriendRequest(profile.uid, message);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('Friend request sent.'))),
      );
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.format('Request failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    }
  }

  Future<void> joinGroup(GroupProfile profile) async {
    final code = TextEditingController(text: profile.code);
    final answer = TextEditingController();
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.format('Join {name}', {'name': profile.name})),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (profile.question.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(profile.question),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: code,
              decoration: InputDecoration(
                labelText: strings.text('Invite code'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: answer,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: strings.text('Answer'),
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
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.text('Apply')),
          ),
        ],
      ),
    );
    final codeText = code.text;
    final answerText = answer.text;
    code.dispose();
    answer.dispose();
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await widget.state.applyJoinGroup(
        profile.id,
        code: codeText,
        answer: answerText,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('Join request sent.'))),
      );
      await load();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.format('Join failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    }
  }

  Future<void> editRemark(UserProfile profile) async {
    final controller = TextEditingController(text: profile.remark);
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
    try {
      await widget.state.updateFriendRemark(profile.uid, remark.trim());
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.text('Remark updated.'))));
      await load();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.format('Update failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    }
  }

  Future<void> deleteFriend(UserProfile profile) async {
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          strings.format('Delete {name}?', {'name': profile.displayName}),
        ),
        content: Text(
          strings.text('This friend will be removed from your list.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.text('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await widget.state.deleteFriend(profile.uid);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.text('Friend deleted.'))));
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.format('Delete failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    }
  }

  Future<void> blockFriend(UserProfile profile) async {
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          strings.format('Block {name}?', {'name': profile.displayName}),
        ),
        content: Text(strings.text('This friend will be blocked.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.text('Block')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await widget.state.blockFriend(profile.uid);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.text('Friend blocked.'))));
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.format('Block failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    }
  }

  Future<void> leaveGroup(GroupProfile profile) async {
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.format('Leave {name}?', {'name': profile.name})),
        content: Text(
          strings.text('This group will be removed from your chats.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.text('Leave')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await widget.state.leaveGroup(profile.id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(strings.text('Left group.'))));
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.format('Leave failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    }
  }

  Future<void> memberAction(GroupMember member, String action) async {
    final profile = group;
    if (profile == null) {
      return;
    }
    try {
      switch (action) {
        case 'mute10':
          await widget.state.muteGroupMember(profile.id, member.uid, 10);
          break;
        case 'unmute':
          await widget.state.muteGroupMember(profile.id, member.uid, 0);
          break;
        case 'kick':
          await widget.state.kickGroupMember(profile.id, member.uid);
          break;
        case 'admin':
          await widget.state.setGroupAdmin(profile.id, member.uid, true);
          break;
        case 'removeAdmin':
          await widget.state.setGroupAdmin(profile.id, member.uid, false);
          break;
      }
      if (!mounted) {
        return;
      }
      final strings = context.strings;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text('Member action completed.'))),
      );
      await load();
    } catch (err) {
      if (mounted) {
        final strings = context.strings;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              strings.format('Action failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    }
  }

  Future<void> showMemberActions(GroupMember member) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.volume_off_outlined),
              title: Text(context.strings.text('Mute 10 minutes')),
              onTap: () => Navigator.of(context).pop('mute10'),
            ),
            ListTile(
              leading: const Icon(Icons.volume_up_outlined),
              title: Text(context.strings.text('Unmute')),
              onTap: () => Navigator.of(context).pop('unmute'),
            ),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: Text(context.strings.text('Set admin')),
              onTap: () => Navigator.of(context).pop('admin'),
            ),
            ListTile(
              leading: const Icon(Icons.remove_moderator_outlined),
              title: Text(context.strings.text('Remove admin')),
              onTap: () => Navigator.of(context).pop('removeAdmin'),
            ),
            ListTile(
              leading: Icon(
                Icons.person_remove_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                context.strings.text('Kick member'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.of(context).pop('kick'),
            ),
          ],
        ),
      ),
    );
    if (action != null) {
      await memberAction(member, action);
    }
  }

  Future<void> openGroupManagement(GroupProfile profile) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupManagementScreen(
          state: widget.state,
          group: profile,
          initialMembers: members,
          canManageOverride: canManageCurrentGroup,
          isOwnerOverride: currentUserIsGroupOwner,
        ),
      ),
    );
    if (mounted) {
      await load();
    }
  }

  void copyText(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.strings.format('{label} copied.', {'label': label}),
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
    );
  }

  Widget buildUserProfile(UserProfile profile) {
    return UserProfileScreen(
      state: widget.state,
      uid: profile.uid,
      key: ValueKey(profile.uid),
    );
  }

  Widget buildGroupProfile(GroupProfile profile) {
    final strings = context.strings;
    final canManageGroup = canManageCurrentGroup;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: Icon(
                Icons.groups_rounded,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            title: Text(profile.name),
            subtitle: Text(
              profile.subtitle.isEmpty
                  ? strings.format('Room {id}', {'id': profile.id})
                  : profile.subtitle,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.tag),
                  title: Text(strings.text('Room ID')),
                  subtitle: SelectableText('${profile.id}'),
                  trailing: IconButton(
                    tooltip: strings.text('Copy room ID'),
                    onPressed: () =>
                        copyText(strings.text('Room ID'), '${profile.id}'),
                    icon: const Icon(Icons.copy),
                  ),
                ),
                infoRow(
                  Icons.info_outline,
                  strings.text('Description'),
                  profile.description,
                ),
                infoRow(
                  Icons.campaign_outlined,
                  strings.text('Notice'),
                  profile.notice,
                ),
                if (profile.inviteCode.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: Text(strings.text('Invite code')),
                    subtitle: SelectableText(profile.inviteCode),
                    trailing: IconButton(
                      tooltip: strings.text('Copy invite code'),
                      onPressed: () => copyText(
                        strings.text('Invite code'),
                        profile.inviteCode,
                      ),
                      icon: const Icon(Icons.copy),
                    ),
                  ),
                infoRow(
                  Icons.lock_outline,
                  strings.text('Fixed code'),
                  profile.code,
                ),
                infoRow(
                  Icons.question_answer_outlined,
                  strings.text('Question'),
                  profile.question,
                ),
              ],
            ),
          ),
          if (canManageGroup) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => openGroupManagement(profile),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: Text(strings.text('Group management')),
            ),
          ],
          if (!profile.isInGroup) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => joinGroup(profile),
              icon: const Icon(Icons.group_add),
              label: Text(strings.text('Apply to join')),
            ),
          ] else ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => leaveGroup(profile),
              icon: const Icon(Icons.logout),
              label: Text(strings.text('Leave group')),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.text('Members'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text('${members.length}'),
            ],
          ),
          const SizedBox(height: 8),
          if (members.isEmpty)
            _EmptyPanel(message: strings.text('No members.'))
          else
            for (final member in members)
              Card(
                elevation: 0,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: _RoundedInkClip(
                  child: ListTile(
                    leading: _Avatar(
                      url: member.avatar,
                      fallback: Icons.person_rounded,
                    ),
                    title: Text(member.name),
                    subtitle: member.subtitle.isEmpty
                        ? Text('UID ${member.uid}')
                        : Text(member.subtitle),
                    onTap: () => openUserProfile(
                      context,
                      widget.state,
                      member.uid,
                      group: profile,
                      member: member,
                    ),
                    trailing: canManageGroup
                        ? IconButton(
                            tooltip: strings.text('Manage'),
                            onPressed: () => showMemberActions(member),
                            icon: const Icon(Icons.more_vert),
                          )
                        : null,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.conversation.type == ConversationType.private) {
      return UserProfileScreen(
        state: widget.state,
        uid: widget.conversation.id,
      );
    }
    final title = widget.conversation.type == ConversationType.group
        ? context.strings.text('Group details')
        : context.strings.text('User details');
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: context.strings.text('Refresh'),
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
            : widget.conversation.type == ConversationType.private
            ? buildUserProfile(user!)
            : buildGroupProfile(group!),
      ),
    );
  }
}

class GroupManagementScreen extends StatefulWidget {
  const GroupManagementScreen({
    super.key,
    required this.state,
    required this.group,
    this.initialMembers = const <GroupMember>[],
    this.canManageOverride = false,
    this.isOwnerOverride = false,
  });

  final CsacAppState state;
  final GroupProfile group;
  final List<GroupMember> initialMembers;
  final bool canManageOverride;
  final bool isOwnerOverride;

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  late GroupProfile group;
  late List<GroupMember> members;
  List<GroupApplication> applications = const <GroupApplication>[];
  bool loading = true;
  bool acting = false;
  int? actingApplicationId;
  String? error;

  GroupMember? get currentMember {
    final currentUid = widget.state.user?.uid;
    if (currentUid == null) {
      return null;
    }
    return members.where((member) => member.uid == currentUid).firstOrNull;
  }

  bool get currentUserIsOwner {
    final currentUid = widget.state.user?.uid;
    return widget.isOwnerOverride ||
        group.isOwner ||
        (group.ownerUid != 0 && group.ownerUid == currentUid) ||
        group.hasOwnerRole ||
        (currentMember?.hasOwnerRole ?? false);
  }

  bool get canManage {
    final currentUid = widget.state.user?.uid;
    return widget.canManageOverride ||
        group.isOwner ||
        (group.ownerUid != 0 && group.ownerUid == currentUid) ||
        group.isAdmin ||
        group.hasAdminRole ||
        (currentMember?.hasAdminRole ?? false);
  }

  @override
  void initState() {
    super.initState();
    group = widget.group;
    members = widget.initialMembers;
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        widget.state.loadGroupProfile(group.id),
        widget.state.loadGroupMembers(group.id),
        widget.state.client.groupApplications(
          roomId: group.id,
          roomName: group.name,
        ),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        group = results[0] as GroupProfile;
        members = results[1] as List<GroupMember>;
        applications = results[2] as List<GroupApplication>;
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

  void showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> runAction(
    Future<void> Function() action,
    String success, {
    bool reload = true,
  }) async {
    setState(() => acting = true);
    try {
      await action();
      if (!mounted) {
        return;
      }
      showSnack(context.strings.text(success));
      if (reload) {
        await load();
      }
    } catch (err) {
      if (mounted) {
        showSnack(
          context.strings.format('Action failed: {error}', {'error': err}),
        );
      }
    } finally {
      if (mounted) {
        setState(() => acting = false);
      }
    }
  }

  Future<void> editInfo() async {
    final roomName = TextEditingController(text: group.name);
    final description = TextEditingController(text: group.description);
    final notice = TextEditingController(text: group.notice);
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('Edit group info')),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: roomName,
                decoration: InputDecoration(
                  labelText: strings.text('Room name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: description,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: strings.text('Description'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notice,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: strings.text('Notice'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.text('Save')),
          ),
        ],
      ),
    );
    final nameText = roomName.text.trim();
    final descriptionText = description.text;
    final noticeText = notice.text;
    roomName.dispose();
    description.dispose();
    notice.dispose();
    if (confirmed != true || !mounted) {
      return;
    }
    if (nameText.isEmpty) {
      showSnack(strings.text('Room name is required.'));
      return;
    }
    await runAction(
      () => widget.state.editGroupInfo(
        group.id,
        roomName: nameText,
        description: descriptionText,
        notice: noticeText,
      ),
      'Group info updated.',
    );
  }

  Future<void> editSettings() async {
    final joinType = TextEditingController(text: group.joinType);
    final code = TextEditingController(text: group.code);
    final question = TextEditingController(text: group.question);
    final answer = TextEditingController(text: group.answer);
    var showPublic = group.showPublic;
    final strings = context.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(strings.text('Group settings')),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: joinType,
                  decoration: InputDecoration(
                    labelText: strings.text('Join type'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: code,
                  decoration: InputDecoration(
                    labelText: strings.text('Fixed code'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: question,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: strings.text('Review question'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: answer,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: strings.text('Review answer'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(strings.text('Show publicly')),
                  value: showPublic,
                  onChanged: (value) =>
                      setDialogState(() => showPublic = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.text('Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(strings.text('Save')),
            ),
          ],
        ),
      ),
    );
    final joinTypeText = joinType.text;
    final codeText = code.text;
    final questionText = question.text;
    final answerText = answer.text;
    joinType.dispose();
    code.dispose();
    question.dispose();
    answer.dispose();
    if (confirmed != true || !mounted) {
      return;
    }
    await runAction(
      () => widget.state.updateGroupSettings(
        group.id,
        joinType: joinTypeText,
        code: codeText,
        question: questionText,
        answer: answerText,
        showPublic: showPublic,
      ),
      'Group settings updated.',
    );
  }

  Future<void> handleApplication(
    GroupApplication application,
    String action,
  ) async {
    setState(() => actingApplicationId = application.id);
    try {
      await widget.state.handleGroupApplication(application.id, action);
      if (!mounted) {
        return;
      }
      showSnack(context.strings.text('Application handled.'));
      await load();
    } catch (err) {
      if (mounted) {
        showSnack(
          context.strings.format('Action failed: {error}', {'error': err}),
        );
      }
    } finally {
      if (mounted) {
        setState(() => actingApplicationId = null);
      }
    }
  }

  Future<void> memberAction(GroupMember member, String action) async {
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

  Future<void> showMemberActions(GroupMember member) async {
    final actions = <String>[
      'mute10',
      'unmute',
      if (currentUserIsOwner && !member.hasOwnerRole) ...[
        'admin',
        'removeAdmin',
      ],
      if (!member.hasOwnerRole) 'kick',
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (actions.contains('mute10'))
              ListTile(
                leading: const Icon(Icons.volume_off_outlined),
                title: Text(context.strings.text('Mute 10 minutes')),
                onTap: () => Navigator.of(context).pop('mute10'),
              ),
            if (actions.contains('unmute'))
              ListTile(
                leading: const Icon(Icons.volume_up_outlined),
                title: Text(context.strings.text('Unmute')),
                onTap: () => Navigator.of(context).pop('unmute'),
              ),
            if (actions.contains('admin'))
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(context.strings.text('Set admin')),
                onTap: () => Navigator.of(context).pop('admin'),
              ),
            if (actions.contains('removeAdmin'))
              ListTile(
                leading: const Icon(Icons.remove_moderator_outlined),
                title: Text(context.strings.text('Remove admin')),
                onTap: () => Navigator.of(context).pop('removeAdmin'),
              ),
            if (actions.contains('kick'))
              ListTile(
                leading: Icon(
                  Icons.person_remove_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  context.strings.text('Kick member'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => Navigator.of(context).pop('kick'),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      await memberAction(member, selected);
    }
  }

  Future<void> resetInviteCode() async {
    final ok = await confirm(
      context.strings.text('Reset invite code?'),
      context.strings.text('The old invite code will stop working.'),
      context.strings.text('Reset'),
    );
    if (!ok || !mounted) {
      return;
    }
    await runAction(
      () => widget.state.resetInviteCode(group.id),
      'Invite code reset.',
    );
  }

  Future<void> transferGroup() async {
    final target = await chooseMember(
      context.strings.text('Transfer owner to'),
      members
          .where((member) => member.uid != widget.state.user?.uid)
          .where((member) => !member.hasOwnerRole)
          .toList(),
    );
    if (target == null || !mounted) {
      return;
    }
    final ok = await confirm(
      context.strings.format('Transfer group to {name}?', {
        'name': target.name,
      }),
      context.strings.text('You will lose owner permissions after transfer.'),
      context.strings.text('Transfer'),
    );
    if (!ok || !mounted) {
      return;
    }
    await runAction(
      () => widget.state.transferGroup(group.id, target.uid),
      'Group transferred.',
    );
  }

  Future<void> disbandGroup() async {
    final ok = await confirm(
      context.strings.format('Disband {name}?', {'name': group.name}),
      context.strings.text('This group will be permanently disbanded.'),
      context.strings.text('Disband'),
    );
    if (!ok || !mounted) {
      return;
    }
    await runAction(
      () => widget.state.disbandGroup(group.id),
      'Group disbanded.',
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<GroupMember?> chooseMember(
    String title,
    List<GroupMember> candidates,
  ) {
    return showModalBottomSheet<GroupMember>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: candidates.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(context.strings.text('No selectable members.')),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  for (final member in candidates)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: _RoundedInkClip(
                        child: ListTile(
                          leading: _Avatar(
                            url: member.avatar,
                            fallback: Icons.person_rounded,
                          ),
                          title: Text(member.name),
                          subtitle: Text(
                            member.subtitle.isEmpty
                                ? 'UID ${member.uid}'
                                : member.subtitle,
                          ),
                          onTap: () => Navigator.of(context).pop(member),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Future<bool> confirm(String title, String message, String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Widget sectionTitle(String title, [String? trailing]) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null) Text(trailing),
      ],
    );
  }

  Widget actionTile({
    required IconData icon,
    required String title,
    required VoidCallback? onTap,
    String subtitle = '',
    Color? color,
  }) {
    return ListTile(
      enabled: !acting && onTap != null,
      leading: Icon(icon, color: color),
      title: Text(title, style: color == null ? null : TextStyle(color: color)),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: acting ? null : onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.text('Group management')),
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
            : !canManage
            ? _EmptyPanel(message: strings.text('No management permission.'))
            : RefreshIndicator(
                onRefresh: load,
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
                              backgroundColor: colors.secondaryContainer,
                              child: Icon(
                                Icons.groups_rounded,
                                color: colors.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    [
                                      strings.format('Room {id}', {
                                        'id': group.id,
                                      }),
                                      if (currentUserIsOwner)
                                        strings.text('Owner')
                                      else if (group.isAdmin)
                                        strings.text('Admin'),
                                    ].join(' | '),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    sectionTitle(strings.text('Group settings')),
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      child: _RoundedInkClip(
                        child: Column(
                          children: [
                            actionTile(
                              icon: Icons.edit_note,
                              title: strings.text('Edit group info'),
                              subtitle: group.description,
                              onTap: editInfo,
                            ),
                            const Divider(height: 1),
                            actionTile(
                              icon: Icons.tune,
                              title: strings.text('Join settings'),
                              subtitle: group.joinType,
                              onTap: editSettings,
                            ),
                            const Divider(height: 1),
                            actionTile(
                              icon: Icons.refresh,
                              title: strings.text('Reset invite code'),
                              subtitle: group.inviteCode,
                              onTap: resetInviteCode,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    sectionTitle(
                      strings.text('Group applications'),
                      '${applications.where((item) => item.pending).length}',
                    ),
                    const SizedBox(height: 8),
                    if (applications.isEmpty)
                      _EmptyPanel(
                        message: strings.text('No group applications.'),
                      )
                    else
                      for (final application in applications)
                        Card(
                          elevation: 0,
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: _Avatar(
                                    url: application.avatar,
                                    fallback: Icons.person_rounded,
                                  ),
                                  title: Text(application.nickname),
                                  subtitle: Text(
                                    application.username.isEmpty
                                        ? 'UID ${application.uid}'
                                        : '@${application.username} | UID ${application.uid}',
                                  ),
                                  trailing: _StatusChip(
                                    pending: application.pending,
                                  ),
                                  onTap: () => openUserProfile(
                                    context,
                                    widget.state,
                                    application.uid,
                                    group: group,
                                  ),
                                ),
                                if (application.content.isNotEmpty ||
                                    application.answer.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      application.content.isEmpty
                                          ? application.answer
                                          : application.content,
                                    ),
                                  ),
                                if (application.pending) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed:
                                            actingApplicationId ==
                                                application.id
                                            ? null
                                            : () => handleApplication(
                                                application,
                                                'refuse',
                                              ),
                                        child: Text(strings.text('Refuse')),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton.icon(
                                        onPressed:
                                            actingApplicationId ==
                                                application.id
                                            ? null
                                            : () => handleApplication(
                                                application,
                                                'pass',
                                              ),
                                        icon:
                                            actingApplicationId ==
                                                application.id
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(Icons.check),
                                        label: Text(strings.text('Pass')),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    const SizedBox(height: 20),
                    sectionTitle(strings.text('Members'), '${members.length}'),
                    const SizedBox(height: 8),
                    for (final member in members)
                      Card(
                        elevation: 0,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: _RoundedInkClip(
                          child: ListTile(
                            leading: _Avatar(
                              url: member.avatar,
                              fallback: Icons.person_rounded,
                            ),
                            title: Text(member.name),
                            subtitle: member.subtitle.isEmpty
                                ? Text('UID ${member.uid}')
                                : Text(member.subtitle),
                            onTap: () => openUserProfile(
                              context,
                              widget.state,
                              member.uid,
                              group: group,
                              member: member,
                            ),
                            trailing: IconButton(
                              tooltip: strings.text('Manage'),
                              onPressed: acting
                                  ? null
                                  : () => showMemberActions(member),
                              icon: const Icon(Icons.more_vert),
                            ),
                          ),
                        ),
                      ),
                    if (currentUserIsOwner) ...[
                      const SizedBox(height: 20),
                      sectionTitle(strings.text('Owner actions')),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 0,
                        child: _RoundedInkClip(
                          child: Column(
                            children: [
                              actionTile(
                                icon: Icons.swap_horiz,
                                title: strings.text('Transfer group owner'),
                                onTap: transferGroup,
                              ),
                              const Divider(height: 1),
                              actionTile(
                                icon: Icons.delete_forever_outlined,
                                title: strings.text('Disband group'),
                                color: colors.error,
                                onTap: disbandGroup,
                              ),
                            ],
                          ),
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
