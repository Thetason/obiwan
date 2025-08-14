#!/usr/bin/env python3
"""
다양한 음정으로 CREPE 서버 테스트 - G3만 되는 게 아님을 증명
"""
import requests
import numpy as np
import base64

def test_multiple_notes():
    """여러 음정 테스트"""
    print("🎵 CREPE 서버 - 다양한 음정 테스트")
    print("=" * 50)
    
    # 다양한 음정들 (Hz, 음표명)
    test_notes = [
        (130.8, "C3"),   # 도
        (146.8, "D3"),   # 레  
        (164.8, "E3"),   # 미
        (174.6, "F3"),   # 파
        (196.0, "G3"),   # 솔
        (220.0, "A3"),   # 라
        (246.9, "B3"),   # 시
        (261.6, "C4"),   # 높은 도
        (293.7, "D4"),   # 높은 레
        (329.6, "E4"),   # 높은 미
        (349.2, "F4"),   # 높은 파
        (392.0, "G4"),   # 높은 솔
        (440.0, "A4"),   # 표준 라
        (493.9, "B4"),   # 높은 시
        (523.3, "C5"),   # 더 높은 도
    ]
    
    for freq, note_name in test_notes:
        print(f"\n🎼 테스트: {note_name} ({freq} Hz)")
        
        # 사인파 생성
        duration = 1.0
        sample_rate = 48000
        t = np.linspace(0, duration, int(sample_rate * duration), False)
        audio = 0.5 * np.sin(2 * np.pi * freq * t)
        
        # Base64 인코딩
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
                    # 가장 높은 신뢰도 찾기
                    max_conf_idx = np.argmax(confidences)
                    detected = frequencies[max_conf_idx]
                    conf = confidences[max_conf_idx]
                    
                    detected_note = frequency_to_note(detected)
                    error = abs(detected - freq)
                    
                    status = "✅" if error < 10 else "❌"
                    print(f"  {status} {freq} Hz ({note_name}) → {detected:.1f} Hz ({detected_note})")
                    print(f"     신뢰도: {conf:.3f}, 오차: {error:.1f}Hz")
                    
        except Exception as e:
            print(f"  ❌ 오류: {e}")

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

if __name__ == "__main__":
    test_multiple_notes()