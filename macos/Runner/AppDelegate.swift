import AVFoundation
import Cocoa
import FlutterMacOS
import Speech

enum SpeechPracticeMacError: String {
  case permissionDenied
  case notAvailable
  case noSpeech
  case invalidArguments
  case recordingFailed
}

final class MacSpeechPracticeHandler: NSObject, FlutterStreamHandler {
  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private var eventSink: FlutterEventSink?

  private var audioEngine: AVAudioEngine?
  private var audioFile: AVAudioFile?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var currentFileURL: URL?
  private var currentPromptId: String?

  init(binaryMessenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(
      name: "top.valuespot.fluency/speech_practice",
      binaryMessenger: binaryMessenger
    )
    eventChannel = FlutterEventChannel(
      name: "top.valuespot.fluency/speech_practice/events",
      binaryMessenger: binaryMessenger
    )
    super.init()
    methodChannel.setMethodCallHandler(handle)
    eventChannel.setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPermissionStatus":
      result(permissionMap())
    case "requestPermissions":
      requestPermissions(result: result)
    case "startSession":
      startSession(call.arguments as? [String: Any], result: result)
    case "stopSession":
      stopSession(result: result)
    case "cancelSession":
      cancelSession(result: result)
    case "deleteRecording":
      deleteRecording(call.arguments as? [String: Any], result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func permissionMap() -> [String: String] {
    [
      "microphoneStatus": microphonePermissionStatus(),
      "speechStatus": speechPermissionStatus()
    ]
  }

  private func microphonePermissionStatus() -> String {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
      return "granted"
    case .denied:
      return "denied"
    case .restricted:
      return "restricted"
    case .notDetermined:
      return "notDetermined"
    @unknown default:
      return "denied"
    }
  }

  private func speechPermissionStatus() -> String {
    switch SFSpeechRecognizer.authorizationStatus() {
    case .authorized:
      return "granted"
    case .denied:
      return "denied"
    case .restricted:
      return "restricted"
    case .notDetermined:
      return "notDetermined"
    @unknown default:
      return "denied"
    }
  }

  private func requestPermissions(result: @escaping FlutterResult) {
    let group = DispatchGroup()
    group.enter()
    SFSpeechRecognizer.requestAuthorization { _ in
      group.leave()
    }

    group.enter()
    AVCaptureDevice.requestAccess(for: .audio) { _ in
      group.leave()
    }

    group.notify(queue: .main) {
      result(self.permissionMap())
    }
  }

  private func startSession(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
    guard microphonePermissionStatus() == "granted", speechPermissionStatus() == "granted" else {
      result(FlutterError(
        code: SpeechPracticeMacError.permissionDenied.rawValue,
        message: "Microphone or speech permission denied",
        details: nil
      ))
      return
    }

    guard
      let promptId = arguments?["promptId"] as? String,
      !promptId.isEmpty
    else {
      result(FlutterError(
        code: SpeechPracticeMacError.invalidArguments.rawValue,
        message: "Missing promptId",
        details: nil
      ))
      return
    }

    let localeIdentifier = (arguments?["locale"] as? String) ?? "en-US"
    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)),
          recognizer.isAvailable
    else {
      result(FlutterError(
        code: SpeechPracticeMacError.notAvailable.rawValue,
        message: "Speech recognizer unavailable",
        details: nil
      ))
      return
    }

    cleanupLiveSession(cancelRecognition: true)

    let fileName = sanitizedFileName(promptId)
    let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("\(fileName)-\(Int(Date().timeIntervalSince1970 * 1000)).caf")

    do {
      let engine = AVAudioEngine()
      let inputNode = engine.inputNode
      let inputFormat = inputNode.outputFormat(forBus: 0)
      let request = SFSpeechAudioBufferRecognitionRequest()
      request.shouldReportPartialResults = true

      let audioFile = try AVAudioFile(forWriting: fileURL, settings: inputFormat.settings)

      currentPromptId = promptId
      currentFileURL = fileURL
      self.audioFile = audioFile
      recognitionRequest = request
      audioEngine = engine

      recognitionTask = recognizer.recognitionTask(with: request) { [weak self] recognitionResult, error in
        self?.handleRecognitionCallback(recognitionResult: recognitionResult, error: error)
      }

      inputNode.removeTap(onBus: 0)
      inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
        guard let self else { return }
        self.recognitionRequest?.append(buffer)
        do {
          let playbackBuffer = self.makeAmplifiedBuffer(from: buffer, gain: 2.2)
          try self.audioFile?.write(from: playbackBuffer)
        } catch {
          self.emitError(
            code: SpeechPracticeMacError.recordingFailed.rawValue,
            message: "Failed to write recording buffer"
          )
        }
      }

