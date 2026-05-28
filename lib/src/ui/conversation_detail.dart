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

  bool get groupUnavailable {
    return widget.conversation.type == ConversationType.group &&
        error == context.strings.text('This group is no longer available.');
  }

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
        if (widget.conversation.type == ConversationType.group &&
            isGroupUnavailableError(err)) {
          await widget.state.removeConversationLocal(widget.conversation);
          if (!mounted) {
            return;
          }
          setState(
            () => error = context.strings.text(
              'This group is no longer available.',
            ),
          );
          _showCupertinoToast(
            context,
            context.strings.text('This group has been removed from chats.'),
          );
        } else {
          setState(() => error = err.toString());
        }
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
    final message = await showCupertinoDialog<String>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(
          strings.format('Add {name}', {'name': profile.displayName}),
        ),
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
    try {
      await widget.state.sendFriendRequest(profile.uid, message);
      if (!mounted) {
        return;
      }
      _showCupertinoToast(context, strings.text('Friend request sent.'));
    } catch (err) {
      if (mounted) {
        _showCupertinoToast(
          context,
          strings.format('Request failed: {error}', {'error': err}),
        );
      }
    }
  }

  Future<void> joinGroup(GroupProfile profile) async {
    final code = TextEditingController(text: profile.code);
    final answer = TextEditingController();
    final strings = context.strings;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(strings.format('Join {name}', {'name': profile.name})),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (profile.question.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(profile.question),
                ),
              ),
            ],
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: code,
              placeholder: strings.text('Invite code'),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: answer,
              maxLines: 2,
              placeholder: strings.text('Answer'),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.text('Cancel')),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
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
      _showCupertinoToast(context, strings.text('Join request sent.'));
      await load();
    } catch (err) {
      if (mounted) {
        _showCupertinoToast(
          context,
          strings.format('Join failed: {error}', {'error': err}),
        );
      }
    }
  }

  Future<void> editRemark(UserProfile profile) async {
    final controller = TextEditingController(text: profile.remark);
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
    try {
      await widget.state.updateFriendRemark(profile.uid, remark.trim());
      if (!mounted) {
        return;
      }
      _showCupertinoToast(context, strings.text('Remark updated.'));
      await load();
    } catch (err) {
      if (mounted) {
        _showCupertinoToast(
          context,
          strings.format('Update failed: {error}', {'error': err}),
        );
      }
    }
  }

  Future<void> deleteFriend(UserProfile profile) async {
    final strings = context.strings;
    final confirmed = await _showCupertinoConfirm(
      context,
      title: strings.format('Delete {name}?', {'name': profile.displayName}),
      message: strings.text('This friend will be removed from your list.'),
      confirmText: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await widget.state.deleteFriend(profile.uid);
      if (!mounted) {
        return;
      }
      _showCupertinoToast(context, strings.text('Friend deleted.'));
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        _showCupertinoToast(
          context,
          strings.format('Delete failed: {error}', {'error': err}),
        );
      }
    }
  }

  Future<void> blockFriend(UserProfile profile) async {
    final strings = context.strings;
    final confirmed = await _showCupertinoConfirm(
      context,
      title: strings.format('Block {name}?', {'name': profile.displayName}),
      message: strings.text('This friend will be blocked.'),
      confirmText: 'Block',
      isDestructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await widget.state.blockFriend(profile.uid);
      if (!mounted) {
        return;
      }
      _showCupertinoToast(context, strings.text('Friend blocked.'));
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        _showCupertinoToast(
          context,
          strings.format('Block failed: {error}', {'error': err}),
        );
      }
    }
  }

  Future<void> leaveGroup(GroupProfile profile) async {
    final strings = context.strings;
    final confirmed = await _showCupertinoConfirm(
      context,
      title: strings.format('Leave {name}?', {'name': profile.name}),
      message: strings.text('This group will be removed from your chats.'),
      confirmText: 'Leave',
      isDestructive: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await widget.state.leaveGroup(profile.id);
      if (!mounted) {
        return;
      }
      _showCupertinoToast(context, strings.text('Left group.'));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (err) {
      if (mounted) {
        if (isGroupUnavailableError(err)) {
          await widget.state.removeConversationLocal(widget.conversation);
          if (!mounted) {
            return;
          }
          _showCupertinoToast(
            context,
            strings.text('This group has been removed from chats.'),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
          return;
        }
        _showCupertinoToast(
          context,
          strings.format('Leave failed: {error}', {'error': err}),
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
      _showCupertinoToast(context, strings.text('Member action completed.'));
      await load();
    } catch (err) {
      if (mounted) {
        final strings = context.strings;
        _showCupertinoToast(
          context,
          strings.format('Action failed: {error}', {'error': err}),
        );
      }
    }
  }

  Future<void> showMemberActions(GroupMember member) async {
    final strings = context.strings;
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('mute10'),
            child: Text(strings.text('Mute 10 minutes')),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('unmute'),
            child: Text(strings.text('Unmute')),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('admin'),
            child: Text(strings.text('Set admin')),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('removeAdmin'),
            child: Text(strings.text('Remove admin')),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop('kick'),
            child: Text(strings.text('Kick member')),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(strings.text('Cancel')),
        ),
      ),
    );
    if (action != null) {
      await memberAction(member, action);
    }
  }

  Future<void> openGroupManagement(GroupProfile profile) async {
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
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
    _showCupertinoToast(
      context,
      context.strings.format('{label} copied.', {'label': label}),
    );
  }

  Widget buildGroupProfile(GroupProfile profile) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final canManageGroup = canManageCurrentGroup;
    return CustomScrollView(
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: load),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
            child: Column(
              children: [
                // Group header
                _CupertinoGroupedCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: colors.elevatedBackground,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Icon(
                              CupertinoIcons.group_solid,
                              color: colors.secondaryLabel,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.name,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: colors.label,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  profile.subtitle.isEmpty
                                      ? strings.format('Room {id}', {
                                          'id': profile.id,
                                        })
                                      : profile.subtitle,
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
                const SizedBox(height: 6),
                // Group info card
                _CupertinoGroupedCard(
                  children: [
                    _CupertinoListTile(
                      leading: Icon(
                        CupertinoIcons.number,
                        size: 20,
                        color: colors.secondaryLabel,
                      ),
                      title: strings.text('Room ID'),
                      subtitle: '${profile.id}',
                      trailing: GestureDetector(
                        onTap: () =>
                            copyText(strings.text('Room ID'), '${profile.id}'),
                        child: Icon(
                          CupertinoIcons.doc_on_doc,
                          size: 18,
                          color: colors.tertiaryLabel,
                        ),
                      ),
                    ),
                    if (profile.description.isNotEmpty)
                      _CupertinoListTile(
                        leading: Icon(
                          CupertinoIcons.info,
                          size: 20,
                          color: colors.secondaryLabel,
                        ),
                        title: strings.text('Description'),
                        subtitle: profile.description,
                      ),
                    if (profile.notice.isNotEmpty)
                      _CupertinoListTile(
                        leading: Icon(
                          CupertinoIcons.speaker_2,
                          size: 20,
                          color: colors.secondaryLabel,
                        ),
                        title: strings.text('Notice'),
                        subtitle: profile.notice,
                      ),
                    if (profile.inviteCode.isNotEmpty)
                      _CupertinoListTile(
                        leading: Icon(
                          CupertinoIcons.lock,
                          size: 20,
                          color: colors.secondaryLabel,
                        ),
                        title: strings.text('Invite code'),
                        subtitle: profile.inviteCode,
                        trailing: GestureDetector(
                          onTap: () => copyText(
                            strings.text('Invite code'),
                            profile.inviteCode,
                          ),
                          child: Icon(
                            CupertinoIcons.doc_on_doc,
                            size: 18,
                            color: colors.tertiaryLabel,
                          ),
                        ),
                      ),
                    if (profile.code.isNotEmpty)
                      _CupertinoListTile(
                        leading: Icon(
                          CupertinoIcons.lock_shield,
                          size: 20,
                          color: colors.secondaryLabel,
                        ),
                        title: strings.text('Fixed code'),
                        subtitle: profile.code,
                      ),
                    if (profile.question.isNotEmpty)
                      _CupertinoListTile(
                        leading: Icon(
                          CupertinoIcons.question_circle,
                          size: 20,
                          color: colors.secondaryLabel,
                        ),
                        title: strings.text('Question'),
                        subtitle: profile.question,
                      ),
                  ],
                ),
                // Action buttons
                if (canManageGroup) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: CupertinoButton.filled(
                        onPressed: () => openGroupManagement(profile),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.shield, size: 18),
                            const SizedBox(width: 6),
                            Text(strings.text('Group management')),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (!profile.isInGroup) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: CupertinoButton.filled(
                        onPressed: () => joinGroup(profile),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(CupertinoIcons.person_add, size: 18),
                            const SizedBox(width: 6),
                            Text(strings.text('Apply to join')),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        color: CupertinoColors.destructiveRed,
                        onPressed: () => leaveGroup(profile),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              CupertinoIcons.square_arrow_left,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(strings.text('Leave group')),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                // Members section
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          strings.text('Members'),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: colors.label,
                          ),
                        ),
                      ),
                      Text(
                        '${members.length}',
                        style: TextStyle(
                          fontSize: 15,
                          color: colors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (members.isEmpty)
                  _EmptyPanel(message: strings.text('No members.'))
                else
                  _CupertinoGroupedCard(
                    children: [
                      for (final member in members)
                        _CupertinoListTile(
                          leading: _Avatar(
                            url: member.avatar,
                            fallback: CupertinoIcons.person_solid,
                          ),
                          title: member.name,
                          subtitle: member.subtitle.isEmpty
                              ? 'UID ${member.uid}'
                              : member.subtitle,
                          onTap: () => openUserProfile(
                            context,
                            widget.state,
                            member.uid,
                            group: profile,
                            member: member,
                          ),
                          trailing: canManageGroup
                              ? GestureDetector(
                                  onTap: () => showMemberActions(member),
                                  child: Icon(
                                    CupertinoIcons.ellipsis,
                                    size: 20,
                                    color: colors.tertiaryLabel,
                                  ),
                                )
                              : null,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
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
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final title = widget.conversation.type == ConversationType.group
        ? strings.text('Group details')
        : strings.text('User details');
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        backgroundColor: CsacColors.of(context).navBarBackground,
        middle: Text(title),
        trailing: GestureDetector(
          onTap: loading ? null : load,
          child: Icon(
            CupertinoIcons.refresh,
            size: 22,
            color: loading ? colors.tertiaryLabel : colors.primaryColor,
          ),
        ),
      ),
      child: SafeArea(
        child: loading
            ? const Center(child: CupertinoActivityIndicator())
            : error != null
            ? groupUnavailable
                  ? _EmptyPanel(message: error!)
                  : _InlineError(message: error!, onRetry: load)
            : widget.conversation.type == ConversationType.private
            ? UserProfileScreen(
                state: widget.state,
                uid: widget.conversation.id,
              )
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

  bool get groupUnavailable {
    return error == context.strings.text('This group is no longer available.');
  }

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
        if (isGroupUnavailableError(err)) {
          await widget.state.removeGroupConversationLocal(group.id);
          if (!mounted) {
            return;
          }
          setState(
            () => error = context.strings.text(
              'This group is no longer available.',
            ),
          );
          showSnack(
            context.strings.text('This group has been removed from chats.'),
          );
        } else {
          setState(() => error = err.toString());
        }
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void showSnack(String message) {
    _showCupertinoToast(context, message);
  }

  Future<bool> runAction(
    Future<void> Function() action,
    String success, {
    bool reload = true,
  }) async {
    setState(() => acting = true);
    try {
      await action();
      if (!mounted) {
        return false;
      }
      showSnack(context.strings.text(success));
      if (reload) {
        await load();
      }
      return true;
    } catch (err) {
      if (mounted) {
        if (isGroupUnavailableError(err)) {
          await widget.state.removeGroupConversationLocal(group.id);
          if (!mounted) {
            return false;
          }
          showSnack(
            context.strings.text('This group has been removed from chats.'),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
          return true;
        }
        showSnack(
          context.strings.format('Action failed: {error}', {'error': err}),
        );
      }
      return false;
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
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(strings.text('Edit group info')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: roomName,
              placeholder: strings.text('Room name'),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: description,
              maxLines: 2,
              placeholder: strings.text('Description'),
            ),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: notice,
              maxLines: 3,
              placeholder: strings.text('Notice'),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.text('Cancel')),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
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
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: Text(strings.text('Group settings')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: joinType,
                placeholder: strings.text('Join type'),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: code,
                placeholder: strings.text('Fixed code'),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: question,
                maxLines: 2,
                placeholder: strings.text('Review question'),
              ),
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: answer,
                maxLines: 2,
                placeholder: strings.text('Review answer'),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    strings.text('Show publicly'),
                    style: const TextStyle(fontSize: 15),
                  ),
                  CupertinoSwitch(
                    value: showPublic,
                    onChanged: (value) =>
                        setDialogState(() => showPublic = value),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(strings.text('Cancel')),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
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
    final strings = context.strings;
    final actions = <String>[
      'mute10',
      'unmute',
      if (currentUserIsOwner && !member.hasOwnerRole) ...[
        'admin',
        'removeAdmin',
      ],
      if (!member.hasOwnerRole) 'kick',
    ];
    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          if (actions.contains('mute10'))
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('mute10'),
              child: Text(strings.text('Mute 10 minutes')),
            ),
          if (actions.contains('unmute'))
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('unmute'),
              child: Text(strings.text('Unmute')),
            ),
          if (actions.contains('admin'))
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('admin'),
              child: Text(strings.text('Set admin')),
            ),
          if (actions.contains('removeAdmin'))
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('removeAdmin'),
              child: Text(strings.text('Remove admin')),
            ),
          if (actions.contains('kick'))
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop('kick'),
              child: Text(strings.text('Kick member')),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(strings.text('Cancel')),
        ),
      ),
    );
    if (selected != null) {
      await memberAction(member, selected);
    }
  }

  Future<void> resetInviteCode() async {
    final strings = context.strings;
    final ok = await _showCupertinoConfirm(
      context,
      title: strings.text('Reset invite code?'),
      message: strings.text('The old invite code will stop working.'),
      confirmText: 'Reset',
      isDestructive: true,
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
    final strings = context.strings;
    final target = await chooseMember(
      strings.text('Transfer owner to'),
      members
          .where((member) => member.uid != widget.state.user?.uid)
          .where((member) => !member.hasOwnerRole)
          .toList(),
    );
    if (target == null || !mounted) {
      return;
    }
    final ok = await _showCupertinoConfirm(
      context,
      title: strings.format('Transfer group to {name}?', {'name': target.name}),
      message: strings.text('You will lose owner permissions after transfer.'),
      confirmText: 'Transfer',
      isDestructive: true,
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
    final strings = context.strings;
    final ok = await _showCupertinoConfirm(
      context,
      title: strings.format('Disband {name}?', {'name': group.name}),
      message: strings.text('This group will be permanently disbanded.'),
      confirmText: 'Disband',
      isDestructive: true,
    );
    if (!ok || !mounted) {
      return;
    }
    final success = await runAction(
      () => widget.state.disbandGroup(group.id),
      'Group disbanded.',
      reload: false,
    );
    if (mounted && success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<GroupMember?> chooseMember(
    String title,
    List<GroupMember> candidates,
  ) {
    final colors = CsacColors.of(context);
    return showCupertinoModalPopup<GroupMember>(
      context: context,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: SafeArea(
          top: false,
          child: candidates.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    context.strings.text('No selectable members.'),
                    style: TextStyle(color: colors.secondaryLabel),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: colors.label,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(null),
                            child: Icon(
                              CupertinoIcons.xmark_circle_fill,
                              color: colors.tertiaryLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final member in candidates)
                            _CupertinoListTile(
                              leading: _Avatar(
                                url: member.avatar,
                                fallback: CupertinoIcons.person_solid,
                              ),
                              title: member.name,
                              subtitle: member.subtitle.isEmpty
                                  ? 'UID ${member.uid}'
                                  : member.subtitle,
                              onTap: () => Navigator.of(context).pop(member),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> reportGroup(GroupProfile profile) {
    return showReportDialog(
      context: context,
      state: widget.state,
      type: 'group',
      title: context.strings.text('Report group'),
      rid: profile.id,
      roomName: profile.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        border: null,
        backgroundColor: CsacColors.of(context).navBarBackground,
        middle: Text(strings.text('Group management')),
        trailing: GestureDetector(
          onTap: loading ? null : load,
          child: Icon(
            CupertinoIcons.refresh,
            size: 22,
            color: loading ? colors.tertiaryLabel : colors.primaryColor,
          ),
        ),
      ),
      child: SafeArea(
        child: loading
            ? const Center(child: CupertinoActivityIndicator())
            : error != null
            ? groupUnavailable
                  ? _EmptyPanel(message: error!)
                  : _InlineError(message: error!, onRetry: load)
            : !canManage
            ? _EmptyPanel(message: strings.text('No management permission.'))
            : CustomScrollView(
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: load),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
                      child: Column(
                        children: [
                          // Group header card
                          _CupertinoGroupedCard(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: colors.elevatedBackground,
                                        borderRadius: BorderRadius.circular(22),
                                      ),
                                      child: Icon(
                                        CupertinoIcons.group_solid,
                                        color: colors.secondaryLabel,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            group.name,
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w600,
                                              color: colors.label,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
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
                          const SizedBox(height: 6),
                          // Report
                          _CupertinoGroupedCard(
                            children: [
                              _CupertinoListTile(
                                leading: Icon(
                                  CupertinoIcons.flag,
                                  size: 20,
                                  color: CupertinoColors.destructiveRed,
                                ),
                                title: strings.text('Report group'),
                                titleColor: CupertinoColors.destructiveRed,
                                onTap: () => reportGroup(group),
                              ),
                            ],
                          ),
                          // Group settings section
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                strings.text('Group settings'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colors.secondaryLabel,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _CupertinoGroupedCard(
                            children: [
                              _CupertinoListTile(
                                leading: Icon(
                                  CupertinoIcons.pencil,
                                  size: 20,
                                  color: colors.secondaryLabel,
                                ),
                                title: strings.text('Edit group info'),
                                subtitle: group.description,
                                onTap: acting ? null : editInfo,
                              ),
                              _CupertinoListTile(
                                leading: Icon(
                                  CupertinoIcons.slider_horizontal_3,
                                  size: 20,
                                  color: colors.secondaryLabel,
                                ),
                                title: strings.text('Join settings'),
                                subtitle: group.joinType,
                                onTap: acting ? null : editSettings,
                              ),
                              _CupertinoListTile(
                                leading: Icon(
                                  CupertinoIcons.refresh,
                                  size: 20,
                                  color: colors.secondaryLabel,
                                ),
                                title: strings.text('Reset invite code'),
                                subtitle: group.inviteCode,
                                onTap: acting ? null : resetInviteCode,
                              ),
                            ],
                          ),
                          // Applications section
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    strings.text('Group applications'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: colors.secondaryLabel,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${applications.where((item) => item.pending).length}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.secondaryLabel,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (applications.isEmpty)
                            _EmptyPanel(
                              message: strings.text('No group applications.'),
                            )
                          else
                            _CupertinoGroupedCard(
                              children: [
                                for (final application in applications)
                                  _buildApplicationTile(
                                    application,
                                    strings,
                                    colors,
                                  ),
                              ],
                            ),
                          // Members section
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    strings.text('Members'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: colors.secondaryLabel,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${members.length}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colors.secondaryLabel,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          _CupertinoGroupedCard(
                            children: [
                              for (final member in members)
                                _CupertinoListTile(
                                  leading: _Avatar(
                                    url: member.avatar,
                                    fallback: CupertinoIcons.person_solid,
                                  ),
                                  title: member.name,
                                  subtitle: member.subtitle.isEmpty
                                      ? 'UID ${member.uid}'
                                      : member.subtitle,
                                  onTap: () => openUserProfile(
                                    context,
                                    widget.state,
                                    member.uid,
                                    group: group,
                                    member: member,
                                  ),
                                  trailing: GestureDetector(
                                    onTap: acting
                                        ? null
                                        : () => showMemberActions(member),
                                    child: Icon(
                                      CupertinoIcons.ellipsis,
                                      size: 20,
                                      color: colors.tertiaryLabel,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // Owner actions
                          if (currentUserIsOwner) ...[
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  strings.text('Owner actions'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: colors.secondaryLabel,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            _CupertinoGroupedCard(
                              children: [
                                _CupertinoListTile(
                                  leading: Icon(
                                    CupertinoIcons.arrow_right_arrow_left,
                                    size: 20,
                                    color: colors.secondaryLabel,
                                  ),
                                  title: strings.text('Transfer group owner'),
                                  onTap: acting ? null : transferGroup,
                                ),
                                _CupertinoListTile(
                                  leading: Icon(
                                    CupertinoIcons.trash,
                                    size: 20,
                                    color: CupertinoColors.destructiveRed,
                                  ),
                                  title: strings.text('Disband group'),
                                  titleColor: CupertinoColors.destructiveRed,
                                  onTap: acting ? null : disbandGroup,
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

  Widget _buildApplicationTile(
    GroupApplication application,
    dynamic strings,
    CsacColors colors,
  ) {
    final isActing = actingApplicationId == application.id;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => openUserProfile(
              context,
              widget.state,
              application.uid,
              group: group,
            ),
            child: Row(
              children: [
                _Avatar(
                  url: application.avatar,
                  fallback: CupertinoIcons.person_solid,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application.nickname,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: colors.label,
                        ),
                      ),
                      Text(
                        application.username.isEmpty
                            ? 'UID ${application.uid}'
                            : '@${application.username} | UID ${application.uid}',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(pending: application.pending),
              ],
            ),
          ),
          if (application.content.isNotEmpty || application.answer.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                application.content.isEmpty
                    ? application.answer
                    : application.content,
                style: TextStyle(fontSize: 14, color: colors.secondaryLabel),
              ),
            ),
          if (application.pending) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  onPressed: isActing
                      ? null
                      : () => handleApplication(application, 'refuse'),
                  child: Text(
                    strings.text('Refuse'),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  onPressed: isActing
                      ? null
                      : () => handleApplication(application, 'pass'),
                  child: isActing
                      ? const CupertinoActivityIndicator(
                          radius: 8,
                          color: CupertinoColors.white,
                        )
                      : Text(
                          strings.text('Pass'),
                          style: const TextStyle(fontSize: 15),
                        ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
