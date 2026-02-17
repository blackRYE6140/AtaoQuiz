package com.example.atao_quiz

import android.app.Activity
import android.app.KeyguardManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "atao_quiz/device_credential"
    private var pendingCredentialResult: MethodChannel.Result? = null
    private var pendingCredentialIntent: Intent? = null
    private var isActivityResumed: Boolean = false
    private var didScreenTurnOffSinceLastConsume: Boolean = false
    private var isScreenReceiverRegistered: Boolean = false

    private val screenOffReceiver =
        object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (Intent.ACTION_SCREEN_OFF == intent?.action) {
                    didScreenTurnOffSinceLastConsume = true
                    Log.d(TAG, "Screen turned off, lock flag enabled.")
                }
            }
        }

    private val credentialLauncher =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { activityResult ->
            val result = pendingCredentialResult
            pendingCredentialResult = null
            pendingCredentialIntent = null

            if (result == null) {
                return@registerForActivityResult
            }

            val resultCode = activityResult.resultCode
            Log.d(TAG, "Device credential flow completed with resultCode=$resultCode")
            result.success(resultCode == Activity.RESULT_OK)
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        registerScreenOffReceiverIfNeeded()
    }

    override fun onDestroy() {
        unregisterScreenOffReceiverIfNeeded()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDeviceCredentialAvailable" -> {
                    val keyguardManager = getKeyguardManager()
                    result.success(keyguardManager.isDeviceSecure)
                }

                "authenticateWithDeviceCredential" -> {
                    startDeviceCredentialAuth(call, result)
                }

                "getDeviceAuthDebugInfo" -> {
                    val keyguardManager = getKeyguardManager()
                    result.success(
                        mapOf(
                            "manufacturer" to Build.MANUFACTURER,
                            "brand" to Build.BRAND,
                            "model" to Build.MODEL,
                            "sdkInt" to Build.VERSION.SDK_INT,
                            "isDeviceSecure" to keyguardManager.isDeviceSecure,
                        ),
                    )
                }

                "consumeScreenOffFlag" -> {
                    val shouldLock = didScreenTurnOffSinceLastConsume
                    didScreenTurnOffSinceLastConsume = false
                    result.success(shouldLock)
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        isActivityResumed = true

        val pendingIntent = pendingCredentialIntent
        val pendingResult = pendingCredentialResult

        if (pendingIntent != null && pendingResult != null) {
            pendingCredentialIntent = null
            launchCredentialIntent(pendingIntent)
        }
    }

    override fun onPause() {
        isActivityResumed = false
        super.onPause()
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

        val keyguardManager = getKeyguardManager()
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

        if (isActivityResumed) {
            launchCredentialIntent(intent)
        } else {
            Log.d(
                TAG,
                "Deferring credential launch until activity is resumed.",
            )
            pendingCredentialIntent = intent
        }
    }

    private fun launchCredentialIntent(intent: Intent) {
        runOnUiThread {
            try {
                credentialLauncher.launch(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to launch credential intent", e)
                val result = pendingCredentialResult
                pendingCredentialResult = null
                pendingCredentialIntent = null
                result?.error(
                    "launch_failed",
                    e.message ?: "Failed to launch credential intent.",
                    null,
                )
            }
        }
    }

    private fun getKeyguardManager(): KeyguardManager {
        return getSystemService(KEYGUARD_SERVICE) as KeyguardManager
    }

    private fun registerScreenOffReceiverIfNeeded() {
        if (isScreenReceiverRegistered) {
            return
        }

        registerReceiver(screenOffReceiver, IntentFilter(Intent.ACTION_SCREEN_OFF))
        isScreenReceiverRegistered = true
    }

    private fun unregisterScreenOffReceiverIfNeeded() {
        if (!isScreenReceiverRegistered) {
            return
        }

        try {
            unregisterReceiver(screenOffReceiver)
        } catch (e: IllegalArgumentException) {
            Log.w(TAG, "Screen off receiver was not registered.", e)
        } finally {
            isScreenReceiverRegistered = false
        }
    }

    companion object {
        private const val TAG = "AtaoDeviceCredential"
    }
}
