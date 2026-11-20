# App Blocking (Android)

## Architecture

- Flutter presents the app picker and permission explanations. `AppBlockingPlatform` communicates with `MainActivity` over `com.focusmaxx/app_blocking`.
- `MainActivity` lists launcher-visible apps and checks special access. The manifest declares only the `MAIN`/`LAUNCHER` query; FocusMaxx does not request `QUERY_ALL_PACKAGES`.
- `DatabaseHelper` stores selected packages, per-user settings, and Pomodoro snapshots in SQLite schema version 5.
- `AppBlockingService` is a native foreground service. It reads `UsageEvents` every 1.5 seconds while blocking is active, then draws a `TYPE_APPLICATION_OVERLAY` reminder for a selected app. The service stops on pause/reset/end, or idles without polling during breaks by default.
- The overlay can return to FocusMaxx or end the current Pomodoro session. It does not terminate or disable another app.

## Android access

The user must enable these items from the App Blocking settings screen:

1. **Usage access** so Android lets FocusMaxx read foreground-activity events.
2. **Display over other apps** so FocusMaxx can show the reminder above the selected app.
3. **Notifications** so the active monitoring service has a visible status notification.

FocusMaxx explains each special access before opening Android Settings and checks again when the user returns. Accessibility is not used. The native service starts from the visible timer screen, and API 34+ declares the `specialUse` foreground-service type and its use case. A Play Store release must declare this special-use service type in Play Console.

The project currently uses `minSdk 24`, `compileSdk 36`, and `targetSdk 36`. App discovery is limited to launchable applications to avoid broad package visibility. Apps hidden from the launcher are not selectable. Device manufacturers may still stop services through aggressive battery management.

## Manual device verification

Use an Android 7+ device or emulator with at least one launchable app installed. On Android 13+, grant notification access when prompted.

1. Open **Settings > Pemblokiran Aplikasi**. Confirm app names and icons appear and FocusMaxx itself does not.
2. Select a test app, leave the screen, reopen it, and confirm the choice remains selected.
3. Enable blocking. Decline each permission once and confirm the setting does not turn on; grant it in Android Settings, return, then enable again.
4. Start a focus session and open the selected app. Confirm the FocusMaxx reminder appears within roughly two polling intervals. Tap **Kembali ke FocusMaxx** and confirm the timer continues.
5. Open the selected app again and tap **Akhiri sesi fokus**. Confirm the timer resets and the foreground service notification disappears.
6. Start another session and pause it. Confirm the overlay and monitoring stop; resume and confirm they restart.
7. Let a focus interval end. With default settings, verify the overlay is inactive during break. Enable **Tetap ingatkan saat istirahat** and verify it remains active instead.
8. Let the break end while FocusMaxx is backgrounded. Confirm focus monitoring resumes without reopening the app.
9. Recreate the Activity (for example, rotate if the device allows it) and relaunch after process recreation. Confirm timer state and app selections restore from SQLite.
10. Revoke Usage Access or overlay access during a session. Confirm the settings screen reports the revoked status and a new session cannot start blocking until access is restored.
11. Uninstall a selected app. Confirm its saved selection remains counted as unavailable and it is not passed as an installed candidate.
12. Test with no app selected. Blocking must not enable and the Pomodoro timer remains usable when blocking is disabled.

Also test on a device with battery optimization enabled. Exact service survival and Settings labels vary by manufacturer; FocusMaxx does not promise a system-level lock.
