# Vocal Trainer AI - Claude Development Guide

## Project Overview
Obi-wan v2 - AI Vocal Training Assistant using CREPE + SPICE dual AI engines for real-time vocal analysis.

## Development Principles
**CRITICAL**: This project follows the software development principles outlined in `DEVELOPMENT_PRINCIPLES.md`. 

### Core Rules
1. **NO DUMMY DATA**: Never use fake, mock, or simulated data. All functionality must work with real data.
2. **Real Implementation Only**: Always implement actual functionality, never placeholders.
3. **User-Driven Workflow**: Users control the flow, no automatic transitions.
4. **Clean Code**: Follow Martin's SOLID principles and clean code rules.
5. **TDD Approach**: Test-driven development when applicable.
6. **Refactoring**: Always leave code cleaner than found.

## Project Architecture

### Technology Stack
- **Frontend**: Flutter (Dart)
- **Platform**: macOS native (AVAudioEngine)
- **AI Engines**: CREPE + SPICE for vocal analysis
- **Audio**: Real-time recording and playback

### Key Components
1. **WaveStartScreen**: Main recording interface with real microphone input
2. **AudioPlayerWidget**: Apple Voice Memos-style playback interface
3. **NativeAudioService**: Swift-Flutter bridge for audio operations
4. **AppDelegate.swift**: Native macOS audio implementation with AVAudioEngine

## Development Workflow

### 3-Step User Journey
1. **Step 1**: User holds to record singing (real microphone input)
2. **Step 2**: User reviews recording with Apple Voice Memos UI (real waveform + playback)
3. **Step 3**: User chooses to analyze → AI provides vocal feedback

### Implemented Features ✅
- Real microphone recording using AVAudioEngine (48kHz)
- Real-time audio level visualization during recording
- Apple Voice Memos-style UI for playback review
- Real waveform visualization from recorded audio data
- Native audio playback with AVAudioPlayer
- Interactive waveform scrubbing and controls
- User-controlled workflow progression

### Pending Features ⏳
- CREPE + SPICE background AI analysis during Step 2
- Step 3: Vocal analysis feedback UI
- Enhanced audio playback progress tracking

## Code Standards

### Variable Naming (Sajaniemi's Roles)
- Use intention-revealing names that indicate variable role
- Example: `_audioLevelController` (Container), `_isRecording` (Flag), `_currentPosition` (Most Recent Holder)

### Functions (Clean Code)
- Keep methods under 20 lines
- Single responsibility per method
- Descriptive names that reveal intent

### File Organization
- `/lib/screens/`: UI screens
- `/lib/widgets/`: Reusable UI components  
- `/lib/services/`: Business logic and native bridges
- `/macos/Runner/`: Native Swift implementation

## Native Integration

### Flutter-Swift Communication
```dart
// Flutter side
final result = await _channel.invokeMethod<bool>('playAudio');
```

```swift
// Swift side
case "playAudio":
    playAudio(result: result)
```

### Audio Data Flow
1. Swift AVAudioEngine captures real microphone input
2. Real-time RMS calculation for visualization
3. Audio samples stored in Float array
4. Flutter receives audio data for waveform rendering
5. Swift AVAudioPlayer handles playback of recorded audio

## Testing Strategy
- Test with real audio input/output only
- Verify actual microphone permissions and functionality
- Test user workflow without automatic progressions
- Validate audio quality and synchronization

## Common Patterns

### Error Handling
```dart
try {
  final result = await nativeMethod();
  if (!result) {
    throw Exception('Operation failed');
  }
} catch (e) {
  print('❌ Error: $e');
  // Handle gracefully
}
```

### State Management
```dart
setState(() {
  _isRecording = !_isRecording; // Flag role
  _currentPosition = newValue;   // Most Recent Holder role
});
```

## Development Commands
```bash
# Run on macOS
flutter run -d macos

# Clean build
flutter clean && flutter pub get
```

## Remember
- Always follow principles in `DEVELOPMENT_PRINCIPLES.md`
- No dummy data or simulations
- Real implementation first
- User controls the workflow
- Clean, maintainable code