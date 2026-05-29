import SwiftUI
import Combine        // @Published — Swift 6 no longer re-exports Combine via SwiftUI
import AVFoundation   // AVAudioSession / AVAudioEngine (keep-alive) + AVAudioRecorder (capture)
import MediaPlayer    // MPRemoteCommandCenter — the earpiece tap events

// MARK: - Earpiece controller
//
// This is the v1 recording loop. The flow we're building toward is:
//   double-tap → record → stop → [STT → LLM → TTS → playback]
// This file implements everything up to and including "stop", and saves the
// captured audio to a file. The STT/LLM/TTS handoff is stubbed (see
// `handleFinishedRecording`) — that's the next milestone, once the OpenAI key
// is wired in.
//
// THE PRIVACY GATE (the whole point of the project):
//   While "armed" we run a loop of *silent* audio. That silent audio is only
//   there so iOS keeps routing headphone taps to us — the microphone is NOT
//   engaged. The mic turns on ONLY inside `startRecording()`, on a deliberate
//   double-tap, and turns off again the moment we stop. So the iOS orange mic
//   dot is literally the privacy gate made visible: it lights only while you're
//   holding a query.
//
// Note: plain `ObservableObject`, NOT annotated `@MainActor` — annotating it
// breaks the synthesized `objectWillChange` (see BUILDLOG). MPRemoteCommandCenter
// does NOT promise which thread it calls our handlers on — and when the screen is
// locked it often isn't the main thread — so we funnel every command through
// `onMain(_:)` before touching @Published state or scheduling timers. (That funnel
// is what makes the locked-screen recording actually stop; see `onMain`.)
final class EarpieceController: ObservableObject {

    /// v1 states: idle and listening for a trigger, capturing your voice, or
    /// busy running the STT → reasoning → TTS pipeline on what you said.
    enum Status {
        case armed
        case recording
        case working
    }

    @Published var status: Status = .armed
    @Published var events: [String] = []          // newest-first on-screen log
    @Published var lastRecordingURL: URL?          // so we can play it back to verify
    @Published var demoFiles: [URL] = []           // DEMO BUILD: last captured exchange, for Export

    // Keep-alive: a silent audio loop that keeps us eligible for remote commands.
    private let audioEngine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var keepAliveBuffer: AVAudioPCMBuffer?    // the silent loop, built once and reused on restart

    // Capture + playback.
    private var recorder: AVAudioRecorder?
    private var verificationPlayer: AVAudioPlayer?   // strong ref so playback isn't deallocated mid-sound

    // The assistant pipeline (STT → reasoning + web-search → TTS), behind the
    // `AssistantProvider` seam (BUILDLOG Entry 5) so the app never talks to a
    // specific vendor directly. Swapping providers is a one-file change.
    private let assistant: AssistantProvider = OpenAIProvider()
    // Streamed answer playback: a dedicated node on the shared keep-alive engine. We
    // schedule PCM buffers onto it as they arrive from the provider, so the answer
    // starts speaking on the first chunk instead of waiting for the whole clip.
    private let answerNode = AVAudioPlayerNode()
    private lazy var ttsPlayFormat = AVAudioFormat(standardFormatWithSampleRate: assistant.ttsSampleRate,
                                                   channels: 1)!

    // On-device speech for instant spoken cues like "Thinking". It's local, so
    // the user hears "got it" the moment they stop talking — no waiting on the
    // first cloud round-trip. Different voice from the OpenAI answer, which is
    // fine for a one-word acknowledgement (and matters on an earpiece with no
    // screen to glance at).
    private let speechSynthesizer = AVSpeechSynthesizer()

    // Safety net: if we somehow miss the "stop" tap, don't record forever
    // (runaway file size + wasted API cost later). Auto-stop after this long.
    private var maxDurationTimer: Timer?
    private let maxRecordingSeconds: TimeInterval = 30

