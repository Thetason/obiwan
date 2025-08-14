#!/usr/bin/env python3
"""
CREPE Server - 실제 작동하는 피치 분석 서버
Google의 CREPE 모델을 사용한 고품질 단일 피치 추적
"""

import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'  # TensorFlow 경고 숨기기

from flask import Flask, request, jsonify
from flask_cors import CORS
import numpy as np
import base64
import crepe
import resampy
import io
import wave
import struct

app = Flask(__name__)
CORS(app)

# CREPE 모델 사전 로드 (첫 요청 지연 방지)
print("CREPE 모델 로딩 중...")
_ = crepe.predict(np.zeros(16000), 16000, viterbi=False, verbose=0)
print("CREPE 모델 로드 완료!")

@app.route('/health', methods=['GET'])
def health():
    """서버 상태 확인"""
    return jsonify({
        'status': 'healthy',
        'model': 'CREPE',
        'version': '1.0.0',
        'description': 'Convolutional Representation for Pitch Estimation'
    })

@app.route('/analyze', methods=['POST'])
def analyze():
    """
    오디오 데이터의 피치 분석
    
    Request:
    {
        "audio_base64": "base64 encoded audio",
        "sample_rate": 44100
    }
    
    Response:
    {
        "pitches": [261.63, 293.66, ...],
        "confidences": [0.95, 0.87, ...],
        "timestamps": [0.0, 0.01, ...],
        "statistics": {...}
    }
    """
    try:
        data = request.json
        
        # Base64 디코딩
        audio_base64 = data.get('audio_base64', '')
        sample_rate = data.get('sample_rate', 44100)
        
        if not audio_base64:
            return jsonify({'error': 'No audio data provided'}), 400
        
        # Base64 → 바이트 배열
        audio_bytes = base64.b64decode(audio_base64)
        
        # WAV 파일인 경우 처리
        if audio_bytes[:4] == b'RIFF':
            # WAV 헤더 파싱
            with io.BytesIO(audio_bytes) as wav_io:
                with wave.open(wav_io, 'rb') as wav_file:
                    n_channels = wav_file.getnchannels()
                    sample_width = wav_file.getsampwidth()
                    framerate = wav_file.getframerate()
                    n_frames = wav_file.getnframes()
                    
                    # 오디오 데이터 읽기
                    frames = wav_file.readframes(n_frames)
                    
                    # 16비트 정수를 float로 변환
                    if sample_width == 2:
                        audio_int16 = struct.unpack(f'{n_frames * n_channels}h', frames)
                        audio = np.array(audio_int16, dtype=np.float32) / 32768.0
                    else:
                        audio = np.frombuffer(frames, dtype=np.float32)
                    
                    # 스테레오를 모노로 변환
                    if n_channels == 2:
                        audio = audio.reshape(-1, 2).mean(axis=1)
                    
                    sample_rate = framerate
        else:
            # Raw float32 데이터로 가정
            audio = np.frombuffer(audio_bytes, dtype=np.float32)
        
        # 오디오 길이 확인
        if len(audio) == 0:
            return jsonify({'error': 'Empty audio data'}), 400
        
        # CREPE는 16kHz를 선호하므로 리샘플링
        if sample_rate != 16000:
            audio = resampy.resample(audio, sample_rate, 16000)
            sample_rate = 16000
        
        # 오디오 정규화 (-1 ~ 1)
        max_val = np.max(np.abs(audio))
        if max_val > 0:
            audio = audio / max_val
        
        # CREPE 분석 실행
        # step_size: 10ms (더 세밀한 분석)
        # model_capacity: full (최고 품질)
        # viterbi: True (시간적 연속성 개선)
        time, frequency, confidence, activation = crepe.predict(
            audio, 
            sample_rate,
            step_size=10,
            model_capacity='full',
            viterbi=True,
            verbose=0
        )
        
        # NaN 값 처리
        valid_indices = ~np.isnan(frequency)
        time = time[valid_indices]
        frequency = frequency[valid_indices]
        confidence = confidence[valid_indices]
        
        # 낮은 신뢰도 필터링 (0.5 이하)
        high_conf_indices = confidence > 0.5
        time = time[high_conf_indices]
        frequency = frequency[high_conf_indices]
        confidence = confidence[high_conf_indices]
        
        # 통계 계산
        statistics = {}
        if len(frequency) > 0:
            statistics = {
                'mean_pitch': float(np.mean(frequency)),
                'std_pitch': float(np.std(frequency)),
                'min_pitch': float(np.min(frequency)),
                'max_pitch': float(np.max(frequency)),
                'mean_confidence': float(np.mean(confidence)),
                'pitch_range': float(np.max(frequency) - np.min(frequency)),
                'num_frames': len(frequency)
            }
        
        # 결과 반환
        return jsonify({
            'pitches': frequency.tolist(),
            'confidences': confidence.tolist(),
            'timestamps': time.tolist(),
            'statistics': statistics,
            'sample_rate': 16000,
            'model': 'CREPE-full',
            'step_size_ms': 10
        })
        
    except Exception as e:
        import traceback
        return jsonify({
            'error': str(e),
            'traceback': traceback.format_exc()
        }), 500

