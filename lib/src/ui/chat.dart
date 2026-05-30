part of '../../main.dart';

enum _PendingSendStatus { sending, failed }

enum _ComposeMenuAction {
  image,
  recordVoice,
  audioFile,
  genericFile,
  media,
  export,
  mention,
}

enum _ChatBarMenuAction { search, refresh, essence, details }

class _VoiceFileType {
  const _VoiceFileType(this.extension, this.mimeType);

  final String extension;
  final String mimeType;
}

class _PendingSend {
  const _PendingSend({
    required this.localId,
    required this.text,
    this.imageBytes,
    this.imageName = '',
    this.voiceBytes,
    this.voiceName = '',
    this.voiceDuration = 0,
    this.fileBytes,
    this.fileName = '',
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
  final Uint8List? fileBytes;
  final String fileName;
  final int replyTo;
  final List<int> mentionUids;
  final _PendingSendStatus status;
  final String error;

  bool get hasImage => imageBytes != null;
  bool get hasVoice => voiceBytes != null;
  bool get hasFile => fileBytes != null;

  _PendingSend copyWith({
    String? text,
    Uint8List? imageBytes,
    String? imageName,
    Uint8List? voiceBytes,
    String? voiceName,
    int? voiceDuration,
    Uint8List? fileBytes,
    String? fileName,
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
      fileBytes: fileBytes ?? this.fileBytes,
      fileName: fileName ?? this.fileName,
      replyTo: replyTo ?? this.replyTo,
      mentionUids: mentionUids ?? this.mentionUids,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}

class _VoiceDraft {
  const _VoiceDraft({
    required this.bytes,
    required this.fileName,
    required this.durationSeconds,
    this.sourceLabel = '',
  });

  final Uint8List bytes;
  final String fileName;
  final int durationSeconds;
  final String sourceLabel;
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

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  final chatSearch = TextEditingController();
  final scroll = ScrollController();
  final imagePicker = ImagePicker();
  final audioRecorder = AudioRecorder();
  final audioPlayer = AudioPlayer();
  StreamSubscription<Object?>? audioErrorSubscription;
  StreamSubscription<void>? audioCompleteSubscription;
  Timer? chatSearchTimer;
  Timer? recordingTicker;
  final itemKeys = <int, GlobalKey>{};
  final messages = <ChatMessage>[];
  final pendingSends = <_PendingSend>[];
  final mentionTargets = <GroupMember>[];
  final selectedMessageIds = <int>{};
  final chatSearchResultIds = <int>[];
  Timer? timer;
  Timer? draftTimer;
  GroupProfile? groupProfile;
  ChatMessage? replyTarget;
  int nextPendingId = -1;
  int initialUnreadCount = 0;
  int refreshTicks = 0;
  int chatSearchIndex = -1;
  DateTime? recordingStartedAt;
  String? recordingPath;
  int? playingMessageId;
  int? voicePreviewToken;
  int recordingElapsedSeconds = 0;
  Duration voicePosition = Duration.zero;
  Duration voiceDuration = Duration.zero;
  _VoiceDraft? voiceDraft;
  bool loading = true;
  bool loadingOlder = false;
  bool hasMoreOlder = true;
  bool refreshing = false;
  bool pickingImage = false;
  bool searchMode = false;
  bool chatSearching = false;
  bool recording = false;
  bool previewingVoiceDraft = false;
  bool applyingDraft = false;
  bool applyingMentionText = false;
  bool mentionPickerOpen = false;
  bool showEntryHint = true;
  bool animateMessageEntries = false;
  bool offline = false;
  bool showJumpToBottom = false;
  bool conversationUnavailable = false;
  String previousInputText = '';
  String? error;

  bool get selectionMode => selectedMessageIds.isNotEmpty;

  double get voiceDraftProgress {
    final draft = voiceDraft;
    if (draft == null || voicePreviewToken == null) {
      return 0;
    }
    final duration = voiceDuration.inMilliseconds > 0
        ? voiceDuration
        : Duration(seconds: draft.durationSeconds);
    if (duration.inMilliseconds <= 0) {
      return 0.35;
    }
    return voicePosition.inMilliseconds / duration.inMilliseconds;
  }

  List<ChatMessage> get selectedMessages {
    return messages
        .where((message) => selectedMessageIds.contains(message.id))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    initialUnreadCount = widget.conversation.unreadCount;
    widget.state.setActiveConversation(widget.conversation);
    widget.state.markConversationRead(widget.conversation);
    input.addListener(scheduleDraftSave);
    input.addListener(handleInputChanged);
    scroll.addListener(handleScrollChanged);
    loadDraft();
    loadGroupAnnouncement();
    loadInitial();
    Future<void>.delayed(const Duration(milliseconds: 360), () {
      if (mounted) {
        setState(() => animateMessageEntries = true);
      }
    });
    Future<void>.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => showEntryHint = false);
      }
    });
    audioErrorSubscription = audioPlayer.eventStream.listen(
      (_) {},
      onError: (Object err) {
        if (!mounted) {
          return;
        }
        setState(() => playingMessageId = null);
        showSnack(
          context.strings.format('Playback failed: {error}', {'error': err}),
        );
      },
    );
    audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) {
        return;
      }
      setState(() => voicePosition = position);
    }, onError: handleAudioPlaybackError);
    audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) {
        return;
      }
      setState(() => voiceDuration = duration);
    }, onError: handleAudioPlaybackError);
    timer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => refresh(silent: true),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    draftTimer?.cancel();
    chatSearchTimer?.cancel();
    recordingTicker?.cancel();
    audioErrorSubscription?.cancel();
    audioCompleteSubscription?.cancel();
    audioPlayer.dispose();
    audioRecorder.dispose();
    unawaited(ConversationDraftStore.save(widget.conversation, input.text));
    if (widget.state.isActiveConversation(widget.conversation)) {
      widget.state.setActiveConversation(null);
    }
    input.dispose();
    chatSearch.dispose();
    scroll.dispose();
    super.dispose();
  }

  void handleScrollChanged() {
    if (!scroll.hasClients) {
      return;
    }
    final shouldShow =
        scroll.position.maxScrollExtent - scroll.position.pixels > 280;
    if (shouldShow != showJumpToBottom && mounted) {
      setState(() => showJumpToBottom = shouldShow);
    }
    if (scroll.position.pixels <= 96) {
      unawaited(loadOlderMessages());
    }
  }

  Future<void> loadOlderMessages() async {
    if (!mounted ||
        loadingOlder ||
        loading ||
        !hasMoreOlder ||
        messages.isEmpty) {
      return;
    }
    final beforeId = messages.first.id;
    final previousExtent = scroll.hasClients
        ? scroll.position.maxScrollExtent
        : 0.0;
    setState(() => loadingOlder = true);
    try {
      final older = await widget.state.loadOlderMessages(
        widget.conversation,
        beforeId: beforeId,
      );
      if (!mounted) return;
      if (older.isEmpty) {
        setState(() {
          hasMoreOlder = false;
          loadingOlder = false;
        });
        return;
      }
      final current = List<ChatMessage>.of(messages);
      setState(() {
        messages
          ..clear()
          ..addAll(mergeChatMessages(older, current));
        loadingOlder = false;
        offline = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !scroll.hasClients) return;
        final delta = scroll.position.maxScrollExtent - previousExtent;
        if (delta > 0) {
          scroll.jumpTo(scroll.position.pixels + delta);
        }
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        loadingOlder = false;
        offline = messages.isNotEmpty;
        error = context.strings.format('Offline cache: {error}', {
          'error': err,
        });
      });
    }
  }

  void handleAudioPlaybackError(Object err) {
    if (!mounted) {
      return;
    }
    unawaited(audioCompleteSubscription?.cancel());
    audioCompleteSubscription = null;
    setState(() {
      playingMessageId = null;
      voicePreviewToken = null;
      previewingVoiceDraft = false;
      voicePosition = Duration.zero;
      voiceDuration = Duration.zero;
    });
    showSnack(
      context.strings.format('Playback failed: {error}', {'error': err}),
    );
  }

  void listenForAudioComplete({int? messageId, int? previewToken}) {
    unawaited(audioCompleteSubscription?.cancel());
    audioCompleteSubscription = audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }
      if (previewToken != null) {
        if (voicePreviewToken != previewToken) {
          return;
        }
        setState(() {
          voicePreviewToken = null;
          previewingVoiceDraft = false;
          voicePosition = Duration.zero;
        });
        return;
      }
      if (messageId == null || playingMessageId != messageId) {
        return;
      }
      final next = widget.state.preferences.chat.voiceContinuousPlayback
          ? nextVoiceMessageAfter(messageId)
          : null;
      setState(() {
        playingMessageId = null;
        voicePosition = Duration.zero;
        voiceDuration = Duration.zero;
      });
      if (next != null) {
        unawaited(toggleVoicePlayback(next));
      }
    }, onError: handleAudioPlaybackError);
  }

  int? get firstUnreadMessageId {
    if (widget.conversation.type != ConversationType.private ||
        messages.isEmpty) {
      return null;
    }
    final myUid = widget.state.user?.uid;
    final explicitUnread = messages
        .where((message) => message.senderId != myUid && !message.isRead)
        .firstOrNull;
    if (explicitUnread != null) {
      return explicitUnread.id;
    }
    if (initialUnreadCount <= 0) {
      return null;
    }
    final incoming = messages
        .where((message) => message.senderId != myUid)
        .toList();
    if (incoming.isEmpty) {
      return null;
    }
    final index = (incoming.length - initialUnreadCount).clamp(
      0,
      incoming.length - 1,
    );
    return incoming[index].id;
  }

  bool get canJumpToFirstUnread => firstUnreadMessageId != null;

  int? get currentSearchMessageId {
    if (chatSearchIndex < 0 || chatSearchIndex >= chatSearchResultIds.length) {
      return null;
    }
    return chatSearchResultIds[chatSearchIndex];
  }

  Future<void> loadDraft() async {
    final draft = await ConversationDraftStore.load(widget.conversation);
    if (!mounted || input.text.isNotEmpty) {
      return;
    }
    applyingDraft = true;
    input
      ..text = draft
      ..selection = TextSelection.collapsed(offset: draft.length);
    previousInputText = draft;
    applyingDraft = false;
  }

  void handleInputChanged() {
    final text = input.text;
    if (applyingDraft || applyingMentionText) {
      previousInputText = text;
      return;
    }
    final selection = input.selection;
    final insertedText = text.length > previousInputText.length;
    final triggerOffset = selection.baseOffset;
    final shouldTriggerMention =
        widget.conversation.type == ConversationType.group &&
        !mentionPickerOpen &&
        insertedText &&
        selection.isCollapsed &&
        triggerOffset > 0 &&
        triggerOffset <= text.length &&
        text.codeUnitAt(triggerOffset - 1) == 0x40;
    previousInputText = text;
    if (shouldTriggerMention) {
      unawaited(chooseMentionTargets(triggerOffset: triggerOffset));
    }
  }

  void replaceMentionTrigger(int triggerOffset, List<GroupMember> selected) {
    if (selected.isEmpty ||
        triggerOffset <= 0 ||
        triggerOffset > input.text.length) {
      return;
    }
    if (input.text.codeUnitAt(triggerOffset - 1) != 0x40) {
      return;
    }
    final mentionText =
        '${selected.map((member) => '@${member.name}').join(' ')} ';
    final nextText = input.text.replaceRange(
      triggerOffset - 1,
      triggerOffset,
      mentionText,
    );
    final nextOffset = triggerOffset - 1 + mentionText.length;
    applyingMentionText = true;
    input.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
    previousInputText = nextText;
    applyingMentionText = false;
  }

  void scheduleDraftSave() {
    if (applyingDraft) {
      return;
    }
    draftTimer?.cancel();
    draftTimer = Timer(const Duration(milliseconds: 450), () {
      unawaited(ConversationDraftStore.save(widget.conversation, input.text));
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
    } catch (err) {
      if (isGroupUnavailableError(err)) {
        await handleUnavailableConversation();
      }
    }
  }

  Future<void> handleUnavailableConversation() async {
    if (!mounted || conversationUnavailable) {
      return;
    }
    setState(() {
      conversationUnavailable = true;
      error = context.strings.text('This group is no longer available.');
      pendingSends.clear();
    });
    if (widget.conversation.type == ConversationType.group) {
      await widget.state.removeConversationLocal(widget.conversation);
    }
    if (!mounted) {
      return;
    }
    showSnack(context.strings.text('This group has been removed from chats.'));
    Navigator.of(context).maybePop();
  }

  String sendFailureMessage(Object error) {
    final strings = context.strings;
    switch (classifySendRestriction(error)) {
      case CsacSendRestriction.groupUnavailable:
        return strings.text('This group is no longer available.');
      case CsacSendRestriction.muted:
        return strings.text('You are muted and cannot send messages.');
      case CsacSendRestriction.forbidden:
        return strings.text('You do not have permission to send messages.');
      case CsacSendRestriction.none:
        return error.toString();
    }
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
      if (cached.isNotEmpty && focusId != null) {
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
        hasMoreOlder = true;
      });
      await markCurrentConversationRead();
    } catch (err) {
      if (!mounted) {
        return;
      }
      if (isGroupUnavailableError(err)) {
        await handleUnavailableConversation();
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
        if (messages.isNotEmpty) {
          scrollAfterInitialLoad();
        }
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
          ..addAll(mergeChatMessages(List<ChatMessage>.of(messages), loaded));
        offline = false;
        hasMoreOlder = true;
      });
      await markCurrentConversationRead();
      scrollAfterLoad();
    } catch (err) {
      if (isGroupUnavailableError(err)) {
        await handleUnavailableConversation();
        return;
      }
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
            ..addAll(mergeChatMessages(List<ChatMessage>.of(messages), loaded));
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
      if (isGroupUnavailableError(err)) {
        await handleUnavailableConversation();
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
    if (conversationUnavailable) {
      showSnack(context.strings.text('This group is no longer available.'));
      return;
    }
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

  Future<void> pickAndSendImage() async {
    if (conversationUnavailable) {
      showSnack(context.strings.text('This group is no longer available.'));
      return;
    }
    if (pickingImage) {
      return;
    }
    setState(() => pickingImage = true);
    final picked = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (!mounted) {
      return;
    }
    setState(() => pickingImage = false);
    if (picked == null) {
      return;
    }
    final bytes = await picked.readAsBytes();
    if (!mounted) {
      return;
    }
    final caption = await showCupertinoDialog<String>(
      context: context,
      builder: (context) =>
          _ImageCaptionDialog(fileName: picked.name, bytes: bytes),
    );
    if (caption == null) {
      return;
    }
    final pending = _PendingSend(
      localId: nextPendingId--,
      text: caption.trim(),
      imageBytes: bytes,
      imageName: picked.name,
      replyTo: replyTarget?.id ?? 0,
      mentionUids: mentionTargets.map((member) => member.uid).toList(),
    );
    setState(() {
      pendingSends.add(pending);
      replyTarget = null;
      mentionTargets.clear();
      error = null;
    });
    scrollToEnd();
    unawaited(performPendingSend(pending.localId));
  }

  Future<void> toggleRecording() async {
    if (recording) {
      await stopRecordingToDraft();
      return;
    }
    await startRecording();
  }

  void startRecordingTimer() {
    recordingTicker?.cancel();
    recordingElapsedSeconds = 0;
    recordingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = recordingStartedAt;
      if (!mounted || startedAt == null) {
        return;
      }
      setState(() {
        recordingElapsedSeconds = DateTime.now()
            .difference(startedAt)
            .inSeconds
            .clamp(0, 600);
      });
    });
  }

  Future<void> cancelRecording() async {
    if (!recording) {
      return;
    }
    try {
      await audioRecorder.stop();
    } catch (_) {}
    recordingTicker?.cancel();
    final path = recordingPath;
    if (path != null && path.isNotEmpty) {
      unawaited(File(path).delete().then<void>((_) {}).catchError((_) {}));
    }
    if (!mounted) {
      return;
    }
    setState(() {
      recording = false;
      recordingPath = null;
      recordingStartedAt = null;
      recordingElapsedSeconds = 0;
    });
  }

  Future<void> startRecording() async {
    if (conversationUnavailable) {
      showSnack(context.strings.text('This group is no longer available.'));
      return;
    }
    final permissionMessage = context.strings.text(
      'Microphone permission is required.',
    );
    final unavailableMessage = context.strings.text(
      'Voice recording is not available.',
    );
    final failedMessage = context.strings.text('Recording failed: {error}');
    try {
      final allowed = await audioRecorder.hasPermission();
      if (!allowed) {
        showSnack(permissionMessage);
        return;
      }
      final isMobile = Platform.isAndroid || Platform.isIOS;
      var encoder = isMobile ? AudioEncoder.aacLc : AudioEncoder.wav;
      var extension = encoder == AudioEncoder.wav ? 'wav' : 'm4a';
      if (!await audioRecorder.isEncoderSupported(encoder)) {
        encoder = AudioEncoder.wav;
        extension = 'wav';
      }
      if (!await audioRecorder.isEncoderSupported(encoder)) {
        showSnack(unavailableMessage);
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = p.join(
        dir.path,
        'csac_voice_${DateTime.now().millisecondsSinceEpoch}.$extension',
      );
      await audioRecorder.start(
        RecordConfig(
          encoder: encoder,
          bitRate: isMobile ? 64000 : 128000,
          numChannels: 1,
          sampleRate: isMobile ? 44100 : 0,
        ),
        path: path,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        recording = true;
        recordingPath = path;
        recordingStartedAt = DateTime.now();
        recordingElapsedSeconds = 0;
        error = null;
      });
      startRecordingTimer();
    } catch (err) {
      if (mounted) {
        showSnack(failedMessage.replaceAll('{error}', '$err'));
      }
    }
  }

  Future<void> stopRecordingToDraft() async {
    final notSavedMessage = context.strings.text(
      'No voice recording was saved.',
    );
    final tooShortMessage = context.strings.text('Voice message is too short.');
    final failedMessage = context.strings.text('Recording failed: {error}');
    try {
      final fallbackPath = recordingPath;
      final path = await audioRecorder.stop();
      recordingTicker?.cancel();
      final startedAt = recordingStartedAt;
      if (!mounted) {
        return;
      }
      setState(() {
        recording = false;
        recordingPath = null;
        recordingStartedAt = null;
        recordingElapsedSeconds = 0;
      });
      final resolvedPath = path?.isNotEmpty == true ? path : fallbackPath;
      if (resolvedPath == null || resolvedPath.isEmpty) {
        showSnack(notSavedMessage);
        return;
      }
      final file = File(resolvedPath);
      if (!await file.exists()) {
        showSnack(notSavedMessage);
        return;
      }
      final bytes = await file.readAsBytes();
      final duration = startedAt == null
          ? 1
          : DateTime.now().difference(startedAt).inSeconds.clamp(1, 600);
      if (duration < 1 || bytes.isEmpty) {
        showSnack(tooShortMessage);
        return;
      }
      setState(() {
        voiceDraft = _VoiceDraft(
          bytes: bytes,
          fileName: p.basename(resolvedPath),
          durationSeconds: duration,
          sourceLabel: context.strings.text('Recorded voice'),
        );
        error = null;
      });
    } catch (err) {
      if (mounted) {
        recordingTicker?.cancel();
        setState(() {
          recording = false;
          recordingPath = null;
          recordingStartedAt = null;
          recordingElapsedSeconds = 0;
        });
        showSnack(failedMessage.replaceAll('{error}', '$err'));
      }
    }
  }

  void discardVoiceDraft() {
    if (voicePreviewToken != null) {
      unawaited(audioCompleteSubscription?.cancel());
      audioCompleteSubscription = null;
      unawaited(audioPlayer.stop());
    }
    setState(() {
      voiceDraft = null;
      previewingVoiceDraft = false;
      voicePreviewToken = null;
      voicePosition = Duration.zero;
      voiceDuration = Duration.zero;
    });
  }

  Future<void> sendVoiceDraft() async {
    final draft = voiceDraft;
    if (draft == null) {
      return;
    }
    if (voicePreviewToken != null) {
      await audioCompleteSubscription?.cancel();
      audioCompleteSubscription = null;
      await audioPlayer.stop();
    }
    final pending = _PendingSend(
      localId: nextPendingId--,
      text: '',
      voiceBytes: draft.bytes,
      voiceName: draft.fileName,
      voiceDuration: draft.durationSeconds,
      replyTo: replyTarget?.id ?? 0,
      mentionUids: mentionTargets.map((member) => member.uid).toList(),
    );
    setState(() {
      voiceDraft = null;
      previewingVoiceDraft = false;
      voicePreviewToken = null;
      voicePosition = Duration.zero;
      voiceDuration = Duration.zero;
      pendingSends.add(pending);
      replyTarget = null;
      mentionTargets.clear();
      error = null;
    });
    scrollToEnd();
    unawaited(performPendingSend(pending.localId));
  }

  Future<void> previewVoiceDraft() async {
    final draft = voiceDraft;
    if (draft == null) {
      return;
    }
    final strings = context.strings;
    try {
      if (voicePreviewToken != null) {
        await audioCompleteSubscription?.cancel();
        audioCompleteSubscription = null;
        await audioPlayer.stop();
        if (mounted) {
          setState(() {
            voicePreviewToken = null;
            previewingVoiceDraft = false;
          });
        }
        return;
      }
      await audioPlayer.stop();
      final dir = await getTemporaryDirectory();
      final fileType = resolveVoiceFileType(draft.bytes, null, draft.fileName);
      final extension = fileType?.extension ?? voiceExtension(draft.fileName);
      var file = File(
        p.join(
          dir.path,
          'csac_voice_preview_${DateTime.now().millisecondsSinceEpoch}.$extension',
        ),
      );
      await file.writeAsBytes(draft.bytes, flush: true);
      file = await linuxPlayableVoiceFile(file, fileType, strings);
      final token = DateTime.now().microsecondsSinceEpoch;
      await audioPlayer.play(
        DeviceFileSource(
          file.path,
          mimeType: p.extension(file.path).toLowerCase() == '.wav'
              ? 'audio/wav'
              : fileType?.mimeType,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        playingMessageId = null;
        voicePreviewToken = token;
        previewingVoiceDraft = true;
        voicePosition = Duration.zero;
        voiceDuration = Duration(seconds: draft.durationSeconds);
      });
      listenForAudioComplete(previewToken: token);
    } catch (err) {
      if (mounted) {
        setState(() {
          playingMessageId = null;
          voicePosition = Duration.zero;
          voiceDuration = Duration.zero;
        });
        showSnack(
          context.strings.format('Playback failed: {error}', {'error': err}),
        );
      }
    }
  }

  Future<void> pickVoiceFile() async {
    if (conversationUnavailable) {
      showSnack(context.strings.text('This group is no longer available.'));
      return;
    }
    final strings = context.strings;
    try {
      final file = await openFile(
        acceptedTypeGroups: <XTypeGroup>[
          XTypeGroup(
            label: strings.text('Audio files'),
            extensions: voiceExtensions,
            mimeTypes: const ['audio/*'],
          ),
        ],
      );
      if (file == null) {
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        showSnack(strings.text('No voice recording was saved.'));
        return;
      }
      final fileName = file.name.isEmpty ? p.basename(file.path) : file.name;
      final estimatedDuration = await estimateVoiceDuration(bytes, fileName);
      if (!mounted) {
        return;
      }
      setState(() {
        voiceDraft = _VoiceDraft(
          bytes: bytes,
          fileName: fileName,
          durationSeconds: estimatedDuration,
          sourceLabel: strings.text('Audio file'),
        );
        error = null;
      });
    } catch (err) {
      if (mounted) {
        showSnack(strings.format('Update failed: {error}', {'error': err}));
      }
    }
  }

  Future<void> pickAndSendFile() async {
    if (conversationUnavailable) {
      showSnack(context.strings.text('This group is no longer available.'));
      return;
    }
    final strings = context.strings;
    try {
      final file = await openFile();
      if (file == null) {
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) {
        return;
      }
      if (bytes.isEmpty) {
        showSnack(strings.text('Selected file is empty.'));
        return;
      }
      final name = file.name.isEmpty ? p.basename(file.path) : file.name;
      final confirmed = await _showCupertinoConfirm(
        context,
        title: strings.format('Send file: {fileName}', {'fileName': name}),
        message: strings.text('Send this file to the current chat?'),
        confirmText: 'Send',
      );
      if (!confirmed || !mounted) {
        return;
      }
      final pending = _PendingSend(
        localId: nextPendingId--,
        text: '',
        fileBytes: bytes,
        fileName: name,
      );
      setState(() {
        pendingSends.add(pending);
        error = null;
      });
      scrollToEnd();
      unawaited(performPendingSend(pending.localId));
    } catch (err) {
      if (mounted) {
        showSnack(
          strings.format('Send failed with error: {error}', {'error': err}),
        );
      }
    }
  }

  Future<int> estimateVoiceDuration(Uint8List bytes, String fileName) async {
    final strings = context.strings;
    try {
      final fileType = resolveVoiceFileType(bytes, null, fileName);
      final dir = await getTemporaryDirectory();
      final extension = fileType?.extension ?? voiceExtension(fileName);
      var file = File(
        p.join(
          dir.path,
          'csac_voice_probe_${DateTime.now().microsecondsSinceEpoch}.$extension',
        ),
      );
      await file.writeAsBytes(bytes, flush: true);
      file = await linuxPlayableVoiceFile(file, fileType, strings);
      final player = AudioPlayer();
      try {
        await player.setSource(
          DeviceFileSource(
            file.path,
            mimeType: p.extension(file.path).toLowerCase() == '.wav'
                ? 'audio/wav'
                : fileType?.mimeType,
          ),
        );
        final duration = await player.getDuration();
        return duration?.inSeconds.clamp(0, 600) ?? 0;
      } finally {
        await player.dispose();
        unawaited(file.delete().then<void>((_) {}).catchError((_) {}));
      }
    } catch (_) {
      return 0;
    }
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
      if (pending.hasVoice) {
        await widget.state.client.sendVoiceMessage(
          widget.conversation,
          pending.voiceBytes!,
          pending.voiceName,
          durationSeconds: pending.voiceDuration,
        );
      } else if (pending.hasFile) {
        await widget.state.client.sendFileMessage(
          widget.conversation,
          pending.fileBytes!,
          pending.fileName,
        );
      } else if (pending.hasImage) {
        await widget.state.client.sendImageMessage(
          widget.conversation,
          pending.imageBytes!,
          pending.imageName,
          caption: pending.text,
          replyTo: pending.replyTo,
          mentionUids: pending.mentionUids,
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
      setState(() {
        pendingSends.removeWhere((item) => item.localId == localId);
      });
      await widget.state.markConversationRead(widget.conversation);
      await refresh(silent: true);
      scrollToEnd();
    } catch (err) {
      if (!mounted) {
        return;
      }
      final message = sendFailureMessage(err);
      if (isGroupUnavailableError(err)) {
        replacePendingSend(
          localId,
          (item) =>
              item.copyWith(status: _PendingSendStatus.failed, error: message),
        );
        await handleUnavailableConversation();
        return;
      }
      replacePendingSend(
        localId,
        (item) =>
            item.copyWith(status: _PendingSendStatus.failed, error: message),
      );
      if (classifySendRestriction(err) != CsacSendRestriction.none) {
        showSnack(message);
      }
    }
  }

  Future<void> sendPatTo(ChatMessage message) async {
    if (widget.conversation.type != ConversationType.group ||
        message.senderId <= 0) {
      return;
    }
    try {
      await widget.state.sendPatMessage(widget.conversation, message.senderId);
      if (!mounted) return;
      await refresh(silent: true);
      scrollToEnd();
    } catch (err) {
      if (mounted) {
        showSnack(
          context.strings.format('Send failed: {error}', {'error': err}),
        );
      }
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

  void openChatSearch() {
    setState(() => searchMode = true);
  }

  void openMediaDrawer() {
    _csacPush<void>(
      context,
      (_) => ConversationMediaScreen(
        state: widget.state,
        conversation: widget.conversation,
        onOpenMessage: (messageId) {
          final navigator = Navigator.of(context);
          navigator.pop();
          unawaited(
            ensureMessagesAround(messageId).then((_) {
              if (mounted) {
                scrollToMessage(messageId);
              }
            }),
          );
        },
      ),
    );
  }

  void openChatArchive() {
    _csacPush<void>(
      context,
      (_) => ChatArchiveScreen(
        state: widget.state,
        conversation: widget.conversation,
      ),
    );
  }

  void closeChatSearch() {
    chatSearchTimer?.cancel();
    chatSearch.clear();
    setState(() {
      searchMode = false;
      chatSearching = false;
      chatSearchResultIds.clear();
      chatSearchIndex = -1;
    });
  }

  void scheduleChatSearch(String value) {
    chatSearchTimer?.cancel();
    chatSearchTimer = Timer(const Duration(milliseconds: 220), () {
      unawaited(runChatSearch(value));
    });
  }

  Future<void> runChatSearch(String value) async {
    final query = value.trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        chatSearching = false;
        chatSearchResultIds.clear();
        chatSearchIndex = -1;
      });
      return;
    }
    setState(() => chatSearching = true);
    final loaded = await widget.state.searchConversationMessages(
      widget.conversation,
      query,
    );
    if (!mounted || chatSearch.text.trim() != query) {
      return;
    }
    setState(() {
      chatSearchResultIds
        ..clear()
        ..addAll(loaded.map((message) => message.id));
      chatSearchIndex = chatSearchResultIds.isEmpty ? -1 : 0;
      chatSearching = false;
    });
    final id = currentSearchMessageId;
    if (id != null) {
      await ensureMessagesAround(id);
      scrollToMessage(id);
    }
  }

  Future<void> ensureMessagesAround(int messageId) async {
    if (messages.any((message) => message.id == messageId)) {
      return;
    }
    try {
      final loaded = await widget.state.loadCachedMessagesAround(
        widget.conversation,
        messageId,
      );
      if (!mounted || loaded.isEmpty) {
        return;
      }
      final merged = mergeChatMessages(messages, loaded);
      setState(() {
        messages
          ..clear()
          ..addAll(merged);
      });
    } catch (_) {
      // Search navigation should stay responsive even if a cache window fails.
    }
  }

  Future<void> moveChatSearch(int delta) async {
    if (chatSearchResultIds.isEmpty) {
      return;
    }
    final next = (chatSearchIndex + delta).clamp(
      0,
      chatSearchResultIds.length - 1,
    );
    if (next == chatSearchIndex) {
      return;
    }
    setState(() => chatSearchIndex = next);
    final id = currentSearchMessageId;
    if (id != null) {
      await ensureMessagesAround(id);
      scrollToMessage(id);
    }
  }

  void showSnack(String message) {
    if (!mounted) {
      return;
    }
    _showCupertinoToast(context, message);
  }

  Future<void> toggleVoicePlayback(ChatMessage message) async {
    if (message.voiceUrl.isEmpty) {
      return;
    }
    try {
      if (voicePreviewToken != null) {
        setState(() {
          voicePreviewToken = null;
          previewingVoiceDraft = false;
        });
      }
      if (playingMessageId == message.id) {
        await audioCompleteSubscription?.cancel();
        audioCompleteSubscription = null;
        await audioPlayer.pause();
        if (mounted) {
          setState(() {
            playingMessageId = null;
            voicePosition = Duration.zero;
            voiceDuration = Duration.zero;
          });
        }
        return;
      }
      await audioCompleteSubscription?.cancel();
      audioCompleteSubscription = null;
      await audioPlayer.stop();
      final source = await localVoiceSource(message.voiceUrl);
      await audioPlayer.play(source);
      if (!mounted) {
        return;
      }
      setState(() {
        playingMessageId = message.id;
        voicePreviewToken = null;
        previewingVoiceDraft = false;
        voicePosition = Duration.zero;
        voiceDuration = Duration(seconds: message.voiceDuration);
      });
      listenForAudioComplete(messageId: message.id);
    } catch (err) {
      if (mounted) {
        showSnack(
          context.strings.format('Playback failed: {error}', {'error': err}),
        );
      }
    }
  }

  double activeVoiceProgress(ChatMessage message) {
    final duration = voiceDuration.inMilliseconds > 0
        ? voiceDuration
        : Duration(seconds: message.voiceDuration);
    if (duration.inMilliseconds <= 0) {
      return playingMessageId == message.id ? 0.35 : 0;
    }
    return voicePosition.inMilliseconds / duration.inMilliseconds;
  }

  ChatMessage? nextVoiceMessageAfter(int messageId) {
    final currentIndex = messages.indexWhere(
      (message) => message.id == messageId,
    );
    if (currentIndex < 0) {
      return null;
    }
    for (var i = currentIndex + 1; i < messages.length; i++) {
      final message = messages[i];
      if (message.voiceUrl.isNotEmpty) {
        return message;
      }
    }
    return null;
  }

  Future<Source> localVoiceSource(String url) async {
    final strings = context.strings;
    final response = await widget.state.client.downloadAsset(
      url,
      accept: 'audio/*, application/octet-stream, */*',
    );
    final bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      throw Exception(strings.text('Empty voice file'));
    }
    final fileType = detectVoiceFileType(bytes);
    if (fileType == null) {
      final fallbackType = resolveVoiceDownloadFallbackType(
        response,
        bytes,
        url,
      );
      if (fallbackType != null) {
        return localVoiceSourceFromBytes(bytes, fallbackType, strings, url);
      }
      throw Exception(
        strings.format(
          'Downloaded voice is not a playable audio file: {detail}',
          {'detail': voiceDownloadDiagnostic(response, bytes)},
        ),
      );
    }
    return localVoiceSourceFromBytes(bytes, fileType, strings, url);
  }

  Future<Source> localVoiceSourceFromBytes(
    Uint8List bytes,
    _VoiceFileType fileType,
    CsacStrings strings,
    String url,
  ) async {
    final dir = await getTemporaryDirectory();
    final cacheKey = Object.hash(url, bytes.length).toUnsigned(32);
    var file = File(
      p.join(dir.path, 'csac_voice_play_$cacheKey.${fileType.extension}'),
    );
    await file.writeAsBytes(bytes, flush: true);
    file = await linuxPlayableVoiceFile(file, fileType, strings);
    return DeviceFileSource(
      file.path,
      mimeType: p.extension(file.path).toLowerCase() == '.wav'
          ? 'audio/wav'
          : fileType.mimeType,
    );
  }

  _VoiceFileType? resolveVoiceDownloadFallbackType(
    http.Response response,
    Uint8List bytes,
    String url,
  ) {
    if (downloadLooksLikeTextOrHtml(bytes)) {
      return null;
    }
    final fromContentType = voiceFileTypeForMime(
      response.headers['content-type'],
    );
    if (fromContentType != null) {
      return fromContentType;
    }
    final mimeType = voiceMimeType(url);
    if (mimeType == null) {
      return null;
    }
    final extension = voiceExtension(url);
    if (extension == 'webm') {
      return null;
    }
    return _VoiceFileType(extension, mimeType);
  }

  bool downloadLooksLikeTextOrHtml(Uint8List bytes) {
    final head = bytes.take(256).toList();
    final sample = utf8.decode(head, allowMalformed: true);
    final trimmed = sample.trimLeft().toLowerCase();
    if (trimmed.startsWith('<!doctype html') ||
        trimmed.startsWith('<html') ||
        trimmed.startsWith('<script')) {
      return true;
    }
    final mostlyText =
        head.isNotEmpty &&
        head.every((byte) {
          return byte == 0x09 || byte == 0x0a || byte == 0x0d || byte >= 0x20;
        });
    return mostlyText &&
        (trimmed.startsWith('{') ||
            trimmed.startsWith('[') ||
            trimmed.contains('<html') ||
            trimmed.contains('error') ||
            trimmed.contains('exception'));
  }

  Future<File> linuxPlayableVoiceFile(
    File source,
    _VoiceFileType? type,
    CsacStrings strings,
  ) async {
    if (!Platform.isLinux ||
        type?.extension == 'wav' ||
        !widget.state.preferences.chat.linuxFfmpegVoiceFallback) {
      return source;
    }
    final ffmpeg = await findExecutableOnPath('ffmpeg');
    if (ffmpeg == null) {
      throw Exception(
        strings.text('ffmpeg is required to play this voice on Linux.'),
      );
    }
    final target = File('${source.path}.wav');
    if (await target.exists()) {
      return target;
    }
    final result = await Process.run(ffmpeg, [
      '-y',
      '-hide_banner',
      '-loglevel',
      'error',
      '-i',
      source.path,
      '-acodec',
      'pcm_s16le',
      '-ac',
      '1',
      '-ar',
      '44100',
      target.path,
    ]);
    if (result.exitCode == 0 && await target.exists()) {
      return target;
    }
    final detail = '${result.stderr}'.trim();
    throw Exception(
      strings.format('Voice conversion failed: {error}', {
        'error': detail.isEmpty ? 'ffmpeg exit ${result.exitCode}' : detail,
      }),
    );
  }

  Future<String?> findExecutableOnPath(String executable) async {
    final directories = <String>{
      ...?Platform.environment['PATH']?.split(':'),
      '/usr/bin',
      '/usr/local/bin',
      '/bin',
      '/snap/bin',
      '/var/lib/flatpak/exports/bin',
    };
    for (final directory in directories) {
      if (directory.trim().isEmpty) {
        continue;
      }
      final candidate = File(p.join(directory, executable));
      if (await candidate.exists()) {
        return candidate.path;
      }
    }
    return null;
  }

  _VoiceFileType? resolveVoiceFileType(
    Uint8List bytes,
    String? contentType,
    String url,
  ) {
    final detected = detectVoiceFileType(bytes);
    if (detected != null) {
      return detected;
    }
    final fromContentType = voiceFileTypeForMime(contentType);
    if (fromContentType != null) {
      return fromContentType;
    }
    final mimeType = voiceMimeType(url);
    final extension = voiceExtension(url);
    if (mimeType == null) {
      return null;
    }
    return _VoiceFileType(extension, mimeType);
  }

  String voiceDownloadDiagnostic(http.Response response, Uint8List bytes) {
    final contentType = response.headers['content-type'] ?? 'unknown';
    final sample = bytes
        .take(64)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join(' ');
    return 'HTTP ${response.statusCode}, content-type: $contentType, bytes: ${bytes.length}, head: $sample';
  }

  _VoiceFileType? detectVoiceFileType(Uint8List bytes) {
    bool startsWith(List<int> header, [int offset = 0]) {
      if (bytes.length < offset + header.length) {
        return false;
      }
      for (var i = 0; i < header.length; i++) {
        if (bytes[offset + i] != header[i]) {
          return false;
        }
      }
      return true;
    }

    if (startsWith(const [0x52, 0x49, 0x46, 0x46]) &&
        startsWith(const [0x57, 0x41, 0x56, 0x45], 8)) {
      return const _VoiceFileType('wav', 'audio/wav');
    }
    if (startsWith(const [0x46, 0x4f, 0x52, 0x4d]) &&
        (startsWith(const [0x41, 0x49, 0x46, 0x46], 8) ||
            startsWith(const [0x41, 0x49, 0x46, 0x43], 8))) {
      return const _VoiceFileType('aiff', 'audio/aiff');
    }
    if (startsWith(const [0x66, 0x4c, 0x61, 0x43])) {
      return const _VoiceFileType('flac', 'audio/flac');
    }
    if (startsWith(const [0x4f, 0x67, 0x67, 0x53])) {
      return const _VoiceFileType('ogg', 'audio/ogg');
    }
    if (startsWith(const [0x1a, 0x45, 0xdf, 0xa3])) {
      return const _VoiceFileType('webm', 'audio/webm');
    }
    if (bytes.length >= 2 && bytes[0] == 0xff && (bytes[1] & 0xf0) == 0xf0) {
      return const _VoiceFileType('aac', 'audio/aac');
    }
    if (startsWith(const [0x49, 0x44, 0x33]) ||
        (bytes.length >= 2 && bytes[0] == 0xff && (bytes[1] & 0xe0) == 0xe0)) {
      return const _VoiceFileType('mp3', 'audio/mpeg');
    }
    if (startsWith(const [0x23, 0x21, 0x41, 0x4d, 0x52])) {
      return const _VoiceFileType('amr', 'audio/amr');
    }
    if (startsWith(const [0x66, 0x74, 0x79, 0x70], 4)) {
      final brand = String.fromCharCodes(
        bytes.sublist(8, min(bytes.length, 12)),
      ).toLowerCase();
      if (brand.startsWith('3g')) {
        if (brand.startsWith('3g2')) {
          return const _VoiceFileType('3g2', 'audio/3gpp2');
        }
        return const _VoiceFileType('3gp', 'audio/3gpp');
      }
      return const _VoiceFileType('m4a', 'audio/mp4');
    }
    if (startsWith(const [0x63, 0x61, 0x66, 0x66])) {
      return const _VoiceFileType('caf', 'audio/x-caf');
    }
    return null;
  }

  _VoiceFileType? voiceFileTypeForMime(String? contentType) {
    final mimeType = contentType?.split(';').first.trim().toLowerCase() ?? '';
    switch (mimeType) {
      case 'audio/mp4':
      case 'audio/x-m4a':
      case 'audio/m4a':
        return const _VoiceFileType('m4a', 'audio/mp4');
      case 'audio/wav':
      case 'audio/x-wav':
      case 'audio/vnd.wave':
        return const _VoiceFileType('wav', 'audio/wav');
      case 'audio/ogg':
      case 'audio/opus':
      case 'application/ogg':
        return const _VoiceFileType('ogg', 'audio/ogg');
      case 'audio/flac':
      case 'audio/x-flac':
        return const _VoiceFileType('flac', 'audio/flac');
      case 'audio/webm':
        return const _VoiceFileType('webm', 'audio/webm');
      case 'audio/mpeg':
      case 'audio/mp3':
        return const _VoiceFileType('mp3', 'audio/mpeg');
      case 'audio/aac':
      case 'audio/aacp':
        return const _VoiceFileType('aac', 'audio/aac');
      case 'audio/3gpp':
      case 'audio/3gp':
        return const _VoiceFileType('3gp', 'audio/3gpp');
      case 'audio/3gpp2':
      case 'audio/3g2':
        return const _VoiceFileType('3g2', 'audio/3gpp2');
      case 'audio/amr':
      case 'audio/x-amr':
        return const _VoiceFileType('amr', 'audio/amr');
      case 'audio/x-caf':
      case 'audio/caf':
        return const _VoiceFileType('caf', 'audio/x-caf');
      case 'audio/aiff':
      case 'audio/x-aiff':
        return const _VoiceFileType('aiff', 'audio/aiff');
    }
    return null;
  }

  String voiceExtension(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    final extension = p.extension(path).replaceFirst('.', '');
    if (extension.isNotEmpty && extension.length <= 5) {
      return extension;
    }
    return 'm4a';
  }

  String? voiceMimeType(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    if (path.endsWith('.m4a') || path.endsWith('.mp4')) {
      return 'audio/mp4';
    }
    if (path.endsWith('.aac')) {
      return 'audio/aac';
    }
    if (path.endsWith('.wav')) {
      return 'audio/wav';
    }
    if (path.endsWith('.ogg')) {
      return 'audio/ogg';
    }
    if (path.endsWith('.opus')) {
      return 'audio/ogg';
    }
    if (path.endsWith('.flac')) {
      return 'audio/flac';
    }
    if (path.endsWith('.webm')) {
      return 'audio/webm';
    }
    if (path.endsWith('.mp3') || path.endsWith('.mpeg')) {
      return 'audio/mpeg';
    }
    if (path.endsWith('.3gp') || path.endsWith('.3gpp')) {
      return 'audio/3gpp';
    }
    if (path.endsWith('.3g2') || path.endsWith('.3gpp2')) {
      return 'audio/3gpp2';
    }
    if (path.endsWith('.amr')) {
      return 'audio/amr';
    }
    if (path.endsWith('.caf')) {
      return 'audio/x-caf';
    }
    if (path.endsWith('.aif') || path.endsWith('.aiff')) {
      return 'audio/aiff';
    }
    return null;
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

  Future<void> chooseMentionTargets({int? triggerOffset}) async {
    if (widget.conversation.type != ConversationType.group) {
      return;
    }
    if (mentionPickerOpen) {
      return;
    }
    mentionPickerOpen = true;
    try {
      final members = await widget.state.loadGroupMembers(
        widget.conversation.id,
      );
      if (!mounted) {
        return;
      }
      final selected = await showCupertinoModalPopup<List<GroupMember>>(
        context: context,
        builder: (context) => _MentionPickerSheet(
          members: members,
          selectedUids: mentionTargets.map((member) => member.uid).toSet(),
        ),
      );
      if (selected == null || !mounted) {
        return;
      }
      if (triggerOffset != null) {
        replaceMentionTrigger(triggerOffset, selected);
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
    } finally {
      mentionPickerOpen = false;
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
    final recalledBody = context.strings.text('Message recalled');
    try {
      await widget.state.recallMessage(widget.conversation, message.id);
      final recalled = message.copyWith(
        body: recalledBody,
        imageUrl: '',
        voiceUrl: '',
        fileUrl: '',
        canRecall: false,
        isRecalled: true,
        recallStatus: message.senderId == widget.state.user?.uid ? 1 : 2,
      );
      replaceMessageLocally(recalled);
      await widget.state.cache.saveMessages(widget.conversation, [recalled]);
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
    return _csacPush<void>(
      context,
      (_) => EssenceMessagesScreen(
        state: widget.state,
        conversation: widget.conversation,
      ),
    );
  }

  Future<void> showMessageActions(ChatMessage message, bool mine) async {
    final action = await showCupertinoModalPopup<_MessageAction>(
      context: context,
      builder: (context) => _CsacBlurredPopup(
        child: _MessageActionSheet(
          message: message,
          canRecall: !message.isRecalled && (message.canRecall || mine),
          canEssence:
              widget.conversation.type == ConversationType.group &&
              !message.isRecalled,
        ),
      ).csacPopupEnter(),
    );
    if (action == null || !mounted) {
      return;
    }
    switch (action) {
      case _MessageAction.select:
        enterSelection(message);
        break;
      case _MessageAction.copyText:
        Clipboard.setData(
          ClipboardData(
            text:
                '#${message.id} ${message.sender}\n${message.time}\n\n${message.body}',
          ),
        );
        _showCupertinoToast(context, context.strings.text('Message copied'));
        break;
      case _MessageAction.copyImage:
        final link = message.imageUrl.isNotEmpty
            ? message.imageUrl
            : message.voiceUrl.isNotEmpty
            ? message.voiceUrl
            : message.fileUrl;
        Clipboard.setData(ClipboardData(text: link));
        _showCupertinoToast(context, context.strings.text('Link copied.'));
        break;
      case _MessageAction.openImage:
        if (message.imageUrl.isNotEmpty) {
          showImagePreview(context, message.imageUrl);
        } else {
          final link = message.voiceUrl.isNotEmpty
              ? message.voiceUrl
              : message.fileUrl;
          await launchUrl(
            Uri.parse(link),
            mode: LaunchMode.externalApplication,
          );
        }
        break;
      case _MessageAction.downloadImage:
        if (message.imageUrl.isNotEmpty) {
          await downloadImage(context, message.imageUrl);
        } else {
          final item = ConversationMediaItem(
            kind: message.voiceUrl.isNotEmpty
                ? ConversationMediaKind.voice
                : ConversationMediaKind.file,
            message: message,
            url: message.voiceUrl.isNotEmpty
                ? message.voiceUrl
                : message.fileUrl,
            title: message.fileName,
          );
          await saveMediaItem(context, widget.state, item);
        }
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
      case _MessageAction.report:
        await showReportDialog(
          context: context,
          state: widget.state,
          type: widget.conversation.type == ConversationType.group
              ? 'group'
              : 'user',
          title: context.strings.text('Report message'),
          uid: message.senderId,
          rid: widget.conversation.type == ConversationType.group
              ? widget.conversation.id
              : 0,
          messageId: message.id,
          nickname: message.sender,
          roomName: widget.conversation.type == ConversationType.group
              ? widget.conversation.name
              : '',
        );
        break;
    }
  }

  void openConversationDetails() {
    if (widget.conversation.type == ConversationType.private) {
      openUserProfile(context, widget.state, widget.conversation.id);
      return;
    }
    _csacPush<void>(
      context,
      (_) => ConversationDetailScreen(
        state: widget.state,
        conversation: widget.conversation,
      ),
    ).then((_) => loadGroupAnnouncement());
  }

  Future<void> showChatBarMenu() async {
    final strings = context.strings;
    final action = await showCupertinoModalPopup<_ChatBarMenuAction>(
      context: context,
      builder: (context) => _CsacBlurredPopup(
        child: CupertinoActionSheet(
          title: Text(strings.text('More actions')),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () =>
                  Navigator.of(context).pop(_ChatBarMenuAction.search),
              child: Text(strings.text('Search')),
            ),
            CupertinoActionSheetAction(
              onPressed: () =>
                  Navigator.of(context).pop(_ChatBarMenuAction.refresh),
              child: Text(strings.text('Refresh')),
            ),
            if (widget.conversation.type == ConversationType.group)
              CupertinoActionSheetAction(
                onPressed: () =>
                    Navigator.of(context).pop(_ChatBarMenuAction.essence),
                child: Text(strings.text('Essence')),
              ),
            CupertinoActionSheetAction(
              onPressed: () =>
                  Navigator.of(context).pop(_ChatBarMenuAction.details),
              child: Text(strings.text('Details')),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.text('Cancel')),
          ),
        ),
      ).csacPopupEnter(),
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _ChatBarMenuAction.search:
        openChatSearch();
        break;
      case _ChatBarMenuAction.refresh:
        await reloadConversationFromNetwork(showLoading: true);
        break;
      case _ChatBarMenuAction.essence:
        await openEssenceList();
        break;
      case _ChatBarMenuAction.details:
        openConversationDetails();
        break;
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
    _showCupertinoToast(
      context,
      context.strings.text('Selected messages copied.'),
    );
  }

  Future<void> deleteSelectedLocalMessages() async {
    final selected = selectedMessages;
    if (selected.isEmpty) {
      return;
    }
    final confirmed = await _showCupertinoConfirm(
      context,
      title: context.strings.text('Delete selected local messages?'),
      message: context.strings.text(
        'Only local cached copies will be removed.',
      ),
      confirmText: context.strings.text('Delete'),
      isDestructive: true,
    );
    if (!confirmed || !mounted) {
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
      _showCupertinoToast(
        context,
        context.strings.text('Local messages deleted.'),
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
    final target = await showCupertinoModalPopup<Conversation>(
      context: context,
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
      _showCupertinoToast(context, context.strings.text('Forwarded.'));
    } catch (err) {
      if (!mounted) {
        return;
      }
      final message = sendFailureMessage(err);
      if (target.type == ConversationType.group &&
          isGroupUnavailableError(err)) {
        await widget.state.removeConversationLocal(target);
        if (!mounted) {
          return;
        }
      }
      _showCupertinoToast(
        context,
        context.strings.format('Forward failed: {error}', {'error': message}),
      );
    }
  }

  String formatMessageForCopy(ChatMessage message) {
    return [
      '#${message.id} ${message.sender}',
      if (message.time.isNotEmpty) message.time,
      if (message.body.trim().isNotEmpty) message.body.trim(),
      if (message.imageUrl.isNotEmpty) message.imageUrl,
      if (message.voiceUrl.isNotEmpty) message.voiceUrl,
      if (message.fileUrl.isNotEmpty) message.fileUrl,
    ].join('\n');
  }

  String formatMessageForForward(ChatMessage message) {
    return [
      '${message.sender}:',
      if (message.body.trim().isNotEmpty) message.body.trim(),
      if (message.imageUrl.isNotEmpty)
        context.strings.format('Image: {url}', {'url': message.imageUrl}),
      if (message.voiceUrl.isNotEmpty)
        context.strings.format('Voice: {url}', {'url': message.voiceUrl}),
      if (message.fileUrl.isNotEmpty)
        context.strings.format('File: {url}', {'url': message.fileUrl}),
    ].join('\n');
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

  void jumpToEndAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!scroll.hasClients) {
          return;
        }
        scroll.jumpTo(scroll.position.maxScrollExtent);
      });
    });
  }

  void scrollAfterInitialLoad() {
    if (widget.focusMessageId == null) {
      jumpToEndAfterLayout();
      return;
    }
    scrollAfterLoad();
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
        return;
      }
      revealMessage(keyContext, duration: const Duration(milliseconds: 280));
    });
  }

  void scrollToMessage(int messageId) {
    final keyContext = itemKeys[messageId]?.currentContext;
    if (keyContext == null) {
      _showCupertinoToast(
        context,
        context.strings.text('Referenced message is not loaded.'),
      );
      return;
    }
    revealMessage(keyContext, duration: const Duration(milliseconds: 260));
  }

  void revealMessage(BuildContext keyContext, {required Duration duration}) {
    Scrollable.ensureVisible(
      keyContext,
      duration: duration,
      curve: Curves.easeOut,
      alignment: 0.18,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  }

  void jumpToFirstUnread() {
    final id = firstUnreadMessageId;
    if (id == null) {
      return;
    }
    scrollToMessage(id);
  }

  String displayMessageTime(ChatMessage message, {required bool showSeconds}) {
    final raw = message.rawTime.isNotEmpty ? message.rawTime : message.time;
    return humanReadableTimestamp(raw, showSeconds: showSeconds);
  }

  Future<void> showComposeMenu() async {
    final strings = context.strings;
    final action = await _showAdaptiveActionSheet<_ComposeMenuAction>(
      context,
      title: strings.text('More actions'),
      actions: [
        const _AdaptiveSheetAction(
          value: _ComposeMenuAction.image,
          label: 'Send image',
          icon: CupertinoIcons.photo,
        ),
        if (widget.conversation.type == ConversationType.group)
          const _AdaptiveSheetAction(
            value: _ComposeMenuAction.mention,
            label: '@',
            icon: CupertinoIcons.at,
          ),
        _AdaptiveSheetAction(
          value: _ComposeMenuAction.recordVoice,
          label: recording ? 'Stop recording' : 'Record voice',
          icon: recording ? CupertinoIcons.stop_circle : CupertinoIcons.mic,
        ),
        const _AdaptiveSheetAction(
          value: _ComposeMenuAction.audioFile,
          label: 'Choose audio file',
          icon: CupertinoIcons.music_note,
        ),
        const _AdaptiveSheetAction(
          value: _ComposeMenuAction.genericFile,
          label: 'Send file',
          icon: CupertinoIcons.doc,
        ),
        const _AdaptiveSheetAction(
          value: _ComposeMenuAction.media,
          label: 'Media drawer',
          icon: CupertinoIcons.collections,
        ),
        const _AdaptiveSheetAction(
          value: _ComposeMenuAction.export,
          label: 'Create chat archive',
          icon: CupertinoIcons.archivebox_fill,
        ),
      ],
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _ComposeMenuAction.image:
        await pickAndSendImage();
        break;
      case _ComposeMenuAction.recordVoice:
        await toggleRecording();
        break;
      case _ComposeMenuAction.audioFile:
        await pickVoiceFile();
        break;
      case _ComposeMenuAction.genericFile:
        await pickAndSendFile();
        break;
      case _ComposeMenuAction.media:
        openMediaDrawer();
        break;
      case _ComposeMenuAction.export:
        openChatArchive();
        break;
      case _ComposeMenuAction.mention:
        await chooseMentionTargets();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final announcement = groupProfile?.notice.trim() ?? '';
    final showEmpty =
        !loading &&
        messages.isEmpty &&
        pendingSends.isEmpty &&
        !conversationUnavailable;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 600;
    final composeEnabled = !conversationUnavailable;
    final chatPrefs = widget.state.preferences.chat;
    final backgroundImagePath = chatPrefs.backgroundImagePath.trim();
    final backgroundColor = chatPrefs.backgroundColorValue == 0
        ? colors.systemBackground
        : Color(0xff000000 | (chatPrefs.backgroundColorValue & 0x00ffffff));
    return CupertinoPageScaffold(
      backgroundColor: backgroundColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: colors.navBarBackground,
        border: null,
        automaticallyImplyLeading: !widget.embedded && !selectionMode,
        leading: selectionMode
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: clearSelection,
                child: const Icon(CupertinoIcons.xmark),
              )
            : null,
        middle: selectionMode
            ? Text(
                strings.format('{count} messages selected', {
                  'count': selectedMessageIds.length,
                }),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: openConversationDetails,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!widget.embedded) ...[
                      _ConversationAvatarHero(
                        conversation: widget.conversation,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: _ConversationTitleHero(
                        conversation: widget.conversation,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: colors.label,
                        ),
                        enabled: !widget.embedded,
                      ),
                    ),
                  ],
                ),
              ),
        trailing: selectionMode
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    onPressed: copySelectedMessages,
                    child: const Icon(CupertinoIcons.doc_on_doc, size: 20),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    onPressed: forwardSelectedMessages,
                    child: const Icon(
                      CupertinoIcons.arrowshape_turn_up_right,
                      size: 20,
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    onPressed: deleteSelectedLocalMessages,
                    child: const Icon(CupertinoIcons.trash, size: 20),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (offline)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(CupertinoIcons.wifi_slash, size: 20),
                    ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: showChatBarMenu,
                    child: const Icon(CupertinoIcons.ellipsis_circle, size: 22),
                  ),
                ],
              ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            if (error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: colors.destructive.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: colors.destructive,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size.square(28),
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
            if (announcement.isNotEmpty)
              _GroupAnnouncementBar(
                announcement: announcement,
                onTap: openConversationDetails,
              ),
            if (searchMode)
              _ChatSearchBar(
                controller: chatSearch,
                searching: chatSearching,
                current: chatSearchIndex < 0 ? 0 : chatSearchIndex + 1,
                total: chatSearchResultIds.length,
                onChanged: scheduleChatSearch,
                onPrevious: () => moveChatSearch(-1),
                onNext: () => moveChatSearch(1),
                onClose: closeChatSearch,
              ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: chatPrefs.tapToDismissKeyboard
                    ? () => FocusScope.of(context).unfocus()
                    : null,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _ConversationSurfaceHero(
                        conversation: widget.conversation,
                        enabled: false,
                        child: _ChatBackground(
                          color: backgroundColor,
                          imagePath: backgroundImagePath,
                        ),
                      ),
                    ),
                    conversationUnavailable
                        ? _EmptyPanel(
                            message: strings.text(
                              'This group is no longer available.',
                            ),
                          )
                        : loading
                        ? const Center(child: CupertinoActivityIndicator())
                        : showEmpty
                        ? _EmptyPanel(message: strings.text('No messages.'))
                        : ListView.builder(
                            controller: scroll,
                            padding: EdgeInsets.fromLTRB(
                              compact ? 10 : 28,
                              compact ? 10 : 18,
                              compact ? 10 : 28,
                              compact ? 72 : 84,
                            ),
                            itemCount: messages.length + pendingSends.length,
                            itemBuilder: (context, index) {
                              if (index >= messages.length) {
                                final pending =
                                    pendingSends[index - messages.length];
                                return _PendingMessageBubble(
                                  pending: pending,
                                  onRetry: () =>
                                      retryPendingSend(pending.localId),
                                );
                              }
                              final message = messages[index];
                              final mine =
                                  widget.state.user?.uid == message.senderId;
                              final selected = selectedMessageIds.contains(
                                message.id,
                              );
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
                                avatarUrl: mine
                                    ? widget.state.user?.avatar ?? ''
                                    : message.senderAvatar,
                                avatarName: mine
                                    ? widget.state.user?.nickname ??
                                          widget.state.user?.username ??
                                          message.sender
                                    : message.sender,
                                displayTime: displayMessageTime(
                                  message,
                                  showSeconds: chatPrefs.showSeconds,
                                ),
                                compactLayout: chatPrefs.compactBubbles,
                                showSenderLine: chatPrefs.showSenderName,
                                showMemberMeta:
                                    widget.conversation.type ==
                                    ConversationType.group,
                                animateEntry: animateMessageEntries,
                                showReadStatus:
                                    widget.conversation.type ==
                                    ConversationType.private,
                                focused: widget.focusMessageId == message.id,
                                searchFocused:
                                    currentSearchMessageId == message.id,
                                searchQuery: searchMode ? chatSearch.text : '',
                                selected: selected,
                                selectionMode: selectionMode,
                                onTap: selectionMode
                                    ? () => toggleMessageSelection(message)
                                    : null,
                                onDoubleTap: selectionMode
                                    ? null
                                    : () => sendPatTo(message),
                                onLongPress: selectionMode
                                    ? null
                                    : () => showMessageActions(message, mine),
                                onSwipeReply: selectionMode
                                    ? null
                                    : () => setReplyTarget(message),
                                onReplyTap: message.replyTo > 0
                                    ? () => scrollToMessage(message.replyTo)
                                    : null,
                                onImageTap: message.imageUrl.isEmpty
                                    ? null
                                    : () => showImagePreview(
                                        context,
                                        message.imageUrl,
                                      ),
                                onFileTap: message.fileUrl.isEmpty
                                    ? null
                                    : () => launchUrl(
                                        Uri.parse(message.fileUrl),
                                        mode: LaunchMode.externalApplication,
                                      ),
                                onVoiceTap: message.voiceUrl.isEmpty
                                    ? null
                                    : () => toggleVoicePlayback(message),
                                voiceProgress: playingMessageId == message.id
                                    ? activeVoiceProgress(message)
                                    : 0,
                                playingVoice: playingMessageId == message.id,
                              );
                            },
                          ),
                    Positioned(
                      top: 12,
                      left: compact ? 12 : 28,
                      right: compact ? 12 : 28,
                      child: AnimatedSwitcher(
                        duration: _csacMotionMedium,
                        child: showEntryHint && !selectionMode
                            ? _ChatEntryHint(
                                key: const ValueKey('chat-entry-hint'),
                                onClose: () =>
                                    setState(() => showEntryHint = false),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    Positioned(
                      top: showEntryHint && !selectionMode ? 72 : 56,
                      right: compact ? 12 : 28,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: canJumpToFirstUnread
                            ? _FloatingChatButton(
                                key: const ValueKey('firstUnread'),
                                icon: CupertinoIcons.arrow_down_to_line,
                                label: strings.text('Unread'),
                                onPressed: jumpToFirstUnread,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    Positioned(
                      right: compact ? 12 : 28,
                      bottom: 12,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: showJumpToBottom
                            ? _FloatingChatButton(
                                key: const ValueKey('bottom'),
                                icon: CupertinoIcons.chevron_down,
                                onPressed: scrollToEnd,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.cardBackground.withValues(alpha: 0.85),
                    border: Border(
                      top: BorderSide(color: colors.separator, width: 0.5),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 10 : 18,
                        8,
                        compact ? 10 : 18,
                        compact ? 10 : 14,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (replyTarget != null || mentionTargets.isNotEmpty)
                            _ComposeTargetsBar(
                              replyTarget: replyTarget,
                              mentions: mentionTargets,
                              onClearReply: () =>
                                  setState(() => replyTarget = null),
                              onClearMentions: () =>
                                  setState(() => mentionTargets.clear()),
                            ),
                          if (recording)
                            _RecordingCapsule(
                              seconds: recordingElapsedSeconds,
                              onCancel: cancelRecording,
                              onDone: stopRecordingToDraft,
                            ),
                          if (voiceDraft != null && !recording)
                            _VoiceDraftCard(
                              draft: voiceDraft!,
                              playing: previewingVoiceDraft,
                              progress: voiceDraftProgress,
                              onPreview: previewVoiceDraft,
                              onDiscard: discardVoiceDraft,
                              onSend: sendVoiceDraft,
                            ),
                          Row(
                            children: [
                              _ComposeIconButton(
                                icon: recording
                                    ? CupertinoIcons.stop_circle_fill
                                    : CupertinoIcons.plus,
                                color: recording ? colors.destructive : null,
                                busy: pickingImage,
                                onPressed: composeEnabled
                                    ? showComposeMenu
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: CupertinoTextField(
                                  controller: input,
                                  minLines: 1,
                                  maxLines: 4,
                                  textInputAction: TextInputAction.send,
                                  enabled: composeEnabled,
                                  onSubmitted: composeEnabled
                                      ? (_) => send()
                                      : null,
                                  placeholder: composeEnabled
                                      ? strings.text('Message')
                                      : strings.text(
                                          'This group is no longer available.',
                                        ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.elevatedBackground,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: colors.separator.withValues(
                                        alpha: 0.35,
                                      ),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              CupertinoButton.filled(
                                padding: const EdgeInsets.all(8),
                                minimumSize: const Size.square(34),
                                borderRadius: BorderRadius.circular(17),
                                onPressed: composeEnabled ? send : null,
                                child: const Icon(
                                  CupertinoIcons.arrow_up,
                                  size: 18,
                                  color: CupertinoColors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
    required this.avatarUrl,
    required this.avatarName,
    this.focused = false,
    this.selected = false,
    this.selectionMode = false,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSwipeReply,
    this.onReplyTap,
    this.onImageTap,
    this.onFileTap,
    this.onVoiceTap,
    this.voiceProgress = 0,
    this.playingVoice = false,
    this.showReadStatus = false,
    this.displayTime = '',
    this.searchQuery = '',
    this.compactLayout = false,
    this.searchFocused = false,
    this.showSenderLine = true,
    this.showMemberMeta = false,
    this.animateEntry = true,
  });

  final ChatMessage message;
  final ChatMessage? replyMessage;
  final bool mine;
  final String avatarUrl;
  final String avatarName;
  final bool focused;
  final bool selected;
  final bool selectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSwipeReply;
  final VoidCallback? onReplyTap;
  final VoidCallback? onImageTap;
  final VoidCallback? onFileTap;
  final VoidCallback? onVoiceTap;
  final double voiceProgress;
  final bool playingVoice;
  final bool showReadStatus;
  final String displayTime;
  final String searchQuery;
  final bool compactLayout;
  final bool searchFocused;
  final bool showSenderLine;
  final bool showMemberMeta;
  final bool animateEntry;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final maxBubbleWidth = width < 600 ? width * 0.76 : 440.0;
    final bubbleColor = mine ? colors.myBubble : colors.otherBubble;
    final textColor = mine ? colors.myBubbleText : colors.otherBubbleText;
    final secondaryTextColor = mine
        ? CupertinoColors.white.withValues(alpha: 0.72)
        : colors.secondaryLabel;
    final replyColor = mine
        ? CupertinoColors.white.withValues(alpha: 0.15)
        : colors.elevatedBackground;
    final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final strings = context.strings;
    final memberTitle = message.memberTitle.trim();
    final memberBadgeText = showMemberMeta
        ? 'LV${message.memberLevel.clamp(1, 100)}${memberTitle.isEmpty ? '' : ' $memberTitle'}'
        : '';
    final senderLine = [
      message.sender,
      if (displayTime.isNotEmpty) displayTime,
    ].join(' · ');
    if (message.isRecalled || message.msgType == 4) {
      final systemText = message.isRecalled
          ? strings.format('{sender} recalled a message', {
              'sender': message.sender,
            })
          : message.body;
      return Padding(
        padding: EdgeInsets.symmetric(vertical: compactLayout ? 2 : 6),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectionMode) ...[
                Icon(
                  selected
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.circle,
                  size: 17,
                  color: selected ? colors.primaryColor : colors.secondaryLabel,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  systemText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compactLayout ? 11 : 12,
                    color: colors.secondaryLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final borderRadius = mine
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          );
    final verticalPadding = compactLayout ? 1.5 : (width < 600 ? 3.0 : 5.0);
    final bubblePadding = compactLayout
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 7)
        : const EdgeInsets.symmetric(horizontal: 13, vertical: 9);
    final avatar = Padding(
      padding: EdgeInsets.only(top: showSenderLine ? 18 : 2),
      child: _Avatar(
        url: avatarUrl,
        fallback: CupertinoIcons.person_fill,
        size: compactLayout ? 28 : 32,
        name: avatarName,
      ),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: animateEntry ? 0 : 1, end: 1),
      duration: animateEntry ? _csacMotionMedium : Duration.zero,
      curve: _csacEaseOut,
      builder: (context, value, child) {
        final offset = Offset(
          (mine ? 1 : -1) * (1 - value) * 10,
          (1 - value) * 4,
        );
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: offset,
            child: Transform.scale(
              scale: 0.985 + value * 0.015,
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: child,
            ),
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        child: _SwipeReplyGesture(
          mine: mine,
          enabled: !selectionMode && onSwipeReply != null,
          onReply: onSwipeReply,
          child: SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: onTap,
              onDoubleTap: onDoubleTap,
              onLongPress: onLongPress,
              child: Row(
                mainAxisAlignment: mine
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!mine) ...[avatar, const SizedBox(width: 8)],
                  Flexible(
                    child: Column(
                      crossAxisAlignment: align,
                      children: [
                        if (showSenderLine || selectionMode)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selectionMode) ...[
                                Icon(
                                  selected
                                      ? CupertinoIcons.checkmark_circle_fill
                                      : CupertinoIcons.circle,
                                  size: 18,
                                  color: selected
                                      ? colors.primaryColor
                                      : colors.secondaryLabel,
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (showSenderLine) ...[
                                if (memberBadgeText.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(
                                        color: colors.secondaryLabel.withValues(
                                          alpha: 0.28,
                                        ),
                                        width: 0.6,
                                      ),
                                      color: colors.secondaryFill.withValues(
                                        alpha: 0.28,
                                      ),
                                    ),
                                    child: Text(
                                      memberBadgeText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        height: 1.1,
                                        color: colors.secondaryLabel,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                ],
                                Flexible(
                                  child: Text(
                                    senderLine,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.secondaryLabel,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        if (showSenderLine || selectionMode)
                          SizedBox(height: compactLayout ? 2 : 3),
                        AnimatedContainer(
                          duration: _csacMotionFast,
                          curve: _csacEaseInOut,
                          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                          padding: bubblePadding,
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            borderRadius: borderRadius,
                            boxShadow: [
                              BoxShadow(
                                color: CupertinoColors.black.withValues(
                                  alpha: 0.06,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            border: (selected || focused || searchFocused)
                                ? Border.all(
                                    color: colors.primaryColor,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (message.replyTo > 0) ...[
                                GestureDetector(
                                  onTap: onReplyTap,
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
                                          : strings.format(
                                              'Reply {sender}: {message}',
                                              {
                                                'sender': replyMessage!.sender,
                                                'message': compactMessage(
                                                  replyMessage!.body,
                                                ),
                                              },
                                            ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: secondaryTextColor,
                                        fontWeight: FontWeight.w600,
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
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: secondaryTextColor.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              CupertinoIcons.at,
                                              size: 12,
                                              color: textColor,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              strings.text('Mentioned'),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: textColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (message.isEssence)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: secondaryTextColor.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              CupertinoIcons.star_fill,
                                              size: 12,
                                              color: textColor,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              strings.text('Essence'),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: textColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ],
                              if (message.imageUrl.isNotEmpty) ...[
                                _MessageImage(
                                  url: message.imageUrl,
                                  onTap: onImageTap,
                                ),
                                if (message.body.isNotEmpty &&
                                    !message.body.startsWith('[image]'))
                                  const SizedBox(height: 8),
                              ],
                              if (message.voiceUrl.isNotEmpty) ...[
                                _VoiceMessageControl(
                                  durationSeconds: message.voiceDuration,
                                  playing: playingVoice,
                                  progress: voiceProgress,
                                  onTap: onVoiceTap,
                                  foreground: textColor,
                                  secondary: secondaryTextColor,
                                ),
                                if (message.body.isNotEmpty &&
                                    !message.body.startsWith('[voice]'))
                                  const SizedBox(height: 8),
                              ],
                              if (message.fileUrl.isNotEmpty) ...[
                                _FileMessageControl(
                                  fileName: message.fileName.ifEmpty(
                                    fileNameFromUrl(
                                      message.fileUrl,
                                    ).ifEmpty(strings.text('File')),
                                  ),
                                  onTap: onFileTap,
                                  foreground: textColor,
                                  secondary: secondaryTextColor,
                                ),
                                if (message.body.isNotEmpty &&
                                    !message.body.startsWith('[file]'))
                                  const SizedBox(height: 8),
                              ],
                              if (message.body.isNotEmpty &&
                                  !message.body.startsWith('[image]') &&
                                  !message.body.startsWith('[voice]') &&
                                  !message.body.startsWith('[file]'))
                                message.msgType == 4
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            CupertinoIcons.hand_thumbsup,
                                            size: 15,
                                            color: textColor,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              message.body,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: textColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      )
                                    : _HighlightedMessageText(
                                        text: message.body,
                                        query: searchQuery,
                                        color: textColor,
                                        highlightColor: mine
                                            ? CupertinoColors.white.withValues(
                                                alpha: 0.22,
                                              )
                                            : colors.primaryColor.withValues(
                                                alpha: 0.18,
                                              ),
                                      ),
                            ],
                          ),
                        ),
                        if (showReadStatus) ...[
                          const SizedBox(height: 3),
                          Text(
                            message.isRead
                                ? context.strings.text('Read')
                                : context.strings.text('Unread'),
                            style: TextStyle(
                              fontSize: 11,
                              color: message.isRead
                                  ? colors.primaryColor
                                  : colors.tertiaryLabel,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (mine) ...[const SizedBox(width: 8), avatar],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatBackground extends StatelessWidget {
  const _ChatBackground({required this.color, required this.imagePath});

  final Color color;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final imageFile = imagePath.isEmpty ? null : File(imagePath);
    final hasImage = imageFile?.existsSync() == true;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        image: hasImage
            ? DecorationImage(
                image: FileImage(imageFile!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  colors.systemBackground.withValues(
                    alpha: colors.isDark ? 0.42 : 0.18,
                  ),
                  BlendMode.srcOver,
                ),
              )
            : null,
      ),
    );
  }
}

class _ChatEntryHint extends StatelessWidget {
  const _ChatEntryHint({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final strings = context.strings;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: _CsacPressable(
          onTap: onClose,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
                decoration: BoxDecoration(
                  color: colors.navBarBackground.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colors.primaryColor.withValues(alpha: 0.18),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withValues(
                        alpha: colors.isDark ? 0.28 : 0.08,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.hand_draw,
                      size: 18,
                      color: colors.primaryColor,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        strings.text(
                          'Swipe a message sideways to reply quickly.',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.label,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      CupertinoIcons.xmark_circle_fill,
                      size: 18,
                      color: colors.tertiaryLabel,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ).csacCardEnter(y: 3),
    );
  }
}

class _SwipeReplyGesture extends StatefulWidget {
  const _SwipeReplyGesture({
    required this.mine,
    required this.enabled,
    required this.child,
    this.onReply,
  });

  final bool mine;
  final bool enabled;
  final Widget child;
  final VoidCallback? onReply;

  @override
  State<_SwipeReplyGesture> createState() => _SwipeReplyGestureState();
}

class _SwipeReplyGestureState extends State<_SwipeReplyGesture> {
  static const double _triggerDistance = 46;
  static const double _maxDrag = 74;

  double drag = 0;
  bool armed = false;

  double get progress => (drag.abs() / _triggerDistance).clamp(0.0, 1.0);

  void updateDrag(DragUpdateDetails details) {
    if (!widget.enabled) return;
    final direction = widget.mine ? -1.0 : 1.0;
    final raw = drag + details.delta.dx;
    final directional = raw * direction;
    final clamped = directional <= 0 ? 0.0 : directional.clamp(0.0, _maxDrag);
    final next = clamped * direction;
    final nextArmed = clamped >= _triggerDistance;
    if (nextArmed != armed) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      drag = next;
      armed = nextArmed;
    });
  }

  void endDrag([DragEndDetails? details]) {
    if (armed) {
      HapticFeedback.mediumImpact();
      widget.onReply?.call();
    }
    setState(() {
      drag = 0;
      armed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final iconAlignment = widget.mine
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final iconPadding = widget.mine
        ? const EdgeInsets.only(right: 10)
        : const EdgeInsets.only(left: 10);
    final visualOffset = drag * 0.48;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: updateDrag,
      onHorizontalDragEnd: endDrag,
      onHorizontalDragCancel: endDrag,
      child: Stack(
        alignment: iconAlignment,
        children: [
          Positioned.fill(
            child: Padding(
              padding: iconPadding,
              child: Align(
                alignment: iconAlignment,
                child: AnimatedScale(
                  scale: armed ? 1.04 : 0.88 + progress * 0.12,
                  duration: _csacMotionFast,
                  curve: _csacEaseOut,
                  child: AnimatedOpacity(
                    opacity: progress == 0 ? 0 : 0.24 + progress * 0.66,
                    duration: _csacMotionFast,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: armed
                            ? colors.primaryColor
                            : colors.primaryColor.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.reply,
                        size: 17,
                        color: armed
                            ? CupertinoColors.white
                            : colors.primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          AnimatedSlide(
            offset: Offset(visualOffset / 320, 0),
            duration: drag == 0
                ? const Duration(milliseconds: 220)
                : Duration.zero,
            curve: Curves.easeOutBack,
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _HighlightedMessageText extends StatelessWidget {
  const _HighlightedMessageText({
    required this.text,
    required this.query,
    required this.color,
    required this.highlightColor,
  });

  final String text;
  final String query;
  final Color color;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final baseStyle = TextStyle(color: color, fontSize: 15.5, height: 1.28);
    if (normalizedQuery.isEmpty) {
      return Text(text, style: baseStyle);
    }
    final lower = text.toLowerCase();
    final spans = <TextSpan>[];
    var cursor = 0;
    while (cursor < text.length) {
      final index = lower.indexOf(normalizedQuery, cursor);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(cursor)));
        break;
      }
      if (index > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, index)));
      }
      final end = index + normalizedQuery.length;
      spans.add(
        TextSpan(
          text: text.substring(index, end),
          style: TextStyle(
            backgroundColor: highlightColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      cursor = end;
    }
    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }
}

class _ChatSearchBar extends StatelessWidget {
  const _ChatSearchBar({
    required this.controller,
    required this.searching,
    required this.current,
    required this.total,
    required this.onChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onClose,
  });

  final TextEditingController controller;
  final bool searching;
  final int current;
  final int total;
  final ValueChanged<String> onChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: colors.cardBackground.withValues(alpha: 0.92),
        border: Border(bottom: BorderSide(color: colors.separator, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoSearchTextField(
              controller: controller,
              autofocus: true,
              placeholder: strings.text('Search in chat'),
              onChanged: onChanged,
              onSubmitted: (_) => onNext(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 54,
            child: Center(
              child: searching
                  ? const CupertinoActivityIndicator(radius: 8)
                  : Text(
                      total == 0 ? '0/0' : '$current/$total',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.secondaryLabel,
                      ),
                    ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(30),
            onPressed: total > 0 && current > 1 ? onPrevious : null,
            child: const Icon(CupertinoIcons.chevron_up, size: 18),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(30),
            onPressed: total > 0 && current < total ? onNext : null,
            child: const Icon(CupertinoIcons.chevron_down, size: 18),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(30),
            onPressed: onClose,
            child: const Icon(CupertinoIcons.xmark_circle_fill, size: 19),
          ),
        ],
      ),
    );
  }
}

class _ComposeIconButton extends StatelessWidget {
  const _ComposeIconButton({
    required this.icon,
    required this.onPressed,
    this.color,
    this.busy = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size.square(36),
      onPressed: onPressed,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: colors.secondaryFill,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: busy
            ? const CupertinoActivityIndicator(radius: 9)
            : Icon(icon, size: 19, color: color ?? colors.primaryColor),
      ),
    );
  }
}

class _RecordingCapsule extends StatelessWidget {
  const _RecordingCapsule({
    required this.seconds,
    required this.onCancel,
    required this.onDone,
  });

  final int seconds;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: colors.floatingTabBarBackground,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colors.separator.withValues(alpha: 0.35),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: colors.destructive,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors.destructive.withValues(alpha: 0.45),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatVoiceDuration(seconds),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.label,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 24,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (final height in voiceWaveformHeights(seconds, 24))
                          Expanded(
                            child: Align(
                              alignment: Alignment.center,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 3,
                                height: height,
                                decoration: BoxDecoration(
                                  color: colors.primaryColor.withValues(
                                    alpha: 0.72,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size.square(30),
                  onPressed: onCancel,
                  child: Text(
                    strings.text('Cancel'),
                    style: TextStyle(fontSize: 13, color: colors.destructive),
                  ),
                ),
                CupertinoButton.filled(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size.square(30),
                  borderRadius: BorderRadius.circular(15),
                  onPressed: onDone,
                  child: Text(
                    strings.text('Preview'),
                    style: const TextStyle(fontSize: 13),
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

class _VoiceDraftCard extends StatelessWidget {
  const _VoiceDraftCard({
    required this.draft,
    required this.playing,
    required this.progress,
    required this.onPreview,
    required this.onDiscard,
    required this.onSend,
  });

  final _VoiceDraft draft;
  final bool playing;
  final double progress;
  final VoidCallback onPreview;
  final VoidCallback onDiscard;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: colors.elevatedBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.separator.withValues(alpha: 0.35),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(36),
              onPressed: onPreview,
              child: Icon(
                playing
                    ? CupertinoIcons.pause_circle_fill
                    : CupertinoIcons.play_circle_fill,
                size: 34,
                color: colors.primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    draft.sourceLabel.isEmpty
                        ? strings.text('Voice draft')
                        : draft.sourceLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colors.label,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _MiniWaveform(
                    seed: draft.bytes.length + draft.durationSeconds,
                    progress: progress,
                    activeColor: colors.primaryColor,
                    inactiveColor: colors.secondaryLabel.withValues(
                      alpha: 0.28,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      draft.durationSeconds <= 0
                          ? strings.text('Unknown duration')
                          : formatVoiceDuration(draft.durationSeconds),
                      draft.fileName,
                    ].where((part) => part.trim().isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size.square(32),
              onPressed: onDiscard,
              child: Icon(
                CupertinoIcons.arrow_counterclockwise,
                size: 20,
                color: colors.secondaryLabel,
              ),
            ),
            CupertinoButton.filled(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size.square(32),
              borderRadius: BorderRadius.circular(16),
              onPressed: onSend,
              child: Text(strings.text('Send')),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniWaveform extends StatelessWidget {
  const _MiniWaveform({
    required this.seed,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  final int seed;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final bars = voiceWaveformHeights(seed, 22);
    final activeBars = (bars.length * progress.clamp(0.0, 1.0)).ceil();
    return SizedBox(
      height: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < bars.length; i++) ...[
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 3,
                  height: bars[i],
                  decoration: BoxDecoration(
                    color: i < activeBars ? activeColor : inactiveColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            if (i != bars.length - 1) const SizedBox(width: 2),
          ],
        ],
      ),
    );
  }
}

class _FloatingChatButton extends StatelessWidget {
  const _FloatingChatButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.label,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: onPressed,
          child: Container(
            height: 36,
            padding: EdgeInsets.symmetric(horizontal: label == null ? 10 : 12),
            decoration: BoxDecoration(
              color: colors.floatingTabBarBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: colors.separator.withValues(alpha: 0.35),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withValues(
                    alpha: colors.isDark ? 0.28 : 0.10,
                  ),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: colors.primaryColor),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    label!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.primaryColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingMessageBubble extends StatelessWidget {
  const _PendingMessageBubble({required this.pending, required this.onRetry});

  final _PendingSend pending;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final strings = context.strings;
    final failed = pending.status == _PendingSendStatus.failed;
    final width = MediaQuery.sizeOf(context).width;
    final bubbleColor = failed
        ? colors.destructive.withValues(alpha: 0.15)
        : colors.myBubble;
    final textColor = failed ? colors.destructive : colors.myBubbleText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            failed ? strings.text('Send failed') : strings.text('Sending...'),
            style: TextStyle(
              fontSize: 11,
              color: failed ? colors.destructive : colors.secondaryLabel,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            constraints: BoxConstraints(
              maxWidth: width < 600 ? width * 0.76 : 440,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pending.hasImage) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.photo, size: 18, color: textColor),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          pending.imageName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (pending.text.isNotEmpty) const SizedBox(height: 8),
                ],
                if (pending.hasVoice) ...[
                  _VoiceMessageControl(
                    durationSeconds: pending.voiceDuration,
                    playing: false,
                    progress: 0,
                    onTap: null,
                    foreground: textColor,
                    secondary: textColor.withValues(alpha: 0.72),
                  ),
                  if (pending.text.isNotEmpty) const SizedBox(height: 8),
                ],
                if (pending.hasFile) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.doc, size: 18, color: textColor),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          pending.fileName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (pending.text.isNotEmpty) const SizedBox(height: 8),
                ],
                if (pending.text.isNotEmpty)
                  Text(pending.text, style: TextStyle(color: textColor)),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!failed)
                      const CupertinoActivityIndicator(radius: 7)
                    else
                      Icon(
                        CupertinoIcons.exclamationmark_circle,
                        size: 16,
                        color: colors.destructive,
                      ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        failed && pending.error.isNotEmpty
                            ? compactMessage(pending.error, max: 80)
                            : strings.text('Sending...'),
                        style: TextStyle(fontSize: 11, color: textColor),
                      ),
                    ),
                    if (failed) ...[
                      const SizedBox(width: 8),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        onPressed: onRetry,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(CupertinoIcons.refresh, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              strings.text('Retry send'),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceMessageControl extends StatelessWidget {
  const _VoiceMessageControl({
    required this.durationSeconds,
    required this.playing,
    this.progress = 0,
    required this.onTap,
    required this.foreground,
    required this.secondary,
  });

  final int durationSeconds;
  final bool playing;
  final double progress;
  final VoidCallback? onTap;
  final Color foreground;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final label = durationSeconds <= 0
        ? context.strings.text('Unknown duration')
        : formatVoiceDuration(durationSeconds);
    final bars = voiceWaveformHeights(durationSeconds, 18);
    final clampedProgress = progress.clamp(0.0, 1.0);
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 168, maxWidth: 260),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                playing
                    ? CupertinoIcons.pause_circle_fill
                    : CupertinoIcons.play_circle_fill,
                color: foreground,
                size: 30,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final activeBars = (bars.length * clampedProgress).ceil();
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (var i = 0; i < bars.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: constraints.maxWidth / bars.length - 2,
                            height: bars[i],
                            decoration: BoxDecoration(
                              color: (playing && i < activeBars)
                                  ? foreground
                                  : secondary.withValues(alpha: 0.32),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileMessageControl extends StatelessWidget {
  const _FileMessageControl({
    required this.fileName,
    required this.onTap,
    required this.foreground,
    required this.secondary,
  });

  final String fileName;
  final VoidCallback? onTap;
  final Color foreground;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 180, maxWidth: 260),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.doc_fill, color: foreground, size: 28),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.strings.text('Tap to open'),
                      style: TextStyle(fontSize: 11, color: secondary),
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
    final strings = context.strings;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: colors.systemOrange.withValues(alpha: 0.12),
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            Icon(
              CupertinoIcons.speaker_2,
              color: colors.systemOrange,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    strings.text('Group announcement'),
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.label,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    announcement,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              CupertinoIcons.chevron_right,
              color: colors.secondaryLabel,
              size: 16,
            ),
          ],
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
  report,
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
    return CupertinoActionSheet(
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(_MessageAction.select),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.checkmark_circle, size: 20),
              const SizedBox(width: 8),
              Text(strings.text('Select messages')),
            ],
          ),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(_MessageAction.reply),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.reply, size: 20),
              const SizedBox(width: 8),
              Text(strings.text('Reply')),
            ],
          ),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(_MessageAction.copyText),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.doc_on_doc, size: 20),
              const SizedBox(width: 8),
              Text(strings.text('Copy text')),
            ],
          ),
        ),
        if (message.imageUrl.isNotEmpty ||
            message.voiceUrl.isNotEmpty ||
            message.fileUrl.isNotEmpty)
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.of(context).pop(_MessageAction.copyImage),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.link, size: 20),
                const SizedBox(width: 8),
                Text(strings.text('Copy link')),
              ],
            ),
          ),
        if (message.imageUrl.isNotEmpty || message.fileUrl.isNotEmpty)
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.of(context).pop(_MessageAction.openImage),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.arrow_up_right_square, size: 20),
                const SizedBox(width: 8),
                Text(
                  strings.text(
                    message.imageUrl.isNotEmpty ? 'Open image' : 'Open file',
                  ),
                ),
              ],
            ),
          ),
        if (message.imageUrl.isNotEmpty ||
            message.voiceUrl.isNotEmpty ||
            message.fileUrl.isNotEmpty)
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.of(context).pop(_MessageAction.downloadImage),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.cloud_download, size: 20),
                const SizedBox(width: 8),
                Text(strings.text('Download')),
              ],
            ),
          ),
        if (canRecall)
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(_MessageAction.recall),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.arrow_uturn_left, size: 20),
                const SizedBox(width: 8),
                Text(strings.text('Recall')),
              ],
            ),
          ),
        if (canEssence)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(_MessageAction.essence),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  message.isEssence
                      ? CupertinoIcons.star_fill
                      : CupertinoIcons.star,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  strings.text(
                    message.isEssence ? 'Remove essence' : 'Set essence',
                  ),
                ),
              ],
            ),
          ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(_MessageAction.report),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(CupertinoIcons.flag, size: 20),
              const SizedBox(width: 8),
              Text(strings.text('Report message')),
            ],
          ),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(strings.text('Cancel')),
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
    final colors = CsacColors.of(context);
    final strings = context.strings;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          if (replyTarget != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colors.elevatedBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.reply,
                    size: 14,
                    color: colors.secondaryLabel,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      strings.format('Reply #{id}: {sender}', {
                        'id': replyTarget!.id,
                        'sender': replyTarget!.sender,
                      }),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: colors.label),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onClearReply,
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      size: 16,
                      color: colors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ),
          if (mentions.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colors.elevatedBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.at,
                    size: 14,
                    color: colors.secondaryLabel,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    mentions.length == 1
                        ? '@${mentions.first.name}'
                        : strings.format('@ {count} members', {
                            'count': mentions.length,
                          }),
                    style: TextStyle(fontSize: 12, color: colors.label),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: onClearMentions,
                    child: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      size: 16,
                      color: colors.secondaryLabel,
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
    final colors = CsacColors.of(context);
    final strings = context.strings;
    return Container(
      height: 520,
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: colors.separator,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      strings.text('Mention members'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: colors.label,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
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
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (checked) {
                                selected.remove(member.uid);
                              } else {
                                selected.add(member.uid);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  checked
                                      ? CupertinoIcons.checkmark_circle_fill
                                      : CupertinoIcons.circle,
                                  size: 22,
                                  color: checked
                                      ? colors.primaryColor
                                      : colors.secondaryLabel,
                                ),
                                const SizedBox(width: 12),
                                _Avatar(
                                  url: member.avatar,
                                  fallback: CupertinoIcons.person_solid,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        member.name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: colors.label,
                                        ),
                                      ),
                                      if (member.subtitle.isNotEmpty)
                                        Text(
                                          member.subtitle,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colors.secondaryLabel,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
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
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.secondaryLabel,
                    ),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text(strings.text('Cancel')),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton.filled(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
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
    final colors = CsacColors.of(context);
    final strings = context.strings;
    return Container(
      height: 520,
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: colors.separator,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                strings.text('Forward to'),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: colors.label,
                ),
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
                        return GestureDetector(
                          onTap: () => Navigator.of(context).pop(conversation),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  conversation.type == ConversationType.group
                                      ? CupertinoIcons.person_3_fill
                                      : CupertinoIcons.person_fill,
                                  size: 24,
                                  color: colors.secondaryLabel,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        conversation.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: colors.label,
                                        ),
                                      ),
                                      if (conversation.subtitle.isNotEmpty)
                                        Text(
                                          conversation.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: colors.secondaryLabel,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  CupertinoIcons.chevron_right,
                                  size: 16,
                                  color: colors.tertiaryLabel,
                                ),
                              ],
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
    return _csacPush<void>(
      context,
      (_) => ChatScreen(
        state: widget.state,
        conversation: widget.conversation,
        focusMessageId: message.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final strings = context.strings;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(strings.text('Essence messages')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              onPressed: () {
                _csacPush<void>(
                  context,
                  (_) => EssenceStatsScreen(
                    state: widget.state,
                    conversation: widget.conversation,
                  ),
                );
              },
              child: const Icon(CupertinoIcons.chart_bar, size: 20),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              onPressed: load,
              child: const Icon(CupertinoIcons.refresh, size: 20),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: load),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CupertinoActivityIndicator()),
                    ),
                  if (error != null)
                    _InlineError(message: error!, onRetry: load),
                  if (!loading && messages.isEmpty)
                    _EmptyPanel(message: strings.text('No essence messages.'))
                  else
                    for (final message in messages)
                      GestureDetector(
                        onTap: () => openMessage(message),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.cardBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.star,
                                size: 20,
                                color: colors.systemOrange,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.sender,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: colors.label,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      [
                                        if (message.time.isNotEmpty)
                                          message.time,
                                        message.body,
                                      ].join(' | '),
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
                              const SizedBox(width: 8),
                              Icon(
                                CupertinoIcons.chevron_right,
                                size: 16,
                                color: colors.tertiaryLabel,
                              ),
                            ],
                          ),
                        ),
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

class EssenceStatsScreen extends StatefulWidget {
  const EssenceStatsScreen({
    super.key,
    required this.state,
    required this.conversation,
  });

  final CsacAppState state;
  final Conversation conversation;

  @override
  State<EssenceStatsScreen> createState() => _EssenceStatsScreenState();
}

class _EssenceStatsScreenState extends State<EssenceStatsScreen> {
  static const types = <String>['today', 'week', 'month', 'all'];

  String selectedType = 'today';
  EssenceStats? stats;
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
      final loaded = await widget.state.loadEssenceStats(
        widget.conversation.id,
        selectedType,
      );
      if (mounted) {
        setState(() => stats = loaded);
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

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final strings = context.strings;
    final loaded = stats;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(strings.text('Essence stats')),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: load),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  CupertinoSlidingSegmentedControl<String>(
                    groupValue: selectedType,
                    children: {
                      for (final type in types)
                        type: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Text(
                            strings.text('stats.$type'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    },
                    onValueChanged: (value) {
                      if (value != null) {
                        setState(() => selectedType = value);
                        load();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: CupertinoActivityIndicator()),
                    ),
                  if (error != null)
                    _InlineError(message: error!, onRetry: load),
                  if (loaded != null) ...[
                    GridView.count(
                      crossAxisCount: MediaQuery.sizeOf(context).width > 520
                          ? 4
                          : 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.8,
                      children: [
                        _StatTile(
                          label: strings.text('Total'),
                          value: '${loaded.total}',
                        ),
                        _StatTile(
                          label: strings.text('Text'),
                          value: '${loaded.textCount}',
                        ),
                        _StatTile(
                          label: strings.text('Images'),
                          value: '${loaded.imageCount}',
                        ),
                        _StatTile(
                          label: strings.text('Voice'),
                          value: '${loaded.voiceCount}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.cardBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.clock,
                            size: 20,
                            color: colors.secondaryLabel,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strings.text('Latest set time'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: colors.label,
                                  ),
                                ),
                                Text(
                                  loaded.latestSetTime.isEmpty
                                      ? strings.text('(empty)')
                                      : loaded.latestSetTime,
                                  style: TextStyle(
                                    fontSize: 13,
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
                    Text(
                      strings.text('Contribution rank'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: colors.label,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (loaded.rank.isEmpty)
                      _EmptyPanel(message: strings.text('No rank data.'))
                    else
                      for (final item in loaded.rank)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.cardBackground,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: colors.primaryColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${item.rank == 0 ? loaded.rank.indexOf(item) + 1 : item.rank}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colors.primaryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.nickname,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: colors.label,
                                      ),
                                    ),
                                    Text(
                                      'UID ${item.uid}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colors.secondaryLabel,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${item.count}',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: colors.label,
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: colors.secondaryLabel),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colors.label,
            ),
          ),
        ],
      ),
    );
  }
}
