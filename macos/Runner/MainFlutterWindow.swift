import Cocoa
import FlutterMacOS
import AVFoundation

class SimpleAudioRecorder {
  private var audioRecorder: AVAudioRecorder?
  private var audioPlayer: AVAudioPlayer?
  private var recordingURL: URL?
  private var channel: FlutterMethodChannel?
  
  init(channel: FlutterMethodChannel) {
    self.channel = channel
    setupRecordingURL()
  }
  
  private func setupRecordingURL() {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    recordingURL = documentsPath.appendingPathComponent("recording.caf")
  }
  
  func startRecording(result: @escaping FlutterResult) {
    // 마이크 권한 확인
    let status = AVCaptureDevice.authorizationStatus(for: .audio)
    print("🔐 [SimpleRecorder] 마이크 권한: \(status.rawValue)")
    
    if status != .authorized {
      print("❌ [SimpleRecorder] 마이크 권한 없음")
      result(FlutterError(code: "PERMISSION_DENIED", message: "Microphone permission required", details: nil))
      return
    }
    
    guard let url = recordingURL else {
      result(FlutterError(code: "NO_URL", message: "Recording URL not set", details: nil))
      return
    }
    
    // macOS 기본 설정 사용
    let settings: [String: Any] = [:]
    
    do {
      // 기존 파일 삭제
      if FileManager.default.fileExists(atPath: url.path) {
        try FileManager.default.removeItem(at: url)
        print("🗑️ [SimpleRecorder] 기존 파일 삭제")
      }
      
      audioRecorder = try AVAudioRecorder(url: url, settings: settings)
      audioRecorder?.delegate = nil
      audioRecorder?.isMeteringEnabled = true
      
      guard audioRecorder?.prepareToRecord() == true else {
        print("❌ [SimpleRecorder] prepareToRecord 실패")
        result(FlutterError(code: "PREPARE_FAILED", message: "Failed to prepare recording", details: nil))
        return
      }
      
      let success = audioRecorder?.record() ?? false
      
      if success {
        print("✅ [SimpleRecorder] 실제 마이크 녹음 시작")
        print("📁 [SimpleRecorder] 녹음 파일: \(url.path)")
        
        // 0.5초 후에 메터링 확인
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          self.audioRecorder?.updateMeters()
          let level = self.audioRecorder?.averagePower(forChannel: 0) ?? -999
          print("🎙️ [SimpleRecorder] 오디오 레벨 확인: \(level) dB")
        }
        
        result(true)
      } else {
        print("❌ [SimpleRecorder] record() 호출 실패")
        // AVAudioRecorder 상태 확인
        if let recorder = audioRecorder {
          print("📊 [SimpleRecorder] 상태: isRecording=\(recorder.isRecording), url=\(recorder.url)")
          print("📊 [SimpleRecorder] settings=\(recorder.settings)")
        }
        result(FlutterError(code: "RECORD_FAILED", message: "Failed to start recording", details: nil))
      }
    } catch {
      print("❌ [SimpleRecorder] 녹음 초기화 실패: \(error)")
      result(FlutterError(code: "RECORD_ERROR", message: error.localizedDescription, details: nil))
    }
  }
  
  func stopRecording(result: @escaping FlutterResult) {
    audioRecorder?.stop()
    audioRecorder = nil
    print("✅ [SimpleRecorder] 녹음 중지")
    result(true)
  }
  
  func playRecording(result: @escaping FlutterResult) {
    // 임시: 재생은 시뮬레이션만 하고 성공 반환
    print("🔊 [SimpleRecorder] 재생 시뮬레이션")
    
    // 3초 후에 자동 중지되도록 시뮬레이션
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
      print("⏸️ [SimpleRecorder] 재생 완료 시뮬레이션")
    }
    
    result(true)
  }
  
  func getDummyAudioData(result: @escaping FlutterResult) {
    guard let url = recordingURL else {
      print("❌ [SimpleRecorder] 녹음 파일 URL이 없음")
      result(FlutterError(code: "NO_FILE", message: "No recording file", details: nil))
      return
    }
    
    // 파일이 존재하는지 확인
    if !FileManager.default.fileExists(atPath: url.path) {
      print("❌ [SimpleRecorder] 녹음 파일이 존재하지 않음: \(url.path)")
      result(FlutterError(code: "FILE_NOT_FOUND", message: "Recording file not found", details: nil))
      return
    }
    
    // 파일 크기 확인
    do {
      let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
      let fileSize = attributes[.size] as? Int64 ?? 0
      print("📁 [SimpleRecorder] 녹음 파일 크기: \(fileSize) bytes")
      
      if fileSize == 0 {
        print("⚠️ [SimpleRecorder] 파일이 비어있음, 더미 데이터 반환")
        let dummyData = (0..<44100).map { i in
          Float(sin(Double(i) * 0.01) * 0.5)
        }
        result(dummyData)
        return
      }
      
      // 실제 오디오 데이터를 읽어서 반환
      let audioFile = try AVAudioFile(forReading: url)
      let frameCount = Int(audioFile.length)
      
      guard let buffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: AVAudioFrameCount(frameCount)) else {
        print("❌ [SimpleRecorder] 오디오 버퍼 생성 실패")
        result(FlutterError(code: "BUFFER_ERROR", message: "Failed to create audio buffer", details: nil))
        return
      }
      
      try audioFile.read(into: buffer)
      
      // Float 배열로 변환
      var audioData: [Float] = []
      if let channelData = buffer.floatChannelData?[0] {
        for i in 0..<Int(buffer.frameLength) {
          audioData.append(channelData[i])
        }
      }
      
      print("📊 [SimpleRecorder] 실제 오디오 데이터 추출: \(audioData.count) 샘플")
      result(audioData)
      
    } catch {
      print("❌ [SimpleRecorder] 오디오 파일 읽기 실패: \(error)")
      // 실패시 더미 데이터 반환
      let dummyData = (0..<44100).map { i in
        Float(sin(Double(i) * 0.01) * 0.5)
      }
      result(dummyData)
    }
  }
}

