// Export the appropriate implementation based on platform
export 'web_audio_capture_service_stub.dart'
    if (dart.library.js_interop) 'web_audio_capture_service_web.dart';