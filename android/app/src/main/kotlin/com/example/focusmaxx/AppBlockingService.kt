package com.example.focusmaxx

import android.app.AppOpsManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Process
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

class AppBlockingService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val blockedPackages = mutableSetOf<String>()
    private var monitoringEnabled = false
    private var lastEventTimestamp = 0L
    private var overlayView: View? = null
    private var windowManager: WindowManager? = null
    private var foregroundPackage: String? = null
    private var resumeAtEpochMillis: Long? = null

    private val poll = object : Runnable {
        override fun run() {
            if (!monitoringEnabled) return
            checkForegroundApplication()
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                blockedPackages.clear()
                blockedPackages.addAll(
                    intent.getStringArrayListExtra(EXTRA_PACKAGES).orEmpty(),
                )
                monitoringEnabled = intent.getBooleanExtra(EXTRA_MONITORING_ENABLED, true)
                resumeAtEpochMillis = intent.getLongExtra(EXTRA_RESUME_AT_EPOCH_MS, 0L)
                    .takeIf { it > 0L }
                startForegroundCompat()
                scheduleMonitoring()
            }
            ACTION_UPDATE_MONITORING -> {
                blockedPackages.clear()
                blockedPackages.addAll(
                    intent.getStringArrayListExtra(EXTRA_PACKAGES).orEmpty(),
                )
                monitoringEnabled = intent.getBooleanExtra(EXTRA_MONITORING_ENABLED, false)
                resumeAtEpochMillis = intent.getLongExtra(EXTRA_RESUME_AT_EPOCH_MS, 0L)
                    .takeIf { it > 0L }
                scheduleMonitoring()
            }
            else -> stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun scheduleMonitoring() {
        handler.removeCallbacks(poll)
        handler.removeCallbacks(resumeMonitoring)
        if (monitoringEnabled && blockedPackages.isNotEmpty()) {
            handler.post(poll)
        } else {
            removeOverlay()
            updateNotification()
            val resumeAt = resumeAtEpochMillis
            val delay = resumeAt?.minus(System.currentTimeMillis()) ?: 0L
            if (delay > 0L && blockedPackages.isNotEmpty()) {
                handler.postDelayed(resumeMonitoring, delay)
            }
        }
    }

    private val resumeMonitoring = Runnable {
        resumeAtEpochMillis = null
        monitoringEnabled = true
        scheduleMonitoring()
    }

    private fun checkForegroundApplication() {
        if (!hasUsageAccess()) {
            monitoringEnabled = false
            removeOverlay()
            updateNotification("Akses penggunaan aplikasi tidak tersedia")
            return
        }
        val usageStats = getSystemService(USAGE_STATS_SERVICE) as UsageStatsManager
        val endTime = System.currentTimeMillis()
        val beginTime = (endTime - EVENT_LOOKBACK_MS).coerceAtLeast(lastEventTimestamp)
        val events = usageStats.queryEvents(beginTime, endTime) ?: return
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.timeStamp < lastEventTimestamp) continue
            val isResumed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                event.eventType == UsageEvents.Event.ACTIVITY_RESUMED
            } else {
                @Suppress("DEPRECATION")
                event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND
            }
            if (isResumed && !event.packageName.isNullOrBlank()) {
                foregroundPackage = event.packageName
                lastEventTimestamp = event.timeStamp
            }
        }
        val current = foregroundPackage
        if (current != null && current in blockedPackages) {
            showOverlay(current)
        } else {
            removeOverlay()
        }
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(APP_OPS_SERVICE) as AppOpsManager
        @Suppress("DEPRECATION")
        return appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName,
        ) == AppOpsManager.MODE_ALLOWED
    }

    private fun showOverlay(blockedPackage: String) {
        if (overlayView != null || !Settings.canDrawOverlays(this)) return
        val appName = try {
            val app = packageManager.getApplicationInfo(blockedPackage, 0)
            packageManager.getApplicationLabel(app).toString()
        } catch (_: Exception) {
            blockedPackage
        }
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.argb(190, 14, 25, 17))
            isClickable = true
        }
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(28), dp(28), dp(28), dp(24))
            background = GradientDrawable().apply {
                setColor(Color.rgb(248, 252, 248))
                cornerRadius = dp(24).toFloat()
            }
        }
        panel.addView(TextView(this).apply {
            text = "FocusMaxx"
            textSize = 16f
            setTextColor(Color.rgb(27, 94, 32))
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        })
        panel.addView(TextView(this).apply {
            text = "Tetap Fokus!"
            textSize = 25f
            setTextColor(Color.rgb(27, 94, 32))
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, dp(18), 0, dp(8))
        })
        panel.addView(TextView(this).apply {
            text = "Kamu sedang dalam sesi fokus. Kembali dari $appName dan lanjutkan tugasmu."
            textSize = 16f
            setTextColor(Color.rgb(37, 55, 42))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(22))
        })
        panel.addView(Button(this).apply {
            text = "Kembali ke FocusMaxx"
            setOnClickListener {
                foregroundPackage = packageName
                lastEventTimestamp = System.currentTimeMillis()
                removeOverlay()
                val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                if (launchIntent != null) startActivity(launchIntent)
            }
        }, LinearLayout.LayoutParams(-1, dp(52)))
        panel.addView(Button(this).apply {
            text = "Akhiri sesi fokus"
            setOnClickListener {
                foregroundPackage = packageName
                lastEventTimestamp = System.currentTimeMillis()
                removeOverlay()
                val intent = Intent(this@AppBlockingService, MainActivity::class.java)
                    .setAction(MainActivity.ACTION_END_FOCUS_SESSION)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                startActivity(intent)
            }
        }, LinearLayout.LayoutParams(-1, dp(52)).apply { topMargin = dp(8) })
        root.addView(panel, FrameLayout.LayoutParams(-1, -2, Gravity.CENTER).apply {
            leftMargin = dp(28)
            rightMargin = dp(28)
        })
        val windowType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            windowType,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply { gravity = Gravity.CENTER }
        try {
            windowManager?.addView(root, params)
            overlayView = root
            updateNotification("Aplikasi terpilih sedang dibatasi")
        } catch (_: Exception) {
            removeOverlay()
        }
    }

    private fun removeOverlay() {
        val view = overlayView ?: return
        try {
            windowManager?.removeView(view)
        } catch (_: Exception) {
            // The system may already have detached the overlay window.
        }
        overlayView = null
    }

    private fun startForegroundCompat() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Sesi pemblokiran fokus",
            NotificationManager.IMPORTANCE_LOW,
        ).apply { description = "Menampilkan status pemantauan aplikasi selama sesi fokus." }
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .createNotificationChannel(channel)
    }

    private fun buildNotification(message: String? = null): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("FocusMaxx sedang berjalan")
            .setContentText(message ?: if (monitoringEnabled) {
                "Pemantauan aplikasi aktif selama sesi fokus."
            } else {
                "Pemantauan aplikasi dijeda selama istirahat."
            })
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()

    private fun updateNotification(message: String? = null) {
        (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
            .notify(NOTIFICATION_ID, buildNotification(message))
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    override fun onDestroy() {
        handler.removeCallbacks(poll)
        handler.removeCallbacks(resumeMonitoring)
        removeOverlay()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_START = "com.example.focusmaxx.action.START_MONITORING"
        const val ACTION_UPDATE_MONITORING = "com.example.focusmaxx.action.UPDATE_MONITORING"
        const val EXTRA_PACKAGES = "blocked_packages"
        const val EXTRA_MONITORING_ENABLED = "monitoring_enabled"
        const val EXTRA_RESUME_AT_EPOCH_MS = "resume_at_epoch_ms"
        private const val CHANNEL_ID = "focus_app_blocking"
        private const val NOTIFICATION_ID = 9012
        private const val POLL_INTERVAL_MS = 1_500L
        private const val EVENT_LOOKBACK_MS = 10_000L

        fun updateMonitoring(
            context: Context,
            packages: List<String>,
            enabled: Boolean,
            resumeAtEpochMillis: Long?,
        ) {
            context.startService(
                Intent(context, AppBlockingService::class.java)
                    .setAction(ACTION_UPDATE_MONITORING)
                    .putStringArrayListExtra(EXTRA_PACKAGES, ArrayList(packages))
                    .putExtra(EXTRA_MONITORING_ENABLED, enabled)
                    .putExtra(EXTRA_RESUME_AT_EPOCH_MS, resumeAtEpochMillis ?: 0L),
            )
        }
    }
}
