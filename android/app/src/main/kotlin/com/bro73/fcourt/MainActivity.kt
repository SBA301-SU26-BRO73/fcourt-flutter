package com.bro73.fcourt

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.bro73.fcourt/maps")
            .setMethodCallHandler { call, result ->
                if (call.method != "availability") {
                    result.notImplemented()
                } else {
                    val availability = try {
                        val info = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                        val key = info.metaData?.getString("com.google.android.geo.API_KEY")
                        when {
                            key.isNullOrBlank() -> "missingKey"
                            GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(this) != ConnectionResult.SUCCESS -> "unavailable"
                            else -> "available"
                        }
                    } catch (_: Exception) {
                        "unavailable"
                    }
                    result.success(availability)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.bro73.fcourt/push")
            .setMethodCallHandler { call, result ->
                if (call.method != "createNotificationChannel") {
                    result.notImplemented()
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val channel = NotificationChannel(
                        "fcourt_notifications",
                        "Thông báo FCOURT",
                        NotificationManager.IMPORTANCE_HIGH
                    ).apply {
                        description = "Thông báo về trạng thái đặt sân"
                    }
                    getSystemService(NotificationManager::class.java)
                        .createNotificationChannel(channel)
                    result.success(null)
                } else {
                    result.success(null)
                }
            }
    }
}