    // End-of-recording, take 2. We learned on real hardware that earpiece taps
    // STOP reaching the app once recording starts: Bluetooth drops from A2DP
    // (media mode, where taps arrive as media commands) to the HFP call profile
    // (where taps become call controls and never reach us). So "double-tap again
    // to stop" is physically impossible mid-recording. Instead we watch the mic
    // level and stop automatically once you've gone quiet — silence OR the 30s
    // cap above, whichever comes first.
    private var meteringTimer: Timer?
    /// Mic level (dBFS: ~-160 = pure silence, 0 = max) below which a moment
    /// counts as "silence". Tunable — quieter rooms can drop this (e.g. -50).
    private let silenceThreshold: Float = -40
    /// How long the level must stay below the threshold, continuously, before
    /// we treat the query as finished and stop.
    private let silenceDuration: TimeInterval = 1.5
    /// Only arm silence-stop AFTER we've heard speech once, so the natural pause
    /// before you start talking can't end the recording instantly.
    private var hasHeardSpeech = false
    /// When the current run of silence began (nil = not currently silent).
    private var silenceStartedAt: Date?

    // Dead-input detection (the locked-screen case). iOS won't engage the Bluetooth
    // mic for a backgrounded app that *starts* recording while the screen is locked,
    // so the recorder runs but captures pure digital silence (~-120 dBFS, far below
    // any live mic's noise floor). We track the loudest level heard and when recording
    // began; if nothing crosses the no-signal floor within a short grace period, the
    // mic isn't reaching us, and we stop early with a spoken "unlock and ask again"
    // (see `checkForSilence` / `stopRecording`) — instead of recording 30s of nothing
    // and then reporting a confusing "I didn't hear that".
    private var maxLevelSeen: Float = -160
    private var recordingStartedAt: Date?
    /// Loudest level (dBFS) that still counts as no signal at all: a dead/unreachable
    /// mic sits near -120/-160, while a live mic — even in a silent room — reads well
    /// above this. Set conservatively so we never mistake a working mic for a dead one.
    private let deadInputFloor: Float = -100
    /// How long to wait before concluding the mic is unreachable, so a normal recording
    /// has time to show real input first.
    private let deadInputGracePeriod: TimeInterval = 2.0

    init() {
        configureSessionForKeepAlive()
        setupSilentKeepAlive()
        setupRemoteCommands()
        requestMicPermission()      // ask once, up front — granting ≠ listening
        log("Armed. Tap your earpiece to start a query.")
    }

    // MARK: Audio session

