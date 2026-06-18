import AVFoundation
import AudioToolbox
import Cocoa
import FlutterMacOS
import ScreenCaptureKit
import whisper
#if canImport(llama)
import llama
#endif

/// Bridges Flutter to native macOS audio APIs for meeting recording and Whisper transcription.
class RecordingBridge: NSObject {
    static let channelName = "com.calendartask/recording"

    // Audio engine for microphone capture
    private var audioEngine: AVAudioEngine?
    private var micFile: AVAudioFile?
    private var micFilePath: String?

    // System audio (ScreenCaptureKit)
    private var sysFile: AVAudioFile?
    private var sysFilePath: String?
    private var scStreamHolder: AnyObject?      // SCStream (type-erased for @available)
    private var scDelegateHolder: AnyObject?    // SCStreamDelegateImpl (type-erased)

    private var captureMode: String = "screenCapture"
    private var isRecording = false
    private let targetSampleRate: Double = 16000
    // Serial queue for all sysFile reads/writes — prevents race between the
    // SCStream sample-handler thread (writes) and the stop path (nil-out).
    private let sysFileQueue = DispatchQueue(label: "com.calendartask.sysfile")

    init(messenger: FlutterBinaryMessenger) {
        super.init()
        let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    // MARK: - Dispatch

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "startRecording":
            startRecording(mode: args["mode"] as? String ?? "screenCapture", result: result)
        case "stopRecording":
            stopRecording(result: result)
        case "transcribeAudio":
            guard let wavPath = args["wavPath"] as? String,
                  let modelPath = args["modelPath"] as? String,
                  let binaryPath = args["binaryPath"] as? String else {
                result(FlutterError(code: "ARGS", message: "Missing arguments", details: nil)); return
            }
            transcribeAudio(wavPath: wavPath, modelPath: modelPath, binaryPath: binaryPath, result: result)
        case "isLocalLlmAvailable":
            result(Self.localLlmAvailable)
        case "runLocalLlm":
            guard let modelPath = args["modelPath"] as? String,
                  let prompt = args["prompt"] as? String else {
                result(FlutterError(code: "ARGS", message: "Missing arguments", details: nil)); return
            }
            runLocalLlm(modelPath: modelPath, prompt: prompt,
                        maxTokens: args["maxTokens"] as? Int ?? 1024, result: result)
        case "removeQuarantine":
            removeQuarantine(path: args["path"] as? String ?? "", result: result)
        case "getMicrophonePermission":
            getMicrophonePermission(result: result)
        case "requestMicrophonePermission":
            requestMicrophonePermission(result: result)
        case "getAudioInputDevices":
            getAudioInputDevices(result: result)
        case "isScreenCaptureAvailable":
            if #available(macOS 13.0, *) { result(true) } else { result(false) }
        case "isRecording":
            result(isRecording)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Recording control

    private func startRecording(mode: String, result: @escaping FlutterResult) {
        guard !isRecording else {
            result(FlutterError(code: "ALREADY_RECORDING", message: "Already recording", details: nil))
            return
        }
        captureMode = mode
        if mode == "screenCapture" {
            if #available(macOS 13.0, *) {
                startScreenCaptureRecording(result: result)
            } else {
                startMicEngineOnly(result: result)
            }
        } else if mode == "blackhole" {
            startBlackholeRecording(result: result)
        } else {
            startMicEngineOnly(result: result)
        }
    }

