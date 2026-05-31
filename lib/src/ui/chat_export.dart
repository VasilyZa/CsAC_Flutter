part of '../../main.dart';

enum ChatExportFormat { txt, html, json }

class ChatExportOptions {
  const ChatExportOptions({required this.format, required this.includeMedia});

  final ChatExportFormat format;
  final bool includeMedia;
}

class ChatExportResult {
  const ChatExportResult({
    required this.filePath,
    required this.messageCount,
    required this.mediaCount,
    required this.mediaFailures,
  });

  final String filePath;
  final int messageCount;
  final int mediaCount;
  final int mediaFailures;
}

class _ChatExportMediaRef {
  const _ChatExportMediaRef({
    required this.url,
    required this.kind,
    required this.relativePath,
    required this.fileName,
    this.error = '',
  });

  final String url;
  final String kind;
  final String relativePath;
  final String fileName;
  final String error;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'kind': kind,
      'url': url,
      'file_name': fileName,
      'relative_path': relativePath,
      if (error.isNotEmpty) 'error': error,
    };
  }
}

extension _ChatExport on _ChatScreenState {
  Future<void> exportConversation() async {
    final options = await showChatExportOptions();
    if (!mounted || options == null) {
      return;
    }
    var directory = '';
    if (!isWebPlatform) {
      final pickedDirectory = await getDirectoryPath(
        confirmButtonText: context.strings.text('Choose export folder'),
        canCreateDirectories: true,
      );
      directory = pickedDirectory ?? '';
    }
    if (!mounted || (!isWebPlatform && directory.trim().isEmpty)) {
      return;
    }
    setExporting(true);
    try {
      final result = await writeChatExport(directory, options);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.format('Chat exported to {path}', {
              'path': result.filePath,
            }),
          ),
        ),
      );
    } catch (err) {
      if (!mounted) {
        return;
      }
      final message = err is StateError ? err.message : err.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.strings.format('Export failed: {error}', {
              'error': message,
            }),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setExporting(false);
      }
    }
  }

  Future<ChatExportOptions?> showChatExportOptions() async {
    var format = ChatExportFormat.html;
    var includeMedia = false;
    return showDialog<ChatExportOptions>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.strings.text('Export chat history')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<ChatExportFormat>(
                segments: [
                  ButtonSegment(
                    value: ChatExportFormat.txt,
                    label: Text(context.strings.text('TXT')),
                  ),
                  ButtonSegment(
                    value: ChatExportFormat.html,
                    label: Text(context.strings.text('HTML')),
                  ),
                  ButtonSegment(
                    value: ChatExportFormat.json,
                    label: Text(context.strings.text('JSON')),
                  ),
                ],
                selected: {format},
                onSelectionChanged: (value) {
                  setDialogState(() => format = value.first);
                },
              ),
              const SizedBox(height: 12),
              _DialogCheckRow(
                value: includeMedia,
                title: context.strings.text('Download media files'),
                subtitle: context.strings.text(
                  'Images, voices and files will be saved beside the export.',
                ),
                onChanged: (value) {
                  setDialogState(() => includeMedia = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.strings.text('Cancel')),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(
                ChatExportOptions(
                  format: format,
                  includeMedia: includeMedia && supportsLocalFiles,
                ),
              ),
              icon: const Icon(Icons.ios_share_outlined),
              label: Text(context.strings.text('Export')),
            ),
          ],
        ),
      ),
    );
  }

  Future<ChatExportResult> writeChatExport(
    String directory,
    ChatExportOptions options,
  ) async {
    final noMessagesText = context.strings.text(
      'No cached messages to export.',
    );
    final cachedMessages = await widget.state.loadAllCachedMessages(
      widget.conversation,
    );
    final allMessages = mergeChatMessages(cachedMessages, messages);
    if (allMessages.isEmpty) {
      throw StateError(noMessagesText);
    }
    final baseName =
        'csac_${widget.conversation.type.name}_${widget.conversation.id}_'
        '${_exportTimestamp()}';
    final extension = switch (options.format) {
      ChatExportFormat.txt => 'txt',
      ChatExportFormat.html => 'html',
      ChatExportFormat.json => 'json',
    };
    final mediaRefs = <int, List<_ChatExportMediaRef>>{};
    if (options.includeMedia) {
      final mediaDirectoryPath = p.join(directory, '${baseName}_media');
      await ensureDirectoryExists(mediaDirectoryPath);
      for (final message in allMessages) {
        mediaRefs[message.id] = await downloadMessageMedia(
          message,
          mediaDirectoryPath,
        );
      }
    }
    final result = await writeChatExportFile(
      directory: directory,
      baseName: baseName,
      extension: extension,
      content: switch (options.format) {
        ChatExportFormat.txt => buildTxtExport(allMessages, mediaRefs),
        ChatExportFormat.html => buildHtmlExport(allMessages, mediaRefs),
        ChatExportFormat.json => buildJsonExport(allMessages, mediaRefs),
      },
    );
    final refs = mediaRefs.values.expand((items) => items).toList();
    return ChatExportResult(
      filePath: result.filePath,
      messageCount: allMessages.length,
      mediaCount: refs.where((ref) => ref.relativePath.isNotEmpty).length,
      mediaFailures: refs.where((ref) => ref.error.isNotEmpty).length,
    );
  }

  Future<List<_ChatExportMediaRef>> downloadMessageMedia(
    ChatMessage message,
    String mediaDirectoryPath,
  ) async {
    final targets = <({String kind, String url, String accept})>[
      if (message.imageUrl.isNotEmpty)
        (kind: 'image', url: message.imageUrl, accept: 'image/*, */*'),
      if (message.voiceUrl.isNotEmpty)
        (
          kind: 'voice',
          url: message.voiceUrl,
          accept: 'audio/*, application/octet-stream, */*',
        ),
      if (message.fileUrl.isNotEmpty)
        (
          kind: 'file',
          url: message.fileUrl,
          accept: 'application/octet-stream, */*',
        ),
    ];
    final refs = <_ChatExportMediaRef>[];
    for (final target in targets) {
      final originalName = fileNameFromUrl(target.url);
      final fallbackExtension = switch (target.kind) {
        'image' => '.jpg',
        'voice' => '.wav',
        _ => '.bin',
      };
      final extension = p.extension(originalName).isEmpty
          ? fallbackExtension
          : p.extension(originalName);
      final fileName =
          'msg_${message.id}_${target.kind}${_safeFileExtension(extension)}';
      try {
        final bytes = await widget.state.client.getBinary(
          target.url,
          accept: target.accept,
        );
        final relativePath = await writeChatExportMediaFile(
          mediaDirectoryPath: mediaDirectoryPath,
          fileName: fileName,
          bytes: bytes,
        );
        refs.add(
          _ChatExportMediaRef(
            url: target.url,
            kind: target.kind,
            relativePath: relativePath,
            fileName: fileName,
          ),
        );
      } catch (err) {
        refs.add(
          _ChatExportMediaRef(
            url: target.url,
            kind: target.kind,
            relativePath: '',
            fileName: fileName,
            error: err.toString(),
          ),
        );
      }
    }
    return refs;
  }

  String buildTxtExport(
    List<ChatMessage> allMessages,
    Map<int, List<_ChatExportMediaRef>> mediaRefs,
  ) {
    final buffer = StringBuffer()
      ..writeln('CsAC chat export')
      ..writeln('Conversation: ${widget.conversation.name}')
      ..writeln('Type: ${widget.conversation.type.name}')
      ..writeln('ID: ${widget.conversation.id}')
      ..writeln('Exported at: ${formatLocalDateTime(DateTime.now())}')
      ..writeln();
    for (final message in allMessages) {
      buffer
        ..writeln(
          '[${exportMessageTime(message)}] ${message.sender} #${message.id}',
        )
        ..writeln(message.body);
      for (final ref
          in mediaRefs[message.id] ?? const <_ChatExportMediaRef>[]) {
        buffer.writeln(
          '${ref.kind}: ${ref.relativePath.isEmpty ? ref.url : ref.relativePath}',
        );
        if (ref.error.isNotEmpty) {
          buffer.writeln('download_error: ${ref.error}');
        }
      }
      if (message.imageUrl.isNotEmpty &&
          !(mediaRefs[message.id] ?? const <_ChatExportMediaRef>[]).any(
            (ref) => ref.kind == 'image',
          )) {
        buffer.writeln('image: ${message.imageUrl}');
      }
      if (message.voiceUrl.isNotEmpty &&
          !(mediaRefs[message.id] ?? const <_ChatExportMediaRef>[]).any(
            (ref) => ref.kind == 'voice',
          )) {
        buffer.writeln('voice: ${message.voiceUrl}');
      }
      if (message.fileUrl.isNotEmpty &&
          !(mediaRefs[message.id] ?? const <_ChatExportMediaRef>[]).any(
            (ref) => ref.kind == 'file',
          )) {
        buffer.writeln('file: ${message.fileUrl}');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  String buildHtmlExport(
    List<ChatMessage> allMessages,
    Map<int, List<_ChatExportMediaRef>> mediaRefs,
  ) {
    final title = htmlEscape.convert(widget.conversation.name);
    final buffer = StringBuffer()
      ..writeln('<!doctype html>')
      ..writeln('<html lang="en">')
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8">')
      ..writeln(
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
      )
      ..writeln('<title>$title - CsAC export</title>')
      ..writeln('<style>')
      ..writeln(
        'body{font-family:system-ui,-apple-system,Segoe UI,sans-serif;margin:24px;background:#f6f7f9;color:#1b1c1f;}',
      )
      ..writeln(
        'main{max-width:860px;margin:auto;} .msg{background:white;border:1px solid #dde1e6;border-radius:12px;padding:14px;margin:12px 0;}',
      )
      ..writeln(
        '.meta{color:#5b616e;font-size:13px;margin-bottom:8px;} .body{white-space:pre-wrap;line-height:1.45;}',
      )
      ..writeln(
        '.media{margin-top:10px;font-size:14px;} img{max-width:320px;max-height:320px;border-radius:8px;display:block;margin-top:6px;}',
      )
      ..writeln('</style>')
      ..writeln('</head><body><main>')
      ..writeln('<h1>$title</h1>')
      ..writeln(
        '<p>CsAC chat export · ${htmlEscape.convert(formatLocalDateTime(DateTime.now()))}</p>',
      );
    for (final message in allMessages) {
      buffer
        ..writeln('<article class="msg">')
        ..writeln(
          '<div class="meta">${htmlEscape.convert(exportMessageTime(message))} · '
          '${htmlEscape.convert(message.sender)} · #${message.id}</div>',
        )
        ..writeln(
          '<div class="body">${htmlEscape.convert(message.body)}</div>',
        );
      final refs = mediaRefs[message.id] ?? const <_ChatExportMediaRef>[];
      for (final ref in refs) {
        final href = htmlEscape.convert(
          ref.relativePath.isEmpty ? ref.url : ref.relativePath,
        );
        final label = htmlEscape.convert(ref.kind);
        buffer.writeln('<div class="media"><a href="$href">$label</a>');
        if (ref.kind == 'image' && ref.relativePath.isNotEmpty) {
          buffer.writeln('<img src="$href" alt="image">');
        }
        if (ref.error.isNotEmpty) {
          buffer.writeln(
            '<div>download error: ${htmlEscape.convert(ref.error)}</div>',
          );
        }
        buffer.writeln('</div>');
      }
      if (refs.isEmpty) {
        for (final item in [
          (kind: 'image', url: message.imageUrl),
          (kind: 'voice', url: message.voiceUrl),
          (kind: 'file', url: message.fileUrl),
        ]) {
          if (item.url.isEmpty) {
            continue;
          }
          final href = htmlEscape.convert(item.url);
          buffer.writeln(
            '<div class="media"><a href="$href">${htmlEscape.convert(item.kind)}</a></div>',
          );
        }
      }
      buffer.writeln('</article>');
    }
    buffer.writeln('</main></body></html>');
    return buffer.toString();
  }

  String buildJsonExport(
    List<ChatMessage> allMessages,
    Map<int, List<_ChatExportMediaRef>> mediaRefs,
  ) {
    return const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'app': 'CsAC',
      'exported_at': formatLocalDateTime(DateTime.now()),
      'conversation': <String, Object?>{
        'type': widget.conversation.type.name,
        'id': widget.conversation.id,
        'name': widget.conversation.name,
        'subtitle': widget.conversation.subtitle,
      },
      'messages': [
        for (final message in allMessages)
          <String, Object?>{
            'id': message.id,
            'sender_id': message.senderId,
            'sender': message.sender,
            'time': exportMessageTime(message),
            'body': message.body,
            'image_url': message.imageUrl,
            'voice_url': message.voiceUrl,
            'voice_duration': message.voiceDuration,
            'file_url': message.fileUrl,
            'file_name': message.fileName,
            'is_recalled': message.isRecalled,
            'is_essence': message.isEssence,
            'is_mentioned': message.isMentioned,
            'reply_to': message.replyTo,
            'media': [
              for (final ref
                  in mediaRefs[message.id] ?? const <_ChatExportMediaRef>[])
                ref.toJson(),
            ],
          },
      ],
    });
  }

  String exportMessageTime(ChatMessage message) {
    return displayMessageTime(
      message,
      widget.state.preferences,
    ).ifEmpty(message.time);
  }
}

String _exportTimestamp() {
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${now.year}${two(now.month)}${two(now.day)}_'
      '${two(now.hour)}${two(now.minute)}${two(now.second)}';
}

String _safeFileExtension(String extension) {
  final normalized = extension.trim().toLowerCase();
  if (RegExp(r'^\.[a-z0-9]{1,10}$').hasMatch(normalized)) {
    return normalized;
  }
  return '.bin';
}
