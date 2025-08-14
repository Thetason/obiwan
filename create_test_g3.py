#!/usr/bin/env python3
"""
실제 G3 음성과 유사한 테스트 파일 생성
"""
import numpy as np
import soundfile as sf

def create_g3_test_file():
    """G3와 유사한 복합음 생성"""
    frequency = 196.0  # G3
    duration = 2.0
    sample_rate = 48000
    
    t = np.linspace(0, duration, int(sample_rate * duration), False)
    
    # 기본 주파수 (G3)
    fundamental = 0.8 * np.sin(2 * np.pi * frequency * t)
    
    # 하모닉 추가 (실제 음성과 유사하게)
    harmonic2 = 0.3 * np.sin(2 * np.pi * frequency * 2 * t)  # 옥타브 위 (G4)
    harmonic3 = 0.15 * np.sin(2 * np.pi * frequency * 3 * t)  # 완전5도 위
    harmonic4 = 0.05 * np.sin(2 * np.pi * frequency * 4 * t)  # 두 옥타브 위
    
    # 약간의 노이즈 추가 (실제 음성과 유사하게)
    noise = 0.02 * np.random.normal(0, 1, len(t))
    
    # 합성
    audio = fundamental + harmonic2 + harmonic3 + harmonic4 + noise
    
    # 엔벨로프 적용 (페이드 인/아웃)
    envelope_samples = int(0.1 * sample_rate)  # 0.1초 페이드
    fade_in = np.linspace(0, 1, envelope_samples)
    fade_out = np.linspace(1, 0, envelope_samples)
    
    audio[:envelope_samples] *= fade_in
    audio[-envelope_samples:] *= fade_out
    
    # 정규화
    audio = audio / np.max(np.abs(audio)) * 0.7
    
    # WAV 파일로 저장
    sf.write('test_g3_voice.wav', audio, sample_rate)
    
    print(f"✅ G3 테스트 파일 생성: test_g3_voice.wav")
    print(f"   - 기본 주파수: {frequency} Hz (G3)")
    print(f"   - 길이: {duration} 초")
    print(f"   - 샘플레이트: {sample_rate} Hz")
    print(f"   - 하모닉 포함: 실제 음성과 유사")

if __name__ == "__main__":
    create_g3_test_file()