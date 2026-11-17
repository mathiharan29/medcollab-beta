package com.vocle.audiosourceprobe;

import android.app.Activity;
import android.app.Instrumentation;
import android.content.Context;
import android.content.Intent;
import android.media.AudioFormat;
import android.os.Build;
import android.os.Bundle;
import android.os.ParcelFileDescriptor;
import android.os.SystemClock;
import android.speech.ModelDownloadListener;
import android.speech.RecognitionListener;
import android.speech.RecognitionSupport;
import android.speech.RecognitionSupportCallback;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import android.system.ErrnoException;
import android.system.Os;
import android.system.OsConstants;
import android.util.Log;
import java.io.File;
import java.io.FileDescriptor;
import java.io.InputStream;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import org.json.JSONObject;

/** Standalone API probe. The process has no Flutter, Vocle backend or audio playback. */
public final class AudioSourceProbe extends Instrumentation {
    public static final class Foreground extends Activity {}

    private static final String TAG = "VocleAudioSource";
    private static final int RATE = 16000;
    private static final int TIMEOUT_SECONDS = 18;
    private static final String EXPECTED = "open bala chat";

    @Override
    public void onCreate(Bundle arguments) {
        super.onCreate(arguments);
        start();
    }

    @Override
    public void onStart() {
        Bundle result = new Bundle();
        Activity activity = null;
        try {
            Context context = getTargetContext();
            activity = startActivitySync(new Intent(context, Foreground.class)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            byte[] speech;
            try (InputStream input = context.getAssets().open("chat-bala.pcm")) {
                speech = input.readAllBytes();
            }
            byte[] silence = new byte[speech.length];
            int capacity = pipeCapacity();
            if (speech.length <= capacity) {
                throw new IllegalStateException("Fixture must exceed idle pipe capacity");
            }
            boolean standard = SpeechRecognizer.isRecognitionAvailable(context);
            boolean offline = SpeechRecognizer.isOnDeviceRecognitionAvailable(context);
            log(new JSONObject().put("event", "availability").put("sdk", Build.VERSION.SDK_INT)
                .put("fingerprint", Build.FINGERPRINT).put("defaultAvailable", standard)
                .put("onDeviceAvailable", offline).put("pcmBytes", speech.length)
                .put("idlePipeCapacity", capacity));
            boolean proven = false;
            for (String engine : List.of("on-device", "default")) {
                if (!(engine.equals("on-device") ? offline : standard)) continue;
                checkSupport(context, engine);
                boolean modelUnavailable = false;
                boolean engineProven = false;
                for (String mode : List.of("regular-file", "pipe")) {
                    Comparison trial = compare(context, engine, mode, "offline-preferred", speech, silence);
                    modelUnavailable |= trial.modelUnavailable;
                    engineProven |= trial.proven;
                }
                if (!engineProven && modelUnavailable && Build.VERSION.SDK_INT >= 34) {
                    downloadEnglish(context, engine);
                    for (String mode : List.of("regular-file", "pipe")) {
                        engineProven |= compare(context, engine, mode, "after-model-request", speech, silence).proven;
                    }
                }
                if (!engineProven && engine.equals("default") && modelUnavailable) {
                    // Synthetic input only. Test the installed recognizer's
                    // other policy separately from Vocle's offline preference.
                    engineProven |= compare(context, engine, "pipe", "online-allowed", speech, silence).proven;
                }
                proven |= engineProven;
            }
            log(new JSONObject().put("event", "verdict").put("sourceProven", proven));
            result.putString("stream", "\nAUDIO_SOURCE_PROVEN=" + proven + "\n");
            finish(proven ? Activity.RESULT_OK : Activity.RESULT_CANCELED, result);
        } catch (Exception error) {
            Log.e(TAG, "Probe infrastructure failure", error);
            result.putString("stream", "\nAUDIO_SOURCE_PROBE_ERROR=" + error + "\n");
            finish(Activity.RESULT_CANCELED, result);
        } finally {
            if (activity != null) {
                Activity launched = activity;
                runOnMainSync(launched::finish);
            }
        }
    }

    private static void log(JSONObject row) {
        Log.i(TAG, row.toString());
    }

    private static String normalize(String value) {
        return value.toLowerCase(Locale.ROOT).replaceAll("[^a-z]+", " ").trim();
    }

    private SpeechRecognizer recognizer(Context context, String engine) {
        return engine.equals("on-device") ? SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            : SpeechRecognizer.createSpeechRecognizer(context);
    }

    private Intent request(String language) {
        return new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            .putExtra(RecognizerIntent.EXTRA_LANGUAGE, language)
            .putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true);
    }

    private static final class Comparison {
        final boolean proven;
        final boolean modelUnavailable;

        Comparison(boolean proven, boolean modelUnavailable) {
            this.proven = proven;
            this.modelUnavailable = modelUnavailable;
        }
    }

