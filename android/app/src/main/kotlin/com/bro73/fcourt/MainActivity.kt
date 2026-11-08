package com.bro73.fcourt

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager
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
    }
}
