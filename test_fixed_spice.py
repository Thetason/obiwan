#!/usr/bin/env python3
"""
수정된 SPICE 서버 테스트 - 주파수 보정 확인
"""
import requests
import numpy as np
import base64
import json

def generate_sine_wave(frequency, duration=1.0, sample_rate=48000):
    """지정된 주파수의 사인파 생성"""
    t = np.linspace(0, duration, int(sample_rate * duration), False)
    # 0.5 진폭의 사인파 생성
    sine_wave = 0.5 * np.sin(2 * np.pi * frequency * t)
    return sine_wave.astype(np.float32)

def encode_audio_to_base64(audio_data):
    """Float32 오디오를 Base64로 인코딩"""
    byte_data = audio_data.tobytes()
    return base64.b64encode(byte_data).decode('utf-8')

def test_spice_with_correction(freq):
    """SPICE 테스트 및 주파수 보정 적용"""
    print(f"\n🎵 테스트 주파수: {freq} Hz")
    
    # 1초 사인파 생성
    audio = generate_sine_wave(freq, duration=1.0)
    print(f"📊 생성된 오디오: {len(audio)} 샘플, max={np.max(np.abs(audio)):.4f}")
    
    # Base64 인코딩
    audio_b64 = encode_audio_to_base64(audio)
    
    try:
        response = requests.post('http://localhost:5003/analyze', 
                               json={
                                   'audio_base64': audio_b64,
                                   'encoding': 'base64_float32',
                                   'sample_rate': 48000
                               },
                               timeout=10)
        
        if response.status_code == 200:
            result = response.json()
            
            if result.get('success') and result.get('data', {}).get('frequencies'):
                data = result['data']
                frequencies = data['frequencies']
                confidences = data.get('confidence', [])
                
                if frequencies and confidences:
                    # 가장 높은 신뢰도의 주파수 선택
                    best_idx = confidences.index(max(confidences))
                    raw_freq = frequencies[best_idx]
                    
                    # 주파수 보정 (샘플레이트 불일치 수정)
                    correction_factor = 48000.0 / 16000.0  # 3.0
                    corrected_freq = raw_freq * correction_factor
                    
                    print(f"🔧 원본 주파수: {raw_freq:.1f} Hz")
                    print(f"✅ 보정된 주파수: {corrected_freq:.1f} Hz")
                    print(f"📊 신뢰도: {confidences[best_idx]:.3f}")
                    print(f"❌ 오차: {abs(corrected_freq - freq):.1f} Hz ({abs(corrected_freq - freq)/freq*100:.1f}%)")
                    
                    return corrected_freq
                else:
                    print("❌ 주파수나 신뢰도 데이터가 없음")
            else:
                print(f"❌ SPICE 실패: {result.get('error', '알 수 없는 오류')}")
        else:
            print(f"❌ HTTP 오류: {response.status_code}")
    except Exception as e:
        print(f"❌ 요청 실패: {e}")
    
    return None

def main():
    print("🧪 수정된 SPICE 서버 테스트 (주파수 보정 포함)")
    print("=" * 60)
    
    # 잘 알려진 주파수들로 테스트
    test_frequencies = [
        220.0,   # A3
        440.0,   # A4 (기준음)
        523.25,  # C5 (도)
        659.25,  # E5 (미)
        880.0,   # A5
    ]
    
    results = {}
    
    for freq in test_frequencies:
        detected = test_spice_with_correction(freq)
        results[freq] = detected
    
    print("\n" + "=" * 60)
    print("📋 테스트 결과 요약 (보정 후):")
    print("=" * 60)
    
    for original, detected in results.items():
        if detected:
            error = abs(detected - original)
            error_pct = error / original * 100
            status = "✅ 정확" if error < 10 else "⚠️ 부정확" if error < 50 else "❌ 매우 부정확"
            print(f"{original:6.1f} Hz → {detected:6.1f} Hz | 오차: {error:5.1f} Hz ({error_pct:4.1f}%) {status}")
        else:
            print(f"{original:6.1f} Hz → 감지 실패 ❌")

if __name__ == "__main__":
    main()