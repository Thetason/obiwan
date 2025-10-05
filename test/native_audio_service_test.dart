import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocal_trainer_ai/services/native_audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('audio_capture');
  final List<String> methodCalls = [];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    methodCalls.clear();
    channel.setMockMethodCallHandler((MethodCall call) async {
      methodCalls.add(call.method);
      switch (call.method) {
        case 'startRecording':
          return true;
        case 'stopRecording':
          return true;
        case 'getRecordedAudio':
          return <double>[0.0, 0.1, 0.0];
        case 'getCurrentAudioLevel':
          return 0.25;
        case 'stopAudio':
        case 'pauseAudio':
        case 'playAudio':
        case 'seekAudio':
          return false;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('macOS backend delegates to MethodChannel APIs', () async {
    final status = await NativeAudioService.instance.initialize();
    expect(status?.backendName, 'macos_method_channel');

    final started = await NativeAudioService.instance.startRecording();
    expect(started, isTrue);

    final level = await NativeAudioService.instance.getCurrentAudioLevel();
    expect(level, closeTo(0.25, 0.0001));

    final stopped = await NativeAudioService.instance.stopRecording();
    expect(stopped, isTrue);

    expect(methodCalls, containsAll(<String>['startRecording', 'stopRecording', 'getRecordedAudio']));
  });
}
