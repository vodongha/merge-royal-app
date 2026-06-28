import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

import '../theme/app_theme.dart';

/// Google Play **in-app updates** (flexible / background flow).
///
/// On launch we ask Play whether a newer version is available. If so we start a
/// *flexible* update: the new APK downloads in the background while the player
/// keeps playing, then we surface a "Restart to update" snackbar that installs
/// it via [InAppUpdate.completeFlexibleUpdate].
///
/// Notes:
/// - Android only; no-op on web/iOS/desktop.
/// - Only works for builds installed from Google Play (internal-testing track or
///   production). It throws on debug/sideloaded builds — we swallow that.
class UpdateService {
  UpdateService._();

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  static Future<void> checkForFlexibleUpdate(BuildContext context) async {
    if (!_supported) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) {
        return;
      }
      if (info.flexibleUpdateAllowed) {
        // Downloads in the background; resolves once fully downloaded.
        await InAppUpdate.startFlexibleUpdate();
        if (context.mounted) _promptRestart(context);
      } else if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (_) {
      // No Play context (debug/sideload) or user dismissed — ignore quietly.
    }
  }

  static void _promptRestart(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 12),
        backgroundColor: AppTheme.panel,
        behavior: SnackBarBehavior.floating,
        content: const Text('Update downloaded',
            style: TextStyle(color: Colors.white)),
        action: SnackBarAction(
          label: 'RESTART',
          textColor: AppTheme.neon,
          onPressed: () {
            InAppUpdate.completeFlexibleUpdate();
          },
        ),
      ),
    );
  }
}
