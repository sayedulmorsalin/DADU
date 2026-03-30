import 'dart:io';

import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

class AppVersionService {
  AppVersionService._();

  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.sayedulmarsalin.dadu';

  static Future<bool> isUpdateRequired() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      return _isUpdateAvailable(updateInfo);
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } on UnsupportedError {
      return false;
    }
  }

  static Future<bool> openUpdateFlow() async {
    if (Platform.isAndroid) {
      try {
        final updateInfo = await InAppUpdate.checkForUpdate();

        if (_isUpdateAvailable(updateInfo)) {
          if (updateInfo.immediateUpdateAllowed) {
            await InAppUpdate.performImmediateUpdate();
            return true;
          }

          if (updateInfo.flexibleUpdateAllowed) {
            await InAppUpdate.startFlexibleUpdate();
            await InAppUpdate.completeFlexibleUpdate();
            return true;
          }
        }
      } on MissingPluginException {
      } on PlatformException {
      } on UnsupportedError {}
    }

    return _openPlayStorePage();
  }

  static bool _isUpdateAvailable(AppUpdateInfo updateInfo) {
    return updateInfo.updateAvailability ==
            UpdateAvailability.updateAvailable ||
        updateInfo.updateAvailability ==
            UpdateAvailability.developerTriggeredUpdateInProgress;
  }

  static Future<bool> _openPlayStorePage() async {
    final uri = Uri.parse(playStoreUrl);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
