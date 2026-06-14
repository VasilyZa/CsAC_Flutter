part of '../../main.dart';

const _qrShareCanvasWidth = 1200.0;
const _qrShareCanvasHeight = 1600.0;

enum _QrShareTheme { soft, blue, dark, plain }

enum _QrCenterMark { none, avatar, logo }

class _QrShareStyle {
  const _QrShareStyle({
    this.theme = _QrShareTheme.soft,
    this.centerMark = _QrCenterMark.avatar,
    this.showAvatar = true,
    this.showTitle = true,
  });

  final _QrShareTheme theme;
  final _QrCenterMark centerMark;
  final bool showAvatar;
  final bool showTitle;

  _QrShareStyle copyWith({
    _QrShareTheme? theme,
    _QrCenterMark? centerMark,
    bool? showAvatar,
    bool? showTitle,
  }) {
    return _QrShareStyle(
      theme: theme ?? this.theme,
      centerMark: centerMark ?? this.centerMark,
      showAvatar: showAvatar ?? this.showAvatar,
      showTitle: showTitle ?? this.showTitle,
    );
  }
}

class _QrSharePalette {
  const _QrSharePalette({
    required this.background,
    required this.card,
    required this.primary,
    required this.text,
    required this.muted,
    required this.border,
    required this.qrBackground,
    required this.qrForeground,
  });

  final Color background;
  final Color card;
  final Color primary;
  final Color text;
  final Color muted;
  final Color border;
  final Color qrBackground;
  final Color qrForeground;
}

_QrSharePalette _qrSharePalette(_QrShareTheme theme) {
  switch (theme) {
    case _QrShareTheme.soft:
      return const _QrSharePalette(
        background: Color(0xFFF2F2F7),
        card: CupertinoColors.white,
        primary: CupertinoColors.activeBlue,
        text: Color(0xFF111827),
        muted: Color(0xFF6B7280),
        border: Color(0xFFE5E7EB),
        qrBackground: CupertinoColors.white,
        qrForeground: Color(0xFF111827),
      );
    case _QrShareTheme.blue:
      return const _QrSharePalette(
        background: Color(0xFFEAF3FF),
        card: CupertinoColors.white,
        primary: Color(0xFF0A5CAD),
        text: Color(0xFF102033),
        muted: Color(0xFF4A6680),
        border: Color(0xFFB8D6F3),
        qrBackground: CupertinoColors.white,
        qrForeground: Color(0xFF08233F),
      );
    case _QrShareTheme.dark:
      return const _QrSharePalette(
        background: Color(0xFF11100D),
        card: Color(0xFF1C1812),
        primary: Color(0xFFD9B35F),
        text: Color(0xFFFFF8E8),
        muted: Color(0xFFE3CF9C),
        border: Color(0xFF6E5625),
        qrBackground: Color(0xFFFFF8E8),
        qrForeground: Color(0xFF18140E),
      );
    case _QrShareTheme.plain:
      return const _QrSharePalette(
        background: CupertinoColors.white,
        card: CupertinoColors.white,
        primary: Color(0xFF111827),
        text: Color(0xFF111827),
        muted: Color(0xFF4B5563),
        border: Color(0xFFE5E7EB),
        qrBackground: CupertinoColors.white,
        qrForeground: Color(0xFF111827),
      );
  }
}

String _qrThemeLabel(CsacStrings strings, _QrShareTheme theme) {
  switch (theme) {
    case _QrShareTheme.soft:
      return strings.text('Soft card');
    case _QrShareTheme.blue:
      return strings.text('Blue card');
    case _QrShareTheme.dark:
      return strings.text('Dark card');
    case _QrShareTheme.plain:
      return strings.text('Plain QR');
  }
}

String _qrCenterMarkLabel(CsacStrings strings, _QrCenterMark mark) {
  switch (mark) {
    case _QrCenterMark.none:
      return strings.text('None');
    case _QrCenterMark.avatar:
      return strings.text('Avatar');
    case _QrCenterMark.logo:
      return strings.text('Logo');
  }
}

ImageProvider<Object>? _qrEmbeddedImage(_QrShareStyle style, String avatarUrl) {
  if (style.centerMark != _QrCenterMark.avatar || avatarUrl.trim().isEmpty) {
    return null;
  }
  return NetworkImage(avatarUrl.trim());
}

