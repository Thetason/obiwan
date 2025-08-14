#!/usr/bin/env python3
"""
G3 (196Hz) 테스트 - 사용자가 실제로 부른 음정 확인
"""
import requests
import numpy as np
import base64

def test_g3_recognition():
    """G3 (196Hz) 인식 테스트"""
    print("🎵 G3 (196Hz) 인식 테스트")
    print("=" * 40)
    
    # G3 사인파 생성
    frequency = 196.0  # G3
    duration = 1.0
    sample_rate = 48000
    
    t = np.linspace(0, duration, int(sample_rate * duration), False)
    audio = 0.5 * np.sin(2 * np.pi * frequency * t)
    
    print(f"🎼 생성된 G3 신호: {frequency} Hz")
    print(f"📊 오디오 길이: {len(audio)} 샘플")
    
    # Base64 인코딩
    byte_data = audio.astype(np.float32).tobytes()
    audio_b64 = base64.b64encode(byte_data).decode('utf-8')
    
    # CREPE 서버 테스트
    try:
        response = requests.post('http://localhost:5002/analyze', 
                               json={
                                   'audio_base64': audio_b64,
                                   'sample_rate': 48000
                               },
                               timeout=10)
        
        if response.status_code == 200:
            result = response.json()
            frequencies = result.get('frequencies', [])
            confidences = result.get('confidence', [])
            
            if frequencies and confidences:
                # 가장 높은 신뢰도 찾기 (Flutter 앱과 동일한 로직)
                max_conf_idx = np.argmax(confidences)
                detected_freq = frequencies[max_conf_idx]
                detected_conf = confidences[max_conf_idx]
                
                print(f"🎯 CREPE 감지: {detected_freq:.1f} Hz (신뢰도: {detected_conf:.3f})")
                
                # 음표 이름 계산
                note_name = frequency_to_note(detected_freq)
                print(f"🎵 감지된 음표: {note_name}")
                
                # 오차 계산
                error = abs(detected_freq - frequency)
                error_pct = error / frequency * 100
                
                print(f"📊 정확도:")
                print(f"  - 목표: {frequency} Hz (G3)")
                print(f"  - 감지: {detected_freq:.1f} Hz")
                print(f"  - 오차: {error:.1f} Hz ({error_pct:.1f}%)")
                
                # 옥타브 문제 확인
                if abs(detected_freq - frequency * 2) < 10:
                    print("⚠️  옥타브 위로 감지됨 (G4)")
                elif abs(detected_freq - frequency / 2) < 10:
                    print("⚠️  옥타브 아래로 감지됨 (G2)")
                elif error < 10:
                    print("✅ 정확하게 감지됨")
                else:
                    print("❌ 완전히 다른 음정 감지됨")
                
                return detected_freq
        else:
            print(f"❌ HTTP 오류: {response.status_code}")
            
    except Exception as e:
        print(f"❌ 테스트 실패: {e}")
    
    return None

def frequency_to_note(frequency):
    """주파수를 음표 이름으로 변환"""
    if frequency <= 0:
        return ''
    
    A4 = 440.0
    semitones = 12 * np.log2(frequency / A4)
    note_index = (int(semitones) + 9) % 12
    octave = 4 + (int(semitones) + 9) // 12
    
    notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    return f"{notes[note_index]}{octave}"

def test_multiple_octaves():
    """여러 옥타브의 G 음정 테스트"""
    print("\n🎼 여러 옥타브 G 음정 테스트")
    print("=" * 40)
    
    g_frequencies = [
        (98.0, "G2"),
        (196.0, "G3"), 
        (392.0, "G4"),
        (784.0, "G5")
    ]
    
    for freq, note in g_frequencies:
        print(f"\n🎵 테스트: {note} ({freq} Hz)")
        
        # 사인파 생성
        t = np.linspace(0, 1.0, 48000, False)
        audio = 0.5 * np.sin(2 * np.pi * freq * t)
        
        # CREPE 테스트
        byte_data = audio.astype(np.float32).tobytes()
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
                frequencies = result.get('frequencies', [])
                confidences = result.get('confidence', [])
                
                if frequencies and confidences:
                    max_conf_idx = np.argmax(confidences)
                    detected = frequencies[max_conf_idx]
                    conf = confidences[max_conf_idx]
                    
                    detected_note = frequency_to_note(detected)
                    error = abs(detected - freq)
                    
                    status = "✅" if error < 10 else "❌"
                    print(f"  {status} {freq} Hz → {detected:.1f} Hz ({detected_note}, 오차: {error:.1f}Hz)")
                    
        except Exception as e:
            print(f"  ❌ 오류: {e}")

if __name__ == "__main__":
    # G3 단독 테스트
    detected_g3 = test_g3_recognition()
    
    # 여러 옥타브 테스트
    test_multiple_octaves()
    
    print("\n" + "=" * 40)
    print("💡 결론:")
    if detected_g3:
        if abs(detected_g3 - 196) < 10:
            print("✅ G3 인식이 정확합니다")
        elif abs(detected_g3 - 392) < 10:
            print("⚠️  G3을 G4(한 옥타브 위)로 잘못 인식합니다")
        else:
            print("❌ G3 인식에 심각한 오류가 있습니다")
    else:
        print("❌ CREPE 서버 연결 실패")