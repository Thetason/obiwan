import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioCaptureService {
  FlutterSoundRecorder? _recorder;
  StreamController<Uint8List>? _audioStreamController;
  bool _isRecording = false;
  
  Stream<Uint8List> get audioStream => _audioStreamController?.stream ?? const Stream.empty();
  bool get isRecording => _isRecording;

  Future<void> initialize() async {
    _recorder = FlutterSoundRecorder();
    _audioStreamController = StreamController<Uint8List>.broadcast();
    
    await _recorder!.openRecorder();
    
    // Request microphone permission
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission not granted');
    }
  }

  Future<void> startRecording() async {
    if (_recorder == null || _isRecording) return;
    
    try {
      _isRecording = true;
      
      await _recorder!.startRecorder(
        toStream: _audioStreamController!.sink,
        codec: Codec.pcm16,
        sampleRate: 44100,
        numChannels: 1,
      );
      
      print('🎙️ Recording started - Sample Rate: 44100Hz');
    } catch (e) {
      _isRecording = false;
      throw Exception('Failed to start recording: $e');
    }
  }

  Future<void> stopRecording() async {
    if (_recorder == null || !_isRecording) return;
    
    try {
      await _recorder!.stopRecorder();
      _isRecording = false;
      print('🔇 Recording stopped');
    } catch (e) {
      throw Exception('Failed to stop recording: $e');
    }
  }

  void dispose() {
    stopRecording();
    _recorder?.closeRecorder();
    _audioStreamController?.close();
    _recorder = null;
    _audioStreamController = null;
  }
}

// Riverpod provider
final audioCaptureServiceProvider = Provider<AudioCaptureService>((ref) {
  final service = AudioCaptureService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Recording state provider
final isRecordingProvider = StateNotifierProvider<RecordingStateNotifier, bool>((ref) {
  return RecordingStateNotifier(ref.read(audioCaptureServiceProvider));
});

class RecordingStateNotifier extends StateNotifier<bool> {
  final AudioCaptureService _audioService;
  
  RecordingStateNotifier(this._audioService) : super(false);
  
  Future<void> toggleRecording() async {
    if (state) {
      await _audioService.stopRecording();
      state = false;
    } else {
      try {
        await _audioService.initialize();
        await _audioService.startRecording();
        state = true;
      } catch (e) {
        print('❌ Recording error: $e');
        state = false;
        rethrow;
      }
    }
  }
}

// Audio data stream provider
final audioDataStreamProvider = StreamProvider<Uint8List>((ref) {
  final audioService = ref.read(audioCaptureServiceProvider);
  return audioService.audioStream;
});