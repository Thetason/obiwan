// Web Audio API for real microphone capture
class AudioCapture {
    constructor() {
        this.audioContext = null;
        this.mediaStream = null;
        this.sourceNode = null;
        this.scriptNode = null;
        this.analyser = null;
        this.isRecording = false;
        this.onDataCallback = null;
    }

    async initialize() {
        try {
            // Request microphone access
            this.mediaStream = await navigator.mediaDevices.getUserMedia({ 
                audio: {
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true,
                    sampleRate: 48000
                } 
            });
            
            // Create audio context
            this.audioContext = new (window.AudioContext || window.webkitAudioContext)({
                sampleRate: 48000
            });
            
            // Create analyser node for frequency analysis
            this.analyser = this.audioContext.createAnalyser();
            this.analyser.fftSize = 2048;
            this.analyser.smoothingTimeConstant = 0.8;
            
            // Connect microphone to audio graph
            this.sourceNode = this.audioContext.createMediaStreamSource(this.mediaStream);
            this.sourceNode.connect(this.analyser);
            
            // Create script processor for raw audio data
            this.scriptNode = this.audioContext.createScriptProcessor(4096, 1, 1);
            this.scriptNode.onaudioprocess = (event) => {
                if (this.isRecording && this.onDataCallback) {
                    const inputData = event.inputBuffer.getChannelData(0);
                    const samples = Array.from(inputData);
                    
                    // Get frequency data
                    const frequencyData = new Uint8Array(this.analyser.frequencyBinCount);
                    this.analyser.getByteFrequencyData(frequencyData);
                    
                    // Calculate pitch using autocorrelation
                    const pitch = this.detectPitch(inputData);
                    
                    // Send data to Flutter
                    this.onDataCallback({
                        samples: samples,
                        frequency: pitch,
                        frequencyData: Array.from(frequencyData),
                        timestamp: Date.now()
                    });
                }
            };
            
            this.sourceNode.connect(this.scriptNode);
            this.scriptNode.connect(this.audioContext.destination);
            
            console.log('Audio capture initialized successfully');
            return true;
        } catch (error) {
            console.error('Failed to initialize audio capture:', error);
            return false;
        }
    }
    
    detectPitch(buffer) {
        const sampleRate = this.audioContext.sampleRate;
        const bufferSize = buffer.length;
        const correlations = new Array(bufferSize).fill(0);
        
        // Autocorrelation
        for (let lag = 0; lag < bufferSize; lag++) {
            for (let i = 0; i < bufferSize - lag; i++) {
                correlations[lag] += buffer[i] * buffer[i + lag];
            }
        }
        
        // Find the first peak after the zero lag
        let maxCorrelation = 0;
        let bestLag = -1;
        const minLag = Math.floor(sampleRate / 800); // 800 Hz max
        const maxLag = Math.floor(sampleRate / 80);  // 80 Hz min
        
        for (let lag = minLag; lag < maxLag && lag < bufferSize; lag++) {
            if (correlations[lag] > maxCorrelation) {
                maxCorrelation = correlations[lag];
                bestLag = lag;
            }
        }
        
        if (bestLag > -1 && maxCorrelation > correlations[0] * 0.3) {
            return sampleRate / bestLag;
        }
        
        return 0;
    }
    
    startRecording(callback) {
        this.isRecording = true;
        this.onDataCallback = callback;
        console.log('Recording started');
    }
    
    stopRecording() {
        this.isRecording = false;
        console.log('Recording stopped');
    }
    
    dispose() {
        if (this.scriptNode) {
            this.scriptNode.disconnect();
            this.scriptNode = null;
        }
        if (this.sourceNode) {
            this.sourceNode.disconnect();
            this.sourceNode = null;
        }
        if (this.mediaStream) {
            this.mediaStream.getTracks().forEach(track => track.stop());
            this.mediaStream = null;
        }
        if (this.audioContext) {
            this.audioContext.close();
            this.audioContext = null;
        }
    }
}

// Global instance
window.audioCapture = new AudioCapture();