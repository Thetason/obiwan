#!/usr/bin/env python3
"""
SPICE 서버 직접 테스트 - 알려진 주파수 사인파로 테스트
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

def test_spice_with_frequency(freq):
    """특정 주파수로 SPICE 테스트"""
    print(f"\n🎵 테스트 주파수: {freq} Hz")
    
    # 1초 사인파 생성
    audio = generate_sine_wave(freq, duration=1.0)
    print(f"📊 생성된 오디오: {len(audio)} 샘플, max={np.max(np.abs(audio)):.4f}")
    
    # Base64 인코딩
    audio_b64 = encode_audio_to_base64(audio)
    print(f"📦 Base64 크기: {len(audio_b64)} 바이트")
    
    # SPICE 서버로 전송 (새 형식 사용)
    try:
        response = requests.post('http://localhost:5003/analyze', 
                               json={
                                   'audio_base64': audio_b64,
                                   'encoding': 'base64_float32',
                                   'sample_rate': 48000
                               },
                               timeout=10)
        
        print(f"📡 응답 상태: {response.status_code}")
        print(f"📝 원본 응답: {response.text}")
        
        if response.status_code == 200:
            result = response.json()
            print(f"🔍 파싱된 결과: {result}")
            
            # SPICE 응답 구조 분석
            if 'success' in result and result['success']:
                data = result.get('data', {})
                if 'frequencies' in data and data['frequencies']:
                    detected_freqs = data['frequencies']
                    confidences = data.get('confidence', [])
                    
                    print(f"✅ SPICE 응답: {len(detected_freqs)}개 결과")
                    print(f"📈 감지된 주파수들: {detected_freqs[:5]}...")  # 처음 5개만
                    print(f"📊 신뢰도들: {confidences[:5] if confidences else 'N/A'}...")
                    
                    if detected_freqs:
                        # 0이 아닌 주파수들만 필터링
                        valid_freqs = [f for f in detected_freqs if f > 50]  # 50Hz 이상만
                        if valid_freqs:
                            avg_freq = np.mean(valid_freqs)
                            print(f"🎯 평균 주파수 (유효한 것만): {avg_freq:.1f} Hz")
                            print(f"❌ 오차: {abs(avg_freq - freq):.1f} Hz ({abs(avg_freq - freq)/freq*100:.1f}%)")
                            return avg_freq
                        else:
                            print("⚠️ 유효한 주파수가 없음 (모두 50Hz 미만)")
                            return None
                else:
                    print("❌ 주파수 데이터가 없음")
            else:
                print(f"❌ SPICE 실패: {result.get('error', '알 수 없는 오류')}")
        else:
            print(f"❌ HTTP 오류: {response.status_code}")
            print(f"응답 헤더: {dict(response.headers)}")
    except Exception as e:
        print(f"❌ 요청 실패: {e}")
    
    return None

def test_different_amplitudes(freq=440.0):
    """다양한 진폭으로 테스트 (SPICE 임계값 확인)"""
    print(f"\n🔊 진폭 테스트 (주파수: {freq} Hz)")
    print("-" * 30)
    
    amplitudes = [0.1, 0.3, 0.5, 0.7, 0.9]
    
    for amp in amplitudes:
        print(f"\n📏 진폭: {amp}")
        
        # 사인파 생성
        t = np.linspace(0, 1.0, 48000, False)
        audio = amp * np.sin(2 * np.pi * freq * t).astype(np.float32)
        
        # Base64 인코딩
        audio_b64 = encode_audio_to_base64(audio)
        
        try:
            response = requests.post('http://localhost:5003/analyze', 
                                   json={
                                       'audio_base64': audio_b64,
                                       'encoding': 'base64_float32',
                                       'sample_rate': 48000
                                   },
                                   timeout=5)
            
            if response.status_code == 200:
                result = response.json()
                if result.get('success') and result.get('data', {}).get('frequencies'):
                    freqs = result['data']['frequencies']
                    valid_freqs = [f for f in freqs if f > 50]
                    if valid_freqs:
                        avg_freq = np.mean(valid_freqs)
                        print(f"  ✅ 감지: {avg_freq:.1f} Hz")
                    else:
                        print(f"  ❌ 유효 주파수 없음 (raw: {freqs[:3]}...)")
                else:
                    print(f"  ❌ 실패: {result}")
            else:
                print(f"  ❌ HTTP 오류: {response.status_code}")
        except Exception as e:
            print(f"  ❌ 에러: {e}")

def main():
    print("🧪 SPICE 서버 정확도 테스트")
    print("=" * 50)
    
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
        detected = test_spice_with_frequency(freq)
        results[freq] = detected
    
    # 진폭 테스트
    test_different_amplitudes()
    
    print("\n" + "=" * 50)
    print("📋 테스트 결과 요약:")
    print("=" * 50)
    
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