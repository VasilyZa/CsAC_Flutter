part of '../../main.dart';

class _MessageImage extends StatelessWidget {
  const _MessageImage({required this.url, this.onTap});

  final String url;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return _CsacPressable(
      onTap: onTap,
      scale: 0.975,
      child: Hero(
        tag: 'image-preview-$url',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            width: 260,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 260,
                height: 120,
                decoration: BoxDecoration(
                  color: colors.elevatedBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  CupertinoIcons.photo,
                  size: 42,
                  color: CupertinoColors.secondaryLabel,
                ),
              );
            },
            loadingBuilder: (context, child, progress) {
              if (progress == null) {
                return child;
              }
              return Container(
                width: 260,
                height: 120,
                alignment: Alignment.center,
                child: const CupertinoActivityIndicator(),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ImageCaptionDialog extends StatefulWidget {
  const _ImageCaptionDialog({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;

  @override
  State<_ImageCaptionDialog> createState() => _ImageCaptionDialogState();
}

class _ImageCaptionDialogState extends State<_ImageCaptionDialog> {
  final caption = TextEditingController();

  @override
  void dispose() {
    caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return CupertinoAlertDialog(
      title: Text(
        strings.format('Send image: {fileName}', {'fileName': widget.fileName}),
      ),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 260,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: colors.elevatedBackground,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.memory(
                widget.bytes,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  CupertinoIcons.photo,
                  size: 48,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ),
            const SizedBox(height: 14),
            CupertinoTextField(
              controller: caption,
              maxLines: 3,
              placeholder: strings.text('Caption'),
              padding: const EdgeInsets.all(12),
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(strings.text('Cancel')),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(context).pop(caption.text),
          child: Text(strings.text('Send')),
        ),
      ],
    );
  }
}

void showImagePreview(BuildContext context, String url) {
  final strings = context.strings;
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: CupertinoColors.black,
      transitionDuration: _csacMotionMedium,
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return CupertinoPageScaffold(
          backgroundColor: CupertinoColors.black,
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.7,
                    maxScale: 5,
                    child: Hero(
                      tag: 'image-preview-$url',
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          CupertinoIcons.photo,
                          size: 64,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _FrostedGlassButton(
                    icon: CupertinoIcons.xmark,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Row(
                    children: [
                      _FrostedGlassButton(
                        icon: CupertinoIcons.doc_on_doc,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: url));
                          _showCupertinoToast(
                            context,
                            strings.text('Image link copied'),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _FrostedGlassButton(
                        icon: CupertinoIcons.arrow_up_right_square,
                        onPressed: () => launchUrl(
                          Uri.parse(url),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FrostedGlassButton(
                        icon: CupertinoIcons.arrow_down_to_line,
                        onPressed: () => downloadImage(context, url),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: _csacEaseOut);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

class _FrostedGlassButton extends StatelessWidget {
  const _FrostedGlassButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: CupertinoButton(
          padding: const EdgeInsets.all(10),
          color: CupertinoColors.systemGrey.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
          minimumSize: const Size.square(36),
          onPressed: onPressed,
          child: Icon(icon, size: 20, color: CupertinoColors.white),
        ),
      ),
    );
  }
}

Future<void> downloadImage(BuildContext context, String url) async {
  final strings = context.strings;
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final uri = Uri.parse(url);
    final ext = normalizedImageExtension(uri.path);
    final fileName = 'csac_${DateTime.now().millisecondsSinceEpoch}$ext';
    final String path;
    if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      final imagesDirectory = Directory(p.join(directory.path, 'CsAC Images'));
      await imagesDirectory.create(recursive: true);
      path = p.join(imagesDirectory.path, fileName);
      await File(path).writeAsBytes(response.bodyBytes);
    } else {
      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: <XTypeGroup>[
          XTypeGroup(
            label: strings.text('Images'),
            extensions: imageExtensions,
          ),
        ],
      );
      if (location == null) {
        if (context.mounted) {
          _showCupertinoToast(context, strings.text('Download cancelled.'));
        }
        return;
      }
      path = _pathWithImageExtension(location, ext);
      final imageFile = XFile.fromData(
        response.bodyBytes,
        name: p.basename(path),
        mimeType: mimeTypeForExtension(p.extension(path)),
      );
      await imageFile.saveTo(path);
    }
    if (!context.mounted) {
      return;
    }
    _showCupertinoToast(
      context,
      strings.format('Saved to {path}', {'path': path}),
    );
  } catch (err) {
    if (!context.mounted) {
      return;
    }
    _showCupertinoToast(
      context,
      strings.format('Download failed: {error}', {'error': err}),
    );
  }
}

String _pathWithImageExtension(FileSaveLocation location, String fallbackExt) {
  if (p.extension(location.path).isNotEmpty) {
    return location.path;
  }
  final activeExt = location.activeFilter?.extensions?.firstOrNull;
  return '${location.path}.${activeExt ?? fallbackExt.replaceFirst('.', '')}';
}

const imageExtensions = <String>['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];

String normalizedImageExtension(String path) {
  final ext = p.extension(path).toLowerCase();
  if (ext.isEmpty) {
    return '.jpg';
  }
  final bare = ext.replaceFirst('.', '');
  if (imageExtensions.contains(bare)) {
    return ext;
  }
  return '.jpg';
}

String mimeTypeForExtension(String extension) {
  switch (extension.toLowerCase().replaceFirst('.', '')) {
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'bmp':
      return 'image/bmp';
    case 'jpg':
    case 'jpeg':
    default:
      return 'image/jpeg';
  }
}

const voiceExtensions = <String>[
  'm4a',
  'mp4',
  'aac',
  'wav',
  'ogg',
  'webm',
  'mp3',
  'mpeg',
  'amr',
  '3gp',
];

const archiveExtensions = <String>['md', 'html', 'json'];

String mediaTypeLabel(BuildContext context, ConversationMediaKind kind) {
  final strings = context.strings;
  switch (kind) {
    case ConversationMediaKind.image:
      return strings.text('Images');
    case ConversationMediaKind.voice:
      return strings.text('Voices');
    case ConversationMediaKind.file:
      return strings.text('Files');
    case ConversationMediaKind.all:
      return strings.text('All');
  }
}

IconData mediaKindIcon(ConversationMediaKind kind) {
  switch (kind) {
    case ConversationMediaKind.image:
      return CupertinoIcons.photo;
    case ConversationMediaKind.voice:
      return CupertinoIcons.waveform_circle;
    case ConversationMediaKind.file:
      return CupertinoIcons.doc;
    case ConversationMediaKind.all:
      return CupertinoIcons.collections;
  }
}

String mediaFileName(ConversationMediaItem item) {
  final title = item.title.trim();
  if (title.isNotEmpty &&
      item.kind == ConversationMediaKind.file &&
      !title.contains(':')) {
    return title;
  }
  final fromUrl = fileNameFromUrl(item.url);
  if (fromUrl.isNotEmpty) {
    return fromUrl;
  }
  switch (item.kind) {
    case ConversationMediaKind.image:
      return 'image_${item.message.id}.jpg';
    case ConversationMediaKind.voice:
      return 'voice_${item.message.id}.m4a';
    case ConversationMediaKind.file:
      return 'file_${item.message.id}';
    case ConversationMediaKind.all:
      return 'media_${item.message.id}';
  }
}

String sanitizedFileName(String value) {
  final cleaned = value
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
      .replaceAll(RegExp(r'\s+'), ' ');
  return cleaned.isEmpty ? 'file' : cleaned;
}

String mimeTypeForVoiceExtension(String extension) {
  switch (extension.toLowerCase().replaceFirst('.', '')) {
    case 'wav':
      return 'audio/wav';
    case 'ogg':
      return 'audio/ogg';
    case 'webm':
      return 'audio/webm';
    case 'mp3':
    case 'mpeg':
      return 'audio/mpeg';
    case 'aac':
      return 'audio/aac';
    case 'amr':
      return 'audio/amr';
    case '3gp':
      return 'audio/3gpp';
    case 'm4a':
    case 'mp4':
    default:
      return 'audio/mp4';
  }
}

Future<Uint8List> downloadMediaBytes(
  CsacAppState state,
  String url, {
  required ConversationMediaKind kind,
}) async {
  if (kind == ConversationMediaKind.image) {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return response.bodyBytes;
  }
  final accept = kind == ConversationMediaKind.voice
      ? 'audio/*, application/octet-stream, */*'
      : 'application/octet-stream, */*';
  final response = await state.client.downloadAsset(url, accept: accept);
  return response.bodyBytes;
}

Future<void> saveMediaItem(
  BuildContext context,
  CsacAppState state,
  ConversationMediaItem item,
) async {
  final strings = context.strings;
  final mediaLabel = mediaTypeLabel(context, item.kind);
  try {
    final bytes = await downloadMediaBytes(state, item.url, kind: item.kind);
    final fallbackName = sanitizedFileName(mediaFileName(item));
    String path;
    if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      final mediaDirectory = Directory(p.join(directory.path, 'CsAC Media'));
      await mediaDirectory.create(recursive: true);
      path = p.join(mediaDirectory.path, fallbackName);
      await File(path).writeAsBytes(bytes, flush: true);
    } else {
      final location = await getSaveLocation(
        suggestedName: fallbackName,
        acceptedTypeGroups: <XTypeGroup>[
          if (item.kind == ConversationMediaKind.image)
            XTypeGroup(label: mediaLabel, extensions: imageExtensions)
          else if (item.kind == ConversationMediaKind.voice)
            XTypeGroup(label: mediaLabel, extensions: voiceExtensions)
          else
            XTypeGroup(label: mediaLabel),
        ],
      );
      if (location == null) {
        if (context.mounted) {
          _showCupertinoToast(context, strings.text('Download cancelled.'));
        }
        return;
      }
      path = location.path;
      if (p.extension(path).isEmpty && p.extension(fallbackName).isNotEmpty) {
        path = '$path${p.extension(fallbackName)}';
      }
      await XFile.fromData(
        bytes,
        name: p.basename(path),
        mimeType: item.kind == ConversationMediaKind.voice
            ? mimeTypeForVoiceExtension(p.extension(path))
            : null,
      ).saveTo(path);
    }
    if (!context.mounted) {
      return;
    }
    _showCupertinoToast(
      context,
      strings.format('Saved to {path}', {'path': path}),
    );
  } catch (err) {
    if (!context.mounted) {
      return;
    }
    _showCupertinoToast(
      context,
      strings.format('Download failed: {error}', {'error': err}),
    );
  }
}
