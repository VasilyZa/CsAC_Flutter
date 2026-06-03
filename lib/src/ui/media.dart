part of '../../main.dart';

class _MessageImage extends StatelessWidget {
  const _MessageImage({required this.url, this.heroTag, this.onTap});

  final String url;
  final Object? heroTag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final width = math.min(260.0, chatBubbleMaxWidth(context) - 24);
    final image = Image.network(
      url,
      width: width,
      height: 180,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
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
          width: width,
          height: 120,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(strokeWidth: 2),
        );
      },
    );
    return _CsacPressable(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: heroTag == null ? image : Hero(tag: heroTag!, child: image),
      ),
    );
  }
}

class _PreparedImage {
  const _PreparedImage({
    required this.bytes,
    required this.fileName,
    required this.caption,
  });

  final Uint8List bytes;
  final String fileName;
  final String caption;
}

class _ImageSendPreviewScreen extends StatefulWidget {
  const _ImageSendPreviewScreen({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;

  @override
  State<_ImageSendPreviewScreen> createState() =>
      _ImageSendPreviewScreenState();
}

enum _ImageCropMode { original, square, portrait, landscape }

class _ImageSendPreviewScreenState extends State<_ImageSendPreviewScreen> {
  final caption = TextEditingController();
  final toolbarScrollController = ScrollController();
  final previewKey = GlobalKey();
  final strokes = <_ImageDrawStroke>[];
  _ImageDrawStroke? activeStroke;
  _ImageCropMode cropMode = _ImageCropMode.original;
  Color drawColor = Colors.redAccent;
  bool drawing = false;
  bool sending = false;

  @override
  void dispose() {
    caption.dispose();
    toolbarScrollController.dispose();
    super.dispose();
  }

  Future<void> send() async {
    if (sending) {
      return;
    }
    setState(() => sending = true);
    try {
      final bytes = await _renderEditedImage(
        source: widget.bytes,
        cropMode: cropMode,
        strokes: strokes,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(
        _PreparedImage(
          bytes: bytes,
          fileName: _editedImageFileName(widget.fileName),
          caption: caption.text,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => sending = false);
      }
    }
  }

  void startStroke(DragStartDetails details) {
    if (!drawing) {
      return;
    }
    final box = previewKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size ?? Size.zero;
    final point = _normalizeEditorPoint(details.localPosition, size);
    setState(() {
      activeStroke = _ImageDrawStroke(color: drawColor, points: [point]);
    });
  }

  void updateStroke(DragUpdateDetails details) {
    final stroke = activeStroke;
    if (!drawing || stroke == null) {
      return;
    }
    final box = previewKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size ?? Size.zero;
    final point = _normalizeEditorPoint(details.localPosition, size);
    setState(() => stroke.points.add(point));
  }

  void endStroke([DragEndDetails? _]) {
    final stroke = activeStroke;
    if (stroke == null) {
      return;
    }
    setState(() {
      strokes.add(stroke);
      activeStroke = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = Theme.of(context).colorScheme;
    final allStrokes = [...strokes, if (activeStroke != null) activeStroke!];
    return CsacPageScaffold(
      appBar: CsacNavigationBar(
        title: Text(strings.text('Image preview')),
        actions: [
          CsacIconButton(
            tooltip: strings.text('Undo'),
            onPressed: strokes.isEmpty
                ? null
                : () => setState(() => strokes.removeLast()),
            icon: const Icon(Icons.undo),
          ),
          CsacIconButton(
            tooltip: strings.text('Reset edits'),
            onPressed: strokes.isEmpty && cropMode == _ImageCropMode.original
                ? null
                : () {
                    setState(() {
                      strokes.clear();
                      activeStroke = null;
                      cropMode = _ImageCropMode.original;
                    });
                  },
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: _cropAspectRatio(cropMode),
                  child: SizedBox(
                    width: _imageEditorCanvasWidth,
                    height: _imageEditorCanvasHeight,
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: GestureDetector(
                        key: previewKey,
                        onPanStart: startStroke,
                        onPanUpdate: updateStroke,
                        onPanEnd: endStroke,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(
                              widget.bytes,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Icon(
                                Icons.image_outlined,
                                size: 58,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            CustomPaint(
                              painter: _ImageDrawPainter(strokes: allStrokes),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: CsacColors.of(
                      context,
                    ).cardBackground.withValues(alpha: 0.92),
                    border: Border(
                      top: BorderSide(
                        color: CsacColors.of(
                          context,
                        ).separator.withValues(alpha: 0.26),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CsacSingleChildScrollView(
                          controller: toolbarScrollController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                child: drawing
                                    ? FilledButton.tonalIcon(
                                        key: const ValueKey('draw-on'),
                                        onPressed: () =>
                                            setState(() => drawing = false),
                                        icon: const Icon(Icons.brush),
                                        label: Text(strings.text('Draw')),
                                      )
                                    : OutlinedButton.icon(
                                        key: const ValueKey('draw-off'),
                                        onPressed: () =>
                                            setState(() => drawing = true),
                                        icon: const Icon(Icons.draw_outlined),
                                        label: Text(strings.text('Draw')),
                                      ),
                              ),
                              const SizedBox(width: 8),
                              for (final color in [
                                colors.primary,
                                colors.error,
                                Colors.white,
                                Colors.black,
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _DrawColorButton(
                                    color: color,
                                    selected: drawColor == color,
                                    onTap: () =>
                                        setState(() => drawColor = color),
                                  ),
                                ),
                              const SizedBox(width: 6),
                              SegmentedButton<_ImageCropMode>(
                                segments: [
                                  ButtonSegment(
                                    value: _ImageCropMode.original,
                                    label: Text(strings.text('Original')),
                                  ),
                                  ButtonSegment(
                                    value: _ImageCropMode.square,
                                    label: Text(strings.text('Square')),
                                  ),
                                  ButtonSegment(
                                    value: _ImageCropMode.portrait,
                                    label: Text(strings.text('Portrait')),
                                  ),
                                  ButtonSegment(
                                    value: _ImageCropMode.landscape,
                                    label: Text(strings.text('Landscape')),
                                  ),
                                ],
                                selected: {cropMode},
                                onSelectionChanged: (value) =>
                                    setState(() => cropMode = value.first),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: CsacTextField(
                                controller: caption,
                                minLines: 1,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: strings.text('Caption'),
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              onPressed: sending ? null : send,
                              icon: sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              label: Text(strings.text('Send')),
                            ),
                          ],
                        ),
                      ],
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

class _ImageDrawStroke {
  _ImageDrawStroke({required this.color, required this.points});

  final Color color;
  final List<Offset> points;
}

class _ImageDrawPainter extends CustomPainter {
  const _ImageDrawPainter({required this.strokes});

  final List<_ImageDrawStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / _imageEditorCanvasWidth;
    final scaleY = size.height / _imageEditorCanvasHeight;
    canvas.save();
    canvas.scale(scaleX, scaleY);
    for (final stroke in strokes) {
      if (stroke.points.length < 2) {
        continue;
      }
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ImageDrawPainter oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}

class _DrawColorButton extends StatelessWidget {
  const _DrawColorButton({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _CsacPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 150.ms,
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }
}

double _cropAspectRatio(_ImageCropMode mode) {
  switch (mode) {
    case _ImageCropMode.original:
      return 4 / 3;
    case _ImageCropMode.square:
      return 1;
    case _ImageCropMode.portrait:
      return 3 / 4;
    case _ImageCropMode.landscape:
      return 16 / 9;
  }
}

Offset _normalizeEditorPoint(Offset point, Size size) {
  if (size.width <= 0 || size.height <= 0) {
    return Offset.zero;
  }
  return Offset(
    (point.dx / size.width * _imageEditorCanvasWidth).clamp(
      0,
      _imageEditorCanvasWidth,
    ),
    (point.dy / size.height * _imageEditorCanvasHeight).clamp(
      0,
      _imageEditorCanvasHeight,
    ),
  );
}

String _editedImageFileName(String fileName) {
  final extension = normalizedImageExtension(fileName);
  final base = p.basenameWithoutExtension(fileName).trim();
  final safeBase = base.isEmpty ? 'image' : base;
  return '${safeBase}_edited$extension';
}

Future<Uint8List> _renderEditedImage({
  required Uint8List source,
  required _ImageCropMode cropMode,
  required List<_ImageDrawStroke> strokes,
}) async {
  if (cropMode == _ImageCropMode.original && strokes.isEmpty) {
    return source;
  }
  final codec = await ui.instantiateImageCodec(source);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final sourceSize = Size(image.width.toDouble(), image.height.toDouble());
  final aspect = cropMode == _ImageCropMode.original
      ? sourceSize.width / sourceSize.height
      : _cropAspectRatio(cropMode);
  final outputWidth = math.min(1600, sourceSize.width).round();
  final outputHeight = math.max(1, (outputWidth / aspect).round());
  final outputSize = Size(outputWidth.toDouble(), outputHeight.toDouble());
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, outputSize.width, outputSize.height),
  );
  final sourceRect = _centeredCoverSourceRect(sourceSize, aspect);
  final outputRect = Offset.zero & outputSize;
  canvas.drawImageRect(image, sourceRect, outputRect, Paint());
  final scaleX = outputSize.width / _imageEditorCanvasWidth;
  final scaleY = outputSize.height / _imageEditorCanvasHeight;
  for (final stroke in strokes) {
    if (stroke.points.length < 2) {
      continue;
    }
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = 4 * ((scaleX + scaleY) / 2)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(
        stroke.points.first.dx * scaleX,
        stroke.points.first.dy * scaleY,
      );
    for (final point in stroke.points.skip(1)) {
      path.lineTo(point.dx * scaleX, point.dy * scaleY);
    }
    canvas.drawPath(path, paint);
  }
  final picture = recorder.endRecording();
  final outputImage = await picture.toImage(outputWidth, outputHeight);
  final byteData = await outputImage.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  outputImage.dispose();
  return byteData?.buffer.asUint8List() ?? source;
}

Rect _centeredCoverSourceRect(Size size, double aspect) {
  final sourceAspect = size.width / size.height;
  if ((sourceAspect - aspect).abs() < 0.001) {
    return Offset.zero & size;
  }
  if (sourceAspect > aspect) {
    final width = size.height * aspect;
    final left = (size.width - width) / 2;
    return Rect.fromLTWH(left, 0, width, size.height);
  }
  final height = size.width / aspect;
  final top = (size.height - height) / 2;
  return Rect.fromLTWH(0, top, size.width, height);
}

const _imageEditorCanvasWidth = 1000.0;
const _imageEditorCanvasHeight = 1000.0;

void showImagePreview(BuildContext context, String url, {Object? heroTag}) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: 260.ms,
      reverseTransitionDuration: 220.ms,
      pageBuilder: (_, animation, _) =>
          _ImagePreviewRoute(url: url, heroTag: heroTag, animation: animation),
    ),
  );
}

class _ImagePreviewRoute extends StatelessWidget {
  const _ImagePreviewRoute({
    required this.url,
    required this.animation,
    this.heroTag,
  });

  final String url;
  final Object? heroTag;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final image = Image.network(
      url,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Icon(
        Icons.broken_image_outlined,
        size: 64,
        color: Colors.white70,
      ),
    );
    return FadeTransition(
      opacity: animation,
      child: CsacPageScaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.7,
                  maxScale: 5,
                  child: heroTag == null
                      ? image
                      : Hero(tag: heroTag!, child: image),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: _PreviewIconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: CupertinoIcons.xmark,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    _PreviewIconButton(
                      tooltip: strings.text('Copy link'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: url));
                        CsacToastMessenger.of(context).showToast(
                          CsacToast(
                            content: Text(strings.text('Image link copied')),
                          ),
                        );
                      },
                      icon: CupertinoIcons.doc_on_doc,
                    ),
                    const SizedBox(width: 8),
                    _PreviewIconButton(
                      tooltip: strings.text('Open'),
                      onPressed: () => launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: CupertinoIcons.arrow_up_right_square,
                    ),
                    const SizedBox(width: 8),
                    _PreviewIconButton(
                      tooltip: strings.text('Download'),
                      onPressed: () => downloadImage(context, url),
                      icon: CupertinoIcons.arrow_down_circle,
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

class _PreviewIconButton extends StatelessWidget {
  const _PreviewIconButton({
    required this.onPressed,
    required this.icon,
    this.tooltip,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(38, 38),
      onPressed: onPressed,
      child: ClipOval(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: CupertinoColors.black.withValues(alpha: 0.34),
              shape: BoxShape.circle,
              border: Border.all(
                color: CupertinoColors.white.withValues(alpha: 0.18),
                width: 0.5,
              ),
            ),
            child: Icon(icon, color: CupertinoColors.white, size: 20),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

Future<void> downloadImage(BuildContext context, String url) async {
  await downloadUrl(
    context,
    url,
    suggestedName:
        'csac_${DateTime.now().millisecondsSinceEpoch}${normalizedImageExtension(Uri.parse(url).path)}',
    typeLabel: context.strings.text('Images'),
    extensions: imageExtensions,
  );
}

Future<void> downloadUrl(
  BuildContext context,
  String url, {
  String suggestedName = '',
  String typeLabel = '',
  List<String> extensions = const <String>[],
}) async {
  final strings = context.strings;
  if (isWebPlatform) {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) {
      return;
    }
    CsacToastMessenger.of(
      context,
    ).showToast(CsacToast(content: Text(strings.text('Link copied'))));
    return;
  }
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final uri = Uri.parse(url);
    final fallbackExt = extensions.isEmpty
        ? p.extension(uri.path)
        : '.${extensions.first}';
    final fileName = suggestedName.trim().isEmpty
        ? defaultDownloadName(url, fallbackExtension: fallbackExt)
        : suggestedName.trim();
    final path = await saveDownloadedBytes(
      bytes: response.bodyBytes,
      suggestedName: fileName,
      typeLabel: typeLabel,
      extensions: extensions,
    );
    if (path == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    CsacToastMessenger.of(context).showToast(
      CsacToast(
        content: Text(strings.format('Saved to {path}', {'path': path})),
      ),
    );
  } catch (err) {
    if (!context.mounted) {
      return;
    }
    CsacToastMessenger.of(context).showToast(
      CsacToast(
        content: Text(
          strings.format('Download failed: {error}', {'error': err}),
        ),
      ),
    );
  }
}

const imageExtensions = <String>['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'];

const voiceExtensions = <String>[
  'mp3',
  'm4a',
  'aac',
  'wav',
  'ogg',
  'webm',
  'amr',
  'flac',
];

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

String defaultDownloadName(String url, {String fallbackExtension = ''}) {
  final fromUrl = fileNameFromUrl(url);
  if (fromUrl.isNotEmpty && p.extension(fromUrl).isNotEmpty) {
    return fromUrl;
  }
  final extension = fallbackExtension.isEmpty ? '.bin' : fallbackExtension;
  return 'csac_${DateTime.now().millisecondsSinceEpoch}$extension';
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
    case 'mp3':
      return 'audio/mpeg';
    case 'm4a':
      return 'audio/mp4';
    case 'aac':
      return 'audio/aac';
    case 'wav':
      return 'audio/wav';
    case 'ogg':
      return 'audio/ogg';
    case 'webm':
      return 'audio/webm';
    case 'amr':
      return 'audio/amr';
    case 'flac':
      return 'audio/flac';
    case 'pdf':
      return 'application/pdf';
    case 'zip':
      return 'application/zip';
    case 'json':
      return 'application/json';
    case 'txt':
    case 'md':
    case 'csv':
      return 'text/plain';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    default:
      return 'application/octet-stream';
  }
}
