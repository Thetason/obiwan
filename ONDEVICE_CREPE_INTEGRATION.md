On‑Device CREPE Integration (TFLite/CoreML)

Goal
- Real‑time, offline f0 inference with v0.1 preset (16kHz, hop 20ms, window 100ms)
- Replace server dependency; keep servers for batch/eval/labeling

Layout
- Dart service: lib/services/ondevice_crepe_service.dart (done)
- Presets: lib/config/pipeline_preset.dart (done)
- Assets: assets/models/ (pubspec mapped)

Models
- TFLite: assets/models/crepe_tiny.tflite (int8 or float16)
- CoreML: assets/models/CREPE.mlmodelc (compiled)

Android (TFLite)
1) Convert CREPE to TFLite (tiny/lite) with int8/float16
2) Add tflite_flutter + delegates (NNAPI/GPU)
3) Implement platform channel or use plugin to load model from assets/models
4) Frame inference (100ms window) → decode f0 & confidence

iOS (CoreML)
1) Convert to CoreML with quantization
2) Add a Swift method channel handler to run model on 100ms frames
3) Metal/ANE acceleration where available

Dart API (planned)
- OnDeviceCrepeService.initialize()
- analyzeWindow(window: Float32List, sr)
- analyzeTimeSeries(audio: Float32List, sr)

Fallback
- If model missing, service returns YIN/Autocorr via SinglePitchTracker.

Next
- Drop models into assets/models, wire Android/iOS runtimes, return real f0/confidence
- Update DualEngineService to treat on‑device CREPE as primary path