    /// Armed state: `.playback`. This category cannot record, which is exactly
    /// what we want while idle — the mic is unavailable, not just unused.
    private func configureSessionForKeepAlive() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            log("Session (keep-alive) setup FAILED: \(error.localizedDescription)")
        }
    }

    /// Recording state: `.playAndRecord`. `.allowBluetooth` routes the mic to the
    /// earpiece (this drops the Bluetooth link to mono call-quality audio — fine
    /// for speech-to-text). `.defaultToSpeaker` keeps spoken answers audible later.
    private func configureSessionForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord,
                                mode: .default,
                                options: [.allowBluetooth, .defaultToSpeaker])
        try session.setActive(true)
    }

    // MARK: Keep-alive silent audio
    //
    // iOS decides who receives headphone taps partly by "who is actually playing
    // audio." A loop of silence counts, and is inaudible. This runs the whole
    // time the app is alive (UIBackgroundModes = audio keeps it going when the
    // screen locks / phone is pocketed — the real use case).
    private func setupSilentKeepAlive() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        audioEngine.attach(player)
        audioEngine.connect(player, to: audioEngine.mainMixerNode, format: format)

        // A second node on the same engine for the spoken answer (streamed in as PCM).
        // The mixer happily mixes its 24 kHz against the keep-alive's 44.1 kHz.
        audioEngine.attach(answerNode)
        audioEngine.connect(answerNode, to: audioEngine.mainMixerNode, format: ttsPlayFormat)

        let frameCount = AVAudioFrameCount(44100)   // 1 second; zero-filled = silence
        if let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) {
            buffer.frameLength = frameCount
            keepAliveBuffer = buffer
        }
        startSilentAudio()
    }

    /// (Re)start the silent loop. Idempotent — safe to call on every reclaim; it
    /// only does work if the engine or the player has actually stopped (which is
    /// what happens after an interruption like a call or another app's audio).
    private func startSilentAudio() {
        guard let buffer = keepAliveBuffer else { return }
        do {
            if !audioEngine.isRunning { try audioEngine.start() }
            if !player.isPlaying {
                player.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
                player.play()
            }
        } catch {
            log("Keep-alive engine start FAILED: \(error.localizedDescription)")
        }
    }

    // MARK: Holding the "Now Playing" slot
    //
    // iOS routes earpiece taps to whichever app is currently "Now Playing." Our
    // silent keep-alive claims that role — but it LOSES it whenever another app
    // plays audio, a call arrives, or Bluetooth re-routes. When that happens the
    // taps silently start going to Music/Spotify instead of us (exactly the bug
    // we hit the first time the LinkBuds connected). So we listen for those
    // events and grab the slot back.

    func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            log("Audio interrupted — another app or a call took over.")
        case .ended:
            reclaimAudioFocus(logReason: "after interruption")
        @unknown default:
            break
        }
    }

    /// Re-activate our session, restart the silent loop, and re-assert Now Playing
    /// so earpiece taps come back to us. Only while idle — never mid-recording.
    func reclaimAudioFocus(logReason: String?) {
        guard status == .armed else { return }
        configureSessionForKeepAlive()
        startSilentAudio()
        refreshNowPlaying()
        if let logReason { log("Reclaimed earpiece control (\(logReason)).") }
    }

    // MARK: Remote commands (the earpiece taps)
    //
    // On the test hardware (Earfun Air Pro 3, iOS 26.5) a double-tap fires
    // `nextTrackCommand`. That's our trigger. We keep handlers on the other
    // commands too so unexpected mappings still show up in the log during
    // hardware testing (e.g. when the Sony LinkBuds Open arrive).
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        // THE trigger. Double-tap toggles recording on, then off.
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.onMain { self?.handleTrigger() }
            return .success
        }

        // Diagnostics only — log other gestures so we can see each device's mapping.
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.onMain { self?.log("(single tap → togglePlayPause — not bound)") }; return .success
        }
        center.playCommand.addTarget { [weak self] _ in
            self?.onMain { self?.log("(play — not bound)") }; return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.onMain { self?.log("(pause — not bound)") }; return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.onMain { self?.log("(triple tap → previousTrack — not bound)") }; return .success
        }

        refreshNowPlaying()
    }

    /// Some iOS versions only route commands to an app that has set Now Playing
    /// info. We refresh it whenever state changes to keep our claim fresh.
    private func refreshNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: status == .recording ? "Earpiece — recording" : "Earpiece — armed",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
    }

    // MARK: The trigger

    /// Called on every double-tap. Toggles between armed and recording.
    private func handleTrigger() {
        switch status {
        case .armed:     startRecording()
        case .recording: stopRecording(reason: "double-tap")
        case .working:   log("Still working on the last query — hang on.")
        }
    }

    private func startRecording() {
        // Privacy gate: this is the ONLY place the mic is engaged.
        guard AVAudioApplication.shared.recordPermission == .granted else {
            log("Mic permission not granted — enable it in Settings, then double-tap again.")
            return
        }

        do {
            try configureSessionForRecording()

            // 16 kHz mono AAC: plenty for speech, small files, accepted by OpenAI STT.
            let url = newRecordingURL()
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16_000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]

            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true     // required before we can read the mic level
            recorder.record()
            self.recorder = recorder

            status = .recording
            refreshNowPlaying()
            log("● Recording… speak your query; stops automatically when you finish (or after \(Int(maxRecordingSeconds))s).")

            // Fresh silence-detection state for this recording.
            hasHeardSpeech = false
            silenceStartedAt = nil
            maxLevelSeen = -160
            recordingStartedAt = Date()

            // Both timers are added to the MAIN run loop in `.common` modes, not via
            // `Timer.scheduledTimer` (which uses whatever run loop the caller is on).
            // `startRecording` always runs on main now (see `onMain`), and `.common`
            // keeps them firing across run-loop mode changes — together that's what
            // lets the recording stop while the screen is locked / phone is pocketed.

            // Poll the mic level ~4×/sec to detect when you've stopped talking.
            let metering = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
                self?.checkForSilence()
            }
            RunLoop.main.add(metering, forMode: .common)
            meteringTimer = metering

            // Runaway safety net: never record longer than the cap.
            let maxDuration = Timer(timeInterval: maxRecordingSeconds, repeats: false) { [weak self] _ in
                self?.stopRecording(reason: "max-duration safety cap")
            }
            RunLoop.main.add(maxDuration, forMode: .common)
            maxDurationTimer = maxDuration
        } catch {
            log("Start recording FAILED: \(error.localizedDescription)")
            // Fall back to the armed/keep-alive session so taps still work.
            configureSessionForKeepAlive()
        }
    }

    /// Called ~4×/second while recording. Reads the current mic level and, once
    /// we've heard speech, stops the recording after a continuous quiet stretch.
    private func checkForSilence() {
        guard let recorder else { return }
        recorder.updateMeters()                            // refresh the level readings
        let level = recorder.averagePower(forChannel: 0)   // dBFS
        if level > maxLevelSeen { maxLevelSeen = level }

        // Dead-input guard (locked screen): if the mic has produced nothing but digital
        // silence by the end of the grace period, iOS isn't giving us the Bluetooth mic
        // (it won't start one for a locked, backgrounded app). Stop now and tell the
        // user, rather than recording the full 30s of nothing.
        if !hasHeardSpeech,
           let since = recordingStartedAt,
           Date().timeIntervalSince(since) >= deadInputGracePeriod,
           maxLevelSeen < deadInputFloor {
            stopRecording(reason: "mic unreachable")
            return
        }

        if level > silenceThreshold {
            // Speech (or noise above the floor): remember it, reset any silence run.
            hasHeardSpeech = true
            silenceStartedAt = nil
            return
        }

        // Below threshold = silence. Ignore until we've heard speech at least once,
        // so the lead-in pause before you start talking can't end the recording.
        guard hasHeardSpeech else { return }

        if let since = silenceStartedAt {
            if Date().timeIntervalSince(since) >= silenceDuration {
                stopRecording(reason: "silence")
            }
        } else {
            silenceStartedAt = Date()   // begin timing this quiet stretch
        }
    }

    private func stopRecording(reason: String) {
        maxDurationTimer?.invalidate()
        maxDurationTimer = nil
        meteringTimer?.invalidate()
        meteringTimer = nil

        recorder?.stop()
        let url = recorder?.url
        recorder = nil

        // Mic off: back to the silent keep-alive session.
        configureSessionForKeepAlive()
        status = .armed
        refreshNowPlaying()

        // Locked-screen case: iOS never gave us the mic (see the dead-input guard in
        // checkForSilence). Don't run the pipeline on a silent file — instead tell the
        // user out loud what to do, since on the earpiece they have no screen to read.
        if reason == "mic unreachable" {
            log("Stopped (\(reason)) — no mic input, the phone was probably locked.")
            speakCue("I couldn't reach the microphone. Unlock your phone and ask again.")
            return
        }

        if let url {
            lastRecordingURL = url
            log("Stopped (\(reason)). Saved \(url.lastPathComponent).")
            // Hand the pipeline whether the mic ever rose above the silence floor,
            // so it can shortcut the "you said nothing" case without a cloud call.
            handleFinishedRecording(url, heardSpeech: hasHeardSpeech)
        } else {
            log("Stopped (\(reason)), but no file URL was produced.")
        }
    }

    /// The full query pipeline. We have the recorded audio on disk; now turn it
    /// into a spoken answer:  transcribe → reason (with web search) → speak.
    /// Launched as a Task because every step is a network round-trip.
    private func handleFinishedRecording(_ url: URL, heardSpeech: Bool) {
        Task { await runAssistantPipeline(url, heardSpeech: heardSpeech) }
    }

    private func runAssistantPipeline(_ url: URL, heardSpeech: Bool) async {
        status = .working
        refreshNowPlaying()

        // No-speech shortcut: if the mic never crossed the silence floor while
        // recording, there's nothing to send. Say "I didn't hear that" right away
        // (in place of the "Thinking" cue) and skip the cloud round-trips entirely —
        // no transcription, no API spend.
        guard heardSpeech else {
            reportNoSpeech()
            return
        }

        speakCue("Thinking")     // instant, audible "got it" before any cloud work starts

        // The felt latency is the sum of three sequential cloud round-trips, and we
        // don't play a word until the whole TTS clip arrives. Time each stage so we
        // can see where the dead pause actually lives before trying to shrink it.
        let t0 = Date()
        do {
            log("Transcribing…")
            let heard = try await assistant.transcribe(audioURL: url)
            let t1 = Date()

            let question = heard.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !question.isEmpty else {
                // We heard *something* cross the mic threshold, but it transcribed to
                // nothing — a cough, a door, room noise. Same "I didn't hear that".
                reportNoSpeech()
                return
            }
            log("You asked: \"\(question)\"")

            log("Thinking…")
            let answer = try await assistant.respond(to: question)
            let t2 = Date()
            log("Answer: \(answer)")

            log("Speaking…")
            onMain { self.prepareAnswerPlayback() }     // clear any prior answer, ensure engine
            var firstAudioAt: Date?
            var answerPCM = Data()                       // DEMO BUILD: keep the answer audio to save
            for try await chunk in assistant.synthesizeStream(answer) {
                if firstAudioAt == nil { firstAudioAt = Date() }   // first chunk = audio can start
                answerPCM.append(chunk)                  // DEMO BUILD: accumulate (no effect on playback)
                if let buffer = makePCMBuffer(from: chunk) {
                    onMain { self.playAnswerBuffer(buffer) }
                }
            }
            let firstAudio = firstAudioAt ?? Date()
            log(String(format: "⏱ STT %.1fs · think %.1fs · TTS→first audio %.1fs · total %.1fs",
                       t1.timeIntervalSince(t0), t2.timeIntervalSince(t1),
                       firstAudio.timeIntervalSince(t2), firstAudio.timeIntervalSince(t0)))

            // DEMO BUILD ONLY: persist the full exchange (your query audio + the answer
            // audio + transcript) so it can be dropped over a screen recording. This
            // block does not exist on `main`.
            let files = DemoCapture.saveSession(queryAudio: url, answerPCM: answerPCM,
                                                sampleRate: assistant.ttsSampleRate,
                                                question: question, answer: answer)
            onMain {
                self.demoFiles = files
                self.log("Demo capture saved (\(files.count) files) — tap Export below.")
            }
            returnToArmed()
        } catch {
            // Any failed step lands here; the error's message is the log line.
            log("⚠️ \(error.localizedDescription)")
            returnToArmed()
        }
    }

    /// Ready the answer node for a fresh reply: drop any buffers still queued from a
    /// previous answer and make sure the shared engine is running.
    private func prepareAnswerPlayback() {
        answerNode.stop()
        if !audioEngine.isRunning {
            do { try audioEngine.start() }
            catch { log("Answer engine start FAILED: \(error.localizedDescription)") }
        }
    }

    /// Convert one chunk of raw little-endian 16-bit mono PCM into the Float32 buffer an
    /// AVAudioPlayerNode plays. Pure computation — safe off the main thread; the actual
    /// scheduling (`playAnswerBuffer`) hops back to main. Bytes are assembled by hand
    /// (not cast) so we never trip over Int16 alignment in the incoming Data.
    private func makePCMBuffer(from pcm: Data) -> AVAudioPCMBuffer? {
        let frames = pcm.count / 2                     // 2 bytes per 16-bit sample, mono
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: ttsPlayFormat,
                                            frameCapacity: AVAudioFrameCount(frames)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(frames)
        let out = buffer.floatChannelData![0]
        pcm.withUnsafeBytes { raw in
            for i in 0..<frames {
                let lo = UInt16(raw[i * 2])
                let hi = UInt16(raw[i * 2 + 1])
                let sample = Int16(bitPattern: lo | (hi << 8))   // little-endian → host
                out[i] = Float(sample) / 32768.0                 // Int16 range → [-1, 1]
            }
        }
        return buffer
    }

    /// Schedule a converted buffer on the answer node, starting playback if it isn't
    /// already going. Must run on the main thread (engine/node interaction).
    private func playAnswerBuffer(_ buffer: AVAudioPCMBuffer) {
        answerNode.scheduleBuffer(buffer, completionHandler: nil)
        if !answerNode.isPlaying { answerNode.play() }
    }

    private func returnToArmed() {
        status = .armed
        refreshNowPlaying()
    }

    /// Speaks a short cue with the on-device voice (instant, free, offline) so
    /// the user gets audible confirmation on a screenless earpiece.
    private func speakCue(_ text: String) {
        speechSynthesizer.speak(AVSpeechUtterance(string: text))
    }

    /// Nothing recordable came through. Tell the user out loud (this replaces the
    /// "Thinking" cue rather than following it), note it in the log, and go back to
    /// armed so the next tap works. Reached two ways: no sound crossed the mic floor
    /// at all, or sound did but transcribed to nothing.
    private func reportNoSpeech() {
        speakCue("I didn't hear that")
        log("No speech detected — tap again and speak when you're ready.")
        returnToArmed()
    }

    // MARK: On-screen testing controls (gated behind Testing mode in the UI)

    /// Runs the exact same start/stop logic a headphone tap would (`handleTrigger`),
    /// but driven from the on-screen Testing-mode button. Handy for exercising the
    /// recording loop without the earpiece — testing at a desk, or on the simulator
    /// where there's no gesture at all.
    func triggerForTesting() {
        handleTrigger()
    }

    /// Plays back the most recent recording through the current output so we can
    /// confirm the mic actually captured something — a Testing-mode tool.
    func playLastRecording() {
        guard let url = lastRecordingURL else { return }
        do {
            verificationPlayer = try AVAudioPlayer(contentsOf: url)
            verificationPlayer?.play()
            log("Playing back \(url.lastPathComponent)…")
        } catch {
            log("Playback FAILED: \(error.localizedDescription)")
        }
    }

    // MARK: Helpers

    /// Run `work` on the main thread. MPRemoteCommandCenter doesn't guarantee which
    /// thread it calls our tap handlers on, and when the phone is locked it's often
    /// a background thread. That mattered for more than tidiness: `startRecording`
    /// schedules the stop-timers on "the current run loop," and a background thread's
    /// run loop never spins — so the timers never fired, the recording never stopped,
    /// and the answer never played. Forcing every command onto main fixes that
    /// (and keeps @Published mutations on main, where SwiftUI needs them).
    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    private func requestMicPermission() {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            break
        case .denied:
            log("Mic permission was denied earlier — enable it in Settings to record.")
        case .undetermined:
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                // Callback can arrive off-main; hop back for the log/state.
                DispatchQueue.main.async {
                    self?.log(granted ? "Mic permission granted." : "Mic permission denied.")
                }
            }
        @unknown default:
            break
        }
    }

    private func newRecordingURL() -> URL {
        let stamp = Date().formatted(.iso8601.dateSeparator(.dash).timeSeparator(.omitted))
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("recording-\(stamp).m4a")
    }

    private func log(_ message: String) {
        let time = Date().formatted(date: .omitted, time: .standard)
        events.insert("[\(time)] \(message)", at: 0)
    }
}

