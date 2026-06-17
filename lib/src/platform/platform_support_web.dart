import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

bool get isWebPlatform => true;

bool get isDesktopPlatform => false;

bool get isMobilePlatform => false;

bool get supportsVersionUpdateChecks => false;

bool get supportsLocalFiles => false;

bool get supportsVoiceRecording => false;

bool get supportsLocalAuth => false;

bool get isApplePlatform => false;

bool get shouldForceHideMobileTextInput => false;

void installGlobalBadCertificateOverride() {}

void configureInsecureHttpsOverrides() => installGlobalBadCertificateOverride();

void hidePlatformTextInput() {
  FocusManager.instance.primaryFocus?.unfocus();
}

Future<String> persistChatBackgroundFile(XFile picked) async {
  throw UnsupportedError('Chat background files are not supported on Web.');
}

Future<XFile?> pickImageForMobileGallery({int imageQuality = 92}) async {
  throw UnsupportedError('Image picking is not supported on Web here.');
}

Future<String> createMobileChatExportDirectory(String baseName) async {
  throw UnsupportedError('Local chat exports are not supported on Web.');
}

Future<String?> saveDownloadedBytes({
  required Uint8List bytes,
  required String suggestedName,
  String typeLabel = '',
  List<String> extensions = const <String>[],
}) async {
  throw UnsupportedError('File downloads are handled by the browser.');
}

Future<bool> localFileExists(String path) async => false;

bool localFileExistsSync(String path) => false;

ImageProvider<Object>? localFileImageProvider(String path) => null;

Future<Uint8List?> readLocalFileBytes(String path) async => null;

String basenameOfPath(String path) {
  final normalized = path.replaceAll(r'\', '/');
  final index = normalized.lastIndexOf('/');
  return index < 0 ? normalized : normalized.substring(index + 1);
}

Future<String> cacheVoiceBytes({
  required int messageId,
  required String sourceUrl,
  required Future<Uint8List> Function() loadBytes,
}) async {
  throw UnsupportedError('Voice file caching is not supported on Web.');
}

Future<bool> localFileLooksLikeHtml(String path) async => false;

Future<String> createTemporaryVoicePath() async {
  throw UnsupportedError('Voice recording is not supported on Web.');
}

Future<String> writeTemporaryQrScanImage(
  Uint8List bytes,
  String sourceName,
) async {
  throw UnsupportedError('QR image scanning is not supported on Web.');
}

Future<void> deleteLocalFileIfExists(String path) async {}
