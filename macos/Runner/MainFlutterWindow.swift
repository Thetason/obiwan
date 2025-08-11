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
  private var tempFileURL: URL?  // 임시 파일 추적
  private var isDisposed = false  // dispose 상태 추적
  
  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    setupAudioEngine()
  }
  
  deinit {
    print("🧹 [RealTime] RealTimeAudioRecorder deinit 호출됨")
    isDisposed = true
    
    // CRITICAL FIX: 타이머를 먼저 정리 (콜백 방지)
    playbackTimer?.invalidate()
    playbackTimer = nil
    
    // CRITICAL FIX: audioPlayer delegate를 nil로 설정 후 정지
    if let player = audioPlayer {
      player.delegate = nil  // delegate 해제로 콜백 방지
      player.stop()
      audioPlayer = nil
    }
    
    // 녹음 중이면 중지
    if isRecording {
      inputNode?.removeTap(onBus: 0)
      audioEngine?.stop()
      isRecording = false
    }
    
    // CRITICAL FIX: 임시 파일 안전 삭제
    if let tempURL = tempFileURL {
      DispatchQueue.global(qos: .background).async {
        try? FileManager.default.removeItem(at: tempURL)
      }
      tempFileURL = nil
    }
    
    // 엔진 정리
    audioEngine = nil
    inputNode = nil
    
    // 샘플 데이터 정리
    recordedSamples.removeAll()
    
    print("✅ [RealTime] RealTimeAudioRecorder 정리 완료")
  }
  
  private func setupAudioEngine() {
    print("🔧 [RealTime] 오디오 엔진 셋업 시작")
    
    // 기존 엔진이 있으면 완전히 정리
    if let engine = audioEngine {
      print("🔧 [RealTime] 기존 엔진 정리 중 (실행상태: \(engine.isRunning))")
      if engine.isRunning {
        engine.stop()
      }
      // 기존 탭도 제거
      inputNode?.removeTap(onBus: 0)
      audioEngine = nil
      inputNode = nil
    }
    
    // CRITICAL FIX: macOS 오디오 시스템 준비
    print("🔧 [RealTime] macOS 오디오 시스템 준비 중...")
    
    // 새 엔진 생성
    audioEngine = AVAudioEngine()
    inputNode = audioEngine?.inputNode
    
    // 엔진과 입력 노드 유효성 검사
    guard let engine = audioEngine else {
      print("❌ [RealTime] 오디오 엔진 생성 실패")
      return
    }
    
    guard let input = inputNode else {
      print("❌ [RealTime] 입력 노드 생성 실패")
      return
    }
    
    print("✅ [RealTime] 오디오 엔진 초기화 완료")
    print("🎛️ [RealTime] 엔진 상태: isRunning=\(engine.isRunning)")
    print("🎤 [RealTime] 입력 노드 포맷: \(input.outputFormat(forBus: 0))")
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
    
    // 엔진이 없으면 다시 초기화
    if audioEngine == nil {
      print("🔧 [RealTime] 오디오 엔진이 nil - 재초기화")
      setupAudioEngine()
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
      
      // 4. 기존 탭 제거 (안전 조치)
      input.removeTap(onBus: 0)
      print("🔧 [RealTime] 기존 탭 제거 완료")
      
      // 5. 실시간 오디오 처리 탭 설치 - CRITICAL FIX (SIMPLIFIED VERSION)
      let bufferSize: AVAudioFrameCount = 2048  // 적절한 버퍼 크기
      
      print("🔧 [RealTime] 탭 설치 시도 - 버퍼: \(bufferSize)")
      print("🔧 [RealTime] 입력 포맷: \(inputFormat)")
      
      // 가장 단순한 형태의 탭 설치 (format을 nil로 하여 자동 변환)
      input.installTap(onBus: 0, bufferSize: bufferSize, format: nil) { [weak self] (buffer, when) in
        // 즉시 로깅 - 어떤 스레드에서든 호출되었는지 확인
        print("📥 [RealTime] *** TAP CALLBACK RECEIVED *** - frameLength: \(buffer.frameLength)")
        
        // 강제 언래핑을 피하고 안전한 체크
        guard let strongSelf = self else { 
          print("❌ [RealTime] self is nil in callback")
          return 
        }
        
        // 녹음 상태 체크 추가
        guard strongSelf.isRecording else {
          print("⚠️ [RealTime] 녹음 중이 아닌데 콜백 수신됨")
          return
        }
        
        // 직접 처리 (메인 스레드 디스패치 제거)
        strongSelf.processAudioBuffer(buffer: buffer)
      }
      
      print("🎧 [RealTime] 오디오 탭 설치 완료 - 버퍼 크기: \(bufferSize)")
      print("🎧 [RealTime] 콜백이 오디오 스레드에서 직접 실행됨")
      
      // 5. 오디오 엔진 시작 - CRITICAL FIX with validation
      print("🚀 [RealTime] 오디오 엔진 시작 시도...")
      try engine.start()
      
      // 엔진 시작 후 즉시 상태 확인
      let engineRunning = engine.isRunning
      print("🔍 [RealTime] 엔진 시작 후 상태: isRunning=\(engineRunning)")
      
      if !engineRunning {
        throw NSError(domain: "AudioEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "Engine failed to start"])
      }
      
      // 입력 노드 상태 확인 (macOS에서는 isRunning 속성이 없음)
      print("🔍 [RealTime] 입력 노드 상태 확인 완료")
      print("🎤 [RealTime] 입력 버스 수: \(input.numberOfInputs), 출력 버스 수: \(input.numberOfOutputs)")
      
      // 0.5초 후 샘플 체크 (실제 오디오만 사용)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        guard let self = self else { return }
        if self.recordedSamples.isEmpty {
          print("⚠️ [RealTime] 0.5초 경과 - 아직 샘플이 수집되지 않음")
          print("🎤 [RealTime] 마이크 확인 필요 - 실제 오디오 입력을 기다리는 중...")
        } else {
          print("✅ [RealTime] 실제 오디오 캡처 성공: \(self.recordedSamples.count) 샘플")
        }
      }
      
      // 녹음 상태 설정
      isRecording = true
      
      print("✅ [RealTime] 실시간 녹음 시작 성공!")
      print("📊 [RealTime] 최종 상태 - 엔진: \(engineRunning), 녹음: \(isRecording)")
      
      // CRITICAL FIX: dispose 상태 체크와 함께 weak self 사용
      var checkCount = 0
      Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
        guard let self = self, !self.isDisposed else {
          timer.invalidate()
          return
        }
        
        checkCount += 1
        print("🔍 [RealTime] \(checkCount)초 후 상태 체크 - 샘플 수: \(self.recordedSamples.count)")
        
        if checkCount >= 5 { // 5초 후 정지
          timer.invalidate()
        }
        
        if self.recordedSamples.count > 0 {
          print("🎉 [RealTime] 콜백 작동 확인! 샘플 수집 성공!")
          timer.invalidate()
        }
      }
      
      result(true)
      
    } catch {
      print("❌ [RealTime] 녹음 시작 실패: \(error)")
      result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
    }
  }
  
  private func processAudioBuffer(buffer: AVAudioPCMBuffer) {
    // 녹음 상태 재확인
    guard isRecording else {
      print("⚠️ [RealTime] processAudioBuffer 호출됨 - 녹음 중이 아님")
      return
    }
    
    let frameLength = Int(buffer.frameLength)
    let channelCount = Int(buffer.format.channelCount)
    let sampleRate = buffer.format.sampleRate
    
    // 즉시 로깅 - processAudioBuffer 호출 확인 (매번 로그)
    print("🔄 [RealTime] *** PROCESS AUDIO BUFFER CALLED *** - \(frameLength) 프레임, \(channelCount) 채널, \(sampleRate)Hz")
    
    // 버퍼 유효성 검사
    guard frameLength > 0 && frameLength < 100000 else {
      print("❌ [RealTime] 비정상적인 프레임 길이: \(frameLength)")
      return
    }
    
    guard let channelData = buffer.floatChannelData else {
      print("❌ [RealTime] 오디오 채널 데이터가 nil")
      return
    }
    
    // 실제 데이터 샘플 검사
    let firstChannelData = channelData[0]
    var hasNonZeroSample = false
    var maxSample: Float = 0.0
    
    for i in 0..<min(frameLength, 10) {  // 첫 10개 샘플만 체크
      let sample = firstChannelData[i]
      if abs(sample) > 0.0001 {
        hasNonZeroSample = true
        maxSample = max(maxSample, abs(sample))
      }
    }
    
    print("🔍 [RealTime] 버퍼 데이터 검사 - 비영 샘플: \(hasNonZeroSample), 최대 값: \(maxSample)")
    
    // 실제 마이크 입력만 녹음 (테스트 신호 절대 생성하지 않음)
    if !hasNonZeroSample {
      print("🎤 [RealTime] 무음 구간 - 실제 마이크 입력 대기 중")
      // 무음이어도 계속 녹음 (실제 무음도 녹음의 일부)
    }
    
    // 디버그: 버퍼 수신 확인
    if recordedSamples.count % 10000 == 0 {
      print("🎤 [RealTime] 버퍼 수신: \(frameLength) 프레임, \(channelCount) 채널, 총 샘플: \(recordedSamples.count)")
    }
    
    // 멀티채널 오디오를 모노로 다운믹스 - CRITICAL FIX
    let oldSampleCount = recordedSamples.count
    
    if channelCount == 1 {
      // 모노 오디오: 직접 사용
      let monoChannelData = channelData[0] // UnsafeMutablePointer<Float>
      print("📊 [RealTime] 모노 채널 데이터 추가 중... \(frameLength) 샘플")
      
      for i in 0..<frameLength {
        recordedSamples.append(monoChannelData[i])
      }
      
      print("✅ [RealTime] 모노 샘플 추가 완료: \(oldSampleCount) -> \(recordedSamples.count)")
      
    } else if channelCount >= 2 {
      // 스테레오/멀티채널 오디오: 평균으로 다운믹스
      let leftChannel = channelData[0] // UnsafeMutablePointer<Float>
      
      print("📊 [RealTime] 스테레오 채널 데이터 다운믹스 중... \(frameLength) 샘플")
      
      // 오른쪽 채널이 있으면 평균, 없으면 왼쪽만 사용
      if channelCount >= 2 {
        let rightChannel = channelData[1] // UnsafeMutablePointer<Float>
        for i in 0..<frameLength {
          let monoSample = (leftChannel[i] + rightChannel[i]) * 0.5  // L+R 평균
          recordedSamples.append(monoSample)
        }
        print("✅ [RealTime] 스테레오 L+R 평균 샘플 추가: \(oldSampleCount) -> \(recordedSamples.count)")
      } else {
        for i in 0..<frameLength {
          recordedSamples.append(leftChannel[i])
        }
        print("✅ [RealTime] 좌측 채널만 샘플 추가: \(oldSampleCount) -> \(recordedSamples.count)")
      }
    }
    
    // 샘플 추가 확인
    let newSampleCount = recordedSamples.count
    if newSampleCount > oldSampleCount {
      print("🎯 [RealTime] 샘플 추가 성공: \(oldSampleCount) -> \(newSampleCount) (+\(newSampleCount - oldSampleCount))")
    } else {
      print("⚠️ [RealTime] 샘플이 추가되지 않음! 이전: \(oldSampleCount), 현재: \(newSampleCount)")
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
    
    // CRITICAL FIX: dispose 상태와 함께 실시간 레벨 전송
    DispatchQueue.main.async { [weak self] in
      guard let self = self, !self.isDisposed else { return }
      
      // 너무 자주 호출되지 않도록 샘플링
      if self.recordedSamples.count % 4410 == 0 { // 0.1초마다
        print("📊 [RealTime] 레벨: \(String(format: "%.1f", dbLevel))dB, 샘플: \(self.recordedSamples.count)")
        
        // channel과 disposed 상태 체크
        if let channel = self.channel, !self.isDisposed {
          channel.invokeMethod("onAudioLevel", arguments: [
            "level": Double(dbLevel),
            "rms": Double(rms),
            "samples": self.recordedSamples.count
          ])
        }
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
    
    // 안전하게 탭 제거
    input.removeTap(onBus: 0)
    print("✅ [RealTime] 입력 탭 제거 완료")
    
    // 엔진 중지 (안전하게)
    if engine.isRunning {
      engine.stop()
      print("✅ [RealTime] 오디오 엔진 중지 완료")
    }
    
    isRecording = false
    
    let duration = recordingStartTime?.timeIntervalSinceNow ?? 0
    print("✅ [RealTime] 녹음 중지 완료")
    print("📊 [RealTime] 총 샘플: \(recordedSamples.count), 시간: \(String(format: "%.1f", abs(duration)))초")
    
    // 엔진은 유지하고 상태만 리셋
    // 다음 녹음을 위해 엔진 재사용
    
    result(true)
  }
  
  func getRecordedAudio(result: @escaping FlutterResult) {
    print("📁 [RealTime] 녹음 데이터 요청")
    print("📊 [RealTime] 저장된 샘플 수: \(recordedSamples.count)")
    print("🔍 [RealTime] 녹음 상태: isRecording=\(isRecording)")
    print("🔍 [RealTime] 오디오 엔진 상태: \(audioEngine?.isRunning ?? false)")
    
    if recordedSamples.isEmpty {
      print("❌ [RealTime] 녹음된 데이터 없음 - 실제 에러 반환")
      
      // 에러 원인 분석
      var errorMessage = "No audio samples recorded"
      var errorCode = "NO_SAMPLES"
      
      if audioEngine == nil {
        errorMessage = "Audio engine not initialized"
        errorCode = "ENGINE_NOT_READY"
      } else if let engine = audioEngine, !engine.isRunning {
        errorMessage = "Audio engine not running during recording"
        errorCode = "ENGINE_NOT_RUNNING"
      } else if inputNode == nil {
        errorMessage = "Audio input node not available"
        errorCode = "INPUT_NODE_MISSING"
      } else {
        errorMessage = "Audio buffer processing failed - no data captured"
        errorCode = "BUFFER_PROCESSING_FAILED"
      }
      
      print("🔍 [RealTime] 에러 분석: \(errorMessage)")
      result(FlutterError(code: errorCode, message: errorMessage, details: [
        "samplesCount": recordedSamples.count,
        "isRecording": isRecording,
        "engineRunning": audioEngine?.isRunning ?? false,
        "inputNodeAvailable": inputNode != nil
      ]))
    } else {
      print("✅ [RealTime] 실제 녹음 데이터 반환: \(recordedSamples.count) 샘플")
      result(recordedSamples)
    }
  }
  
  func getRealtimeAudioBuffer(result: @escaping FlutterResult) {
    // 실시간 피치 분석을 위한 최근 버퍼만 반환 (2048 샘플 = ~0.04초)
    let bufferSize = 2048
    
    if recordedSamples.count < bufferSize {
      // 아직 충분한 데이터가 없음
      result([])
      return
    }
    
    // 최근 버퍼만 추출
    let startIdx = recordedSamples.count - bufferSize
    let recentBuffer = Array(recordedSamples[startIdx..<recordedSamples.count])
    
    print("🎤 [RealTime] 실시간 버퍼 반환: \(recentBuffer.count) 샘플")
    result(recentBuffer)
  }
  
  func loadAudioFile(path: String, result: @escaping FlutterResult) {
    print("🎵 [RealTime] 오디오 파일 로딩: \(path)")
    
    let fileURL = URL(fileURLWithPath: path)
    
    do {
      // AVAudioFile로 오디오 파일 읽기
      let audioFile = try AVAudioFile(forReading: fileURL)
      let format = audioFile.processingFormat
      let frameCount = UInt32(audioFile.length)
      
      print("📊 [RealTime] 오디오 포맷: \(format.sampleRate)Hz, \(format.channelCount)채널, \(frameCount)프레임")
      
      // 오디오 버퍼 생성 (안전한 크기 체크)
      guard frameCount > 0 && frameCount < 100_000_000 else {  // 합리적인 상한선 설정
        result(FlutterError(code: "INVALID_FRAME_COUNT", message: "Invalid frame count: \(frameCount)", details: nil))
        return
      }
      
      guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
        result(FlutterError(code: "BUFFER_ERROR", message: "Failed to create audio buffer", details: nil))
        return
      }
      
      // 파일에서 버퍼로 읽기
      try audioFile.read(into: buffer)
      buffer.frameLength = frameCount
      
      // Float 배열로 변환 (모노로 다운믹스)
      var audioSamples: [Float] = []
      let channelCount = Int(format.channelCount)
      
      if channelCount == 1 {
        // 모노 오디오
        guard let channelData = buffer.floatChannelData?[0] else {
          result(FlutterError(code: "CHANNEL_ERROR", message: "Failed to get channel data", details: nil))
          return
        }
        for i in 0..<Int(frameCount) {
          audioSamples.append(channelData[i])
        }
      } else {
        // 스테레오/멀티채널 → 모노 다운믹스
        guard let leftChannel = buffer.floatChannelData?[0],
              let rightChannel = buffer.floatChannelData?[1] else {
          result(FlutterError(code: "CHANNEL_ERROR", message: "Failed to get channel data", details: nil))
          return
        }
        
        for i in 0..<Int(frameCount) {
          let monoSample = (leftChannel[i] + rightChannel[i]) * 0.5
          audioSamples.append(monoSample)
        }
      }
      
      print("✅ [RealTime] 오디오 파일 로드 완료: \(audioSamples.count) 샘플")
      
      // Flutter로 반환 (딕셔너리 형태로)
      result([
        "samples": audioSamples,
        "sampleRate": format.sampleRate,
        "duration": Double(frameCount) / format.sampleRate
      ])
      
    } catch {
      print("❌ [RealTime] 오디오 파일 로드 실패: \(error)")
      result(FlutterError(code: "LOAD_ERROR", message: error.localizedDescription, details: nil))
    }
  }
  
  func playRecording(result: @escaping FlutterResult) {
    print("🔊 [RealTime] 실제 오디오 재생 요청")
    
    guard !recordedSamples.isEmpty, !isDisposed else {
      print("❌ [RealTime] 재생할 오디오 데이터 없음 또는 disposed")
      result(false)
      return
    }
    
    // CRITICAL FIX: 기존 플레이어와 타이머를 안전하게 정리
    cleanupPlayback()
    
    // 녹음된 Float 배열을 임시 오디오 파일로 변환
    do {
      let tempURL = createTempAudioFile(samples: recordedSamples)
      tempFileURL = tempURL  // 임시 파일 추적
      print("📁 [RealTime] 임시 파일 생성: \(tempURL.path)")
      
      // 파일 존재 확인
      guard FileManager.default.fileExists(atPath: tempURL.path) else {
        print("❌ [RealTime] 임시 오디오 파일이 생성되지 않음")
        result(false)
        return
      }
      
      // AVAudioSession은 iOS 전용이므로 macOS에서는 사용하지 않음
      // macOS는 AVAudioEngine이 자동으로 오디오 세션을 관리함
      
      // AVAudioPlayer로 재생
      audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
      audioPlayer?.delegate = self
      
      guard audioPlayer?.prepareToPlay() == true else {
        print("❌ [RealTime] 오디오 플레이어 준비 실패")
        result(false)
        return
      }
      
      if audioPlayer?.play() == true {
        print("✅ [RealTime] 실제 오디오 재생 시작 - 길이: \(String(format: "%.1f", audioPlayer?.duration ?? 0))초")
        
        // CRITICAL FIX: 재생 완료를 안전하게 모니터링
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
          guard let self = self, !self.isDisposed else {
            timer.invalidate()
            return
          }
          
          guard let player = self.audioPlayer else {
            timer.invalidate()
            return
          }
          
          if !player.isPlaying {
            timer.invalidate()
            print("⏸️ [RealTime] 재생 완료")
            
            // CRITICAL FIX: 임시 파일 안전 삭제 (백그라운드 스레드)
            if let tempURL = self.tempFileURL {
              DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
                try? FileManager.default.removeItem(at: tempURL)
              }
              self.tempFileURL = nil
            }
          }
        }
        
        result(true)
      } else {
        print("❌ [RealTime] 오디오 재생 시작 실패")
        cleanupPlayback()  // 실패 시 정리
        result(false)
      }
      
    } catch {
      print("❌ [RealTime] 오디오 재생 실패: \(error)")
      cleanupPlayback()  // 예외 발생 시 정리
      result(false)
    }
  }
  
  // CRITICAL FIX: 재생 관련 리소스 안전 정리
  func cleanupPlayback() {
    // 타이머 먼저 정리
    playbackTimer?.invalidate()
    playbackTimer = nil
    
    // 플레이어 delegate 해제 후 정지 (안전한 순서로)
    if let player = audioPlayer {
      // 1. delegate를 먼저 해제 (추가 콜백 방지)
      player.delegate = nil
      // 2. 재생 중지
      if player.isPlaying {
        player.stop()
      }
      // 3. 참조 해제
      audioPlayer = nil
    }
    
    // 임시 파일 정리 (백그라운드에서)
    if let tempURL = tempFileURL {
      DispatchQueue.global(qos: .background).async {
        try? FileManager.default.removeItem(at: tempURL)
      }
      tempFileURL = nil
    }
  }
  
  private func createTempAudioFile(samples: [Float]) -> URL {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let tempURL = documentsPath.appendingPathComponent("temp_playback_\(Int(Date().timeIntervalSince1970)).wav")
    
    // 기존 파일이 있으면 삭제
    try? FileManager.default.removeItem(at: tempURL)
    
    // 실제 녹음된 샘플레이트와 동일하게 설정 (48kHz)
    let sampleRate: Double = 48000.0
    
    guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false) else {
      print("❌ [RealTime] 오디오 포맷 생성 실패")
      return tempURL
    }
    
    do {
      // 안전한 파일 생성
      let audioFile = try AVAudioFile(forWriting: tempURL, settings: format.settings)
      
      let frameCapacity = AVAudioFrameCount(samples.count)
      guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
        print("❌ [RealTime] 버퍼 생성 실패")
        return tempURL
      }
      
      // Float 샘플을 버퍼에 안전하게 복사
      guard let channelData = buffer.floatChannelData?[0] else {
        print("❌ [RealTime] 채널 데이터 접근 실패")
        return tempURL
      }
      
      let sampleCount = min(samples.count, Int(frameCapacity))
      for i in 0..<sampleCount {
        channelData[i] = samples[i]
      }
      buffer.frameLength = AVAudioFrameCount(sampleCount)
      
      try audioFile.write(from: buffer)
      print("📁 [RealTime] 임시 재생 파일 생성: \(sampleCount) 샘플 -> \(tempURL.lastPathComponent)")
      
      // 파일 크기 확인
      if let fileSize = try? FileManager.default.attributesOfItem(atPath: tempURL.path)[.size] as? Int {
        print("📊 [RealTime] 생성된 파일 크기: \(fileSize) bytes")
      }
      
    } catch {
      print("❌ [RealTime] 임시 파일 생성 실패: \(error)")
    }
    
    return tempURL
  }
  
  // MARK: - AVAudioPlayerDelegate
  // CRITICAL FIX: delegate 메소드에서 disposed 상태 확인
  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    guard !isDisposed else { return }  // disposed 상태면 무시
    
    print("🔊 [RealTime] 재생 완료됨: successfully=\(flag)")
    
    // 타이머 정리
    playbackTimer?.invalidate()
    playbackTimer = nil
    
    // 플레이어 정리 (중요: delegate를 먼저 nil로 설정)
    if audioPlayer === player {
      player.delegate = nil
      audioPlayer = nil
    }
    
    // 임시 파일 안전 삭제
    if let tempURL = tempFileURL {
      DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 0.5) {
        try? FileManager.default.removeItem(at: tempURL)
      }
      tempFileURL = nil
    }
  }
  
  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    guard !isDisposed else { return }  // disposed 상태면 무시
    
    if let error = error {
      print("❌ [RealTime] 재생 디코드 오류: \(error)")
    }
    
    // 오류 시 정리
    cleanupPlayback()
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
      case "getRealtimeAudioBuffer":
        recorder.getRealtimeAudioBuffer(result: result)
      case "loadAudioFile":
        if let args = call.arguments as? [String: Any],
           let path = args["path"] as? String {
          recorder.loadAudioFile(path: path, result: result)
        } else {
          result(FlutterError(code: "INVALID_ARGS", message: "Path required", details: nil))
        }
      case "playAudio":
        recorder.playRecording(result: result)
      case "pauseAudio":
        result(true)
      case "stopAudio":
        self?.audioRecorder?.cleanupPlayback()
        result(true)
      case "stopPlayback":
        // stopPlayback 메서드 구현 (stopAudio와 동일한 동작)
        self?.audioRecorder?.cleanupPlayback()
        result(true)
      case "seekAudio":
        result(true)
      case "getCurrentAudioLevel":
        // 현재 오디오 레벨 반환 (임시 구현)
        result(0.0)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    print("✅ [Main] 실시간 오디오 시스템 설정 완료")
  }
}