    private Comparison compare(Context context, String engine, String mode, String profile,
        byte[] speech, byte[] silence) throws Exception {
        Session supplied = recognize(context, engine, mode, profile, "speech", speech);
        Session control = recognize(context, engine, mode, profile, "silence", silence);
        boolean matched = normalize(supplied.transcript()).equals(EXPECTED);
        boolean quiet = control.transcript().isEmpty()
            && (control.terminal.equals("segment-end") || control.terminal.equals("results")
               || control.error == SpeechRecognizer.ERROR_NO_MATCH
               || control.error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT);
        boolean consumed = mode.equals("pipe")
            && supplied.written == speech.length && control.written == silence.length;
        boolean passed = matched && quiet && consumed
            && supplied.error == 0 && !supplied.terminal.equals("timeout");
        log(new JSONObject().put("event", "comparison").put("engine", engine)
            .put("source", mode).put("profile", profile).put("expectedPhraseMatched", matched)
            .put("silenceControlPassed", quiet).put("pipeConsumptionProven", consumed)
            .put("sourceProven", passed));
        return new Comparison(passed, supplied.error == SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE);
    }

    private void downloadEnglish(Context context, String engine) throws Exception {
        SpeechRecognizer[] instance = new SpeechRecognizer[1];
        CountDownLatch done = new CountDownLatch(1);
        AtomicReference<String> state = new AtomicReference<>("timeout");
        runOnMainSync(() -> {
            instance[0] = recognizer(context, engine);
            instance[0].triggerModelDownload(request("en-US"), context.getMainExecutor(),
                new ModelDownloadListener() {
                    private void report(String result) { state.set(result); done.countDown(); }
                    @Override public void onProgress(int percent) {}
                    @Override public void onSuccess() { report("success"); }
                    @Override public void onScheduled() { report("scheduled"); }
                    @Override public void onError(int error) { report("error_" + error); }
                });
        });
        try {
            done.await(50, TimeUnit.SECONDS);
            log(new JSONObject().put("event", "model-download").put("engine", engine)
                .put("locale", "en-US").put("outcome", state.get()));
            if (state.get().equals("scheduled")) SystemClock.sleep(30000);
        } finally {
            runOnMainSync(instance[0]::destroy);
        }
        checkSupport(context, engine);
    }

    private void checkSupport(Context context, String engine) throws Exception {
        SpeechRecognizer[] instance = new SpeechRecognizer[1];
        CountDownLatch done = new CountDownLatch(1);
        JSONObject info = new JSONObject().put("event", "support").put("engine", engine).put("locale", "en-US");
        runOnMainSync(() -> {
            instance[0] = recognizer(context, engine);
            instance[0].checkRecognitionSupport(request("en-US"), context.getMainExecutor(),
                new RecognitionSupportCallback() {
                    @Override
                    public void onSupportResult(RecognitionSupport support) {
                        try {
                            info.put("installedOffline", support.getInstalledOnDeviceLanguages())
                                .put("downloadableOffline", support.getSupportedOnDeviceLanguages())
                                .put("pendingOffline", support.getPendingOnDeviceLanguages())
                                .put("online", support.getOnlineLanguages());
                        } catch (Exception error) {
                            throw new IllegalStateException(error);
                        } finally {
                            done.countDown();
                        }
                    }
                    @Override
                    public void onError(int error) {
                        try { info.put("error", error); }
                        catch (Exception failure) { throw new IllegalStateException(failure); }
                        finally { done.countDown(); }
                    }
                });
        });
        if (!done.await(6, TimeUnit.SECONDS)) info.put("timeout", true);
        runOnMainSync(instance[0]::destroy);
        log(info);
    }