Future<ui.Image?> _loadQrAvatarImage(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  try {
    final response = await http.get(Uri.parse(trimmed));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final codec = await ui.instantiateImageCodec(response.bodyBytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    return null;
  }
}

Future<Uint8List> _renderQrSharePng({
  required String link,
  required String title,
  required String subtitle,
  required String avatarUrl,
  required _QrShareStyle style,
}) async {
  final avatarImage = style.centerMark == _QrCenterMark.avatar
      ? await _loadQrAvatarImage(avatarUrl)
      : null;
  final palette = _qrSharePalette(style.theme);
  final painter = QrPainter(
    data: link,
    version: QrVersions.auto,
    errorCorrectionLevel: QrErrorCorrectLevel.M,
    gapless: true,
    eyeStyle: QrEyeStyle(
      eyeShape: QrEyeShape.square,
      color: palette.qrForeground,
    ),
    dataModuleStyle: QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.square,
      color: palette.qrForeground,
    ),
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  _paintQrShareCard(
    canvas,
    painter: painter,
    link: link,
    title: title,
    subtitle: subtitle,
    avatarImage: avatarImage,
    style: style,
  );
  final image = await recorder.endRecording().toImage(
    _qrShareCanvasWidth.toInt(),
    _qrShareCanvasHeight.toInt(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  avatarImage?.dispose();
  return data?.buffer.asUint8List() ?? Uint8List(0);
}

Future<void> _shareQrPng(
  BuildContext context, {
  required String link,
  required String title,
  required String subject,
  required String fileName,
  required String cardTitle,
  required String cardSubtitle,
  required String avatarUrl,
  required _QrShareStyle style,
}) async {
  final renderObject = context.findRenderObject();
  final box = renderObject is RenderBox ? renderObject : null;
  final bytes = await _renderQrSharePng(
    link: link,
    title: cardTitle,
    subtitle: cardSubtitle,
    avatarUrl: avatarUrl,
    style: style,
  );
  if (bytes.isEmpty) {
    throw StateError('QR image is empty');
  }
  await SharePlus.instance.share(
    ShareParams(
      title: title,
      subject: subject,
      text: link,
      files: [XFile.fromData(bytes, name: fileName, mimeType: 'image/png')],
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
}

void _paintQrShareCard(
  Canvas canvas, {
  required QrPainter painter,
  required String link,
  required String title,
  required String subtitle,
  required ui.Image? avatarImage,
  required _QrShareStyle style,
}) {
  final palette = _qrSharePalette(style.theme);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, _qrShareCanvasWidth, _qrShareCanvasHeight),
    Paint()..color = palette.background,
  );
  final cardRect = RRect.fromRectAndRadius(
    const Rect.fromLTWH(92, 118, 1016, 1364),
    const Radius.circular(56),
  );
  canvas.drawRRect(cardRect, Paint()..color = palette.card);
  canvas.drawRRect(
    cardRect,
    Paint()
      ..color = palette.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );

  if (style.theme == _QrShareTheme.plain) {
    final qrOuter = RRect.fromRectAndRadius(
      const Rect.fromLTWH(174, 356, 852, 852),
      const Radius.circular(32),
    );
    canvas.drawRRect(qrOuter, Paint()..color = palette.qrBackground);
    final qrRect = qrOuter.outerRect.deflate(44);
    canvas.save();
    canvas.translate(qrRect.left, qrRect.top);
    painter.paint(canvas, qrRect.size);
    canvas.restore();
    _paintQrCenterMark(
      canvas,
      center: qrRect.center,
      palette: palette,
      avatarImage: avatarImage,
      fallbackText: title,
      style: style,
    );
    return;
  }

  var cursorY = 204.0;
  if (style.showAvatar) {
    _paintQrAvatar(
      canvas,
      center: Offset(_qrShareCanvasWidth / 2, cursorY + 72),
      radius: 72,
      palette: palette,
      avatarImage: avatarImage,
      fallbackText: title,
    );
    cursorY += 174;
  }
  if (style.showTitle && title.trim().isNotEmpty) {
    cursorY += _paintCenteredParagraph(
      canvas,
      title.trim(),
      Offset(_qrShareCanvasWidth / 2, cursorY),
      maxWidth: 760,
      style: TextStyle(
        color: palette.text,
        fontSize: 50,
        fontWeight: FontWeight.w800,
        height: 1.15,
      ),
      maxLines: 2,
    );
    if (subtitle.trim().isNotEmpty) {
      cursorY += 16;
      cursorY += _paintCenteredParagraph(
        canvas,
        subtitle.trim(),
        Offset(_qrShareCanvasWidth / 2, cursorY),
        maxWidth: 720,
        style: TextStyle(
          color: palette.muted,
          fontSize: 28,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
        maxLines: 1,
      );
    }
  }
  final qrTop = math.max(626.0, cursorY + 54);
  final qrOuter = RRect.fromRectAndRadius(
    Rect.fromLTWH(220, qrTop, 760, 760),
    const Radius.circular(42),
  );
  canvas.drawRRect(qrOuter, Paint()..color = palette.qrBackground);
  canvas.drawRRect(
    qrOuter,
    Paint()
      ..color = palette.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  final qrRect = qrOuter.outerRect.deflate(46);
  canvas.save();
  canvas.translate(qrRect.left, qrRect.top);
  painter.paint(canvas, qrRect.size);
  canvas.restore();
  _paintQrCenterMark(
    canvas,
    center: qrRect.center,
    palette: palette,
    avatarImage: avatarImage,
    fallbackText: title,
    style: style,
  );
  _paintCenteredParagraph(
    canvas,
    link,
    const Offset(_qrShareCanvasWidth / 2, 1348),
    maxWidth: 780,
    style: TextStyle(
      color: palette.muted,
      fontSize: 24,
      fontWeight: FontWeight.w500,
      height: 1.25,
    ),
    maxLines: 2,
  );
}

void _paintQrAvatar(
  Canvas canvas, {
  required Offset center,
  required double radius,
  required _QrSharePalette palette,
  required ui.Image? avatarImage,
  required String fallbackText,
}) {
  canvas.drawCircle(
    center,
    radius + 6,
    Paint()..color = palette.primary.withValues(alpha: 0.16),
  );
  canvas.drawCircle(center, radius, Paint()..color = palette.qrBackground);
  if (avatarImage != null) {
    final rect = Rect.fromCircle(center: center, radius: radius - 4);
    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    paintImage(
      canvas: canvas,
      rect: rect,
      image: avatarImage,
      fit: BoxFit.cover,
    );
    canvas.restore();
    return;
  }
  _paintCenteredParagraph(
    canvas,
    _qrInitial(fallbackText),
    Offset(center.dx, center.dy - 24),
    maxWidth: radius * 1.6,
    style: TextStyle(
      color: palette.primary,
      fontSize: 54,
      fontWeight: FontWeight.w900,
      height: 1,
    ),
    maxLines: 1,
  );
}

void _paintQrCenterMark(
  Canvas canvas, {
  required Offset center,
  required _QrSharePalette palette,
  required ui.Image? avatarImage,
  required String fallbackText,
  required _QrShareStyle style,
}) {
  switch (style.centerMark) {
    case _QrCenterMark.none:
      return;
    case _QrCenterMark.avatar:
      _paintQrCenterAvatar(
        canvas,
        center: center,
        palette: palette,
        avatarImage: avatarImage,
        fallbackText: fallbackText,
      );
    case _QrCenterMark.logo:
      _paintQrCenterLogo(canvas, center: center, palette: palette);
  }
}

void _paintQrCenterAvatar(
  Canvas canvas, {
  required Offset center,
  required _QrSharePalette palette,
  required ui.Image? avatarImage,
  required String fallbackText,
}) {
  final rect = Rect.fromCenter(center: center, width: 156, height: 156);
  final outer = RRect.fromRectAndRadius(
    rect.inflate(12),
    const Radius.circular(38),
  );
  canvas.drawRRect(outer, Paint()..color = palette.qrBackground);
  canvas.drawRRect(
    outer,
    Paint()
      ..color = palette.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  if (avatarImage != null) {
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(30)));
    paintImage(
      canvas: canvas,
      rect: rect,
      image: avatarImage,
      fit: BoxFit.cover,
    );
    canvas.restore();
    return;
  }
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(30)),
    Paint()..color = palette.primary,
  );
  _paintCenteredParagraph(
    canvas,
    _qrInitial(fallbackText),
    Offset(center.dx, center.dy - 18),
    maxWidth: 120,
    style: const TextStyle(
      color: CupertinoColors.white,
      fontSize: 46,
      fontWeight: FontWeight.w900,
      height: 1,
    ),
    maxLines: 1,
  );
}

void _paintQrCenterLogo(
  Canvas canvas, {
  required Offset center,
  required _QrSharePalette palette,
}) {
  final rect = Rect.fromCenter(center: center, width: 156, height: 156);
  final outer = RRect.fromRectAndRadius(
    rect.inflate(12),
    const Radius.circular(38),
  );
  canvas.drawRRect(outer, Paint()..color = palette.qrBackground);
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, const Radius.circular(30)),
    Paint()..color = palette.primary,
  );
  _paintCenteredParagraph(
    canvas,
    'CsAC',
    Offset(center.dx, center.dy - 16),
    maxWidth: 128,
    style: const TextStyle(
      color: CupertinoColors.white,
      fontSize: 34,
      fontWeight: FontWeight.w900,
      height: 1,
    ),
    maxLines: 1,
  );
}