      engine.prepare()
      try engine.start()
      result(["filePath": fileURL.path])
    } catch {
      cleanupLiveSession(cancelRecognition: true)
      result(FlutterError(
        code: SpeechPracticeMacError.recordingFailed.rawValue,
        message: "Failed to start live recording",
        details: error.localizedDescription
      ))
    }
  }

  private func stopSession(result: @escaping FlutterResult) {
    audioEngine?.inputNode.removeTap(onBus: 0)
    audioEngine?.stop()
    recognitionRequest?.endAudio()
    audioFile = nil
    result(["filePath": currentFileURL?.path as Any])
  }

  private func cancelSession(result: @escaping FlutterResult) {
    cleanupLiveSession(cancelRecognition: true)
    result([:])
  }

  private func deleteRecording(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
    guard let filePath = arguments?["filePath"] as? String, !filePath.isEmpty else {
      result([:])
      return
    }

    let url = URL(fileURLWithPath: filePath)
    if FileManager.default.fileExists(atPath: url.path) {
      try? FileManager.default.removeItem(at: url)
    }
    if currentFileURL?.path == filePath {
      currentFileURL = nil
    }
    result([:])
  }

  private func handleRecognitionCallback(
    recognitionResult: SFSpeechRecognitionResult?,
    error: Error?
  ) {
    guard let promptId = currentPromptId else { return }

    if let error {
      emitEvent([
        "type": "error",
        "promptId": promptId,
        "errorCode": SpeechPracticeMacError.noSpeech.rawValue,
        "errorMessage": error.localizedDescription
      ])
      cleanupLiveSession(cancelRecognition: true)
      return
    }

    guard let recognitionResult else {
      return
    }

    let transcript = recognitionResult.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
    if !transcript.isEmpty {
      emitEvent([
        "type": recognitionResult.isFinal
          ? "finalTranscriptReady"
          : "partialTranscriptUpdated",
        "promptId": promptId,
        "transcript": transcript
      ])
    }

    if recognitionResult.isFinal {
      cleanupLiveSession(cancelRecognition: false)
    }
  }

  private func emitError(code: String, message: String) {
    guard let promptId = currentPromptId else { return }
    emitEvent([
      "type": "error",
      "promptId": promptId,
      "errorCode": code,
      "errorMessage": message
    ])
  }

  private func emitEvent(_ event: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(event)
    }
  }

  private func makeAmplifiedBuffer(from buffer: AVAudioPCMBuffer, gain: Float) -> AVAudioPCMBuffer {
    guard let copy = AVAudioPCMBuffer(
      pcmFormat: buffer.format,
      frameCapacity: buffer.frameCapacity
    ) else {
      return buffer
    }
    copy.frameLength = buffer.frameLength

    if let source = buffer.floatChannelData, let destination = copy.floatChannelData {
      for channel in 0..<Int(buffer.format.channelCount) {
        let sourceChannel = source[channel]
        let destinationChannel = destination[channel]
        for frame in 0..<Int(buffer.frameLength) {
          let amplified = sourceChannel[frame] * gain
          destinationChannel[frame] = max(-1.0, min(1.0, amplified))
        }
      }
      return copy
    }

    if let source = buffer.int16ChannelData, let destination = copy.int16ChannelData {
      for channel in 0..<Int(buffer.format.channelCount) {
        let sourceChannel = source[channel]
        let destinationChannel = destination[channel]
        for frame in 0..<Int(buffer.frameLength) {
          let amplified = Float(sourceChannel[frame]) * gain
          let clamped = max(Float(Int16.min), min(Float(Int16.max), amplified))
          destinationChannel[frame] = Int16(clamped)
        }
      }
      return copy
    }

    return buffer
  }

  private func cleanupLiveSession(cancelRecognition: Bool) {
    audioEngine?.inputNode.removeTap(onBus: 0)
    audioEngine?.stop()
    audioEngine = nil
    audioFile = nil

    recognitionRequest?.endAudio()
    recognitionRequest = nil

    if cancelRecognition {
      recognitionTask?.cancel()
    }
    recognitionTask = nil
    currentPromptId = nil
  }

  private func sanitizedFileName(_ promptId: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    let unicodeScalars = promptId.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
    return String(unicodeScalars)
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  private var speechPracticeHandler: MacSpeechPracticeHandler?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      speechPracticeHandler = MacSpeechPracticeHandler(binaryMessenger: controller.engine.binaryMessenger)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