    private func stopRecording(result: @escaping FlutterResult) {
        guard isRecording else {
            result(FlutterError(code: "NOT_RECORDING", message: "Not recording", details: nil))
            return
        }
        isRecording = false
        if captureMode == "screenCapture", #available(macOS 13.0, *) {
            stopScreenCaptureRecording(result: result)
        } else {
            stopMicEngine()
            let path = micFilePath ?? ""
            micFilePath = nil
            result(path)
        }
    }

    // MARK: - Microphone-only capture

    private func startMicEngineOnly(result: @escaping FlutterResult) {
        let engine = AVAudioEngine()
        guard setupMicTap(engine: engine) else {
            result(FlutterError(code: "SETUP_ERROR", message: "Failed to set up mic tap", details: nil))
            return
        }
        audioEngine = engine
        do {
            try engine.start()
            isRecording = true
            result(nil)
        } catch {
            result(FlutterError(code: "ENGINE_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    /// Installs a tap on the engine's input node that converts to 16kHz mono WAV.
    /// The AVAudioConverter is built lazily inside the first tap callback so we use
    /// the actual runtime hardware format rather than the pre-start format (which can
    /// be zero-rate on some Macs before the engine is running).
    @discardableResult
    private func setupMicTap(engine: AVAudioEngine) -> Bool {
        let path = makeTempPath(suffix: "_mic")
        guard let file = makeWavFile(at: path) else { return false }
        micFilePath = path
        micFile = file

        let targetFmt = wavFormat()
        var lazyConverter: AVAudioConverter? = nil

        // nil format → receive the hardware's native format in the callback
        engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] buf, _ in
            guard let self = self, let outFile = self.micFile else { return }

            if lazyConverter == nil {
                lazyConverter = AVAudioConverter(from: buf.format, to: targetFmt)
            }
            guard let conv = lazyConverter else { return }

            let cap = AVAudioFrameCount(Double(buf.frameLength) * targetFmt.sampleRate / buf.format.sampleRate + 1)
            guard cap > 0, let out = AVAudioPCMBuffer(pcmFormat: targetFmt, frameCapacity: cap) else { return }
            var err: NSError?
            var inputDone = false
            conv.convert(to: out, error: &err) { _, status in
                if inputDone { status.pointee = .noDataNow; return nil }
                inputDone = true
                status.pointee = .haveData
                return buf
            }
            if err == nil, out.frameLength > 0 { try? outFile.write(from: out) }
        }
        return true
    }

    private func stopMicEngine() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        micFile = nil
    }

    // MARK: - BlackHole capture

    private func startBlackholeRecording(result: @escaping FlutterResult) {
        guard let deviceId = findAudioInputDevice(containing: "BlackHole") else {
            // Fall back to mic-only
            startMicEngineOnly(result: result)
            return
        }

        let engine = AVAudioEngine()
        guard let inputUnit = engine.inputNode.audioUnit else {
            // No audio unit available — fall back to mic-only rather than crashing.
            startMicEngineOnly(result: result)
            return
        }
        var dev = deviceId
        let status = AudioUnitSetProperty(
            inputUnit,
            AudioUnitPropertyID(kAudioOutputUnitProperty_CurrentDevice),
            AudioUnitScope(kAudioUnitScope_Global),
            0,
            &dev,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            startMicEngineOnly(result: result)
            return
        }

        guard setupMicTap(engine: engine) else {
            result(FlutterError(code: "SETUP_ERROR", message: "Failed to set up BlackHole tap", details: nil))
            return
        }
        audioEngine = engine
        do {
            try engine.start()
            isRecording = true
            result(nil)
        } catch {
            result(FlutterError(code: "ENGINE_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    // MARK: - ScreenCaptureKit capture (macOS 13.0+ for audio)

    @available(macOS 13.0, *)
    private func startScreenCaptureRecording(result: @escaping FlutterResult) {
        // Start mic engine first
        let engine = AVAudioEngine()
        guard setupMicTap(engine: engine) else {
            result(FlutterError(code: "SETUP_ERROR", message: "Mic tap setup failed", details: nil))
            return
        }
        audioEngine = engine
        do { try engine.start() } catch {
            result(FlutterError(code: "ENGINE_ERROR", message: error.localizedDescription, details: nil))
            return
        }

        // Create sys audio output file
        let sysPath = makeTempPath(suffix: "_sys")
        guard let sysF = makeWavFile(at: sysPath) else {
            stopMicEngine()
            result(FlutterError(code: "FILE_ERROR", message: "Cannot create sys audio file", details: nil))
            return
        }
        sysFilePath = sysPath
        sysFile = sysF

        // Start SCStream for system audio
        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { [weak self] content, error in
            guard let self = self else { return }
            if let error = error {
                self.teardownAfterFailedScreenCaptureStart()
                DispatchQueue.main.async {
                    result(FlutterError(code: "SC_ERROR", message: error.localizedDescription, details: nil))
                }
                return
            }
            guard let display = content?.displays.first else {
                self.teardownAfterFailedScreenCaptureStart()
                DispatchQueue.main.async {
                    result(FlutterError(code: "NO_DISPLAY", message: "No display found for capture", details: nil))
                }
                return
            }

            let config = SCStreamConfiguration()
            config.sampleRate = 48000   // native; we convert to 16kHz
            config.channelCount = 2

            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let delegate = SCDelegateImpl()
            delegate.onAudio = { [weak self] sb in self?.appendSystemAudio(sb) }
            self.scDelegateHolder = delegate
            self.scStreamHolder = nil

            let stream = SCStream(filter: filter, configuration: config, delegate: delegate)
            do {
                try stream.addStreamOutput(delegate, type: .audio, sampleHandlerQueue: .global(qos: .userInteractive))
                try stream.startCapture()
                self.scStreamHolder = stream
                DispatchQueue.main.async {
                    self.isRecording = true
                    result(nil)
                }
            } catch {
                self.teardownAfterFailedScreenCaptureStart()
                DispatchQueue.main.async {
                    result(FlutterError(code: "SC_START_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }

    /// Tears down the mic engine and sys-audio file left running when a ScreenCaptureKit
    /// start fails after the mic engine was already started. Without this the mic tap keeps
    /// recording with `isRecording == false`, so it can never be stopped from the UI and the
    /// next start leaks another engine.
    @available(macOS 13.0, *)
    private func teardownAfterFailedScreenCaptureStart() {
        stopMicEngine()
        let mic = micFilePath
        micFilePath = nil
        if let mic = mic { try? FileManager.default.removeItem(atPath: mic) }
        scStreamHolder = nil
        scDelegateHolder = nil
        let sys = sysFilePath
        sysFilePath = nil
        // Close the sys file on the serial queue (consistent with the write path), then remove it.
        sysFileQueue.async { [weak self] in
            self?.sysFile = nil
            if let sys = sys { try? FileManager.default.removeItem(atPath: sys) }
        }
    }

    private func appendSystemAudio(_ sampleBuffer: CMSampleBuffer) {
        guard let pcm = pcmBuffer(from: sampleBuffer) else { return }
        let targetFmt = wavFormat()
        guard let converter = AVAudioConverter(from: pcm.format, to: targetFmt) else { return }
        let cap = AVAudioFrameCount(Double(pcm.frameLength) * targetSampleRate / pcm.format.sampleRate + 1)
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFmt, frameCapacity: cap) else { return }
        var err: NSError?
        var done = false
        converter.convert(to: out, error: &err) { _, status in
            defer { done = true }
            status.pointee = done ? .noDataNow : .haveData
            return done ? nil : pcm
        }
        if err == nil, out.frameLength > 0 {
            sysFileQueue.async { [weak self] in try? self?.sysFile?.write(from: out) }
        }
    }

    @available(macOS 13.0, *)
    private func stopScreenCaptureRecording(result: @escaping FlutterResult) {
        stopMicEngine()
        let mic = micFilePath; micFilePath = nil
        let sys = sysFilePath; sysFilePath = nil
        // Do NOT nil sysFile here — the SCStream callback thread may still be mid-write.
        // We nil it inside the serial sysFileQueue after stopCapture drains all pending writes.

        let stream = scStreamHolder as? SCStream
        scStreamHolder = nil
        scDelegateHolder = nil

        if let stream = stream {
            stream.stopCapture { [weak self] _ in
                guard let self = self else { return }
                // Dispatch onto sysFileQueue so we run after any in-flight writes complete.
                self.sysFileQueue.async {
                    self.sysFile = nil  // safe to close now — no more writes pending
                    DispatchQueue.global(qos: .userInitiated).async {
                        let out = self.mixFiles(path1: mic, path2: sys)
                        if let mic = mic { try? FileManager.default.removeItem(atPath: mic) }
                        if let sys = sys { try? FileManager.default.removeItem(atPath: sys) }
                        DispatchQueue.main.async { result(out ?? mic ?? "") }
                    }
                }
            }
        } else {
            sysFileQueue.async { [weak self] in self?.sysFile = nil }
            result(mic ?? "")
        }
    }

    // MARK: - Audio mixing

    private func mixFiles(path1: String?, path2: String?) -> String? {
        guard let p1 = path1, let p2 = path2,
              let f1 = try? AVAudioFile(forReading: URL(fileURLWithPath: p1)),
              let f2 = try? AVAudioFile(forReading: URL(fileURLWithPath: p2)) else { return path1 }

        let fmt = f1.processingFormat
        let len1 = AVAudioFrameCount(f1.length)
        let len2 = AVAudioFrameCount(f2.length)
        let total = max(len1, len2)
        guard total > 0 else { return path1 }

        guard let b1 = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: len1),
              let b2 = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: len2),
              let out = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: total) else { return path1 }

        try? f1.read(into: b1)
        try? f2.read(into: b2)
        out.frameLength = total

        guard let ch1 = b1.floatChannelData?[0],
              let ch2 = b2.floatChannelData?[0],
              let chO = out.floatChannelData?[0] else { return path1 }

        for i in 0..<Int(total) {
            let s1: Float = i < Int(b1.frameLength) ? ch1[i] : 0
            let s2: Float = i < Int(b2.frameLength) ? ch2[i] : 0
            chO[i] = (s1 + s2) * 0.5
        }

        let outPath = makeTempPath(suffix: "_mixed")
        guard let outFile = makeWavFile(at: outPath) else { return path1 }
        try? outFile.write(from: out)
        return outPath
    }

    // MARK: - Local LLM (llama.xcframework)

    /// True only when llama.xcframework is linked into the build. Flutter queries
    /// this so the UI can steer the user to cloud extraction otherwise.
    #if canImport(llama)
    static let localLlmAvailable = true
    #else
    static let localLlmAvailable = false
    #endif

    private func runLocalLlm(modelPath: String, prompt: String, maxTokens: Int, result: @escaping FlutterResult) {
        #if canImport(llama)
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let text = try LlamaRunner.generate(modelPath: modelPath, prompt: prompt, maxTokens: maxTokens)
                DispatchQueue.main.async { result(text) }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "LLM_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
        #else
        result(FlutterError(code: "LLM_UNAVAILABLE",
                            message: "llama.xcframework is not linked into this build", details: nil))
        #endif
    }

    // MARK: - Transcription

    /// Transcribes a 16kHz mono WAV file using the bundled whisper.xcframework.
    /// binaryPath is ignored (kept for API compatibility); modelPath points to the ggml model file.
    private func transcribeAudio(wavPath: String, modelPath: String, binaryPath: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Load the WAV as 16kHz mono float32 samples
            guard let samples = Self.loadWavSamples(path: wavPath) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "WAV_ERROR", message: "Could not read WAV file: \(wavPath)", details: nil))
                }
                return
            }

            // Init whisper context from model file
            guard let ctx = whisper_init_from_file(modelPath) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "MODEL_ERROR", message: "Could not load whisper model: \(modelPath)", details: nil))
                }
                return
            }
            defer { whisper_free(ctx) }

            // Configure params
            var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
            let langPtr = strdup("auto")
            defer { free(langPtr) }
            params.language = UnsafePointer(langPtr)
            params.translate = false
            params.print_progress = false
            params.print_realtime = false
            params.print_timestamps = false
            params.print_special = false
            params.n_threads = Int32(max(1, ProcessInfo.processInfo.processorCount - 1))

            // Run transcription
            let ret = samples.withUnsafeBufferPointer { buf in
                whisper_full(ctx, params, buf.baseAddress, Int32(buf.count))
            }

            guard ret == 0 else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "WHISPER_ERROR", message: "Transcription failed (code \(ret))", details: nil))
                }
                return
            }

            // Collect segments
            var transcript = ""
            let nSegments = whisper_full_n_segments(ctx)
            for i in 0..<nSegments {
                if let text = whisper_full_get_segment_text(ctx, i) {
                    transcript += String(cString: text)
                }
            }
            DispatchQueue.main.async { result(transcript.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }
    }

    /// Reads a WAV file and returns 16kHz mono float32 samples.
    /// Returns nil only on a hard read failure; returns [] for an empty/silent recording.
    private static func loadWavSamples(path: String) -> [Float]? {
        // Bail early on trivially small files (WAV header alone is 44 bytes)
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
        guard fileSize > 44 else { return [] }

        let url = URL(fileURLWithPath: path)
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            print("[RecordingBridge] AVAudioFile open failed: \(error)")
            return nil
        }

        guard file.length > 0 else { return [] }

        let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
        guard let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buf)) != nil else { return nil }

        // Fast path: already 16kHz mono float32
        if file.processingFormat.sampleRate == 16000 && file.processingFormat.channelCount == 1,
           let floatData = buf.floatChannelData {
            return Array(UnsafeBufferPointer(start: floatData[0], count: Int(buf.frameLength)))
        }

        // Resample / convert via AVAudioConverter
        guard let converter = AVAudioConverter(from: file.processingFormat, to: targetFormat),
              let outBuf = AVAudioPCMBuffer(pcmFormat: targetFormat,
                                            frameCapacity: AVAudioFrameCount(Double(buf.frameLength) * 16000 / file.processingFormat.sampleRate + 1)) else { return nil }
        var error: NSError?
        var inputDone = false
        converter.convert(to: outBuf, error: &error) { _, status in
            if inputDone { status.pointee = .noDataNow; return nil }
            inputDone = true
            status.pointee = .haveData
            return buf
        }
        guard error == nil, let floatData = outBuf.floatChannelData else { return nil }
        return Array(UnsafeBufferPointer(start: floatData[0], count: Int(outBuf.frameLength)))
    }

    // removeQuarantine kept for compatibility but not needed with xcframework
    private func removeQuarantine(path: String, result: @escaping FlutterResult) {
        result(nil)
    }

    // MARK: - Permissions

    private func getMicrophonePermission(result: FlutterResult) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:      result("granted")
        case .denied, .restricted: result("denied")
        default:               result("notDetermined")
        }
    }

    private func requestMicrophonePermission(result: @escaping FlutterResult) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async { result(granted) }
        }
    }

    // MARK: - Audio device enumeration

    private func getAudioInputDevices(result: FlutterResult) {
        result(listInputDeviceNames())
    }

    private func listInputDeviceNames() -> [String] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr else { return [] }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else { return [] }

        return ids.compactMap { id -> String? in
            // Only include devices with input streams
            var inAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain)
            var inSize: UInt32 = 0
            AudioObjectGetPropertyDataSize(id, &inAddr, 0, nil, &inSize)
            guard inSize > 0 else { return nil }

            var nameAddr = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            var name: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            guard AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nameSize, &name) == noErr else { return nil }
            return name as String
        }
    }

    private func findAudioInputDevice(containing substring: String) -> AudioDeviceID? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr else { return nil }
        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else { return nil }

        for id in ids {
            var inAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain)
            var inSize: UInt32 = 0
            AudioObjectGetPropertyDataSize(id, &inAddr, 0, nil, &inSize)
            guard inSize > 0 else { continue }

            var nameAddr = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            var name: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            guard AudioObjectGetPropertyData(id, &nameAddr, 0, nil, &nameSize, &name) == noErr else { continue }
            if (name as String).localizedCaseInsensitiveContains(substring) { return id }
        }
        return nil
    }

    // MARK: - Helpers

    private func wavFormat() -> AVAudioFormat {
        AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: targetSampleRate, channels: 1, interleaved: false)!
    }

    private func makeWavFile(at path: String) -> AVAudioFile? {
        // Write as 32-bit float PCM so the tap buffers (float32) write directly
        // without any intermediate conversion, and loadWavSamples can read them back cleanly.
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: targetSampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
        ]
        return try? AVAudioFile(forWriting: URL(fileURLWithPath: path), settings: settings)
    }

    private func makeTempPath(suffix: String = "") -> String {
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        return NSTemporaryDirectory() + "caltask_\(ts)\(suffix).wav"
    }

    private func pcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let desc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return nil }
        let fmt = AVAudioFormat(cmAudioFormatDescription: desc)
        let count = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard count > 0, let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: count) else { return nil }
        buf.frameLength = count
        guard CMSampleBufferCopyPCMDataIntoAudioBufferList(sampleBuffer, at: 0, frameCount: Int32(count), into: buf.mutableAudioBufferList) == noErr else { return nil }
        return buf
    }
}

