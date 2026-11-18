package com.example.medcollab_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var speech: SpeechBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // On-device speech: Needl Voice transcripts + voice bot (issues 13/14).
        speech = SpeechBridge(applicationContext, flutterEngine.dartExecutor.binaryMessenger) { this }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (speech?.onPermissionResult(requestCode, grantResults) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        speech?.dispose()
        speech = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
