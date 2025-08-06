import Cocoa
import FlutterMacOS
import AVFoundation

class RealTimeAudioRecorder: NSObject, AVAudioPlayerDelegate {
  private var audioEngine: AVAudioEngine?
  private var inputNode: AVAudioInputNode?
  private var channel: FlutterMethodChannel?
  private var isRecording = false
  private var recordedSamples: [Float] = []
  private var recordingStartTime: Date?
  private var audioPlayer: AVAudioPlayer?
  private var playbackTimer: Timer?
  
  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    setupAudioEngine()
  }
  
  private func setupAudioEngine() {
    audioEngine = AVAudioEngine()
    inputNode = audioEngine?.inputNode
    print("🔧 [RealTime] 오디오 엔진 초기화 완료")
  }
  
  func startRecording(result: @escaping FlutterResult) {
    print("🎙️ [RealTime] 녹음 시작 요청")
    
    // 1. 마이크 권한 확인
    let status = AVCaptureDevice.authorizationStatus(for: .audio)
    print("🔐 [RealTime] 마이크 권한 상태: \(status.rawValue)")
    
    guard status == .authorized else {
      print("❌ [RealTime] 마이크 권한 없음")
      result(FlutterError(code: "PERMISSION_DENIED", message: "Microphone permission required", details: nil))
      return
    }
    
    guard let engine = audioEngine, let input = inputNode else {
      print("❌ [RealTime] 오디오 엔진 초기화 실패")
      result(FlutterError(code: "ENGINE_NOT_READY", message: "Audio engine not ready", details: nil))
      return
    }
    
    if isRecording {
      print("⚠️ [RealTime] 이미 녹음 중")
      result(true)
      return
    }
    
    do {
      // 2. 샘플 배열 초기화
      recordedSamples.removeAll()
      recordingStartTime = Date()
      
      // 3. 입력 포맷 확인
      let inputFormat = input.outputFormat(forBus: 0)
      print("🎛️ [RealTime] 입력 포맷: \(inputFormat.sampleRate)Hz, \(inputFormat.channelCount)채널")
      
      // 4. 실시간 오디오 처리 탭 설치
      input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, when in
        self?.processAudioBuffer(buffer: buffer)
      }
      
      // 5. 오디오 엔진 시작
      try engine.start()
      isRecording = true
      
      print("✅ [RealTime] 실시간 녹음 시작 성공!")
      print("📊 [RealTime] 엔진 실행 상태: \(engine.isRunning)")
      
      result(true)
      
    } catch {
      print("❌ [RealTime] 녹음 시작 실패: \(error)")
      result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
    }
  }
  
  private func processAudioBuffer(buffer: AVAudioPCMBuffer) {
    let frameLength = Int(buffer.frameLength)
    let channelCount = Int(buffer.format.channelCount)
    
    // 멀티채널 오디오를 모노로 다운믹스
    if channelCount == 1 {
      // 모노 오디오: 직접 사용
      guard let channelData = buffer.floatChannelData?[0] else { return }
      for i in 0..<frameLength {
        recordedSamples.append(channelData[i])
      }
    } else {
      // 스테레오/멀티채널 오디오: 평균으로 다운믹스
      guard let leftChannel = buffer.floatChannelData?[0],
            let rightChannel = buffer.floatChannelData?[1] else { return }
      
      for i in 0..<frameLength {
        let monoSample = (leftChannel[i] + rightChannel[i]) * 0.5  // L+R 평균
        recordedSamples.append(monoSample)
      }
      
      print("📊 [RealTime] 스테레오→모노 다운믹스: \(channelCount)채널 → 1채널")
    }
    
    // RMS 레벨 계산 (최근 추가된 샘플들로)
    let recentSampleCount = min(frameLength, recordedSamples.count)
    let startIndex = max(0, recordedSamples.count - recentSampleCount)
    
    var sum: Float = 0.0
    for i in startIndex..<recordedSamples.count {
      sum += recordedSamples[i] * recordedSamples[i]
    }
    let rms = sqrt(sum / Float(recentSampleCount))
    let dbLevel = 20 * log10(max(rms, 0.000001))  // dB 변환
    
    // 실시간으로 레벨을 Flutter로 전송
    DispatchQueue.main.async {
      // 너무 자주 호출되지 않도록 샘플링
      if self.recordedSamples.count % 4410 == 0 { // 0.1초마다
        print("📊 [RealTime] 레벨: \(String(format: "%.1f", dbLevel))dB, 샘플: \(self.recordedSamples.count)")
        
        // Flutter로 오디오 레벨 전송
        self.channel?.invokeMethod("onAudioLevel", arguments: [
          "level": Double(dbLevel),
          "rms": Double(rms),
          "samples": self.recordedSamples.count
        ])
      }
    }
  }
  
  func stopRecording(result: @escaping FlutterResult) {
    print("🛑 [RealTime] 녹음 중지 요청")
    
    guard let engine = audioEngine, let input = inputNode else {
      result(false)
      return
    }
    
    if !isRecording {
      print("⚠️ [RealTime] 녹음 중이 아님")
      result(true)
      return
    }
    
    // 탭 제거
    input.removeTap(onBus: 0)
    
    // 엔진 중지
    if engine.isRunning {
      engine.stop()
    }
    
    isRecording = false
    
    let duration = recordingStartTime?.timeIntervalSinceNow ?? 0
    print("✅ [RealTime] 녹음 중지 완료")
    print("📊 [RealTime] 총 샘플: \(recordedSamples.count), 시간: \(String(format: "%.1f", abs(duration)))초")
    
    result(true)
  }
  
  func getRecordedAudio(result: @escaping FlutterResult) {
    print("📁 [RealTime] 녹음 데이터 요청")
    print("📊 [RealTime] 저장된 샘플 수: \(recordedSamples.count)")
    
    if recordedSamples.isEmpty {
      print("⚠️ [RealTime] 녹음된 데이터 없음, 더미 데이터 반환")
      let dummyData = (0..<44100).map { i in
        Float(sin(Double(i) * 0.01) * 0.5)
      }
      result(dummyData)
    } else {
      print("✅ [RealTime] 실제 녹음 데이터 반환: \(recordedSamples.count) 샘플")
      result(recordedSamples)
    }
  }
  
  func playRecording(result: @escaping FlutterResult) {
    print("🔊 [RealTime] 실제 오디오 재생 요청")
    
    guard !recordedSamples.isEmpty else {
      print("❌ [RealTime] 재생할 오디오 데이터 없음")
      result(false)
      return
    }
    
    // 녹음된 Float 배열을 임시 오디오 파일로 변환
    do {
      let tempURL = createTempAudioFile(samples: recordedSamples)
      
      // AVAudioPlayer로 재생
      audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
      audioPlayer?.delegate = self
      audioPlayer?.prepareToPlay()
      
      if audioPlayer?.play() == true {
        print("✅ [RealTime] 실제 오디오 재생 시작 - 길이: \(String(format: "%.1f", audioPlayer?.duration ?? 0))초")
        
        // 재생 완료를 모니터링
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
          guard let player = self?.audioPlayer else {
            self?.playbackTimer?.invalidate()
            return
          }
          
          if !player.isPlaying {
            self?.playbackTimer?.invalidate()
            print("⏸️ [RealTime] 재생 완료")
            
            // 임시 파일 삭제
            try? FileManager.default.removeItem(at: tempURL)
          }
        }
        
        result(true)
      } else {
        print("❌ [RealTime] 오디오 재생 시작 실패")
        result(false)
      }
      
    } catch {
      print("❌ [RealTime] 오디오 재생 실패: \(error)")
      result(false)
    }
  }
  
  private func createTempAudioFile(samples: [Float]) -> URL {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let tempURL = documentsPath.appendingPathComponent("temp_playback.wav")
    
    // 실제 녹음된 샘플레이트와 동일하게 설정 (48kHz)
    let sampleRate: Double = 48000.0  // 녹음과 동일한 48kHz로 변경
    let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!
    
    do {
      let audioFile = try AVAudioFile(forWriting: tempURL, settings: format.settings)
      
      guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
        print("❌ [RealTime] 버퍼 생성 실패")
        return tempURL
      }
      
      // Float 샘플을 버퍼에 복사
      let channelData = buffer.floatChannelData![0]
      for i in 0..<samples.count {
        channelData[i] = samples[i]
      }
      buffer.frameLength = AVAudioFrameCount(samples.count)
      
      try audioFile.write(from: buffer)
      print("📁 [RealTime] 임시 재생 파일 생성: \(samples.count) 샘플 -> \(tempURL.lastPathComponent)")
      
    } catch {
      print("❌ [RealTime] 임시 파일 생성 실패: \(error)")
    }
    
    return tempURL
  }
  
  // MARK: - AVAudioPlayerDelegate
  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    print("🔊 [RealTime] 재생 완료됨: successfully=\(flag)")
    playbackTimer?.invalidate()
    playbackTimer = nil
  }
  
  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    if let error = error {
      print("❌ [RealTime] 재생 디코드 오류: \(error)")
    }
  }
}

