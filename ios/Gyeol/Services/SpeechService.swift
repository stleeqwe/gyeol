// 결 (Gyeol) — Apple Speech Framework on-device 통합
// 시스템설계 v3 §4.6 + 핵심질문체계 v7 §11.5
// - on-device 모드 강제 (외부 전송 0)
// - 60초 무음 자동 종료
// - 1분 제한 자동 세션 재시작 (50초 시점)

import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
public final class SpeechService: NSObject, ObservableObject {
    @Published public private(set) var isAvailable: Bool = true
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var permissionStatus: PermissionStatus = .notDetermined
    @Published public private(set) var transcript: String = ""
    @Published public private(set) var elapsedSeconds: Int = 0
    @Published public private(set) var amplitude: Float = 0
    @Published public var lastError: String?

    public enum PermissionStatus: Equatable {
        case notDetermined, granted, denied
    }

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    private var audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var sessionRestartTimer: Timer?
    private var silenceTimer: Timer?
    private var elapsedTimer: Timer?
    private var lastNonSilenceAt: Date = Date()
    private var accumulated: String = ""

    private let sessionMaxSeconds: TimeInterval = 50    // 1분 제한 우회 — 50초에 재시작
    private let silenceMaxSeconds: TimeInterval = 60    // 60초 무음 자동 종료

    public override init() {
        super.init()
        recognizer?.delegate = self
        isAvailable = recognizer?.isAvailable ?? false
    }

    public func requestPermissions() async {
        GyLog.speech.info("permission.request")
        let speech = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in cont.resume(returning: status) }
        }
        let mic = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in cont.resume(returning: granted) }
        }
        if speech == .authorized && mic {
            self.permissionStatus = .granted
        } else if speech == .notDetermined {
            self.permissionStatus = .notDetermined
        } else {
            self.permissionStatus = .denied
        }
        GyLog.speech.info("permission.result", fields: [
            "speech_status": String(speech.rawValue),
            "mic_granted": String(mic),
            "final": "\(self.permissionStatus)",
        ])
    }

    public func start() {
        guard permissionStatus == .granted else {
            self.lastError = "permission_denied"
            GyLog.speech.warn("session.start_blocked", fields: ["reason": "permission_denied"])
            return
        }
        guard !isRecording else {
            GyLog.speech.debug("session.start_ignored", fields: ["reason": "already_recording"])
            return
        }
        accumulated = ""
        transcript = ""
        elapsedSeconds = 0
        lastNonSilenceAt = Date()
        GyLog.speech.info("session.start", fields: ["on_device_supported": String(recognizer?.supportsOnDeviceRecognition ?? false)])
        startSession()
        startTimers()
    }

    public func stop() {
        let recordedSeconds = elapsedSeconds
        let transcriptChars = transcript.count
        stopTimers()
        teardownSession()
        isRecording = false
        GyLog.speech.info("session.stop", fields: [
            "elapsed_seconds": String(recordedSeconds),
            "transcript_chars": String(transcriptChars),
        ])
    }

    private func startSession() {
        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            #endif

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            if recognizer?.supportsOnDeviceRecognition == true {
                req.requiresOnDeviceRecognition = true
            }
            self.request = req

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.request?.append(buffer)
                self?.computeAmplitude(buffer: buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()

            self.task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
                guard let self else { return }
                Task { @MainActor in
                    if let result {
                        let text = result.bestTranscription.formattedString
                        self.transcript = self.accumulated + (self.accumulated.isEmpty ? "" : " ") + text
                        self.lastNonSilenceAt = Date()
                    }
                    if let _ = error {
                        // recognizer 오류는 부분 — 자동 재시작 메커니즘 외에는 stop 안 함
                    }
                }
            }

            isRecording = true
        } catch {
            self.lastError = "session_start_failed"
            isRecording = false
        }
    }

    private func teardownSession() {
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func restartSession() {
        // 누적 텍스트 보존 — Apple Speech 1분 제약 우회 (50초 시점 자동 재시작)
        accumulated = transcript
        GyLog.speech.info("session.restart_for_1min_workaround", fields: [
            "accumulated_chars": String(accumulated.count),
            "elapsed_seconds": String(elapsedSeconds),
        ])
        teardownSession()
        startSession()
    }

    private func startTimers() {
        sessionRestartTimer = Timer.scheduledTimer(withTimeInterval: sessionMaxSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.restartSession() }
        }
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if Date().timeIntervalSince(self.lastNonSilenceAt) >= self.silenceMaxSeconds {
                    GyLog.speech.info("session.silence_auto_stop", fields: ["silence_seconds": String(Int(self.silenceMaxSeconds))])
                    self.stop()
                    self.lastError = "silence_auto_stop"
                }
            }
        }
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.elapsedSeconds += 1 }
        }
    }

    private func stopTimers() {
        sessionRestartTimer?.invalidate(); sessionRestartTimer = nil
        silenceTimer?.invalidate(); silenceTimer = nil
        elapsedTimer?.invalidate(); elapsedTimer = nil
    }

    private func computeAmplitude(buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let length = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<length { sum += abs(channel[i]) }
        let avg = sum / Float(max(length, 1))
        Task { @MainActor in self.amplitude = min(1.0, avg * 8) }
    }
}

extension SpeechService: SFSpeechRecognizerDelegate {
    nonisolated public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in self.isAvailable = available }
    }
}
