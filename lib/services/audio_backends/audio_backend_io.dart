import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'audio_backend_interface.dart';

class MacOSNativeAudioBackend implements AudioBackend {
  final MethodChannel _channel = const MethodChannel('audio_capture');
  final StreamController<Map<String, double>> _levelController =
      StreamController<Map<String, double>>.broadcast();

  bool _initialized = false;

  @override
  Stream<Map<String, double>> get audioLevelStream => _levelController.stream;

  @override
  Future<AudioServiceStatus> initialize() async {
    if (_initialized) {
      return AudioServiceStatus(
        supported: true,
        initialized: true,
        permissionGranted: true,
        backendName: 'macos_method_channel',
        message: '이미 초기화됨',
      );
    }

    _channel.setMethodCallHandler(_handleMethodCall);
    _initialized = true;
    return const AudioServiceStatus(
      supported: true,
      initialized: true,
      permissionGranted: true,
      backendName: 'macos_method_channel',
      message: 'macOS MethodChannel 초기화 완료',
    );
  }

  @override
  Future<AudioServiceStatus> requestPermissions() async {
    // macOS는 앱 권한 다이얼로그를 자체적으로 처리한다.
    return const AudioServiceStatus(
      supported: true,
      initialized: true,
      permissionGranted: true,
      backendName: 'macos_method_channel',
      message: 'macOS 권한은 OS 레벨에서 관리됩니다.',
    );
  }

  @override
  Future<bool> startRecording() async {
    final result = await _channel.invokeMethod<bool>('startRecording');
    return result ?? false;
  }

  @override
  Future<bool> stopRecording() async {
    final result = await _channel.invokeMethod<bool>('stopRecording');
    return result ?? false;
  }

  @override
  Future<AudioCaptureResult?> fetchRecordedAudio() async {
    final result = await _channel.invokeMethod<List<dynamic>>('getRecordedAudio');
    final audioData = result?.cast<double>();
    return AudioCaptureResult(
      samples: audioData,
      sampleRate: null,
      duration: null,
      format: 'pcm',
    );
  }

