part of '../../main.dart';

class AddFriendScreen extends StatefulWidget {
  const AddFriendScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends State<AddFriendScreen> {
  final uid = TextEditingController();
  final message = TextEditingController();
  UserProfile? preview;
  bool sending = false;
  bool searching = false;
  bool seededMessage = false;
  String? error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!seededMessage) {
      message.text = context.strings.text('Please add me as a friend.');
      seededMessage = true;
    }
  }

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
      await _showDiscoverySuccess(
        context,
        context.strings.text('Friend request sent.'),
      );
      if (!mounted) {
        return;
      }
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
    final previewProfile = preview;
    return _DiscoveryPage(
      title: strings.text('Add friend'),
      bottomBar: _DiscoveryPrimaryBar(
        label: strings.text('Send request'),
        icon: CupertinoIcons.paperplane_fill,
        loading: sending,
        onPressed: sending ? null : submit,
      ),
      child: CsacCustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _DiscoveryListSection(
              header: strings.text('Lookup'),
              children: [
                _DiscoveryFormFieldTile(
                  label: strings.text('User UID'),
                  controller: uid,
                  icon: CupertinoIcons.tag,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => lookup(),
                ),
                _DiscoveryActionTile(
                  label: strings.text('Lookup user'),
                  icon: CupertinoIcons.search,
                  loading: searching,
                  onTap: searching ? null : lookup,
                ),
              ],
            ),
          ),
          if (previewProfile != null)
            SliverToBoxAdapter(
              child: _DiscoveryListSection(
                header: strings.text('Profile'),
                children: [
                  CupertinoListTile(
                    leading: _Avatar(
                      url: previewProfile.avatar,
                      fallback: CupertinoIcons.person_fill,
                      name: previewProfile.displayName,
                    ),
                    title: Text(
                      previewProfile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      previewProfile.subtitle.isEmpty
                          ? strings.format('UID {uid}', {
                              'uid': previewProfile.uid,
                            })
                          : previewProfile.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: _DiscoveryChevron(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    onTap: openPreviewProfile,
                  ),
                ],
              ),
            ),
          SliverToBoxAdapter(
            child: _DiscoveryListSection(
              header: strings.text('Request'),
              children: [
                _DiscoveryFormFieldTile(
                  label: strings.text('Request message'),
                  controller: message,
                  icon: CupertinoIcons.chat_bubble_text,
                  minLines: 3,
                  maxLines: 5,
                ),
              ],
            ),
          ),
          if (error != null)
            SliverToBoxAdapter(
              child: _DiscoveryErrorBanner(
                message: error!,
                onDismiss: () => setState(() => error = null),
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
      ),
    );
  }
}

