package com.example.snipt

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.example.snipt.capture.CaptureFlutterApi
import com.example.snipt.capture.CaptureHostApi
import com.example.snipt.capture.CapturePayload
import com.example.snipt.capture.CaptureService
import com.example.snipt.capture.CaptureSourceDto
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Hosts the Flutter UI and the lane-B capture surface.
 *
 * Android 10+ only allows clipboard reads while this activity holds focus, so
 * "capture now" requests (from the tile / notification) defer the read until
 * [onWindowFocusChanged]. Share and process-text intents carry their payload
 * directly and need no clipboard access.
 */
class MainActivity : FlutterActivity(), CaptureHostApi {

    private var flutterApi: CaptureFlutterApi? = null
    private val pending = mutableListOf<CapturePayload>()
    private var clipboardCapturePending = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        CaptureHostApi.setUp(messenger, this)
        flutterApi = CaptureFlutterApi(messenger)
        flushPending()
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && clipboardCapturePending) {
            clipboardCapturePending = false
            readClipboardNow()?.let { dispatch(it.copy(source = CaptureSourceDto.TILE)) }
        }
    }

    private fun handleIntent(intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_SEND -> {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (!text.isNullOrBlank()) {
                    dispatch(CapturePayload(text, CaptureSourceDto.SHARE, null))
                }
            }
            Intent.ACTION_PROCESS_TEXT -> {
                val text = intent
                    .getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
                if (!text.isNullOrBlank()) {
                    dispatch(CapturePayload(text, CaptureSourceDto.PROCESS_TEXT, null))
                }
            }
            ACTION_CAPTURE_NOW -> {
                // Clipboard is only readable once we are focused.
                clipboardCapturePending = true
            }
        }
    }

    private fun dispatch(payload: CapturePayload) {
        val api = flutterApi
        if (api == null) {
            pending.add(payload)
        } else {
            api.onClipCaptured(payload) { /* fire and forget */ }
        }
    }

    private fun flushPending() {
        val api = flutterApi ?: return
        pending.forEach { api.onClipCaptured(it) {} }
        pending.clear()
    }

    // region CaptureHostApi (Dart -> native)

    override fun isServiceRunning(): Boolean = CaptureService.isRunning

    override fun startService() {
        val intent = Intent(this, CaptureService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    override fun stopService() {
        stopService(Intent(this, CaptureService::class.java))
    }

    override fun hasOverlayPermission(): Boolean = Settings.canDrawOverlays(this)

    override fun requestOverlayPermission() {
        startActivity(
            Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }

    override fun readClipboardNow(): CapturePayload? {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = cm.primaryClip ?: return null
        if (clip.itemCount == 0) return null
        val text = clip.getItemAt(0).coerceToText(this)?.toString()
        if (text.isNullOrBlank()) return null
        return CapturePayload(text, CaptureSourceDto.MANUAL, null)
    }

    override fun copyToClipboard(text: String) {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        cm.setPrimaryClip(ClipData.newPlainText("snipt", text))
    }

    // endregion

    companion object {
        const val ACTION_CAPTURE_NOW = "com.example.snipt.action.CAPTURE_NOW"
    }
}