  @override
  Future<Map<String, dynamic>> describeSystem() async {
    try {
      bool canStart = await startRecording();
      if (canStart) {
        await stopRecording();
      }
      return {
        'supported': true,
        'backend': 'macOS',
        'canRecord': canStart,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } on PlatformException catch (e) {
      return {
        'supported': true,
        'backend': 'macOS',
        'error': '${e.code}: ${e.message}',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAudioLevel':
        final Map<String, dynamic> levelData =
            Map<String, dynamic>.from(call.arguments as Map);
        final dbLevel = (levelData['level'] as num?)?.toDouble() ?? -60.0;
        final rms = (levelData['rms'] as num?)?.toDouble() ?? 0.0;
        final samples = (levelData['samples'] as num?)?.toDouble() ?? 0.0;
        _levelController.add({
          'level': dbLevel,
          'rms': rms,
          'samples': samples,
        });
        return 'success';
      default:
        return 'unknown_method';
    }
  }

  @override
  Future<void> dispose() async {
    await _levelController.close();
  }
}

class FlutterSoundMobileBackend implements AudioBackend {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final StreamController<Map<String, double>> _levelController =
      StreamController<Map<String, double>>.broadcast();
  StreamSubscription<RecordingDisposition>? _progressSubscription;
  bool _initialized = false;
  bool _permissionGranted = false;
  String? _lastRecordingPath;
  static const int _sampleRate = 44100;

  @override
  Stream<Map<String, double>> get audioLevelStream => _levelController.stream;

  @override
  Future<AudioServiceStatus> initialize() async {
    if (_initialized) {
      return AudioServiceStatus(
        supported: true,
        initialized: true,
        permissionGranted: _permissionGranted,
        backendName: 'flutter_sound',
        message: '이미 초기화됨',
      );
    }

    await _recorder.openRecorder();
    await _recorder.setSubscriptionDuration(const Duration(milliseconds: 120));
    _initialized = true;
    return AudioServiceStatus(
      supported: true,
      initialized: true,
      permissionGranted: _permissionGranted,
      backendName: 'flutter_sound',
      message: 'FlutterSound 레코더 초기화 완료',
    );
  }

  @override
  Future<AudioServiceStatus> requestPermissions() async {
    final micStatus = await Permission.microphone.request();
    _permissionGranted = micStatus.isGranted;

    return AudioServiceStatus(
      supported: true,
      initialized: _initialized,
      permissionGranted: _permissionGranted,
      backendName: 'flutter_sound',
      message: _permissionGranted
          ? '마이크 권한이 허용되었습니다.'
          : '마이크 권한이 필요합니다.',
      error: _permissionGranted ? null : 'Microphone permission denied',
    );
  }

  @override
  Future<bool> startRecording() async {
    if (!_initialized) {
      await initialize();
    }

    if (!_permissionGranted) {
      final status = await requestPermissions();
      if (!status.permissionGranted) {
        return false;
      }
    }

    final tempDir = await getTemporaryDirectory();
    final filePath =
        '${tempDir.path}/obiwan_record_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _recorder.startRecorder(
      toFile: filePath,
      codec: Codec.pcm16WAV,
      sampleRate: _sampleRate,
      numChannels: 1,
    );
    _lastRecordingPath = filePath;

    await _progressSubscription?.cancel();
    _progressSubscription = _recorder.onProgress?.listen((event) {
      final dbLevel = event.decibels ?? -60.0;
      final normalized = math.max(0.0, math.min(1.0, (dbLevel + 60.0) / 60.0));
      final samples = event.duration != null
          ? (event.duration!.inMilliseconds / 1000.0 * _sampleRate)
          : 0.0;
      _levelController.add({
        'level': dbLevel,
        'rms': normalized,
        'samples': samples,
      });
    });

    return true;
  }

  @override
  Future<bool> stopRecording() async {
    try {
      await _recorder.stopRecorder();
      await _progressSubscription?.cancel();
      _progressSubscription = null;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AudioCaptureResult?> fetchRecordedAudio() async {
    final path = _lastRecordingPath;
    if (path == null) {
      return null;
    }

    final file = File(path);
    if (!await file.exists()) {
      return AudioCaptureResult(
        filePath: path,
        format: 'wav',
      );
    }

    final bytes = await file.readAsBytes();
    if (bytes.length <= 44) {
      return AudioCaptureResult(
        filePath: path,
        format: 'wav',
      );
    }

    final data = bytes.sublist(44);
    final byteData = ByteData.sublistView(data);
    final sampleCount = data.length ~/ 2;
    final samples = List<double>.generate(sampleCount, (index) {
      final value = byteData.getInt16(index * 2, Endian.little);
      return value / 32768.0;
    });

    final duration =
        Duration(milliseconds: ((sampleCount / _sampleRate) * 1000).round());

    return AudioCaptureResult(
      samples: samples,
      sampleRate: _sampleRate,
      duration: duration,
      filePath: path,
      format: 'wav',
    );
  }

  @override
  Future<Map<String, dynamic>> describeSystem() async {
    return {
      'supported': true,
      'backend': 'flutter_sound',
      'initialized': _initialized,
      'permissionGranted': _permissionGranted,
      'lastRecordingPath': _lastRecordingPath,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<void> dispose() async {
    await _progressSubscription?.cancel();
    await _recorder.closeRecorder();
    await _levelController.close();
  }
}

AudioBackend createBackend() {
  if (defaultTargetPlatform == TargetPlatform.macOS) {
    return MacOSNativeAudioBackend();
  }

  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    return FlutterSoundMobileBackend();
  }

  return UnsupportedAudioBackend();
}

class UnsupportedAudioBackend implements AudioBackend {
  @override
  Stream<Map<String, double>>? get audioLevelStream => null;

  @override
  Future<AudioServiceStatus> initialize() async =>
      const AudioServiceStatus.unsupported(message: '플랫폼을 인식할 수 없습니다.');

  @override
  Future<AudioServiceStatus> requestPermissions() async =>
      const AudioServiceStatus.unsupported(message: '권한 요청을 지원하지 않습니다.');

  @override
  Future<bool> startRecording() async => false;

  @override
  Future<bool> stopRecording() async => false;

  @override
  Future<AudioCaptureResult?> fetchRecordedAudio() async => null;

  @override
  Future<Map<String, dynamic>> describeSystem() async =>
      {'supported': false, 'backend': 'unknown'};

  @override
  Future<void> dispose() async {}
}
