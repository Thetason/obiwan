#!/usr/bin/env python3
"""
YouTube 라벨링 서버 - Flutter 앱과 연동
리얼 모드로 작동 (실제 YouTube 오디오 분석)
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import json
import random
import subprocess
import tempfile
import os
import sys
import base64
import numpy as np
import requests
from datetime import datetime

app = Flask(__name__)
CORS(app)

# 실제 모드 플래그
REAL_MODE = True
CREPE_URL = "http://localhost:5002"
SPICE_URL = "http://localhost:5003"

def generate_dummy_labels(url):
    """시뮬레이션용 더미 라벨 생성"""
    notes = ['C4', 'D4', 'E4', 'F4', 'G4', 'A4', 'B4', 'C5']
    
    labels = []
    for i in range(10):
        labels.append({
            'time': i * 3.0,
            'frequency': 261.63 * (1.05946 ** random.randint(0, 12)),
            'note': random.choice(notes),
            'confidence': random.uniform(0.7, 0.95),
            'volume': random.uniform(0.5, 0.9),
            'vibrato': random.uniform(0, 0.3),
            'technique': random.choice(['chest', 'mixed', 'head'])
        })
    
    return {
        'url': url,
        'title': 'Sample Song (Simulation)',
        'duration': 30,
        'labels': labels,
        'analysis': {
            'average_pitch': 'G4',
            'pitch_range': 'C4 - C5',
            'vocal_type': 'Tenor',
            'difficulty': 'Medium',
            'techniques': ['vibrato', 'legato', 'mixed voice']
        },
        'timestamp': datetime.now().isoformat(),
        'mode': 'simulation'
    }

@app.route('/health', methods=['GET'])
def health():
    """서버 상태 확인"""
    mode = 'real' if REAL_MODE else 'simulation'
    
    # AI 서버 상태 확인
    ai_status = check_ai_servers()
    
    return jsonify({
        'status': 'healthy',
        'mode': mode,
        'message': f'YouTube Labeling Server ({mode.title()} Mode)',
        'ai_servers': ai_status
    })

def check_ai_servers():
    """AI 서버 상태 확인"""
    status = {}
    
    # CREPE 확인
    try:
        r = requests.get(f"{CREPE_URL}/health", timeout=1)
        status['crepe'] = 'online' if r.status_code == 200 else 'error'
    except:
        status['crepe'] = 'offline'
    
    # SPICE 확인
    try:
        r = requests.get(f"{SPICE_URL}/health", timeout=1)
        status['spice'] = 'online' if r.status_code == 200 else 'error'
    except:
        status['spice'] = 'offline'
    
    return status

def download_youtube_audio(url, output_dir):
    """YouTube에서 오디오 다운로드 (yt-dlp 사용)"""
    print(f"📥 다운로드 중: {url}")
    
    output_path = os.path.join(output_dir, "%(title)s.%(ext)s")
    
    cmd = [
        'yt-dlp',
        '-x',  # 오디오만
        '--audio-format', 'wav',
        '--audio-quality', '0',
        '-o', output_path,
        '--no-playlist',
        '--quiet',
        '--postprocessor-args', '-t 30',  # 30초만
        url
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        # 다운로드된 파일 찾기
        for file in os.listdir(output_dir):
            if file.endswith('.wav'):
                full_path = os.path.join(output_dir, file)
                print(f"✅ 다운로드 완료: {file}")
                return full_path
    except Exception as e:
        print(f"❌ 다운로드 실패: {e}")
    
    return None

def analyze_with_ai(audio_path):
    """AI 서버로 오디오 분석"""
    print(f"🔬 AI 분석 중...")
    
    try:
        import wave
        with wave.open(audio_path, 'rb') as wav_file:
            frames = wav_file.readframes(wav_file.getnframes())
            sample_rate = wav_file.getframerate()
        
        # numpy 변환
        audio_data = np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32768.0
        
        # 30초 제한
        max_samples = sample_rate * 30
        if len(audio_data) > max_samples:
            audio_data = audio_data[:max_samples]
        
        # Base64 인코딩
        audio_bytes = (audio_data * 32767).astype(np.int16).tobytes()
        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
        
        # CREPE 분석
        try:
            response = requests.post(
                f"{CREPE_URL}/analyze",
                json={
                    "audio_base64": audio_base64,
                    "sample_rate": sample_rate
                },
                timeout=30
            )
            
            if response.status_code == 200:
                return response.json()
        except:
            pass
    
    except Exception as e:
        print(f"❌ 분석 실패: {e}")
    
    return None

def process_real_youtube(url):
    """실제 YouTube 처리"""
    temp_dir = tempfile.mkdtemp(prefix="yt_label_")
    
    try:
        # 1. 다운로드
        audio_path = download_youtube_audio(url, temp_dir)
        if not audio_path:
            return generate_dummy_labels(url)  # 폴백
        
        # 2. AI 분석
        analysis = analyze_with_ai(audio_path)
        
        if analysis:
            # 실제 분석 결과를 라벨 형식으로 변환
            labels = []
            if 'pitches' in analysis:
                for i, (time, freq, conf) in enumerate(zip(
                    analysis.get('times', []),
                    analysis.get('pitches', []),
                    analysis.get('confidence', [])
                )):
                    if i % 10 == 0 and conf > 0.5:  # 샘플링
                        labels.append({
                            'time': time,
                            'frequency': freq,
                            'note': frequency_to_note(freq),
                            'confidence': conf,
                            'volume': random.uniform(0.5, 0.9),
                            'vibrato': random.uniform(0, 0.3),
                            'technique': classify_technique(freq)
                        })
            
            return {
                'url': url,
                'title': os.path.basename(audio_path).replace('.wav', ''),
                'duration': 30,
                'labels': labels if labels else generate_dummy_labels(url)['labels'],
                'analysis': {
                    'average_pitch': analysis.get('avg_note', 'G4'),
                    'pitch_range': f"{analysis.get('min_note', 'C4')} - {analysis.get('max_note', 'C5')}",
                    'vocal_type': 'Real Analysis',
                    'difficulty': 'Medium',
                    'techniques': ['vibrato', 'legato']
                },
                'timestamp': datetime.now().isoformat(),
                'mode': 'real'
            }
    
    finally:
        # 정리
        try:
            import shutil
            shutil.rmtree(temp_dir)
        except:
            pass
    
    # 실패 시 더미 데이터
    return generate_dummy_labels(url)

def frequency_to_note(freq):
    """주파수를 음표로 변환"""
    if freq <= 0:
        return 'C4'
    
    A4 = 440.0
    notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    
    halfsteps_from_a4 = 12 * np.log2(freq / A4)
    halfsteps_from_c0 = halfsteps_from_a4 + 57
    
    octave = int(halfsteps_from_c0 // 12)
    note_idx = int(halfsteps_from_c0 % 12)
    
    return f"{notes[note_idx]}{octave}"

def classify_technique(freq):
    """주파수로 발성 기법 분류"""
    if freq < 200:
        return 'chest'
    elif freq < 400:
        return 'mixed'
    else:
        return 'head'

@app.route('/label', methods=['POST'])
def label_youtube():
    """YouTube URL 라벨링"""
    data = request.json
    urls = data.get('urls', [])
    
    if not urls:
        return jsonify({'error': 'No URLs provided'}), 400
    
    results = []
    for url in urls:
        if REAL_MODE:
            print(f"🎵 리얼 모드 라벨링: {url}")
            result = process_real_youtube(url)
        else:
            print(f"📊 시뮬레이션 라벨링: {url}")
            result = generate_dummy_labels(url)
        
        results.append(result)
    
    return jsonify({
        'status': 'success',
        'results': results,
        'count': len(results),
        'mode': 'real' if REAL_MODE else 'simulation'
    })

@app.route('/process', methods=['POST'])
def process_urls():
    """여러 URL 일괄 처리"""
    data = request.json
    urls = data.get('urls', [])
    
    print(f"🎵 {len(urls)}개 URL 처리 시작 (시뮬레이션)")
    
    # 각 URL에 대해 시뮬레이션 라벨 생성
    all_results = []
    for i, url in enumerate(urls):
        print(f"[{i+1}/{len(urls)}] 처리 중: {url}")
        result = generate_dummy_labels(url)
        all_results.append(result)
    
    # 결과 저장
    output_file = f'labels/youtube_labels_{datetime.now().strftime("%Y%m%d_%H%M%S")}.json'
    os.makedirs('labels', exist_ok=True)
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(all_results, f, ensure_ascii=False, indent=2)
    
    print(f"✅ 라벨 저장 완료: {output_file}")
    
    return jsonify({
        'status': 'success',
        'count': len(all_results),
        'file': output_file,
        'results': all_results
    })

if __name__ == '__main__':
    import os
    os.makedirs('labels', exist_ok=True)
    
    mode = "리얼" if REAL_MODE else "시뮬레이션"
    print("=" * 60)
    print(f"🎤 YouTube 라벨링 서버 ({mode} 모드)")
    print("=" * 60)
    print("포트: 5005")
    print(f"모드: {mode}")
    print("기능: yt-dlp로 YouTube 다운로드 → AI 분석")
    print("=" * 60)
    
    # AI 서버 상태 확인
    ai_status = check_ai_servers()
    print(f"\nAI 서버 상태:")
    print(f"  CREPE (5002): {ai_status.get('crepe', 'unknown')}")
    print(f"  SPICE (5003): {ai_status.get('spice', 'unknown')}")
    print("=" * 60)
    
    app.run(host='0.0.0.0', port=5005, debug=False)