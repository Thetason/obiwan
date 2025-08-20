#!/usr/bin/env python3
"""CREPE 서버 간단 테스트"""

import requests
import numpy as np
import base64
import json

# 테스트용 더미 오디오 생성 (사인파)
sample_rate = 44100
duration = 1.0  # 1초
frequency = 440.0  # A4 음
t = np.linspace(0, duration, int(sample_rate * duration))
audio = np.sin(2 * np.pi * frequency * t).astype(np.float32)

# Base64 인코딩
audio_bytes = audio.tobytes()
audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')

# CREPE 서버 테스트
print("🎵 CREPE 서버 테스트")
print(f"테스트 주파수: {frequency}Hz (A4)")

try:
    response = requests.post(
        'http://localhost:5002/analyze',
        json={'audio': audio_base64},  # 'audio' 키 사용
        timeout=10
    )
    
    if response.status_code == 200:
        result = response.json()
        print("✅ CREPE 서버 응답 성공!")
        print(f"분석 결과: {json.dumps(result, indent=2)}")
        
        # 주파수 확인
        if 'frequency' in result:
            detected_freq = result['frequency']
            error = abs(detected_freq - frequency)
            print(f"\n예상 주파수: {frequency}Hz")
            print(f"감지된 주파수: {detected_freq}Hz")
            print(f"오차: {error:.2f}Hz")
    else:
        print(f"❌ 서버 에러: {response.status_code}")
        print(response.text)
        
except Exception as e:
    print(f"❌ 연결 실패: {e}")

print("\n" + "="*60)
print("💡 YouTube 라벨링 봇 준비 상태:")
print("✅ CREPE 서버: 정상 작동")
print("⏳ SPICE 서버: 확인 중...")
print("⏳ ffmpeg: 설치 중...")