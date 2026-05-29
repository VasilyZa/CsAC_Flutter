part of '../../main.dart';

class ChatArchiveScreen extends StatefulWidget {
  const ChatArchiveScreen({
    super.key,
    required this.state,
    required this.conversation,
  });

  final CsacAppState state;
  final Conversation conversation;

  @override
  State<ChatArchiveScreen> createState() => _ChatArchiveScreenState();
}

class _ChatArchiveScreenState extends State<ChatArchiveScreen> {
  String format = 'md';
  bool includeMedia = false;
  bool exporting = false;
  String exportedPath = '';
  String? error;

  void changeFormat(String? value) {
    if (exporting || value == null) {
      return;
    }
    setState(() => format = value);
  }

  Future<void> exportArchive() async {
    final strings = context.strings;
    setState(() {
      exporting = true;
      error = null;
      exportedPath = '';
    });
    try {
      final messages = await widget.state.loadAllCachedMessages(
        widget.conversation,
      );
      if (messages.isEmpty) {
        throw Exception(strings.text('No cached messages to export.'));
      }
      final activeFormat = format;
      final safeName = sanitizedFileName(
        widget.conversation.name,
      ).replaceAll(' ', '_');
      final baseName =
          'CsAC_${safeName}_${DateTime.now().millisecondsSinceEpoch}';
      String path;
      Directory? mediaDir;
      if (Platform.isAndroid || Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        final exportDir = Directory(p.join(directory.path, 'CsAC Archives'));
        await exportDir.create(recursive: true);
        path = p.join(exportDir.path, '$baseName.$activeFormat');
        if (includeMedia) {
          mediaDir = Directory(p.join(exportDir.path, '${baseName}_media'));
          await mediaDir.create(recursive: true);
        }
      } else {
        final location = await getSaveLocation(
          suggestedName: '$baseName.$activeFormat',
          acceptedTypeGroups: <XTypeGroup>[
            XTypeGroup(
              label: strings.text('Chat archives'),
              extensions: archiveExtensions,
            ),
          ],
        );
        if (location == null) {
          if (mounted) {
            _showCupertinoToast(context, strings.text('Download cancelled.'));
          }
          return;
        }
        path = p.extension(location.path).isEmpty
            ? '${location.path}.$activeFormat'
            : location.path;
        if (includeMedia) {
          mediaDir = Directory(
            p.join(
              p.dirname(path),
              '${p.basenameWithoutExtension(path)}_media',
            ),
          );
          await mediaDir.create(recursive: true);
        }
      }
      final mediaRefs = includeMedia && mediaDir != null
          ? await downloadArchiveMedia(messages, mediaDir)
          : <int, List<_ArchiveMediaRef>>{};
      final content = switch (activeFormat) {
        'html' => buildHtmlArchive(messages, mediaRefs),
        'json' => buildJsonArchive(messages, mediaRefs),
        _ => buildMarkdownArchive(messages, mediaRefs),
      };
      await File(path).writeAsString(content, flush: true);
      if (!mounted) {
        return;
      }
      setState(() => exportedPath = path);
      _showCupertinoToast(
        context,
        strings.format('Chat archive saved to {path}', {'path': path}),
      );
    } catch (err) {
      if (mounted) {
        setState(() => error = err.toString());
      }
    } finally {
      if (mounted) {
        setState(() => exporting = false);
      }
    }
  }