double _paintCenteredParagraph(
  Canvas canvas,
  String text,
  Offset topCenter, {
  required double maxWidth,
  required TextStyle style,
  required int maxLines,
}) {
  final paragraphStyle = ui.ParagraphStyle(
    textAlign: TextAlign.center,
    maxLines: maxLines,
    ellipsis: maxLines == 1 ? '...' : null,
    fontSize: style.fontSize,
    fontWeight: style.fontWeight,
    height: style.height,
  );
  final builder = ui.ParagraphBuilder(paragraphStyle)
    ..pushStyle(style.getTextStyle())
    ..addText(text);
  final paragraph = builder.build()
    ..layout(ui.ParagraphConstraints(width: maxWidth));
  canvas.drawParagraph(
    paragraph,
    Offset(topCenter.dx - maxWidth / 2, topCenter.dy),
  );
  return paragraph.height;
}

String _qrInitial(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'C';
  }
  return String.fromCharCode(trimmed.runes.first).toUpperCase();
}

class UserQrScreen extends StatelessWidget {
  const UserQrScreen({super.key, required this.state});

  final CsacAppState state;

  @override
  Widget build(BuildContext context) {
    final user = state.user;
    final strings = context.strings;
    if (user == null) {
      return CsacPageScaffold(
        appBar: CsacNavigationBar(title: Text(strings.text('My QR code'))),
        body: _EmptyPanel(message: strings.text('Not logged in')),
      );
    }
    return CsacQrShareScreen(
      title: strings.text('My QR code'),
      link: csacUserProfileDeepLink(user.uid),
      cardTitle: user.nickname,
      cardSubtitle: 'UID ${user.uid}',
      avatarUrl: state.currentUserAvatar,
      fallbackIcon: CupertinoIcons.person_fill,
      helperText: strings.text('Scan to open this profile in CsAC.'),
      shareTitle: strings.text('Share my user QR code'),
      shareSubject: strings.text('CsAC user QR code'),
      fileName: 'csac-user-${user.uid}.png',
      copyToast: strings.text('Profile link copied.'),
      semanticsLabel: strings.text('My CsAC user profile QR code'),
    );
  }
}

