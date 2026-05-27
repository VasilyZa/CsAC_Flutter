part of '../../main.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final uid = TextEditingController();
  final message = TextEditingController(text: '请求添加你为好友');
  UserProfile? preview;
  bool sending = false;
  bool searching = false;
  String? error;

  @override
  void dispose() {
    uid.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> lookup() async {
    final target = int.tryParse(uid.text.trim()) ?? 0;
    if (target <= 0) {
      setState(() => error = context.strings.text('Enter a valid UID.'));
      return;
    }
    setState(() {
      searching = true;
      error = null;
      preview = null;
    });
    try {
      final loaded = await widget.state.loadUserProfile(target);
      if (!mounted) {
        return;
      }
      setState(() => preview = loaded);
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => searching = false);
      }
    }
  }

  Future<void> submit() async {
    final target = int.tryParse(uid.text.trim()) ?? 0;
    if (target <= 0) {
      setState(() => error = context.strings.text('Enter a valid UID.'));
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await widget.state.sendFriendRequest(target, message.text);
      if (!mounted) {
        return;
      }
      _showCupertinoToast(
        context,
        context.strings.text('Friend request sent.'),
      );
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  Future<void> openPreviewProfile() async {
    final profile = preview;
    if (profile == null) {
      return;
    }
    await openUserProfile(context, widget.state, profile.uid);
    if (mounted) {
      await lookup();
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(strings.text('Add friend')),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _CupertinoFormField(
              controller: uid,
              placeholder: strings.text('User UID'),
              icon: CupertinoIcons.number,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => lookup(),
            ),
            const SizedBox(height: 12),
            CupertinoButton(
              onPressed: searching ? null : lookup,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (searching)
                    const CupertinoActivityIndicator(radius: 9)
                  else
                    const Icon(CupertinoIcons.search, size: 18),
                  const SizedBox(width: 8),
                  Text(strings.text('Lookup user')),
                ],
              ),
            ),
            if (preview != null) ...[
              const SizedBox(height: 12),
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  _CupertinoListTile(
                    onTap: openPreviewProfile,
                    leading: _Avatar(
                      url: preview!.avatar,
                      fallback: CupertinoIcons.person_fill,
                    ),
                    title: preview!.displayName,
                    subtitle: preview!.subtitle.isEmpty
                        ? 'UID ${preview!.uid}'
                        : preview!.subtitle,
                    trailing: const Icon(
                      CupertinoIcons.chevron_forward,
                      size: 16,
                      color: CupertinoColors.systemGrey2,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _CupertinoFormField(
              controller: message,
              placeholder: strings.text('Request message'),
              icon: CupertinoIcons.chat_bubble,
              maxLines: 3,
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              _InlineError(message: error!, onRetry: submit),
            ],
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: sending ? null : submit,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (sending)
                    const CupertinoActivityIndicator(radius: 9)
                  else
                    const Icon(CupertinoIcons.paperplane, size: 18),
                  const SizedBox(width: 8),
                  Text(strings.text('Send request')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final roomName = TextEditingController();
  bool creating = false;
  String? error;

  @override
  void dispose() {
    roomName.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final name = roomName.text.trim();
    if (name.isEmpty) {
      setState(
        () => error = context.strings.text('Please enter a group name.'),
      );
      return;
    }
    if (name.length > 32) {
      setState(
        () => error = context.strings.text(
          'Group name can be up to 32 characters.',
        ),
      );
      return;
    }
    setState(() {
      creating = true;
      error = null;
    });
    try {
      final created = await widget.state.createGroup(name);
      if (!mounted) {
        return;
      }
      await showCreatedGroupDialog(created);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => creating = false);
      }
    }
  }

  Future<void> showCreatedGroupDialog(CreatedGroup created) {
    final strings = context.strings;
    return showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: Text(strings.text('Group created.')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(strings.format('Room ID: {id}', {'id': created.id})),
            if (created.inviteCode.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                strings.format('Invite code: {code}', {
                  'code': created.inviteCode,
                }),
              ),
            ],
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.text('Close')),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                CupertinoPageRoute<void>(
                  builder: (_) => ConversationDetailScreen(
                    state: widget.state,
                    conversation: created.conversation,
                  ),
                ),
              );
            },
            child: Text(strings.text('Group details')),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                CupertinoPageRoute<void>(
                  builder: (_) => ChatScreen(
                    state: widget.state,
                    conversation: created.conversation,
                  ),
                ),
              );
            },
            child: Text(strings.text('Open chat')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(strings.text('Create group')),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _CupertinoFormField(
              controller: roomName,
              placeholder: strings.text('Group name'),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
            ),
            if (error != null) _InlineError(message: error!, onRetry: submit),
            const SizedBox(height: 12),
            CupertinoButton.filled(
              onPressed: creating ? null : submit,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (creating)
                    const CupertinoActivityIndicator(radius: 9)
                  else
                    const Icon(CupertinoIcons.add, size: 18),
                  const SizedBox(width: 8),
                  Text(strings.text('Create group')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final roomId = TextEditingController();
  final code = TextEditingController();
  final answer = TextEditingController();
  final search = TextEditingController();
  List<GroupProfile> publicGroups = const <GroupProfile>[];
  bool loading = true;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadPublicGroups();
  }

  @override
  void dispose() {
    roomId.dispose();
    code.dispose();
    answer.dispose();
    search.dispose();
    super.dispose();
  }

  Future<void> loadPublicGroups() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget.state.loadPublicGroups();
      if (!mounted) {
        return;
      }
      setState(() => publicGroups = loaded);
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

  Future<void> submit({int? groupId}) async {
    final target = groupId ?? int.tryParse(roomId.text.trim()) ?? 0;
    if (target <= 0) {
      setState(() => error = context.strings.text('Enter a valid room ID.'));
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await widget.state.applyJoinGroup(
        target,
        code: code.text,
        answer: answer.text,
      );
      if (!mounted) {
        return;
      }
      _showCupertinoToast(
        context,
        context.strings.text('Join request sent.'),
      );
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  void useGroup(GroupProfile group) {
    roomId.text = '${group.id}';
    if (group.code.isNotEmpty) {
      code.text = group.code;
    }
    if (group.question.isNotEmpty) {
      answer.selection = TextSelection.collapsed(offset: answer.text.length);
    }
  }

  List<GroupProfile> filteredPublicGroups() {
    final query = search.text.trim().toLowerCase();
    if (query.isEmpty) {
      return publicGroups;
    }
    return publicGroups.where((group) {
      final target =
          '${group.id} ${group.name} ${group.subtitle} ${group.description} ${group.notice}'
              .toLowerCase();
      return target.contains(query);
    }).toList();
  }

  void openGroupDetail(GroupProfile group) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => ConversationDetailScreen(
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

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(strings.text('Join group')),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 0),
          onPressed: loading ? null : loadPublicGroups,
          child: const Icon(CupertinoIcons.refresh, size: 22),
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: loadPublicGroups),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _CupertinoFormField(
                    controller: roomId,
                    placeholder: strings.text('Room ID'),
                    icon: CupertinoIcons.number,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _CupertinoFormField(
                    controller: code,
                    placeholder: strings.text('Invite code'),
                    icon: CupertinoIcons.lock,
                  ),
                  const SizedBox(height: 12),
                  _CupertinoFormField(
                    controller: answer,
                    placeholder: strings.text('Answer'),
                    icon: CupertinoIcons.question_circle,
                    maxLines: 2,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    _InlineError(message: error!, onRetry: submit),
                  ],
                  const SizedBox(height: 16),
                  CupertinoButton.filled(
                    onPressed: sending ? null : submit,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (sending)
                          const CupertinoActivityIndicator(radius: 9)
                        else
                          const Icon(CupertinoIcons.group_solid, size: 18),
                        const SizedBox(width: 8),
                        Text(strings.text('Apply to join')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    strings.text('Public groups'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: colors.label,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoSearchTextField(
                    controller: search,
                    onChanged: (_) => setState(() {}),
                    placeholder: strings.text('Search public groups'),
                  ),
                  const SizedBox(height: 8),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CupertinoActivityIndicator(),
                    )
                  else if (filteredPublicGroups().isEmpty)
                    _EmptyPanel(
                      message: strings.text('No public groups.'),
                    )
                  else
                    _CupertinoGroupedCard(
                      margin: EdgeInsets.zero,
                      children: [
                        for (final group in filteredPublicGroups())
                          GestureDetector(
                            onLongPress: () => openGroupDetail(group),
                            child: _CupertinoListTile(
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: colors.cardBackground,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  CupertinoIcons.group_solid,
                                  size: 18,
                                ),
                              ),
                              title: group.name,
                              subtitle: [
                                strings.format(
                                  'Room {id}',
                                  {'id': group.id},
                                ),
                                group.subtitle,
                                group.description,
                              ]
                                  .where((part) => part.isNotEmpty)
                                  .join(' | '),
                              trailing: CupertinoButton(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                minimumSize: const Size(0, 0),
                                onPressed: sending
                                    ? null
                                    : () {
                                        useGroup(group);
                                        submit(groupId: group.id);
                                      },
                                child: Text(strings.text('Join')),
                              ),
                              onTap: () => useGroup(group),
                            ),
                          ),
                      ],
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageSearchScreen extends StatefulWidget {
  const MessageSearchScreen({
    super.key,
    required this.state,
    this.embedded = false,
  });

  final CsacAppState state;
  final bool embedded;

  @override
  State<MessageSearchScreen> createState() => _MessageSearchScreenState();
}

class _MessageSearchScreenState extends State<MessageSearchScreen> {
  final search = TextEditingController();
  SearchScope scope = SearchScope.all;
  List<MessageSearchResult> results = const <MessageSearchResult>[];
  bool loading = false;
  String? error;
  Timer? debounce;

  @override
  void initState() {
    super.initState();
    runSearch();
  }

  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  void scheduleSearch() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 250), runSearch);
  }

  Future<void> runSearch() async {
    setState(() {});
    final query = search.text.trim();
    if (query.isEmpty &&
        scope != SearchScope.image &&
        scope != SearchScope.essence) {
      setState(() {
        results = const <MessageSearchResult>[];
        loading = false;
        error = null;
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final loaded = await widget.state.searchMessages(query, scope);
      if (!mounted) {
        return;
      }
      setState(() => results = loaded);
    } catch (err) {
      if (!mounted) {
        return;
      }
      setState(() => error = err.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void setScope(SearchScope value) {
    setState(() => scope = value);
    runSearch();
  }

  Future<void> openResult(MessageSearchResult result) {
    return Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => ChatScreen(
          state: widget.state,
          conversation: result.conversation,
          focusMessageId: result.message.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: CupertinoSearchTextField(
            controller: search,
            onChanged: (_) => scheduleSearch(),
            autofocus: true,
            placeholder: strings.text('Search cached messages'),
            onSuffixTap: () {
              search.clear();
              runSearch();
            },
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            children: [
              _ScopeChip(
                label: strings.text('All'),
                selected: scope == SearchScope.all,
                onSelected: () => setScope(SearchScope.all),
              ),
              _ScopeChip(
                label: strings.text('Friends'),
                selected: scope == SearchScope.private,
                onSelected: () => setScope(SearchScope.private),
              ),
              _ScopeChip(
                label: strings.text('Groups'),
                selected: scope == SearchScope.group,
                onSelected: () => setScope(SearchScope.group),
              ),
              _ScopeChip(
                label: strings.text('Images'),
                selected: scope == SearchScope.image,
                onSelected: () => setScope(SearchScope.image),
              ),
              _ScopeChip(
                label: strings.text('Essence'),
                selected: scope == SearchScope.essence,
                onSelected: () => setScope(SearchScope.essence),
              ),
            ],
          ),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: CupertinoActivityIndicator(radius: 10),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      error!,
                      style: const TextStyle(
                        color: CupertinoColors.systemRed,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    onPressed: () => setState(() => error = null),
                    child: Text(strings.text('Dismiss')),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: results.isEmpty
              ? _EmptyPanel(
                  message:
                      search.text.trim().isEmpty &&
                          scope != SearchScope.image &&
                          scope != SearchScope.essence
                      ? strings.text('Type to search cached messages.')
                      : strings.text('No matching messages.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 18),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final result = results[index];
                    return _SearchResultTile(
                      result: result,
                      onTap: () => openResult(result),
                    );
                  },
                ),
        ),
      ],
    );
    if (widget.embedded) {
      return SafeArea(top: true, child: body);
    }
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(strings.text('Search messages')),
      ),
      child: SafeArea(child: body),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onSelected,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? CupertinoTheme.of(context).primaryColor
                : colors.cardBackground,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.0,
              color: selected
                  ? CupertinoColors.white
                  : colors.label,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.result, required this.onTap});

  final MessageSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isGroup = result.conversation.type == ConversationType.group;
    final message = result.message;
    final colors = CsacColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isGroup
                      ? CupertinoColors.systemTeal.withValues(alpha: 0.15)
                      : CupertinoColors.systemBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: Icon(
                  isGroup
                      ? CupertinoIcons.group_solid
                      : CupertinoIcons.person_fill,
                  size: 18,
                  color: isGroup
                      ? CupertinoColors.systemTeal
                      : CupertinoColors.systemBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.conversation.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.label,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${message.sender}${message.time.isEmpty ? '' : ' · ${message.time}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.secondaryLabel,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.snippet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.secondaryLabel,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                message.imageUrl.isNotEmpty
                    ? CupertinoIcons.photo
                    : message.isEssence
                        ? CupertinoIcons.star
                        : CupertinoIcons.chevron_forward,
                size: 16,
                color: CupertinoColors.systemGrey2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