  Future<Map<int, List<_ArchiveMediaRef>>> downloadArchiveMedia(
    List<ChatMessage> messages,
    Directory mediaDir,
  ) async {
    final refs = <int, List<_ArchiveMediaRef>>{};
    Future<void> add(
      ChatMessage message,
      ConversationMediaKind kind,
      String url,
      String name,
    ) async {
      final bytes = await downloadMediaBytes(widget.state, url, kind: kind);
      final fileName = sanitizedFileName(name);
      final path = p.join(mediaDir.path, '${message.id}_$fileName');
      await File(path).writeAsBytes(bytes, flush: true);
      refs
          .putIfAbsent(message.id, () => <_ArchiveMediaRef>[])
          .add(
            _ArchiveMediaRef(
              kind: kind.name,
              url: url,
              relativePath: '${p.basename(mediaDir.path)}/${p.basename(path)}',
            ),
          );
    }

    for (final message in messages) {
      if (message.imageUrl.isNotEmpty) {
        await add(
          message,
          ConversationMediaKind.image,
          message.imageUrl,
          fileNameFromUrl(message.imageUrl).ifEmpty('image.jpg'),
        );
      }
      if (message.voiceUrl.isNotEmpty) {
        await add(
          message,
          ConversationMediaKind.voice,
          message.voiceUrl,
          fileNameFromUrl(message.voiceUrl).ifEmpty('voice.m4a'),
        );
      }
      if (message.fileUrl.isNotEmpty) {
        await add(
          message,
          ConversationMediaKind.file,
          message.fileUrl,
          message.fileName
              .ifEmpty(fileNameFromUrl(message.fileUrl))
              .ifEmpty('file'),
        );
      }
    }
    return refs;
  }

