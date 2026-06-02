import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

bool get isWebPlatform => false;

bool get isDesktopPlatform =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

bool get supportsVersionUpdateChecks => true;

bool get supportsLocalFiles => true;

bool get supportsVoiceRecording => true;

bool get supportsLocalAuth => true;

bool get isApplePlatform => Platform.isIOS || Platform.isMacOS;

bool get shouldForceHideMobileTextInput => Platform.isIOS || Platform.isAndroid;

void installGlobalBadCertificateOverride() {
  final previous = HttpOverrides.current;
  if (previous is _AcceptAllCertificatesHttpOverrides) {
    return;
  }
  HttpOverrides.global = _AcceptAllCertificatesHttpOverrides(previous);
}

http.Client createPlatformHttpClient({
  String userAgent = 'CsAC-Mobile',
  bool preferCronet = true,
}) {
  if (Platform.isAndroid && preferCronet) {
    return AndroidOkHttpClient(userAgent: userAgent);
  }
  return http.Client();
}

String? lastPlatformHttpProtocol(http.Client client) {
  if (client is AndroidOkHttpClient) {
    return client.lastProtocol;
  }
  if (isDesktopPlatform) {
    return 'HTTP/1.1';
  }
  return null;
}

String? _normalizeHttpProtocol(String? value) {
  final text = value?.trim().toLowerCase() ?? '';
  if (text.isEmpty) {
    return null;
  }
  if (text == 'h2' || text == 'http_2' || text == 'http/2') {
    return 'HTTP/2';
  }
  if (text == 'http/1.1' || text == 'http_1_1') {
    return 'HTTP/1.1';
  }
  return value;
}

class _AcceptAllCertificatesHttpOverrides extends HttpOverrides {
  _AcceptAllCertificatesHttpOverrides(this.previous);

  final HttpOverrides? previous;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client =
        previous?.createHttpClient(context) ?? super.createHttpClient(context);
    client.badCertificateCallback = (_, _, _) => true;
    return client;
  }
}

class AndroidOkHttpClient extends http.BaseClient {
  AndroidOkHttpClient({required this.userAgent});

  static const _channel = MethodChannel('csac/android_http');

  final String userAgent;
  bool _closed = false;
  String? _lastProtocol;

  String? get lastProtocol => _lastProtocol;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) {
      throw http.ClientException('HTTP client is closed.', request.url);
    }
    final body = await request.finalize().toBytes();
    final headers = Map<String, String>.from(request.headers);
    headers.putIfAbsent('User-Agent', () => userAgent);
    final result = await _channel
        .invokeMapMethod<String, Object?>('send', <String, Object?>{
          'method': request.method,
          'url': request.url.toString(),
          'headers': headers,
          'body': body,
        });
    if (result == null) {
      throw http.ClientException(
        'Android HTTP returned no response.',
        request.url,
      );
    }
    final statusCode = (result['statusCode'] as num?)?.toInt() ?? 0;
    final responseHeaders = (result['headers'] as Map<Object?, Object?>? ?? {})
        .map((key, value) => MapEntry('$key'.toLowerCase(), '$value'));
    final responseBody = result['body'];
    _lastProtocol = _normalizeProtocol(result['protocol']?.toString());
    final bytes = responseBody is Uint8List
        ? responseBody
        : utf8.encode(responseBody?.toString() ?? '');
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      statusCode,
      contentLength: bytes.length,
      request: request,
      headers: responseHeaders,
      reasonPhrase: result['reasonPhrase']?.toString(),
    );
  }

  @override
  void close() {
    _closed = true;
  }

  String? _normalizeProtocol(String? value) {
    return _normalizeHttpProtocol(value);
  }
}

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

Future<String?> saveDownloadedBytes({
  required Uint8List bytes,
  required String suggestedName,
  String typeLabel = '',
  List<String> extensions = const <String>[],
}) async {
  if (isDesktopPlatform) {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: extensions.isEmpty
          ? const <XTypeGroup>[]
          : <XTypeGroup>[XTypeGroup(label: typeLabel, extensions: extensions)],
    );
    if (location == null) {
      return null;
    }
    var targetPath = location.path;
    if (p.extension(targetPath).isEmpty) {
      final activeExt = location.activeFilter?.extensions?.firstOrNull;
      final ext = activeExt ?? p.extension(suggestedName).replaceFirst('.', '');
      if (ext.isNotEmpty) {
        targetPath = '$targetPath.$ext';
      }
    }
    await File(targetPath).writeAsBytes(bytes, flush: true);
    return targetPath;
  }

  final directory = await _mobileDownloadDirectory();
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  final safeName = _safeDownloadFileName(suggestedName);
  final target = await _uniqueFile(directory, safeName);
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

Future<Directory> _mobileDownloadDirectory() async {
  if (Platform.isAndroid) {
    final external = await getExternalStorageDirectory();
    if (external != null) {
      return Directory(p.join(external.path, 'Downloads'));
    }
  }
  final documents = await getApplicationDocumentsDirectory();
  return Directory(p.join(documents.path, 'Downloads'));
}

String _safeDownloadFileName(String name) {
  final cleaned = name
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ');
  return cleaned.isEmpty ? 'csac_download.bin' : cleaned;
}

Future<File> _uniqueFile(Directory directory, String fileName) async {
  final extension = p.extension(fileName);
  final baseName = extension.isEmpty
      ? fileName
      : fileName.substring(0, fileName.length - extension.length);
  var candidate = File(p.join(directory.path, fileName));
  var suffix = 1;
  while (await candidate.exists()) {
    candidate = File(p.join(directory.path, '${baseName}_$suffix$extension'));
    suffix += 1;
  }
  return candidate;
}

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
