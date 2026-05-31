Future<int> backgroundStorageBytes() async => 0;

Future<int> logStorageBytes() async => 0;

Future<int> voiceTemporaryStorageBytes() async => 0;

Future<List<StoredAppLogFile>> loadStoredAppLogFiles() async {
  return const <StoredAppLogFile>[];
}

Future<String> readStoredTextFile(
  String path, {
  int maxBytes = 256 * 1024,
}) async {
  return '';
}

Future<void> clearStoredImageCaches() async {}

Future<void> clearStoredLogCaches() async {}

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
