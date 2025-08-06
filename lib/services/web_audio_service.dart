import 'dart:js' as js;
import 'dart:async';

class WebAudioService {
  static WebAudioService? _instance;
  static WebAudioService get instance => _instance ??= WebAudioService._();
  
  WebAudioService._();
  
  bool _isInitialized = false;
  bool _isRecording = false;
  StreamController<double>? _audioLevelController;
  
  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  
  Stream<double>? get audioLevelStream => _audioLevelController?.stream;
  
  Future<bool> initialize() async {
    try {
      // JavaScript 함수가 준비될 때까지 대기
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (js.context.hasProperty('initializeAudio')) {
        final result = await js.context.callMethod('initializeAudio');
        _isInitialized = result == true;
        
        if (_isInitialized) {
          _audioLevelController = StreamController<double>.broadcast();
          print('✅ Web Audio Service 초기화 완료');
        } else {
          print('❌ Web Audio Service 초기화 실패');
        }
      } else {
        print('❌ initializeAudio 함수를 찾을 수 없음');
        _isInitialized = false;
      }
      
      return _isInitialized;
    } catch (e) {
      print('Web Audio Service 초기화 오류: $e');
      return false;
    }
  }
  
  void startRecording() {
    if (!_isInitialized || _isRecording) return;
    
    try {
      _isRecording = true;
      
      // JavaScript 콜백 함수 등록
      js.context['onAudioLevel'] = (level) {
        final normalizedLevel = (level as num).toDouble();
        _audioLevelController?.add(normalizedLevel);
      };
      
      // 녹음 시작
      js.context.callMethod('startAudioRecording', [js.context['onAudioLevel']]);
      
      print('🎤 Web Audio 녹음 시작');
    } catch (e) {
      print('Web Audio 녹음 시작 오류: $e');
      _isRecording = false;
    }
  }
  
  void stopRecording() {
    if (!_isRecording) return;
    
    try {
      js.context.callMethod('stopAudioRecording');
      _isRecording = false;
      js.context['onAudioLevel'] = null;
      
      print('🎤 Web Audio 녹음 종료');
    } catch (e) {
      print('Web Audio 녹음 종료 오류: $e');
    }
  }
  
  List<double>? getFrequencyData() {
    if (!_isInitialized) return null;
    
    try {
      final result = js.context.callMethod('getAudioFrequencyData');
      if (result != null) {
        final List<dynamic> jsArray = result;
        return jsArray.map((e) => (e as num).toDouble()).toList();
      }
    } catch (e) {
      print('주파수 데이터 가져오기 오류: $e');
    }
    
    return null;
  }
  
  void dispose() {
    stopRecording();
    _audioLevelController?.close();
    _audioLevelController = null;
    js.context['onAudioLevel'] = null;
  }
}