  String buildMarkdownArchive(
    List<ChatMessage> messages,
    Map<int, List<_ArchiveMediaRef>> refs,
  ) {
    final buffer = StringBuffer()
      ..writeln('# ${widget.conversation.name}')
      ..writeln()
      ..writeln('Generated by CsAC')
      ..writeln();
    for (final message in messages) {
      buffer.writeln('## #${message.id} ${message.sender}');
      if (message.time.isNotEmpty) buffer.writeln('- Time: ${message.time}');
      if (message.body.trim().isNotEmpty && !message.body.startsWith('[')) {
        buffer.writeln();
        buffer.writeln(message.body.trim());
      }
      for (final ref in refs[message.id] ?? const <_ArchiveMediaRef>[]) {
        buffer.writeln('- ${ref.kind}: ${ref.relativePath}');
      }
      if ((refs[message.id] ?? const <_ArchiveMediaRef>[]).isEmpty) {
        if (message.imageUrl.isNotEmpty) {
          buffer.writeln('- image: ${message.imageUrl}');
        }
        if (message.voiceUrl.isNotEmpty) {
          buffer.writeln('- voice: ${message.voiceUrl}');
        }
        if (message.fileUrl.isNotEmpty) {
          buffer.writeln('- file: ${message.fileUrl}');
        }
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  String buildHtmlArchive(
    List<ChatMessage> messages,
    Map<int, List<_ArchiveMediaRef>> refs,
  ) {
    final buffer = StringBuffer()
      ..writeln('<!doctype html><html><head><meta charset="utf-8">')
      ..writeln('<title>${escapeHtml(widget.conversation.name)}</title>')
      ..writeln('<style>')
      ..writeln('body{font-family:-apple-system,BlinkMacSystemFont,sans-serif;')
      ..writeln('background:#f5f5f7;color:#111;margin:0;padding:28px}')
      ..writeln('.msg{background:white;border-radius:18px;padding:14px 16px;')
      ..writeln(
        'margin:10px auto;max-width:760px;box-shadow:0 8px 26px rgba(0,0,0,.06)}',
      )
      ..writeln('.meta{font-size:12px;color:#6e6e73;margin-bottom:8px}')
      ..writeln('.body{white-space:pre-wrap;line-height:1.45}')
      ..writeln('.media{font-size:13px;margin-top:8px}')
      ..writeln(
        'img{max-width:320px;border-radius:12px;display:block;margin-top:8px}',
      )
      ..writeln('</style>')
      ..writeln(
        '</head><body><h1>${escapeHtml(widget.conversation.name)}</h1>',
      );
    for (final message in messages) {
      buffer.writeln('<section class="msg">');
      final meta =
          '#${message.id} ${escapeHtml(message.sender)} '
          '${escapeHtml(message.time)}';
      buffer.writeln('<div class="meta">$meta</div>');
      if (message.body.trim().isNotEmpty && !message.body.startsWith('[')) {
        buffer.writeln(
          '<div class="body">${escapeHtml(message.body.trim())}</div>',
        );
      }
      final messageRefs = refs[message.id] ?? const <_ArchiveMediaRef>[];
      if (messageRefs.isNotEmpty) {
        for (final ref in messageRefs) {
          if (ref.kind == 'image') {
            buffer.writeln('<img src="${escapeHtml(ref.relativePath)}">');
          } else {
            final path = escapeHtml(ref.relativePath);
            buffer.writeln(
              '<div class="media">${escapeHtml(ref.kind)}: <a href="$path">$path</a></div>',
            );
          }
        }
      } else {
        if (message.imageUrl.isNotEmpty) {
          buffer.writeln(
            '<div class="media">image: ${escapeHtml(message.imageUrl)}</div>',
          );
        }
        if (message.voiceUrl.isNotEmpty) {
          buffer.writeln(
            '<div class="media">voice: ${escapeHtml(message.voiceUrl)}</div>',
          );
        }
        if (message.fileUrl.isNotEmpty) {
          buffer.writeln(
            '<div class="media">file: ${escapeHtml(message.fileUrl)}</div>',
          );
        }
      }
      buffer.writeln('</section>');
    }
    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  String buildJsonArchive(
    List<ChatMessage> messages,
    Map<int, List<_ArchiveMediaRef>> refs,
  ) {
    final data = {
      'conversation': {
        'type': widget.conversation.type.name,
        'id': widget.conversation.id,
        'name': widget.conversation.name,
      },
      'messages': [
        for (final message in messages)
          {
            'id': message.id,
            'sender_id': message.senderId,
            'sender': message.sender,
            'body': message.body,
            'time': message.time,
            'raw_time': message.rawTime,
            'image_url': message.imageUrl,
            'voice_url': message.voiceUrl,
            'voice_duration': message.voiceDuration,
            'file_url': message.fileUrl,
            'file_name': message.fileName,
            'media': [
              for (final ref in refs[message.id] ?? const <_ArchiveMediaRef>[])
                {
                  'kind': ref.kind,
                  'url': ref.url,
                  'relative_path': ref.relativePath,
                },
            ],
          },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  String escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    final strings = context.strings;
    return CupertinoPageScaffold(
      backgroundColor: colors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        border: null,
        backgroundColor: colors.navBarBackground,
        middle: Text(strings.text('Create chat archive')),
      ),
      child: SafeArea(
        child: _AdaptivePageFrame(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.conversation.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: colors.label,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          strings.text(
                            'Package this chat into a portable archive.',
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.secondaryLabel,
                          ),
                        ),
                        const SizedBox(height: 14),
                        CupertinoSlidingSegmentedControl<String>(
                          groupValue: format,
                          children: const {
                            'md': Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Text('Markdown'),
                            ),
                            'html': Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Text('HTML'),
                            ),
                            'json': Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Text('JSON'),
                            ),
                          },
                          onValueChanged: changeFormat,
                        ),
                      ],
                    ),
                  ),
                  _ChatOptionSwitchTile(
                    icon: CupertinoIcons.paperclip,
                    title: strings.text('Download media files'),
                    subtitle: strings.text(
                      'Images, voices and files will be saved beside the archive.',
                    ),
                    value: includeMedia,
                    onChanged: exporting
                        ? (_) {}
                        : (value) => setState(() => includeMedia = value),
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                _InlineError(message: error!, onRetry: exportArchive),
              ],
              if (exportedPath.isNotEmpty) ...[
                const SizedBox(height: 12),
                _CupertinoGroupedCard(
                  margin: EdgeInsets.zero,
                  children: [
                    _CupertinoListTile(
                      leading: Icon(
                        CupertinoIcons.checkmark_circle,
                        color: colors.systemGreen,
                      ),
                      title: strings.text('Archive ready'),
                      subtitle: exportedPath,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: exportedPath));
                        _showCupertinoToast(
                          context,
                          strings.text('Path copied.'),
                        );
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: exporting ? null : exportArchive,
                child: exporting
                    ? const CupertinoActivityIndicator(
                        color: CupertinoColors.white,
                      )
                    : Text(strings.text('Create archive')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArchiveMediaRef {
  const _ArchiveMediaRef({
    required this.kind,
    required this.url,
    required this.relativePath,
  });

  final String kind;
  final String url;
  final String relativePath;
}
