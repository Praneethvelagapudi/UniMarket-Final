package edu.students.unimarket

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private val requestCode = 801
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(NotificationChannel("bookings", "Booking confirmations", NotificationManager.IMPORTANCE_HIGH))
            manager.createNotificationChannel(NotificationChannel("messages", "Incoming messages", NotificationManager.IMPORTANCE_HIGH))
        }
        fun canNotify(channelId: String): Boolean = manager.areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < 26 || manager.getNotificationChannel(channelId)?.importance != NotificationManager.IMPORTANCE_NONE)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "unimarket/notifications").setMethodCallHandler { call, result ->
            when (call.method) {
                "clear" -> { manager.cancelAll(); result.success(null) }
                "requestPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        if (permissionResult != null) result.error("permission-pending", "Permission request is already open", null)
                        else { permissionResult = result; requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), requestCode) }
                    // Runtime permission is app-wide. A disabled booking channel
                    // must not incorrectly disable the separate messages channel.
                    // Delivery checks the selected channel in "show" below.
                    } else result.success(manager.areNotificationsEnabled())
                }
                "show" -> {
                    val id = call.argument<String>("id") ?: "booking"
                    val channelId = if (id.startsWith("message-")) "messages" else "bookings"
                    if (!canNotify(channelId)) { result.success(false) }
                    else {
                        val title = call.argument<String>("title") ?: "UniMarket"
                        val body = call.argument<String>("body") ?: ""
                        val intent = Intent(this, MainActivity::class.java).apply { flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP }
                        val pending = PendingIntent.getActivity(this, id.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channelId) else Notification.Builder(this)
                        builder.setSmallIcon(R.drawable.ic_notification).setContentTitle(title).setContentText(body)
                            .setVisibility(Notification.VISIBILITY_PRIVATE)
                            .setStyle(Notification.BigTextStyle().bigText(body)).setContentIntent(pending).setAutoCancel(true)
                        if (Build.VERSION.SDK_INT < 26) builder.setPriority(Notification.PRIORITY_HIGH)
                        try { manager.notify(id.hashCode(), builder.build()); result.success(true) }
                        catch (e: SecurityException) { result.success(false) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == this.requestCode) {
            permissionResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            permissionResult = null
        }
    }
}
