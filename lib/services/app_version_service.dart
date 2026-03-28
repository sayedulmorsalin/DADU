import 'package:package_info_plus/package_info_plus.dart';

class AppVersionService {
  AppVersionService._();

  static final Future<String> _installedVersion = _loadInstalledVersion();

  static Future<String> _loadInstalledVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  static Future<bool> isUpdateRequired(String remoteVersion) async {
    final installedVersion = await _installedVersion;
    return compareVersions(remoteVersion, installedVersion) > 0;
  }

  static int compareVersions(String first, String second) {
    final firstParts = _normalizeVersion(first);
    final secondParts = _normalizeVersion(second);
    final maxLength =
        firstParts.length > secondParts.length
            ? firstParts.length
            : secondParts.length;

    for (var index = 0; index < maxLength; index++) {
      final firstValue = index < firstParts.length ? firstParts[index] : 0;
      final secondValue = index < secondParts.length ? secondParts[index] : 0;

      if (firstValue != secondValue) {
        return firstValue.compareTo(secondValue);
      }
    }

    return 0;
  }

  static List<int> _normalizeVersion(String version) {
    final sanitized = version.trim();
    if (sanitized.isEmpty) {
      return [0];
    }

    final replacedBuildSeparator = sanitized.replaceAll('+', '.');
    final segments = replacedBuildSeparator.split('.');
    final values =
        segments.map((segment) => int.tryParse(segment.trim()) ?? 0).toList();

    return values.isEmpty ? [0] : values;
  }
}