Future<void> _showDiscoverySuccess(BuildContext context, String message) {
  final strings = context.strings;
  return showCupertinoDialog<void>(
    context: context,
    builder: (dialogContext) {
      return CupertinoAlertDialog(
        title: Text(strings.text('Sent')),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.text('Done')),
          ),
        ],
      );
    },
  );
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
      await _showDiscoverySuccess(
        context,
        context.strings.text('Join request sent.'),
      );
      if (!mounted) {
        return;
      }
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
    setState(() {
      roomId.text = '${group.id}';
      if (group.code.isNotEmpty) {
        code.text = group.code;
      }
      if (group.question.isNotEmpty) {
        answer.selection = TextSelection.collapsed(offset: answer.text.length);
      }
    });
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
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final groups = filteredPublicGroups();
    return _DiscoveryPage(
      title: strings.text('Join group'),
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: const Size.square(36),
        onPressed: loading ? null : loadPublicGroups,
        child: loading
            ? CupertinoActivityIndicator(radius: 9, color: colors.primaryColor)
            : Icon(
                CupertinoIcons.refresh,
                size: 20,
                color: colors.primaryColor,
              ),
      ),
      bottomBar: _DiscoveryPrimaryBar(
        label: strings.text('Apply to join'),
        icon: CupertinoIcons.group,
        loading: sending,
        onPressed: sending ? null : submit,
      ),
      child: CsacCustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: loadPublicGroups),
          SliverToBoxAdapter(
            child: _DiscoveryListSection(
              header: strings.text('Join request'),
              footer: strings.text(
                'Invite code and answer are optional unless the group requires them.',
              ),
              children: [
                _DiscoveryFormFieldTile(
                  label: strings.text('Room ID'),
                  controller: roomId,
                  icon: CupertinoIcons.tag,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),
                _DiscoveryFormFieldTile(
                  label: strings.text('Invite code'),
                  controller: code,
                  icon: CupertinoIcons.lock,
                  textInputAction: TextInputAction.next,
                ),
                _DiscoveryFormFieldTile(
                  label: strings.text('Answer'),
                  controller: answer,
                  icon: CupertinoIcons.question_circle,
                  minLines: 2,
                  maxLines: 4,
                ),
              ],
            ),
          ),
          if (error != null)
            SliverToBoxAdapter(
              child: _DiscoveryErrorBanner(
                message: error!,
                onDismiss: () => setState(() => error = null),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: _CupertinoSearchField(
                controller: search,
                placeholder: strings.text('Search public groups'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          if (loading)
            SliverToBoxAdapter(
              child: _DiscoveryProgressStrip(
                label: strings.text('Loading public groups...'),
              ),
            )
          else if (groups.isEmpty)
            SliverToBoxAdapter(
              child: _DiscoveryEmptyState(
                icon: CupertinoIcons.group,
                message: strings.text('No public groups.'),
              ),
            )
          else
            SliverToBoxAdapter(
              child: _DiscoveryListSection(
                header: strings.text('Public groups'),
                footer: strings.text(
                  'Pick a public group below to fill the room ID.',
                ),
                children: [
                  for (final group in groups)
                    _PublicGroupTile(
                      group: group,
                      selected: roomId.text.trim() == '${group.id}',
                      sending: sending,
                      onUse: () => useGroup(group),
                      onJoin: () {
                        useGroup(group);
                        submit(groupId: group.id);
                      },
                      onOpen: () => openGroupDetail(group),
                    ),
                ],
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
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
      await _showDiscoverySuccess(
        context,
        context.strings.format('Group created: {name}', {'name': group.name}),
      );
      if (!mounted) {
        return;
      }
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
    return _DiscoveryPage(
      title: strings.text('Create group'),
      bottomBar: _DiscoveryPrimaryBar(
        label: strings.text('Create group'),
        icon: CupertinoIcons.plus_circle,
        loading: creating,
        onPressed: creating ? null : submit,
      ),
      child: CsacCustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _DiscoveryListSection(
              header: strings.text('Group profile'),
              footer: strings.text(
                'You can edit group details after creation.',
              ),
              children: [
                _DiscoveryFormFieldTile(
                  label: strings.text('Room name'),
                  controller: roomName,
                  icon: CupertinoIcons.group,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => submit(),
                ),
              ],
            ),
          ),
          if (error != null)
            SliverToBoxAdapter(
              child: _DiscoveryErrorBanner(
                message: error!,
                onDismiss: () => setState(() => error = null),
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
        ],
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
    setState(() {});
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
    final colors = CsacColors.of(context);
    final emptyMessage =
        search.text.trim().isEmpty &&
            scope != SearchScope.image &&
            scope != SearchScope.essence
        ? strings.text('Type to search cached messages.')
        : strings.text('No matching messages.');
    final body = SafeArea(
      top: widget.embedded,
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: _CupertinoSearchField(
              controller: search,
              placeholder: strings.text('Search cached messages'),
              onChanged: (_) => scheduleSearch(),
              autofocus: !widget.embedded,
            ),
          ),
          SizedBox(
            height: 52,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  ui.PointerDeviceKind.touch,
                  ui.PointerDeviceKind.mouse,
                  ui.PointerDeviceKind.stylus,
                  ui.PointerDeviceKind.invertedStylus,
                  ui.PointerDeviceKind.unknown,
                },
              ),
              child: CsacListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                children: [
                  _SearchScopeSegment(
                    icon: CupertinoIcons.rectangle_stack,
                    label: strings.text('All'),
                    selected: scope == SearchScope.all,
                    onTap: () => setScope(SearchScope.all),
                  ),
                  const SizedBox(width: 8),
                  _SearchScopeSegment(
                    icon: CupertinoIcons.person_fill,
                    label: strings.text('Friends'),
                    selected: scope == SearchScope.private,
                    onTap: () => setScope(SearchScope.private),
                  ),
                  const SizedBox(width: 8),
                  _SearchScopeSegment(
                    icon: CupertinoIcons.group,
                    label: strings.text('Groups'),
                    selected: scope == SearchScope.group,
                    onTap: () => setScope(SearchScope.group),
                  ),
                  const SizedBox(width: 8),
                  _SearchScopeSegment(
                    icon: CupertinoIcons.photo,
                    label: strings.text('Images'),
                    selected: scope == SearchScope.image,
                    onTap: () => setScope(SearchScope.image),
                  ),
                  const SizedBox(width: 8),
                  _SearchScopeSegment(
                    icon: CupertinoIcons.star,
                    label: strings.text('Essence'),
                    selected: scope == SearchScope.essence,
                    onTap: () => setScope(SearchScope.essence),
                  ),
                ],
              ),
            ),
          ),
          if (loading)
            _DiscoveryProgressStrip(label: strings.text('Searching...'))
          else
            Container(
              height: 0.5,
              color: colors.separator.withValues(alpha: 0.6),
            ),
          if (error != null)
            _DiscoveryErrorBanner(
              message: error!,
              onDismiss: () => setState(() => error = null),
            ),
          Expanded(
            child: results.isEmpty
                ? _DiscoveryEmptyState(
                    icon: CupertinoIcons.search,
                    message: emptyMessage,
                  )
                : CsacListView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(bottom: 18),
                    children: [
                      _DiscoveryListSection(
                        header: strings.text('Results'),
                        children: [
                          for (var index = 0; index < results.length; index++)
                            _MotionListItem(
                              index: index,
                              child: _SearchResultTile(
                                result: results[index],
                                preferences: widget.state.preferences,
                                onTap: () => openResult(results[index]),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
    if (widget.embedded) {
      return ColoredBox(color: colors.systemBackground, child: body);
    }
    return CupertinoPageScaffold(
      backgroundColor: colors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(strings.text('Search messages')),
        backgroundColor: colors.navBarBackground,
        border: null,
      ),
      child: body,
    );
  }
}

class SpaceTimelineScreen extends StatefulWidget {
  const SpaceTimelineScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  State<SpaceTimelineScreen> createState() => _SpaceTimelineScreenState();
}

class _SpaceTimelineScreenState extends State<SpaceTimelineScreen> {
  List<SpacePost> posts = const <SpacePost>[];
  bool loading = true;
  bool loadingMore = false;
  int page = 1;
  int total = 0;
  String? error;

  bool get hasMore => posts.length < total;

  @override
  void initState() {
    super.initState();
    unawaited(load(refresh: true));
  }

  Future<void> load({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        loading = true;
        error = null;
        page = 1;
      });
    } else {
      setState(() => loadingMore = true);
    }
    try {
      final loaded = await widget.state.loadSpacePosts(
        page: refresh ? 1 : page + 1,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        total = loaded.total;
        page = loaded.page;
        posts = refresh ? loaded.items : [...posts, ...loaded.items];
      });
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          loadingMore = false;
        });
      }
    }
  }

  Future<void> openComposer({SpacePost? replyTo}) async {
    final changed = await Navigator.of(context).push<bool>(
      CsacPageRoute<bool>(
        builder: (_) =>
            SpaceComposerScreen(state: widget.state, replyTo: replyTo),
      ),
    );
    if (changed == true && mounted) {
      await load(refresh: true);
    }
  }

  Future<void> toggleLike(SpacePost post) async {
    final previousPosts = posts;
    final optimistic = post.copyWith(
      isLiked: !post.isLiked,
      likes: math.max(0, post.likes + (post.isLiked ? -1 : 1)),
    );
    setState(() {
      error = null;
      posts = _replaceSpacePost(posts, optimistic);
    });
    try {
      final updated = await widget.state.toggleSpaceLike(post.id);
      if (mounted) {
        setState(() => posts = _replaceSpacePost(posts, updated));
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          posts = previousPosts;
          error = err.toString();
        });
      }
    }
  }

  Future<void> deletePost(SpacePost post) async {
    final strings = context.strings;
    final confirmed = await showCupertinoCsacDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(strings.text('Delete post?')),
        content: Text(strings.text('This space post will be deleted.')),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.text('Cancel')),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.text('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.state.deleteSpacePost(post.id);
      if (mounted) {
        await load(refresh: true);
      }
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return _DiscoveryPage(
      title: strings.text('Space'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(36),
            onPressed: loading ? null : () => load(refresh: true),
            child: loading
                ? CupertinoActivityIndicator(
                    radius: 9,
                    color: colors.primaryColor,
                  )
                : Icon(
                    CupertinoIcons.refresh,
                    size: 20,
                    color: colors.primaryColor,
                  ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(36),
            onPressed: () => openComposer(),
            child: Icon(
              CupertinoIcons.square_pencil,
              size: 22,
              color: colors.primaryColor,
            ),
          ),
        ],
      ),
      child: CsacCustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: () => load(refresh: true)),
          if (error != null)
            SliverToBoxAdapter(
              child: _DiscoveryErrorBanner(
                message: error!,
                onDismiss: () => setState(() => error = null),
              ),
            ),
          if (loading)
            SliverToBoxAdapter(
              child: _DiscoveryProgressStrip(
                label: strings.text('Loading space posts...'),
              ),
            )
          else if (posts.isEmpty)
            SliverToBoxAdapter(
              child: _DiscoveryEmptyState(
                icon: CupertinoIcons.sparkles,
                message: strings.text('No space posts yet.'),
              ),
            )
          else
            SliverList.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) => _SpacePostCard(
                post: posts[index],
                currentUid: widget.state.user?.uid ?? 0,
                onLike: () => toggleLike(posts[index]),
                onReply: () => openComposer(replyTo: posts[index]),
                onDelete: deletePost,
              ),
            ),
          if (!loading && hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                child: CupertinoButton(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(14),
                  onPressed: loadingMore ? null : () => load(),
                  child: loadingMore
                      ? CupertinoActivityIndicator(
                          radius: 9,
                          color: colors.primaryColor,
                        )
                      : Text(strings.text('Load more')),
                ),
              ),
            )
          else
            const SliverPadding(padding: EdgeInsets.only(bottom: 96)),
        ],
      ),
    );
  }
}

