// Web Audio API for Flutter Web
class WebAudioCapture {
  constructor() {
    this.audioContext = null;
    this.microphone = null;
    this.scriptProcessor = null;
    this.isRecording = false;
    this.audioCallbacks = [];
    this.sampleRate = 16000; // Target sample rate
    this.bufferSize = 1024;
  }

  async initialize() {
    try {
      // Create audio context
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      this.audioContext = new AudioContext({
        sampleRate: 48000 // Browser default, we'll downsample later
      });
      
      // Only log in development
      if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
        console.log('[WebAudioCapture] Initialized with sample rate:', this.audioContext.sampleRate);
      }
      return true;
    } catch (error) {
      console.error('[WebAudioCapture] Failed to initialize:', error);
      return false;
    }
  }

  async requestMicrophonePermission() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ 
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
          sampleRate: 48000
        } 
      });
      
      this.microphone = this.audioContext.createMediaStreamSource(stream);
      
      if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
        console.log('[WebAudioCapture] Microphone permission granted');
      }
      return true;
    } catch (error) {
      console.error('[WebAudioCapture] Microphone permission denied:', error);
      return false;
    }
  }

  async startRecording(callback) {
    if (!this.audioContext || !this.microphone) {
      console.error('[WebAudioCapture] Not initialized or no microphone access');
      return false;
    }

    if (this.isRecording) {
      console.warn('[WebAudioCapture] Already recording');
      return true;
    }

    try {
      // Resume audio context if suspended
      if (this.audioContext.state === 'suspended') {
        await this.audioContext.resume();
      }

      // Create script processor for audio processing
      this.scriptProcessor = this.audioContext.createScriptProcessor(
        this.bufferSize, 
        1, // input channels
        1  // output channels
      );

      // Process audio data
      this.scriptProcessor.onaudioprocess = (event) => {
        if (!this.isRecording) return;

        const inputBuffer = event.inputBuffer;
        const inputData = inputBuffer.getChannelData(0);
        
        // Downsample from 48kHz to 16kHz
        const downsampled = this.downsample(inputData, 48000, this.sampleRate);
        
        // Convert Float32Array to regular array for Flutter
        const audioData = Array.from(downsampled);
        
        // Send to Flutter
        if (callback) {
          callback(audioData);
        }
        
        // Also call any registered callbacks
        this.audioCallbacks.forEach(cb => cb(audioData));
      };

      // Connect nodes
      this.microphone.connect(this.scriptProcessor);
      this.scriptProcessor.connect(this.audioContext.destination);

      this.isRecording = true;
      
      if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
        console.log('[WebAudioCapture] Recording started');
      }
      return true;
    } catch (error) {
      console.error('[WebAudioCapture] Failed to start recording:', error);
      return false;
    }
  }

  stopRecording() {
    if (!this.isRecording) {
      console.warn('[WebAudioCapture] Not recording');
      return;
    }

    this.isRecording = false;

    if (this.scriptProcessor) {
      this.scriptProcessor.disconnect();
      this.microphone.disconnect();
      this.scriptProcessor.onaudioprocess = null;
      this.scriptProcessor = null;
    }

    if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
      console.log('[WebAudioCapture] Recording stopped');
    }
  }

  // Downsample audio data
  downsample(buffer, fromSampleRate, toSampleRate) {
    if (fromSampleRate === toSampleRate) {
      return buffer;
    }
    
    const sampleRateRatio = fromSampleRate / toSampleRate;
    const newLength = Math.round(buffer.length / sampleRateRatio);
    const result = new Float32Array(newLength);
    
    let offsetResult = 0;
    let offsetBuffer = 0;
    
    while (offsetResult < result.length) {
      const nextOffsetBuffer = Math.round((offsetResult + 1) * sampleRateRatio);
      let accum = 0;
      let count = 0;
      
      for (let i = offsetBuffer; i < nextOffsetBuffer && i < buffer.length; i++) {
        accum += buffer[i];
        count++;
      }
      
      result[offsetResult] = accum / count;
      offsetResult++;
      offsetBuffer = nextOffsetBuffer;
    }
    
    return result;
  }

  // Register callback for audio data
  registerCallback(callback) {
    this.audioCallbacks.push(callback);
  }

  // Unregister callback
  unregisterCallback(callback) {
    const index = this.audioCallbacks.indexOf(callback);
    if (index > -1) {
      this.audioCallbacks.splice(index, 1);
    }
  }

  dispose() {
    this.stopRecording();
    if (this.audioContext) {
      this.audioContext.close();
      this.audioContext = null;
    }
    this.audioCallbacks = [];
    
    if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
      console.log('[WebAudioCapture] Disposed');
    }
  }
}

// Create global instance
window.webAudioCapture = new WebAudioCapture();

// Add test functions for debugging
window.testWebAudio = {
  checkSupport: function() {
    console.log('[TEST] Checking Web Audio API support...');
    console.log('AudioContext:', !!(window.AudioContext || window.webkitAudioContext));
    console.log('getUserMedia:', !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia));
    console.log('Browser:', navigator.userAgent);
    return {
      audioContext: !!(window.AudioContext || window.webkitAudioContext),
      getUserMedia: !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia)
    };
  },
  
  testInitialize: async function() {
    console.log('[TEST] Testing Web Audio initialization...');
    try {
      const result = await window.webAudioCapture.initialize();
      console.log('[TEST] Initialize result:', result);
      return result;
    } catch (error) {
      console.error('[TEST] Initialize failed:', error);
      return false;
    }
  },
  
  testMicPermission: async function() {
    console.log('[TEST] Testing microphone permission...');
    try {
      const result = await window.webAudioCapture.requestMicrophonePermission();
      console.log('[TEST] Mic permission result:', result);
      return result;
    } catch (error) {
      console.error('[TEST] Mic permission failed:', error);
      return false;
    }
  }
};

if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
  console.log('[WebAudioCapture] Script loaded successfully');
  console.log('[WebAudioCapture] Test functions available at window.testWebAudio');
}