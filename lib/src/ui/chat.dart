part of '../../main.dart';

enum _PendingSendStatus { sending, failed }

class _PendingSend {
  const _PendingSend({
    required this.localId,
    required this.text,
    this.imageBytes,
    this.imageName = '',
    this.voiceBytes,
    this.voiceName = '',
    this.voiceDuration = 0,
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
  final int replyTo;
  final List<int> mentionUids;
  final _PendingSendStatus status;
  final String error;

  bool get hasImage => imageBytes != null;
  bool get hasVoice => voiceBytes != null;

  _PendingSend copyWith({
    String? text,
    Uint8List? imageBytes,
    String? imageName,
    Uint8List? voiceBytes,
    String? voiceName,
    int? voiceDuration,
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

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final imagePicker = ImagePicker();
  final audioRecorder = AudioRecorder();
  final audioPlayer = AudioPlayer();
  StreamSubscription<Object?>? audioErrorSubscription;
  final itemKeys = <int, GlobalKey>{};
  final messages = <ChatMessage>[];
  final pendingSends = <_PendingSend>[];
  final mentionTargets = <GroupMember>[];
  final selectedMessageIds = <int>{};
  Timer? timer;
  Timer? draftTimer;
  GroupProfile? groupProfile;
  ChatMessage? replyTarget;
  int nextPendingId = -1;
  int refreshTicks = 0;
  DateTime? recordingStartedAt;
  String? recordingPath;
  int? playingMessageId;
  bool loading = true;
  bool refreshing = false;
  bool pickingImage = false;
  bool recording = false;
  bool applyingDraft = false;
  bool offline = false;
  String? error;

  bool get selectionMode => selectedMessageIds.isNotEmpty;

  List<ChatMessage> get selectedMessages {
    return messages
        .where((message) => selectedMessageIds.contains(message.id))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    widget.state.setActiveConversation(widget.conversation);
    widget.state.markConversationRead(widget.conversation);
    input.addListener(scheduleDraftSave);
    loadDraft();
    loadGroupAnnouncement();
    loadInitial();
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
    timer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => refresh(silent: true),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    draftTimer?.cancel();
    audioErrorSubscription?.cancel();
    audioPlayer.dispose();
    audioRecorder.dispose();
    unawaited(ConversationDraftStore.save(widget.conversation, input.text));
    if (widget.state.isActiveConversation(widget.conversation)) {
      widget.state.setActiveConversation(null);
    }
    input.dispose();
    scroll.dispose();
    super.dispose();
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
    applyingDraft = false;
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
    } catch (_) {
      // The chat should remain usable even when the detail request fails.
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
    final caption = await showDialog<String>(
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
      await stopAndSendVoice();
      return;
    }
    await startRecording();
  }

  Future<void> startRecording() async {
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
      var encoder = Platform.isLinux ? AudioEncoder.wav : AudioEncoder.aacLc;
      var extension = Platform.isLinux ? 'wav' : 'mp4';
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
      await audioRecorder.start(RecordConfig(encoder: encoder), path: path);
      if (!mounted) {
        return;
      }
      setState(() {
        recording = true;
        recordingPath = path;
        recordingStartedAt = DateTime.now();
        error = null;
      });
    } catch (err) {
      if (mounted) {
        showSnack(failedMessage.replaceAll('{error}', '$err'));
      }
    }
  }

  Future<void> stopAndSendVoice() async {
    final notSavedMessage = context.strings.text(
      'No voice recording was saved.',
    );
    final tooShortMessage = context.strings.text('Voice message is too short.');
    final failedMessage = context.strings.text('Recording failed: {error}');
    try {
      final path = await audioRecorder.stop();
      final startedAt = recordingStartedAt;
      if (!mounted) {
        return;
      }
      setState(() {
        recording = false;
        recordingPath = null;
        recordingStartedAt = null;
      });
      final resolvedPath = path ?? recordingPath;
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
      final pending = _PendingSend(
        localId: nextPendingId--,
        text: '',
        voiceBytes: bytes,
        voiceName: p.basename(resolvedPath),
        voiceDuration: duration,
      );
      setState(() {
        pendingSends.add(pending);
        replyTarget = null;
        mentionTargets.clear();
        error = null;
      });
      scrollToEnd();
      unawaited(performPendingSend(pending.localId));
    } catch (err) {
      if (mounted) {
        setState(() {
          recording = false;
          recordingPath = null;
          recordingStartedAt = null;
        });
        showSnack(failedMessage.replaceAll('{error}', '$err'));
      }
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
      replacePendingSend(
        localId,
        (item) => item.copyWith(
          status: _PendingSendStatus.failed,
          error: err.toString(),
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

  void showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> toggleVoicePlayback(ChatMessage message) async {
    if (message.voiceUrl.isEmpty) {
      return;
    }
    try {
      if (playingMessageId == message.id) {
        await audioPlayer.pause();
        if (mounted) {
          setState(() => playingMessageId = null);
        }
        return;
      }
      await audioPlayer.stop();
      final source = Platform.isAndroid
          ? await androidVoiceSource(message.voiceUrl)
          : UrlSource(
              message.voiceUrl,
              mimeType: voiceMimeType(message.voiceUrl),
            );
      await audioPlayer.play(source);
      if (!mounted) {
        return;
      }
      setState(() => playingMessageId = message.id);
      audioPlayer.onPlayerComplete.first.then((_) {
        if (mounted && playingMessageId == message.id) {
          setState(() => playingMessageId = null);
        }
      });
    } catch (err) {
      if (mounted) {
        showSnack(
          context.strings.format('Playback failed: {error}', {'error': err}),
        );
      }
    }
  }

  Future<Source> androidVoiceSource(String url) async {
    final uri = Uri.parse(url);
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final dir = await getTemporaryDirectory();
    final extension = voiceExtension(url);
    final file = File(
      p.join(dir.path, 'csac_voice_play_${uri.path.hashCode}.$extension'),
    );
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return DeviceFileSource(file.path, mimeType: voiceMimeType(url));
  }

  String voiceExtension(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    final extension = p.extension(path).replaceFirst('.', '');
    if (extension.isNotEmpty && extension.length <= 5) {
      return extension;
    }
    return 'wav';
  }

  String? voiceMimeType(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    if (path.endsWith('.m4a') || path.endsWith('.mp4')) {
      return 'audio/mp4';
    }
    if (path.endsWith('.wav')) {
      return 'audio/wav';
    }
    if (path.endsWith('.ogg')) {
      return 'audio/ogg';
    }
    if (path.endsWith('.webm')) {
      return 'audio/webm';
    }
    if (path.endsWith('.mp3') || path.endsWith('.mpeg')) {
      return 'audio/mpeg';
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
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => ConversationDetailScreen(
              state: widget.state,
              conversation: widget.conversation,
            ),
          ),
        )
        .then((_) => loadGroupAnnouncement());
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
    return [
      '#${message.id} ${message.sender}',
      if (message.time.isNotEmpty) message.time,
      if (message.body.trim().isNotEmpty) message.body.trim(),
      if (message.imageUrl.isNotEmpty) message.imageUrl,
    ].join('\n');
  }

  String formatMessageForForward(ChatMessage message) {
    return [
      '${message.sender}:',
      if (message.body.trim().isNotEmpty) message.body.trim(),
      if (message.imageUrl.isNotEmpty)
        context.strings.format('Image: {url}', {'url': message.imageUrl}),
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
    final strings = context.strings;
    final announcement = groupProfile?.notice.trim() ?? '';
    final showEmpty = !loading && messages.isEmpty && pendingSends.isEmpty;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded && !selectionMode,
        leading: selectionMode
            ? IconButton(
                tooltip: strings.text('Cancel selection'),
                onPressed: clearSelection,
                icon: const Icon(Icons.close),
              )
            : null,
        title: Text(
          selectionMode
              ? strings.format('{count} messages selected', {
                  'count': selectedMessageIds.length,
                })
              : widget.conversation.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: selectionMode
            ? [
                IconButton(
                  tooltip: strings.text('Copy selected'),
                  onPressed: copySelectedMessages,
                  icon: const Icon(Icons.copy),
                ),
                IconButton(
                  tooltip: strings.text('Forward'),
                  onPressed: forwardSelectedMessages,
                  icon: const Icon(Icons.forward_outlined),
                ),
                IconButton(
                  tooltip: strings.text('Delete local copies'),
                  onPressed: deleteSelectedLocalMessages,
                  icon: const Icon(Icons.delete_outline),
                ),
              ]
            : [
                if (offline)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.cloud_off_outlined),
                  ),
                IconButton(
                  tooltip: strings.text('Refresh'),
                  onPressed: () =>
                      reloadConversationFromNetwork(showLoading: true),
                  icon: const Icon(Icons.refresh),
                ),
                if (widget.conversation.type == ConversationType.group)
                  IconButton(
                    tooltip: strings.text('Essence'),
                    onPressed: openEssenceList,
                    icon: const Icon(Icons.star_outline),
                  ),
                IconButton(
                  tooltip: strings.text('Details'),
                  onPressed: openConversationDetails,
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
                  child: Text(strings.text('Dismiss')),
                ),
              ],
            ),
          if (announcement.isNotEmpty)
            _GroupAnnouncementBar(
              announcement: announcement,
              onTap: openConversationDetails,
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : showEmpty
                ? _EmptyPanel(message: strings.text('No messages.'))
                : ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length + pendingSends.length,
                    itemBuilder: (context, index) {
                      if (index >= messages.length) {
                        final pending = pendingSends[index - messages.length];
                        return _PendingMessageBubble(
                          pending: pending,
                          onRetry: () => retryPendingSend(pending.localId),
                        );
                      }
                      final message = messages[index];
                      final mine = widget.state.user?.uid == message.senderId;
                      final selected = selectedMessageIds.contains(message.id);
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
                        selected: selected,
                        selectionMode: selectionMode,
                        onTap: selectionMode
                            ? () => toggleMessageSelection(message)
                            : null,
                        onLongPress: selectionMode
                            ? null
                            : () => showMessageActions(message, mine),
                        onReplyTap: message.replyTo > 0
                            ? () => scrollToMessage(message.replyTo)
                            : null,
                        onImageTap: message.imageUrl.isEmpty
                            ? null
                            : () => showImagePreview(context, message.imageUrl),
                        onVoiceTap: message.voiceUrl.isEmpty
                            ? null
                            : () => toggleVoicePlayback(message),
                        playingVoice: playingMessageId == message.id,
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
                            hintText: strings.text('Message'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (widget.conversation.type == ConversationType.group)
                        IconButton.filledTonal(
                          tooltip: strings.text('Mention'),
                          onPressed: chooseMentionTargets,
                          icon: const Icon(Icons.alternate_email),
                        ),
                      if (widget.conversation.type == ConversationType.group)
                        const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: recording
                            ? strings.text('Stop recording')
                            : strings.text('Voice'),
                        onPressed: toggleRecording,
                        icon: Icon(
                          recording ? Icons.stop : Icons.mic_none_outlined,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: strings.text('Image'),
                        onPressed: pickingImage ? null : pickAndSendImage,
                        icon: pickingImage
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.image_outlined),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: send,
                        child: const Icon(Icons.send),
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
    this.selected = false,
    this.selectionMode = false,
    this.onTap,
    this.onLongPress,
    this.onReplyTap,
    this.onImageTap,
    this.onVoiceTap,
    this.playingVoice = false,
  });

  final ChatMessage message;
  final ChatMessage? replyMessage;
  final bool mine;
  final bool focused;
  final bool selected;
  final bool selectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onReplyTap;
  final VoidCallback? onImageTap;
  final VoidCallback? onVoiceTap;
  final bool playingVoice;

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
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: align,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectionMode) ...[
                  Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    '${message.sender}${message.time.isEmpty ? '' : ' · ${message.time}'}',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected || focused
                      ? colors.primary
                      : mine
                      ? colors.primaryContainer
                      : colors.outlineVariant,
                  width: selected || focused ? 2 : 1,
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
                  if (message.voiceUrl.isNotEmpty) ...[
                    _VoiceMessageControl(
                      durationSeconds: message.voiceDuration,
                      playing: playingVoice,
                      onTap: onVoiceTap,
                      foreground: textColor,
                      secondary: secondaryTextColor,
                    ),
                    if (message.body.isNotEmpty &&
                        !message.body.startsWith('[voice]'))
                      const SizedBox(height: 8),
                  ],
                  if (message.body.isNotEmpty &&
                      !message.body.startsWith('[image]') &&
                      !message.body.startsWith('[voice]'))
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

class _PendingMessageBubble extends StatelessWidget {
  const _PendingMessageBubble({required this.pending, required this.onRetry});

  final _PendingSend pending;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final strings = context.strings;
    final failed = pending.status == _PendingSendStatus.failed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            failed ? strings.text('Send failed') : strings.text('Sending...'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: failed ? colors.error : colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: failed ? colors.errorContainer : colors.primaryContainer,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: failed ? colors.error : colors.primaryContainer,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pending.hasImage) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 18,
                        color: failed
                            ? colors.onErrorContainer
                            : colors.onPrimaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          pending.imageName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: failed
                                ? colors.onErrorContainer
                                : colors.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
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
                    onTap: null,
                    foreground: failed
                        ? colors.onErrorContainer
                        : colors.onPrimaryContainer,
                    secondary:
                        (failed
                                ? colors.onErrorContainer
                                : colors.onPrimaryContainer)
                            .withValues(alpha: 0.72),
                  ),
                  if (pending.text.isNotEmpty) const SizedBox(height: 8),
                ],
                if (pending.text.isNotEmpty)
                  Text(
                    pending.text,
                    style: TextStyle(
                      color: failed
                          ? colors.onErrorContainer
                          : colors.onPrimaryContainer,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!failed)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onPrimaryContainer,
                        ),
                      )
                    else
                      Icon(
                        Icons.error_outline,
                        size: 16,
                        color: colors.onErrorContainer,
                      ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        failed && pending.error.isNotEmpty
                            ? compactMessage(pending.error, max: 80)
                            : strings.text('Sending...'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: failed
                              ? colors.onErrorContainer
                              : colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                    if (failed) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(strings.text('Retry send')),
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
    required this.onTap,
    required this.foreground,
    required this.secondary,
  });

  final int durationSeconds;
  final bool playing;
  final VoidCallback? onTap;
  final Color foreground;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final label = formatVoiceDuration(durationSeconds);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 132, maxWidth: 220),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                playing
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_fill_outlined,
                color: foreground,
                size: 30,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: playing ? null : 0,
                    minHeight: 5,
                    color: foreground,
                    backgroundColor: secondary.withValues(alpha: 0.24),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
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

class _GroupAnnouncementBar extends StatelessWidget {
  const _GroupAnnouncementBar({
    required this.announcement,
    required this.onTap,
  });

  final String announcement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final strings = context.strings;
    return Material(
      color: colors.secondaryContainer,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              Icon(Icons.campaign_outlined, color: colors.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.text('Group announcement'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      announcement,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: colors.onSecondaryContainer),
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
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.checklist),
            title: Text(strings.text('Select messages')),
            subtitle: Text(strings.text('Choose multiple messages')),
            onTap: () => Navigator.of(context).pop(_MessageAction.select),
          ),
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
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(strings.text('Report message')),
            onTap: () => Navigator.of(context).pop(_MessageAction.report),
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
            tooltip: context.strings.text('Essence stats'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => EssenceStatsScreen(
                    state: widget.state,
                    conversation: widget.conversation,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.query_stats_outlined),
          ),
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
    final strings = context.strings;
    final loaded = stats;
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('Essence stats'))),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            SegmentedButton<String>(
              segments: [
                for (final type in types)
                  ButtonSegment(
                    value: type,
                    label: Text(strings.text('stats.$type')),
                  ),
              ],
              selected: {selectedType},
              onSelectionChanged: (value) {
                setState(() => selectedType = value.first);
                load();
              },
            ),
            const SizedBox(height: 12),
            if (loading) const LinearProgressIndicator(minHeight: 2),
            if (error != null) _InlineError(message: error!, onRetry: load),
            if (loaded != null) ...[
              GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width > 520 ? 4 : 2,
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
              Card(
                elevation: 0,
                child: ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(strings.text('Latest set time')),
                  subtitle: Text(
                    loaded.latestSetTime.isEmpty
                        ? strings.text('(empty)')
                        : loaded.latestSetTime,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                strings.text('Contribution rank'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (loaded.rank.isEmpty)
                _EmptyPanel(message: strings.text('No rank data.'))
              else
                for (final item in loaded.rank)
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          '${item.rank == 0 ? loaded.rank.indexOf(item) + 1 : item.rank}',
                        ),
                      ),
                      title: Text(item.nickname),
                      subtitle: Text('UID ${item.uid}'),
                      trailing: Text('${item.count}'),
                    ),
                  ),
            ],
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
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
