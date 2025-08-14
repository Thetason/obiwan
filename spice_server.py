#!/usr/bin/env python3
"""
SPICE Server - 실제 작동하는 피치 분석 서버
Google의 SPICE 모델을 사용한 Self-supervised 피치 추정
"""

import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'

from flask import Flask, request, jsonify
from flask_cors import CORS
import numpy as np
import base64
import tensorflow as tf
import tensorflow_hub as hub
import resampy
import io
import wave
import struct

app = Flask(__name__)
CORS(app)

# SPICE 모델 로드
print("SPICE 모델 로딩 중...")
model = hub.load("https://tfhub.dev/google/spice/2")
print("SPICE 모델 로드 완료!")

# 음계 정의 (A0 ~ C8)
A4 = 440
C0 = A4 * np.power(2, -4.75)
note_names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

def hz2offset(freq):
    """주파수를 MIDI 피치 오프셋으로 변환"""
    if freq <= 0:
        return 0
    return 12 * np.log2(freq / C0)

def quantize_predictions(freqs, confs):
    """예측값을 가장 가까운 음계로 양자화"""
    quantized_freqs = []
    quantized_notes = []
    
    for freq, conf in zip(freqs, confs):
        if conf < 0.5 or freq <= 0:
            quantized_freqs.append(0)
            quantized_notes.append("Rest")
        else:
            offset = hz2offset(freq)
            n = int(np.round(offset))
            cents = (offset - n) * 100
            
            note_idx = n % 12
            octave = n // 12
            
            note_name = note_names[note_idx] + str(octave)
            
            # 정확한 음계 주파수 계산
            quantized_freq = C0 * np.power(2, n / 12)
            quantized_freqs.append(quantized_freq)
            quantized_notes.append(note_name)
    
    return quantized_freqs, quantized_notes

