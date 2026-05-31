import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<int> backgroundStorageBytes() async {
  return _directoryBytes(await _backgroundDirectory());
}

Future<int> logStorageBytes() async {
  return await _directoryBytes(await _logDirectory()) +
      await _temporaryFilesBytes(_looksLikeLogFile);
}

Future<int> voiceTemporaryStorageBytes() {
  return _temporaryFilesBytes((name) => name.startsWith('csac_voice_'));
}

Future<List<StoredAppLogFile>> loadStoredAppLogFiles() async {
  final files = <StoredAppLogFile>[];
  await _collectLogFiles(await _logDirectory(), files, recursive: true);
  await _collectLogFiles(await getTemporaryDirectory(), files);
  final byPath = <String, StoredAppLogFile>{
    for (final file in files) file.path: file,
  };
  final sorted = byPath.values.toList()
    ..sort((a, b) => b.modified.compareTo(a.modified));
  return sorted;
}

Future<String> readStoredTextFile(
  String path, {
  int maxBytes = 256 * 1024,
}) async {
  final file = File(path);
  if (!await file.exists()) {
    return '';
  }
  final length = await file.length();
  final start = length > maxBytes ? length - maxBytes : 0;
  final stream = file.openRead(start);
  return String.fromCharCodes(await stream.expand((chunk) => chunk).toList());
}

Future<void> clearStoredImageCaches() async {
  await _deleteDirectoryContents(await _backgroundDirectory());
  await _deleteTemporaryFiles((name) => name.startsWith('csac_voice_'));
}

Future<void> clearStoredLogCaches() async {
  await _deleteDirectoryContents(await _logDirectory());
  await _deleteTemporaryFiles(_looksLikeLogFile);
}

class StoredAppLogFile {
  const StoredAppLogFile({
    required this.path,
    required this.name,
    required this.bytes,
    required this.modified,
  });

  final String path;
  final String name;
  final int bytes;
  final DateTime modified;
}

Future<Directory> _backgroundDirectory() async {
  final support = await getApplicationSupportDirectory();
  return Directory(p.join(support.path, 'backgrounds'));
}

Future<Directory> _logDirectory() async {
  final support = await getApplicationSupportDirectory();
  return Directory(p.join(support.path, 'logs'));
}

Future<int> _directoryBytes(Directory directory) async {
  if (!await directory.exists()) {
    return 0;
  }
  var total = 0;
  await for (final entity in directory.list(recursive: true)) {
    if (entity is File) {
      total += await entity.length();
    }
  }
  return total;
}

Future<int> _temporaryFilesBytes(bool Function(String name) include) async {
  final directory = await getTemporaryDirectory();
  if (!await directory.exists()) {
    return 0;
  }
  var total = 0;
  await for (final entity in directory.list()) {
    if (entity is File && include(p.basename(entity.path).toLowerCase())) {
      total += await entity.length();
    }
  }
  return total;
}

Future<void> _collectLogFiles(
  Directory directory,
  List<StoredAppLogFile> files, {
  bool recursive = false,
}) async {
  if (!await directory.exists()) {
    return;
  }
  await for (final entity in directory.list(recursive: recursive)) {
    if (entity is! File ||
        !_looksLikeLogFile(p.basename(entity.path).toLowerCase())) {
      continue;
    }
    final stat = await entity.stat();
    files.add(
      StoredAppLogFile(
        path: entity.path,
        name: p.basename(entity.path),
        bytes: stat.size,
        modified: stat.modified,
      ),
    );
  }
}

Future<void> _deleteDirectoryContents(Directory directory) async {
  if (!await directory.exists()) {
    return;
  }
  await for (final entity in directory.list(recursive: false)) {
    await entity.delete(recursive: true);
  }
}

Future<void> _deleteTemporaryFiles(bool Function(String name) include) async {
  final directory = await getTemporaryDirectory();
  if (!await directory.exists()) {
    return;
  }
  await for (final entity in directory.list()) {
    if (entity is File && include(p.basename(entity.path).toLowerCase())) {
      await entity.delete();
    }
  }
}

bool _looksLikeLogFile(String name) {
  return name.endsWith('.log') ||
      name.endsWith('.log.txt') ||
      name.startsWith('csac_log_');
}
