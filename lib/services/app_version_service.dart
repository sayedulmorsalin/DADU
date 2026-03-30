import 'package:package_info_plus/package_info_plus.dart';

class AppVersionService {
  AppVersionService._();

  static Future<String> getInstalledVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  static Future<bool> isUpdateRequired(String remoteVersion) async {
    final installedVersion = await getInstalledVersion();
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

    final values =
        RegExp(r'\d+')
            .allMatches(sanitized)
            .map((match) => int.tryParse(match.group(0)!) ?? 0)
            .toList();

    return values.isEmpty ? [0] : values;
  }
}
