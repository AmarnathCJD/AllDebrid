package com.alldebrid.alldebrid_app

import io.flutter.embedding.android.FlutterActivity
import android.app.PictureInPictureParams
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.alldebrid/pip"
    private var pipEnabled = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setPipEnabled") {
                pipEnabled = call.argument<Boolean>("enabled") ?: false
                updatePipParams()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun updatePipParams() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            setPictureInPictureParams(
                PictureInPictureParams.Builder()
                    .setAutoEnterEnabled(pipEnabled)
                    .build()
            )
        }
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        if (pipEnabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            enterPictureInPictureMode(PictureInPictureParams.Builder().build())
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: android.content.res.Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        notifyPipChanged(isInPictureInPictureMode)
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode)
        notifyPipChanged(isInPictureInPictureMode)
    }

    private fun notifyPipChanged(isInPip: Boolean) {
        MethodChannel(flutterEngine?.dartExecutor?.binaryMessenger ?: return, CHANNEL).invokeMethod("onPipChanged", isInPip)
    }
}

