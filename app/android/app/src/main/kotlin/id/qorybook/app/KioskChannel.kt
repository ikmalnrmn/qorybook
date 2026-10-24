package id.qorybook.app

import android.app.Activity
import android.app.ActivityManager
import android.app.KeyguardManager
import android.app.NotificationManager
import android.app.NotificationManager.Policy
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Mode Anak: menyematkan aplikasi (screen pinning lewat startLockTask) dan
 * menyalakan Jangan Ganggu. Pengaturan Jangan Ganggu milik orang tua disimpan
 * dulu dan dipulihkan persis saat Mode Anak berakhir, termasuk jika aplikasi
 * sempat tertutup paksa.
 */
class KioskChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private val nm = activity.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val am = activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
    private val keyguard = activity.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
    private val prefs = activity.getSharedPreferences("qorybook_kiosk", Context.MODE_PRIVATE)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "status" -> result.success(status())
                "startLockTask" -> {
                    if (!isPinned()) activity.startLockTask()
                    result.success(true)
                }
                "stopLockTask" -> {
                    if (isPinned()) activity.stopLockTask()
                    result.success(true)
                }
                "enableDnd" -> result.success(enableDnd(call.argument<Boolean>("allowCalls") ?: true))
                "restoreDnd" -> {
                    restoreDnd()
                    result.success(true)
                }
                "openDndAccessSettings" -> {
                    open(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
                    result.success(true)
                }
                "openSecuritySettings" -> {
                    open(Intent(Settings.ACTION_SECURITY_SETTINGS))
                    result.success(true)
                }
                "openUrl" -> {
                    // Hanya dipanggil dari Area Orang Tua, saat sematan layar sudah dilepas.
                    val url = call.argument<String>("url") ?: ""
                    result.success(
                        try {
                            open(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                            true
                        } catch (e: ActivityNotFoundException) {
                            false
                        }
                    )
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("kiosk_error", e.message ?: e.javaClass.simpleName, null)
        }
    }

    private fun isPinned(): Boolean = am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE

    private fun status(): Map<String, Any?> = mapOf(
        "pinned" to isPinned(),
        "dndAccess" to nm.isNotificationPolicyAccessGranted,
        "dndActive" to prefs.getBoolean(KEY_ACTIVE, false),
        "deviceSecure" to keyguard.isDeviceSecure,
        "pinToUnpin" to pinRequiredToUnpin(),
        "sdk" to Build.VERSION.SDK_INT,
    )

    /** Pengaturan "Minta PIN sebelum melepas sematan"; null jika sistem tidak mengizinkan dibaca. */
    private fun pinRequiredToUnpin(): Boolean? = try {
        Settings.Secure.getInt(activity.contentResolver, "lock_to_app_exit_locked") == 1
    } catch (e: Exception) {
        null
    }

    private fun open(intent: Intent) {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(intent)
    }

    private fun enableDnd(allowCalls: Boolean): Boolean {
        if (!nm.isNotificationPolicyAccessGranted) return false
        if (!prefs.getBoolean(KEY_ACTIVE, false)) {
            val p = nm.notificationPolicy
            prefs.edit()
                .putBoolean(KEY_ACTIVE, true)
                .putInt("prev_filter", nm.currentInterruptionFilter)
                .putInt("prev_categories", p.priorityCategories)
                .putInt("prev_call_senders", p.priorityCallSenders)
                .putInt("prev_message_senders", p.priorityMessageSenders)
                .putInt("prev_visual", p.suppressedVisualEffects)
                .commit()
        }

        var categories = 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) categories = categories or Policy.PRIORITY_CATEGORY_ALARMS
        if (allowCalls) categories = categories or Policy.PRIORITY_CATEGORY_CALLS or Policy.PRIORITY_CATEGORY_REPEAT_CALLERS

        var visual = 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            visual = Policy.SUPPRESSED_EFFECT_PEEK or
                Policy.SUPPRESSED_EFFECT_STATUS_BAR or
                Policy.SUPPRESSED_EFFECT_BADGE or
                Policy.SUPPRESSED_EFFECT_AMBIENT or
                Policy.SUPPRESSED_EFFECT_NOTIFICATION_LIST or
                Policy.SUPPRESSED_EFFECT_LIGHTS
            // Panggilan masuk memakai tampilan layar penuh; jangan diblok bila telepon diizinkan.
            if (!allowCalls) visual = visual or Policy.SUPPRESSED_EFFECT_FULL_SCREEN_INTENT
        }

        nm.notificationPolicy = Policy(categories, Policy.PRIORITY_SENDERS_STARRED, Policy.PRIORITY_SENDERS_STARRED, visual)
        nm.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_PRIORITY)
        return true
    }

    private fun restoreDnd() {
        if (!prefs.getBoolean(KEY_ACTIVE, false)) return
        if (nm.isNotificationPolicyAccessGranted) {
            nm.notificationPolicy = Policy(
                prefs.getInt("prev_categories", 0),
                prefs.getInt("prev_call_senders", Policy.PRIORITY_SENDERS_ANY),
                prefs.getInt("prev_message_senders", Policy.PRIORITY_SENDERS_ANY),
                prefs.getInt("prev_visual", 0),
            )
            val prev = prefs.getInt("prev_filter", NotificationManager.INTERRUPTION_FILTER_ALL)
            nm.setInterruptionFilter(
                if (prev == NotificationManager.INTERRUPTION_FILTER_UNKNOWN) NotificationManager.INTERRUPTION_FILTER_ALL else prev
            )
        }
        prefs.edit().putBoolean(KEY_ACTIVE, false).commit()
    }

    companion object {
        private const val KEY_ACTIVE = "dnd_active_by_app"
    }
}
