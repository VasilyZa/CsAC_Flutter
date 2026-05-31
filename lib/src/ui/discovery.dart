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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Friend request sent.'))),
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
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.text('Add friend'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            TextField(
              controller: uid,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => lookup(),
              decoration: InputDecoration(
                labelText: context.strings.text('User UID'),
                prefixIcon: const Icon(Icons.tag),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: searching ? null : lookup,
              icon: searching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(context.strings.text('Lookup user')),
            ),
            if (preview != null) ...[
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                child: ListTile(
                  onTap: openPreviewProfile,
                  leading: _Avatar(
                    url: preview!.avatar,
                    fallback: Icons.person_rounded,
                  ),
                  title: Text(preview!.displayName),
                  subtitle: Text(
                    preview!.subtitle.isEmpty
                        ? 'UID ${preview!.uid}'
                        : preview!.subtitle,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: message,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.strings.text('Request message'),
                prefixIcon: const Icon(Icons.message_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: sending ? null : submit,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(context.strings.text('Send request')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Join request sent.'))),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.strings.text('Join group')),
        actions: [
          IconButton(
            tooltip: context.strings.text('Refresh'),
            onPressed: loading ? null : loadPublicGroups,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadPublicGroups,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              TextField(
                controller: roomId,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.strings.text('Room ID'),
                  prefixIcon: const Icon(Icons.tag),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: code,
                decoration: InputDecoration(
                  labelText: context.strings.text('Invite code'),
                  prefixIcon: const Icon(Icons.key_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: answer,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: context.strings.text('Answer'),
                  prefixIcon: const Icon(Icons.question_answer_outlined),
                  border: const OutlineInputBorder(),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: sending ? null : submit,
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.group_add),
                label: Text(context.strings.text('Apply to join')),
              ),
              const SizedBox(height: 20),
              Text(
                context.strings.text('Public groups'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: context.strings.text('Search public groups'),
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              if (loading)
                const LinearProgressIndicator(minHeight: 2)
              else if (filteredPublicGroups().isEmpty)
                _EmptyPanel(message: context.strings.text('No public groups.'))
              else
                for (final group in filteredPublicGroups())
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.secondaryContainer,
                        child: Icon(
                          Icons.groups_rounded,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                        ),
                      ),
                      title: Text(group.name),
                      subtitle: Text(
                        [
                          context.strings.format('Room {id}', {'id': group.id}),
                          group.subtitle,
                          group.description,
                        ].where((part) => part.isNotEmpty).join(' | '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: TextButton(
                        onPressed: sending
                            ? null
                            : () {
                                useGroup(group);
                                submit(groupId: group.id);
                              },
                        child: Text(context.strings.text('Join')),
                      ),
                      onTap: () => useGroup(group),
                      onLongPress: () => openGroupDetail(group),
                    ),
                  ),
            ],
          ),
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
      setState(() => error = context.strings.text('Room name is required.'));
      return;
    }
    setState(() {
      creating = true;
      error = null;
    });
    try {
      final group = await widget.state.createGroup(name);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.format('Group created: {name}', {
              'name': group.name,
            }),
          ),
        ),
      );
      Navigator.of(context).pushReplacement(
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

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('Create group'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            TextField(
              controller: roomName,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
              decoration: InputDecoration(
                labelText: strings.text('Room name'),
                prefixIcon: const Icon(Icons.groups_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: creating ? null : submit,
              icon: creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(strings.text('Create group')),
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
      CsacPageRoute<void>(
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
          child: TextField(
            controller: search,
            onChanged: (_) => scheduleSearch(),
            autofocus: !widget.embedded,
            decoration: InputDecoration(
              hintText: strings.text('Search cached messages'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: search.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: strings.text('Clear'),
                      onPressed: () {
                        search.clear();
                        runSearch();
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        SizedBox(
          height: 46,
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
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: _InlineError(
              message: error!,
              onRetry: () => setState(() => error = null),
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
                    return _MotionListItem(
                      index: index,
                      child: _SearchResultTile(
                        result: result,
                        preferences: widget.state.preferences,
                        onTap: () => openResult(result),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: Text(strings.text('Search messages'))),
      body: SafeArea(top: widget.embedded, child: body),
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: _CupertinoMiniPill(
        label: label,
        selected: selected,
        onTap: onSelected,
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.result,
    required this.preferences,
    required this.onTap,
  });

  final MessageSearchResult result;
  final CsacPreferences preferences;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isGroup = result.conversation.type == ConversationType.group;
    final message = result.message;
    final time = displayMessageTime(message, preferences);
    final colors = CsacColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: _CsacPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.separator.withValues(alpha: 0.24),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: CupertinoTheme.of(
                    context,
                  ).primaryColor.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isGroup
                      ? CupertinoIcons.group_solid
                      : CupertinoIcons.person_fill,
                  color: CupertinoTheme.of(context).primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.conversation.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.label,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${message.sender}${time.isEmpty ? '' : ' · $time'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.secondaryLabel,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.snippet,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.secondaryLabel),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                message.imageUrl.isNotEmpty
                    ? CupertinoIcons.photo
                    : message.isEssence
                    ? CupertinoIcons.star
                    : CupertinoIcons.chevron_right,
                color: colors.tertiaryLabel,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
