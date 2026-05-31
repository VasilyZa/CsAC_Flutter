import 'dart:convert';

import 'package:flutter/services.dart';

class ChatExportWriteResult {
  const ChatExportWriteResult({
    required this.filePath,
    required this.mediaDirectoryPath,
  });

  final String filePath;
  final String mediaDirectoryPath;
}

Future<ChatExportWriteResult> writeChatExportFile({
  required String directory,
  required String baseName,
  required String extension,
  required String content,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  await Clipboard.setData(ClipboardData(text: content));
  return ChatExportWriteResult(
    filePath:
        '$baseName.$extension (copied to clipboard, ${bytes.length} bytes)',
    mediaDirectoryPath: '',
  );
}

Future<void> ensureDirectoryExists(String path) async {}

Future<String> writeChatExportMediaFile({
  required String mediaDirectoryPath,
  required String fileName,
  required List<int> bytes,
}) async {
  return '';
}
