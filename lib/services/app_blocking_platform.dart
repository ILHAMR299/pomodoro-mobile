import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/installed_application.dart';

class AppBlockingPlatform {
  AppBlockingPlatform._();

  static const _channel = MethodChannel('com.focusmaxx/app_blocking');

  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android;

  static Future<List<InstalledApplication>> installedApplications() async {
    final rows = await _channel.invokeListMethod<Object?>(
      'installedApplications',
    );
    return (rows ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(InstalledApplication.fromMap)
        .toList(growable: false);
  }

  static Future<bool> hasUsageAccess() async =>
      await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;

  static Future<bool> canDrawOverlays() async =>
      await _channel.invokeMethod<bool>('canDrawOverlays') ?? false;

  static Future<bool> hasNotificationPermission() async =>
      await _channel.invokeMethod<bool>('hasNotificationPermission') ?? true;

  static Future<void> openUsageAccessSettings() =>
      _channel.invokeMethod<void>('openUsageAccessSettings');

  static Future<void> openOverlaySettings() =>
      _channel.invokeMethod<void>('openOverlaySettings');

  static Future<void> openNotificationSettings() =>
      _channel.invokeMethod<void>('openNotificationSettings');

  static Future<bool> takePendingEndSession() async =>
      await _channel.invokeMethod<bool>('takePendingEndSession') ?? false;

  static void setEndSessionHandler(VoidCallback? onEndSession) {
    if (onEndSession == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'endFocusSession') onEndSession();
    });
  }

  static Future<bool> requestNotificationPermission() async =>
      await _channel.invokeMethod<bool>('requestNotificationPermission') ??
      false;

  static Future<void> startMonitoring(
    List<String> packageNames, {
    required bool monitoringEnabled,
    int? resumeAtEpochMillis,
  }) => _channel.invokeMethod<void>('startMonitoring', {
    'packageNames': packageNames,
    'monitoringEnabled': monitoringEnabled,
    'resumeAtEpochMillis': resumeAtEpochMillis,
  });

  static Future<void> updateMonitoring(
    List<String> packageNames, {
    required bool enabled,
    int? resumeAtEpochMillis,
  }) => _channel.invokeMethod<void>('updateMonitoring', {
    'packageNames': packageNames,
    'monitoringEnabled': enabled,
    'resumeAtEpochMillis': resumeAtEpochMillis,
  });

  static Future<void> stopMonitoring() =>
      _channel.invokeMethod<void>('stopMonitoring');
}
