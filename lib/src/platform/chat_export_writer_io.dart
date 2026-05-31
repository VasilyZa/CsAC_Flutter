import 'dart:io';

import 'package:path/path.dart' as p;

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
  final exportDirectory = Directory(directory);
  if (!exportDirectory.existsSync()) {
    exportDirectory.createSync(recursive: true);
  }
  final file = File(p.join(exportDirectory.path, '$baseName.$extension'));
  await file.writeAsString(content, flush: true);
  return ChatExportWriteResult(
    filePath: file.path,
    mediaDirectoryPath: p.join(exportDirectory.path, '${baseName}_media'),
  );
}

Future<void> ensureDirectoryExists(String path) async {
  final directory = Directory(path);
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
}

Future<String> writeChatExportMediaFile({
  required String mediaDirectoryPath,
  required String fileName,
  required List<int> bytes,
}) async {
  final file = File(p.join(mediaDirectoryPath, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return '${p.basename(mediaDirectoryPath)}/$fileName';
}
