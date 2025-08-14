#!/usr/bin/env python3
"""
사람 목소리와 비슷한 복합 신호로 CREPE 테스트
"""
import requests
import numpy as np
import base64

def generate_voice_like_signal(fundamental_freq, duration=1.0, sample_rate=48000):
    """사람 목소리와 비슷한 복합 신호 생성 (기본 주파수 + 배음들)"""
    t = np.linspace(0, duration, int(sample_rate * duration), False)
    
    # 기본 주파수 (가장 강함)
    signal = 0.6 * np.sin(2 * np.pi * fundamental_freq * t)
    
    # 2차 배음 (절반 강도)
    signal += 0.3 * np.sin(2 * np.pi * fundamental_freq * 2 * t)
    
    # 3차 배음 (1/3 강도)
    signal += 0.2 * np.sin(2 * np.pi * fundamental_freq * 3 * t)
    
    # 4차 배음 (1/4 강도)
    signal += 0.15 * np.sin(2 * np.pi * fundamental_freq * 4 * t)
    
    # 약간의 노이즈 추가 (실제 목소리처럼)
    noise = 0.05 * np.random.randn(len(signal))
    signal += noise
    
    # 정규화
    max_val = np.max(np.abs(signal))
    if max_val > 0:
        signal = signal / max_val * 0.5
    
    return signal.astype(np.float32)

def test_voice_signal(fundamental_freq):
    """목소리 같은 신호로 테스트"""
    print(f"\n🎤 기본 주파수: {fundamental_freq} Hz (목소리 시뮬레이션)")
    
    # 복합 신호 생성
    audio = generate_voice_like_signal(fundamental_freq, duration=1.0)
    print(f"📊 생성된 복합 신호: {len(audio)} 샘플, max={np.max(np.abs(audio)):.4f}")
    
    # Base64 인코딩
    byte_data = audio.tobytes()
    audio_b64 = base64.b64encode(byte_data).decode('utf-8')
    
    try:
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
                
                print(f"✅ CREPE 응답: {len(frequencies)}개 결과")
                
                # 신뢰도 높은 순으로 정렬
                freq_conf_pairs = list(zip(frequencies, confidences))
                freq_conf_pairs.sort(key=lambda x: x[1], reverse=True)
                
                print("🎯 신뢰도 높은 순 주파수:")
                for i, (freq, conf) in enumerate(freq_conf_pairs[:10]):  # 상위 10개
                    is_fundamental = abs(freq - fundamental_freq) < 20
                    is_harmonic = False
                    harmonic_num = 0
                    
                    # 배음 확인
                    for h in range(2, 6):
                        if abs(freq - fundamental_freq * h) < 20:
                            is_harmonic = True
                            harmonic_num = h
                            break
                    
                    marker = "🎯" if is_fundamental else f"🔗{harmonic_num}" if is_harmonic else "❓"
                    print(f"  {i+1:2d}. {freq:6.1f} Hz (신뢰도: {conf:.3f}) {marker}")
                
                # Flutter 앱처럼 가장 높은 신뢰도만 선택
                flutter_choice = freq_conf_pairs[0]
                print(f"\n📱 Flutter 앱 선택: {flutter_choice[0]:.1f} Hz (신뢰도: {flutter_choice[1]:.3f})")
                
                # 기본 주파수와의 차이 계산
                error = abs(flutter_choice[0] - fundamental_freq)
                error_pct = error / fundamental_freq * 100
                
                if error < 10:
                    status = "✅ 정확"
                elif abs(flutter_choice[0] - fundamental_freq * 2) < 20:
                    status = "⚠️ 2배음 (옥타브 위)"
                elif abs(flutter_choice[0] - fundamental_freq * 3) < 20:
                    status = "⚠️ 3배음"
                elif abs(flutter_choice[0] - fundamental_freq * 4) < 20:
                    status = "⚠️ 4배음"
                else:
                    status = "❌ 완전 다름"
                
                print(f"🎵 결과: 기본주파수 {fundamental_freq} Hz vs 감지 {flutter_choice[0]:.1f} Hz")
                print(f"📊 오차: {error:.1f} Hz ({error_pct:.1f}%) {status}")
                
                return flutter_choice[0]
        
    except Exception as e:
        print(f"❌ 오류: {e}")
    
    return None

def main():
    print("🧪 목소리 시뮬레이션 테스트")
    print("=" * 60)
    
    # 일반적인 사람 목소리 주파수들
    voice_frequencies = [
        220.0,   # 남성 저음 (A3)
        330.0,   # 남성 중음 (E4)
        440.0,   # 여성 중음 (A4)
        523.25,  # 여성 고음 (C5)
    ]
    
    results = {}
    
    for freq in voice_frequencies:
        detected = test_voice_signal(freq)
        results[freq] = detected
    
    print("\n" + "=" * 60)
    print("📋 목소리 시뮬레이션 테스트 결과:")
    print("=" * 60)
    
    for original, detected in results.items():
        if detected:
            error = abs(detected - original)
            
            # 배음 확인
            is_harmonic = False
            harmonic_info = ""
            for h in range(2, 6):
                if abs(detected - original * h) < 20:
                    is_harmonic = True
                    harmonic_info = f" (🔗{h}배음)"
                    break
            
            if error < 10:
                status = "✅ 정확"
            elif is_harmonic:
                status = f"⚠️ 배음 감지{harmonic_info}"
            else:
                status = "❌ 부정확"
                
            print(f"{original:6.1f} Hz → {detected:6.1f} Hz | {status}")
        else:
            print(f"{original:6.1f} Hz → 감지 실패 ❌")
    
    print("\n💡 결론:")
    print("Flutter 앱이 '가장 높은 신뢰도' 주파수만 선택하면")
    print("배음(harmonic)을 기본 주파수로 잘못 인식할 수 있습니다!")

if __name__ == "__main__":
    main()