class GroupQrScreen extends StatelessWidget {
  const GroupQrScreen({super.key, required this.group});

  final GroupProfile group;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return CsacQrShareScreen(
      title: strings.text('Group QR code'),
      link: csacGroupChatDeepLink(group.id),
      cardTitle: group.name,
      cardSubtitle: strings.format('Room {id}', {'id': group.id}),
      avatarUrl: group.avatar,
      fallbackIcon: CupertinoIcons.group_solid,
      helperText: strings.text('Scan to open this group chat in CsAC.'),
      shareTitle: strings.text('Share group QR code'),
      shareSubject: strings.text('CsAC group QR code'),
      fileName: 'csac-group-${group.id}.png',
      copyToast: strings.text('Group link copied.'),
      semanticsLabel: strings.text('CsAC group QR code'),
    );
  }
}

class CsacQrShareScreen extends StatefulWidget {
  const CsacQrShareScreen({
    super.key,
    required this.title,
    required this.link,
    required this.cardTitle,
    required this.cardSubtitle,
    required this.avatarUrl,
    required this.fallbackIcon,
    required this.helperText,
    required this.shareTitle,
    required this.shareSubject,
    required this.fileName,
    required this.copyToast,
    required this.semanticsLabel,
  });

  final String title;
  final String link;
  final String cardTitle;
  final String cardSubtitle;
  final String avatarUrl;
  final IconData fallbackIcon;
  final String helperText;
  final String shareTitle;
  final String shareSubject;
  final String fileName;
  final String copyToast;
  final String semanticsLabel;

  @override
  State<CsacQrShareScreen> createState() => _CsacQrShareScreenState();
}

class _CsacQrShareScreenState extends State<CsacQrShareScreen> {
  bool sharing = false;
  _QrShareStyle style = const _QrShareStyle();

