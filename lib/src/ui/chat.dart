part of '../../main.dart';

enum _PendingSendStatus { sending, failed }

enum _ComposeMenuAction { image, voice, mention }

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
  int initialUnreadCount = 0;
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
  bool showJumpToBottom = false;
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
    initialUnreadCount = widget.conversation.unreadCount;
    widget.state.setActiveConversation(widget.conversation);
    widget.state.markConversationRead(widget.conversation);
    input.addListener(scheduleDraftSave);
    scroll.addListener(handleScrollChanged);
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

  void handleScrollChanged() {
    if (!scroll.hasClients) {
      return;
    }
    final shouldShow = scroll.position.maxScrollExtent - scroll.position.pixels > 280;
    if (shouldShow != showJumpToBottom && mounted) {
      setState(() => showJumpToBottom = shouldShow);
    }
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
    final incoming = messages.where((message) => message.senderId != myUid).toList();
    if (incoming.isEmpty) {
      return null;
    }
    final index = (incoming.length - initialUnreadCount).clamp(0, incoming.length - 1);
    return incoming[index].id;
  }

  bool get canJumpToFirstUnread => firstUnreadMessageId != null;

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
      var extension = Platform.isLinux ? 'wav' : 'm4a';
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
          bitRate: Platform.isAndroid ? 64000 : 128000,
          numChannels: 1,
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
      final fallbackPath = recordingPath;
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
    _showCupertinoToast(context, message);
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
    final response = await widget.state.client.downloadAsset(
      url,
      accept: 'audio/*, application/octet-stream, */*',
    );
    final bytes = response.bodyBytes;
    if (bytes.isEmpty) {
      throw Exception('Empty voice file');
    }
    final fileType = resolveVoiceFileType(
      bytes,
      response.headers['content-type'],
      url,
    );
    if (fileType == null) {
      throw Exception('Downloaded voice is not a playable audio file.');
    }
    final dir = await getTemporaryDirectory();
    final cacheKey = Object.hash(url, bytes.length).toUnsigned(32);
    final file = File(
      p.join(dir.path, 'csac_voice_play_$cacheKey.${fileType.extension}'),
    );
    await file.writeAsBytes(bytes, flush: true);
    return DeviceFileSource(file.path, mimeType: fileType.mimeType);
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
      return const _VoiceFileType('m4a', 'audio/mp4');
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
      case 'application/ogg':
        return const _VoiceFileType('ogg', 'audio/ogg');
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
      case 'audio/amr':
        return const _VoiceFileType('amr', 'audio/amr');
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
    if (path.endsWith('.webm')) {
      return 'audio/webm';
    }
    if (path.endsWith('.mp3') || path.endsWith('.mpeg')) {
      return 'audio/mpeg';
    }
    if (path.endsWith('.3gp') || path.endsWith('.3gpp')) {
      return 'audio/3gpp';
    }
    if (path.endsWith('.amr')) {
      return 'audio/amr';
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
      CupertinoPageRoute<void>(
        builder: (_) => EssenceMessagesScreen(
          state: widget.state,
          conversation: widget.conversation,
        ),
      ),
    );
  }

  Future<void> showMessageActions(ChatMessage message, bool mine) async {
    final action = await showCupertinoModalPopup<_MessageAction>(
      context: context,
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
        _showCupertinoToast(context, context.strings.text('Message copied'));
        break;
      case _MessageAction.copyImage:
        Clipboard.setData(ClipboardData(text: message.imageUrl));
        _showCupertinoToast(context, context.strings.text('Image link copied'));
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
          CupertinoPageRoute<void>(
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
      message: context.strings.text('Only local cached copies will be removed.'),
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
      _showCupertinoToast(
        context,
        context.strings.format('Forward failed: {error}', {'error': err}),
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
      _showCupertinoToast(
        context,
        context.strings.text('Referenced message is not loaded.'),
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

  void jumpToFirstUnread() {
    final id = firstUnreadMessageId;
    if (id == null) {
      return;
    }
    scrollToMessage(id);
  }

  Future<void> showComposeMenu() async {
    final strings = context.strings;
    final action = await _showAdaptiveActionSheet<_ComposeMenuAction>(
      context,
      title: strings.text('More actions'),
      actions: [
        _AdaptiveSheetAction(
          value: _ComposeMenuAction.image,
          label: strings.text('Send image'),
          icon: CupertinoIcons.photo,
        ),
        _AdaptiveSheetAction(
          value: _ComposeMenuAction.voice,
          label: recording ? strings.text('Stop recording') : strings.text('Voice message'),
          icon: recording ? CupertinoIcons.stop_circle : CupertinoIcons.mic,
        ),
        if (widget.conversation.type == ConversationType.group)
          const _AdaptiveSheetAction(
            value: _ComposeMenuAction.mention,
            label: '@',
            icon: CupertinoIcons.at,
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
      case _ComposeMenuAction.voice:
        await toggleRecording();
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
    final showEmpty = !loading && messages.isEmpty && pendingSends.isEmpty;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 600;
    return CupertinoPageScaffold(
      backgroundColor: colors.systemBackground,
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
        middle: Text(
          selectionMode
              ? strings.format('{count} messages selected', {
                  'count': selectedMessageIds.length,
                })
              : widget.conversation.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
                    child: const Icon(CupertinoIcons.arrowshape_turn_up_right, size: 20),
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
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    onPressed: () =>
                        reloadConversationFromNetwork(showLoading: true),
                    child: const Icon(CupertinoIcons.refresh, size: 20),
                  ),
                  if (widget.conversation.type == ConversationType.group)
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      onPressed: openEssenceList,
                      child: const Icon(CupertinoIcons.star, size: 20),
                    ),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    onPressed: openConversationDetails,
                    child: const Icon(CupertinoIcons.info, size: 20),
                  ),
                ],
              ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            if (error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: colors.destructive.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        error!,
                        style: TextStyle(color: colors.destructive, fontSize: 13),
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 28,
                      onPressed: () => setState(() => error = null),
                      child: Text(
                        strings.text('Dismiss'),
                        style: TextStyle(color: colors.destructive, fontSize: 13),
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
            Expanded(
              child: Stack(
                children: [
                  loading
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
                              showReadStatus: widget.conversation.type == ConversationType.private,
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
                  Positioned(
                    top: 56,
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
                              onClearReply: () => setState(() => replyTarget = null),
                              onClearMentions: () =>
                                  setState(() => mentionTargets.clear()),
                            ),
                          Row(
                            children: [
                              _ComposeIconButton(
                                icon: recording ? CupertinoIcons.stop_circle_fill : CupertinoIcons.plus,
                                color: recording ? colors.destructive : null,
                                busy: pickingImage,
                                onPressed: showComposeMenu,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: CupertinoTextField(
                                  controller: input,
                                  minLines: 1,
                                  maxLines: 4,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => send(),
                                  placeholder: strings.text('Message'),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.elevatedBackground,
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: colors.separator.withValues(alpha: 0.35),
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              CupertinoButton.filled(
                                padding: const EdgeInsets.all(8),
                                minSize: 34,
                                borderRadius: BorderRadius.circular(17),
                                onPressed: send,
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
    this.focused = false,
    this.selected = false,
    this.selectionMode = false,
    this.onTap,
    this.onLongPress,
    this.onReplyTap,
    this.onImageTap,
    this.onVoiceTap,
    this.playingVoice = false,
    this.showReadStatus = false,
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
  final bool showReadStatus;

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
    return Padding(
      padding: EdgeInsets.symmetric(vertical: width < 600 ? 3 : 5),
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
                        ? CupertinoIcons.checkmark_circle_fill
                        : CupertinoIcons.circle,
                    size: 18,
                    color: selected ? colors.primaryColor : colors.secondaryLabel,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    '${message.sender}${message.time.isEmpty ? '' : ' · ${message.time}'}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.secondaryLabel,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Container(
              constraints: BoxConstraints(maxWidth: maxBubbleWidth),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: (selected || focused)
                    ? Border.all(color: colors.primaryColor, width: 2)
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
                              : strings.format('Reply {sender}: {message}', {
                                  'sender': replyMessage!.sender,
                                  'message': compactMessage(replyMessage!.body),
                                }),
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: secondaryTextColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.at, size: 12, color: textColor),
                                const SizedBox(width: 2),
                                Text(
                                  strings.text('Mentioned'),
                                  style: TextStyle(fontSize: 11, color: textColor),
                                ),
                              ],
                            ),
                          ),
                        if (message.isEssence)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: secondaryTextColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.star_fill, size: 12, color: textColor),
                                const SizedBox(width: 2),
                                Text(
                                  strings.text('Essence'),
                                  style: TextStyle(fontSize: 11, color: textColor),
                                ),
                              ],
                            ),
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
                    Text(message.body, style: TextStyle(color: textColor, fontSize: 15.5, height: 1.28)),
                ],
              ),
            ),
            if (showReadStatus) ...[
              const SizedBox(height: 3),
              Text(
                message.isRead ? context.strings.text('Read') : context.strings.text('Unread'),
                style: TextStyle(
                  fontSize: 11,
                  color: message.isRead ? colors.primaryColor : colors.tertiaryLabel,
                ),
              ),
            ],
          ],
        ),
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
      minSize: 36,
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
          minSize: 0,
          onPressed: onPressed,
          child: Container(
            height: 36,
            padding: EdgeInsets.symmetric(horizontal: label == null ? 10 : 12),
            decoration: BoxDecoration(
              color: colors.floatingTabBarBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.separator.withValues(alpha: 0.35), width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withValues(alpha: colors.isDark ? 0.28 : 0.10),
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
    final bubbleColor = failed ? colors.destructive.withValues(alpha: 0.15) : colors.myBubble;
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
            constraints: BoxConstraints(maxWidth: width < 600 ? width * 0.76 : 440),
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
                    onTap: null,
                    foreground: textColor,
                    secondary: textColor.withValues(alpha: 0.72),
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
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (failed) ...[
                      const SizedBox(width: 8),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minSize: 0,
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
    return GestureDetector(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 132, maxWidth: 220),
        child: Padding(
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
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: secondary.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.centerLeft,
                    child: playing
                        ? const SizedBox.expand(
                            child: CupertinoActivityIndicator(radius: 2),
                          )
                        : const SizedBox.shrink(),
                  ),
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
            Icon(CupertinoIcons.speaker_2, color: colors.systemOrange, size: 20),
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
            Icon(CupertinoIcons.chevron_right, color: colors.secondaryLabel, size: 16),
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
        if (message.imageUrl.isNotEmpty)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(_MessageAction.copyImage),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.link, size: 20),
                const SizedBox(width: 8),
                Text(strings.text('Copy image link')),
              ],
            ),
          ),
        if (message.imageUrl.isNotEmpty)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(_MessageAction.openImage),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.arrow_up_right_square, size: 20),
                const SizedBox(width: 8),
                Text(strings.text('Open image')),
              ],
            ),
          ),
        if (message.imageUrl.isNotEmpty)
          CupertinoActionSheetAction(
            onPressed: () => Navigator.of(context).pop(_MessageAction.downloadImage),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.cloud_download, size: 20),
                const SizedBox(width: 8),
                Text(strings.text('Download image')),
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
                  message.isEssence ? CupertinoIcons.star_fill : CupertinoIcons.star,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(strings.text(
                  message.isEssence ? 'Remove essence' : 'Set essence',
                )),
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
                  Icon(CupertinoIcons.reply, size: 14, color: colors.secondaryLabel),
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
                    child: Icon(CupertinoIcons.xmark_circle_fill, size: 16, color: colors.secondaryLabel),
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
                  Icon(CupertinoIcons.at, size: 14, color: colors.secondaryLabel),
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
                    child: Icon(CupertinoIcons.xmark_circle_fill, size: 16, color: colors.secondaryLabel),
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
                    minSize: 0,
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                    style: TextStyle(fontSize: 13, color: colors.secondaryLabel),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text(strings.text('Cancel')),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton.filled(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
    return Navigator.of(context).push(
      CupertinoPageRoute<void>(
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
                Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => EssenceStatsScreen(
                      state: widget.state,
                      conversation: widget.conversation,
                    ),
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
        top: false,
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
                  if (error != null) _InlineError(message: error!, onRetry: load),
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
                              Icon(CupertinoIcons.star, size: 20, color: colors.systemOrange),
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
                                        if (message.time.isNotEmpty) message.time,
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
                              Icon(CupertinoIcons.chevron_right, size: 16, color: colors.tertiaryLabel),
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
        top: false,
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Text(strings.text('stats.$type'), style: const TextStyle(fontSize: 13)),
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.cardBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.clock, size: 20, color: colors.secondaryLabel),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strings.text('Latest set time'),
                                  style: TextStyle(fontSize: 15, color: colors.label),
                                ),
                                Text(
                                  loaded.latestSetTime.isEmpty
                                      ? strings.text('(empty)')
                                      : loaded.latestSetTime,
                                  style: TextStyle(fontSize: 13, color: colors.secondaryLabel),
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
                                  color: colors.primaryColor.withValues(alpha: 0.12),
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
                                      style: TextStyle(fontSize: 15, color: colors.label),
                                    ),
                                    Text(
                                      'UID ${item.uid}',
                                      style: TextStyle(fontSize: 12, color: colors.secondaryLabel),
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