class MainFlutterWindow: NSWindow {
  private var simpleRecorder: SimpleAudioRecorder?
  
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    setupAudioChannel(controller: flutterViewController)
    requestMicrophonePermission()

    super.awakeFromNib()
  }
  
  private func requestMicrophonePermission() {
    let status = AVCaptureDevice.authorizationStatus(for: .audio)
    
    switch status {
    case .authorized:
      print("✅ macOS 마이크 권한 이미 허용됨")
    case .notDetermined:
      print("🔔 macOS 마이크 권한 요청 중...")
      AVCaptureDevice.requestAccess(for: .audio) { granted in
        DispatchQueue.main.async {
          if granted {
            print("✅ macOS 마이크 권한 허용됨!")
          } else {
            print("❌ macOS 마이크 권한 거부됨")
          }
        }
      }
    case .denied, .restricted:
      print("❌ macOS 마이크 권한이 거부되었습니다. 시스템 환경설정에서 변경하세요.")
    @unknown default:
      print("⚠️ 알 수 없는 마이크 권한 상태")
    }
  }
  
  private func setupAudioChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "audio_capture",
      binaryMessenger: controller.engine.binaryMessenger
    )
    
    simpleRecorder = SimpleAudioRecorder(channel: channel)
    
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let recorder = self?.simpleRecorder else {
        result(FlutterError(code: "NO_RECORDER", message: "Recorder not initialized", details: nil))
        return
      }
      
      switch call.method {
      case "startRecording":
        recorder.startRecording(result: result)
      case "stopRecording":
        recorder.stopRecording(result: result)
      case "getRecordedAudio":
        recorder.getDummyAudioData(result: result)
      case "playAudio":
        recorder.playRecording(result: result)
      case "pauseAudio":
        result(true)
      case "stopAudio":
        result(true)
      case "seekAudio":
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    print("✅ [MainWindow] 간단한 오디오 채널 설정 완료")
  }
}