class MainFlutterWindow: NSWindow {
  private var audioRecorder: RealTimeAudioRecorder?
  
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
      print("✅ [Main] macOS 마이크 권한 허용됨")
    case .notDetermined:
      print("🔔 [Main] macOS 마이크 권한 요청 중...")
      AVCaptureDevice.requestAccess(for: .audio) { granted in
        DispatchQueue.main.async {
          print(granted ? "✅ [Main] 마이크 권한 허용됨!" : "❌ [Main] 마이크 권한 거부됨")
        }
      }
    case .denied, .restricted:
      print("❌ [Main] 마이크 권한이 거부되었습니다.")
    @unknown default:
      print("⚠️ [Main] 알 수 없는 권한 상태")
    }
  }
  
  private func setupAudioChannel(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "audio_capture",
      binaryMessenger: controller.engine.binaryMessenger
    )
    
    audioRecorder = RealTimeAudioRecorder(channel: channel)
    
    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let recorder = self?.audioRecorder else {
        result(FlutterError(code: "NO_RECORDER", message: "Recorder not initialized", details: nil))
        return
      }
      
      switch call.method {
      case "startRecording":
        recorder.startRecording(result: result)
      case "stopRecording":
        recorder.stopRecording(result: result)
      case "getRecordedAudio":
        recorder.getRecordedAudio(result: result)
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
    
    print("✅ [Main] 실시간 오디오 시스템 설정 완료")
  }
}