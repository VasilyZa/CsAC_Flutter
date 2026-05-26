part of '../../main.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.state,
    required this.conversation,
    this.focusMessageId,
    this.embedded = false,
  });

  final CsacAppState state;
  final Conversation conversation;
  final int? focusMessageId;
  final bool embedded;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final imagePicker = ImagePicker();
  final itemKeys = <int, GlobalKey>{};
  final messages = <ChatMessage>[];
  final mentionTargets = <GroupMember>[];
  Timer? timer;
  ChatMessage? replyTarget;
  int refreshTicks = 0;
  bool loading = true;
  bool refreshing = false;
  bool sending = false;
  bool offline = false;
  String? error;

  @override
  void initState() {
    super.initState();
    widget.state.setActiveConversation(widget.conversation);
    widget.state.markConversationRead(widget.conversation);
    loadInitial();
    timer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => refresh(silent: true),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    if (widget.state.isActiveConversation(widget.conversation)) {
      widget.state.setActiveConversation(null);
    }
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> markCurrentConversationRead() async {
    final lastMsgId = messages.isEmpty ? 0 : messages.last.id;
    await widget.state.markConversationRead(
      widget.conversation,
      lastMsgId: lastMsgId,
    );
  }

  Future<void> loadInitial() async {
    setState(() {
      loading = true;
      error = null;
      offline = false;
    });
    try {
      final focusId = widget.focusMessageId;
      final cached = focusId == null
          ? await widget.state.loadCachedMessages(widget.conversation)
          : await widget.state.loadCachedMessagesAround(
              widget.conversation,
              focusId,
            );
      if (!mounted) {
        return;
      }
      setState(() {
        messages
          ..clear()
          ..addAll(cached);
        loading = cached.isEmpty;
      });
      if (cached.isNotEmpty) {
        scrollAfterLoad();
      }
      final loaded = cached.isEmpty
          ? await widget.state.loadMessagesFromNetwork(widget.conversation)
          : await widget.state.syncMessages(
              widget.conversation,
              afterId: cached.last.id,
            );
      if (!mounted) {
        return;
      }
      setState(() {
        messages
          ..clear()
          ..addAll(mergeChatMessages(cached, loaded));
        offline = false;
      });
      await markCurrentConversationRead();
      scrollAfterLoad();
    } catch (err) {
      if (!mounted) {
        return;
      }
      setState(() {
        offline = messages.isNotEmpty;
        error = messages.isEmpty
            ? err.toString()
            : context.strings.format('Offline cache: {error}', {'error': err});
      });
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> reloadConversationFromNetwork({bool showLoading = false}) async {
    if (!mounted) {
      return;
    }
    if (showLoading) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final loaded = await widget.state.reloadMessagesFromNetwork(
        widget.conversation,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        messages
          ..clear()
          ..addAll(loaded);
        offline = false;
      });
      await markCurrentConversationRead();
      scrollAfterLoad();
    } catch (err) {
      if (mounted) {
        setState(() {
          error = err.toString();
          offline = messages.isNotEmpty;
        });
      }
    } finally {
      if (showLoading && mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> refresh({bool silent = false}) async {
    if (!mounted || refreshing) {
      return;
    }
    refreshing = true;
    try {
      refreshTicks += 1;
      if (silent && refreshTicks % 8 == 0) {
        final loaded = await widget.state.reloadMessagesFromNetwork(
          widget.conversation,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          messages
            ..clear()
            ..addAll(loaded);
          offline = false;
        });
        await markCurrentConversationRead();
        return;
      }
      final afterId = messages.isEmpty ? 0 : messages.last.id;
      final loaded = await widget.state.syncMessages(
        widget.conversation,
        afterId: afterId,
      );
      if (loaded.isEmpty) {
        if (offline && mounted) {
          setState(() => offline = false);
        }
        return;
      }
      final merged = mergeChatMessages(messages, loaded);
      setState(() {
        messages
          ..clear()
          ..addAll(merged);
        offline = false;
      });
      await markCurrentConversationRead();
      if (widget.focusMessageId == null) {
        scrollToEnd();
      }
    } catch (err) {
      if (!mounted) {
        return;
      }
      if (!silent) {
        setState(() => error = err.toString());
      }
      if (mounted) {
        setState(() => offline = messages.isNotEmpty);
      }
    } finally {
      refreshing = false;
    }
  }

  Future<void> send() async {
    final text = input.text.trim();
    if (text.isEmpty || sending) {
      return;
    }
    setState(() => sending = true);
    try {
      await widget.state.client.sendMessage(
        widget.conversation,
        text,
        replyTo: replyTarget?.id ?? 0,
        mentionUids: mentionTargets.map((member) => member.uid).toList(),
      );
      input.clear();
      clearComposeTargets();
      await widget.state.markConversationRead(widget.conversation);
      await refresh(silent: true);
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

  Future<void> pickAndSendImage() async {
    if (sending) {
      return;
    }
    final picked = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (picked == null || !mounted) {
      return;
    }
    final bytes = await picked.readAsBytes();
    if (!mounted) {
      return;
    }
    final caption = await showDialog<String>(
      context: context,
      builder: (context) =>
          _ImageCaptionDialog(fileName: picked.name, bytes: bytes),
    );
    if (caption == null) {
      return;
    }
    setState(() => sending = true);
    try {
      await widget.state.client.sendImageMessage(
        widget.conversation,
        bytes,
        picked.name,
        caption: caption.trim(),
        replyTo: replyTarget?.id ?? 0,
        mentionUids: mentionTargets.map((member) => member.uid).toList(),
      );
      clearComposeTargets();
      await widget.state.markConversationRead(widget.conversation);
      await refresh(silent: true);
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

  void clearComposeTargets() {
    if (!mounted) {
      return;
    }
    setState(() {
      replyTarget = null;
      mentionTargets.clear();
    });
  }

  void setReplyTarget(ChatMessage message) {
    setState(() => replyTarget = message);
  }

  Future<void> chooseMentionTargets() async {
    if (widget.conversation.type != ConversationType.group) {
      return;
    }
    try {
      final members = await widget.state.loadGroupMembers(
        widget.conversation.id,
      );
      if (!mounted) {
        return;
      }
      final selected = await showModalBottomSheet<List<GroupMember>>(
        context: context,
        showDragHandle: true,
        builder: (context) => _MentionPickerSheet(
          members: members,
          selectedUids: mentionTargets.map((member) => member.uid).toSet(),
        ),
      );
      if (selected == null || !mounted) {
        return;
      }
      setState(() {
        mentionTargets
          ..clear()
          ..addAll(selected);
      });
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    }
  }

  void replaceMessageLocally(ChatMessage replacement) {
    final index = messages.indexWhere(
      (message) => message.id == replacement.id,
    );
    if (index < 0) {
      return;
    }
    setState(() => messages[index] = replacement);
  }

  Future<void> recallMessage(ChatMessage message) async {
    final recalledBody = context.strings.text('[recalled]');
    try {
      await widget.state.recallMessage(widget.conversation, message.id);
      final recalled = message.copyWith(
        body: recalledBody,
        imageUrl: '',
        canRecall: false,
        isRecalled: true,
      );
      replaceMessageLocally(recalled);
      await widget.state.cache.saveMessages(widget.conversation, [recalled]);
      await reloadConversationFromNetwork();
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    }
  }

  Future<void> toggleEssence(ChatMessage message) async {
    if (widget.conversation.type != ConversationType.group) {
      return;
    }
    try {
      await widget.state.toggleEssence(widget.conversation.id, message.id);
      final updated = message.copyWith(isEssence: !message.isEssence);
      replaceMessageLocally(updated);
      await widget.state.cache.saveMessages(widget.conversation, [updated]);
      await reloadConversationFromNetwork();
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    }
  }

  Future<void> openEssenceList() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EssenceMessagesScreen(
          state: widget.state,
          conversation: widget.conversation,
        ),
      ),
    );
  }

  Future<void> showMessageActions(ChatMessage message, bool mine) async {
    final action = await showModalBottomSheet<_MessageAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => _MessageActionSheet(
        message: message,
        canRecall: message.canRecall || mine,
        canEssence: widget.conversation.type == ConversationType.group,
      ),
    );
    if (action == null || !mounted) {
      return;
    }
    switch (action) {
      case _MessageAction.copyText:
        Clipboard.setData(
          ClipboardData(
            text:
                '#${message.id} ${message.sender}\n${message.time}\n\n${message.body}',
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.text('Message copied'))),
        );
        break;
      case _MessageAction.copyImage:
        Clipboard.setData(ClipboardData(text: message.imageUrl));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.text('Image link copied'))),
        );
        break;
      case _MessageAction.openImage:
        showImagePreview(context, message.imageUrl);
        break;
      case _MessageAction.downloadImage:
        await downloadImage(context, message.imageUrl);
        break;
      case _MessageAction.reply:
        setReplyTarget(message);
        break;
      case _MessageAction.recall:
        await recallMessage(message);
        break;
      case _MessageAction.essence:
        await toggleEssence(message);
        break;
    }
  }

  void scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scroll.hasClients) {
        return;
      }
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void scrollAfterLoad() {
    final focusId = widget.focusMessageId;
    if (focusId == null) {
      scrollToEnd();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyContext = itemKeys[focusId]?.currentContext;
      if (keyContext == null) {
        scrollToEnd();
        return;
      }
      Scrollable.ensureVisible(
        keyContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        alignment: 0.42,
      );
    });
  }

  void scrollToMessage(int messageId) {
    final keyContext = itemKeys[messageId]?.currentContext;
    if (keyContext == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.text('Referenced message is not loaded.'),
          ),
        ),
      );
      return;
    }
    Scrollable.ensureVisible(
      keyContext,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      alignment: 0.42,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(
          widget.conversation.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (offline)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.cloud_off_outlined),
            ),
          IconButton(
            tooltip: context.strings.text('Refresh'),
            onPressed: () => reloadConversationFromNetwork(showLoading: true),
            icon: const Icon(Icons.refresh),
          ),
          if (widget.conversation.type == ConversationType.group)
            IconButton(
              tooltip: context.strings.text('Essence'),
              onPressed: openEssenceList,
              icon: const Icon(Icons.star_outline),
            ),
          IconButton(
            tooltip: context.strings.text('Details'),
            onPressed: () {
              if (widget.conversation.type == ConversationType.private) {
                openUserProfile(context, widget.state, widget.conversation.id);
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ConversationDetailScreen(
                    state: widget.state,
                    conversation: widget.conversation,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          if (error != null)
            MaterialBanner(
              content: Text(error!),
              actions: [
                TextButton(
                  onPressed: () => setState(() => error = null),
                  child: Text(context.strings.text('Dismiss')),
                ),
              ],
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? _EmptyPanel(message: context.strings.text('No messages.'))
                : ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final mine = widget.state.user?.uid == message.senderId;
                      final replyMessage = messages
                          .where((item) => item.id == message.replyTo)
                          .cast<ChatMessage?>()
                          .firstOrNull;
                      return _MessageBubble(
                        key: itemKeys.putIfAbsent(
                          message.id,
                          () => GlobalKey(),
                        ),
                        message: message,
                        replyMessage: replyMessage,
                        mine: mine,
                        focused: widget.focusMessageId == message.id,
                        onLongPress: () => showMessageActions(message, mine),
                        onReplyTap: message.replyTo > 0
                            ? () => scrollToMessage(message.replyTo)
                            : null,
                        onImageTap: message.imageUrl.isEmpty
                            ? null
                            : () => showImagePreview(context, message.imageUrl),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (replyTarget != null || mentionTargets.isNotEmpty)
                    _ComposeTargetsBar(
                      replyTarget: replyTarget,
                      mentions: mentionTargets,
                      onClearReply: () => setState(() => replyTarget = null),
                      onClearMentions: () =>
                          setState(() => mentionTargets.clear()),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: input,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => send(),
                          decoration: InputDecoration(
                            hintText: context.strings.text('Message'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (widget.conversation.type == ConversationType.group)
                        IconButton.filledTonal(
                          tooltip: context.strings.text('Mention'),
                          onPressed: sending ? null : chooseMentionTargets,
                          icon: const Icon(Icons.alternate_email),
                        ),
                      if (widget.conversation.type == ConversationType.group)
                        const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: context.strings.text('Image'),
                        onPressed: sending ? null : pickAndSendImage,
                        icon: const Icon(Icons.image_outlined),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: sending ? null : send,
                        child: sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    this.replyMessage,
    required this.mine,
    this.focused = false,
    this.onLongPress,
    this.onReplyTap,
    this.onImageTap,
  });

  final ChatMessage message;
  final ChatMessage? replyMessage;
  final bool mine;
  final bool focused;
  final VoidCallback? onLongPress;
  final VoidCallback? onReplyTap;
  final VoidCallback? onImageTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final color = mine
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    final textColor = mine ? colors.onPrimaryContainer : colors.onSurface;
    final secondaryTextColor = mine
        ? colors.onPrimaryContainer.withValues(alpha: 0.72)
        : colors.onSurfaceVariant;
    final replyColor = mine
        ? colors.primary.withValues(alpha: 0.12)
        : colors.surfaceContainerHigh;
    final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: align,
          children: [
            Text(
              '${message.sender}${message.time.isEmpty ? '' : ' · ${message.time}'}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: focused
                      ? colors.primary
                      : mine
                      ? colors.primaryContainer
                      : colors.outlineVariant,
                  width: focused ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.replyTo > 0) ...[
                    InkWell(
                      onTap: onReplyTap,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: replyColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          replyMessage == null
                              ? strings.format('Reply #{id}', {
                                  'id': message.replyTo,
                                })
                              : strings.format('Reply {sender}: {message}', {
                                  'sender': replyMessage!.sender,
                                  'message': compactMessage(replyMessage!.body),
                                }),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: secondaryTextColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (message.isMentioned || message.isEssence) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (message.isMentioned)
                          Chip(
                            avatar: const Icon(Icons.alternate_email, size: 16),
                            label: Text(strings.text('Mentioned')),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (message.isEssence)
                          Chip(
                            avatar: const Icon(Icons.star, size: 16),
                            label: Text(strings.text('Essence')),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (message.imageUrl.isNotEmpty) ...[
                    _MessageImage(url: message.imageUrl, onTap: onImageTap),
                    if (message.body.isNotEmpty &&
                        !message.body.startsWith('[image]'))
                      const SizedBox(height: 8),
                  ],
                  if (message.body.isNotEmpty &&
                      !message.body.startsWith('[image]'))
                    Text(message.body, style: TextStyle(color: textColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _MessageAction {
  copyText,
  copyImage,
  openImage,
  downloadImage,
  reply,
  recall,
  essence,
}

class _MessageActionSheet extends StatelessWidget {
  const _MessageActionSheet({
    required this.message,
    required this.canRecall,
    required this.canEssence,
  });

  final ChatMessage message;
  final bool canRecall;
  final bool canEssence;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.reply),
            title: Text(strings.text('Reply')),
            subtitle: Text('#${message.id} ${message.sender}'),
            onTap: () => Navigator.of(context).pop(_MessageAction.reply),
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: Text(strings.text('Copy text')),
            onTap: () => Navigator.of(context).pop(_MessageAction.copyText),
          ),
          if (message.imageUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(strings.text('Copy image link')),
              onTap: () => Navigator.of(context).pop(_MessageAction.copyImage),
            ),
          if (message.imageUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text(strings.text('Open image')),
              onTap: () => Navigator.of(context).pop(_MessageAction.openImage),
            ),
          if (message.imageUrl.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(strings.text('Download image')),
              onTap: () =>
                  Navigator.of(context).pop(_MessageAction.downloadImage),
            ),
          if (canRecall)
            ListTile(
              leading: const Icon(Icons.undo),
              title: Text(strings.text('Recall')),
              onTap: () => Navigator.of(context).pop(_MessageAction.recall),
            ),
          if (canEssence)
            ListTile(
              leading: Icon(
                message.isEssence ? Icons.star : Icons.star_outline,
              ),
              title: Text(
                strings.text(
                  message.isEssence ? 'Remove essence' : 'Set essence',
                ),
              ),
              onTap: () => Navigator.of(context).pop(_MessageAction.essence),
            ),
        ],
      ),
    );
  }
}

class _ComposeTargetsBar extends StatelessWidget {
  const _ComposeTargetsBar({
    required this.replyTarget,
    required this.mentions,
    required this.onClearReply,
    required this.onClearMentions,
  });

  final ChatMessage? replyTarget;
  final List<GroupMember> mentions;
  final VoidCallback onClearReply;
  final VoidCallback onClearMentions;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          if (replyTarget != null)
            InputChip(
              avatar: const Icon(Icons.reply, size: 18),
              label: Text(
                strings.format('Reply #{id}: {sender}', {
                  'id': replyTarget!.id,
                  'sender': replyTarget!.sender,
                }),
                overflow: TextOverflow.ellipsis,
              ),
              onDeleted: onClearReply,
            ),
          if (mentions.isNotEmpty)
            InputChip(
              avatar: const Icon(Icons.alternate_email, size: 18),
              label: Text(
                mentions.length == 1
                    ? '@${mentions.first.name}'
                    : strings.format('@ {count} members', {
                        'count': mentions.length,
                      }),
              ),
              onDeleted: onClearMentions,
            ),
        ],
      ),
    );
  }
}

class _MentionPickerSheet extends StatefulWidget {
  const _MentionPickerSheet({
    required this.members,
    required this.selectedUids,
  });

  final List<GroupMember> members;
  final Set<int> selectedUids;

  @override
  State<_MentionPickerSheet> createState() => _MentionPickerSheetState();
}

class _MentionPickerSheetState extends State<_MentionPickerSheet> {
  late final Set<int> selected = Set<int>.from(widget.selectedUids);

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SafeArea(
      child: SizedBox(
        height: 520,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.text('Mention members'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (selected.length == widget.members.length) {
                          selected.clear();
                        } else {
                          selected
                            ..clear()
                            ..addAll(
                              widget.members.map((member) => member.uid),
                            );
                        }
                      });
                    },
                    child: Text(strings.text('Toggle all')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.members.isEmpty
                  ? _EmptyPanel(message: strings.text('No members.'))
                  : ListView.builder(
                      itemCount: widget.members.length,
                      itemBuilder: (context, index) {
                        final member = widget.members[index];
                        final checked = selected.contains(member.uid);
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: _RoundedInkClip(
                            child: CheckboxListTile(
                              value: checked,
                              onChanged: (_) {
                                setState(() {
                                  if (checked) {
                                    selected.remove(member.uid);
                                  } else {
                                    selected.add(member.uid);
                                  }
                                });
                              },
                              secondary: _Avatar(
                                url: member.avatar,
                                fallback: Icons.person_rounded,
                              ),
                              title: Text(member.name),
                              subtitle: member.subtitle.isEmpty
                                  ? null
                                  : Text(member.subtitle),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Text(
                    strings.format('{count} selected', {
                      'count': selected.length,
                    }),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text(strings.text('Cancel')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        widget.members
                            .where((member) => selected.contains(member.uid))
                            .toList(),
                      );
                    },
                    child: Text(strings.text('Done')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EssenceMessagesScreen extends StatefulWidget {
  const EssenceMessagesScreen({
    super.key,
    required this.state,
    required this.conversation,
  });

  final CsacAppState state;
  final Conversation conversation;

  @override
  State<EssenceMessagesScreen> createState() => _EssenceMessagesScreenState();
}

class _EssenceMessagesScreenState extends State<EssenceMessagesScreen> {
  List<ChatMessage> messages = const <ChatMessage>[];
  bool loading = true;
  String? error;

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
      final loaded = await widget.state.loadEssenceMessages(
        widget.conversation.id,
      );
      if (!mounted) {
        return;
      }
      setState(() => messages = loaded.reversed.toList());
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

  Future<void> openMessage(ChatMessage message) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          state: widget.state,
          conversation: widget.conversation,
          focusMessageId: message.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.strings.text('Essence messages')),
        actions: [
          IconButton(
            tooltip: context.strings.text('Refresh'),
            onPressed: load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            if (loading) const LinearProgressIndicator(minHeight: 2),
            if (error != null) _InlineError(message: error!, onRetry: load),
            if (!loading && messages.isEmpty)
              _EmptyPanel(message: context.strings.text('No essence messages.'))
            else
              for (final message in messages)
                Card(
                  elevation: 0,
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: ListTile(
                    onTap: () => openMessage(message),
                    leading: const Icon(Icons.star_outline),
                    title: Text(
                      message.sender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      [
                        if (message.time.isNotEmpty) message.time,
                        message.body,
                      ].join(' | '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