  Future<void> copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.link));
    if (mounted) {
      CsacToastMessenger.of(
        context,
      ).showToast(CsacToast(content: Text(widget.copyToast)));
    }
  }

  Future<void> shareQr() async {
    if (sharing) {
      return;
    }
    setState(() => sharing = true);
    try {
      await _shareQrPng(
        context,
        link: widget.link,
        title: widget.shareTitle,
        subject: widget.shareSubject,
        fileName: widget.fileName,
        cardTitle: widget.cardTitle,
        cardSubtitle: widget.cardSubtitle,
        avatarUrl: widget.avatarUrl,
        style: style,
      );
    } catch (err) {
      if (mounted) {
        CsacToastMessenger.of(context).showToast(
          CsacToast(
            content: Text(
              context.strings.format('Share failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => sharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return CsacPageScaffold(
      appBar: CsacNavigationBar(title: Text(widget.title)),
      backgroundColor: colors.systemBackground,
      body: SafeArea(
        child: _AdaptivePageFrame(
          maxWidth: 680,
          child: CsacListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              _QrCardPreview(
                link: widget.link,
                title: widget.cardTitle,
                subtitle: widget.cardSubtitle,
                avatarUrl: widget.avatarUrl,
                fallbackIcon: widget.fallbackIcon,
                helperText: widget.helperText,
                semanticsLabel: widget.semanticsLabel,
                style: style,
              ),
              const SizedBox(height: 12),
              _QrStyleControls(
                style: style,
                onChanged: (value) => setState(() => style = value),
              ),
              const SizedBox(height: 12),
              _CupertinoGroupedCard(
                margin: EdgeInsets.zero,
                children: [
                  _CupertinoListTile(
                    leading: sharing
                        ? CupertinoActivityIndicator(color: colors.primaryColor)
                        : const Icon(CupertinoIcons.square_arrow_up),
                    title: strings.text('Share QR code'),
                    subtitle: strings.text('Share as a PNG image'),
                    onTap: sharing ? null : shareQr,
                  ),
                  _CupertinoListTile(
                    leading: const Icon(CupertinoIcons.link),
                    title: strings.text('Copy link'),
                    subtitle: widget.link,
                    onTap: copyLink,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QrCardPreview extends StatelessWidget {
  const _QrCardPreview({
    required this.link,
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.fallbackIcon,
    required this.helperText,
    required this.semanticsLabel,
    required this.style,
  });

  final String link;
  final String title;
  final String subtitle;
  final String avatarUrl;
  final IconData fallbackIcon;
  final String helperText;
  final String semanticsLabel;
  final _QrShareStyle style;

  @override
  Widget build(BuildContext context) {
    final palette = _qrSharePalette(style.theme);
    final embeddedImage = _qrEmbeddedImage(style, avatarUrl);
    final plain = style.theme == _QrShareTheme.plain;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.border, width: 0.8),
      ),
      child: Column(
        children: [
          if (!plain && style.showAvatar) ...[
            _Avatar(url: avatarUrl, fallback: fallbackIcon, radius: 34),
            const SizedBox(height: 12),
          ],
          if (!plain && style.showTitle) ...[
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.text,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (subtitle.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            if (helperText.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                helperText,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.muted, fontSize: 13),
              ),
            ],
            const SizedBox(height: 18),
          ],
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.qrBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox.square(
                dimension: 230,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    QrImageView(
                      data: link,
                      version: QrVersions.auto,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      size: 230,
                      backgroundColor: palette.qrBackground,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: palette.qrForeground,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: palette.qrForeground,
                      ),
                      embeddedImage: embeddedImage,
                      embeddedImageStyle: embeddedImage == null
                          ? null
                          : const QrEmbeddedImageStyle(size: Size.square(42)),
                      semanticsLabel: semanticsLabel,
                    ),
                    if (style.centerMark == _QrCenterMark.logo)
                      _QrLogoCenterMark(palette: palette),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SelectableText(
            link,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.muted,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _QrLogoCenterMark extends StatelessWidget {
  const _QrLogoCenterMark({required this.palette});

  final _QrSharePalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.qrBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const SizedBox(
            width: 42,
            height: 42,
            child: Center(
              child: Text(
                'CsAC',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QrStyleControls extends StatelessWidget {
  const _QrStyleControls({required this.style, required this.onChanged});

  final _QrShareStyle style;
  final ValueChanged<_QrShareStyle> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final plain = style.theme == _QrShareTheme.plain;
    return _CupertinoGroupedCard(
      margin: EdgeInsets.zero,
      header: strings.text('QR card style'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: CupertinoSlidingSegmentedControl<_QrShareTheme>(
            groupValue: style.theme,
            children: {
              for (final theme in _QrShareTheme.values)
                theme: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(_qrThemeLabel(strings, theme)),
                ),
            },
            onValueChanged: (value) {
              if (value != null) {
                onChanged(style.copyWith(theme: value));
              }
            },
          ),
        ),
        _QrSwitchTile(
          title: strings.text('Show avatar'),
          value: style.showAvatar,
          enabled: !plain,
          onChanged: (value) => onChanged(style.copyWith(showAvatar: value)),
        ),
        _QrSwitchTile(
          title: strings.text('Show name'),
          value: style.showTitle,
          enabled: !plain,
          onChanged: (value) => onChanged(style.copyWith(showTitle: value)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.text('Center mark')),
              const SizedBox(height: 8),
              CupertinoSlidingSegmentedControl<_QrCenterMark>(
                groupValue: style.centerMark,
                children: {
                  for (final mark in _QrCenterMark.values)
                    mark: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(_qrCenterMarkLabel(strings, mark)),
                    ),
                },
                onValueChanged: (value) {
                  if (value != null) {
                    onChanged(style.copyWith(centerMark: value));
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QrSwitchTile extends StatelessWidget {
  const _QrSwitchTile({
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = CsacColors.of(context);
    return CupertinoListTile(
      title: Text(
        title,
        style: TextStyle(color: enabled ? colors.label : colors.tertiaryLabel),
      ),
      trailing: CupertinoSwitch(
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

String? firstQrBarcodeValue(BarcodeCapture? capture) {
  if (capture == null) {
    return null;
  }
  for (final barcode in capture.barcodes) {
    final value = (barcode.rawValue ?? barcode.displayValue ?? '').trim();
    if (value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

Future<String?> firstQrValueInImagePath(
  String path, {
  MobileScannerController? scanner,
}) async {
  final ownsScanner = scanner == null;
  final activeScanner =
      scanner ??
      MobileScannerController(
        autoStart: false,
        formats: const [BarcodeFormat.qrCode],
      );
  try {
    final capture = await activeScanner.analyzeImage(
      path,
      formats: const [BarcodeFormat.qrCode],
    );
    return firstQrBarcodeValue(capture);
  } finally {
    if (ownsScanner) {
      unawaited(activeScanner.dispose());
    }
  }
}

Future<String> cacheQrScanImageUrl(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('HTTP ${response.statusCode}');
  }
  return writeTemporaryQrScanImage(
    response.bodyBytes,
    Uri.tryParse(url)?.path ?? 'image.png',
  );
}

Future<Uri?> confirmScannedCsacUri(BuildContext context, Uri uri) {
  return Navigator.of(context).push<Uri>(
    CsacPageRoute<Uri>(builder: (_) => CsacQrScanResultScreen(uri: uri)),
  );
}

class CsacQrScanResultScreen extends StatelessWidget {
  const CsacQrScanResultScreen({super.key, required this.uri});

  final Uri uri;

  Future<void> confirm(BuildContext context) async {
    await QrScanHistoryStore.add(uri.toString());
    if (context.mounted) {
      Navigator.of(context).pop(uri);
    }
  }

  Future<void> copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (context.mounted) {
      CsacToastMessenger.of(
        context,
      ).showToast(CsacToast(content: Text(context.strings.text('Copied.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    final target = parseCsacDeepLink(uri);
    return CsacPageScaffold(
      appBar: CsacNavigationBar(title: Text(strings.text('Scan result'))),
      backgroundColor: colors.systemBackground,
      body: SafeArea(
        child: _AdaptivePageFrame(
          maxWidth: 680,
          child: target.isSupported
              ? CsacListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  children: [
                    _CupertinoGroupedCard(
                      margin: EdgeInsets.zero,
                      children: [
                        _CupertinoListTile(
                          leading: const Icon(CupertinoIcons.qrcode),
                          title: _deepLinkTargetLabel(strings, target),
                          subtitle: strings.text(
                            'Confirm before opening this scanned link.',
                          ),
                        ),
                        _CupertinoListTile(
                          leading: const Icon(CupertinoIcons.number),
                          title: strings.text('Identifier'),
                          subtitle: _deepLinkTargetIdentifier(strings, target),
                        ),
                        _CupertinoListTile(
                          leading: const Icon(CupertinoIcons.link),
                          title: strings.text('Link'),
                          subtitle: uri.toString(),
                          trailing: CsacIconButton(
                            tooltip: strings.text('Copy'),
                            onPressed: () => copyLink(context),
                            icon: const Icon(CupertinoIcons.doc_on_doc),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    CupertinoButton.filled(
                      borderRadius: BorderRadius.circular(14),
                      onPressed: () => confirm(context),
                      child: Text(strings.text('Open')),
                    ),
                    const SizedBox(height: 8),
                    CupertinoButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(strings.text('Cancel')),
                    ),
                  ],
                )
              : _EmptyPanel(message: strings.text('Unsupported CsAC link.')),
        ),
      ),
    );
  }
}

class QrScanHistoryScreen extends StatefulWidget {
  const QrScanHistoryScreen({super.key});

  @override
  State<QrScanHistoryScreen> createState() => _QrScanHistoryScreenState();
}

class _QrScanHistoryScreenState extends State<QrScanHistoryScreen> {
  List<QrScanHistoryEntry> entries = const <QrScanHistoryEntry>[];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    final loaded = await QrScanHistoryStore.loadAll();
    if (mounted) {
      setState(() {
        entries = loaded;
        loading = false;
      });
    }
  }

  Future<void> clearHistory() async {
    await QrScanHistoryStore.clear();
    if (!mounted) {
      return;
    }
    setState(() => entries = const <QrScanHistoryEntry>[]);
    CsacToastMessenger.of(context).showToast(
      CsacToast(content: Text(context.strings.text('Scan history cleared.'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    return CsacPageScaffold(
      appBar: CsacNavigationBar(
        title: Text(strings.text('Scan history')),
        actions: [
          CsacIconButton(
            tooltip: strings.text('Clear history'),
            onPressed: entries.isEmpty ? null : clearHistory,
            icon: const Icon(CupertinoIcons.delete),
          ),
        ],
      ),
      backgroundColor: colors.systemBackground,
      body: SafeArea(
        child: loading
            ? Center(
                child: CupertinoActivityIndicator(color: colors.primaryColor),
              )
            : entries.isEmpty
            ? _EmptyPanel(message: strings.text('No scan history.'))
            : _AdaptivePageFrame(
                maxWidth: 680,
                child: CsacListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final uri = Uri.tryParse(entry.link);
                    final target = uri == null
                        ? const CsacDeepLinkTarget(
                            CsacDeepLinkAction.unsupported,
                          )
                        : parseCsacDeepLink(uri);
                    final canOpen =
                        uri != null &&
                        isCsacDeepLink(uri) &&
                        target.isSupported;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CupertinoGroupedCard(
                        margin: EdgeInsets.zero,
                        children: [
                          _CupertinoListTile(
                            leading: const Icon(CupertinoIcons.qrcode),
                            title: _deepLinkTargetLabel(strings, target),
                            subtitle: entry.link,
                            onTap: canOpen
                                ? () => Navigator.of(context).pop(uri)
                                : null,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class CsacQrScannerScreen extends StatefulWidget {
  const CsacQrScannerScreen({super.key});

  @override
  State<CsacQrScannerScreen> createState() => _CsacQrScannerScreenState();
}

class _CsacQrScannerScreenState extends State<CsacQrScannerScreen> {
  late final MobileScannerController controller;
  bool handling = false;
  bool pickingImage = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  @override
  void dispose() {
    unawaited(controller.dispose());
    super.dispose();
  }

  Future<bool> handleScannedValue(
    String value, {
    bool showInvalid = true,
  }) async {
    final strings = context.strings;
    final uri = Uri.tryParse(value);
    if (uri == null || !isCsacDeepLink(uri)) {
      if (showInvalid && mounted) {
        CsacToastMessenger.of(context).showToast(
          CsacToast(content: Text(strings.text('This is not a CsAC QR code.'))),
        );
      }
      return false;
    }
    final target = parseCsacDeepLink(uri);
    if (!target.isSupported) {
      if (showInvalid && mounted) {
        CsacToastMessenger.of(context).showToast(
          CsacToast(content: Text(strings.text('Unsupported CsAC link.'))),
        );
      }
      return false;
    }
    final confirmed = await confirmScannedCsacUri(context, uri);
    if (!mounted || confirmed == null) {
      return false;
    }
    Navigator.of(context).pop(confirmed);
    return true;
  }

  void handleDetect(BarcodeCapture capture) {
    if (handling) {
      return;
    }
    final value = firstQrBarcodeValue(capture);
    if (value == null) {
      return;
    }
    setState(() => handling = true);
    unawaited(controller.stop());
    unawaited(() async {
      final completed = await handleScannedValue(value, showInvalid: false);
      if (!completed && mounted) {
        setState(() => handling = false);
        unawaited(controller.start());
      }
    }());
  }

  Future<void> pickImageQr() async {
    if (pickingImage || handling) {
      return;
    }
    setState(() => pickingImage = true);
    var stoppedCamera = false;
    var completed = false;
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) {
        return;
      }
      setState(() => handling = true);
      await controller.stop();
      stoppedCamera = true;
      final value = await firstQrValueInImagePath(
        picked.path,
        scanner: controller,
      );
      if (!mounted) {
        return;
      }
      if (value == null) {
        CsacToastMessenger.of(context).showToast(
          CsacToast(
            content: Text(
              context.strings.text('No QR code found in this image.'),
            ),
          ),
        );
        return;
      }
      completed = await handleScannedValue(value);
    } catch (err) {
      if (mounted) {
        CsacToastMessenger.of(context).showToast(
          CsacToast(
            content: Text(
              context.strings.format('QR scan failed: {error}', {'error': err}),
            ),
          ),
        );
      }
    } finally {
      if (mounted && !completed) {
        setState(() {
          pickingImage = false;
          handling = false;
        });
        if (stoppedCamera) {
          unawaited(controller.start());
        }
      }
    }
  }

  Future<void> openHistory() async {
    if (handling) {
      return;
    }
    final uri = await Navigator.of(context).push<Uri>(
      CsacPageRoute<Uri>(builder: (_) => const QrScanHistoryScreen()),
    );
    if (!mounted || uri == null) {
      return;
    }
    Navigator.of(context).pop(uri);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = CsacColors.of(context);
    if (!isMobilePlatform) {
      return CsacPageScaffold(
        appBar: CsacNavigationBar(title: Text(strings.text('Scan QR code'))),
        body: _EmptyPanel(
          message: strings.text('QR scanning is only available on mobile.'),
        ),
      );
    }
    return CsacPageScaffold(
      backgroundColor: CupertinoColors.black,
      appBar: CsacNavigationBar(
        title: Text(strings.text('Scan QR code')),
        actions: [
          CsacIconButton(
            tooltip: strings.text('Scan history'),
            onPressed: handling ? null : openHistory,
            icon: const Icon(CupertinoIcons.clock),
          ),
          CsacIconButton(
            tooltip: strings.text('Choose from album'),
            onPressed: pickingImage || handling ? null : pickImageQr,
            icon: pickingImage
                ? CupertinoActivityIndicator(color: colors.primaryColor)
                : const Icon(CupertinoIcons.photo_on_rectangle),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: controller, onDetect: handleDetect),
          Center(
            child: IgnorePointer(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.white, width: 3),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              color: CupertinoColors.black.withValues(alpha: 0.62),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.qrcode_viewfinder,
                    color: CupertinoColors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.text(
                      'Scan a CsAC user or group QR code or link QR code',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strings.text('Only CsAC URL scheme links will be opened.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CupertinoColors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (handling)
            const Center(child: CupertinoActivityIndicator(radius: 16)),
        ],
      ),
    );
  }
}

Future<Uri?> openCsacQrScanner(BuildContext context) {
  return Navigator.of(
    context,
  ).push<Uri>(CsacPageRoute<Uri>(builder: (_) => const CsacQrScannerScreen()));
}

String _deepLinkTargetLabel(CsacStrings strings, CsacDeepLinkTarget target) {
  switch (target.action) {
    case CsacDeepLinkAction.chats:
      return strings.text('Chats');
    case CsacDeepLinkAction.search:
    case CsacDeepLinkAction.searchResult:
      return strings.text('Search');
    case CsacDeepLinkAction.space:
      return strings.text('Space');
    case CsacDeepLinkAction.spacePost:
      return strings.text('Post QR code');
    case CsacDeepLinkAction.notices:
      return strings.text('Notices');
    case CsacDeepLinkAction.profile:
      return strings.text('Me');
    case CsacDeepLinkAction.userProfile:
      return strings.text('Profile');
    case CsacDeepLinkAction.groupChat:
      return strings.text('Group chat');
    case CsacDeepLinkAction.privateChat:
      return strings.text('Private chat');
    case CsacDeepLinkAction.groupMessage:
    case CsacDeepLinkAction.privateMessage:
      return strings.text('Message QR code');
    case CsacDeepLinkAction.unsupported:
      return strings.text('Unsupported CsAC link.');
  }
}

String _deepLinkTargetIdentifier(
  CsacStrings strings,
  CsacDeepLinkTarget target,
) {
  if (target.query?.trim().isNotEmpty == true) {
    return target.query!.trim();
  }
  final id = target.id;
  final messageId = target.messageId;
  if (id != null && messageId != null) {
    return '$id / $messageId';
  }
  if (id != null) {
    return '$id';
  }
  return strings.text('None');
}
