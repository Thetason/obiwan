import 'audio_backend_interface.dart';
import 'audio_backend_stub.dart'
    if (dart.library.io) 'audio_backend_io.dart'
    if (dart.library.html) 'audio_backend_web.dart';

AudioBackend createAudioBackend() => createBackend();