@app.route('/health', methods=['GET'])
def health():
    """서버 상태 확인"""
    return jsonify({
        'status': 'healthy',
        'model': 'SPICE',
        'version': '2.0',
        'description': 'Self-supervised Pitch Estimation'
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
        "notes": ["C4", "D4", ...],
        "timestamps": [0.0, 0.032, ...],
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
            # Raw float32 데이터
            audio = np.frombuffer(audio_bytes, dtype=np.float32)
        
        # 오디오 길이 확인
        if len(audio) == 0:
            return jsonify({'error': 'Empty audio data'}), 400
        
        # SPICE는 16kHz를 필요로 함
        if sample_rate != 16000:
            audio = resampy.resample(audio, sample_rate, 16000)
            sample_rate = 16000
        
        # 정규화
        max_val = np.max(np.abs(audio))
        if max_val > 0:
            audio = audio / max_val
        
        # TensorFlow 텐서로 변환
        audio_tensor = tf.constant(audio, dtype=tf.float32)
        
        # SPICE 모델 실행
        model_output = model.signatures["serving_default"](
            tf.expand_dims(audio_tensor, 0)
        )
        
        # 피치와 신뢰도 추출
        pitch_outputs = model_output["pitch"]
        uncertainty_outputs = model_output["uncertainty"]
        
        # 신뢰도 계산 (불확실성의 역)
        confidences = 1.0 - uncertainty_outputs[0]
        
        # Hz로 변환 (SPICE는 MIDI 피치를 출력)
        frequencies = []
        for pitch in pitch_outputs[0]:
            if pitch > 0:
                freq = C0 * np.power(2, pitch / 12)
            else:
                freq = 0
            frequencies.append(freq)
        
        frequencies = np.array(frequencies)
        confidences = np.array(confidences)
        
        # 유효한 피치만 필터링 (신뢰도 > 0.5)
        valid_indices = confidences > 0.5
        frequencies = frequencies[valid_indices]
        confidences = confidences[valid_indices]
        
        # 타임스탬프 생성 (32ms 간격)
        time_step = 0.032  # SPICE의 기본 프레임 간격
        timestamps = np.arange(len(frequencies)) * time_step
        
        # 음계로 양자화
        quantized_freqs, note_names = quantize_predictions(frequencies, confidences)
        
        # 통계 계산
        statistics = {}
        if len(frequencies) > 0:
            valid_freqs = frequencies[frequencies > 0]
            if len(valid_freqs) > 0:
                statistics = {
                    'mean_pitch': float(np.mean(valid_freqs)),
                    'std_pitch': float(np.std(valid_freqs)),
                    'min_pitch': float(np.min(valid_freqs)),
                    'max_pitch': float(np.max(valid_freqs)),
                    'mean_confidence': float(np.mean(confidences)),
                    'pitch_range': float(np.max(valid_freqs) - np.min(valid_freqs)),
                    'num_frames': len(frequencies),
                    'total_duration': float(len(audio) / sample_rate)
                }
        
        # 결과 반환
        return jsonify({
            'pitches': frequencies.tolist(),
            'confidences': confidences.tolist(),
            'quantized_pitches': quantized_freqs,
            'notes': note_names,
            'timestamps': timestamps.tolist(),
            'statistics': statistics,
            'sample_rate': 16000,
            'model': 'SPICE-v2',
            'frame_step_ms': 32
        })
        
    except Exception as e:
        import traceback
        return jsonify({
            'error': str(e),
            'traceback': traceback.format_exc()
        }), 500

@app.route('/analyze_polyphonic', methods=['POST'])
def analyze_polyphonic():
    """
    다성 음악 분석 (실험적)
    여러 음정을 동시에 감지 시도
    """
    try:
        data = request.json
        audio_base64 = data.get('audio_base64', '')
        sample_rate = data.get('sample_rate', 44100)
        
        if not audio_base64:
            return jsonify({'error': 'No audio data provided'}), 400
        
        # 오디오 디코딩 (동일한 로직)
        audio_bytes = base64.b64decode(audio_base64)
        
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
                        # 스테레오 채널 분리 (다성 분석용)
                        audio_stereo = audio.reshape(-1, 2)
                        audio_left = audio_stereo[:, 0]
                        audio_right = audio_stereo[:, 1]
                    else:
                        audio_left = audio
                        audio_right = audio
                    
                    sample_rate = framerate
        else:
            audio = np.frombuffer(audio_bytes, dtype=np.float32)
            audio_left = audio
            audio_right = audio
        
        # 각 채널 리샘플링
        if sample_rate != 16000:
            audio_left = resampy.resample(audio_left, sample_rate, 16000)
            audio_right = resampy.resample(audio_right, sample_rate, 16000)
            sample_rate = 16000
        
        # 각 채널 분석
        results_left = analyze_channel(audio_left)
        results_right = analyze_channel(audio_right)
        
        # 결과 병합
        all_pitches = []
        all_notes = []
        
        for i in range(min(len(results_left['pitches']), len(results_right['pitches']))):
            pitch_left = results_left['pitches'][i]
            pitch_right = results_right['pitches'][i]
            
            pitches_frame = []
            notes_frame = []
            
            if pitch_left > 0:
                pitches_frame.append(pitch_left)
                notes_frame.append(results_left['notes'][i])
            
            if pitch_right > 0 and abs(pitch_right - pitch_left) > 20:  # 20Hz 이상 차이
                pitches_frame.append(pitch_right)
                notes_frame.append(results_right['notes'][i])
            
            all_pitches.append(pitches_frame)
            all_notes.append(notes_frame)
        
        return jsonify({
            'polyphonic_pitches': all_pitches,
            'polyphonic_notes': all_notes,
            'left_channel': results_left,
            'right_channel': results_right,
            'model': 'SPICE-v2-polyphonic'
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def analyze_channel(audio):
    """단일 채널 분석 헬퍼 함수"""
    # 정규화
    max_val = np.max(np.abs(audio))
    if max_val > 0:
        audio = audio / max_val
    
    # SPICE 모델 실행
    audio_tensor = tf.constant(audio, dtype=tf.float32)
    model_output = model.signatures["serving_default"](
        tf.expand_dims(audio_tensor, 0)
    )
    
    pitch_outputs = model_output["pitch"]
    uncertainty_outputs = model_output["uncertainty"]
    confidences = 1.0 - uncertainty_outputs[0]
    
    # Hz로 변환
    frequencies = []
    for pitch in pitch_outputs[0]:
        if pitch > 0:
            freq = C0 * np.power(2, pitch / 12)
        else:
            freq = 0
        frequencies.append(freq)
    
    # 음계 양자화
    quantized_freqs, note_names = quantize_predictions(frequencies, confidences)
    
    return {
        'pitches': frequencies,
        'notes': note_names,
        'confidences': confidences.numpy().tolist()
    }

if __name__ == '__main__':
    print("=" * 50)
    print("🎵 SPICE Server - Self-supervised 피치 분석")
    print("=" * 50)
    print("포트: 5003")
    print("모델: SPICE v2 (Google Research)")
    print("특징: 자가 학습, 음계 양자화")
    print("=" * 50)
    print("엔드포인트:")
    print("  GET  /health              - 서버 상태")
    print("  POST /analyze             - 단성 피치 분석")
    print("  POST /analyze_polyphonic  - 다성 분석 (실험적)")
    print("=" * 50)
    
    app.run(host='0.0.0.0', port=5003, debug=False)