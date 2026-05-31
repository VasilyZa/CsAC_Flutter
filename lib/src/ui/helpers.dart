part of '../../main.dart';

String compactMessage(String text, {int max = 80}) {
  final value = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (value.length <= max) {
    return value;
  }
  return '${value.substring(0, max - 3)}...';
}

CsacTimestampPattern timestampPatternForPreference(MessageTimeFormat format) {
  switch (format) {
    case MessageTimeFormat.slash:
      return CsacTimestampPattern.slash;
    case MessageTimeFormat.dash:
      return CsacTimestampPattern.dash;
    case MessageTimeFormat.compact:
      return CsacTimestampPattern.compact;
    case MessageTimeFormat.timeOnly:
      return CsacTimestampPattern.timeOnly;
  }
}

String displayMessageTime(ChatMessage message, CsacPreferences preferences) {
  return formatCsacTimestamp(
    message.timeSortValue > 0 ? message.timeSortValue : message.time,
    pattern: timestampPatternForPreference(preferences.messageTimeFormat),
  );
}

String messageTimeFormatLabelFor(
  BuildContext context,
  MessageTimeFormat format,
) {
  switch (format) {
    case MessageTimeFormat.slash:
      return context.strings.text('yyyy/mm/dd hh:mm:ss');
    case MessageTimeFormat.dash:
      return context.strings.text('yyyy-mm-dd hh:mm:ss');
    case MessageTimeFormat.compact:
      return context.strings.text('mm/dd hh:mm');
    case MessageTimeFormat.timeOnly:
      return context.strings.text('hh:mm:ss');
  }
}

String messageTimeFormatExampleFor(MessageTimeFormat format) {
  final sample = DateTime(2026, 5, 28, 21, 30, 15);
  switch (format) {
    case MessageTimeFormat.slash:
      return formatLocalDateTime(sample, separator: '/');
    case MessageTimeFormat.dash:
      return formatLocalDateTime(sample, separator: '-');
    case MessageTimeFormat.compact:
      return formatCompactLocalDateTime(sample);
    case MessageTimeFormat.timeOnly:
      return formatLocalTime(sample);
  }
}

String chatBubbleCornerStyleLabelFor(
  BuildContext context,
  ChatBubbleCornerStyle style,
) {
  switch (style) {
    case ChatBubbleCornerStyle.telegram:
      return context.strings.text('Telegram style');
    case ChatBubbleCornerStyle.ios:
      return context.strings.text('iOS style');
    case ChatBubbleCornerStyle.qq:
      return context.strings.text('QQ style');
  }
}

String fontStyleLabelFor(BuildContext context, CsacFontStyle style) {
  final strings = context.strings;
  switch (style) {
    case CsacFontStyle.system:
      return strings.text('Default system');
    case CsacFontStyle.serif:
      return strings.text('Serif');
    case CsacFontStyle.rounded:
      return strings.text('Rounded');
    case CsacFontStyle.monospace:
      return strings.text('Monospace');
  }
}

String fontStyleDescriptionFor(BuildContext context, CsacFontStyle style) {
  final strings = context.strings;
  switch (style) {
    case CsacFontStyle.system:
      return strings.text('Use the platform default font');
    case CsacFontStyle.serif:
      return strings.text('More book-like text');
    case CsacFontStyle.rounded:
      return strings.text('Softer iOS-style rounded text');
    case CsacFontStyle.monospace:
      return strings.text('Fixed-width terminal-like text');
  }
}

String pickedImageFileName(XFile picked, ImageSource source) {
  final name = picked.name.trim();
  final extension = p.extension(name).toLowerCase();
  if (name.isNotEmpty && extension.isNotEmpty) {
    return name;
  }
  final fallbackExtension = extension.isEmpty ? '.jpg' : extension;
  final prefix = source == ImageSource.camera ? 'csac_photo' : 'csac_image';
  return '${prefix}_${DateTime.now().millisecondsSinceEpoch}$fallbackExtension';
}

Future<String> persistChatBackground(XFile picked) async {
  final support = await getApplicationSupportDirectory();
  final directory = Directory(p.join(support.path, 'backgrounds'));
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  final extension = p.extension(picked.name).trim().isEmpty
      ? '.jpg'
      : p.extension(picked.name);
  final target = File(
    p.join(
      directory.path,
      'chat_background_${DateTime.now().millisecondsSinceEpoch}$extension',
    ),
  );
  final bytes = await picked.readAsBytes();
  await target.writeAsBytes(bytes, flush: true);
  return target.path;
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}
