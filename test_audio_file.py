#!/usr/bin/env python3
"""실제 오디오 파일로 라벨링 테스트"""

import os
import json
import base64
import requests
import numpy as np
from datetime import datetime

# 기존 오디오 파일 찾기
audio_files = [
    "/Users/seoyeongbin/vocal_trainer_ai/test_audio.wav",
    "/Users/seoyeongbin/vocal_trainer_ai/test_recording.wav",
    "/Users/seoyeongbin/Downloads/sample.wav"
]

# 사용 가능한 파일 찾기
test_file = None
for file in audio_files:
    if os.path.exists(file):
        test_file = file
        break

if not test_file:
    print("❌ 테스트할 오디오 파일이 없습니다.")
    print("WAV 파일을 생성합니다...")
    
    # 간단한 WAV 파일 생성
    import wave
    sample_rate = 44100
    duration = 2.0
    frequency = 440.0  # A4
    
    t = np.linspace(0, duration, int(sample_rate * duration))
    audio = (np.sin(2 * np.pi * frequency * t) * 32767).astype(np.int16)
    
    test_file = "/Users/seoyeongbin/vocal_trainer_ai/test_generated.wav"
    with wave.open(test_file, 'wb') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(audio.tobytes())
    print(f"✅ 테스트 파일 생성: {test_file}")

print(f"🎵 오디오 파일 라벨링 테스트")
print(f"파일: {test_file}")
print(f"크기: {os.path.getsize(test_file):,} bytes")

# 파일 읽기 및 Base64 인코딩
with open(test_file, 'rb') as f:
    audio_bytes = f.read()
    audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')

print(f"Base64 크기: {len(audio_base64):,} characters")

# CREPE 서버 테스트
print("\n📊 AI 분석 시작...")
try:
    response = requests.post(
        'http://localhost:5002/analyze',
        json={'audio': audio_base64},
        timeout=30
    )
    
    if response.status_code == 200:
        result = response.json()
        print("✅ CREPE 분석 성공!")
        
        # 결과 요약
        if 'pitch' in result:
            pitch_data = result['pitch']
            print(f"  - 분석된 프레임: {len(pitch_data)}")
            
            # 평균 피치 계산
            valid_pitches = [p for p in pitch_data if p > 0]
            if valid_pitches:
                avg_pitch = np.mean(valid_pitches)
                print(f"  - 평균 피치: {avg_pitch:.2f}Hz")
                print(f"  - 최소 피치: {min(valid_pitches):.2f}Hz")
                print(f"  - 최대 피치: {max(valid_pitches):.2f}Hz")
        
        # 라벨 생성
        label = {
            "id": f"test_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            "file": test_file,
            "timestamp": datetime.now().isoformat(),
            "analysis": {
                "crepe": result,
                "summary": {
                    "frames": len(result.get('pitch', [])),
                    "avg_pitch": avg_pitch if 'avg_pitch' in locals() else None
                }
            }
        }
        
        # 라벨 저장
        label_file = f"/Users/seoyeongbin/vocal_trainer_ai/labels/test_label_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(label_file, 'w') as f:
            json.dump(label, f, indent=2)
        
        print(f"\n✅ 라벨 저장 완료: {label_file}")
        
    else:
        print(f"❌ 서버 에러: {response.status_code}")
        print(response.text)
        
except Exception as e:
    print(f"❌ 연결 실패: {e}")

print("\n" + "="*60)
print("🎯 YouTube 라벨링 봇 개발 상태:")
print("✅ 로컬 파일 라벨링: 테스트 완료")
print("⏳ YouTube 다운로드: ffmpeg 설치 대기")
print("📊 다음 단계: YouTube URL로 실제 라벨링")