// MARK: - UI

struct ContentView: View {
    @StateObject private var controller = EarpieceController()
    @Environment(\.scenePhase) private var scenePhase
    // Testing mode reveals the on-screen record/playback controls below. Off by
    // default (clean demo UI), and persisted so it survives a relaunch mid-test.
    @AppStorage("earpiece.testingMode") private var testingMode = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Earpiece")
                .font(.largeTitle).bold()

            // Big, obvious state indicator.
            statusBadge

            Text("Tap your earpiece to start a query.\nIt stops on its own when you finish talking.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // On-screen testing controls — shown only when Testing mode is on (toggle
            // at the bottom). They drive the exact same record start/stop as the
            // earpiece gesture, so we can exercise the loop without the buds: at a
            // desk, in a place the gesture is awkward, or on the simulator. The
            // label/colour track live status, so the button doubles as a state read-out.
            if testingMode {
                Button {
                    controller.triggerForTesting()
                } label: {
                    Label(controller.status == .recording ? "Stop recording (test)" : "Start recording (test)",
                          systemImage: controller.status == .recording ? "stop.circle.fill" : "record.circle")
                }
                .buttonStyle(.borderedProminent)
                .tint(controller.status == .recording ? .red : .blue)

                // Play back the last capture to confirm the mic actually heard something.
                if controller.lastRecordingURL != nil {
                    Button {
                        controller.playLastRecording()
                    } label: {
                        Label("Play last recording", systemImage: "play.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            // DEMO BUILD ONLY: export the last captured exchange (query audio + answer
            // audio + transcript) via the share sheet — AirDrop to the Mac, save to
            // Files, etc. — to composite into the demo video. Absent on `main`.
            if !controller.demoFiles.isEmpty {
                ShareLink(items: controller.demoFiles) {
                    Label("Export demo capture", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }

            List(controller.events, id: \.self) { event in
                Text(event)
                    .font(.system(.body, design: .monospaced))
            }

            // DEMO BUILD marker — small and at the bottom so it's easy to crop out of a
            // screen recording, but present so this build is never mistaken for the
            // shipping app (which records nothing).
            Text("demo build · capturing exchanges")
                .font(.caption2)
                .foregroundStyle(.purple.opacity(0.7))

            // Unobtrusive switch to reveal the on-screen testing controls above.
            Toggle("Testing mode", isOn: $testingMode)
                .font(.caption)
                .tint(.gray)
                .padding(.horizontal)
        }
        .padding(.top)
        // Keep (or re-grab) the "Now Playing" role so earpiece taps keep reaching
        // us — after another app plays audio, a phone call, or a Bluetooth change.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { controller.reclaimAudioFocus(logReason: nil) }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
                    .receive(on: RunLoop.main)) { note in
            controller.handleInterruption(note)
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
                    .receive(on: RunLoop.main)) { _ in
            controller.reclaimAudioFocus(logReason: "after route change")
        }
    }

    private var statusBadge: some View {
        let text: String
        let icon: String
        let color: Color
        switch controller.status {
        case .armed:     text = "ARMED";     icon = "ear";      color = .green
        case .recording: text = "RECORDING"; icon = "mic.fill"; color = .red
        case .working:   text = "WORKING…";  icon = "waveform"; color = .orange
        }
        return Label(text, systemImage: icon)
            .font(.title3).bold()
            .foregroundStyle(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.quaternary, in: Capsule())
    }
}

#Preview {
    ContentView()
}
