package com.example.medcollab_app

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import android.media.AudioFormat
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.RandomAccessFile
import java.util.Locale

/**
 * On-device speech for Needl Voice transcripts (issue 13) and the voice bot
 * (issue 14). Android's own recognizer (on-device model when available) and
 * text-to-speech; audio never goes to Vocle's server for recognition.
 *
 * Channels: method `vocle/speech`, events `vocle/speech/events`.
 */
class SpeechBridge(
    private val context: Context,
    messenger: BinaryMessenger,
    private val activity: () -> Activity?,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object { const val MIC_REQUEST = 4711 }
    private var pendingMic: MethodChannel.Result? = null

    private fun micGranted() =
        context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    /** Asks for the microphone (the system prompt) when needed. */
    private fun micPermission(request: Boolean, result: MethodChannel.Result) {
        if (micGranted()) { result.success("granted"); return }
        val act = activity()
        if (!request || act == null) { result.success("denied"); return }
        pendingMic?.success("denied")
        pendingMic = result
        act.requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), MIC_REQUEST)
    }

    /** From MainActivity.onRequestPermissionsResult. */
    fun onPermissionResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != MIC_REQUEST) return false
        val r = pendingMic ?: return true
        pendingMic = null
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        val act = activity()
        // Denied and Android will no longer show the prompt → Settings only.
        val blocked = !granted && act != null &&
            !act.shouldShowRequestPermissionRationale(Manifest.permission.RECORD_AUDIO)
        r.success(if (granted) "granted" else if (blocked) "blocked" else "denied")
        return true
    }

    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try { context.startActivity(intent) } catch (_: Exception) {}
    }

    private val main = Handler(Looper.getMainLooper())
    private val methods = MethodChannel(messenger, "vocle/speech")
    private var events: EventChannel.EventSink? = null
    private var liveRecognizer: SpeechRecognizer? = null
    private var tts: TextToSpeech? = null
    private var ttsReady = false

    init {
        methods.setMethodCallHandler(this)
        EventChannel(messenger, "vocle/speech/events").setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) { events = sink }
    override fun onCancel(arguments: Any?) { events = null }

    private fun emit(map: Map<String, Any?>) = main.post { events?.success(map) }

    private fun onDeviceAvailable(): Boolean =
        Build.VERSION.SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(context)

    private fun newRecognizer(): SpeechRecognizer =
        if (onDeviceAvailable()) SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
        else SpeechRecognizer.createSpeechRecognizer(context)

    /**
     * Languages to try, in order. en-IN first; if its on-device pack is not
     * installed (error 12/13 — common on phones set to another English),
     * the phone's own English, then en-US. Still on-device only.
     */
    private fun languageChain(preferred: String): List<String> {
        val device = Locale.getDefault().toLanguageTag()
        return listOf(preferred, if (device.startsWith("en")) device else null, "en-US")
            .filterNotNull().distinct()
    }

    private fun isLanguageError(error: Int) =
        error == SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED ||
            error == SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE

    private var downloadRequested = false

    /** Ask Android to fetch the preferred pack in the background (once). */
    private fun requestModelDownload(language: String) {
        if (downloadRequested || Build.VERSION.SDK_INT < 33 || !onDeviceAvailable()) return
        downloadRequested = true
        try {
            val r = SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            r.triggerModelDownload(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
            })
            main.postDelayed({ r.destroy() }, 5_000)
        } catch (_: Exception) {}
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capabilities" -> result.success(
                mapOf(
                    "available" to SpeechRecognizer.isRecognitionAvailable(context),
                    "onDevice" to onDeviceAvailable(),
                    "fileInput" to (Build.VERSION.SDK_INT >= 33 && SpeechRecognizer.isRecognitionAvailable(context)),
                    "tts" to true,
                )
            )
            "transcribeFile" -> transcribeFile(
                call.argument<String>("path") ?: "",
                call.argument<String>("language") ?: "en-IN",
                result,
            )
            "micPermission" -> micPermission(call.argument<Boolean>("request") ?: true, result)
            "openAppSettings" -> { openAppSettings(); result.success(null) }
            "startListening" -> startListening(
                call.argument<String>("language") ?: "en-IN",
                call.argument<List<String>>("hints") ?: emptyList(),
                result,
            )
            "stopListening" -> { main.post { liveRecognizer?.stopListening() }; result.success(null) }
            "cancelListening" -> { main.post { releaseLive() }; result.success(null) }
            "speak" -> speak(call.argument<String>("text") ?: "", call.argument<String>("language") ?: "en-IN", result)
            "stopSpeaking" -> { tts?.stop(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    // ── Transcribe a recorded clip (Android 13+) ────────────────────────────
    private fun transcribeFile(path: String, language: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33) { result.error("unsupported", "Android 13+ needed", null); return }
        if (!SpeechRecognizer.isRecognitionAvailable(context)) { result.error("unavailable", "No recognizer", null); return }
        val wav = File(path)
        if (!wav.exists()) { result.error("missing", "No such file", null); return }

        // The recognizer takes raw PCM: copy the WAV's data chunk out.
        val pcm: File
        val sampleRate: Int
        try {
            val (rate, dataOffset, dataLen) = wavInfo(wav)
            sampleRate = rate
            pcm = File(context.cacheDir, "vocle-stt-${System.nanoTime()}.pcm")
            RandomAccessFile(wav, "r").use { input ->
                input.seek(dataOffset)
                pcm.outputStream().use { out ->
                    val buf = ByteArray(16 * 1024)
                    var left = dataLen
                    while (left > 0) {
                        val n = input.read(buf, 0, minOf(buf.size.toLong(), left).toInt())
                        if (n <= 0) break
                        out.write(buf, 0, n)
                        left -= n
                    }
                }
            }
        } catch (e: Exception) {
            result.error("bad_audio", e.message, null); return
        }

        val languages = languageChain(language)
        var replied = false
        fun reply(text: String?, error: String?) {
            if (replied) return
            replied = true
            pcm.delete()
            if (error != null) result.error(error, error, null) else result.success(text ?: "")
        }
        // Safety net: never hang the caller.
        main.postDelayed({ reply("", null) }, 150_000)
        fun attempt(index: Int) { main.post {
            if (replied) return@post
            val lang = languages[index]
            val pfd = ParcelFileDescriptor.open(pcm, ParcelFileDescriptor.MODE_READ_ONLY)
            val recognizer = newRecognizer()
            val parts = mutableListOf<String>()
            var done = false
            fun finish(text: String?, error: String?) {
                if (done) return
                done = true
                recognizer.destroy()
                try { pfd.close() } catch (_: Exception) {}
                reply(text, error)
            }
            fun retryOrFail(error: Int) {
                if (done) return
                if (isLanguageError(error) && index + 1 < languages.size) {
                    if (index == 0) requestModelDownload(language)
                    done = true
                    recognizer.destroy()
                    try { pfd.close() } catch (_: Exception) {}
                    attempt(index + 1)
                } else finish(null, "error_$error")
            }
            recognizer.setRecognitionListener(object : RecognitionListener {
                override fun onSegmentResults(segmentResults: Bundle) {
                    segmentResults.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?.firstOrNull()?.takeIf { it.isNotBlank() }?.let { parts.add(it.trim()) }
                }
                override fun onEndOfSegmentedSession() = finish(parts.joinToString(" "), null)
                override fun onResults(results: Bundle) {
                    results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        ?.firstOrNull()?.takeIf { it.isNotBlank() }?.let { parts.add(it.trim()) }
                    finish(parts.joinToString(" "), null)
                }
                override fun onError(error: Int) {
                    if (error == SpeechRecognizer.ERROR_NO_MATCH || error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT) {
                        finish(parts.joinToString(" "), null)
                    } else retryOrFail(error)
                }
                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onPartialResults(partialResults: Bundle?) {}
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang)
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, pfd)
                putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
                putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
                putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, sampleRate)
                // Whole clip, not just up to the first pause.
                putExtra(RecognizerIntent.EXTRA_SEGMENTED_SESSION, RecognizerIntent.EXTRA_AUDIO_SOURCE)
            }
            recognizer.startListening(intent)
        } }
        attempt(0)
    }

    /** (sampleRate, data offset, data length) of a PCM16 WAV file. */
    private fun wavInfo(f: File): Triple<Int, Long, Long> {
        FileInputStream(f).use { s ->
            val header = ByteArray(12)
            s.read(header)
            require(String(header, 0, 4) == "RIFF" && String(header, 8, 4) == "WAVE") { "not a WAV file" }
            var offset = 12L
            var rate = 16000
            val chunk = ByteArray(8)
            while (s.read(chunk) == 8) {
                val id = String(chunk, 0, 4)
                val size = (chunk[4].toLong() and 0xff) or ((chunk[5].toLong() and 0xff) shl 8) or
                    ((chunk[6].toLong() and 0xff) shl 16) or ((chunk[7].toLong() and 0xff) shl 24)
                offset += 8
                if (id == "fmt ") {
                    val fmt = ByteArray(size.toInt())
                    s.read(fmt)
                    rate = (fmt[4].toInt() and 0xff) or ((fmt[5].toInt() and 0xff) shl 8) or
                        ((fmt[6].toInt() and 0xff) shl 16) or ((fmt[7].toInt() and 0xff) shl 24)
                    offset += size
                } else if (id == "data") {
                    return Triple(rate, offset, size)
                } else {
                    s.skip(size)
                    offset += size
                }
            }
        }
        error("no audio data")
    }

    // ── Live listening (voice bot) ──────────────────────────────────────────
    private var liveHints: List<String> = emptyList()

    private fun startListening(language: String, hints: List<String>, result: MethodChannel.Result) {
        if (!SpeechRecognizer.isRecognitionAvailable(context)) { result.error("unavailable", "No recognizer", null); return }
        if (!micGranted()) { result.error("no_permission", "Microphone not allowed", null); return }
        liveHints = hints
        val languages = languageChain(language)
        main.post {
            listenWith(languages, 0, language, onDevice = onDeviceAvailable())
            result.success(null)
        }
    }

    /**
     * One recognition session. On-device first; when no on-device English
     * pack exists (field probe: ERROR_LANGUAGE_UNAVAILABLE), the phone's
     * standard recognizer is tried once (commands only — Needl Voice clips
     * stay on-device). A watchdog ends a session that heard speech but never
     * returned a result (field run: no final callback within 18 s).
     */
    private fun listenWith(languages: List<String>, index: Int, preferred: String, onDevice: Boolean) {
            releaseLive()
            val r = if (onDevice) SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
                    else SpeechRecognizer.createSpeechRecognizer(context)
            liveRecognizer = r
            val engine = if (onDevice) "on_device" else "online"
            var finished = false
            val stall = Runnable {
                if (liveRecognizer === r && !finished) {
                    finished = true
                    emit(mapOf("type" to "error", "code" to "stalled", "text" to "no result"))
                    releaseLive()
                }
            }
            // Hard cap for one command, even if speech never ends.
            main.postDelayed(stall, 25_000)
            r.setRecognitionListener(object : RecognitionListener {
                override fun onPartialResults(partialResults: Bundle) {
                    partialResults.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
                        ?.let { emit(mapOf("type" to "partial", "text" to it)) }
                }
                override fun onResults(results: Bundle) {
                    if (liveRecognizer !== r || finished) return
                    finished = true
                    main.removeCallbacks(stall)
                    val all = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION) ?: arrayListOf()
                    val scores = results.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
                    val text = all.firstOrNull() ?: ""
                    emit(mapOf(
                        "type" to "final",
                        "text" to text,
                        "alternatives" to all.drop(1).take(4),
                        // -1 / 0 mean "not reported" on many recognisers.
                        "confidence" to scores?.firstOrNull()?.takeIf { it > 0f }?.toDouble(),
                        "engine" to engine,
                    ))
                    releaseLive()
                }
                override fun onRmsChanged(rmsdB: Float) {
                    emit(mapOf("type" to "level", "level" to ((rmsdB + 2f) / 12f).coerceIn(0f, 1f).toDouble()))
                }
                override fun onError(error: Int) {
                    if (liveRecognizer !== r || finished) return // superseded / cancelled
                    main.removeCallbacks(stall)
                    if (isLanguageError(error)) {
                        if (index + 1 < languages.size) {
                            if (index == 0) requestModelDownload(preferred)
                            main.post { listenWith(languages, index + 1, preferred, onDevice) }
                            return
                        }
                        if (onDevice) {
                            main.post { listenWith(languages, 0, preferred, onDevice = false) }
                            return
                        }
                    }
                    finished = true
                    val code = when (error) {
                        SpeechRecognizer.ERROR_NO_MATCH -> "no_match"
                        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "timeout"
                        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "no_permission"
                        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "busy"
                        SpeechRecognizer.ERROR_NETWORK, SpeechRecognizer.ERROR_NETWORK_TIMEOUT,
                        SpeechRecognizer.ERROR_SERVER, SpeechRecognizer.ERROR_SERVER_DISCONNECTED -> "network"
                        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED,
                        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "language"
                        else -> "error"
                    }
                    emit(mapOf("type" to "error", "code" to code, "text" to "error $error"))
                    releaseLive()
                }
                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {
                    // Speech ended: a result should follow within seconds.
                    main.removeCallbacks(stall)
                    main.postDelayed(stall, 8_000)
                }
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })
            r.startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, languages[index])
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
                putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, onDevice)
                if (Build.VERSION.SDK_INT >= 33 && liveHints.isNotEmpty()) {
                    putStringArrayListExtra(RecognizerIntent.EXTRA_BIASING_STRINGS, ArrayList(liveHints))
                }
            })
    }
    private fun releaseLive() {
        liveRecognizer?.let {
            try { it.cancel() } catch (_: Exception) {}
            it.destroy()
        }
        liveRecognizer = null
    }

    // ── Text-to-speech ──────────────────────────────────────────────────────
    private fun speak(text: String, language: String, result: MethodChannel.Result) {
        if (text.isBlank()) { result.success(null); return }
        val say = {
            tts?.language = Locale.forLanguageTag(language)
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "vocle-${System.nanoTime()}")
        }
        if (tts != null && ttsReady) { say(); result.success(null); return }
        tts = TextToSpeech(context) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (ttsReady) say()
        }
        result.success(null)
    }

    fun dispose() {
        main.post { releaseLive() }
        tts?.shutdown()
        tts = null
        methods.setMethodCallHandler(null)
    }
}
