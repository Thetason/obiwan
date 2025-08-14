#!/usr/bin/env python3
"""
바흐 평균율 기준 완전한 음정 시스템 테스트
C0부터 B8까지 108개 음정 전체 분석
"""
import requests
import numpy as np
import base64
import math

def generate_complete_frequency_table():
    """바흐 12평균율 기준 완전한 주파수 테이블 생성"""
    notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    table = {}
    
    # C4 = 261.63Hz 기준
    c4_freq = 261.6255653005986
    
    for octave in range(0, 9):  # C0 ~ B8
        for note_idx, note in enumerate(notes):
            # C4로부터의 반음 거리
            semitones_from_c4 = (octave - 4) * 12 + note_idx
            frequency = c4_freq * (2 ** (semitones_from_c4 / 12))
            
            full_name = f"{note}{octave}"
            table[full_name] = frequency
    
    return table

def test_bach_temperament_system():
    """바흐 평균율 시스템 전체 테스트"""
    print("🎼 바흐 평균율(Well-Tempered) 완전 분석 시스템")
    print("=" * 60)
    
    freq_table = generate_complete_frequency_table()
    
    # 주요 음정들 선별 테스트 (대표적인 24개)
    key_notes = [
        # 낮은 옥타브
        "C2", "D2", "E2", "F2", "G2", "A2", "B2",
        # 중간 옥타브 (성악 주요 음역)
        "C3", "D3", "E3", "F3", "G3", "A3", "B3",
        "C4", "D4", "E4", "F4", "G4", "A4", "B4",
        # 높은 옥타브
        "C5", "D5", "E5", "F5", "G5", "A5", "B5",
    ]
    
    print(f"🎵 주요 24개 음정 CREPE 분석 테스트")
    print("-" * 60)
    
    success_count = 0
    total_error = 0.0
    
    for note_name in key_notes:
        target_freq = freq_table[note_name]
        print(f"\n🎼 {note_name}: {target_freq:.1f} Hz")
        
        # 순수 사인파 생성
        duration = 1.0
        sample_rate = 48000
        t = np.linspace(0, duration, int(sample_rate * duration), False)
        
        # 실제 음성과 유사하게 하모닉 추가
        fundamental = 0.8 * np.sin(2 * np.pi * target_freq * t)
        harmonic2 = 0.2 * np.sin(2 * np.pi * target_freq * 2 * t)
        harmonic3 = 0.1 * np.sin(2 * np.pi * target_freq * 3 * t)
        
        audio = fundamental + harmonic2 + harmonic3
        
        # Base64 인코딩
        byte_data = audio.astype(np.float32).tobytes()
        audio_b64 = base64.b64encode(byte_data).decode('utf-8')
        
        try:
            response = requests.post('http://localhost:5002/analyze', 
                                   json={
                                       'audio_base64': audio_b64,
                                       'sample_rate': 48000
                                   },
                                   timeout=8)
            
            if response.status_code == 200:
                result = response.json()
                frequencies = result.get('frequencies', [])
                confidences = result.get('confidence', [])
                
                if frequencies and confidences:
                    # 최고 신뢰도 결과
                    max_conf_idx = np.argmax(confidences)
                    detected_freq = frequencies[max_conf_idx]
                    confidence = confidences[max_conf_idx]
                    
                    # 오차 계산
                    error_hz = abs(detected_freq - target_freq)
                    error_cents = 1200 * math.log2(detected_freq / target_freq) if target_freq > 0 else 0
                    
                    # 정확도 평가
                    if error_cents < 10:
                        status = "✅ 완벽"
                        accuracy = "PERFECT"
                    elif error_cents < 20:
                        status = "✅ 우수"
                        accuracy = "EXCELLENT"
                    elif error_cents < 50:
                        status = "⚡ 양호"
                        accuracy = "GOOD"
                    else:
                        status = "⚠️ 개선필요"
                        accuracy = "NEEDS_WORK"
                    
                    detected_note = frequency_to_note_name(detected_freq)
                    
                    print(f"   감지: {detected_freq:.1f} Hz ({detected_note})")
                    print(f"   오차: {error_hz:.1f} Hz ({error_cents:+.1f} 센트)")
                    print(f"   신뢰도: {confidence:.3f}")
                    print(f"   평가: {status} ({accuracy})")
                    
                    if error_hz < 10:  # 10Hz 이하는 성공
                        success_count += 1
                    
                    total_error += error_hz
                    
        except Exception as e:
            print(f"   ❌ 분석 실패: {e}")
    
    # 전체 결과 요약
    print("\n" + "=" * 60)
    print("📊 바흐 평균율 시스템 분석 결과")
    print("=" * 60)
    print(f"✅ 성공률: {success_count}/{len(key_notes)} ({success_count/len(key_notes)*100:.1f}%)")
    print(f"📈 평균 오차: {total_error/len(key_notes):.1f} Hz")
    
    if success_count >= len(key_notes) * 0.9:
        print("🏆 바흐 평균율 시스템 완벽 구현 성공!")
    elif success_count >= len(key_notes) * 0.8:
        print("🎉 바흐 평균율 시스템 우수하게 구현됨!")
    else:
        print("⚠️ 시스템 개선이 필요합니다.")

def frequency_to_note_name(frequency):
    """주파수를 음정 이름으로 변환"""
    if frequency <= 0:
        return ''
    
    A4 = 440.0
    semitones = 12 * math.log2(frequency / A4)
    note_index = (int(semitones) + 9) % 12
    octave = 4 + (int(semitones) + 9) // 12
    
    notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    return f"{notes[note_index]}{octave}"

def test_complete_chromatic_scale():
    """전체 반음계 테스트"""
    print(f"\n🎼 완전한 반음계 시스템 테스트 (C3-C5)")
    print("-" * 60)
    
    freq_table = generate_complete_frequency_table()
    
    # C3부터 C5까지 25개 반음
    chromatic_notes = []
    for octave in [3, 4, 5]:
        for note in ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']:
            chromatic_notes.append(f"{note}{octave}")
            if note == 'C' and octave == 5:  # C5까지만
                break
    
    print(f"🎵 반음계 {len(chromatic_notes)}개 음정 연속 테스트")
    
    for i, note_name in enumerate(chromatic_notes):
        target_freq = freq_table[note_name]
        
        # 간단한 테스트 (시간 절약을 위해)
        duration = 0.5
        sample_rate = 48000
        t = np.linspace(0, duration, int(sample_rate * duration), False)
        audio = 0.5 * np.sin(2 * np.pi * target_freq * t)
        
        byte_data = audio.astype(np.float32).tobytes()
        audio_b64 = base64.b64encode(byte_data).decode('utf-8')
        
        try:
            response = requests.post('http://localhost:5002/analyze', 
                                   json={
                                       'audio_base64': audio_b64,
                                       'sample_rate': 48000
                                   },
                                   timeout=5)
            
            if response.status_code == 200:
                result = response.json()
                frequencies = result.get('frequencies', [])
                confidences = result.get('confidence', [])
                
                if frequencies and confidences:
                    max_conf_idx = np.argmax(confidences)
                    detected_freq = frequencies[max_conf_idx]
                    error_hz = abs(detected_freq - target_freq)
                    
                    status = "✅" if error_hz < 10 else "❌"
                    print(f"{status} {note_name}: {target_freq:.0f}Hz → {detected_freq:.0f}Hz (±{error_hz:.1f}Hz)")
                    
        except:
            print(f"❌ {note_name}: 분석 실패")

if __name__ == "__main__":
    test_bach_temperament_system()
    test_complete_chromatic_scale()