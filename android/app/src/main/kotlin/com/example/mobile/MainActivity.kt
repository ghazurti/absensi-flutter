package com.example.mobile

import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "id.go.rsudkotabaubau.absensi/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "getDeviceInfo") {
                    val androidId = Settings.Secure.getString(
                        contentResolver,
                        Settings.Secure.ANDROID_ID
                    ) ?: ""
                    val manufacturer = Build.MANUFACTURER?.trim().orEmpty()
                    val model = Build.MODEL?.trim().orEmpty()
                    val deviceName = if (model.lowercase().startsWith(manufacturer.lowercase())) {
                        model
                    } else {
                        "$manufacturer $model".trim()
                    }
                    result.success(
                        mapOf(
                            "device_id" to androidId,
                            "device_name" to deviceName
                        )
                    )
                } else {
                    result.notImplemented()
                }
            }
    }
}
