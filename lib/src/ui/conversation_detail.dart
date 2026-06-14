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
  final memberSearch = TextEditingController();
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
    if (widget.state.debugMode) {
      return true;
    }
    final profile = group;
    final currentUid = widget.state.user?.uid;
    return (profile?.isOwner ?? false) ||
        (profile?.ownerUid != 0 && profile?.ownerUid == currentUid) ||
        (profile?.isAdmin ?? false) ||
        (profile?.hasAdminRole ?? false) ||
        (currentGroupMember?.hasAdminRole ?? false);
  }

  bool get currentUserIsGroupOwner {
    if (widget.state.debugMode) {
      return true;
    }
    final profile = group;
    final currentUid = widget.state.user?.uid;
    return (profile?.isOwner ?? false) ||
        (profile?.ownerUid != 0 && profile?.ownerUid == currentUid) ||
        (profile?.hasOwnerRole ?? false) ||
        (currentGroupMember?.hasOwnerRole ?? false);
  }

  bool isCurrentUserInGroup(GroupProfile profile) {
    final currentUid = widget.state.user?.uid;
    final hasConversation = widget.state.conversations.any((conversation) {
      return conversation.type == ConversationType.group &&
          conversation.id == profile.id;
    });
    return profile.isInGroup ||
        profile.hasAdminRole ||
        (profile.ownerUid != 0 && profile.ownerUid == currentUid) ||
        currentGroupMember != null ||
        hasConversation;
  }

  @override
  void initState() {
    super.initState();
    widget.state.addListener(handleStateChanged);
    memberSearch.addListener(() => setState(() {}));
    load();
  }

  @override
  void dispose() {
    widget.state.removeListener(handleStateChanged);
    memberSearch.dispose();
    super.dispose();
  }

  void handleStateChanged() {
    if (mounted) {
      setState(() {});
    }
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
    final message = await showCupertinoCsacDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          strings.format('Add {name}', {'name': profile.displayName}),
        ),
        content: CsacTextField(
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
      CsacToastMessenger.of(context).showToast(
        CsacToast(content: Text(strings.text('Friend request sent.'))),
      );
    } catch (err) {
      if (mounted) {
        CsacToastMessenger.of(context).showToast(
          CsacToast(
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
    final confirmed = await showCupertinoCsacDialog<bool>(
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
            CsacTextField(
              controller: code,
              decoration: InputDecoration(
                labelText: strings.text('Invite code'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            CsacTextField(
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
      CsacToastMessenger.of(
        context,
      ).showToast(CsacToast(content: Text(strings.text('Join request sent.'))));
      await load();
    } catch (err) {
      if (mounted) {
        CsacToastMessenger.of(context).showToast(
          CsacToast(
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
    final remark = await showCupertinoCsacDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('Edit remark')),
        content: CsacTextField(
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
      CsacToastMessenger.of(
        context,
      ).showToast(CsacToast(content: Text(strings.text('Remark updated.'))));
      await load();
    } catch (err) {
      if (mounted) {
        CsacToastMessenger.of(context).showToast(
          CsacToast(
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
    final confirmed = await showCupertinoCsacDialog<bool>(
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
      CsacToastMessenger.of(
        context,
      ).showToast(CsacToast(content: Text(strings.text('Friend deleted.'))));
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        CsacToastMessenger.of(context).showToast(
          CsacToast(
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
    final confirmed = await showCupertinoCsacDialog<bool>(
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
      CsacToastMessenger.of(
        context,
      ).showToast(CsacToast(content: Text(strings.text('Friend blocked.'))));
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        CsacToastMessenger.of(context).showToast(
          CsacToast(
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
    final confirmed = await showCupertinoCsacDialog<bool>(
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
      CsacToastMessenger.of(
        context,
      ).showToast(CsacToast(content: Text(strings.text('Left group.'))));
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        CsacToastMessenger.of(context).showToast(
          CsacToast(
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
      CsacToastMessenger.of(context).showToast(
        CsacToast(content: Text(strings.text('Member action completed.'))),
      );
      await load();
    } catch (err) {
      if (mounted) {
        final strings = context.strings;
        CsacToastMessenger.of(context).showToast(
          CsacToast(
            content: Text(
              strings.format('Action failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    }
  }

  Future<void> inviteMember(GroupProfile profile) async {
    var friends = const <Friend>[];
    try {
      friends = await widget.state.loadFriends();
    } catch (_) {}
    if (!mounted) {
      return;
    }
    final targetUid = await showCupertinoCsacDialog<int>(
      context: context,
      builder: (context) => _InviteMemberDialog(
        friends: friends,
        excludedUids: members.map((member) => member.uid).toSet(),
      ),
    );
    if (targetUid == null || !mounted) {
      return;
    }
    try {
      await widget.state.inviteGroupMember(profile.id, targetUid);
      if (!mounted) {
        return;
      }
      CsacToastMessenger.of(context).showToast(
        CsacToast(content: Text(context.strings.text('Invitation sent.'))),
      );
      await load();
    } catch (err) {
      if (mounted) {
        CsacToastMessenger.of(context).showToast(
          CsacToast(
            content: Text(
              context.strings.format('Action failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    }
  }

  Future<void> editMemberTitle(GroupMember member) async {
    final profile = group;
    if (profile == null) {
      return;
    }
    final result = await showCupertinoCsacDialog<_MemberTitleChange>(
      context: context,
      builder: (context) =>
          _MemberTitleDialog(member: member, debugMode: widget.state.debugMode),
    );
    if (result == null || !mounted) {
      return;
    }
    final strings = context.strings;
    if (result.title.runes.length > 16) {
      CsacToastMessenger.of(context).showToast(
        CsacToast(
          content: Text(
            strings.text('Member title must be at most 16 characters.'),
          ),
        ),
      );
      return;
    }
    if (result.level < 1 || (!widget.state.debugMode && result.level > 100)) {
      CsacToastMessenger.of(context).showToast(
        CsacToast(
          content: Text(strings.text('Level must be between 1 and 100.')),
        ),
      );
      return;
    }
    try {
      await widget.state.setGroupMemberTitle(
        profile.id,
        member.uid,
        title: result.title,
        level: result.level,
      );
      if (!mounted) {
        return;
      }
      CsacToastMessenger.of(context).showToast(
        CsacToast(content: Text(strings.text('Member title updated.'))),
      );
      await load();
    } catch (err) {
      if (mounted) {
        CsacToastMessenger.of(context).showToast(
          CsacToast(
            content: Text(
              strings.format('Action failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    }
  }

  Future<void> showMemberActions(GroupMember member) async {
    final strings = context.strings;
    final action = await showCsacActionSheet<String>(
      context: context,
      title: member.name,
      actions: [
        CsacActionSheetAction(
          value: 'title',
          title: strings.text('Set member title'),
          icon: CupertinoIcons.textformat,
        ),
        CsacActionSheetAction(
          value: 'mute10',
          title: strings.text('Mute 10 minutes'),
          icon: CupertinoIcons.speaker_slash,
        ),
        CsacActionSheetAction(
          value: 'unmute',
          title: strings.text('Unmute'),
          icon: CupertinoIcons.speaker_2,
        ),
        CsacActionSheetAction(
          value: 'admin',
          title: strings.text('Set admin'),
          icon: CupertinoIcons.person_badge_plus,
        ),
        CsacActionSheetAction(
          value: 'removeAdmin',
          title: strings.text('Remove admin'),
          icon: CupertinoIcons.person_badge_minus,
        ),
        CsacActionSheetAction(
          value: 'kick',
          title: strings.text('Kick member'),
          icon: CupertinoIcons.person_crop_circle_badge_xmark,
          destructive: true,
        ),
      ],
    );
    if (action != null) {
      if (action == 'title') {
        await editMemberTitle(member);
      } else {
        await memberAction(member, action);
      }
    }
  }

  Future<void> openGroupManagement(GroupProfile profile) async {
    await Navigator.of(context).push(
      CsacPageRoute<void>(
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
    CsacToastMessenger.of(context).showToast(
      CsacToast(
        content: Text(
          context.strings.format('{label} copied.', {'label': label}),
        ),
      ),
    );
  }

  void openReportGroup(GroupProfile profile) {
    Navigator.of(context).push(
      CsacPageRoute<void>(
        builder: (_) => ReportScreen(
          state: widget.state,
          type: 'group',
          targetId: profile.id,
          targetName: profile.name,
        ),
      ),
    );
  }

  Future<void> openMediaCenter() {
    return Navigator.of(context).push(
      CsacPageRoute<void>(
        builder: (_) => ConversationMediaScreen(
          state: widget.state,
          conversation: widget.conversation,
        ),
      ),
    );
  }

  void openPrivateChatForMember(GroupMember member) {
    Navigator.of(context).push(
      CsacPageRoute<void>(
        builder: (_) => ChatScreen(
          state: widget.state,
          conversation: Conversation(
            type: ConversationType.private,
            id: member.uid,
            name: member.name,
            avatar: member.avatar,
            subtitle: member.subtitle,
          ),
        ),
      ),
    );
  }

  List<GroupMember> filteredMembers(TextEditingController controller) {
    final query = controller.text.trim().toLowerCase();
    if (query.isEmpty) {
      return members;
    }
    return members
        .where((member) => member.searchableText.contains(query))
        .toList();
  }

  Widget infoRow(IconData icon, String title, String value) {
    if (value.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return _CupertinoListTile(
      leading: Icon(icon),
      title: title,
      subtitle: value,
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
    final colors = CsacColors.of(context);
    final canManageGroup = canManageCurrentGroup;
    final isInGroup = isCurrentUserInGroup(profile);
    final visibleMembers = filteredMembers(memberSearch);
    final memberQuery = memberSearch.text.trim();
    return RefreshIndicator(
      onRefresh: load,
      child: CsacListView(
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
                  url: profile.avatar,
                  fallback: CupertinoIcons.group_solid,
                  radius: 28,
                  heroTag: conversationAvatarHeroTag(widget.conversation),
                  name: profile.name,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: TextStyle(
                          color: colors.label,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.subtitle.isEmpty
                            ? strings.format('Room {id}', {'id': profile.id})
                            : profile.subtitle,
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
                leading: const Icon(CupertinoIcons.number),
                title: strings.text('Room ID'),
                subtitle: '${profile.id}',
                trailing: CsacIconButton(
                  tooltip: strings.text('Copy room ID'),
                  onPressed: () =>
                      copyText(strings.text('Room ID'), '${profile.id}'),
                  icon: const Icon(CupertinoIcons.doc_on_doc),
                ),
              ),
              infoRow(
                CupertinoIcons.info_circle,
                strings.text('Description'),
                profile.description,
              ),
              infoRow(
                CupertinoIcons.speaker_2,
                strings.text('Notice'),
                profile.notice,
              ),
              if (profile.inviteCode.isNotEmpty)
                _CupertinoListTile(
                  leading: const Icon(CupertinoIcons.link),
                  title: strings.text('Invite code'),
                  subtitle: profile.inviteCode,
                  trailing: CsacIconButton(
                    tooltip: strings.text('Copy invite code'),
                    onPressed: () => copyText(
                      strings.text('Invite code'),
                      profile.inviteCode,
                    ),
                    icon: const Icon(CupertinoIcons.doc_on_doc),
                  ),
                ),
              infoRow(
                CupertinoIcons.lock,
                strings.text('Fixed code'),
                profile.code,
              ),
              infoRow(
                CupertinoIcons.question_circle,
                strings.text('Question'),
                profile.question,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CupertinoGroupedCard(
            margin: EdgeInsets.zero,
            children: [
              if (canManageGroup)
                _CupertinoListTile(
                  leading: const Icon(CupertinoIcons.gear_alt),
                  title: strings.text('Group management'),
                  onTap: () => openGroupManagement(profile),
                ),
              if (isInGroup && (profile.allowInvite || canManageGroup))
                _CupertinoListTile(
                  leading: const Icon(CupertinoIcons.person_add),
                  title: strings.text('Invite member'),
                  onTap: () => inviteMember(profile),
                ),
              if (!isInGroup)
                _CupertinoListTile(
                  leading: const Icon(CupertinoIcons.person_2_fill),
                  title: strings.text('Apply to join'),
                  onTap: () => joinGroup(profile),
                )
              else
                _CupertinoListTile(
                  leading: Icon(
                    CupertinoIcons.square_arrow_left,
                    color: colors.destructive,
                  ),
                  title: strings.text('Leave group'),
                  titleColor: colors.destructive,
                  onTap: () => leaveGroup(profile),
                ),
              _CupertinoListTile(
                leading: const Icon(CupertinoIcons.photo_on_rectangle),
                title: strings.text('Media and files'),
                onTap: openMediaCenter,
              ),
              _CupertinoListTile(
                leading: Icon(CupertinoIcons.flag, color: colors.destructive),
                title: strings.text('Report group'),
                titleColor: colors.destructive,
                onTap: () => openReportGroup(profile),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.text('Members'),
                  style: TextStyle(
                    color: colors.label,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text('${members.length}'),
            ],
          ),
          const SizedBox(height: 8),
          CsacTextField(
            controller: memberSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: strings.text(
                'Search members by nickname, UID or remark',
              ),
              prefixIcon: const Icon(CupertinoIcons.search),
              suffixIcon: memberQuery.isEmpty
                  ? null
                  : CsacIconButton(
                      tooltip: strings.text('Clear'),
                      onPressed: memberSearch.clear,
                      icon: const Icon(CupertinoIcons.xmark_circle_fill),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          if (members.isEmpty)
            _EmptyPanel(message: strings.text('No members.'))
          else if (visibleMembers.isEmpty)
            _EmptyPanel(message: strings.text('No matching members.'))
          else
            _ChatListSection(
              margin: EdgeInsets.zero,
              children: [
                for (final entry in visibleMembers.indexed)
                  _MotionListItem(
                    index: entry.$1,
                    child: _ChatListTile(
                      leading: _Avatar(
                        url: entry.$2.avatar,
                        fallback: CupertinoIcons.person_fill,
                        radius: 25,
                        name: entry.$2.name,
                        heroTag: userAvatarHeroTag(
                          entry.$2.uid,
                          'conversation-detail-${profile.id}',
                        ),
                      ),
                      title: Text(entry.$2.name),
                      subtitle: Text(
                        entry.$2.subtitle.isEmpty
                            ? 'UID ${entry.$2.uid}'
                            : entry.$2.subtitle,
                      ),
                      onTap: () => openUserProfile(
                        context,
                        widget.state,
                        entry.$2.uid,
                        group: profile,
                        member: entry.$2,
                        avatarHeroTag: userAvatarHeroTag(
                          entry.$2.uid,
                          'conversation-detail-${profile.id}',
                        ),
                      ),
                      trailing: canManageGroup
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CsacIconButton(
                                  tooltip: strings.text('Open private chat'),
                                  onPressed: () =>
                                      openPrivateChatForMember(entry.$2),
                                  icon: const Icon(CupertinoIcons.chat_bubble),
                                ),
                                CsacIconButton(
                                  tooltip: strings.text('Manage'),
                                  onPressed: () => showMemberActions(entry.$2),
                                  icon: const Icon(CupertinoIcons.ellipsis),
                                ),
                              ],
                            )
                          : CsacIconButton(
                              tooltip: strings.text('Open private chat'),
                              onPressed: () =>
                                  openPrivateChatForMember(entry.$2),
                              icon: const Icon(CupertinoIcons.chat_bubble),
                            ),
                    ),
                  ),
              ],
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
        avatarHeroTag: conversationAvatarHeroTag(widget.conversation),
      );
    }
    final title = widget.conversation.type == ConversationType.group
        ? context.strings.text('Group details')
        : context.strings.text('User details');
    return CsacPageScaffold(
      backgroundColor: CsacColors.of(context).systemBackground,
      appBar: CsacNavigationBar(
        title: Text(title),
        actions: [
          CsacIconButton(
            tooltip: context.strings.text('Refresh'),
            onPressed: loading ? null : load,
            icon: const Icon(CupertinoIcons.arrow_clockwise),
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

class _InviteMemberDialog extends StatefulWidget {
  const _InviteMemberDialog({
    this.friends = const <Friend>[],
    this.excludedUids = const <int>{},
  });

  final List<Friend> friends;
  final Set<int> excludedUids;

  @override
  State<_InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<_InviteMemberDialog> {
  late final TextEditingController uid;

  List<Friend> get visibleFriends {
    final query = uid.text.trim().toLowerCase();
    final friends = widget.friends
        .where((friend) => !widget.excludedUids.contains(friend.uid))
        .toList();
    if (query.isEmpty) {
      return friends;
    }
    return friends.where((friend) {
      return friend.name.toLowerCase().contains(query) ||
          friend.searchText.toLowerCase().contains(query) ||
          '${friend.uid}'.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    uid = TextEditingController()..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    uid.dispose();
    super.dispose();
  }

  void submit() {
    final value = int.tryParse(uid.text.trim()) ?? 0;
    if (value <= 0) {
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final validUid = (int.tryParse(uid.text.trim()) ?? 0) > 0;
    final friends = visibleFriends;
    return AlertDialog(
      title: Text(strings.text('Invite member')),
      content: SizedBox(
        width: 420,
        height: 380,
        child: Column(
          children: [
            CsacTextField(
              controller: uid,
              autofocus: true,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: strings.text('Search friends or enter UID'),
                helperText: strings.text('Choose a friend or invite by UID'),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => submit(),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: widget.friends.isEmpty
                  ? _EmptyPanel(message: strings.text('No friends found.'))
                  : friends.isEmpty
                  ? _EmptyPanel(message: strings.text('No matching friends.'))
                  : CsacListView.builder(
                      itemCount: friends.length,
                      itemBuilder: (context, index) {
                        final friend = friends[index];
                        return CupertinoListTile(
                          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
                          leading: _Avatar(
                            url: friend.avatar,
                            fallback: CupertinoIcons.person_fill,
                            radius: 18,
                            name: friend.name,
                          ),
                          title: Text(
                            friend.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('UID ${friend.uid}'),
                          trailing: const Icon(CupertinoIcons.chevron_right),
                          onTap: () => Navigator.of(context).pop(friend.uid),
                        );
                      },
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
          onPressed: validUid ? submit : null,
          child: Text(strings.text('Invite')),
        ),
      ],
    );
  }
}

class _MemberTitleChange {
  const _MemberTitleChange({required this.title, required this.level});

  final String title;
  final int level;
}

class _MemberTitleDialog extends StatefulWidget {
  const _MemberTitleDialog({required this.member, this.debugMode = false});

  final GroupMember member;
  final bool debugMode;

  @override
  State<_MemberTitleDialog> createState() => _MemberTitleDialogState();
}

class _MemberTitleDialogState extends State<_MemberTitleDialog> {
  late final TextEditingController title;
  late final TextEditingController level;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.member.memberTitle)
      ..addListener(() => setState(() {}));
    level = TextEditingController(
      text: '${widget.member.memberLevel <= 0 ? 1 : widget.member.memberLevel}',
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    title.dispose();
    level.dispose();
    super.dispose();
  }

  void submit() {
    final parsedLevel = int.tryParse(level.text.trim()) ?? 0;
    if (parsedLevel < 1 ||
        (!widget.debugMode && parsedLevel > 100) ||
        title.text.runes.length > 16) {
      return;
    }
    Navigator.of(
      context,
    ).pop(_MemberTitleChange(title: title.text.trim(), level: parsedLevel));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final parsedLevel = int.tryParse(level.text.trim()) ?? 0;
    final canSubmit =
        parsedLevel >= 1 &&
        (widget.debugMode || parsedLevel <= 100) &&
        title.text.runes.length <= 16;
    return AlertDialog(
      title: Text(strings.text('Set member title')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CsacTextField(
              controller: title,
              maxLength: 16,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: strings.text('Member title'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            CsacTextField(
              controller: level,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: strings.text('Member level'),
                helperText: widget.debugMode
                    ? strings.text('Debug mode allows any positive level.')
                    : strings.text('Level must be between 1 and 100.'),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => submit(),
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
          child: Text(strings.text('Save')),
        ),
      ],
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
  final imagePicker = ImagePicker();
  final memberSearch = TextEditingController();
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
    if (widget.state.debugMode) {
      return true;
    }
    final currentUid = widget.state.user?.uid;
    return widget.isOwnerOverride ||
        group.isOwner ||
        (group.ownerUid != 0 && group.ownerUid == currentUid) ||
        group.hasOwnerRole ||
        (currentMember?.hasOwnerRole ?? false);
  }

  bool get canManage {
    if (widget.state.debugMode) {
      return true;
    }
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
    widget.state.addListener(handleStateChanged);
    group = widget.group;
    members = widget.initialMembers;
    memberSearch.addListener(() => setState(() {}));
    load();
  }

  @override
  void dispose() {
    widget.state.removeListener(handleStateChanged);
    memberSearch.dispose();
    super.dispose();
  }

  void handleStateChanged() {
    if (mounted) {
      setState(() {});
    }
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
    CsacToastMessenger.of(context).showToast(CsacToast(content: Text(message)));
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
    final confirmed = await showCupertinoCsacDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('Edit group info')),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CsacTextField(
                controller: roomName,
                decoration: InputDecoration(
                  labelText: strings.text('Room name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              CsacTextField(
                controller: description,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: strings.text('Description'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              CsacTextField(
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

  Future<void> changeGroupAvatar() async {
    if (acting) {
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
    await runAction(
      () => widget.state.updateGroupAvatar(group.id, bytes, picked.name),
      'Group avatar updated.',
    );
  }

  Future<void> editSettings() async {
    final joinType = TextEditingController(text: group.joinType);
    final code = TextEditingController(text: group.code);
    final question = TextEditingController(text: group.question);
    final answer = TextEditingController(text: group.answer);
    var showPublic = group.showPublic;
    var allowInvite = group.allowInvite;
    final strings = context.strings;
    final confirmed = await showCupertinoCsacDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(strings.text('Group settings')),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CsacTextField(
                  controller: joinType,
                  decoration: InputDecoration(
                    labelText: strings.text('Join type'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                CsacTextField(
                  controller: code,
                  decoration: InputDecoration(
                    labelText: strings.text('Fixed code'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                CsacTextField(
                  controller: question,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: strings.text('Review question'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                CsacTextField(
                  controller: answer,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: strings.text('Review answer'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                CsacSwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(strings.text('Show publicly')),
                  value: showPublic,
                  onChanged: (value) =>
                      setDialogState(() => showPublic = value),
                ),
                CsacSwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(strings.text('Allow member invites')),
                  value: allowInvite,
                  onChanged: (value) =>
                      setDialogState(() => allowInvite = value),
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
        allowInvite: allowInvite,
      ),
      'Group settings updated.',
    );
  }

  Future<void> inviteMember() async {
    final targetUid = await showCupertinoCsacDialog<int>(
      context: context,
      builder: (context) => const _InviteMemberDialog(),
    );
    if (targetUid == null || !mounted) {
      return;
    }
    await runAction(
      () => widget.state.inviteGroupMember(group.id, targetUid),
      'Invitation sent.',
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

  Future<void> editMemberTitle(GroupMember member) async {
    final result = await showCupertinoCsacDialog<_MemberTitleChange>(
      context: context,
      builder: (context) =>
          _MemberTitleDialog(member: member, debugMode: widget.state.debugMode),
    );
    if (result == null || !mounted) {
      return;
    }
    if (result.title.runes.length > 16) {
      showSnack(
        context.strings.text('Member title must be at most 16 characters.'),
      );
      return;
    }
    if (result.level < 1 || (!widget.state.debugMode && result.level > 100)) {
      showSnack(context.strings.text('Level must be between 1 and 100.'));
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

  Future<void> showMemberActions(GroupMember member) async {
    final actions = <String>[
      'title',
      'mute10',
      'unmute',
      if (currentUserIsOwner && !member.hasOwnerRole) ...[
        'admin',
        'removeAdmin',
      ],
      if (!member.hasOwnerRole) 'kick',
    ];
    final strings = context.strings;
    final selected = await showCsacActionSheet<String>(
      context: context,
      title: member.name,
      actions: [
        if (actions.contains('title'))
          CsacActionSheetAction(
            value: 'title',
            title: strings.text('Set member title'),
            icon: CupertinoIcons.textformat,
          ),
        if (actions.contains('mute10'))
          CsacActionSheetAction(
            value: 'mute10',
            title: strings.text('Mute 10 minutes'),
            icon: CupertinoIcons.speaker_slash,
          ),
        if (actions.contains('unmute'))
          CsacActionSheetAction(
            value: 'unmute',
            title: strings.text('Unmute'),
            icon: CupertinoIcons.speaker_2,
          ),
        if (actions.contains('admin'))
          CsacActionSheetAction(
            value: 'admin',
            title: strings.text('Set admin'),
            icon: CupertinoIcons.person_badge_plus,
          ),
        if (actions.contains('removeAdmin'))
          CsacActionSheetAction(
            value: 'removeAdmin',
            title: strings.text('Remove admin'),
            icon: CupertinoIcons.person_badge_minus,
          ),
        if (actions.contains('kick'))
          CsacActionSheetAction(
            value: 'kick',
            title: strings.text('Kick member'),
            icon: CupertinoIcons.person_crop_circle_badge_xmark,
            destructive: true,
          ),
      ],
    );
    if (selected != null) {
      if (selected == 'title') {
        await editMemberTitle(member);
      } else {
        await memberAction(member, selected);
      }
    }
  }

  void openPrivateChatForMember(GroupMember member) {
    Navigator.of(context).push(
      CsacPageRoute<void>(
        builder: (_) => ChatScreen(
          state: widget.state,
          conversation: Conversation(
            type: ConversationType.private,
            id: member.uid,
            name: member.name,
            avatar: member.avatar,
            subtitle: member.subtitle,
          ),
        ),
      ),
    );
  }

  List<GroupMember> filteredMembers() {
    final query = memberSearch.text.trim().toLowerCase();
    if (query.isEmpty) {
      return members;
    }
    return members
        .where((member) => member.searchableText.contains(query))
        .toList();
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
    final currentUser = widget.state.user;
    final candidates = members
        .where(
          (member) =>
              widget.state.debugMode ? true : member.uid != currentUser?.uid,
        )
        .where((member) => widget.state.debugMode ? true : !member.hasOwnerRole)
        .toList();
    if (widget.state.debugMode &&
        currentUser != null &&
        candidates.every((member) => member.uid != currentUser.uid)) {
      candidates.insert(
        0,
        GroupMember(
          uid: currentUser.uid,
          name: currentUser.nickname,
          username: currentUser.username,
          nickname: currentUser.nickname,
          avatar: currentUser.avatar,
          onlineStatus: currentUser.onlineStatus,
        ),
      );
    }
    final target = await chooseMember(
      context.strings.text('Transfer owner to'),
      candidates,
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

  Future<void> banRoom() async {
    final ok = await confirm(
      context.strings.format('Ban group {name}?', {'name': group.name}),
      context.strings.text('This group will be banned from the service.'),
      context.strings.text('Ban'),
    );
    if (!ok || !mounted) {
      return;
    }
    await runAction(() => widget.state.banRoom(group.id), 'Group banned.');
  }

  Future<void> unbanRoom() async {
    await runAction(() => widget.state.unbanRoom(group.id), 'Group unbanned.');
  }

  Future<GroupMember?> chooseMember(
    String title,
    List<GroupMember> candidates,
  ) {
    return showCupertinoCsacSheet<GroupMember>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: candidates.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(context.strings.text('No selectable members.')),
              )
            : CsacListView(
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
                    ListTile(
                      leading: _Avatar(
                        url: member.avatar,
                        fallback: Icons.person_rounded,
                        name: member.name,
                      ),
                      title: Text(member.name),
                      subtitle: Text(
                        member.subtitle.isEmpty
                            ? 'UID ${member.uid}'
                            : member.subtitle,
                      ),
                      onTap: () => Navigator.of(context).pop(member),
                    ),
                ],
              ),
      ),
    );
  }

  Future<bool> confirm(String title, String message, String action) async {
    final confirmed = await showCupertinoCsacDialog<bool>(
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
    final visibleMembers = filteredMembers();
    final memberQuery = memberSearch.text.trim();
    return CsacPageScaffold(
      appBar: CsacNavigationBar(
        title: Text(strings.text('Group management')),
        actions: [
          CsacIconButton(
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
                child: CsacListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    CsacCard(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            _Avatar(
                              url: group.avatar,
                              fallback: Icons.groups_rounded,
                              radius: 24,
                              name: group.name,
                              backgroundColor: colors.secondaryContainer,
                              foregroundColor: colors.onSecondaryContainer,
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
                    CsacCard(
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
                            const CsacDivider(height: 1),
                            actionTile(
                              icon: Icons.add_photo_alternate_outlined,
                              title: strings.text('Change group avatar'),
                              subtitle: strings.text(
                                'Choose a new group profile image',
                              ),
                              onTap: changeGroupAvatar,
                            ),
                            const CsacDivider(height: 1),
                            actionTile(
                              icon: Icons.tune,
                              title: strings.text('Join settings'),
                              subtitle: group.joinType,
                              onTap: editSettings,
                            ),
                            const CsacDivider(height: 1),
                            actionTile(
                              icon: Icons.person_add_alt_1_outlined,
                              title: strings.text('Invite member'),
                              subtitle: group.allowInvite
                                  ? strings.text('Members can invite others')
                                  : strings.text('Only admins can invite'),
                              onTap: inviteMember,
                            ),
                            const CsacDivider(height: 1),
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
                        CsacCard(
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
                                    name: application.nickname,
                                    heroTag: userAvatarHeroTag(
                                      application.uid,
                                      'group-applications-${group.id}',
                                    ),
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
                                    avatarHeroTag: userAvatarHeroTag(
                                      application.uid,
                                      'group-applications-${group.id}',
                                    ),
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
                    CsacTextField(
                      controller: memberSearch,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: strings.text(
                          'Search members by nickname, UID or remark',
                        ),
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: memberQuery.isEmpty
                            ? null
                            : CsacIconButton(
                                tooltip: strings.text('Clear'),
                                onPressed: memberSearch.clear,
                                icon: const Icon(Icons.close),
                              ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (visibleMembers.isEmpty)
                      _EmptyPanel(message: strings.text('No matching members.'))
                    else
                      _ChatListSection(
                        margin: EdgeInsets.zero,
                        children: [
                          for (final entry in visibleMembers.indexed)
                            _MotionListItem(
                              index: entry.$1,
                              child: _ChatListTile(
                                leading: _Avatar(
                                  url: entry.$2.avatar,
                                  fallback: CupertinoIcons.person_fill,
                                  radius: 25,
                                  name: entry.$2.name,
                                  heroTag: userAvatarHeroTag(
                                    entry.$2.uid,
                                    'group-management-${group.id}',
                                  ),
                                ),
                                title: Text(entry.$2.name),
                                subtitle: Text(
                                  entry.$2.subtitle.isEmpty
                                      ? 'UID ${entry.$2.uid}'
                                      : entry.$2.subtitle,
                                ),
                                onTap: () => openUserProfile(
                                  context,
                                  widget.state,
                                  entry.$2.uid,
                                  group: group,
                                  member: entry.$2,
                                  avatarHeroTag: userAvatarHeroTag(
                                    entry.$2.uid,
                                    'group-management-${group.id}',
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CsacIconButton(
                                      tooltip: strings.text(
                                        'Open private chat',
                                      ),
                                      onPressed: () =>
                                          openPrivateChatForMember(entry.$2),
                                      icon: const Icon(
                                        CupertinoIcons.chat_bubble,
                                      ),
                                    ),
                                    CsacIconButton(
                                      tooltip: strings.text('Manage'),
                                      onPressed: acting
                                          ? null
                                          : () => showMemberActions(entry.$2),
                                      icon: const Icon(CupertinoIcons.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    if (currentUserIsOwner) ...[
                      const SizedBox(height: 20),
                      sectionTitle(strings.text('Owner actions')),
                      const SizedBox(height: 8),
                      CsacCard(
                        elevation: 0,
                        child: _RoundedInkClip(
                          child: Column(
                            children: [
                              actionTile(
                                icon: Icons.swap_horiz,
                                title: strings.text('Transfer group owner'),
                                onTap: transferGroup,
                              ),
                              const CsacDivider(height: 1),
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
                    if (widget.state.debugMode) ...[
                      const SizedBox(height: 20),
                      sectionTitle(strings.text('Debug management actions')),
                      const SizedBox(height: 8),
                      CsacCard(
                        elevation: 0,
                        child: _RoundedInkClip(
                          child: Column(
                            children: [
                              actionTile(
                                icon: Icons.block,
                                title: strings.text('Ban group'),
                                color: colors.error,
                                onTap: banRoom,
                              ),
                              const CsacDivider(height: 1),
                              actionTile(
                                icon: Icons.restore_from_trash_outlined,
                                title: strings.text('Unban group'),
                                onTap: unbanRoom,
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
