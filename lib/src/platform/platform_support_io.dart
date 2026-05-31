import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

bool get isWebPlatform => false;

bool get isDesktopPlatform =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

bool get supportsLocalFiles => true;

bool get supportsVoiceRecording => true;

bool get supportsLocalAuth => true;

bool get isApplePlatform => Platform.isIOS || Platform.isMacOS;

bool get shouldForceHideMobileTextInput => Platform.isIOS || Platform.isAndroid;

void hidePlatformTextInput() {
  FocusManager.instance.primaryFocus?.unfocus();
  if (shouldForceHideMobileTextInput) {
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
  }
}

Future<String> persistChatBackgroundFile(XFile picked) async {
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

Future<bool> localFileExists(String path) async {
  return path.isNotEmpty && await File(path).exists();
}

bool localFileExistsSync(String path) {
  return path.isNotEmpty && File(path).existsSync();
}

ImageProvider<Object>? localFileImageProvider(String path) {
  if (!localFileExistsSync(path)) {
    return null;
  }
  return FileImage(File(path));
}

Future<Uint8List?> readLocalFileBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    return null;
  }
  return file.readAsBytes();
}

String basenameOfPath(String path) => p.basename(path);

Future<String> cacheVoiceBytes({
  required int messageId,
  required String sourceUrl,
  required Future<Uint8List> Function() loadBytes,
}) async {
  final uri = Uri.parse(sourceUrl);
  final extension = p.extension(uri.path).isEmpty
      ? '.m4a'
      : p.extension(uri.path);
  final directory = await getTemporaryDirectory();
  final path = p.join(directory.path, 'csac_voice_$messageId$extension');
  final file = File(path);
  if (await file.exists() &&
      await file.length() > 0 &&
      !await localFileLooksLikeHtml(path)) {
    return path;
  }
  final bytes = await loadBytes();
  await file.writeAsBytes(bytes, flush: true);
  return path;
}

Future<bool> localFileLooksLikeHtml(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    return false;
  }
  final stream = file.openRead(0, mathMin(256, await file.length()));
  final bytes = await stream.expand((chunk) => chunk).toList();
  final text = String.fromCharCodes(bytes).trimLeft().toLowerCase();
  return text.startsWith('<!doctype html') ||
      text.startsWith('<html') ||
      text.startsWith('<script');
}

int mathMin(int a, int b) => a < b ? a : b;

Future<String> createTemporaryVoicePath() async {
  final directory = await getTemporaryDirectory();
  return p.join(
    directory.path,
    'csac_voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
  );
}

Future<void> deleteLocalFileIfExists(String path) async {
  final file = File(path);
  if (await file.exists()) {
    await file.delete();
  }
}
