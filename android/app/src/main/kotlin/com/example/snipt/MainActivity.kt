package com.example.snipt

import android.Manifest
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
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
    // Set once Dart registers its handler; until then captures are queued so a
    // cold-start share/process-text is never dropped.
    private var dartReady = false
    // Track the last content dispatched via the focus-gain path so we don't
    // re-dispatch (and double-count usageCount) every time a dialog closes or
    // a permission prompt returns while the clipboard hasn't changed.
    private var lastFocusDispatchedContent: String? = null

    companion object {
        const val ACTION_CAPTURE_NOW = "com.example.snipt.action.CAPTURE_NOW"
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 4201
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        CaptureHostApi.setUp(messenger, this)
        flutterApi = CaptureFlutterApi(messenger)
        handleIntent(intent)
    }

    override fun flutterReady() {
        dartReady = true
        flushPending()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (!hasFocus) return
        val wasPending = clipboardCapturePending
        clipboardCapturePending = false
        val payload = readClipboardNow() ?: return
        // Skip focus-gain captures when the clipboard hasn't changed. This
        // prevents: (a) spamming dispatch on every dialog dismiss / permission
        // return, and (b) double-incrementing usageCount when the user copies
        // from within snipt and then returns (bumpUsage already counted it).
        // Explicit tile/notification captures (wasPending=true) bypass this
        // guard so a deliberate user action is never silently dropped.
        if (!wasPending && payload.content == lastFocusDispatchedContent) return
        lastFocusDispatchedContent = payload.content
        dispatch(payload.copy(source = if (wasPending) CaptureSourceDto.TILE else CaptureSourceDto.MANUAL))
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
        if (!dartReady || api == null) {
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
        // Android 13+ requires runtime POST_NOTIFICATIONS permission before
        // a foreground service notification is visible. Request it first;
        // the service starts from onRequestPermissionsResult once granted.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST_CODE,
            )
            return
        }
        launchCaptureService()
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

    override fun hasNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return ContextCompat.checkSelfPermission(
            this, Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun launchCaptureService() {
        val intent = Intent(this, CaptureService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
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
        // Record what we just wrote so the focus-gain handler doesn't
        // re-dispatch (and double-count usageCount) when the user returns
        // to snipt after copying a clip from within the app.
        lastFocusDispatchedContent = text
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE &&
            grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        ) {
            launchCaptureService()
        }
    }

    // endregion
}