@app.route('/analyze_chunked', methods=['POST'])
def analyze_chunked():
    """
    긴 오디오를 청크 단위로 분석
    메모리 효율적인 처리
    """
    try:
        data = request.json
        audio_base64 = data.get('audio_base64', '')
        sample_rate = data.get('sample_rate', 44100)
        chunk_duration = data.get('chunk_duration', 5)  # 5초 단위
        
        if not audio_base64:
            return jsonify({'error': 'No audio data provided'}), 400
        
        # Base64 디코딩
        audio_bytes = base64.b64decode(audio_base64)
        
        # 오디오 로드 (WAV 처리 로직 동일)
        if audio_bytes[:4] == b'RIFF':
            with io.BytesIO(audio_bytes) as wav_io:
                with wave.open(wav_io, 'rb') as wav_file:
                    n_channels = wav_file.getnchannels()
                    sample_width = wav_file.getsampwidth()
                    framerate = wav_file.getframerate()
                    n_frames = wav_file.getnframes()
                    frames = wav_file.readframes(n_frames)
                    
                    if sample_width == 2:
                        audio_int16 = struct.unpack(f'{n_frames * n_channels}h', frames)
                        audio = np.array(audio_int16, dtype=np.float32) / 32768.0
                    else:
                        audio = np.frombuffer(frames, dtype=np.float32)
                    
                    if n_channels == 2:
                        audio = audio.reshape(-1, 2).mean(axis=1)
                    
                    sample_rate = framerate
        else:
            audio = np.frombuffer(audio_bytes, dtype=np.float32)
        
        # 리샘플링
        if sample_rate != 16000:
            audio = resampy.resample(audio, sample_rate, 16000)
            sample_rate = 16000
        
        # 청크 단위로 분석
        chunk_size = int(chunk_duration * sample_rate)
        all_pitches = []
        all_confidences = []
        all_timestamps = []
        
        for i in range(0, len(audio), chunk_size):
            chunk = audio[i:i+chunk_size]
            
            if len(chunk) < sample_rate:  # 1초 미만은 건너뛰기
                continue
            
            # 청크 정규화
            max_val = np.max(np.abs(chunk))
            if max_val > 0:
                chunk = chunk / max_val
            
            # CREPE 분석
            time, frequency, confidence, _ = crepe.predict(
                chunk,
                sample_rate,
                step_size=10,
                model_capacity='full',
                viterbi=True,
                verbose=0
            )
            
            # 타임스탬프 조정 (청크 오프셋 추가)
            time_offset = i / sample_rate
            time = time + time_offset
            
            # 유효한 값만 추가
            valid = ~np.isnan(frequency) & (confidence > 0.5)
            all_timestamps.extend(time[valid].tolist())
            all_pitches.extend(frequency[valid].tolist())
            all_confidences.extend(confidence[valid].tolist())
        
        # 통계
        statistics = {}
        if all_pitches:
            statistics = {
                'mean_pitch': float(np.mean(all_pitches)),
                'std_pitch': float(np.std(all_pitches)),
                'min_pitch': float(np.min(all_pitches)),
                'max_pitch': float(np.max(all_pitches)),
                'mean_confidence': float(np.mean(all_confidences)),
                'total_duration': float(len(audio) / sample_rate),
                'num_chunks': int(np.ceil(len(audio) / chunk_size))
            }
        
        return jsonify({
            'pitches': all_pitches,
            'confidences': all_confidences,
            'timestamps': all_timestamps,
            'statistics': statistics,
            'chunk_duration': chunk_duration,
            'model': 'CREPE-full-chunked'
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print("=" * 50)
    print("🎵 CREPE Server - 실제 피치 분석 서버")
    print("=" * 50)
    print("포트: 5002")
    print("모델: CREPE (Convolutional Neural Network)")
    print("정확도: 최고 품질 (full capacity)")
    print("=" * 50)
    print("엔드포인트:")
    print("  GET  /health          - 서버 상태")
    print("  POST /analyze         - 피치 분석")
    print("  POST /analyze_chunked - 청크 단위 분석")
    print("=" * 50)
    
    app.run(host='0.0.0.0', port=5002, debug=False)