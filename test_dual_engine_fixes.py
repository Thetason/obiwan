#!/usr/bin/env python3
"""
통합 테스트 - CREPE + SPICE 수정 사항 검증
"""
import requests
import numpy as np
import base64
import json
import concurrent.futures

def generate_sine_wave(frequency, duration=1.0, sample_rate=48000):
    """지정된 주파수의 사인파 생성"""
    t = np.linspace(0, duration, int(sample_rate * duration), False)
    sine_wave = 0.5 * np.sin(2 * np.pi * frequency * t)
    return sine_wave.astype(np.float32)

def encode_audio_to_base64(audio_data):
    """Float32 오디오를 Base64로 인코딩"""
    byte_data = audio_data.tobytes()
    return base64.b64encode(byte_data).decode('utf-8')

def test_crepe(freq):
    """CREPE 서버 테스트"""
    try:
        audio = generate_sine_wave(freq, duration=1.0)
        audio_b64 = encode_audio_to_base64(audio)
        
        response = requests.post('http://localhost:5002/analyze', 
                               json={
                                   'audio_base64': audio_b64,
                                   'sample_rate': 48000
                               },
                               timeout=10)
        
        if response.status_code == 200:
            result = response.json()
            if 'frequencies' in result and result['frequencies']:
                frequencies = result['frequencies']
                confidences = result.get('confidence', [])
                
                if frequencies and confidences:
                    # 가장 높은 신뢰도의 주파수 선택
                    best_idx = confidences.index(max(confidences))
                    detected_freq = frequencies[best_idx]
                    confidence = confidences[best_idx]
                    
                    return {
                        'engine': 'CREPE',
                        'detected': detected_freq,
                        'confidence': confidence,
                        'error': abs(detected_freq - freq),
                        'error_pct': abs(detected_freq - freq) / freq * 100
                    }
    except Exception as e:
        print(f"❌ CREPE 오류: {e}")
    
    return None

def test_spice(freq):
    """SPICE 서버 테스트 (보정 적용)"""
    try:
        audio = generate_sine_wave(freq, duration=1.0)
        audio_b64 = encode_audio_to_base64(audio)
        
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
                    
                    # 주파수 보정 적용
                    correction_factor = 2.64  # Dart 서비스와 동일한 값
                    corrected_freq = raw_freq * correction_factor
                    confidence = confidences[best_idx]
                    
                    return {
                        'engine': 'SPICE',
                        'detected': corrected_freq,
                        'confidence': confidence,
                        'error': abs(corrected_freq - freq),
                        'error_pct': abs(corrected_freq - freq) / freq * 100
                    }
    except Exception as e:
        print(f"❌ SPICE 오류: {e}")
    
    return None

def test_dual_analysis(freq):
    """CREPE + SPICE 병렬 테스트"""
    print(f"\n🎵 테스트 주파수: {freq} Hz")
    
    # 병렬로 CREPE와 SPICE 테스트
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        crepe_future = executor.submit(test_crepe, freq)
        spice_future = executor.submit(test_spice, freq)
        
        crepe_result = crepe_future.result()
        spice_result = spice_future.result()
    
    # 결과 출력
    if crepe_result:
        print(f"✅ CREPE: {crepe_result['detected']:.1f} Hz (오차: {crepe_result['error']:.1f} Hz, {crepe_result['error_pct']:.1f}%)")
    else:
        print("❌ CREPE: 분석 실패")
    
    if spice_result:
        print(f"✅ SPICE: {spice_result['detected']:.1f} Hz (오차: {spice_result['error']:.1f} Hz, {spice_result['error_pct']:.1f}%)")
    else:
        print("❌ SPICE: 분석 실패")
    
    return crepe_result, spice_result

def generate_noisy_audio(frequency, noise_level=0.1):
    """노이즈가 포함된 오디오 생성"""
    clean_audio = generate_sine_wave(frequency, duration=1.0)
    noise = np.random.normal(0, noise_level, clean_audio.shape).astype(np.float32)
    return clean_audio + noise

def test_noise_handling():
    """노이즈 처리 테스트"""
    print(f"\n🔊 노이즈 처리 테스트")
    print("-" * 30)
    
    test_freq = 440.0
    noise_levels = [0.0, 0.05, 0.1, 0.2, 0.3]
    
    for noise_level in noise_levels:
        print(f"\n📏 노이즈 레벨: {noise_level}")
        
        noisy_audio = generate_noisy_audio(test_freq, noise_level)
        audio_b64 = encode_audio_to_base64(noisy_audio)
        
        try:
            # CREPE 테스트
            response = requests.post('http://localhost:5002/analyze', 
                                   json={
                                       'audio_base64': audio_b64,
                                       'sample_rate': 48000
                                   },
                                   timeout=5)
            
            if response.status_code == 200:
                result = response.json()
                if result.get('frequencies'):
                    freqs = result['frequencies']
                    confs = result.get('confidence', [])
                    if freqs and confs:
                        best_idx = confs.index(max(confs))
                        detected = freqs[best_idx]
                        error = abs(detected - test_freq)
                        print(f"  CREPE: {detected:.1f} Hz (오차: {error:.1f} Hz)")
                    else:
                        print("  CREPE: 감지 실패")
                else:
                    print("  CREPE: 응답 없음")
            
        except Exception as e:
            print(f"  CREPE 오류: {e}")

def main():
    print("🧪 통합 테스트 - CREPE + SPICE 수정 사항 검증")
    print("=" * 60)
    
    # 기본 주파수 테스트
    test_frequencies = [
        220.0,   # A3
        440.0,   # A4 (기준음)
        523.25,  # C5 (도)
        659.25,  # E5 (미)
        880.0,   # A5
    ]
    
    crepe_results = []
    spice_results = []
    
    for freq in test_frequencies:
        crepe_result, spice_result = test_dual_analysis(freq)
        crepe_results.append(crepe_result)
        spice_results.append(spice_result)
    
    # 노이즈 처리 테스트
    test_noise_handling()
    
    # 결과 요약
    print("\n" + "=" * 60)
    print("📋 테스트 결과 요약:")
    print("=" * 60)
    
    print("\nCREPE 결과:")
    for i, result in enumerate(crepe_results):
        freq = test_frequencies[i]
        if result:
            status = "✅ 정확" if result['error'] < 10 else "⚠️ 부정확" if result['error'] < 50 else "❌ 매우 부정확"
            print(f"{freq:6.1f} Hz → {result['detected']:6.1f} Hz | 오차: {result['error']:5.1f} Hz ({result['error_pct']:4.1f}%) {status}")
        else:
            print(f"{freq:6.1f} Hz → 감지 실패 ❌")
    
    print("\nSPICE 결과 (보정 후):")
    for i, result in enumerate(spice_results):
        freq = test_frequencies[i]
        if result:
            status = "✅ 정확" if result['error'] < 10 else "⚠️ 부정확" if result['error'] < 50 else "❌ 매우 부정확"
            print(f"{freq:6.1f} Hz → {result['detected']:6.1f} Hz | 오차: {result['error']:5.1f} Hz ({result['error_pct']:4.1f}%) {status}")
        else:
            print(f"{freq:6.1f} Hz → 감지 실패 ❌")

if __name__ == "__main__":
    main()