    private Session recognize(Context context, String engine, String mode, String profile,
        String input, byte[] bytes)
        throws Exception {
        boolean isPipe = mode.equals("pipe");
        File temp = isPipe ? null : File.createTempFile("input-", ".pcm", context.getCacheDir());
        ParcelFileDescriptor[] pipe = isPipe ? ParcelFileDescriptor.createPipe() : null;
        if (temp != null) Files.write(temp.toPath(), bytes);
        ParcelFileDescriptor read = isPipe ? pipe[0]
            : ParcelFileDescriptor.open(temp, ParcelFileDescriptor.MODE_READ_ONLY);
        Session outcome = new Session();
        SpeechRecognizer[] instance = new SpeechRecognizer[1];
        Thread writer = null;
        try {
            Intent intent = request("en-US")
                .putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, !profile.equals("online-allowed"))
                .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, read)
                .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
                .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
                .putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, RATE)
                .putExtra(RecognizerIntent.EXTRA_SEGMENTED_SESSION, RecognizerIntent.EXTRA_AUDIO_SOURCE);
            runOnMainSync(() -> {
                instance[0] = recognizer(context, engine);
                instance[0].setRecognitionListener(outcome);
                instance[0].startListening(intent);
            });
            if (isPipe) {
                writer = new Thread(() -> writePipe(pipe[1], bytes, outcome), "probe-pcm-writer");
                writer.start();
            }
            outcome.done.await(TIMEOUT_SECONDS, TimeUnit.SECONDS);
        } finally {
            // Keep the read descriptor valid until the service has consumed
            // the stream. The writer owns the pipe's EOF.
            if (writer != null) {
                writer.interrupt();
                writer.join(2000);
                if (writer.isAlive()) throw new IllegalStateException("PCM writer did not terminate");
            }
            if (instance[0] != null) runOnMainSync(instance[0]::destroy);
            if (temp != null) {
                try { outcome.filePosition = Os.lseek(read.getFileDescriptor(), 0, OsConstants.SEEK_CUR); }
                catch (ErrnoException ignored) { /* optional diagnostic */ }
            }
            read.close();
            if (isPipe && writer == null) pipe[1].close();
            if (temp != null) Files.deleteIfExists(temp.toPath());
        }
        log(new JSONObject().put("event", "session").put("engine", engine).put("source", mode)
            .put("input", input).put("locale", "en-US").put("profile", profile).put("bytesOffered", bytes.length)
            .put("pipeBytesWritten", outcome.written).put("writerError", outcome.writerError)
            .put("regularFilePosition", outcome.filePosition)
            .put("terminal", outcome.terminal).put("error", outcome.error)
            .put("ready", outcome.ready).put("segmentCount", outcome.parts.size())
            .put("transcript", outcome.transcript()));
        return outcome;
    }

    private static int pipeCapacity() throws Exception {
        ParcelFileDescriptor[] pipe = ParcelFileDescriptor.createPipe();
        try (ParcelFileDescriptor read = pipe[0]; ParcelFileDescriptor write = pipe[1]) {
            FileDescriptor fd = write.getFileDescriptor();
            Os.fcntlInt(fd, OsConstants.F_SETFL, OsConstants.O_NONBLOCK);
            byte[] block = new byte[4096];
            int total = 0;
            while (total < 1024 * 1024) {
                int wrote = writeAvailable(fd, block, 0);
                if (wrote == 0) return total;
                total += wrote;
            }
            throw new IllegalStateException("Could not measure idle pipe capacity");
        }
    }

    private static int writeAvailable(FileDescriptor fd, byte[] bytes, int offset) throws Exception {
        try {
            return Os.write(fd, bytes, offset, Math.min(4096, bytes.length - offset));
        } catch (ErrnoException error) {
            if (error.errno == OsConstants.EAGAIN) return 0;
            throw error;
        }
    }

    private static void writePipe(ParcelFileDescriptor write, byte[] bytes, Session outcome) {
        try (ParcelFileDescriptor end = write) {
            FileDescriptor fd = end.getFileDescriptor();
            Os.fcntlInt(fd, OsConstants.F_SETFL, OsConstants.O_NONBLOCK);
            long deadline = SystemClock.elapsedRealtime() + TIMEOUT_SECONDS * 1000L;
            while (outcome.written < bytes.length && SystemClock.elapsedRealtime() < deadline) {
                if (Thread.currentThread().isInterrupted()) break;
                int count = writeAvailable(fd, bytes, outcome.written);
                outcome.written += count;
                if (count == 0) Thread.sleep(20);
            }
        } catch (InterruptedException ignore) {
            Thread.currentThread().interrupt();
        } catch (Exception error) {
            outcome.writerError = error.toString();
        }
    }

    private static final class Session implements RecognitionListener {
        final CountDownLatch done = new CountDownLatch(1);
        final List<String> parts = new ArrayList<>();
        volatile String terminal = "timeout", writerError = "";
        volatile int error, written;
        volatile boolean ready;
        long filePosition = -1;

        synchronized String transcript() { return String.join(" ", parts); }
        private synchronized void add(Bundle result) {
            ArrayList<String> values = result.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
            if (values != null && !values.isEmpty()) parts.add(values.get(0).trim());
        }
        @Override public void onSegmentResults(Bundle result) { add(result); }
        @Override public void onEndOfSegmentedSession() { terminal = "segment-end"; done.countDown(); }
        @Override public void onResults(Bundle result) { add(result); terminal = "results"; done.countDown(); }
        @Override public void onError(int code) { error = code; terminal = "error"; done.countDown(); }
        @Override public void onReadyForSpeech(Bundle info) { ready = true; }
        @Override public void onBeginningOfSpeech() {}
        @Override public void onRmsChanged(float rms) {}
        @Override public void onBufferReceived(byte[] bytes) {}
        @Override public void onEndOfSpeech() {}
        @Override public void onPartialResults(Bundle result) {}
        @Override public void onEvent(int type, Bundle args) {}
    }
}
