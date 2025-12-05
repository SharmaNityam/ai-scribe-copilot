package com.example.medical_transaction_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.AudioManager
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val TAG = "MainActivity"
    private val INTERRUPTIONS_CHANNEL = "com.aiscribe.interruptions"
    private val RECORDING_CHANNEL = "com.example.medical_transaction_app/recording"
    private val HEADSET_CHANNEL = "com.example.medical_transaction_app/headset"
    
    private var interruptionsChannel: MethodChannel? = null
    private var recordingChannel: MethodChannel? = null
    private var headsetChannel: MethodChannel? = null
    private var phoneStateListener: PhoneStateListener? = null
    private var telephonyManager: TelephonyManager? = null
    private var headsetReceiver: BroadcastReceiver? = null
    private var isListeningToHeadset = false
    private var audioManager: AudioManager? = null
    private var audioFocusChangeListener: AudioManager.OnAudioFocusChangeListener? = null
    private var wasRecordingBeforeCall = false
    private var phoneStateReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        interruptionsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INTERRUPTIONS_CHANNEL)
        recordingChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECORDING_CHANNEL)
        headsetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HEADSET_CHANNEL)
        
        setupPhoneCallDetection()
        setupRecordingService()
        setupHeadsetDetection()
    }

    private fun setupPhoneCallDetection() {
        Log.d(TAG, "Setting up phone call detection...")
        
        // Method 1: Use BroadcastReceiver (works on all Android versions, no permission needed for basic detection)
        setupPhoneStateBroadcastReceiver()
        
        // Method 2: Use PhoneStateListener as fallback (may not work on Android 10+)
        setupPhoneStateListener()
        
        // Method 3: Audio focus listener (backup)
        setupAudioFocusListener()
    }
    
    private fun setupAudioFocusListener() {
        try {
            audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            
            // Instead of requesting audio focus, we'll use a BroadcastReceiver
            // to detect phone state changes, which is more reliable
            audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
                Log.d(TAG, "Audio focus changed: $focusChange")
                // This is a backup method - primary detection is via BroadcastReceiver
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up audio focus listener", e)
        }
    }
    
    private fun setupPhoneStateBroadcastReceiver() {
        try {
            phoneStateReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    val state = intent?.getStringExtra(TelephonyManager.EXTRA_STATE)
                    Log.d(TAG, "Phone state broadcast received: $state")
                    
                    when (state) {
                        TelephonyManager.EXTRA_STATE_IDLE -> {
                            // Call ended
                            Log.d(TAG, "🟢 Phone call ended (IDLE)")
                            if (wasRecordingBeforeCall) {
                                wasRecordingBeforeCall = false
                                interruptionsChannel?.invokeMethod("onPhoneCallEnded", null)
                                Log.d(TAG, "🟢 Sent onPhoneCallEnded to Flutter")
                            }
                        }
                        TelephonyManager.EXTRA_STATE_OFFHOOK -> {
                            // Call answered
                            Log.d(TAG, "🔴 Phone call started (OFFHOOK)")
                            if (!wasRecordingBeforeCall) {
                                wasRecordingBeforeCall = true
                                interruptionsChannel?.invokeMethod("onPhoneCallStarted", null)
                                Log.d(TAG, "🔴 Sent onPhoneCallStarted to Flutter")
                            }
                        }
                        TelephonyManager.EXTRA_STATE_RINGING -> {
                            // Incoming call
                            Log.d(TAG, "🔴 Phone call ringing")
                            if (!wasRecordingBeforeCall) {
                                wasRecordingBeforeCall = true
                                interruptionsChannel?.invokeMethod("onPhoneCallStarted", null)
                                Log.d(TAG, "🔴 Sent onPhoneCallStarted to Flutter")
                            }
                        }
                    }
                }
            }
            
            val filter = IntentFilter(TelephonyManager.ACTION_PHONE_STATE_CHANGED)
            registerReceiver(phoneStateReceiver, filter)
            Log.d(TAG, "Phone state broadcast receiver registered")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up phone state broadcast receiver", e)
        }
    }
    
    private fun setupPhoneStateListener() {
        // Check if we have permission to read phone state
        // On Android 10+, this permission is restricted and may not be granted
        try {
            if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.READ_PHONE_STATE) 
                != PackageManager.PERMISSION_GRANTED) {
                Log.d(TAG, "READ_PHONE_STATE permission not granted - using audio focus only")
                return
            }
            
            telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            
            phoneStateListener = object : PhoneStateListener() {
                override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                    super.onCallStateChanged(state, phoneNumber)
                    Log.d(TAG, "Phone state changed: $state")
                    
                    when (state) {
                        TelephonyManager.CALL_STATE_IDLE -> {
                            // Call ended
                            Log.d(TAG, "🟢 Phone call ended (IDLE)")
                            interruptionsChannel?.invokeMethod("onPhoneCallEnded", null)
                        }
                        TelephonyManager.CALL_STATE_OFFHOOK -> {
                            // Call answered (off-hook)
                            Log.d(TAG, "🔴 Phone call started (OFFHOOK)")
                            interruptionsChannel?.invokeMethod("onPhoneCallStarted", null)
                        }
                        TelephonyManager.CALL_STATE_RINGING -> {
                            // Incoming call ringing
                            Log.d(TAG, "🔴 Phone call ringing")
                            interruptionsChannel?.invokeMethod("onPhoneCallStarted", null)
                        }
                    }
                }
            }
            
            telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)
            Log.d(TAG, "Phone state listener registered")
        } catch (e: SecurityException) {
            Log.d(TAG, "SecurityException setting up phone state listener: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up phone state listener", e)
        }
    }
    
    private fun setupRecordingService() {
        recordingChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    RecordingForegroundService.startService(this)
                    result.success(null)
                }
                "stopForegroundService" -> {
                    RecordingForegroundService.stopService(this)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun setupHeadsetDetection() {
        headsetChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isHeadsetConnected" -> {
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val isConnected = audioManager.isWiredHeadsetOn || audioManager.isBluetoothA2dpOn || audioManager.isBluetoothScoOn
                    result.success(isConnected)
                }
                "startListening" -> {
                    if (!isListeningToHeadset) {
                        registerHeadsetReceiver()
                        isListeningToHeadset = true
                    }
                    result.success(null)
                }
                "stopListening" -> {
                    if (isListeningToHeadset) {
                        unregisterHeadsetReceiver()
                        isListeningToHeadset = false
                    }
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun registerHeadsetReceiver() {
        if (headsetReceiver == null) {
            headsetReceiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    when (intent?.action) {
                        Intent.ACTION_HEADSET_PLUG -> {
                            val state = intent.getIntExtra("state", -1)
                            val isConnected = state == 1
                            headsetChannel?.invokeMethod(
                                if (isConnected) "onHeadsetConnected" else "onHeadsetDisconnected",
                                null
                            )
                        }
                        AudioManager.ACTION_AUDIO_BECOMING_NOISY -> {
                            // Audio becoming noisy usually means headset disconnected
                            headsetChannel?.invokeMethod("onHeadsetDisconnected", null)
                        }
                    }
                }
            }
            
            val filter = IntentFilter().apply {
                addAction(Intent.ACTION_HEADSET_PLUG)
                addAction(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
            }
            
            registerReceiver(headsetReceiver, filter)
        }
    }
    
    private fun unregisterHeadsetReceiver() {
        headsetReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                // Receiver might not be registered
            }
            headsetReceiver = null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_NONE)
        phoneStateListener = null
        audioFocusChangeListener?.let {
            audioManager?.abandonAudioFocus(it)
        }
        audioFocusChangeListener = null
        phoneStateReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                // Receiver might not be registered
            }
        }
        phoneStateReceiver = null
        unregisterHeadsetReceiver()
    }
}