List<SpacePost> _replaceSpacePost(List<SpacePost> items, SpacePost updated) {
  return [
    for (final item in items)
      if (item.id == updated.id)
        item.copyWith(likes: updated.likes, isLiked: updated.isLiked)
      else
        item.copyWith(
          replies: [
            for (final reply in item.replies)
              reply.id == updated.id
                  ? reply.copyWith(
                      likes: updated.likes,
                      isLiked: updated.isLiked,
                    )
                  : reply,
          ],
        ),
  ];
}

class SpaceComposerScreen extends StatefulWidget {
  const SpaceComposerScreen({super.key, required this.state, this.replyTo});

  final CsacAppState state;
  final SpacePost? replyTo;

  @override
  State<SpaceComposerScreen> createState() => _SpaceComposerScreenState();
}

class _SpaceComposerScreenState extends State<SpaceComposerScreen> {
  final content = TextEditingController();
  final picker = ImagePicker();
  final imageBytes = <Uint8List>[];
  final imageNames = <String>[];
  bool sending = false;
  String? error;

  @override
  void dispose() {
    content.dispose();
    super.dispose();
  }

  Future<void> pickImages() async {
    final picked = await picker.pickMultiImage(imageQuality: 86);
    if (picked.isEmpty || !mounted) {
      return;
    }
    for (final image in picked.take(9 - imageBytes.length)) {
      imageBytes.add(await image.readAsBytes());
      imageNames.add(image.name.trim().isEmpty ? 'space.jpg' : image.name);
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> submit() async {
    final text = content.text.trim();
    final strings = context.strings;
    if (text.isEmpty && imageBytes.isEmpty) {
      setState(() => error = strings.text('Write something or choose images.'));
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final replyTo = widget.replyTo;
      if (replyTo == null) {
        await widget.state.sendSpacePost(
          text,
          imageBytes: imageBytes,
          imageFileNames: imageNames,
        );
      } else {
        await widget.state.replySpacePost(
          replyTo.id,
          text,
          imageBytes: imageBytes,
          imageFileNames: imageNames,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
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

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final replyTo = widget.replyTo;
    return _DiscoveryPage(
      title: strings.text(replyTo == null ? 'Post update' : 'Reply post'),
      bottomBar: _DiscoveryPrimaryBar(
        label: strings.text(replyTo == null ? 'Post update' : 'Reply'),
        icon: CupertinoIcons.paperplane_fill,
        loading: sending,
        onPressed: sending ? null : submit,
      ),
      child: CsacCustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _DiscoveryListSection(
              header: strings.text(
                replyTo == null ? 'New space post' : 'Reply to',
              ),
              footer: strings.text('You can attach up to 9 images.'),
              children: [
                if (replyTo != null)
                  CupertinoListTile(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    leading: _Avatar(
                      url: replyTo.avatar,
                      fallback: CupertinoIcons.person_fill,
                      name: replyTo.nickname,
                    ),
                    title: Text(replyTo.nickname),
                    subtitle: Text(
                      replyTo.content.isEmpty
                          ? strings.text('[image]')
                          : replyTo.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                _DiscoveryFormFieldTile(
                  label: strings.text('Content'),
                  controller: content,
                  icon: CupertinoIcons.text_bubble,
                  minLines: 5,
                  maxLines: 8,
                ),
                _DiscoveryActionTile(
                  label: strings.text('Choose images'),
                  icon: CupertinoIcons.photo_on_rectangle,
                  loading: false,
                  onTap: imageBytes.length >= 9 ? null : pickImages,
                ),
              ],
            ),
          ),
          if (imageBytes.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in imageBytes.indexed)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              entry.$2,
                              width: 86,
                              height: 86,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size.square(24),
                              color: CupertinoColors.black.withValues(
                                alpha: 0.45,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              onPressed: () => setState(() {
                                imageBytes.removeAt(entry.$1);
                                imageNames.removeAt(entry.$1);
                              }),
                              child: const Icon(
                                CupertinoIcons.xmark,
                                size: 13,
                                color: CupertinoColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          if (error != null)
            SliverToBoxAdapter(
              child: _DiscoveryErrorBanner(
                message: error!,
                onDismiss: () => setState(() => error = null),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Text(
                strings.text('Friends can see your space posts.'),
                style: TextStyle(color: colors.secondaryLabel, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpacePostCard extends StatelessWidget {
  const _SpacePostCard({
    required this.post,
    required this.currentUid,
    required this.onLike,
    required this.onReply,
    required this.onDelete,
  });

  final SpacePost post;
  final int currentUid;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final ValueChanged<SpacePost> onDelete;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.separator.withValues(alpha: 0.24),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(
                url: post.avatar,
                fallback: CupertinoIcons.person_fill,
                name: post.nickname,
                radius: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.nickname.isEmpty
                          ? 'UID ${post.senderUid}'
                          : post.nickname,
                      style: TextStyle(
                        color: colors.label,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (post.createdAt.isNotEmpty)
                      Text(
                        post.createdAt,
                        style: TextStyle(
                          color: colors.secondaryLabel,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (post.senderUid == currentUid)
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size.square(32),
                  onPressed: () => onDelete(post),
                  child: Icon(
                    CupertinoIcons.delete,
                    size: 18,
                    color: colors.destructive,
                  ),
                ),
            ],
          ),
          if (post.content.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              post.content.trim(),
              style: TextStyle(color: colors.label, fontSize: 15, height: 1.35),
            ),
          ],
          if (post.images.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SpaceImageGrid(images: post.images),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                borderRadius: BorderRadius.circular(999),
                color: post.isLiked
                    ? primary.withValues(alpha: colors.isDark ? 0.22 : 0.12)
                    : colors.tertiaryFill,
                onPressed: onLike,
                child: SizedBox(
                  width: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                        ),
                        child: SizedBox(
                          key: ValueKey<bool>(post.isLiked),
                          width: 16,
                          height: 16,
                          child: Center(
                            child: Transform.translate(
                              offset: Offset(post.isLiked ? -0.8 : 0, 0),
                              child: Icon(
                                post.isLiked
                                    ? CupertinoIcons.heart_fill
                                    : CupertinoIcons.heart,
                                size: 15,
                                color: post.isLiked
                                    ? primary
                                    : colors.secondaryLabel,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: Text(
                          '${post.likes}',
                          key: ValueKey<int>(post.likes),
                          style: TextStyle(
                            color: post.isLiked
                                ? primary
                                : colors.secondaryLabel,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                borderRadius: BorderRadius.circular(999),
                color: colors.tertiaryFill,
                onPressed: onReply,
                child: Text(strings.text('Reply')),
              ),
            ],
          ),
          if (post.replies.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: colors.tertiaryFill.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (final reply in post.replies)
                    _SpaceReplyTile(
                      reply: reply,
                      canDelete: reply.senderUid == currentUid,
                      onDelete: () => onDelete(reply),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SpaceImageGrid extends StatelessWidget {
  const _SpaceImageGrid({required this.images});

  final List<String> images;

  @override
  Widget build(BuildContext context) {
    if (images.length == 1) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width - 56;
          return _SpaceImageTile(
            image: images.first,
            single: true,
            maxWidth: availableWidth,
          );
        },
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 56;
        final columns = images.length == 4 ? 2 : 3;
        final tileSize = ((availableWidth - 6 * (columns - 1)) / columns)
            .clamp(64.0, 120.0)
            .toDouble();
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final image in images.take(9))
              _SpaceImageTile(image: image, size: tileSize),
          ],
        );
      },
    );
  }
}

class _SpaceImageTile extends StatelessWidget {
  const _SpaceImageTile({
    required this.image,
    this.size,
    this.single = false,
    this.maxWidth,
  });

  final String image;
  final double? size;
  final bool single;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final width = single
        ? math
              .min((maxWidth ?? MediaQuery.sizeOf(context).width - 56), 300)
              .toDouble()
        : size!;
    final image = Image.network(
      this.image,
      width: single ? width : size,
      height: single ? null : size,
      fit: single ? BoxFit.contain : BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Container(
        width: single ? width : size,
        height: single ? 160 : size,
        color: colors.tertiaryFill,
        alignment: Alignment.center,
        child: Icon(CupertinoIcons.photo, color: colors.tertiaryLabel),
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showImagePreview(context, this.image),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: single
            ? ConstrainedBox(
                constraints: BoxConstraints(maxWidth: width, maxHeight: 360),
                child: image,
              )
            : Container(
                width: size,
                height: size,
                color: CupertinoColors.black,
                alignment: Alignment.center,
                child: image,
              ),
      ),
    );
  }
}

class _SpaceReplyTile extends StatelessWidget {
  const _SpaceReplyTile({
    required this.reply,
    required this.canDelete,
    required this.onDelete,
  });

  final SpacePost reply;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: reply.nickname.isEmpty
                            ? 'UID ${reply.senderUid}'
                            : reply.nickname,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const TextSpan(text: ': '),
                      TextSpan(
                        text: reply.content.trim().isEmpty
                            ? strings.text('[image]')
                            : reply.content.trim(),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    color: colors.label,
                    fontSize: 13,
                    height: 1.28,
                  ),
                ),
                if (reply.images.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _SpaceImageGrid(images: reply.images),
                ],
              ],
            ),
          ),
          if (canDelete)
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(24),
              onPressed: onDelete,
              child: Icon(
                CupertinoIcons.delete,
                size: 14,
                color: colors.destructive,
              ),
            ),
        ],
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
    final subtitleParts = <String>[
      if (message.sender.trim().isNotEmpty) message.sender.trim(),
      if (time.isNotEmpty) time,
    ];
    return CupertinoListTile(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      leading: _Avatar(
        url: result.conversation.avatar,
        fallback: isGroup ? CupertinoIcons.group_solid : CupertinoIcons.person,
        name: result.conversation.name,
        radius: 20,
      ),
      title: Text(
        result.conversation.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.label,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitleParts.isNotEmpty)
            Text(
              subtitleParts.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.secondaryLabel, fontSize: 13),
            ),
          if (result.snippet.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              result.snippet.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.secondaryLabel),
            ),
          ],
        ],
      ),
      trailing: Icon(
        message.imageUrl.isNotEmpty
            ? CupertinoIcons.photo
            : message.isEssence
            ? CupertinoIcons.star
            : CupertinoIcons.chevron_right,
        color: colors.tertiaryLabel,
        size: 18,
      ),
      onTap: onTap,
    );
  }
}

class _DiscoveryPage extends StatelessWidget {
  const _DiscoveryPage({
    required this.title,
    required this.child,
    this.trailing,
    this.bottomBar,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return CupertinoPageScaffold(
      backgroundColor: colors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        trailing: trailing,
        backgroundColor: colors.navBarBackground,
        border: null,
      ),
      child: SafeArea(
        top: true,
        bottom: false,
        child: _AdaptivePageFrame(
          maxWidth: 820,
          child: Column(
            children: [
              Expanded(child: child),
              if (bottomBar != null) bottomBar!,
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoveryPrimaryBar extends StatelessWidget {
  const _DiscoveryPrimaryBar({
    required this.label,
    required this.icon,
    required this.loading,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.systemBackground.withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: colors.separator, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: CupertinoButton.filled(
            onPressed: loading ? null : onPressed,
            borderRadius: BorderRadius.circular(14),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const CupertinoActivityIndicator(
                    radius: 8,
                    color: CupertinoColors.white,
                  )
                else
                  Icon(icon, size: 18, color: CupertinoColors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoveryListSection extends StatelessWidget {
  const _DiscoveryListSection({
    required this.children,
    this.header,
    this.footer,
  });

  final List<Widget> children;
  final String? header;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return CupertinoListSection.insetGrouped(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 12),
      backgroundColor: Colors.transparent,
      header: header == null ? null : Text(header!),
      footer: footer == null ? null : Text(footer!),
      children: children,
    );
  }
}

class _DiscoveryFormFieldTile extends StatelessWidget {
  const _DiscoveryFormFieldTile({
    required this.label,
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final multiline = minLines > 1 || maxLines > 1;
    return CupertinoListTile(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      leading: Icon(icon, size: 19, color: colors.secondaryLabel),
      title: Text(
        label,
        style: TextStyle(
          color: colors.secondaryLabel,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: CupertinoTextField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          minLines: minLines,
          maxLines: maxLines,
          style: TextStyle(color: colors.label, fontSize: 15),
          placeholderStyle: TextStyle(
            color: colors.tertiaryLabel,
            fontSize: 15,
          ),
          cursorColor: colors.primaryColor,
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: multiline ? 10 : 9,
          ),
          decoration: BoxDecoration(
            color: colors.tertiaryFill,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _DiscoveryActionTile extends StatelessWidget {
  const _DiscoveryActionTile({
    required this.label,
    required this.icon,
    required this.loading,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return CupertinoListTile(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      leading: Icon(icon, size: 19, color: colors.primaryColor),
      title: Text(
        label,
        style: TextStyle(color: colors.label, fontWeight: FontWeight.w600),
      ),
      trailing: loading
          ? CupertinoActivityIndicator(radius: 8, color: colors.primaryColor)
          : _DiscoveryChevron(),
      onTap: onTap,
    );
  }
}

class _DiscoveryErrorBanner extends StatelessWidget {
  const _DiscoveryErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final tint = CupertinoColors.systemRed.resolveFrom(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: colors.isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            size: 16,
            color: tint,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.label, fontSize: 14),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            onPressed: onDismiss,
            child: Text(context.strings.text('Dismiss')),
          ),
        ],
      ),
    );
  }
}

class _DiscoveryEmptyState extends StatelessWidget {
  const _DiscoveryEmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: colors.tertiaryLabel),
            const SizedBox(height: 9),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.secondaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryProgressStrip extends StatelessWidget {
  const _DiscoveryProgressStrip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.cardBackground,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(radius: 8, color: colors.primaryColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.secondaryLabel, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryChevron extends StatelessWidget {
  const _DiscoveryChevron();

  @override
  Widget build(BuildContext context) {
    return Icon(
      CupertinoIcons.chevron_right,
      size: 14,
      color: CsacColors.of(context).tertiaryLabel,
    );
  }
}

class _PublicGroupTile extends StatelessWidget {
  const _PublicGroupTile({
    required this.group,
    required this.selected,
    required this.sending,
    required this.onUse,
    required this.onJoin,
    required this.onOpen,
  });

  final GroupProfile group;
  final bool selected;
  final bool sending;
  final VoidCallback onUse;
  final VoidCallback onJoin;
  final VoidCallback onOpen;

  String detailText(BuildContext context) {
    final strings = context.strings;
    return [
      strings.format('Room {id}', {'id': group.id}),
      if (group.subtitle.trim().isNotEmpty) group.subtitle.trim(),
      if (group.description.trim().isNotEmpty) group.description.trim(),
      if (group.notice.trim().isNotEmpty) group.notice.trim(),
    ].join(' | ');
  }

  String? requirementText(BuildContext context) {
    final strings = context.strings;
    final invite = group.code.trim();
    final question = group.question.trim();
    if (invite.isEmpty && question.isEmpty) {
      return null;
    }
    if (invite.isNotEmpty && question.isNotEmpty) {
      return '${strings.text('Invite code')}: $invite · $question';
    }
    if (invite.isNotEmpty) {
      return '${strings.text('Invite code')}: $invite';
    }
    return question;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    final requirement = requirementText(context);
    final buttonColor = selected
        ? primary
        : primary.withValues(alpha: colors.isDark ? 0.22 : 0.12);
    final buttonForeground = selected ? CupertinoColors.white : primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CupertinoListPressable(
          onTap: onUse,
          onLongPress: onOpen,
          onSecondaryTap: onOpen,
          child: CupertinoListTile(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
            leading: _Avatar(
              url: group.avatar,
              fallback: CupertinoIcons.group_solid,
              name: group.name,
              radius: 20,
            ),
            title: Text(
              group.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.label,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detailText(context),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.secondaryLabel, fontSize: 13),
                ),
                if (requirement != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    requirement,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.tertiaryLabel, fontSize: 12),
                  ),
                ],
              ],
            ),
            trailing: selected
                ? Icon(
                    CupertinoIcons.check_mark_circled_solid,
                    size: 20,
                    color: primary,
                  )
                : const _DiscoveryChevron(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(74, 0, 12, 10),
          child: Row(
            children: [
              const Spacer(),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                minimumSize: Size.zero,
                borderRadius: BorderRadius.circular(16),
                color: buttonColor,
                onPressed: sending ? null : onJoin,
                child: sending
                    ? CupertinoActivityIndicator(
                        radius: 8,
                        color: buttonForeground,
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.arrow_right_circle_fill,
                            size: 14,
                            color: buttonForeground,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            strings.text('Join'),
                            style: TextStyle(
                              color: buttonForeground,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchScopeSegment extends StatelessWidget {
  const _SearchScopeSegment({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    return _CsacPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 160.ms,
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: colors.isDark ? 0.22 : 0.13)
              : colors.cardBackground,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? primary.withValues(alpha: 0.24)
                : colors.separator.withValues(alpha: 0.24),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? primary : colors.secondaryLabel,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? primary : colors.label,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
