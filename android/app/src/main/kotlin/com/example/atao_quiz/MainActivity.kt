package com.example.atao_quiz

import android.app.Activity
import android.app.KeyguardManager
import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "atao_quiz/device_credential"
    private val credentialRequestCode = 4242
    private var pendingCredentialResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDeviceCredentialAvailable" -> {
                    val keyguardManager =
                        getSystemService(KEYGUARD_SERVICE) as KeyguardManager
                    result.success(keyguardManager.isDeviceSecure)
                }

                "authenticateWithDeviceCredential" -> {
                    startDeviceCredentialAuth(call, result)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun startDeviceCredentialAuth(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        if (pendingCredentialResult != null) {
            result.error(
                "already_in_progress",
                "A device credential authentication is already in progress.",
                null,
            )
            return
        }

        val keyguardManager =
            getSystemService(KEYGUARD_SERVICE) as KeyguardManager
        if (!keyguardManager.isDeviceSecure) {
            result.success(false)
            return
        }

        val title =
            call.argument<String>("title") ?: "Authentification requise"
        val description =
            call.argument<String>("description")
                ?: "Confirmez votre identité"

        val intent =
            keyguardManager.createConfirmDeviceCredentialIntent(
                title,
                description,
            )

        if (intent == null) {
            result.error(
                "not_available",
                "Device credential intent is not available.",
                null,
            )
            return
        }

        pendingCredentialResult = result
        startActivityForResult(intent, credentialRequestCode)
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != credentialRequestCode) {
            return
        }

        val result = pendingCredentialResult
        pendingCredentialResult = null

        if (result == null) {
            return
        }

        result.success(resultCode == Activity.RESULT_OK)
    }
}
