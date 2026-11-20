package com.example.focusmaxx

import android.Manifest
import android.app.AppOpsManager
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val channelName = "com.focusmaxx/app_blocking"
    private var notificationPermissionResult: MethodChannel.Result? = null
    private var appBlockingChannel: MethodChannel? = null
    private var endSessionPending = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (intent?.action == ACTION_END_FOCUS_SESSION) endSessionPending = true
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        appBlockingChannel = channel
        channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePendingEndSession" -> {
                        val pending = endSessionPending
                        endSessionPending = false
                        result.success(pending)
                    }
                    "installedApplications" -> result.success(installedApplications())
                    "hasUsageAccess" -> result.success(hasUsageAccess())
                    "canDrawOverlays" -> result.success(Settings.canDrawOverlays(this))
                    "hasNotificationPermission" -> result.success(hasNotificationPermission())
                    "openUsageAccessSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("settings_unavailable", "Pengaturan akses penggunaan tidak tersedia.", error.message)
                        }
                    }
                    "openOverlaySettings" -> {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName"),
                        )
                        try {
                            startActivity(intent)
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("settings_unavailable", "Pengaturan overlay tidak tersedia.", error.message)
                        }
                    }
                    "openNotificationSettings" -> {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        } else {
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName"),
                            )
                        }
                        try {
                            startActivity(intent)
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("settings_unavailable", "Pengaturan notifikasi tidak tersedia.", error.message)
                        }
                    }
                    "requestNotificationPermission" -> requestNotificationPermission(result)
                    "startMonitoring" -> startMonitoring(call, result)
                    "updateMonitoring" -> {
                        AppBlockingService.updateMonitoring(
                            this,
                            call.argument<List<String>>("packageNames").orEmpty(),
                            call.argument<Boolean>("monitoringEnabled") ?: false,
                            call.argument<Long>("resumeAtEpochMillis"),
                        )
                        result.success(null)
                    }
                    "stopMonitoring" -> {
                        stopService(Intent(this, AppBlockingService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == ACTION_END_FOCUS_SESSION) {
            endSessionPending = true
            appBlockingChannel?.invokeMethod("endFocusSession", null)
        }
    }

    private fun installedApplications(): List<Map<String, Any?>> {
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved = packageManager.queryIntentActivities(launcher, 0)
            .asSequence()
            .mapNotNull { info ->
                val packageName = info.activityInfo?.packageName ?: return@mapNotNull null
                if (packageName == this.packageName) return@mapNotNull null
                val appInfo = info.activityInfo.applicationInfo
                val icon = try {
                    drawableBytes(info.loadIcon(packageManager))
                } catch (_: Exception) {
                    null
                }
                mapOf(
                    "packageName" to packageName,
                    "appName" to packageManager.getApplicationLabel(appInfo).toString(),
                    "icon" to icon,
                )
            }
            .distinctBy { it["packageName"] }
            .sortedBy { it["appName"].toString().lowercase() }
            .toList()
        return resolved
    }

    private fun drawableBytes(drawable: Drawable): ByteArray {
        val size = (48 * resources.displayMetrics.density).toInt().coerceAtLeast(48)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(canvas)
        return ByteArrayOutputStream().use { output ->
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
            bitmap.recycle()
            output.toByteArray()
        }
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(APP_OPS_SERVICE) as AppOpsManager
        @Suppress("DEPRECATION")
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun hasNotificationPermission(): Boolean =
        Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 || hasNotificationPermission()) {
            result.success(true)
            return
        }
        if (notificationPermissionResult != null) {
            result.error("permission_request_in_progress", "Permintaan izin notifikasi sedang berlangsung.", null)
            return
        }
        notificationPermissionResult = result
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_NOTIFICATIONS) {
            notificationPermissionResult?.success(hasNotificationPermission())
            notificationPermissionResult = null
        }
    }

    private fun startMonitoring(call: MethodCall, result: MethodChannel.Result) {
        if (!hasUsageAccess()) {
            result.error("usage_access_required", "Aktifkan Akses penggunaan aplikasi terlebih dahulu.", null)
            return
        }
        if (!Settings.canDrawOverlays(this)) {
            result.error("overlay_permission_required", "Izinkan FocusMaxx tampil di atas aplikasi lain.", null)
            return
        }
        val packageNames = call.argument<List<String>>("packageNames").orEmpty()
        if (packageNames.isEmpty()) {
            result.error("no_blocked_apps", "Pilih minimal satu aplikasi untuk diblokir.", null)
            return
        }
        val intent = Intent(this, AppBlockingService::class.java)
            .setAction(AppBlockingService.ACTION_START)
            .putStringArrayListExtra(AppBlockingService.EXTRA_PACKAGES, ArrayList(packageNames))
            .putExtra(
                AppBlockingService.EXTRA_MONITORING_ENABLED,
                call.argument<Boolean>("monitoringEnabled") ?: true,
            )
            .putExtra(
                AppBlockingService.EXTRA_RESUME_AT_EPOCH_MS,
                call.argument<Long>("resumeAtEpochMillis") ?: 0L,
            )
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
            else startService(intent)
            result.success(null)
        } catch (error: Exception) {
            result.error("monitor_start_failed", "Pemantauan fokus tidak dapat dimulai.", error.message)
        }
    }

    companion object {
        private const val REQUEST_NOTIFICATIONS = 8401
        const val ACTION_END_FOCUS_SESSION = "com.example.focusmaxx.action.END_FOCUS_SESSION"
    }
}
