// Web Audio API를 사용한 실시간 오디오 처리
class AudioProcessor {
    constructor() {
        this.audioContext = null;
        this.analyser = null;
        this.microphone = null;
        this.dataArray = null;
        this.isRecording = false;
        this.onAudioLevel = null;
    }

    async initialize() {
        try {
            // 마이크 권한 요청
            const stream = await navigator.mediaDevices.getUserMedia({ 
                audio: {
                    echoCancellation: false,
                    noiseSuppression: false,
                    autoGainControl: false,
                    sampleRate: 16000
                } 
            });
            
            // Web Audio Context 생성
            this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
            
            // Analyser 노드 생성
            this.analyser = this.audioContext.createAnalyser();
            this.analyser.fftSize = 2048;
            this.analyser.smoothingTimeConstant = 0.3;
            
            // 마이크 입력 연결
            this.microphone = this.audioContext.createMediaStreamSource(stream);
            this.microphone.connect(this.analyser);
            
            // 데이터 배열 생성
            const bufferLength = this.analyser.frequencyBinCount;
            this.dataArray = new Uint8Array(bufferLength);
            
            console.log('✅ Web Audio API 초기화 완료');
            return true;
        } catch (error) {
            console.error('❌ Web Audio API 초기화 실패:', error);
            return false;
        }
    }

    startRecording(callback) {
        if (!this.audioContext || !this.analyser) {
            console.error('Audio context not initialized');
            return;
        }

        this.isRecording = true;
        this.onAudioLevel = callback;
        this._processAudio();
    }

    stopRecording() {
        this.isRecording = false;
        this.onAudioLevel = null;
    }

    _processAudio() {
        if (!this.isRecording) return;

        // 주파수 도메인 데이터 가져오기
        this.analyser.getByteFrequencyData(this.dataArray);
        
        // 시간 도메인 데이터 가져오기 (음성 레벨 계산용)
        const timeDataArray = new Uint8Array(this.analyser.fftSize);
        this.analyser.getByteTimeDomainData(timeDataArray);
        
        // RMS 계산
        let sum = 0;
        let maxValue = 0;
        
        for (let i = 0; i < timeDataArray.length; i++) {
            const sample = (timeDataArray[i] - 128) / 128.0;
            sum += sample * sample;
            maxValue = Math.max(maxValue, Math.abs(sample));
        }
        
        const rms = Math.sqrt(sum / timeDataArray.length);
        const normalizedLevel = Math.min(maxValue * 2, 1.0);
        
        // Flutter에 레벨 전송
        if (this.onAudioLevel) {
            this.onAudioLevel(normalizedLevel);
        }
        
        // 다음 프레임 처리
        requestAnimationFrame(() => this._processAudio());
    }

    getFrequencyData() {
        if (!this.analyser || !this.dataArray) return null;
        this.analyser.getByteFrequencyData(this.dataArray);
        return Array.from(this.dataArray);
    }
}

// 전역 인스턴스
window.audioProcessor = new AudioProcessor();

// Flutter와의 통신용 함수들
window.initializeAudio = async function() {
    return await window.audioProcessor.initialize();
};

window.startAudioRecording = function(callback) {
    window.audioProcessor.startRecording(callback);
};

window.stopAudioRecording = function() {
    window.audioProcessor.stopRecording();
};

window.getAudioFrequencyData = function() {
    return window.audioProcessor.getFrequencyData();
};