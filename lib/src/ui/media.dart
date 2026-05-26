part of '../../main.dart';

class _MessageImage extends StatelessWidget {
  const _MessageImage({required this.url, this.onTap});

  final String url;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
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
              color: colors.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Icon(
                Icons.broken_image_outlined,
                size: 42,
                color: colors.onSurfaceVariant,
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
              child: const CircularProgressIndicator(strokeWidth: 2),
            );
          },
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
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(
        strings.format('Send image: {fileName}', {'fileName': widget.fileName}),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 260,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: colors.surfaceContainerHighest,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.memory(
              widget.bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                Icons.image_outlined,
                size: 48,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: caption,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: strings.text('Caption'),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(strings.text('Cancel')),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(caption.text),
          icon: const Icon(Icons.send),
          label: Text(strings.text('Send')),
        ),
      ],
    );
  }
}

void showImagePreview(BuildContext context, String url) {
  final strings = context.strings;
  showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.7,
                  maxScale: 5,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      size: 64,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: strings.text('Copy link'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(strings.text('Image link copied')),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: strings.text('Open'),
                      onPressed: () => launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_new),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: strings.text('Download'),
                      onPressed: () => downloadImage(context, url),
                      icon: const Icon(Icons.download_outlined),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.text('Download cancelled.'))),
          );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.format('Saved to {path}', {'path': path})),
      ),
    );
  } catch (err) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          strings.format('Download failed: {error}', {'error': err}),
        ),
      ),
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