// MARK: - SCStream delegate (availability-gated)

@available(macOS 13.0, *)
private class SCDelegateImpl: NSObject, SCStreamDelegate, SCStreamOutput {
    var onAudio: ((CMSampleBuffer) -> Void)?

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        onAudio?(sampleBuffer)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {}
}

// MARK: - On-device LLM inference via llama.cpp
//
// The llama framework is pulled in automatically by CocoaPods (`pod 'llama'` in
// macos/Podfile downloads the prebuilt xcframework during `flutter build macos`),
// so no manual setup is required. The `#if canImport(llama)` gate is a safety net:
// if the pod is ever removed, the app still builds and reports the engine as
// unavailable rather than failing to compile. The C API targets the llama.cpp
// version pinned in macos/llama.podspec — re-check include/llama.h when bumping it.

#if canImport(llama)
enum LlamaError: LocalizedError {
    case modelLoad(String)
    case contextInit
    case tokenize
    case decode(Int32)

    var errorDescription: String? {
        switch self {
        case .modelLoad(let p): return "Failed to load model: \(p)"
        case .contextInit: return "Failed to create llama context"
        case .tokenize: return "Failed to tokenize prompt"
        case .decode(let c): return "llama_decode failed (code \(c))"
        }
    }
}

enum LlamaRunner {
    /// Runs greedy generation over [prompt] and returns the decoded text.
    /// Loads and frees the model per call — extraction is infrequent, so we
    /// favour predictable memory over keeping a multi-GB model resident.
    static func generate(modelPath: String, prompt: String, maxTokens: Int) throws -> String {
        llama_backend_init()
        defer { llama_backend_free() }

        // Load model — offload all layers to the Metal GPU when available.
        var mparams = llama_model_default_params()
        mparams.n_gpu_layers = 99
        guard let model = llama_model_load_from_file(modelPath, mparams) else {
            throw LlamaError.modelLoad(modelPath)
        }
        defer { llama_model_free(model) }

        let vocab = llama_model_get_vocab(model)

        // Context sized for a meeting transcript plus the generated answer.
        let nCtx: UInt32 = 8192
        var cparams = llama_context_default_params()
        cparams.n_ctx = nCtx
        cparams.n_batch = 512
        cparams.n_threads = Int32(max(1, ProcessInfo.processInfo.processorCount - 1))
        cparams.n_threads_batch = cparams.n_threads
        guard let ctx = llama_init_from_model(model, cparams) else {
            throw LlamaError.contextInit
        }
        defer { llama_free(ctx) }

        // Wrap the prompt with the model's built-in chat template so role
        // markers match what the model was trained on; fall back to ChatML.
        let formatted = applyChatTemplate(model: model, userPrompt: prompt)

        // Tokenize (with special tokens / template markers parsed).
        var tokens = [llama_token](repeating: 0, count: formatted.utf8.count + 16)
        let nPrompt = formatted.withCString { cstr in
            llama_tokenize(vocab, cstr, Int32(strlen(cstr)),
                           &tokens, Int32(tokens.count),
                           /*add_special*/ true, /*parse_special*/ true)
        }
        guard nPrompt > 0 else { throw LlamaError.tokenize }
        tokens = Array(tokens.prefix(Int(nPrompt)))

        // Evaluate the prompt. llama_batch_get_one stores buf.baseAddress, which
        // is only valid inside withUnsafeMutableBufferPointer — so the decode must
        // happen within that scope, not on an escaped copy of the batch struct.
        let promptOk = tokens.withUnsafeMutableBufferPointer { buf -> Bool in
            let batch = llama_batch_get_one(buf.baseAddress, Int32(buf.count))
            return llama_decode(ctx, batch) == 0
        }
        guard promptOk else { throw LlamaError.decode(-1) }

        let nVocab = Int(llama_vocab_n_tokens(vocab))
        var output = ""
        var generated = 0
        var nPast = nPrompt

        while generated < maxTokens && Int(nPast) < Int(nCtx) {
            // Greedy: pick the highest-logit token from the last position.
            guard let logits = llama_get_logits_ith(ctx, -1) else { break }
            var best = 0
            var bestVal = logits[0]
            for i in 1..<nVocab where logits[i] > bestVal {
                bestVal = logits[i]; best = i
            }
            let next = llama_token(best)
            if llama_vocab_is_eog(vocab, next) { break }

            output += tokenToString(vocab: vocab, token: next)
            generated += 1

            var one = next
            let stepOk = withUnsafeMutablePointer(to: &one) { p -> Bool in
                let batch = llama_batch_get_one(p, 1)
                return llama_decode(ctx, batch) == 0
            }
            guard stepOk else { break }
            nPast += 1
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Detokenizes a single token to its UTF-8 piece.
    private static func tokenToString(vocab: OpaquePointer?, token: llama_token) -> String {
        var buf = [CChar](repeating: 0, count: 256)
        let n = llama_token_to_piece(vocab, token, &buf, Int32(buf.count), 0, /*special*/ false)
        guard n > 0 else { return "" }
        return String(decoding: buf.prefix(Int(n)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// Applies the model's chat template to a single user turn, asking for the
    /// assistant prefix. Falls back to ChatML if the model carries no template.
    private static func applyChatTemplate(model: OpaquePointer, userPrompt: String) -> String {
        let tmpl = llama_model_chat_template(model, nil) // nil = default template
        let role = strdup("user")
        let content = strdup(userPrompt)
        defer { free(role); free(content) }

        var msg = llama_chat_message(role: role, content: content)
        var buf = [CChar](repeating: 0, count: userPrompt.utf8.count + 512)
        let n = llama_chat_apply_template(tmpl, &msg, 1, /*add_assistant*/ true,
                                          &buf, Int32(buf.count))
        if n > 0 {
            return String(decoding: buf.prefix(Int(n)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
        // Fallback: ChatML (correct for the default Qwen2.5 model).
        return "<|im_start|>user\n\(userPrompt)<|im_end|>\n<|im_start|>assistant\n"
    }
}
#endif
