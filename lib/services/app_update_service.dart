import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseUrl;
  final String? apkUrl;
  final String releaseNotes;

  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseUrl,
    required this.apkUrl,
    required this.releaseNotes,
  });

  String get downloadUrl => apkUrl ?? releaseUrl;
}

class AppUpdateService {
  static const _latestReleaseApi =
      'https://api.github.com/repos/ManhCuong2005/QuanLyChiTieu/releases/latest';

  static Future<AppUpdateInfo?> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final response = await http
        .get(
          Uri.parse(_latestReleaseApi),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 404) {
      // GitHub returns 404 when the repository has no published release.
      return null;
    }
    if (response.statusCode != 200) {
      throw Exception('GitHub trả về mã ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final latestVersion = _normalizeVersion(json['tag_name'] as String? ?? '');
    final currentVersion = _normalizeVersion(packageInfo.version);
    if (latestVersion.isEmpty ||
        !_isNewerVersion(latestVersion, currentVersion)) {
      return null;
    }

    String? apkUrl;
    final assets = json['assets'];
    if (assets is List) {
      for (final asset in assets.whereType<Map<String, dynamic>>()) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
    }

    return AppUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      releaseUrl:
          json['html_url'] as String? ??
          'https://github.com/ManhCuong2005/QuanLyChiTieu/releases/latest',
      apkUrl: apkUrl,
      releaseNotes: json['body'] as String? ?? '',
    );
  }

  static Future<void> openDownload(AppUpdateInfo update) async {
    final uri = Uri.parse(update.downloadUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Không thể mở liên kết tải bản cập nhật.');
    }
  }

  static String _normalizeVersion(String value) {
    final match = RegExp(r'\d+(?:\.\d+)*').firstMatch(value.trim());
    return match?.group(0) ?? '';
  }

  static bool _isNewerVersion(String latest, String current) {
    final latestParts = latest.split('.').map(int.parse).toList();
    final currentParts = current.split('.').map(int.parse).toList();
    final length =
        latestParts.length > currentParts.length
            ? latestParts.length
            : currentParts.length;

    for (var index = 0; index < length; index++) {
      final latestPart = index < latestParts.length ? latestParts[index] : 0;
      final currentPart =
          index < currentParts.length ? currentParts[index] : 0;
      if (latestPart != currentPart) return latestPart > currentPart;
    }
    return false;
  }
}
