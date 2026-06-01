part of '../../main.dart';

enum _PendingSendStatus { sending, sent, failed }

class _PendingSend {
  const _PendingSend({
    required this.localId,
    required this.text,
    this.imageBytes,
    this.imageName = '',
    this.voiceBytes,
    this.voiceName = '',
    this.voiceDuration = 0,
    this.emoji,
    this.replyTo = 0,
    this.mentionUids = const <int>[],
    this.status = _PendingSendStatus.sending,
    this.error = '',
  });

  final int localId;
  final String text;
  final Uint8List? imageBytes;
  final String imageName;
  final Uint8List? voiceBytes;
  final String voiceName;
  final int voiceDuration;
  final EmojiSticker? emoji;
  final int replyTo;
  final List<int> mentionUids;
  final _PendingSendStatus status;
  final String error;

  bool get hasImage => imageBytes != null;
  bool get hasVoice => voiceBytes != null;
  bool get hasEmoji => emoji != null;

  _PendingSend copyWith({
    String? text,
    Uint8List? imageBytes,
    String? imageName,
    Uint8List? voiceBytes,
    String? voiceName,
    int? voiceDuration,
    EmojiSticker? emoji,
    int? replyTo,
    List<int>? mentionUids,
    _PendingSendStatus? status,
    String? error,
  }) {
    return _PendingSend(
      localId: localId,
      text: text ?? this.text,
      imageBytes: imageBytes ?? this.imageBytes,
      imageName: imageName ?? this.imageName,
      voiceBytes: voiceBytes ?? this.voiceBytes,
      voiceName: voiceName ?? this.voiceName,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      emoji: emoji ?? this.emoji,
      replyTo: replyTo ?? this.replyTo,
      mentionUids: mentionUids ?? this.mentionUids,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}

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

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final input = TextEditingController();
  final inputFocus = FocusNode();
  final scroll = _desktopSmoothScrollController();
  final imagePicker = ImagePicker();
  final voicePlayer = AudioPlayer();
  final itemKeys = <int, GlobalKey>{};
  final messages = <ChatMessage>[];
  final pendingSends = <_PendingSend>[];
  final mentionTargets = <GroupMember>[];
  final selectedMessageIds = <int>{};
  final memberAvatars = <int, String>{};
  Timer? timer;
  Timer? draftTimer;
  StreamSubscription<PlayerState>? voicePlayerStateSub;
  StreamSubscription<Duration?>? voiceDurationSub;
  StreamSubscription<Duration>? voicePositionSub;
  StreamSubscription<PlaybackEvent>? voicePlaybackEventSub;
  GroupProfile? groupProfile;
  ChatMessage? replyTarget;
  int? playingVoiceMessageId;
  final voiceCachePaths = <int, String>{};
  PlayerState voicePlayerState = PlayerState(false, ProcessingState.idle);
  Duration voiceDuration = Duration.zero;
  Duration voicePosition = Duration.zero;
  double voiceSpeed = 1;
  int initialUnreadCount = 0;
  int nextPendingId = -1;
  int refreshTicks = 0;
  bool loading = true;
  bool refreshing = false;
  bool pickingImage = false;
  bool pickingVoice = false;
  bool recordingVoice = false;
  bool applyingDraft = false;
  bool mentionPickerOpening = false;
  bool emojiPickerOpening = false;
  bool offline = false;
  bool nearBottom = true;
  bool loadingOlder = false;
  bool hasMoreOlderMessages = true;
  bool olderPaginationReady = false;
  bool showChatHint = false;
  bool loadingMemberAvatars = false;
  bool keyboardShouldKeepBottom = false;
  bool composeMenuOpen = false;
  double keyboardInsetBottom = 0;
  int? pressedMessageId;
  String? error;

  bool get selectionMode => selectedMessageIds.isNotEmpty;

  bool get canSendText => input.text.trim().isNotEmpty;

  void setExporting(bool value) {
    setState(() => refreshing = value);
  }

  List<ChatMessage> get selectedMessages {
    return messages
        .where((message) => selectedMessageIds.contains(message.id))
        .toList();
  }

  int? get firstUnreadMessageId {
    if (initialUnreadCount <= 0 || messages.isEmpty) {
      return null;
    }
    final index = (messages.length - initialUnreadCount).clamp(
      0,
      messages.length - 1,
    );
    return messages[index].id;
  }

  int? get firstUnreadMessageIndex {
    if (initialUnreadCount <= 0 || messages.isEmpty) {
      return null;
    }
    return (messages.length - initialUnreadCount).clamp(0, messages.length - 1);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    keyboardInsetBottom = currentKeyboardInsetBottom();
    widget.state.addListener(handleAppStateChanged);
    widget.state.setActiveConversation(widget.conversation);
    initialUnreadCount = widget.conversation.unreadCount;
    widget.state.markConversationRead(widget.conversation);
    input.addListener(scheduleDraftSave);
    input.addListener(handleMentionTrigger);
    input.addListener(handleEmojiTrigger);
    input.addListener(handleInputChanged);
    scroll.addListener(handleScroll);
    bindVoicePlayer();
    loadDraft();
    loadGroupAnnouncement();
    loadInitial();
    unawaited(loadChatHint());
    timer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => refresh(silent: true),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    draftTimer?.cancel();
    unawaited(saveDraftNow());
    if (widget.state.isActiveConversation(widget.conversation)) {
      widget.state.setActiveConversation(null);
    }
    widget.state.removeListener(handleAppStateChanged);
    scroll.removeListener(handleScroll);
    input.removeListener(scheduleDraftSave);
    input.removeListener(handleMentionTrigger);
    input.removeListener(handleEmojiTrigger);
    input.removeListener(handleInputChanged);
    input.dispose();
    inputFocus.dispose();
    scroll.dispose();
    voicePlayerStateSub?.cancel();
    voiceDurationSub?.cancel();
    voicePositionSub?.cancel();
    voicePlaybackEventSub?.cancel();
    unawaited(voicePlayer.dispose());
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final nextInset = currentKeyboardInsetBottom();
    final keyboardOpening = keyboardInsetBottom <= 0 && nextInset > 0;
    final keyboardGrowing = nextInset > keyboardInsetBottom && nextInset > 0;
    if (keyboardOpening) {
      keyboardShouldKeepBottom =
          inputFocus.hasFocus && nearBottom && widget.focusMessageId == null;
    }
    if (nextInset <= 0) {
      keyboardShouldKeepBottom = false;
    } else if ((keyboardOpening || keyboardGrowing) &&
        keyboardShouldKeepBottom) {
      scrollToEndAfterKeyboardResize();
    }
    keyboardInsetBottom = nextInset;
  }

  void handleAppStateChanged() {
    if (!mounted) {
      return;
    }
    if (widget.state.preferences.showChatAvatars &&
        widget.conversation.type == ConversationType.group &&
        memberAvatars.isEmpty) {
      unawaited(loadMemberAvatars());
    }
    setState(() {});
  }

  Future<void> loadChatHint() async {
    final seen = await ChatHintStore.isSeen();
    if (seen) {
      return;
    }
    await Future<void>.delayed(650.ms);
    if (!mounted) {
      return;
    }
    setState(() => showChatHint = true);
  }

  Future<void> dismissChatHint() async {
    setState(() => showChatHint = false);
    await ChatHintStore.markSeen();
  }

  void bindVoicePlayer() {
    voicePlayerStateSub = voicePlayer.playerStateStream.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() {
        voicePlayerState = state;
        if (state.processingState == ProcessingState.completed) {
          playingVoiceMessageId = null;
          voicePosition = Duration.zero;
        }
      });
    });
    voiceDurationSub = voicePlayer.durationStream.listen((duration) {
      if (!mounted) {
        return;
      }
      setState(() => voiceDuration = duration ?? Duration.zero);
    });
    voicePositionSub = voicePlayer.positionStream.listen((position) {
      if (!mounted) {
        return;
      }
      setState(() => voicePosition = position);
    });
    voicePlaybackEventSub = voicePlayer.playbackEventStream.listen(
      (_) {},
      onError: (Object err, StackTrace stackTrace) {
        if (!mounted) {
          return;
        }
        setState(() {
          playingVoiceMessageId = null;
          voicePlayerState = PlayerState(false, ProcessingState.idle);
          voicePosition = Duration.zero;
          error = context.strings.format('Voice playback failed: {error}', {
            'error': err,
          });
        });
      },
    );
  }

  void handleScroll() {
    if (!scroll.hasClients) {
      return;
    }
    final distance = scroll.position.maxScrollExtent - scroll.offset;
    final next = distance < 96;
    if (next != nearBottom && mounted) {
      setState(() => nearBottom = next);
    }
    if (olderPaginationReady && scroll.offset < 96) {
      unawaited(loadOlderMessages());
    }
  }

  Future<void> loadDraft() async {
    final draft = await ConversationDraftStore.load(widget.conversation);
    if (!mounted || input.text.isNotEmpty) {
      return;
    }
    applyingDraft = true;
    input
      ..text = draft.text
      ..selection = TextSelection.collapsed(offset: draft.text.length);
    applyingDraft = false;
    if (draft.hasReply) {
      final cachedReply = messages.where((item) {
        return item.id == draft.replyMessageId;
      }).firstOrNull;
      setState(() {
        replyTarget =
            cachedReply ??
            ChatMessage(
              id: draft.replyMessageId,
              senderId: 0,
              sender: draft.replySender,
              body: draft.replyBody,
            );
      });
    }
  }

  void scheduleDraftSave() {
    if (applyingDraft) {
      return;
    }
    draftTimer?.cancel();
    draftTimer = Timer(const Duration(milliseconds: 450), () {
      unawaited(saveDraftNow());
    });
  }

  Future<void> saveDraftNow() {
    return ConversationDraftStore.save(
      widget.conversation,
      input.text,
      replyTarget: replyTarget,
    );
  }

  void handleInputChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void handleMentionTrigger() {
    if (widget.conversation.type != ConversationType.group ||
        mentionPickerOpening ||
        applyingDraft) {
      return;
    }
    final selection = input.selection;
    if (!selection.isValid || !selection.isCollapsed || selection.start <= 0) {
      return;
    }
    final text = input.text;
    final cursor = selection.start;
    if (cursor > text.length || text[cursor - 1] != '@') {
      return;
    }
    final beforeAt = cursor == 1 ? ' ' : text[cursor - 2];
    if (beforeAt.trim().isNotEmpty) {
      return;
    }
    mentionPickerOpening = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await chooseMentionTargets();
      } finally {
        mentionPickerOpening = false;
      }
    });
  }

  void handleEmojiTrigger() {
    if (emojiPickerOpening || applyingDraft) {
      return;
    }
    final selection = input.selection;
    if (!selection.isValid || !selection.isCollapsed || selection.start <= 0) {
      return;
    }
    final text = input.text;
    final cursor = selection.start;
    if (cursor > text.length || text[cursor - 1] != '#') {
      return;
    }
    final beforeHash = cursor == 1 ? ' ' : text[cursor - 2];
    if (beforeHash.trim().isNotEmpty) {
      return;
    }
    emojiPickerOpening = true;
    final triggerIndex = cursor - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await openEmojiStickerPicker(triggerIndex: triggerIndex);
      } finally {
        emojiPickerOpening = false;
      }
    });
  }

  Future<void> clearDraft() async {
    draftTimer?.cancel();
    await ConversationDraftStore.clear(widget.conversation);
  }

  Future<void> loadGroupAnnouncement() async {
    if (widget.conversation.type != ConversationType.group) {
      return;
    }
    try {
      final loaded = await widget.state.loadGroupProfile(
        widget.conversation.id,
      );
      if (!mounted) {
        return;
      }
      setState(() => groupProfile = loaded);
    } catch (_) {
      // The chat should remain usable even when the detail request fails.
    }
  }

  Future<void> loadMemberAvatars() async {
    if (widget.conversation.type != ConversationType.group ||
        !widget.state.preferences.showChatAvatars ||
        loadingMemberAvatars) {
      return;
    }
    loadingMemberAvatars = true;
    try {
      final members = await widget.state.loadGroupMembers(
        widget.conversation.id,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        memberAvatars
          ..clear()
          ..addEntries(
            members
                .where((member) => member.avatar.trim().isNotEmpty)
                .map((member) => MapEntry(member.uid, member.avatar)),
          );
      });
    } catch (_) {
      // Avatars are decorative; message loading should not depend on them.
    } finally {
      loadingMemberAvatars = false;
    }
  }

  String avatarForMessage(ChatMessage message, bool mine) {
    if (mine) {
      return widget.state.user?.avatar ?? '';
    }
    if (message.senderAvatar.trim().isNotEmpty) {
      return message.senderAvatar;
    }
    final memberAvatar = memberAvatars[message.senderId];
    if (memberAvatar != null && memberAvatar.trim().isNotEmpty) {
      return memberAvatar;
    }
    if (widget.conversation.type == ConversationType.private) {
      return widget.conversation.avatar;
    }
    return '';
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
      olderPaginationReady = false;
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
      unawaited(loadMemberAvatars());
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
        hasMoreOlderMessages = messages.length >= 80;
      });
      await markCurrentConversationRead();
      scrollAfterLoad();
      unawaited(loadMemberAvatars());
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
        olderPaginationReady = false;
      });
    }
    try {
      final loaded = await widget.state.reloadMessagesFromNetwork(
        widget.conversation,
      );
      if (!mounted) {
        return;
      }
      final currentMessages = List<ChatMessage>.of(messages);
      final hadMessages = currentMessages.isNotEmpty;
      final merged = await mergeMessagesWithCacheFallback(
        currentMessages,
        loaded,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        messages
          ..clear()
          ..addAll(merged);
        offline = false;
      });
      await markCurrentConversationRead();
      if (!hadMessages || loaded.isNotEmpty || widget.focusMessageId != null) {
        scrollAfterLoad();
      }
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
      final shouldFullReload =
          silent &&
          (refreshTicks % 8 == 0 ||
              (widget.conversation.type == ConversationType.private &&
                  messages.any((message) {
                    return message.senderId == widget.state.user?.uid &&
                        !message.isRead;
                  })));
      if (shouldFullReload) {
        final loaded = await widget.state.reloadMessagesFromNetwork(
          widget.conversation,
        );
        if (!mounted) {
          return;
        }
        final merged = await mergeMessagesWithCacheFallback(
          List<ChatMessage>.of(messages),
          loaded,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          messages
            ..clear()
            ..addAll(merged);
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
        if (messages.isEmpty) {
          final cached = await mergeMessagesWithCacheFallback(
            const <ChatMessage>[],
            loaded,
          );
          if (!mounted) {
            return;
          }
          if (cached.isNotEmpty) {
            setState(() {
              messages
                ..clear()
                ..addAll(cached);
              offline = false;
            });
            await markCurrentConversationRead();
            return;
          }
        }
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

  Future<List<ChatMessage>> mergeMessagesWithCacheFallback(
    List<ChatMessage> currentMessages,
    List<ChatMessage> loaded,
  ) async {
    final merged = mergeChatMessages(currentMessages, loaded);
    if (merged.isNotEmpty || currentMessages.isNotEmpty || loaded.isNotEmpty) {
      return merged;
    }
    final focusId = widget.focusMessageId;
    if (focusId != null) {
      final focused = await widget.state.loadCachedMessagesAround(
        widget.conversation,
        focusId,
      );
      if (focused.isNotEmpty) {
        return focused;
      }
    }
    return widget.state.loadCachedMessages(widget.conversation);
  }

  Future<void> loadOlderMessages() async {
    if (!mounted ||
        loading ||
        loadingOlder ||
        !hasMoreOlderMessages ||
        messages.isEmpty ||
        pendingSends.isNotEmpty) {
      return;
    }
    final beforeId = messages.first.id;
    final previousExtent = scroll.hasClients
        ? scroll.position.maxScrollExtent
        : 0;
    final previousOffset = scroll.hasClients ? scroll.offset : 0;
    setState(() => loadingOlder = true);
    try {
      final older = await widget.state.loadOlderMessages(
        widget.conversation,
        beforeId: beforeId,
      );
      if (!mounted) {
        return;
      }
      final merged = mergeChatMessages(older, messages);
      final addedOlderMessages =
          merged.isNotEmpty && merged.first.id < beforeId;
      setState(() {
        messages
          ..clear()
          ..addAll(merged);
        hasMoreOlderMessages = older.length >= 80 && addedOlderMessages;
        offline = false;
      });
      if (addedOlderMessages) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!scroll.hasClients) {
            return;
          }
          final extentDelta = scroll.position.maxScrollExtent - previousExtent;
          final target = (previousOffset + extentDelta).clamp(
            0.0,
            scroll.position.maxScrollExtent,
          );
          scroll.jumpTo(target);
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          error = context.strings.format('Offline cache: {error}', {
            'error': err,
          });
          offline = messages.isNotEmpty;
        });
      }
    } finally {
      if (mounted) {
        setState(() => loadingOlder = false);
      }
    }
  }

  Future<void> send() async {
    final text = input.text.trim();
    if (text.isEmpty) {
      return;
    }
    final pending = _PendingSend(
      localId: nextPendingId--,
      text: text,
      replyTo: replyTarget?.id ?? 0,
      mentionUids: mentionTargets.map((member) => member.uid).toList(),
    );
    setState(() {
      pendingSends.add(pending);
      input.clear();
      replyTarget = null;
      mentionTargets.clear();
      error = null;
    });
    await clearDraft();
    scrollToEnd();
    unawaited(performPendingSend(pending.localId));
  }

  Future<void> pickAndSendImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    if (pickingImage) {
      return;
    }
    setState(() => pickingImage = true);
    try {
      final picked = await imagePicker.pickImage(
        source: source,
        imageQuality: 92,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (!mounted || picked == null) {
        return;
      }
      final bytes = await picked.readAsBytes();
      if (!mounted) {
        return;
      }
      final fileName = pickedImageFileName(picked, source);
      final prepared = await Navigator.of(context).push<_PreparedImage>(
        CsacPageRoute<_PreparedImage>(
          builder: (_) =>
              _ImageSendPreviewScreen(fileName: fileName, bytes: bytes),
        ),
      );
      if (prepared == null) {
        return;
      }
      final pending = _PendingSend(
        localId: nextPendingId--,
        text: prepared.caption.trim(),
        imageBytes: prepared.bytes,
        imageName: prepared.fileName,
        replyTo: replyTarget?.id ?? 0,
        mentionUids: mentionTargets.map((member) => member.uid).toList(),
      );
      setState(() {
        pendingSends.add(pending);
        replyTarget = null;
        mentionTargets.clear();
        error = null;
      });
      unawaited(saveDraftNow());
      scrollToEnd();
      unawaited(performPendingSend(pending.localId));
    } catch (err) {
      if (mounted) {
        setState(
          () => error = context.strings.format(
            'Image selection failed: {error}',
            {'error': err},
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => pickingImage = false);
      }
    }
  }

  Future<void> openEmojiStickerPicker({int? triggerIndex}) async {
    try {
      final stickers = await widget.state.loadEmojiStickers();
      if (!mounted) {
        return;
      }
      final recentStickers = await EmojiRecentStore.load();
      if (!mounted) {
        return;
      }
      final selected = await showModalBottomSheet<EmojiSticker>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (context) => _EmojiStickerPicker(
          stickers: stickers,
          recentStickers: recentStickers,
        ),
      );
      if (!mounted || selected == null) {
        return;
      }
      removeEmojiTrigger(triggerIndex);
      await sendEmojiSticker(selected);
    } catch (err) {
      if (!mounted) {
        return;
      }
      setState(
        () => error = context.strings.format(
          'Load emoji stickers failed: {error}',
          {'error': err},
        ),
      );
    }
  }

  void removeEmojiTrigger(int? triggerIndex) {
    if (triggerIndex == null || triggerIndex < 0) {
      return;
    }
    final text = input.text;
    if (triggerIndex >= text.length || text[triggerIndex] != '#') {
      return;
    }
    final selection = input.selection;
    final nextText = text.replaceRange(triggerIndex, triggerIndex + 1, '');
    final baseOffset = selection.isValid ? selection.baseOffset : triggerIndex;
    final extentOffset = selection.isValid
        ? selection.extentOffset
        : triggerIndex;
    final nextBase = math.max(
      0,
      baseOffset - (baseOffset > triggerIndex ? 1 : 0),
    );
    final nextExtent = math.max(
      0,
      extentOffset - (extentOffset > triggerIndex ? 1 : 0),
    );
    input.value = input.value.copyWith(
      text: nextText,
      selection: TextSelection(
        baseOffset: nextBase.clamp(0, nextText.length),
        extentOffset: nextExtent.clamp(0, nextText.length),
      ),
      composing: TextRange.empty,
    );
    unawaited(saveDraftNow());
  }

  Future<void> sendEmojiSticker(EmojiSticker sticker) async {
    final pending = _PendingSend(
      localId: nextPendingId--,
      text: '',
      emoji: sticker,
      replyTo: replyTarget?.id ?? 0,
      mentionUids: mentionTargets.map((member) => member.uid).toList(),
    );
    setState(() {
      pendingSends.add(pending);
      replyTarget = null;
      mentionTargets.clear();
      error = null;
    });
    await EmojiRecentStore.record(sticker);
    await clearDraft();
    scrollToEnd();
    unawaited(performPendingSend(pending.localId));
  }

  Future<void> pickAndSendVoice() async {
    if (pickingVoice) {
      return;
    }
    setState(() => pickingVoice = true);
    try {
      final picked = await openFile(
        acceptedTypeGroups: <XTypeGroup>[
          XTypeGroup(
            label: context.strings.text('Audio files'),
            extensions: const <String>[
              'mp3',
              'm4a',
              'aac',
              'wav',
              'ogg',
              'webm',
              'amr',
            ],
          ),
        ],
      );
      if (!mounted || picked == null) {
        return;
      }
      final bytes = await picked.readAsBytes();
      if (!mounted) {
        return;
      }
      final duration = await askVoiceDuration(picked.name);
      if (duration == null || !mounted) {
        return;
      }
      final pending = _PendingSend(
        localId: nextPendingId--,
        text: '',
        voiceBytes: bytes,
        voiceName: picked.name,
        voiceDuration: duration,
        replyTo: replyTarget?.id ?? 0,
      );
      setState(() {
        pendingSends.add(pending);
        replyTarget = null;
        mentionTargets.clear();
        error = null;
      });
      unawaited(saveDraftNow());
      scrollToEnd();
      unawaited(performPendingSend(pending.localId));
    } finally {
      if (mounted) {
        setState(() => pickingVoice = false);
      }
    }
  }

  Future<void> recordAndSendVoice() async {
    if (!supportsVoiceRecording) {
      setState(
        () => error = context.strings.text(
          'Voice recording is not supported on this platform.',
        ),
      );
      return;
    }
    if (recordingVoice) {
      return;
    }
    setState(() => recordingVoice = true);
    try {
      final recorded = await showDialog<_RecordedVoice>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const _VoiceRecorderDialog(),
      );
      if (!mounted || recorded == null) {
        return;
      }
      final bytes = await readLocalFileBytes(recorded.path);
      if (bytes == null) {
        if (mounted) {
          setState(
            () => error = context.strings.text('Recording file missing.'),
          );
        }
        return;
      }
      final pending = _PendingSend(
        localId: nextPendingId--,
        text: '',
        voiceBytes: bytes,
        voiceName: basenameOfPath(recorded.path),
        voiceDuration: recorded.durationSeconds,
        replyTo: replyTarget?.id ?? 0,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        pendingSends.add(pending);
        replyTarget = null;
        mentionTargets.clear();
        error = null;
      });
      unawaited(saveDraftNow());
      scrollToEnd();
      unawaited(performPendingSend(pending.localId));
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => recordingVoice = false);
      }
    }
  }

  Future<int?> askVoiceDuration(String fileName) async {
    final controller = TextEditingController(text: '0');
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.strings.format('Send voice: {fileName}', {
            'fileName': fileName,
          }),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: context.strings.text('Duration seconds'),
            helperText: context.strings.text('Use 0 if unknown.'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(math.max(0, int.tryParse(controller.text.trim()) ?? 0)),
            child: Text(context.strings.text('Send')),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> performPendingSend(int localId) async {
    final pending = pendingSends
        .where((item) => item.localId == localId)
        .firstOrNull;
    if (pending == null) {
      return;
    }
    replacePendingSend(
      localId,
      (item) => item.copyWith(status: _PendingSendStatus.sending, error: ''),
    );
    try {
      if (pending.hasImage) {
        await widget.state.client.sendImageMessage(
          widget.conversation,
          pending.imageBytes!,
          pending.imageName,
          caption: pending.text,
          replyTo: pending.replyTo,
          mentionUids: pending.mentionUids,
        );
      } else if (pending.hasVoice) {
        await widget.state.client.sendVoiceMessage(
          widget.conversation,
          pending.voiceBytes!,
          pending.voiceName,
          duration: pending.voiceDuration,
          replyTo: pending.replyTo,
        );
      } else if (pending.hasEmoji) {
        await widget.state.sendEmojiMessage(
          widget.conversation,
          pending.emoji!,
        );
      } else {
        await widget.state.client.sendMessage(
          widget.conversation,
          pending.text,
          replyTo: pending.replyTo,
          mentionUids: pending.mentionUids,
        );
      }
      if (!mounted) {
        return;
      }
      replacePendingSend(
        localId,
        (item) => item.copyWith(status: _PendingSendStatus.sent, error: ''),
      );
      await Future<void>.delayed(260.ms);
      if (!mounted) {
        return;
      }
      setState(
        () => pendingSends.removeWhere((item) => item.localId == localId),
      );
      await widget.state.markConversationRead(widget.conversation);
      await refresh(silent: true);
      scrollToEnd();
    } catch (err) {
      replacePendingSend(
        localId,
        (item) => item.copyWith(
          status: _PendingSendStatus.failed,
          error: err.toString(),
        ),
      );
    }
  }

  Future<void> sendPat(ChatMessage message) async {
    if (widget.conversation.type != ConversationType.group ||
        !widget.state.preferences.enablePat ||
        message.senderId <= 0 ||
        message.senderId == widget.state.user?.uid) {
      return;
    }
    HapticFeedback.mediumImpact();
    try {
      await widget.state.client.sendPatMessage(
        widget.conversation,
        message.senderId,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.format('You patted {name}', {
              'name': message.sender,
            }),
          ),
        ),
      );
      await refresh(silent: true);
      scrollToEnd();
    } catch (err) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.format('Pat failed: {error}', {'error': err}),
          ),
        ),
      );
    }
  }

  void replacePendingSend(
    int localId,
    _PendingSend Function(_PendingSend item) update,
  ) {
    if (!mounted) {
      return;
    }
    final index = pendingSends.indexWhere((item) => item.localId == localId);
    if (index < 0) {
      return;
    }
    setState(() => pendingSends[index] = update(pendingSends[index]));
  }

  void retryPendingSend(int localId) {
    unawaited(performPendingSend(localId));
  }

  void clearComposeTargets() {
    if (!mounted) {
      return;
    }
    setState(() {
      replyTarget = null;
      mentionTargets.clear();
    });
    unawaited(saveDraftNow());
  }

  void setReplyTarget(ChatMessage message) {
    setState(() => replyTarget = message);
    unawaited(saveDraftNow());
    inputFocus.requestFocus();
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
      replaceMentionTriggerWithSelection(selected);
      inputFocus.requestFocus();
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    }
  }

  void replaceMentionTriggerWithSelection(List<GroupMember> selected) {
    if (selected.isEmpty) {
      return;
    }
    final selection = input.selection;
    if (!selection.isValid || selection.start <= 0) {
      return;
    }
    final cursor = selection.start;
    final text = input.text;
    if (cursor > text.length || text[cursor - 1] != '@') {
      return;
    }
    final names = selected.map((member) => '@${member.name}').join(' ');
    final replacement = '$names ';
    final nextText = text.replaceRange(cursor - 1, cursor, replacement);
    final nextOffset = cursor - 1 + replacement.length;
    input.value = input.value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
      composing: TextRange.empty,
    );
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
    final recalledBody = context.strings.format('{name} recalled a message', {
      'name': message.sender.trim().isEmpty
          ? context.strings.text('Someone')
          : message.sender.trim(),
    });
    try {
      await widget.state.recallMessage(widget.conversation, message.id);
      final recalled = message.copyWith(
        body: recalledBody,
        imageUrl: '',
        emojiAddress: '',
        emojiAbbr: '',
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
      CsacPageRoute<void>(
        builder: (_) => EssenceMessagesScreen(
          state: widget.state,
          conversation: widget.conversation,
        ),
      ),
    );
  }

  Future<void> showMessageActions(ChatMessage message, bool mine) async {
    HapticFeedback.mediumImpact();
    setState(() => pressedMessageId = message.id);
    final action =
        await showModalBottomSheet<_MessageAction>(
          context: context,
          showDragHandle: true,
          backgroundColor: Theme.of(context).colorScheme.surface,
          builder: (context) => _SpringSheet(
            child: _MessageActionSheet(
              message: message,
              canRecall: message.canRecall || mine,
              canEssence: widget.conversation.type == ConversationType.group,
            ),
          ),
        ).whenComplete(() {
          if (mounted && pressedMessageId == message.id) {
            setState(() => pressedMessageId = null);
          }
        });
    if (action == null || !mounted) {
      return;
    }
    switch (action) {
      case _MessageAction.select:
        enterSelection(message);
        break;
      case _MessageAction.copyText:
        final time = displayMessageTime(message, widget.state.preferences);
        Clipboard.setData(
          ClipboardData(
            text:
                '#${message.id} ${message.sender}\n$time\n\n${chatMessagePlainText(message, context.strings)}',
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

  void openConversationDetails() {
    if (widget.conversation.type == ConversationType.private) {
      openUserProfile(
        context,
        widget.state,
        widget.conversation.id,
        avatarHeroTag: conversationAvatarHeroTag(widget.conversation),
      );
      return;
    }
    Navigator.of(context)
        .push(
          CsacPageRoute<void>(
            builder: (_) => ConversationDetailScreen(
              state: widget.state,
              conversation: widget.conversation,
            ),
          ),
        )
        .then((_) => loadGroupAnnouncement());
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

  List<_ComposeMenuAction> composeMenuActions(CsacStrings strings) {
    return [
      _ComposeMenuAction(
        value: 'image',
        icon: Icons.image_outlined,
        label: strings.text('Image'),
      ),
      _ComposeMenuAction(
        value: 'camera',
        icon: Icons.photo_camera_outlined,
        label: strings.text('Take photo'),
      ),
      _ComposeMenuAction(
        value: 'emoji',
        icon: Icons.emoji_emotions_outlined,
        label: strings.text('Emoji stickers'),
      ),
      if (supportsVoiceRecording)
        _ComposeMenuAction(
          value: 'recordVoice',
          icon: Icons.mic,
          label: strings.text('Record voice'),
        ),
      _ComposeMenuAction(
        value: 'voiceFile',
        icon: Icons.audio_file_outlined,
        label: strings.text('Voice file'),
      ),
      if (widget.conversation.type == ConversationType.group)
        _ComposeMenuAction(
          value: 'mention',
          icon: Icons.alternate_email,
          label: strings.text('Mention'),
        ),
      if (widget.conversation.type == ConversationType.group)
        _ComposeMenuAction(
          value: 'essence',
          icon: Icons.star_outline,
          label: strings.text('Essence'),
        ),
      _ComposeMenuAction(
        value: 'media',
        icon: Icons.perm_media_outlined,
        label: strings.text('Media'),
      ),
      if (supportsLocalFiles)
        _ComposeMenuAction(
          value: 'export',
          icon: Icons.ios_share_outlined,
          label: strings.text('Export'),
        ),
    ];
  }

  void toggleComposeMenu() {
    setState(() => composeMenuOpen = !composeMenuOpen);
    if (composeMenuOpen) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  Future<void> handleComposeMenuAction(String action) async {
    if (composeMenuOpen && mounted) {
      setState(() => composeMenuOpen = false);
    }
    switch (action) {
      case 'image':
        await pickAndSendImage();
        break;
      case 'camera':
        await pickAndSendImage(source: ImageSource.camera);
        break;
      case 'emoji':
        await openEmojiStickerPicker();
        break;
      case 'recordVoice':
        await recordAndSendVoice();
        break;
      case 'voiceFile':
        await pickAndSendVoice();
        break;
      case 'mention':
        await chooseMentionTargets();
        break;
      case 'essence':
        await openEssenceList();
        break;
      case 'media':
        await openMediaCenter();
        break;
      case 'export':
        await exportConversation();
        break;
    }
  }

  Future<void> handleAppBarMenuAction(String action) async {
    switch (action) {
      case 'refresh':
        await reloadConversationFromNetwork(showLoading: true);
        break;
      case 'essence':
        await openEssenceList();
        break;
      case 'media':
        await openMediaCenter();
        break;
      case 'export':
        await exportConversation();
        break;
    }
  }

  Future<void> showChatMoreActions() async {
    final strings = context.strings;
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('refresh'),
            child: Text(strings.text('Refresh')),
          ),
          if (widget.conversation.type == ConversationType.group)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('essence'),
              child: Text(strings.text('Essence')),
            ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop('media'),
            child: Text(strings.text('Media and files')),
          ),
          if (supportsLocalFiles)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(context).pop('export'),
              child: Text(strings.text('Export chat history')),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.text('Cancel')),
        ),
      ),
    );
    if (action != null && mounted) {
      await handleAppBarMenuAction(action);
    }
  }

  void enterSelection(ChatMessage message) {
    setState(() {
      selectedMessageIds
        ..clear()
        ..add(message.id);
    });
  }

  void toggleMessageSelection(ChatMessage message) {
    setState(() {
      if (selectedMessageIds.contains(message.id)) {
        selectedMessageIds.remove(message.id);
      } else {
        selectedMessageIds.add(message.id);
      }
    });
  }

  void clearSelection() {
    setState(() => selectedMessageIds.clear());
  }

  Future<void> copySelectedMessages() async {
    final selected = selectedMessages..sort((a, b) => a.id.compareTo(b.id));
    if (selected.isEmpty) {
      return;
    }
    await Clipboard.setData(
      ClipboardData(text: selected.map(formatMessageForCopy).join('\n\n')),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.strings.text('Selected messages copied.')),
      ),
    );
  }

  Future<void> deleteSelectedLocalMessages() async {
    final selected = selectedMessages;
    if (selected.isEmpty) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.strings.text('Delete selected local messages?')),
        content: Text(
          context.strings.text('Only local cached copies will be removed.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.strings.text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.strings.text('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final ids = selected.map((message) => message.id).toSet();
    try {
      await widget.state.cache.deleteMessages(widget.conversation, ids);
      if (!mounted) {
        return;
      }
      setState(() {
        messages.removeWhere((message) => ids.contains(message.id));
        selectedMessageIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.strings.text('Local messages deleted.')),
        ),
      );
    } catch (err) {
      if (!mounted) {
        return;
      }
      setState(() => error = err.toString());
    }
  }

  Future<void> forwardSelectedMessages() async {
    final selected = selectedMessages..sort((a, b) => a.id.compareTo(b.id));
    if (selected.isEmpty) {
      return;
    }
    final target = await showModalBottomSheet<Conversation>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ForwardConversationSheet(
        conversations: widget.state.conversations
            .where(
              (conversation) =>
                  conversation.type != widget.conversation.type ||
                  conversation.id != widget.conversation.id,
            )
            .toList(),
      ),
    );
    if (target == null || !mounted) {
      return;
    }
    try {
      final body = selected.map(formatMessageForForward).join('\n\n');
      await widget.state.client.sendMessage(target, body);
      if (!mounted) {
        return;
      }
      setState(() => selectedMessageIds.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.text('Forwarded.'))),
      );
    } catch (err) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.format('Forward failed: {error}', {'error': err}),
          ),
        ),
      );
    }
  }

  String formatMessageForCopy(ChatMessage message) {
    final time = displayMessageTime(message, widget.state.preferences);
    return [
      '#${message.id} ${message.sender}',
      if (time.isNotEmpty) time,
      if (chatMessagePlainText(message, context.strings).trim().isNotEmpty)
        chatMessagePlainText(message, context.strings).trim(),
      if (message.imageUrl.isNotEmpty) message.imageUrl,
      if (message.voiceUrl.isNotEmpty) message.voiceUrl,
      if (message.emojiAddress.isNotEmpty) message.emojiAddress,
    ].join('\n');
  }

  String formatMessageForForward(ChatMessage message) {
    return [
      '${message.sender}:',
      if (chatMessagePlainText(message, context.strings).trim().isNotEmpty)
        chatMessagePlainText(message, context.strings).trim(),
      if (message.imageUrl.isNotEmpty)
        context.strings.format('Image: {url}', {'url': message.imageUrl}),
      if (message.voiceUrl.isNotEmpty)
        context.strings.format('Voice: {url}', {'url': message.voiceUrl}),
      if (message.emojiAbbr.isNotEmpty)
        context.strings.format('Emoji: {abbr}', {'abbr': message.emojiAbbr}),
    ].join('\n');
  }

  bool isVoicePlaying(ChatMessage message) {
    return playingVoiceMessageId == message.id &&
        voicePlayerState.playing &&
        voicePlayerState.processingState != ProcessingState.completed;
  }

  Future<void> toggleVoicePlayback(ChatMessage message) async {
    if (message.voiceUrl.isEmpty) {
      return;
    }
    try {
      if (playingVoiceMessageId == message.id) {
        if (voicePlayerState.playing) {
          await voicePlayer.pause();
        } else {
          await voicePlayer.setSpeed(voiceSpeed);
          await voicePlayer.play();
        }
        return;
      }
      if (isWebPlatform) {
        await voicePlayer.setUrl(message.voiceUrl);
        setState(() {
          playingVoiceMessageId = message.id;
          voiceDuration = message.voiceDuration > 0
              ? Duration(seconds: message.voiceDuration)
              : Duration.zero;
          voicePosition = Duration.zero;
          voicePlayerState = PlayerState(true, ProcessingState.loading);
        });
        await voicePlayer.setSpeed(voiceSpeed);
        await voicePlayer.play();
        return;
      }
      await voicePlayer.stop();
      final voicePath = await cachedVoicePath(message);
      if (!mounted) {
        return;
      }
      setState(() {
        playingVoiceMessageId = message.id;
        voiceDuration = message.voiceDuration > 0
            ? Duration(seconds: message.voiceDuration)
            : Duration.zero;
        voicePosition = Duration.zero;
        voicePlayerState = PlayerState(true, ProcessingState.loading);
      });
      final loadedDuration = await voicePlayer.setFilePath(voicePath);
      await voicePlayer.setSpeed(voiceSpeed);
      if (mounted && loadedDuration != null) {
        setState(() => voiceDuration = loadedDuration);
      }
      await voicePlayer.play();
    } catch (err) {
      if (mounted) {
        setState(() {
          playingVoiceMessageId = null;
          voicePlayerState = PlayerState(false, ProcessingState.idle);
          voicePosition = Duration.zero;
          error = context.strings.format('Voice playback failed: {error}', {
            'error': err,
          });
        });
      }
    }
  }

  Future<String> cachedVoicePath(ChatMessage message) async {
    final existing = voiceCachePaths[message.id];
    if (existing != null &&
        await localFileExists(existing) &&
        !await localFileLooksLikeHtml(existing)) {
      return existing;
    }
    final uri = Uri.parse(message.voiceUrl);
    final path = await cacheVoiceBytes(
      messageId: message.id,
      sourceUrl: uri.toString(),
      loadBytes: () => widget.state.client.getBinary(
        uri.toString(),
        accept: 'audio/*, application/octet-stream, */*',
      ),
    );
    voiceCachePaths[message.id] = path;
    return path;
  }

  Future<void> seekVoice(Duration position) async {
    final duration = voiceDuration;
    if (duration <= Duration.zero) {
      return;
    }
    final clamped = position < Duration.zero
        ? Duration.zero
        : position > duration
        ? duration
        : position;
    await voicePlayer.seek(clamped);
    if (mounted) {
      setState(() => voicePosition = clamped);
    }
  }

  Future<void> cycleVoiceSpeed() async {
    const speeds = <double>[1, 1.25, 1.5, 2];
    final index = speeds.indexWhere(
      (speed) => (speed - voiceSpeed).abs() < 0.01,
    );
    final nextSpeed = speeds[(index + 1) % speeds.length];
    setState(() => voiceSpeed = nextSpeed);
    await voicePlayer.setSpeed(nextSpeed);
  }

  Duration displayVoiceDuration(ChatMessage message) {
    if (playingVoiceMessageId == message.id && voiceDuration > Duration.zero) {
      return voiceDuration;
    }
    if (message.voiceDuration > 0) {
      return Duration(seconds: message.voiceDuration);
    }
    return Duration.zero;
  }

  double currentKeyboardInsetBottom() {
    final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
    if (view == null) {
      return 0;
    }
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  void scrollToEndAfterKeyboardResize({int frame = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scroll.hasClients || !keyboardShouldKeepBottom) {
        return;
      }
      scroll.jumpTo(scroll.position.maxScrollExtent);
      if (frame < 1) {
        scrollToEndAfterKeyboardResize(frame: frame + 1);
      }
    });
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

  void jumpToEnd() {
    if (!scroll.hasClients) {
      return;
    }
    scroll.animateTo(
      scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void scrollAfterLoad() {
    final focusId = widget.focusMessageId;
    if (focusId == null) {
      scrollToEnd();
      enableOlderPaginationSoon();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusLoadedMessage(focusId);
    });
  }

  void focusLoadedMessage(int messageId, {int attempt = 0}) {
    if (!mounted || !scroll.hasClients) {
      return;
    }
    final keyContext = itemKeys[messageId]?.currentContext;
    if (keyContext != null) {
      Scrollable.ensureVisible(
        keyContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        alignment: 0.42,
      );
      enableOlderPaginationSoon();
      return;
    }
    final messageIndex = messages.indexWhere(
      (message) => message.id == messageId,
    );
    if (messageIndex < 0 || attempt >= 4) {
      enableOlderPaginationSoon();
      return;
    }
    final maxExtent = scroll.position.maxScrollExtent;
    if (maxExtent <= 0 || messages.length <= 1) {
      enableOlderPaginationSoon();
      return;
    }
    final fraction = messageIndex / (messages.length - 1);
    final target = (maxExtent * fraction).clamp(0.0, maxExtent);
    scroll.jumpTo(target);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusLoadedMessage(messageId, attempt: attempt + 1);
    });
  }

  void enableOlderPaginationSoon() {
    Future<void>.delayed(360.ms, () {
      if (mounted) {
        olderPaginationReady = true;
      }
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

  void scrollToFirstUnread() {
    final messageId = firstUnreadMessageId;
    if (messageId == null) {
      return;
    }
    scrollToMessage(messageId);
    setState(() => initialUnreadCount = 0);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final announcement = groupProfile?.notice.trim() ?? '';
    final showEmpty = !loading && messages.isEmpty && pendingSends.isEmpty;
    final unreadMessageId = firstUnreadMessageId;
    final unreadDividerIndex = firstUnreadMessageIndex;
    final backgroundPath = widget.state.preferences.chatBackgroundPath.trim();
    return Scaffold(
      backgroundColor: colors.systemBackground,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded && !selectionMode,
        leading: selectionMode
            ? IconButton(
                tooltip: strings.text('Cancel selection'),
                onPressed: clearSelection,
                icon: const Icon(CupertinoIcons.xmark),
              )
            : null,
        title: selectionMode
            ? Text(
                strings.format('{count} messages selected', {
                  'count': selectedMessageIds.length,
                }),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : Row(
                children: [
                  _ConversationAvatarHero(
                    conversation: widget.conversation,
                    enabled: !widget.embedded,
                    radius: 16,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ConversationTitleHero(
                      conversation: widget.conversation,
                      enabled: !widget.embedded,
                    ),
                  ),
                ],
              ),
        actions: selectionMode
            ? [
                IconButton(
                  tooltip: strings.text('Copy selected'),
                  onPressed: copySelectedMessages,
                  icon: const Icon(CupertinoIcons.doc_on_doc),
                ),
                IconButton(
                  tooltip: strings.text('Forward'),
                  onPressed: forwardSelectedMessages,
                  icon: const Icon(CupertinoIcons.arrowshape_turn_up_right),
                ),
                IconButton(
                  tooltip: strings.text('Delete local copies'),
                  onPressed: deleteSelectedLocalMessages,
                  icon: const Icon(CupertinoIcons.trash),
                ),
              ]
            : [
                if (offline)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(CupertinoIcons.wifi_slash),
                  ),
                IconButton(
                  tooltip: strings.text('More'),
                  onPressed: showChatMoreActions,
                  icon: const Icon(CupertinoIcons.ellipsis_circle),
                ),
                IconButton(
                  tooltip: strings.text('Details'),
                  onPressed: openConversationDetails,
                  icon: const Icon(CupertinoIcons.info_circle),
                ),
              ],
      ),
      body: SafeArea(
        top: true,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            if (composeMenuOpen) {
              setState(() => composeMenuOpen = false);
            }
          },
          child: Stack(
            children: [
              Column(
                children: [
                  if (error != null)
                    _MotionPane(
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                        decoration: BoxDecoration(
                          color: colors.destructive.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colors.destructive.withValues(alpha: 0.22),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                error!,
                                style: TextStyle(
                                  color: colors.destructive,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: Size.zero,
                              onPressed: () => setState(() => error = null),
                              child: Text(
                                strings.text('Dismiss'),
                                style: TextStyle(
                                  color: colors.destructive,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (announcement.isNotEmpty)
                    _MotionPane(
                      child: _GroupAnnouncementBar(
                        announcement: announcement,
                        onTap: openConversationDetails,
                      ),
                    ),
                  if (unreadMessageId != null)
                    _MotionPane(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                        child: _CsacPressable(
                          onTap: scrollToFirstUnread,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
                            decoration: BoxDecoration(
                              color: CupertinoTheme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: CupertinoTheme.of(
                                  context,
                                ).primaryColor.withValues(alpha: 0.18),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.bubble_left_bubble_right,
                                  color: CupertinoTheme.of(
                                    context,
                                  ).primaryColor,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    strings.format(
                                      'Jump to {count} unread messages',
                                      {'count': initialUnreadCount},
                                    ),
                                    style: TextStyle(
                                      color: CupertinoTheme.of(
                                        context,
                                      ).primaryColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Icon(
                                  CupertinoIcons.chevron_down,
                                  color: CupertinoTheme.of(
                                    context,
                                  ).primaryColor,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _ChatBackground(path: backgroundPath),
                        ),
                        loading
                            ? const Center(child: CircularProgressIndicator())
                            : showEmpty
                            ? _EmptyPanel(message: strings.text('No messages.'))
                            : ListView.builder(
                                controller: scroll,
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  12,
                                  12,
                                ),
                                itemCount:
                                    messages.length +
                                    pendingSends.length +
                                    (loadingOlder ? 1 : 0) +
                                    (unreadDividerIndex == null ? 0 : 1),
                                itemBuilder: (context, index) {
                                  if (loadingOlder && index == 0) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                      child: Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  var messageIndex =
                                      index - (loadingOlder ? 1 : 0);
                                  if (unreadDividerIndex != null &&
                                      messageIndex == unreadDividerIndex) {
                                    return _MotionListItem(
                                      index: messageIndex,
                                      child: _UnreadDivider(
                                        count: initialUnreadCount,
                                      ),
                                    );
                                  }
                                  if (unreadDividerIndex != null &&
                                      messageIndex > unreadDividerIndex) {
                                    messageIndex -= 1;
                                  }
                                  if (messageIndex >= messages.length) {
                                    final pending =
                                        pendingSends[messageIndex -
                                            messages.length];
                                    return _MotionListItem(
                                      index: messageIndex,
                                      child: _PendingMessageBubble(
                                        pending: pending,
                                        onRetry: () =>
                                            retryPendingSend(pending.localId),
                                      ),
                                    );
                                  }
                                  final message = messages[messageIndex];
                                  final mine =
                                      widget.state.user?.uid ==
                                      message.senderId;
                                  if (message.messageType == 4 ||
                                      message.isRecalled) {
                                    return _MotionListItem(
                                      index: messageIndex,
                                      child: _SystemMessagePill(
                                        key: itemKeys.putIfAbsent(
                                          message.id,
                                          () => GlobalKey(),
                                        ),
                                        message: message,
                                        preferences: widget.state.preferences,
                                      ),
                                    );
                                  }
                                  final showAvatar =
                                      widget.state.preferences.showChatAvatars;
                                  final avatarUrl = showAvatar
                                      ? avatarForMessage(message, mine)
                                      : '';
                                  final selected = selectedMessageIds.contains(
                                    message.id,
                                  );
                                  final replyMessage = messages
                                      .where(
                                        (item) => item.id == message.replyTo,
                                      )
                                      .cast<ChatMessage?>()
                                      .firstOrNull;
                                  return _MotionListItem(
                                    index: messageIndex,
                                    child: _MessageBubble(
                                      key: itemKeys.putIfAbsent(
                                        message.id,
                                        () => GlobalKey(),
                                      ),
                                      message: message,
                                      replyMessage: replyMessage,
                                      mine: mine,
                                      showAvatar: showAvatar,
                                      avatarUrl: avatarUrl,
                                      showReadStatus:
                                          widget.conversation.type ==
                                              ConversationType.private &&
                                          mine,
                                      showMemberLevel:
                                          widget.conversation.type ==
                                              ConversationType.group &&
                                          widget
                                              .state
                                              .preferences
                                              .showGroupMemberLevel,
                                      focused:
                                          widget.focusMessageId == message.id,
                                      selected: selected,
                                      selectionMode: selectionMode,
                                      pressed: pressedMessageId == message.id,
                                      preferences: widget.state.preferences,
                                      onTap: selectionMode
                                          ? () =>
                                                toggleMessageSelection(message)
                                          : null,
                                      onLongPress: selectionMode
                                          ? null
                                          : () => showMessageActions(
                                              message,
                                              mine,
                                            ),
                                      onSwipeReply: selectionMode
                                          ? null
                                          : () => setReplyTarget(message),
                                      onAvatarDoubleTap:
                                          widget.conversation.type ==
                                                  ConversationType.group &&
                                              widget
                                                  .state
                                                  .preferences
                                                  .enablePat &&
                                              !mine
                                          ? () => sendPat(message)
                                          : null,
                                      onReplyTap: message.replyTo > 0
                                          ? () =>
                                                scrollToMessage(message.replyTo)
                                          : null,
                                      onImageTap: message.imageUrl.isEmpty
                                          ? null
                                          : () => showImagePreview(
                                              context,
                                              message.imageUrl,
                                              heroTag: chatImageHeroTag(
                                                message,
                                              ),
                                            ),
                                      voicePlaying: isVoicePlaying(message),
                                      voiceActive:
                                          playingVoiceMessageId == message.id,
                                      voicePosition:
                                          playingVoiceMessageId == message.id
                                          ? voicePosition
                                          : Duration.zero,
                                      voiceDuration: displayVoiceDuration(
                                        message,
                                      ),
                                      voiceSpeed: voiceSpeed,
                                      onVoiceTap: message.voiceUrl.isEmpty
                                          ? null
                                          : () => toggleVoicePlayback(message),
                                      onVoiceSeek: message.voiceUrl.isEmpty
                                          ? null
                                          : seekVoice,
                                      onVoiceSpeed: message.voiceUrl.isEmpty
                                          ? null
                                          : cycleVoiceSpeed,
                                    ),
                                  );
                                },
                              ),
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: IgnorePointer(
                            ignoring: nearBottom || loading,
                            child: AnimatedSwitcher(
                              duration: _MotionPreference.reduceOf(context)
                                  ? Duration.zero
                                  : 420.ms,
                              reverseDuration:
                                  _MotionPreference.reduceOf(context)
                                  ? Duration.zero
                                  : 320.ms,
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                final reduceMotion = _MotionPreference.reduceOf(
                                  context,
                                );
                                if (reduceMotion) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                }
                                final fade = CurvedAnimation(
                                  parent: animation,
                                  curve: const Interval(
                                    0.08,
                                    1,
                                    curve: Curves.easeOutCubic,
                                  ),
                                  reverseCurve: Curves.easeInCubic,
                                );
                                final scale = Tween<double>(begin: 0.82, end: 1)
                                    .animate(
                                      CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.easeOutBack,
                                        reverseCurve: Curves.easeInBack,
                                      ),
                                    );
                                return FadeTransition(
                                  opacity: fade,
                                  child: AnimatedBuilder(
                                    animation: animation,
                                    child: child,
                                    builder: (context, child) {
                                      final isButton =
                                          child?.key ==
                                          const ValueKey(
                                            'jump-to-bottom-button',
                                          );
                                      final collapse = 1 - animation.value;
                                      final angle = isButton
                                          ? collapse * 0.55
                                          : collapse * 1.35;
                                      return Transform.scale(
                                        scale: scale.value,
                                        child: Transform.rotate(
                                          angle: angle,
                                          child: child,
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                              child: !nearBottom && !loading
                                  ? CupertinoButton(
                                      key: const ValueKey(
                                        'jump-to-bottom-button',
                                      ),
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(38, 38),
                                      onPressed: jumpToEnd,
                                      child: ClipOval(
                                        child: BackdropFilter(
                                          filter: ui.ImageFilter.blur(
                                            sigmaX: 18,
                                            sigmaY: 18,
                                          ),
                                          child: Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: colors.cardBackground
                                                  .withValues(alpha: 0.88),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: colors.separator
                                                    .withValues(alpha: 0.24),
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Icon(
                                              CupertinoIcons.chevron_down,
                                              color: CupertinoTheme.of(
                                                context,
                                              ).primaryColor,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('jump-to-bottom-empty'),
                                    ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: IgnorePointer(
                            ignoring: !showChatHint,
                            child: AnimatedSwitcher(
                              duration: 260.ms,
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: ScaleTransition(
                                    scale: Tween<double>(
                                      begin: 0.98,
                                      end: 1,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                );
                              },
                              child: showChatHint
                                  ? _ChatHintOverlay(
                                      key: const ValueKey('chat-hint'),
                                      onDismiss: dismissChatHint,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: AnimatedContainer(
                      duration: 160.ms,
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: nearBottom
                                ? Colors.transparent
                                : Theme.of(context).colorScheme.outlineVariant,
                            width: nearBottom ? 0 : 1,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: 220.ms,
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SizeTransition(
                                    sizeFactor: animation,
                                    alignment: Alignment.topCenter,
                                    child: child,
                                  ),
                                );
                              },
                              child:
                                  replyTarget != null ||
                                      mentionTargets.isNotEmpty
                                  ? KeyedSubtree(
                                      key: ValueKey<String>(
                                        '${replyTarget?.id ?? 0}:${mentionTargets.length}',
                                      ),
                                      child: _ComposeTargetsBar(
                                        replyTarget: replyTarget,
                                        mentions: mentionTargets,
                                        onClearReply: () {
                                          setState(() => replyTarget = null);
                                          unawaited(saveDraftNow());
                                        },
                                        onClearMentions: () => setState(
                                          () => mentionTargets.clear(),
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            _MotionPane(
                              child: Row(
                                children: [
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(38, 38),
                                    onPressed: toggleComposeMenu,
                                    child: AnimatedRotation(
                                      turns: composeMenuOpen ? 0.125 : 0,
                                      duration:
                                          _MotionPreference.reduceOf(context)
                                          ? Duration.zero
                                          : 220.ms,
                                      curve: Curves.easeOutBack,
                                      child: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: colors.cardBackground,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: colors.separator.withValues(
                                              alpha: 0.26,
                                            ),
                                            width: 0.5,
                                          ),
                                        ),
                                        child: Icon(
                                          CupertinoIcons.plus,
                                          color: CupertinoTheme.of(
                                            context,
                                          ).primaryColor,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: input,
                                      focusNode: inputFocus,
                                      minLines: 1,
                                      maxLines: 4,
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) => send(),
                                      decoration: InputDecoration(
                                        hintText: strings.text('Message'),
                                        border: InputBorder.none,
                                        filled: true,
                                        fillColor: colors.cardBackground,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 46,
                                    height: 46,
                                    child: _AnimatedSendButton(
                                      active: canSendText,
                                      onPressed: send,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: !composeMenuOpen,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => setState(() => composeMenuOpen = false),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 74 + MediaQuery.paddingOf(context).bottom,
                child: IgnorePointer(
                  ignoring: !composeMenuOpen,
                  child: AnimatedSwitcher(
                    duration: _MotionPreference.reduceOf(context)
                        ? Duration.zero
                        : 260.ms,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.985,
                            end: 1,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: composeMenuOpen
                        ? _ComposeMenuPanel(
                            key: const ValueKey('compose-menu-panel'),
                            actions: composeMenuActions(strings),
                            onSelected: handleComposeMenuAction,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    this.replyMessage,
    required this.mine,
    this.showAvatar = false,
    this.avatarUrl = '',
    this.showReadStatus = false,
    this.showMemberLevel = false,
    this.focused = false,
    this.selected = false,
    this.selectionMode = false,
    this.pressed = false,
    required this.preferences,
    this.onTap,
    this.onLongPress,
    this.onSwipeReply,
    this.onAvatarDoubleTap,
    this.onReplyTap,
    this.onImageTap,
    this.voicePlaying = false,
    this.voiceActive = false,
    this.voicePosition = Duration.zero,
    this.voiceDuration = Duration.zero,
    this.voiceSpeed = 1,
    this.onVoiceTap,
    this.onVoiceSeek,
    this.onVoiceSpeed,
  });

  final ChatMessage message;
  final ChatMessage? replyMessage;
  final bool mine;
  final bool showAvatar;
  final String avatarUrl;
  final bool showReadStatus;
  final bool showMemberLevel;
  final bool focused;
  final bool selected;
  final bool selectionMode;
  final bool pressed;
  final CsacPreferences preferences;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSwipeReply;
  final VoidCallback? onAvatarDoubleTap;
  final VoidCallback? onReplyTap;
  final VoidCallback? onImageTap;
  final bool voicePlaying;
  final bool voiceActive;
  final Duration voicePosition;
  final Duration voiceDuration;
  final double voiceSpeed;
  final VoidCallback? onVoiceTap;
  final ValueChanged<Duration>? onVoiceSeek;
  final VoidCallback? onVoiceSpeed;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

String chatImageHeroTag(ChatMessage message) {
  return 'chat-image:${message.id}:${message.imageUrl}';
}

BorderRadius chatBubbleBorderRadius(ChatBubbleCornerStyle style, bool mine) {
  switch (style) {
    case ChatBubbleCornerStyle.telegram:
      return BorderRadius.only(
        topLeft: const Radius.circular(14),
        topRight: const Radius.circular(14),
        bottomLeft: Radius.circular(mine ? 14 : 4),
        bottomRight: Radius.circular(mine ? 4 : 14),
      );
    case ChatBubbleCornerStyle.ios:
      return BorderRadius.only(
        topLeft: const Radius.circular(20),
        topRight: const Radius.circular(20),
        bottomLeft: Radius.circular(mine ? 20 : 6),
        bottomRight: Radius.circular(mine ? 6 : 20),
      );
    case ChatBubbleCornerStyle.qq:
      return BorderRadius.circular(8);
  }
}

class _MessageBubbleState extends State<_MessageBubble> {
  static const double _replyTriggerDistance = 72;
  double dragOffset = 0;
  bool armed = false;

  void handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.onSwipeReply == null) {
      return;
    }
    final next = (dragOffset + details.delta.dx).clamp(-104.0, 0.0).toDouble();
    final nextArmed = next.abs() >= _replyTriggerDistance;
    if (nextArmed != armed) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      dragOffset = next;
      armed = nextArmed;
    });
  }

  void handleHorizontalDragEnd([DragEndDetails? details]) {
    if (widget.onSwipeReply != null && armed) {
      HapticFeedback.mediumImpact();
      widget.onSwipeReply!();
    }
    setState(() {
      dragOffset = 0;
      armed = false;
    });
  }

  void handleHorizontalDragCancel() {
    setState(() {
      dragOffset = 0;
      armed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final defaultColor = widget.mine
        ? colors.primaryContainer
        : colors.surfaceContainerHighest;
    final colorValue = widget.mine
        ? widget.preferences.ownChatBubbleColorValue
        : widget.preferences.otherChatBubbleColorValue;
    final baseColor = colorValue == defaultChatBubbleColorValue
        ? defaultColor
        : Color(colorValue);
    final bubbleOpacity = widget.preferences.chatBubbleOpacity
        .clamp(0.45, 1.0)
        .toDouble();
    final color = baseColor.withValues(alpha: bubbleOpacity);
    final solidTextSource = Color.alphaBlend(
      color,
      theme.scaffoldBackgroundColor,
    );
    final textColor =
        ThemeData.estimateBrightnessForColor(solidTextSource) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    final secondaryTextColor = textColor.withValues(alpha: 0.72);
    final replyColor = widget.mine
        ? colors.primary.withValues(alpha: 0.14)
        : colors.surfaceContainerHigh.withValues(alpha: bubbleOpacity);
    final borderColor = Color.alphaBlend(
      textColor.withValues(alpha: 0.08),
      color,
    );
    final borderRadius = chatBubbleBorderRadius(
      widget.preferences.chatBubbleCornerStyle,
      widget.mine,
    );
    final highlighted = widget.pressed || widget.selected || widget.focused;
    final align = widget.mine
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final strings = context.strings;
    final avatar = widget.showAvatar
        ? _ChatMessageAvatar(
            url: widget.avatarUrl,
            mine: widget.mine,
            name: widget.message.sender,
            onDoubleTap: widget.onAvatarDoubleTap,
          )
        : const SizedBox.shrink();
    final messageTime = displayMessageTime(widget.message, widget.preferences);
    final memberLevelText = widget.showMemberLevel
        ? _memberLevelText(widget.message)
        : '';
    final messageText = chatMessagePlainText(widget.message, strings);
    final hasEmoji = widget.message.emojiAddress.isNotEmpty;
    final maxBubbleWidth = chatBubbleMaxWidth(
      context,
      showAvatar: widget.showAvatar,
    );
    final imageHeroTag = widget.message.imageUrl.isEmpty
        ? null
        : chatImageHeroTag(widget.message);
    final replyProgress = (dragOffset.abs() / _replyTriggerDistance)
        .clamp(0.0, 1.0)
        .toDouble();
    final bubble = AnimatedScale(
      scale: widget.pressed ? 1.025 : 1,
      duration: widget.pressed ? 180.ms : 240.ms,
      curve: widget.pressed ? Curves.easeOutBack : Curves.easeOutCubic,
      child: Column(
        crossAxisAlignment: align,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SelectionCheckbox(
                visible: widget.selectionMode,
                selected: widget.selected,
              ),
              if (widget.selectionMode) const SizedBox(width: 6),
              if (memberLevelText.isNotEmpty) ...[
                _MemberLevelBadge(text: memberLevelText),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  widget.message.sender,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (messageTime.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    messageTime,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: 180.ms,
            curve: Curves.easeOutCubic,
            constraints: BoxConstraints(
              minWidth: widget.showReadStatus ? 76 : 0,
              maxWidth: maxBubbleWidth,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: widget.pressed
                  ? Color.alphaBlend(
                      colors.primary.withValues(alpha: 0.08),
                      color,
                    )
                  : color,
              borderRadius: borderRadius,
              border: Border.all(
                color: highlighted ? colors.primary : borderColor,
                width: highlighted ? 2 : 1,
              ),
              boxShadow: armed || widget.pressed
                  ? [
                      BoxShadow(
                        color: colors.primary.withValues(
                          alpha: widget.pressed ? 0.26 : 0.22,
                        ),
                        blurRadius: widget.pressed ? 22 : 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    bottom: widget.showReadStatus ? 18 : 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.message.replyTo > 0) ...[
                        _CsacPressable(
                          onTap: widget.onReplyTap,
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
                              widget.replyMessage == null
                                  ? strings.format('Reply #{id}', {
                                      'id': widget.message.replyTo,
                                    })
                                  : strings
                                        .format('Reply {sender}: {message}', {
                                          'sender': widget.replyMessage!.sender,
                                          'message': compactMessage(
                                            chatMessagePlainText(
                                              widget.replyMessage!,
                                              strings,
                                            ),
                                          ),
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
                      if (widget.message.isMentioned ||
                          widget.message.isEssence) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (widget.message.isMentioned)
                              _InlineStatusPill(
                                icon: CupertinoIcons.at,
                                label: strings.text('Mentioned'),
                                color: colors.primary,
                              ),
                            if (widget.message.isEssence)
                              _InlineStatusPill(
                                icon: CupertinoIcons.star_fill,
                                label: strings.text('Essence'),
                                color: CupertinoColors.systemYellow.resolveFrom(
                                  context,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (widget.message.imageUrl.isNotEmpty) ...[
                        _MessageImage(
                          url: widget.message.imageUrl,
                          heroTag: imageHeroTag,
                          onTap: widget.onImageTap,
                        ),
                        if (widget.message.body.isNotEmpty &&
                            !widget.message.body.startsWith('[image]'))
                          const SizedBox(height: 8),
                      ],
                      if (widget.message.voiceUrl.isNotEmpty) ...[
                        _VoiceMessageTile(
                          declaredDuration: widget.message.voiceDuration,
                          position: widget.voicePosition,
                          duration: widget.voiceDuration,
                          playing: widget.voicePlaying,
                          active: widget.voiceActive,
                          speed: widget.voiceSpeed,
                          textColor: textColor,
                          onTap: widget.onVoiceTap,
                          onSeek: widget.onVoiceSeek,
                          onSpeed: widget.onVoiceSpeed,
                        ),
                        if (widget.message.body.isNotEmpty &&
                            !widget.message.body.startsWith('[voice]'))
                          const SizedBox(height: 8),
                      ],
                      if (hasEmoji) ...[
                        _EmojiStickerImage(
                          url: widget.message.emojiAddress,
                          size: 118,
                          fallbackLabel: messageText,
                        ),
                      ],
                      if (messageText.isNotEmpty &&
                          !hasEmoji &&
                          !widget.message.body.startsWith('[image]') &&
                          !widget.message.body.startsWith('[voice]'))
                        Text(
                          messageText,
                          softWrap: true,
                          style: TextStyle(color: textColor),
                        ),
                    ],
                  ),
                ),
                if (widget.showReadStatus)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: _PrivateReadStatus(read: widget.message.isRead),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    final rowChildren = <Widget>[
      if (widget.showAvatar && !widget.mine) ...[
        avatar,
        const SizedBox(width: 8),
      ],
      Flexible(child: bubble),
      if (widget.showAvatar && widget.mine) ...[
        const SizedBox(width: 8),
        avatar,
      ],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onHorizontalDragUpdate: handleHorizontalDragUpdate,
        onHorizontalDragEnd: handleHorizontalDragEnd,
        onHorizontalDragCancel: handleHorizontalDragCancel,
        child: Align(
          alignment: widget.mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: AnimatedScale(
                    scale: armed ? 1.08 : 1 + replyProgress * 0.04,
                    duration: 120.ms,
                    curve: Curves.easeOutBack,
                    child: AnimatedOpacity(
                      opacity: replyProgress == 0
                          ? 0
                          : 0.35 + replyProgress * 0.65,
                      duration: 120.ms,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: armed
                              ? colors.primary
                              : colors.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.reply,
                          size: 19,
                          color: armed
                              ? colors.onPrimary
                              : colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedSlide(
                offset: Offset(dragOffset / 320, 0),
                duration: dragOffset == 0 ? 260.ms : Duration.zero,
                curve: Curves.easeOutBack,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: rowChildren,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatBackground extends StatelessWidget {
  const _ChatBackground({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final overlay = colors.surface.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.78 : 0.68,
    );
    final image = localFileImageProvider(path);
    if (image == null) {
      return ColoredBox(color: colors.surface);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: image,
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(overlay, BlendMode.srcOver),
        ),
      ),
    );
  }
}

class _InlineStatusPill extends StatelessWidget {
  const _InlineStatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _memberLevelText(ChatMessage message) {
  if (message.memberLevel <= 0) {
    return '';
  }
  final title = message.memberTitle.trim();
  if (title.isEmpty) {
    return 'Lv.${message.memberLevel}';
  }
  return 'Lv.${message.memberLevel} $title';
}

class _SystemMessagePill extends StatefulWidget {
  const _SystemMessagePill({
    super.key,
    required this.message,
    required this.preferences,
  });

  final ChatMessage message;
  final CsacPreferences preferences;

  @override
  State<_SystemMessagePill> createState() => _SystemMessagePillState();
}

class _SystemMessagePillState extends State<_SystemMessagePill> {
  bool showTime = false;

  @override
  void didUpdateWidget(_SystemMessagePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id) {
      showTime = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = _MotionPreference.reduceOf(context);
    final body = chatMessagePlainText(widget.message, context.strings);
    final time = displayMessageTime(widget.message, widget.preferences);
    final canToggleTime = time.isNotEmpty;
    final text = showTime && canToggleTime ? time : body;
    final child = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: AnimatedSwitcher(
          duration: reduceMotion ? Duration.zero : 180.ms,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                axis: Axis.horizontal,
                child: child,
              ),
            );
          },
          child: Text(
            text,
            key: ValueKey<String>(showTime ? 'time:$text' : 'body:$text'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 28),
      child: Center(
        child: _CsacPressable(
          onTap: canToggleTime
              ? () => setState(() => showTime = !showTime)
              : null,
          child: child,
        ),
      ),
    );
  }
}

class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              height: 1,
              color: colors.primary.withValues(alpha: 0.38),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
            ),
            child: Text(
              strings.format('Unread messages below ({count})', {
                'count': count,
              }),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              height: 1,
              color: colors.primary.withValues(alpha: 0.38),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberLevelBadge extends StatelessWidget {
  const _MemberLevelBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 112),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.tertiaryContainer.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onTertiaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivateReadStatus extends StatelessWidget {
  const _PrivateReadStatus({required this.read});

  final bool read;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: 160.ms,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Row(
        key: ValueKey<bool>(read),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            read ? Icons.done_all : Icons.done,
            size: 14,
            color: read ? colors.primary : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 3),
          Text(
            context.strings.text(read ? 'Read' : 'Unread'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: read ? colors.primary : colors.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessageAvatar extends StatefulWidget {
  const _ChatMessageAvatar({
    required this.url,
    required this.mine,
    required this.name,
    this.onDoubleTap,
  });

  final String url;
  final bool mine;
  final String name;
  final VoidCallback? onDoubleTap;

  @override
  State<_ChatMessageAvatar> createState() => _ChatMessageAvatarState();
}

class _ChatMessageAvatarState extends State<_ChatMessageAvatar> {
  int patPulse = 0;

  void triggerPat() {
    if (widget.onDoubleTap == null) {
      return;
    }
    if (!_MotionPreference.reduceOf(context)) {
      HapticFeedback.selectionClick();
      setState(() => patPulse++);
    }
    widget.onDoubleTap!();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = _MotionPreference.reduceOf(context);
    final avatar = Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: _Avatar(
        url: widget.url,
        fallback: widget.mine ? Icons.person_rounded : Icons.person_outline,
        radius: 16,
        name: widget.name,
        backgroundColor: widget.mine
            ? colors.primaryContainer
            : colors.surfaceContainerHighest,
        foregroundColor: widget.mine
            ? colors.onPrimaryContainer
            : colors.onSurfaceVariant,
      ),
    );
    if (widget.onDoubleTap == null) {
      return avatar;
    }
    final animatedAvatar = reduceMotion
        ? avatar
        : SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (patPulse > 0)
                  TweenAnimationBuilder<double>(
                    key: ValueKey<int>(patPulse),
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: 560.ms,
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      final opacity = (1 - value).clamp(0.0, 1.0);
                      return Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: 1 + value * 0.58,
                          child: child,
                        ),
                      );
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.56),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                TweenAnimationBuilder<double>(
                  key: ValueKey<String>('avatar-pat-$patPulse'),
                  tween: Tween<double>(begin: patPulse == 0 ? 1 : 1.16, end: 1),
                  duration: 420.ms,
                  curve: Curves.easeOutBack,
                  builder: (context, scale, child) {
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: avatar,
                ),
              ],
            ),
          );
    return Tooltip(
      message: context.strings.text('Double tap to pat'),
      child: GestureDetector(onDoubleTap: triggerPat, child: animatedAvatar),
    );
  }
}

class _SelectionCheckbox extends StatelessWidget {
  const _SelectionCheckbox({required this.visible, required this.selected});

  final bool visible;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_MotionPreference.reduceOf(context)) {
      return visible
          ? Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? colors.primary : colors.onSurfaceVariant,
            )
          : const SizedBox(width: 0, height: 18);
    }
    return AnimatedSwitcher(
      duration: 220.ms,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return SizeTransition(
          sizeFactor: animation,
          axis: Axis.horizontal,
          alignment: Alignment.centerLeft,
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
        );
      },
      child: visible
          ? AnimatedSwitcher(
              key: const ValueKey('visible'),
              duration: 160.ms,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                key: ValueKey<bool>(selected),
                size: 18,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
            )
          : const SizedBox(key: ValueKey('hidden'), width: 0, height: 18),
    );
  }
}

class _ChatHintOverlay extends StatelessWidget {
  const _ChatHintOverlay({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final strings = context.strings;
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: colors.cardBackground.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colors.separator.withValues(alpha: 0.28),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.black.withValues(
                  alpha: colors.isDark ? 0.30 : 0.12,
                ),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: CupertinoTheme.of(
                    context,
                  ).primaryColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.lightbulb,
                  color: CupertinoTheme.of(context).primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.text('Quick tips'),
                      style: TextStyle(
                        color: colors.label,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _ChatHintLine(
                      icon: CupertinoIcons.arrow_left,
                      text: strings.text('Swipe left on a message to reply.'),
                    ),
                    _ChatHintLine(
                      icon: CupertinoIcons.hand_point_right,
                      text: strings.text('Long press a message for actions.'),
                    ),
                    _ChatHintLine(
                      icon: CupertinoIcons.plus_circle,
                      text: strings.text('Use + to send images and voice.'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(30, 30),
                onPressed: onDismiss,
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  color: colors.tertiaryLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return content;
  }
}

class _ChatHintLine extends StatelessWidget {
  const _ChatHintLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: colors.secondaryLabel),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.secondaryLabel, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedSendButton extends StatelessWidget {
  const _AnimatedSendButton({required this.active, required this.onPressed});

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = active ? colors.primary : colors.surfaceContainerHighest;
    final foreground = active ? colors.onPrimary : colors.onSurfaceVariant;
    return AnimatedScale(
      scale: active ? 1 : 0.94,
      duration: 170.ms,
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: 190.ms,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ]
              : null,
        ),
        child: IconButton(
          tooltip: context.strings.text('Send'),
          onPressed: onPressed,
          icon: AnimatedSwitcher(
            duration: 160.ms,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              Icons.send_rounded,
              key: ValueKey<bool>(active),
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposeMenuAction {
  const _ComposeMenuAction({
    required this.value,
    required this.icon,
    required this.label,
  });

  final String value;
  final IconData icon;
  final String label;
}

class _ComposeMenuPanel extends StatelessWidget {
  const _ComposeMenuPanel({
    super.key,
    required this.actions,
    required this.onSelected,
  });

  final List<_ComposeMenuAction> actions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = _MotionPreference.reduceOf(context);
    final colors = CsacColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 430,
            maxHeight: math.min(468, MediaQuery.sizeOf(context).height * 0.54),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.cardBackground.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: colors.separator.withValues(alpha: 0.28),
                    width: 0.5,
                  ),
                  boxShadow: reduceMotion
                      ? null
                      : [
                          BoxShadow(
                            color: CupertinoColors.black.withValues(
                              alpha: colors.isDark ? 0.30 : 0.12,
                            ),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: actions.length,
                  separatorBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(left: 74),
                    child: Container(
                      height: 0.5,
                      color: colors.separator.withValues(alpha: 0.42),
                    ),
                  ),
                  itemBuilder: (context, index) {
                    return _ComposeMenuTile(
                      action: actions[index],
                      index: index,
                      onTap: () => onSelected(actions[index].value),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposeMenuTile extends StatelessWidget {
  const _ComposeMenuTile({
    required this.action,
    required this.index,
    required this.onTap,
  });

  final _ComposeMenuAction action;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = _MotionPreference.reduceOf(context);
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    final tile = Tooltip(
      message: action.label,
      child: _CsacPressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 46,
                  child: Icon(action.icon, color: primary, size: 24),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.label,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                CupertinoIcons.chevron_right,
                size: 16,
                color: colors.tertiaryLabel,
              ),
            ],
          ),
        ),
      ),
    );
    if (reduceMotion) {
      return tile;
    }
    return tile
        .animate(delay: Duration(milliseconds: 26 * index))
        .fadeIn(duration: 170.ms, curve: Curves.easeOutCubic)
        .slideY(
          begin: 0.16,
          end: 0,
          duration: 330.ms,
          curve: Curves.easeOutCubic,
        )
        .scale(
          begin: const Offset(0.97, 0.97),
          end: const Offset(1, 1),
          duration: 360.ms,
          curve: Curves.easeOutBack,
        );
  }
}

class _EmojiStickerPicker extends StatefulWidget {
  const _EmojiStickerPicker({
    required this.stickers,
    required this.recentStickers,
  });

  final List<EmojiSticker> stickers;
  final List<EmojiSticker> recentStickers;

  @override
  State<_EmojiStickerPicker> createState() => _EmojiStickerPickerState();
}

class _EmojiStickerPickerState extends State<_EmojiStickerPicker> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<EmojiSticker> filterStickers(List<EmojiSticker> stickers) {
    final query = search.text.trim().toLowerCase();
    if (query.isEmpty) {
      return stickers;
    }
    return stickers.where((sticker) {
      return sticker.fullName.toLowerCase().contains(query) ||
          sticker.abbr.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reduceMotion = _MotionPreference.reduceOf(context);
    final maxHeight = math.min(MediaQuery.sizeOf(context).height * 0.72, 620.0);
    final availableByAbbr = <String, EmojiSticker>{
      for (final sticker in widget.stickers) sticker.abbr: sticker,
    };
    final resolvedRecent = <EmojiSticker>[
      for (final sticker in widget.recentStickers)
        if (availableByAbbr.containsKey(sticker.abbr))
          availableByAbbr[sticker.abbr]!
        else
          sticker,
    ];
    final filteredRecent = filterStickers(resolvedRecent);
    final recentAbbrs = filteredRecent.map((sticker) => sticker.abbr).toSet();
    final allStickers = [
      for (final sticker in filterStickers(widget.stickers))
        if (!recentAbbrs.contains(sticker.abbr)) sticker,
    ];
    final hasMatches = filteredRecent.isNotEmpty || allStickers.isNotEmpty;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_emotions_outlined,
                    color: colors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.text('Emoji stickers'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: strings.text('Search stickers'),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: strings.text('Clear'),
                          onPressed: () => setState(search.clear),
                          icon: const Icon(Icons.close),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  isDense: true,
                ),
              ),
            ),
            if (widget.stickers.isEmpty)
              Flexible(
                child: _EmptyPanel(message: strings.text('No emoji stickers.')),
              )
            else if (!hasMatches)
              Flexible(
                child: _EmptyPanel(
                  message: strings.text('No matching stickers.'),
                ),
              )
            else
              Flexible(
                child: CustomScrollView(
                  slivers: [
                    if (filteredRecent.isNotEmpty) ...[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                        sliver: SliverToBoxAdapter(
                          child: _EmojiPickerSectionHeader(
                            label: strings.text('Recent stickers'),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                        sliver: _EmojiStickerGrid(
                          stickers: filteredRecent,
                          reduceMotion: reduceMotion,
                          onSelected: (sticker) =>
                              Navigator.of(context).pop(sticker),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                        sliver: SliverToBoxAdapter(
                          child: _EmojiPickerSectionHeader(
                            label: strings.text('All stickers'),
                          ),
                        ),
                      ),
                    ],
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                      sliver: _EmojiStickerGrid(
                        stickers: allStickers,
                        reduceMotion: reduceMotion,
                        onSelected: (sticker) =>
                            Navigator.of(context).pop(sticker),
                      ),
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

class _EmojiPickerSectionHeader extends StatelessWidget {
  const _EmojiPickerSectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmojiStickerGrid extends StatelessWidget {
  const _EmojiStickerGrid({
    required this.stickers,
    required this.reduceMotion,
    required this.onSelected,
  });

  final List<EmojiSticker> stickers;
  final bool reduceMotion;
  final ValueChanged<EmojiSticker> onSelected;

  @override
  Widget build(BuildContext context) {
    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 116,
        mainAxisExtent: 128,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final sticker = stickers[index];
        final tile = _EmojiStickerTile(
          sticker: sticker,
          onTap: () => onSelected(sticker),
        );
        if (reduceMotion) {
          return tile;
        }
        return tile
            .animate(delay: Duration(milliseconds: index * 18))
            .fadeIn(duration: 160.ms, curve: Curves.easeOutCubic)
            .scale(
              begin: const Offset(0.92, 0.92),
              end: const Offset(1, 1),
              duration: 300.ms,
              curve: Curves.easeOutBack,
            );
      },
    );
  }
}

class _EmojiStickerTile extends StatelessWidget {
  const _EmojiStickerTile({required this.sticker, required this.onTap});

  final EmojiSticker sticker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return _CsacPressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
            context,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: CupertinoColors.separator
                .resolveFrom(context)
                .withValues(alpha: 0.22),
            width: 0.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: _EmojiStickerImage(
                    url: sticker.address,
                    size: 72,
                    fallbackLabel: sticker.fullName,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                sticker.fullName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmojiStickerImage extends StatelessWidget {
  const _EmojiStickerImage({
    required this.url,
    required this.size,
    this.fallbackLabel = '',
  });

  final String url;
  final double size;
  final String fallbackLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        Icons.emoji_emotions_outlined,
        color: colors.onSecondaryContainer,
        size: size * 0.46,
      ),
    );
    if (url.trim().isEmpty) {
      return Semantics(label: fallbackLabel, child: fallback);
    }
    return Semantics(
      label: fallbackLabel,
      image: true,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => fallback,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return SizedBox(
            width: size,
            height: size,
            child: Center(
              child: SizedBox.square(
                dimension: math.max(18, size * 0.28),
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VoiceMessageTile extends StatelessWidget {
  const _VoiceMessageTile({
    required this.declaredDuration,
    required this.duration,
    required this.position,
    required this.playing,
    required this.active,
    required this.speed,
    required this.textColor,
    this.onTap,
    this.onSeek,
    this.onSpeed,
  });

  final int declaredDuration;
  final Duration duration;
  final Duration position;
  final bool playing;
  final bool active;
  final double speed;
  final Color textColor;
  final VoidCallback? onTap;
  final ValueChanged<Duration>? onSeek;
  final VoidCallback? onSpeed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = Theme.of(context).colorScheme;
    final total = duration > Duration.zero
        ? duration
        : declaredDuration > 0
        ? Duration(seconds: declaredDuration)
        : Duration.zero;
    final clampedPosition = position > total && total > Duration.zero
        ? total
        : position;
    final totalMs = total.inMilliseconds;
    final positionMs = clampedPosition.inMilliseconds.clamp(0, totalMs);
    final canSeek = active && totalMs > 0 && onSeek != null;
    final statusLabel = playing
        ? context.strings.text('Playing')
        : active
        ? context.strings.text('Paused')
        : context.strings.text('Voice message');
    final progress = totalMs > 0 ? positionMs / totalMs : 0.0;
    final maxWidth = chatBubbleMaxWidth(context) - 24;
    return AnimatedContainer(
      duration: 180.ms,
      curve: Curves.easeOutCubic,
      constraints: BoxConstraints(
        minWidth: math.min(220.0, maxWidth),
        maxWidth: maxWidth,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: active
            ? colors.primaryContainer.withValues(alpha: 0.34)
            : colors.surface.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? colors.primary : textColor.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: const Size(38, 38),
                onPressed: onTap,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: AnimatedSwitcher(
                    duration: 190.ms,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => RotationTransition(
                      turns: Tween<double>(begin: -0.08, end: 0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        ),
                      ),
                      child: ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                    ),
                    child: Icon(
                      playing
                          ? CupertinoIcons.pause_fill
                          : CupertinoIcons.play_fill,
                      key: ValueKey<bool>(playing),
                      color: colors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _VoiceWaveform(
                progress: progress,
                playing: playing,
                color: active ? colors.primary : textColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              CupertinoButton(
                onPressed: active ? onSpeed : null,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(44, 32),
                child: Text(formatVoiceSpeed(speed)),
              ),
            ],
          ),
          CupertinoSlider(
            value: totalMs > 0 ? positionMs.toDouble() : 0,
            min: 0,
            max: totalMs > 0 ? totalMs.toDouble() : 1,
            activeColor: colors.primary,
            onChanged: canSeek
                ? (value) => onSeek!(Duration(milliseconds: value.round()))
                : null,
          ),
          Row(
            children: [
              Text(
                formatVoiceClock(clampedPosition),
                style: theme.textTheme.labelSmall?.copyWith(color: textColor),
              ),
              const Spacer(),
              Text(
                total > Duration.zero
                    ? formatVoiceClock(total)
                    : context.strings.text('Unknown duration'),
                style: theme.textTheme.labelSmall?.copyWith(color: textColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoiceWaveform extends StatelessWidget {
  const _VoiceWaveform({
    required this.progress,
    required this.playing,
    required this.color,
  });

  final double progress;
  final bool playing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const bars = <double>[0.35, 0.72, 0.48, 0.92, 0.58, 0.8, 0.4];
    const barWidth = 3.0;
    const barGap = 1.0;
    final waveformWidth = bars.length * barWidth + (bars.length - 1) * barGap;
    return SizedBox(
          width: waveformWidth,
          height: 24,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (final entry in bars.indexed)
                Padding(
                  padding: EdgeInsets.only(
                    right: entry.$1 == bars.length - 1 ? 0 : barGap,
                  ),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: bars[entry.$1],
                      end: playing
                          ? 0.34 + (((progress * 12) + entry.$1 * 0.37) % 0.66)
                          : bars[entry.$1],
                    ),
                    duration: playing ? 240.ms : 180.ms,
                    curve: Curves.easeInOut,
                    builder: (context, value, _) {
                      return AnimatedContainer(
                        duration: 180.ms,
                        width: barWidth,
                        height: 6 + value * 18,
                        decoration: BoxDecoration(
                          color: color.withValues(
                            alpha: playing || entry.$2 <= progress ? 1 : 0.45,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        )
        .animate(
          target: playing ? 1 : 0,
          onComplete: (controller) {
            if (playing) {
              controller.repeat(reverse: true);
            }
          },
        )
        .shimmer(duration: 900.ms, color: color.withValues(alpha: 0.18));
  }
}

String formatVoiceClock(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  if (minutes >= 60) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '$hours:${remainingMinutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String formatVoiceSpeed(double speed) {
  if ((speed - speed.roundToDouble()).abs() < 0.01) {
    return '${speed.round()}x';
  }
  return '${speed.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '')}x';
}

class _RecordedVoice {
  const _RecordedVoice({required this.path, required this.durationSeconds});

  final String path;
  final int durationSeconds;
}

class _VoiceRecorderDialog extends StatefulWidget {
  const _VoiceRecorderDialog();

  @override
  State<_VoiceRecorderDialog> createState() => _VoiceRecorderDialogState();
}

class _VoiceRecorderDialogState extends State<_VoiceRecorderDialog> {
  final recorder = AudioRecorder();
  Timer? ticker;
  DateTime? startedAt;
  String? outputPath;
  bool starting = true;
  bool stopping = false;
  bool cancelled = false;
  String? error;

  @override
  void initState() {
    super.initState();
    unawaited(startRecording());
  }

  @override
  void dispose() {
    ticker?.cancel();
    unawaited(recorder.dispose());
    super.dispose();
  }

  Future<void> startRecording() async {
    try {
      final hasPermission = await recorder.hasPermission();
      if (!mounted) {
        return;
      }
      if (!hasPermission) {
        setState(() {
          starting = false;
          error = context.strings.text('Microphone permission is required.');
        });
        return;
      }
      final path = await createTemporaryVoicePath();
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
        ),
        path: path,
      );
      if (!mounted) {
        return;
      }
      outputPath = path;
      startedAt = DateTime.now();
      ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (mounted) {
          setState(() {});
        }
      });
      setState(() => starting = false);
    } catch (err) {
      if (!mounted) {
        return;
      }
      setState(() {
        starting = false;
        error = err.toString();
      });
    }
  }

  int elapsedSeconds() {
    final started = startedAt;
    if (started == null) {
      return 0;
    }
    return math.max(0, DateTime.now().difference(started).inSeconds);
  }

  String elapsedLabel() {
    final elapsed = elapsedSeconds();
    final minutes = elapsed ~/ 60;
    final seconds = elapsed % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> cancelRecording() async {
    cancelled = true;
    ticker?.cancel();
    try {
      await recorder.cancel();
    } catch (_) {
      final path = outputPath;
      if (path != null) {
        unawaited(deleteLocalFileIfExists(path));
      }
    }
    if (mounted) {
      Navigator.of(context).pop(null);
    }
  }

  Future<void> stopRecording() async {
    if (stopping || starting) {
      return;
    }
    final navigator = Navigator.of(context);
    final missingFileMessage = context.strings.text('Recording file missing.');
    setState(() => stopping = true);
    try {
      ticker?.cancel();
      final duration = math.max(1, elapsedSeconds());
      final path = await recorder.stop() ?? outputPath;
      if (!mounted || cancelled) {
        return;
      }
      if (path == null || !await localFileExists(path)) {
        setState(() {
          stopping = false;
          error = missingFileMessage;
        });
        return;
      }
      navigator.pop(_RecordedVoice(path: path, durationSeconds: duration));
    } catch (err) {
      if (!mounted) {
        return;
      }
      setState(() {
        stopping = false;
        error = err.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(strings.text('Record voice')),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: error == null
                      ? colors.primaryContainer
                      : colors.errorContainer,
                ),
                child: Icon(
                  error == null ? Icons.mic : Icons.mic_off,
                  size: 42,
                  color: error == null
                      ? colors.onPrimaryContainer
                      : colors.onErrorContainer,
                ),
              ),
              const SizedBox(height: 18),
              if (starting)
                Text(strings.text('Starting recorder...'))
              else if (error != null)
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.error,
                  ),
                )
              else
                Text(
                  elapsedLabel(),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                strings.text('Tap stop to send this voice message.'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: stopping ? null : cancelRecording,
            child: Text(strings.text('Cancel')),
          ),
          FilledButton.icon(
            onPressed: starting || stopping || error != null
                ? null
                : stopRecording,
            icon: stopping
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.stop_circle_outlined),
            label: Text(
              strings.text(stopping ? 'Sending...' : 'Stop and send'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingMessageBubble extends StatefulWidget {
  const _PendingMessageBubble({required this.pending, required this.onRetry});

  final _PendingSend pending;
  final VoidCallback onRetry;

  @override
  State<_PendingMessageBubble> createState() => _PendingMessageBubbleState();
}

class _PendingMessageBubbleState extends State<_PendingMessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController shake;
  late final Animation<double> shakeOffset;
  _PendingSendStatus? lastStatus;

  @override
  void initState() {
    super.initState();
    lastStatus = widget.pending.status;
    shake = AnimationController(duration: 420.ms, vsync: this);
    shakeOffset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: 8, end: -5), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: -5, end: 4), weight: 2),
      TweenSequenceItem(tween: Tween<double>(begin: 4, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: shake, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(covariant _PendingMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pending.status == _PendingSendStatus.failed &&
        lastStatus != _PendingSendStatus.failed) {
      shake.forward(from: 0);
    }
    lastStatus = widget.pending.status;
  }

  @override
  void dispose() {
    shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final strings = context.strings;
    final failed = widget.pending.status == _PendingSendStatus.failed;
    final sent = widget.pending.status == _PendingSendStatus.sent;
    final maxBubbleWidth = chatBubbleMaxWidth(context);
    final foreground = failed
        ? colors.onErrorContainer
        : colors.onPrimaryContainer;
    return AnimatedBuilder(
      animation: shake,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(shakeOffset.value, 0),
          child: child,
        );
      },
      child: AnimatedOpacity(
        opacity: sent ? 0 : 1,
        duration: 240.ms,
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AnimatedSwitcher(
                duration: 160.ms,
                child: Text(
                  failed
                      ? strings.text('Send failed')
                      : sent
                      ? strings.text('Sent')
                      : strings.text('Sending...'),
                  key: ValueKey<_PendingSendStatus>(widget.pending.status),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: failed ? colors.error : colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                    duration: 180.ms,
                    curve: Curves.easeOutCubic,
                    constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: failed
                          ? colors.errorContainer
                          : colors.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: failed ? colors.error : colors.primaryContainer,
                      ),
                      boxShadow: failed
                          ? null
                          : [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.16),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.pending.hasImage) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 18,
                                color: foreground,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  widget.pending.imageName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: foreground,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (widget.pending.text.isNotEmpty)
                            const SizedBox(height: 8),
                        ],
                        if (widget.pending.hasVoice) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.mic_none, size: 18, color: foreground),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  widget.pending.voiceDuration > 0
                                      ? '${widget.pending.voiceName} (${widget.pending.voiceDuration}s)'
                                      : widget.pending.voiceName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: foreground,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (widget.pending.text.isNotEmpty)
                            const SizedBox(height: 8),
                        ],
                        if (widget.pending.hasEmoji) ...[
                          _EmojiStickerImage(
                            url: widget.pending.emoji!.address,
                            size: 104,
                            fallbackLabel: widget.pending.emoji!.fullName,
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (widget.pending.text.isNotEmpty)
                          Text(
                            widget.pending.text,
                            style: TextStyle(color: foreground),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!failed)
                              _SendingDots(color: foreground)
                            else
                              Icon(
                                Icons.error_outline,
                                size: 16,
                                color: colors.onErrorContainer,
                              ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                failed && widget.pending.error.isNotEmpty
                                    ? compactMessage(
                                        widget.pending.error,
                                        max: 80,
                                      )
                                    : sent
                                    ? strings.text('Sent')
                                    : strings.text('Sending...'),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: foreground,
                                ),
                              ),
                            ),
                            if (failed) ...[
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: widget.onRetry,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: Text(strings.text('Retry send')),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 160.ms, curve: Curves.easeOutCubic)
                  .scale(
                    begin: widget.pending.hasEmoji
                        ? const Offset(0.72, 0.72)
                        : const Offset(1, 1),
                    end: const Offset(1, 1),
                    duration: widget.pending.hasEmoji ? 360.ms : 1.ms,
                    curve: Curves.easeOutBack,
                  )
                  .slideY(
                    begin: 0.16,
                    end: 0,
                    duration: 260.ms,
                    curve: Curves.easeOutBack,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendingDots extends StatelessWidget {
  const _SendingDots({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < 3; index++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child:
                  Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      )
                      .animate(
                        onPlay: (controller) =>
                            controller.repeat(reverse: true),
                        delay: Duration(milliseconds: index * 90),
                      )
                      .scale(
                        begin: const Offset(0.72, 0.72),
                        end: const Offset(1.25, 1.25),
                        duration: 430.ms,
                        curve: Curves.easeInOut,
                      )
                      .fade(
                        begin: 0.45,
                        end: 1,
                        duration: 430.ms,
                        curve: Curves.easeInOut,
                      ),
            ),
        ],
      ),
    );
  }
}

class _GroupAnnouncementBar extends StatelessWidget {
  const _GroupAnnouncementBar({
    required this.announcement,
    required this.onTap,
  });

  final String announcement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final primary = CupertinoTheme.of(context).primaryColor;
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: _CsacPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: primary.withValues(alpha: 0.18),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Icon(CupertinoIcons.speaker_2, color: primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.text('Group announcement'),
                      style: TextStyle(
                        color: primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      announcement,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.label, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(CupertinoIcons.chevron_right, color: primary, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MessageAction {
  select,
  copyText,
  copyImage,
  openImage,
  downloadImage,
  reply,
  recall,
  essence,
}

class _SpringSheet extends StatelessWidget {
  const _SpringSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (_MotionPreference.reduceOf(context)) {
      return child;
    }
    return child
        .animate()
        .fadeIn(duration: 140.ms, curve: Curves.easeOutCubic)
        .slideY(
          begin: 0.08,
          end: 0,
          duration: 360.ms,
          curve: Curves.easeOutBack,
        )
        .scale(
          begin: const Offset(0.98, 0.98),
          end: const Offset(1, 1),
          duration: 360.ms,
          curve: Curves.easeOutBack,
        );
  }
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
    final actions = <Widget>[
      _CupertinoListTile(
        leading: const Icon(CupertinoIcons.checkmark_circle),
        title: strings.text('Select messages'),
        subtitle: strings.text('Choose multiple messages'),
        onTap: () => Navigator.of(context).pop(_MessageAction.select),
      ),
      _CupertinoListTile(
        leading: const Icon(CupertinoIcons.reply),
        title: strings.text('Reply'),
        subtitle: '#${message.id} ${message.sender}',
        onTap: () => Navigator.of(context).pop(_MessageAction.reply),
      ),
      _CupertinoListTile(
        leading: const Icon(CupertinoIcons.doc_on_doc),
        title: strings.text('Copy text'),
        onTap: () => Navigator.of(context).pop(_MessageAction.copyText),
      ),
      if (message.imageUrl.isNotEmpty)
        _CupertinoListTile(
          leading: const Icon(CupertinoIcons.link),
          title: strings.text('Copy image link'),
          onTap: () => Navigator.of(context).pop(_MessageAction.copyImage),
        ),
      if (message.imageUrl.isNotEmpty)
        _CupertinoListTile(
          leading: const Icon(CupertinoIcons.arrow_up_right_square),
          title: strings.text('Open image'),
          onTap: () => Navigator.of(context).pop(_MessageAction.openImage),
        ),
      if (message.imageUrl.isNotEmpty)
        _CupertinoListTile(
          leading: const Icon(CupertinoIcons.arrow_down_circle),
          title: strings.text('Download image'),
          onTap: () => Navigator.of(context).pop(_MessageAction.downloadImage),
        ),
      if (canRecall)
        _CupertinoListTile(
          leading: const Icon(CupertinoIcons.arrow_uturn_left),
          title: strings.text('Recall'),
          onTap: () => Navigator.of(context).pop(_MessageAction.recall),
        ),
      if (canEssence)
        _CupertinoListTile(
          leading: Icon(
            message.isEssence ? CupertinoIcons.star_fill : CupertinoIcons.star,
          ),
          title: strings.text(
            message.isEssence ? 'Remove essence' : 'Set essence',
          ),
          onTap: () => Navigator.of(context).pop(_MessageAction.essence),
        ),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        child: _CupertinoGroupedCard(
          margin: EdgeInsets.zero,
          children: actions,
        ),
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
                          child: _CupertinoListTile(
                            leading: _Avatar(
                              url: member.avatar,
                              fallback: CupertinoIcons.person_fill,
                              name: member.name,
                            ),
                            title: member.name,
                            subtitle: member.subtitle.isEmpty
                                ? null
                                : member.subtitle,
                            trailing: Icon(
                              checked
                                  ? CupertinoIcons.checkmark_circle_fill
                                  : CupertinoIcons.circle,
                              color: checked
                                  ? CupertinoTheme.of(context).primaryColor
                                  : CsacColors.of(context).tertiaryLabel,
                            ),
                            onTap: () {
                              setState(() {
                                if (checked) {
                                  selected.remove(member.uid);
                                } else {
                                  selected.add(member.uid);
                                }
                              });
                            },
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

class _ForwardConversationSheet extends StatelessWidget {
  const _ForwardConversationSheet({required this.conversations});

  final List<Conversation> conversations;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SafeArea(
      child: SizedBox(
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                strings.text('Forward to'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: conversations.isEmpty
                  ? _EmptyPanel(
                      message: strings.text('No conversations available.'),
                    )
                  : ListView.builder(
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final conversation = conversations[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: _RoundedInkClip(
                            child: ListTile(
                              leading: Icon(
                                conversation.type == ConversationType.group
                                    ? Icons.groups_rounded
                                    : Icons.person_rounded,
                              ),
                              title: Text(
                                conversation.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: conversation.subtitle.isEmpty
                                  ? null
                                  : Text(
                                      conversation.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              onTap: () =>
                                  Navigator.of(context).pop(conversation),
                            ),
                          ),
                        );
                      },
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
  final search = TextEditingController();
  List<ChatMessage> messages = const <ChatMessage>[];
  EssenceStats? stats;
  Map<int, String> contributorAvatars = const <int, String>{};
  String statsType = 'all';
  bool loading = true;
  bool loadingStats = true;
  String? error;
  String? statsError;

  static const statsTypeOptions = ['today', 'week', 'month', 'all'];

  @override
  void initState() {
    super.initState();
    search.addListener(() => setState(() {}));
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      loadingStats = true;
      error = null;
      statsError = null;
    });
    try {
      final results = await Future.wait<Object?>([
        widget.state.loadEssenceMessages(widget.conversation.id),
        widget.state
            .loadEssenceStats(widget.conversation.id, type: statsType)
            .then<Object?>((value) => value)
            .catchError((Object err) => err),
      ]);
      final loaded = results[0] as List<ChatMessage>;
      final statsResult = results[1];
      if (!mounted) {
        return;
      }
      setState(() {
        messages = loaded.reversed.toList();
        if (statsResult is EssenceStats) {
          stats = statsResult;
        } else {
          stats = EssenceStats.fromMessages(loaded, type: statsType);
          statsError = statsResult?.toString();
        }
      });
      unawaited(loadContributorAvatars());
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          loadingStats = false;
        });
      }
    }
  }

  Future<void> changeStatsType(String value) async {
    if (value == statsType) {
      return;
    }
    setState(() {
      statsType = value;
      loadingStats = true;
      statsError = null;
    });
    try {
      final loaded = await widget.state.loadEssenceStats(
        widget.conversation.id,
        type: value,
      );
      if (mounted) {
        setState(() => stats = loaded);
        unawaited(loadContributorAvatars());
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          stats = EssenceStats.fromMessages(messages, type: value);
          statsError = err.toString();
        });
        unawaited(loadContributorAvatars());
      }
    } finally {
      if (mounted) {
        setState(() => loadingStats = false);
      }
    }
  }

  Future<void> loadContributorAvatars() async {
    final contributors = (stats ?? EssenceStats.fromMessages(messages))
        .contributors
        .where((contributor) => contributor.uid > 0)
        .take(5)
        .toList();
    final next = <int, String>{
      for (final entry in contributorAvatars.entries) entry.key: entry.value,
    };
    var changed = false;
    for (final contributor in contributors) {
      if (contributor.avatar.isNotEmpty) {
        if (next[contributor.uid] != contributor.avatar) {
          next[contributor.uid] = contributor.avatar;
          changed = true;
        }
        continue;
      }
      if (next[contributor.uid]?.isNotEmpty == true) {
        continue;
      }
      try {
        final profile = await widget.state.loadUserProfile(contributor.uid);
        if (profile.avatar.isEmpty) {
          continue;
        }
        next[contributor.uid] = profile.avatar;
        changed = true;
      } catch (_) {}
    }
    if (changed && mounted) {
      setState(() => contributorAvatars = next);
    }
  }

  Future<void> openMessage(ChatMessage message) async {
    final messenger = ScaffoldMessenger.of(context);
    final strings = context.strings;
    List<ChatMessage> around;
    var loadedFromNetwork = false;
    try {
      around = await widget.state.loadMessagesAroundFromNetwork(
        widget.conversation,
        message,
      );
      loadedFromNetwork = true;
    } catch (_) {
      await widget.state.cache.saveMessages(widget.conversation, [message]);
      around = await widget.state.loadCachedMessagesAround(
        widget.conversation,
        message.id,
      );
    }
    if (!mounted) {
      return;
    }
    final containsTarget = around.any((item) => item.id == message.id);
    final hasContext =
        around.any((item) => item.id < message.id) ||
        around.any((item) => item.id > message.id);
    if (!containsTarget || (!loadedFromNetwork && !hasContext)) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(strings.text('Unable to locate this essence message.')),
        ),
      );
      return;
    }
    return Navigator.of(context).push<void>(
      CsacPageRoute<void>(
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
    final strings = context.strings;
    final query = search.text.trim().toLowerCase();
    final filteredMessages = query.isEmpty
        ? messages
        : messages.where((message) {
            final target =
                '${message.sender} ${chatMessagePlainText(message, strings)} ${message.time} ${message.imageUrl} ${message.voiceUrl} ${message.fileUrl} ${message.emojiAddress} ${message.emojiAbbr}'
                    .toLowerCase();
            return target.contains(query);
          }).toList();
    final effectiveStats =
        stats ?? EssenceStats.fromMessages(messages, type: statsType);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.text('Essence messages')),
        actions: [
          IconButton(
            tooltip: strings.text('Refresh'),
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
            _EssenceStatsHeader(
              stats: effectiveStats,
              loading: loadingStats,
              statsError: statsError,
              avatarOverrides: contributorAvatars,
              selectedType: statsType,
              typeOptions: statsTypeOptions,
              onTypeChanged: changeStatsType,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: strings.text('Search essence messages'),
                border: const OutlineInputBorder(),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: strings.text('Clear'),
                        onPressed: search.clear,
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              strings.format('{count} essence messages', {
                'count': filteredMessages.length,
              }),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (!loading && messages.isEmpty)
              _EmptyPanel(message: strings.text('No essence messages.'))
            else if (!loading && filteredMessages.isEmpty)
              _EmptyPanel(
                message: strings.text('No matching essence messages.'),
              )
            else
              for (final message in filteredMessages)
                _EssenceMessageTile(
                  message: message,
                  preferences: widget.state.preferences,
                  onTap: () => openMessage(message),
                ),
          ],
        ),
      ),
    );
  }
}

class _EssenceStatsHeader extends StatelessWidget {
  const _EssenceStatsHeader({
    required this.stats,
    required this.loading,
    required this.statsError,
    required this.avatarOverrides,
    required this.selectedType,
    required this.typeOptions,
    required this.onTypeChanged,
  });

  final EssenceStats stats;
  final bool loading;
  final String? statsError;
  final Map<int, String> avatarOverrides;
  final String selectedType;
  final List<String> typeOptions;
  final ValueChanged<String> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.text('Essence statistics'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in typeOptions)
                  _CupertinoMiniPill(
                    label: strings.text(essenceStatsTypeLabel(type)),
                    selected: selectedType == type,
                    onTap: () => onTypeChanged(type),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _EssenceMetricTile(
                    icon: Icons.star_outline,
                    label: strings.text('Total essence'),
                    value: '${stats.total}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _EssenceMetricTile(
                    icon: Icons.people_outline,
                    label: strings.text('Contributors'),
                    value: '${stats.contributors.length}',
                  ),
                ),
              ],
            ),
            if (statsError != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.text('Showing local fallback statistics.'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (stats.categories.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                strings.text('Category breakdown'),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final category in stats.categories)
                _EssenceCategoryRow(category: category, total: stats.total),
            ],
            if (stats.contributors.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                strings.text('Contribution ranking'),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              for (final contributor in stats.contributors.take(5))
                _EssenceContributorRow(
                  contributor: contributor,
                  avatarUrl: avatarOverrides[contributor.uid],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EssenceMetricTile extends StatelessWidget {
  const _EssenceMetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EssenceCategoryRow extends StatelessWidget {
  const _EssenceCategoryRow({required this.category, required this.total});

  final EssenceCategoryCount category;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total <= 0 ? 0.0 : category.count / total;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            essenceCategoryIcon(category.category),
            size: 20,
            color: colors.primary,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(
              context.strings.text(essenceCategoryLabel(category.category)),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio.clamp(0, 1),
                minHeight: 8,
                backgroundColor: colors.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 38,
            child: Text(
              '${category.count}',
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _EssenceContributorRow extends StatelessWidget {
  const _EssenceContributorRow({required this.contributor, this.avatarUrl});

  final EssenceContributor contributor;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _Avatar(
            url: avatarUrl?.isNotEmpty == true
                ? avatarUrl!
                : contributor.avatar,
            fallback: CupertinoIcons.person_fill,
            radius: 16,
            name: contributor.name,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              contributor.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.label, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          _InlineStatusPill(
            icon: CupertinoIcons.bubble_left_bubble_right,
            label: context.strings.format('{count} messages', {
              'count': contributor.count,
            }),
            color: CupertinoTheme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}

class _CupertinoMiniPill extends StatelessWidget {
  const _CupertinoMiniPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

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
        duration: 180.ms,
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? primary.withValues(alpha: 0.14)
              : colors.cardBackground,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? primary.withValues(alpha: 0.22)
                : colors.separator.withValues(alpha: 0.22),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? primary : colors.secondaryLabel,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

String essenceStatsTypeLabel(String type) {
  switch (type) {
    case 'today':
      return 'Today';
    case 'week':
      return 'This week';
    case 'month':
      return 'This month';
    case 'all':
      return 'All time';
    default:
      return type;
  }
}

String essenceCategoryLabel(String category) {
  switch (category) {
    case 'text':
      return 'Text';
    case 'image':
      return 'Images';
    case 'voice':
      return 'Voice';
    case 'file':
      return 'Files';
    default:
      return category;
  }
}

IconData essenceCategoryIcon(String category) {
  switch (category) {
    case 'image':
      return Icons.image_outlined;
    case 'voice':
      return Icons.mic_none_outlined;
    case 'file':
      return Icons.insert_drive_file_outlined;
    default:
      return Icons.notes_outlined;
  }
}

class _EssenceMessageTile extends StatelessWidget {
  const _EssenceMessageTile({
    required this.message,
    required this.preferences,
    required this.onTap,
  });

  final ChatMessage message;
  final CsacPreferences preferences;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time = displayMessageTime(message, preferences);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.star_outline),
        title: Text(
          message.sender,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if (time.isNotEmpty) time,
            chatMessagePlainText(message, context.strings),
          ].join(' | '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
