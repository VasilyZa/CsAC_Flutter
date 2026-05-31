import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class VersionUpdateInfo {
  const VersionUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.displayCurrentVersion,
    required this.displayLatestVersion,
    required this.releaseName,
    required this.releaseUrl,
    required this.releaseNotes,
    required this.publishedAt,
    required this.hasUpdate,
  });

  final String currentVersion;
  final String latestVersion;
  final String displayCurrentVersion;
  final String displayLatestVersion;
  final String releaseName;
  final String releaseUrl;
  final String releaseNotes;
  final DateTime? publishedAt;
  final bool hasUpdate;
}

class VersionUpdateChecker {
  VersionUpdateChecker({http.Client? client})
    : client = client ?? http.Client();

  static const latestReleaseUrl =
      'https://api.github.com/repos/Leonmmcoset/csac-terminal/releases/latest';

  final http.Client client;

  void close() {
    client.close();
  }

  Future<VersionUpdateInfo> check({
    required String currentVersion,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final response = await client
        .get(
          Uri.parse(latestReleaseUrl),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'CsAC-Mobile-Version-Checker',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('GitHub API returned HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('GitHub API returned an invalid response.');
    }
    final tagName = _stringValue(decoded['tag_name']);
    final releaseName = _stringValue(decoded['name']);
    final latestVersion = tagName.isEmpty ? releaseName : tagName;
    if (latestVersion.trim().isEmpty) {
      throw const FormatException('GitHub release has no version tag.');
    }
    final htmlUrl = _stringValue(decoded['html_url']);
    final body = _stringValue(decoded['body']);
    final publishedAt = DateTime.tryParse(
      _stringValue(decoded['published_at']),
    );
    return VersionUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      displayCurrentVersion: displayVersion(currentVersion),
      displayLatestVersion: displayVersion(latestVersion),
      releaseName: releaseName.isEmpty ? latestVersion : releaseName,
      releaseUrl: htmlUrl,
      releaseNotes: body,
      publishedAt: publishedAt,
      hasUpdate: !versionMatches(currentVersion, latestVersion),
    );
  }

  static bool versionMatches(String currentVersion, String releaseVersion) {
    final current = _canonicalVersion(currentVersion);
    final release = _canonicalVersion(releaseVersion);
    if (current.full.isNotEmpty && release.full.isNotEmpty) {
      return current.full == release.full;
    }
    return current.base.isNotEmpty && current.base == release.base;
  }

  static String displayVersion(String value) {
    final version = _canonicalVersion(value);
    return version.full.isEmpty ? value.trim() : version.full;
  }

  static ({String base, String full}) _canonicalVersion(String value) {
    var normalized = value.trim().toLowerCase();
    if (normalized.startsWith('refs/tags/')) {
      normalized = normalized.substring('refs/tags/'.length);
    }
    if (normalized.startsWith('release-')) {
      normalized = normalized.substring('release-'.length);
    }
    if (normalized.startsWith('v')) {
      normalized = normalized.substring(1);
    }
    final match = RegExp(
      r'(\d+(?:\.\d+){1,3})(?:[+\-]([0-9a-z][0-9a-z.\-]*))?',
    ).firstMatch(normalized);
    if (match == null) {
      return (base: normalized, full: normalized);
    }
    final base = match.group(1) ?? '';
    final build = match.group(2) ?? '';
    return (base: base, full: build.isEmpty ? base : '$base+$build');
  }

  static String _stringValue(Object? value) {
    if (value == null) {
      return '';
    }
    return '$value'.trim();
  }
}
