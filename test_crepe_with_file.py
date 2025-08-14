#!/usr/bin/env python3
"""
실제 음성 파일로 CREPE 서버 테스트
"""
import requests
import soundfile as sf
import base64
import numpy as np

def test_crepe_with_audio_file(file_path):
    """음성 파일로 CREPE 서버 테스트"""
    print(f"🎵 CREPE 서버 테스트: {file_path}")
    print("=" * 50)
    
    try:
        # 오디오 파일 로드
        audio_data, sample_rate = sf.read(file_path, dtype='float32')
        print(f"📁 파일 로드 성공:")
        print(f"   - 샘플레이트: {sample_rate} Hz")
        print(f"   - 길이: {len(audio_data)} 샘플 ({len(audio_data)/sample_rate:.1f}초)")
        print(f"   - 데이터 타입: {audio_data.dtype}")
        print(f"   - 최대값: {np.max(np.abs(audio_data)):.4f}")
        print(f"   - RMS: {np.sqrt(np.mean(audio_data**2)):.4f}")
        
        # 모노 처리 (스테레오인 경우)
        if len(audio_data.shape) > 1:
            audio_data = np.mean(audio_data, axis=1)
        
        # Base64 인코딩
        byte_data = audio_data.tobytes()
        audio_b64 = base64.b64encode(byte_data).decode('utf-8')
        
        print(f"📦 Base64 인코딩 완료: {len(audio_b64)} 문자")
        
        # CREPE 서버 요청
        response = requests.post('http://localhost:5002/analyze', 
                               json={
                                   'audio_base64': audio_b64,
                                   'sample_rate': int(sample_rate)
                               },
                               timeout=15)
        
        if response.status_code == 200:
            result = response.json()
            frequencies = result.get('frequencies', [])
            confidences = result.get('confidence', [])
            
            if frequencies and confidences:
                print(f"✅ CREPE 분석 성공: {len(frequencies)}개 프레임")
                
                # 신뢰도가 높은 상위 5개 결과
                sorted_indices = sorted(range(len(confidences)), 
                                      key=lambda i: confidences[i], reverse=True)
                
                print(f"\n🎯 상위 5개 결과 (신뢰도순):")
                for i, idx in enumerate(sorted_indices[:5]):
                    freq = frequencies[idx]
                    conf = confidences[idx]
                    note = frequency_to_note(freq)
                    print(f"  {i+1}. {freq:.1f} Hz ({note}) - 신뢰도: {conf:.3f}")
                
                # 평균 결과 (신뢰도 0.5 이상)
                high_conf_indices = [i for i, c in enumerate(confidences) if c > 0.5]
                if high_conf_indices:
                    avg_freq = np.mean([frequencies[i] for i in high_conf_indices])
                    avg_conf = np.mean([confidences[i] for i in high_conf_indices])
                    avg_note = frequency_to_note(avg_freq)
                    
                    print(f"\n📊 고신뢰도 평균 (신뢰도 > 0.5):")
                    print(f"   - 주파수: {avg_freq:.1f} Hz ({avg_note})")
                    print(f"   - 평균 신뢰도: {avg_conf:.3f}")
                    print(f"   - G3(196Hz)과 차이: {abs(avg_freq - 196.0):.1f} Hz")
                    
                    # 정확도 평가
                    if abs(avg_freq - 196.0) < 10:
                        print("✅ G3 정확히 인식됨!")
                    elif abs(avg_freq - 392.0) < 10:
                        print("⚠️ G4(한 옥타브 위)로 인식됨")
                    elif abs(avg_freq - 98.0) < 10:
                        print("⚠️ G2(한 옥타브 아래)로 인식됨")
                    else:
                        print("❌ 완전히 다른 음정으로 인식됨")
                else:
                    print("❌ 신뢰도가 높은 결과가 없음")
            else:
                print("❌ CREPE 분석 결과가 비어있음")
        else:
            print(f"❌ HTTP 오류: {response.status_code}")
            print(f"응답: {response.text}")
            
    except Exception as e:
        print(f"❌ 테스트 실패: {e}")

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
    test_crepe_with_audio_file("test_g3_voice.wav")