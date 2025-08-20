#!/usr/bin/env python3
"""
Professional Vocal Analysis System
프로페셔널 보컬 트레이너 관점의 음성 분석 및 라벨링 시스템

Based on:
- Classical vocal pedagogy
- Contemporary vocal technique (CVT)
- Speech Level Singing (SLS) methodology
- Bel canto principles
- Modern voice science
"""

import numpy as np
import json
import requests
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass, asdict
from enum import Enum
import math
from datetime import datetime

class VocalRegister(Enum):
    """발성 구역 분류"""
    VOCAL_FRY = "vocal_fry"          # 성문폐쇄음
    CHEST = "chest"                  # 흉성 (Modal/Chest)
    MIX = "mixed"                    # 믹스 (혼성)
    HEAD = "head"                    # 두성
    FALSETTO = "falsetto"            # 가성
    WHISTLE = "whistle"              # 휘슬 레지스터
    UNKNOWN = "unknown"

class ArticulationQuality(Enum):
    """조음/발음 품질"""
    EXCELLENT = "excellent"          # 탁월함
    GOOD = "good"                    # 양호함
    FAIR = "fair"                    # 보통
    POOR = "poor"                    # 불량
    UNCLEAR = "unclear"              # 불분명

class BreathSupport(Enum):
    """호흡 지지력"""
    EXCELLENT = "excellent"          # 완벽한 호흡 지지
    GOOD = "good"                    # 좋은 호흡 지지
    ADEQUATE = "adequate"            # 적절한 호흡
    WEAK = "weak"                    # 약한 호흡
    POOR = "poor"                    # 불충분한 호흡

class VowelShape(Enum):
    """모음 형태 (IPA 기반)"""
    A_OPEN = "ɑ"       # 아 (open back)
    A_FRONT = "a"      # 앞 아
    E_OPEN = "ɛ"       # 에 (open mid front)
    E_CLOSE = "e"      # 이에
    I = "i"            # 이
    O_OPEN = "ɔ"       # 오 (open mid back)
    O_CLOSE = "o"      # 우오
    U = "u"            # 우
    SCHWA = "ə"        # 애매모음
    MIXED = "mixed"    # 혼합 모음

@dataclass
class FormantProfile:
    """포먼트 프로필"""
    f1: float          # 첫 번째 포먼트 (혀 높이)
    f2: float          # 두 번째 포먼트 (혀 위치)
    f3: float          # 세 번째 포먼트 (입술 모양)
    f4: float = 0      # 네 번째 포먼트
    singers_formant: float = 0  # 가수 포먼트 (2800-3500Hz)
    formant_bandwidth: List[float] = None  # 포먼트 대역폭

@dataclass
class ResonancePattern:
    """공명 패턴"""
    chest_resonance: float     # 흉부 공명
    oral_resonance: float      # 구강 공명
    nasal_resonance: float     # 비강 공명
    head_resonance: float      # 두부 공명
    placement_score: float     # 배치 점수 (0-1)
    forward_placement: bool    # 전진 배치 여부

@dataclass
class VibratoAnalysis:
    """비브라토 분석"""
    detected: bool
    rate: float               # Hz (4-7Hz 이상적)
    extent: float             # cents (20-100 cents)
    regularity: float         # 규칙성 (0-1)
    onset_timing: float       # 시작 타이밍 (초)
    consistency: float        # 일관성 (0-1)
    type: str                 # "natural", "forced", "tremolo", "wobble"

@dataclass
class PassaggioAnalysis:
    """전환음(Passaggio) 분석"""
    detected: bool
    location: float           # Hz
    smoothness: float         # 부드러움 정도 (0-1)
    register_blend: float     # 레지스터 블렌딩 (0-1)
    tension_level: float      # 긴장도 (0-1, 낮을수록 좋음)
    transition_type: str      # "smooth", "abrupt", "cracked"

@dataclass
class ExpressionMarking:
    """표현 마킹 (음악적 표현)"""
    dynamics: str             # pp, p, mp, mf, f, ff
    articulation: str         # legato, staccato, marcato
    phrasing_quality: float   # 프레이징 품질 (0-1)
    musicality_score: float   # 음악성 점수 (0-1)
    tempo_consistency: float  # 템포 일관성 (0-1)

@dataclass
class VocalHealthIndicator:
    """음성 건강 지표"""
    vocal_strain: float       # 성대 무리 정도 (0-1)
    breath_efficiency: float  # 호흡 효율성 (0-1)
    tension_areas: List[str]  # 긴장 부위
    sustainability: float     # 지속 가능성 (0-1)
    risk_level: str          # "low", "moderate", "high"

@dataclass
class ComprehensiveVocalLabel:
    """종합적 음성 라벨"""
    # 기본 정보
    timestamp: float
    fundamental_frequency: float
    note: str
    octave: int
    
    # 발성 기법
    register: VocalRegister
    formant_profile: FormantProfile
    resonance_pattern: ResonancePattern
    
    # 고급 분석
    vibrato: VibratoAnalysis
    passaggio: Optional[PassaggioAnalysis]
    expression: ExpressionMarking
    
    # 음성학적 분석
    vowel_shape: VowelShape
    articulation_quality: ArticulationQuality
    breath_support: BreathSupport
    
    # 건강 및 효율성
    vocal_health: VocalHealthIndicator
    
    # 메타데이터
    confidence: float
    analysis_source: str
    
class ProfessionalVocalAnalyzer:
    """프로페셔널 보컬 분석기"""
    
    def __init__(self):
        self.crepe_url = "http://localhost:5002"
        self.spice_url = "http://localhost:5003"
        self.formant_url = "http://localhost:5004"
        
        # 음성학적 기준값들
        self.vowel_formants = self._initialize_vowel_formants()
        self.register_boundaries = self._initialize_register_boundaries()
        self.passaggio_ranges = self._initialize_passaggio_ranges()
        
    def _initialize_vowel_formants(self) -> Dict[VowelShape, Tuple[float, float]]:
        """모음별 표준 포먼트 값 (성인 여성 기준)"""
        return {
            VowelShape.A_OPEN: (850, 1220),    # /ɑ/ 아
            VowelShape.A_FRONT: (750, 1700),   # /a/ 앞 아
            VowelShape.E_OPEN: (610, 1900),    # /ɛ/ 에
            VowelShape.E_CLOSE: (390, 2300),   # /e/ 이에
            VowelShape.I: (310, 2790),         # /i/ 이
            VowelShape.O_OPEN: (500, 1000),    # /ɔ/ 오
            VowelShape.O_CLOSE: (360, 750),    # /o/ 우오
            VowelShape.U: (320, 800),          # /u/ 우
            VowelShape.SCHWA: (500, 1500),     # /ə/ 애매모음
        }
    
    def _initialize_register_boundaries(self) -> Dict[str, Tuple[float, float]]:
        """발성 구역 경계선 (Hz) - 일반적인 여성 기준"""
        return {
            "vocal_fry": (0, 80),
            "chest_low": (80, 200),
            "chest_mid": (200, 350),
            "passaggio_1": (350, 450),  # 첫 번째 전환음
            "mixed": (450, 700),
            "passaggio_2": (700, 800),  # 두 번째 전환음
            "head": (800, 1400),
            "falsetto": (800, 2000),
            "whistle": (2000, 4000)
        }
    
    def _initialize_passaggio_ranges(self) -> Dict[str, Tuple[float, float]]:
        """성부별 전환음 범위"""
        return {
            "soprano": (350, 450),
            "mezzo": (330, 430),
            "alto": (310, 410),
            "tenor": (280, 350),
            "baritone": (250, 320),
            "bass": (200, 280)
        }
    
    def analyze_comprehensive(self, audio_chunk: np.ndarray, time_offset: float, 
                            sample_rate: int = 44100) -> ComprehensiveVocalLabel:
        """종합적 음성 분석"""
        
        # 1. 기본 피치 분석
        pitch_data = self._analyze_pitch_comprehensive(audio_chunk, sample_rate)
        
        # 2. 포먼트 분석 
        formant_profile = self._analyze_formants_detailed(audio_chunk, sample_rate)
        
        # 3. 발성 구역 판정
        register = self._classify_register_advanced(
            pitch_data['frequency'], formant_profile, audio_chunk
        )
        
        # 4. 공명 패턴 분석
        resonance = self._analyze_resonance_pattern(formant_profile, audio_chunk)
        
        # 5. 비브라토 분석
        vibrato = self._analyze_vibrato_professional(audio_chunk, pitch_data['frequency'])
        
        # 6. 전환음 분석 (해당하는 경우)
        passaggio = self._analyze_passaggio(pitch_data['frequency'], formant_profile)
        
        # 7. 표현적 요소 분석
        expression = self._analyze_musical_expression(audio_chunk, pitch_data)
        
        # 8. 모음 형태 분석
        vowel_shape = self._classify_vowel_shape(formant_profile)
        
        # 9. 조음 품질 평가
        articulation = self._evaluate_articulation_quality(formant_profile, audio_chunk)
        
        # 10. 호흡 지지력 평가
        breath_support = self._evaluate_breath_support(audio_chunk, pitch_data)
        
        # 11. 음성 건강 지표
        vocal_health = self._assess_vocal_health(audio_chunk, pitch_data, formant_profile)
        
        return ComprehensiveVocalLabel(
            timestamp=time_offset,
            fundamental_frequency=pitch_data['frequency'],
            note=pitch_data['note'],
            octave=pitch_data['octave'],
            register=register,
            formant_profile=formant_profile,
            resonance_pattern=resonance,
            vibrato=vibrato,
            passaggio=passaggio,
            expression=expression,
            vowel_shape=vowel_shape,
            articulation_quality=articulation,
            breath_support=breath_support,
            vocal_health=vocal_health,
            confidence=pitch_data['confidence'],
            analysis_source="comprehensive_professional"
        )
    
    def _analyze_pitch_comprehensive(self, audio_chunk: np.ndarray, 
                                   sample_rate: int) -> Dict:
        """포괄적 피치 분석 (CREPE + SPICE 결합)"""
        import base64
        
        # 오디오 데이터를 Base64로 인코딩
        audio_bytes = (audio_chunk * 32767).astype(np.int16).tobytes()
        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
        
        pitch_data = {
            'frequency': 0,
            'confidence': 0,
            'note': '',
            'octave': 4,
            'cents_deviation': 0,
            'harmonic_clarity': 0
        }
        
        try:
            # CREPE 분석 (정확도 우선)
            crepe_response = requests.post(
                f"{self.crepe_url}/analyze",
                json={"audio_base64": audio_base64, "sample_rate": sample_rate},
                timeout=3
            )
            
            # SPICE 분석 (음계 양자화)
            spice_response = requests.post(
                f"{self.spice_url}/analyze",
                json={"audio_base64": audio_base64, "sample_rate": sample_rate},
                timeout=3
            )
            
            # 결과 통합
            if crepe_response.status_code == 200:
                crepe_data = crepe_response.json()
                pitches = crepe_data.get('pitches', [])
                confidences = crepe_data.get('confidences', [])
                
                if pitches and confidences:
                    # 고신뢰도 피치들의 평균
                    high_conf_indices = [i for i, c in enumerate(confidences) if c > 0.7]
                    if high_conf_indices:
                        valid_pitches = [pitches[i] for i in high_conf_indices]
                        valid_confs = [confidences[i] for i in high_conf_indices]
                        
                        pitch_data['frequency'] = np.mean(valid_pitches)
                        pitch_data['confidence'] = np.mean(valid_confs)
                        pitch_data['harmonic_clarity'] = min(np.std(valid_pitches) / np.mean(valid_pitches) * 100, 1.0) if valid_pitches else 0
            
            # 음표 정보 추가
            if pitch_data['frequency'] > 0:
                note_info = self._frequency_to_note_detailed(pitch_data['frequency'])
                pitch_data.update(note_info)
                
        except Exception as e:
            print(f"피치 분석 오류: {e}")
        
        return pitch_data
    
    def _frequency_to_note_detailed(self, frequency: float) -> Dict:
        """상세한 주파수-음표 변환"""
        if frequency <= 0:
            return {'note': '', 'octave': 4, 'cents_deviation': 0}
        
        A4 = 440.0
        notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
        
        # 반음 계산
        semitones_from_a4 = 12 * math.log2(frequency / A4)
        
        # 가장 가까운 반음
        nearest_semitone = round(semitones_from_a4)
        cents_deviation = (semitones_from_a4 - nearest_semitone) * 100
        
        # 음표와 옥타브
        note_index = (nearest_semitone + 9) % 12  # A를 기준으로 조정
        octave = 4 + (nearest_semitone + 9) // 12
        
        return {
            'note': notes[note_index],
            'octave': octave,
            'cents_deviation': cents_deviation
        }
    
    def _analyze_formants_detailed(self, audio_chunk: np.ndarray, 
                                 sample_rate: int) -> FormantProfile:
        """상세한 포먼트 분석"""
        import base64
        
        audio_bytes = (audio_chunk * 32767).astype(np.int16).tobytes()
        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
        
        try:
            # 포먼트 서버 호출
            response = requests.post(
                f"{self.formant_url}/analyze",
                json={"audio_base64": audio_base64, "sample_rate": sample_rate},
                timeout=5
            )
            
            if response.status_code == 200:
                data = response.json()
                formants = data.get('formants', {})
                
                return FormantProfile(
                    f1=formants.get('f1', 500),
                    f2=formants.get('f2', 1500), 
                    f3=formants.get('f3', 2500),
                    f4=formants.get('f4', 3500),
                    singers_formant=formants.get('singers_formant', 0),
                    formant_bandwidth=formants.get('bandwidth', [50, 100, 150, 200])
                )
        except:
            pass
        
        # 폴백: 기본값
        return FormantProfile(f1=500, f2=1500, f3=2500, f4=3500, singers_formant=0)
    
    def _classify_register_advanced(self, frequency: float, formants: FormantProfile,
                                  audio_chunk: np.ndarray) -> VocalRegister:
        """고급 발성 구역 분류"""
        if frequency <= 0:
            return VocalRegister.UNKNOWN
        
        # 주파수 기반 기본 분류
        if frequency < 80:
            return VocalRegister.VOCAL_FRY
        elif frequency < 200:
            return VocalRegister.CHEST
        elif 200 <= frequency < 350:
            # 포먼트 패턴으로 세분화
            if formants.f1 > 600 and formants.singers_formant > 0.3:
                return VocalRegister.CHEST
            else:
                return VocalRegister.MIX
        elif 350 <= frequency < 700:
            # 믹스 vs 헤드 판정 (포먼트 기반)
            if formants.f1 > 500 and formants.f2 < 1800:
                return VocalRegister.MIX
            elif formants.f1 < 400 and formants.f2 > 2000:
                return VocalRegister.HEAD
            else:
                return VocalRegister.MIX
        elif 700 <= frequency < 1400:
            # 스펙트럴 에너지 분포로 판정
            spectral_centroid = self._calculate_spectral_centroid(audio_chunk)
            if spectral_centroid > 2000:
                return VocalRegister.HEAD
            else:
                return VocalRegister.FALSETTO
        elif frequency >= 2000:
            return VocalRegister.WHISTLE
        else:
            return VocalRegister.HEAD
    
    def _calculate_spectral_centroid(self, audio_chunk: np.ndarray) -> float:
        """스펙트럴 중심 계산"""
        try:
            # FFT 계산
            fft = np.fft.rfft(audio_chunk)
            magnitude = np.abs(fft)
            
            # 주파수 빈
            freqs = np.fft.rfftfreq(len(audio_chunk), 1/44100)
            
            # 스펙트럴 중심 계산
            if np.sum(magnitude) > 0:
                centroid = np.sum(freqs * magnitude) / np.sum(magnitude)
                return centroid
        except:
            pass
        return 1000  # 기본값
    
    def _analyze_resonance_pattern(self, formants: FormantProfile, 
                                 audio_chunk: np.ndarray) -> ResonancePattern:
        """공명 패턴 분석"""
        # 포먼트 비율 기반 공명 분석
        f1_f2_ratio = formants.f1 / formants.f2 if formants.f2 > 0 else 0
        
        # 흉부 공명 (F1 기반)
        chest_resonance = min(formants.f1 / 800, 1.0)
        
        # 구강 공명 (F2 기반)
        oral_resonance = min(formants.f2 / 2000, 1.0)
        
        # 두부 공명 (F3, 가수 포먼트 기반)
        head_resonance = min((formants.f3 + formants.singers_formant) / 3000, 1.0)
        
        # 비강 공명 추정 (스펙트럴 특성 기반)
        nasal_resonance = self._estimate_nasal_resonance(audio_chunk)
        
        # 배치 점수 (포먼트 선명도 기반)
        placement_score = min(formants.singers_formant / 0.5, 1.0) if formants.singers_formant > 0 else 0.5
        
        # 전진 배치 (F2/F1 비율 기반)
        forward_placement = formants.f2 / formants.f1 > 2.5 if formants.f1 > 0 else False
        
        return ResonancePattern(
            chest_resonance=chest_resonance,
            oral_resonance=oral_resonance,
            nasal_resonance=nasal_resonance,
            head_resonance=head_resonance,
            placement_score=placement_score,
            forward_placement=forward_placement
        )
    
    def _estimate_nasal_resonance(self, audio_chunk: np.ndarray) -> float:
        """비강 공명 추정 (스펙트럴 특성 기반)"""
        try:
            # 비강 공명의 특징적 주파수 대역 (500-1500Hz)
            fft = np.fft.rfft(audio_chunk)
            freqs = np.fft.rfftfreq(len(audio_chunk), 1/44100)
            magnitude = np.abs(fft)
            
            # 비강 공명 대역의 에너지
            nasal_range = (freqs >= 500) & (freqs <= 1500)
            nasal_energy = np.sum(magnitude[nasal_range])
            total_energy = np.sum(magnitude)
            
            return min(nasal_energy / total_energy * 2, 1.0) if total_energy > 0 else 0.3
        except:
            return 0.3  # 기본값
    
    def _analyze_vibrato_professional(self, audio_chunk: np.ndarray, 
                                    frequency: float) -> VibratoAnalysis:
        """프로페셔널 비브라토 분석"""
        # 이전 프레임들과의 연속성을 위해 히스토리 필요 (여기서는 단순화)
        
        # 주파수 변화율 계산
        if len(audio_chunk) < 1024:
            return VibratoAnalysis(
                detected=False, rate=0, extent=0, regularity=0,
                onset_timing=0, consistency=0, type="none"
            )
        
        # 간단한 비브라토 감지 (실제로는 더 복잡한 알고리즘 필요)
        try:
            # 윈도우 기반 피치 변화 분석
            window_size = len(audio_chunk) // 10
            pitch_variations = []
            
            for i in range(0, len(audio_chunk) - window_size, window_size):
                chunk = audio_chunk[i:i+window_size]
                # 간단한 피치 추정 (자기상관 기반)
                pitch_estimate = self._estimate_pitch_autocorr(chunk)
                if pitch_estimate > 0:
                    pitch_variations.append(pitch_estimate)
            
            if len(pitch_variations) < 5:
                return VibratoAnalysis(
                    detected=False, rate=0, extent=0, regularity=0,
                    onset_timing=0, consistency=0, type="insufficient_data"
                )
            
            # 주파수 변화 분석
            pitch_variations = np.array(pitch_variations)
            mean_pitch = np.mean(pitch_variations)
            pitch_std = np.std(pitch_variations)
            
            # 변화율 계산
            variation_rate = pitch_std / mean_pitch if mean_pitch > 0 else 0
            
            # 주기성 검사 (간단한 버전)
            pitch_diff = np.diff(pitch_variations)
            zero_crossings = np.sum(np.diff(np.signbit(pitch_diff)))
            
            # 비브라토 판정
            is_vibrato = (
                0.01 < variation_rate < 0.1 and  # 적절한 변화율
                zero_crossings >= 4 and          # 충분한 진동
                pitch_std > 2                    # 최소 변화량
            )
            
            if is_vibrato:
                # 비브라토 특성 계산
                vibrato_rate = zero_crossings / 2  # 대략적인 Hz
                vibrato_extent = 1200 * np.log2((mean_pitch + pitch_std) / mean_pitch) if mean_pitch > 0 else 0
                regularity = 1.0 - (np.std(pitch_diff) / np.mean(np.abs(pitch_diff))) if np.mean(np.abs(pitch_diff)) > 0 else 0
                
                # 비브라토 타입 분류
                if 4 <= vibrato_rate <= 7 and 20 <= vibrato_extent <= 100:
                    vibrato_type = "natural"
                elif vibrato_rate > 8:
                    vibrato_type = "tremolo"
                elif vibrato_rate < 3:
                    vibrato_type = "wobble"
                else:
                    vibrato_type = "irregular"
                
                return VibratoAnalysis(
                    detected=True,
                    rate=vibrato_rate,
                    extent=vibrato_extent,
                    regularity=regularity,
                    onset_timing=0.5,  # 추정값
                    consistency=regularity,
                    type=vibrato_type
                )
            else:
                return VibratoAnalysis(
                    detected=False, rate=0, extent=variation_rate * 100,
                    regularity=0, onset_timing=0, consistency=0, type="straight_tone"
                )
                
        except Exception as e:
            return VibratoAnalysis(
                detected=False, rate=0, extent=0, regularity=0,
                onset_timing=0, consistency=0, type="analysis_error"
            )
    
    def _estimate_pitch_autocorr(self, chunk: np.ndarray, sample_rate: int = 44100) -> float:
        """자기상관 기반 피치 추정"""
        try:
            # 정규화
            chunk = chunk - np.mean(chunk)
            
            # 자기상관 계산
            autocorr = np.correlate(chunk, chunk, mode='full')
            autocorr = autocorr[autocorr.size // 2:]
            
            # 피크 찾기 (최소/최대 주파수 제한)
            min_period = sample_rate // 800  # 최대 800Hz
            max_period = sample_rate // 80   # 최소 80Hz
            
            if len(autocorr) > max_period:
                autocorr_segment = autocorr[min_period:max_period]
                peak_idx = np.argmax(autocorr_segment) + min_period
                
                if peak_idx > 0:
                    pitch = sample_rate / peak_idx
                    return pitch
            
        except:
            pass
        return 0
    
    def _analyze_passaggio(self, frequency: float, 
                         formants: FormantProfile) -> Optional[PassaggioAnalysis]:
        """전환음 분석"""
        # 전환음 범위 확인
        in_passaggio = False
        for voice_type, (low, high) in self.passaggio_ranges.items():
            if low <= frequency <= high:
                in_passaggio = True
                break
        
        if not in_passaggio:
            return None
        
        # 전환음 특성 분석
        # F1/F2 비율로 전환의 부드러움 판정
        f1_f2_ratio = formants.f1 / formants.f2 if formants.f2 > 0 else 0
        
        # 이상적인 비율에서의 편차
        ideal_ratio = 0.3  # 대략적인 이상적 비율
        ratio_deviation = abs(f1_f2_ratio - ideal_ratio)
        
        smoothness = max(0, 1 - ratio_deviation * 5)  # 편차가 클수록 부드럽지 않음
        
        # 레지스터 블렌딩 (가수 포먼트 기반)
        register_blend = min(formants.singers_formant * 2, 1.0) if formants.singers_formant > 0 else 0.3
        
        # 긴장도 (포먼트 대역폭으로 추정)
        tension_level = 0.5  # 기본값 (실제로는 더 복잡한 계산 필요)
        
        # 전환 타입 분류
        if smoothness > 0.7:
            transition_type = "smooth"
        elif smoothness > 0.4:
            transition_type = "acceptable"
        else:
            transition_type = "abrupt"
        
        return PassaggioAnalysis(
            detected=True,
            location=frequency,
            smoothness=smoothness,
            register_blend=register_blend,
            tension_level=tension_level,
            transition_type=transition_type
        )
    
    def _analyze_musical_expression(self, audio_chunk: np.ndarray, 
                                  pitch_data: Dict) -> ExpressionMarking:
        """음악적 표현 분석"""
        # RMS 에너지로 다이나믹스 판정
        rms_energy = np.sqrt(np.mean(audio_chunk**2))
        
        if rms_energy > 0.7:
            dynamics = "ff"
        elif rms_energy > 0.5:
            dynamics = "f"
        elif rms_energy > 0.3:
            dynamics = "mf"
        elif rms_energy > 0.1:
            dynamics = "mp"
        elif rms_energy > 0.05:
            dynamics = "p"
        else:
            dynamics = "pp"
        
        # 아티큘레이션 (스펙트럴 변화율 기반)
        spectral_flux = self._calculate_spectral_flux(audio_chunk)
        
        if spectral_flux > 0.5:
            articulation = "staccato"
        elif spectral_flux < 0.2:
            articulation = "legato"
        else:
            articulation = "normal"
        
        return ExpressionMarking(
            dynamics=dynamics,
            articulation=articulation,
            phrasing_quality=0.75,  # 기본값
            musicality_score=0.8,   # 기본값
            tempo_consistency=0.85  # 기본값
        )
    
    def _calculate_spectral_flux(self, audio_chunk: np.ndarray) -> float:
        """스펙트럴 플럭스 계산 (음향 변화율)"""
        try:
            # 두 개의 윈도우로 나누어 변화율 계산
            mid_point = len(audio_chunk) // 2
            chunk1 = audio_chunk[:mid_point]
            chunk2 = audio_chunk[mid_point:]
            
            # 각각의 스펙트럼 계산
            fft1 = np.abs(np.fft.rfft(chunk1))
            fft2 = np.abs(np.fft.rfft(chunk2))
            
            # 길이 맞추기
            min_len = min(len(fft1), len(fft2))
            fft1 = fft1[:min_len]
            fft2 = fft2[:min_len]
            
            # 스펙트럴 플럭스
            flux = np.mean((fft2 - fft1)**2) / np.mean(fft1**2) if np.mean(fft1**2) > 0 else 0
            return min(flux, 1.0)
        except:
            return 0.3
    
    def _classify_vowel_shape(self, formants: FormantProfile) -> VowelShape:
        """포먼트 기반 모음 형태 분류"""
        min_distance = float('inf')
        best_vowel = VowelShape.SCHWA
        
        for vowel, (f1_ref, f2_ref) in self.vowel_formants.items():
            # 유클리드 거리 계산
            distance = np.sqrt((formants.f1 - f1_ref)**2 + (formants.f2 - f2_ref)**2)
            
            if distance < min_distance:
                min_distance = distance
                best_vowel = vowel
        
        # 거리가 너무 크면 혼합 모음으로 분류
        if min_distance > 400:  # 임계값
            return VowelShape.MIXED
        
        return best_vowel
    
    def _evaluate_articulation_quality(self, formants: FormantProfile, 
                                     audio_chunk: np.ndarray) -> ArticulationQuality:
        """조음 품질 평가"""
        # 포먼트 선명도 기반 평가
        formant_clarity = self._calculate_formant_clarity(formants)
        
        # 스펙트럴 명료도
        spectral_clarity = self._calculate_spectral_clarity(audio_chunk)
        
        # 종합 점수
        overall_clarity = (formant_clarity + spectral_clarity) / 2
        
        if overall_clarity > 0.8:
            return ArticulationQuality.EXCELLENT
        elif overall_clarity > 0.6:
            return ArticulationQuality.GOOD
        elif overall_clarity > 0.4:
            return ArticulationQuality.FAIR
        elif overall_clarity > 0.2:
            return ArticulationQuality.POOR
        else:
            return ArticulationQuality.UNCLEAR
    
    def _calculate_formant_clarity(self, formants: FormantProfile) -> float:
        """포먼트 선명도 계산"""
        # 포먼트 간격과 강도 기반
        f1_f2_separation = abs(formants.f2 - formants.f1)
        f2_f3_separation = abs(formants.f3 - formants.f2)
        
        # 적절한 간격이 있으면 선명함
        separation_score = min((f1_f2_separation + f2_f3_separation) / 3000, 1.0)
        
        # 가수 포먼트 강도
        singers_formant_score = min(formants.singers_formant * 2, 1.0)
        
        return (separation_score + singers_formant_score) / 2
    
    def _calculate_spectral_clarity(self, audio_chunk: np.ndarray) -> float:
        """스펙트럴 명료도 계산"""
        try:
            # 스펙트럼 계산
            fft = np.abs(np.fft.rfft(audio_chunk))
            
            # 고주파 대 저주파 에너지 비율
            freqs = np.fft.rfftfreq(len(audio_chunk), 1/44100)
            
            low_freq_energy = np.sum(fft[freqs < 1000])
            high_freq_energy = np.sum(fft[freqs > 1000])
            total_energy = low_freq_energy + high_freq_energy
            
            if total_energy > 0:
                clarity = high_freq_energy / total_energy
                return min(clarity * 2, 1.0)  # 정규화
            
        except:
            pass
        return 0.5
    
    def _evaluate_breath_support(self, audio_chunk: np.ndarray, 
                               pitch_data: Dict) -> BreathSupport:
        """호흡 지지력 평가"""
        # 음성의 안정성 기반 평가
        amplitude_stability = 1.0 - (np.std(np.abs(audio_chunk)) / np.mean(np.abs(audio_chunk))) if np.mean(np.abs(audio_chunk)) > 0 else 0
        
        # 피치 안정성
        pitch_stability = pitch_data.get('confidence', 0)
        
        # 지속성 (에너지 감소율)
        energy_decay = self._calculate_energy_decay(audio_chunk)
        sustainability = 1.0 - energy_decay
        
        # 종합 점수
        breath_score = (amplitude_stability + pitch_stability + sustainability) / 3
        
        if breath_score > 0.8:
            return BreathSupport.EXCELLENT
        elif breath_score > 0.6:
            return BreathSupport.GOOD
        elif breath_score > 0.4:
            return BreathSupport.ADEQUATE
        elif breath_score > 0.2:
            return BreathSupport.WEAK
        else:
            return BreathSupport.POOR
    
    def _calculate_energy_decay(self, audio_chunk: np.ndarray) -> float:
        """에너지 감소율 계산"""
        try:
            # 청크를 여러 부분으로 나누어 에너지 변화 측정
            n_segments = 5
            segment_length = len(audio_chunk) // n_segments
            
            energies = []
            for i in range(n_segments):
                start = i * segment_length
                end = start + segment_length
                segment = audio_chunk[start:end]
                energy = np.mean(segment**2)
                energies.append(energy)
            
            if len(energies) > 1:
                # 선형 회귀로 감소율 계산
                x = np.arange(len(energies))
                slope = np.polyfit(x, energies, 1)[0]
                # 음수 기울기는 감소를 의미
                decay_rate = max(0, -slope / energies[0]) if energies[0] > 0 else 0
                return min(decay_rate, 1.0)
        except:
            pass
        return 0.3  # 기본값
    
    def _assess_vocal_health(self, audio_chunk: np.ndarray, pitch_data: Dict,
                           formants: FormantProfile) -> VocalHealthIndicator:
        """음성 건강 지표 평가"""
        
        # 성대 무리 징후 (하모닉-노이즈 비율 기반)
        hnr = self._calculate_hnr(audio_chunk)
        vocal_strain = max(0, 1 - hnr / 15)  # 15dB 이상이 건강함
        
        # 호흡 효율성 (에너지 대비 피치 안정성)
        energy = np.mean(audio_chunk**2)
        pitch_confidence = pitch_data.get('confidence', 0)
        breath_efficiency = pitch_confidence * min(energy * 10, 1.0)
        
        # 긴장 부위 추정
        tension_areas = []
        
        # 높은 라링스 (F1이 비정상적으로 낮음)
        if formants.f1 < 300:
            tension_areas.append("larynx_high")
        
        # 혀 긴장 (F2 편차)
        if formants.f2 > 2500 or formants.f2 < 1000:
            tension_areas.append("tongue_tension")
        
        # 턱 긴장 (포먼트 간격)
        if abs(formants.f2 - formants.f1) < 800:
            tension_areas.append("jaw_tension")
        
        # 지속 가능성
        sustainability = min(breath_efficiency * 2, 1.0)
        
        # 위험도 결정
        if vocal_strain < 0.3 and len(tension_areas) == 0:
            risk_level = "low"
        elif vocal_strain < 0.6 and len(tension_areas) <= 2:
            risk_level = "moderate" 
        else:
            risk_level = "high"
        
        return VocalHealthIndicator(
            vocal_strain=vocal_strain,
            breath_efficiency=breath_efficiency,
            tension_areas=tension_areas,
            sustainability=sustainability,
            risk_level=risk_level
        )
    
    def _calculate_hnr(self, audio_chunk: np.ndarray) -> float:
        """하모닉-노이즈 비율 계산"""
        try:
            # 자기상관 기반 HNR 추정
            autocorr = np.correlate(audio_chunk, audio_chunk, mode='full')
            autocorr = autocorr[autocorr.size // 2:]
            
            # 최대 자기상관값 (하모닉 성분)
            max_autocorr = np.max(autocorr[1:])  # 0번 인덱스 제외
            
            # 전체 에너지
            total_energy = autocorr[0]
            
            if total_energy > 0:
                hnr_linear = max_autocorr / total_energy
                hnr_db = 10 * np.log10(hnr_linear / (1 - hnr_linear)) if hnr_linear < 1 else 20
                return max(0, min(hnr_db, 25))  # 0-25dB 범위
        except:
            pass
        return 10  # 기본값

    def create_pedagogical_assessment(self, label: ComprehensiveVocalLabel) -> Dict:
        """교육학적 평가 생성 (보컬 트레이너 관점)"""
        assessment = {
            'timestamp': label.timestamp,
            'fundamental_metrics': {
                'pitch_accuracy': self._assess_pitch_accuracy(label),
                'intonation_stability': self._assess_intonation_stability(label),
                'register_consistency': self._assess_register_consistency(label),
            },
            'technical_execution': {
                'breath_management': self._assess_breath_management(label),
                'resonance_efficiency': self._assess_resonance_efficiency(label),
                'articulation_precision': self._assess_articulation_precision(label),
                'vocal_agility': self._assess_vocal_agility(label)
            },
            'artistic_expression': {
                'dynamic_control': self._assess_dynamic_control(label),
                'phrase_shaping': self._assess_phrase_shaping(label),
                'stylistic_authenticity': self._assess_stylistic_authenticity(label),
                'emotional_connectivity': self._assess_emotional_connectivity(label)
            },
            'vocal_health': {
                'technique_sustainability': label.vocal_health.sustainability,
                'strain_indicators': label.vocal_health.vocal_strain,
                'risk_assessment': label.vocal_health.risk_level,
                'fatigue_resistance': self._assess_fatigue_resistance(label)
            },
            'development_priorities': self._generate_development_priorities(label),
            'exercise_recommendations': self._generate_exercise_recommendations(label),
            'overall_grade': self._calculate_overall_grade(label)
        }
        
        return assessment
    
    def _assess_pitch_accuracy(self, label: ComprehensiveVocalLabel) -> Dict:
        """피치 정확도 평가"""
        cents_deviation = abs(label.note.split('_')[1]) if '_' in str(label.note) else 0
        
        if cents_deviation < 10:
            accuracy_level = "excellent"
            score = 95 + (10 - cents_deviation)
        elif cents_deviation < 25:
            accuracy_level = "good"
            score = 80 + (25 - cents_deviation) * 0.6
        elif cents_deviation < 50:
            accuracy_level = "fair"
            score = 60 + (50 - cents_deviation) * 0.4
        else:
            accuracy_level = "needs_improvement"
            score = max(30, 60 - (cents_deviation - 50) * 0.2)
        
        return {
            'score': round(score, 1),
            'level': accuracy_level,
            'cents_deviation': cents_deviation,
            'feedback': self._generate_pitch_feedback(accuracy_level, cents_deviation)
        }
    
    def _generate_pitch_feedback(self, level: str, cents: float) -> str:
        """피치 피드백 생성"""
        feedback_map = {
            "excellent": "탁월한 음정 정확도입니다. 이 수준을 유지하세요.",
            "good": f"좋은 음정입니다. {cents:.0f} 센트 편차를 줄여보세요.",
            "fair": f"음정이 {cents:.0f} 센트 벗어났습니다. 스케일 연습을 늘리세요.",
            "needs_improvement": f"음정 개선이 필요합니다. {cents:.0f} 센트는 상당한 편차입니다."
        }
        return feedback_map.get(level, "음정 연습이 필요합니다.")
    
    def _assess_intonation_stability(self, label: ComprehensiveVocalLabel) -> Dict:
        """음정 안정성 평가"""
        confidence = label.confidence
        vibrato_consistency = label.vibrato.consistency if label.vibrato.detected else 0.8
        
        stability_score = (confidence * 0.7 + vibrato_consistency * 0.3) * 100
        
        if stability_score > 85:
            level = "excellent"
        elif stability_score > 70:
            level = "good"
        elif stability_score > 55:
            level = "fair"
        else:
            level = "unstable"
        
        return {
            'score': round(stability_score, 1),
            'level': level,
            'confidence': confidence,
            'vibrato_consistency': vibrato_consistency
        }
    
    def _assess_register_consistency(self, label: ComprehensiveVocalLabel) -> Dict:
        """레지스터 일관성 평가"""
        register = label.register
        formant_profile = label.formant_profile
        
        # 레지스터별 포먼트 적절성 평가
        consistency_score = self._evaluate_register_formant_match(register, formant_profile)
        
        return {
            'score': consistency_score,
            'register': register.value,
            'appropriateness': 'appropriate' if consistency_score > 70 else 'needs_adjustment'
        }
    
    def _evaluate_register_formant_match(self, register: VocalRegister, 
                                       formants: FormantProfile) -> float:
        """레지스터와 포먼트 매칭 평가"""
        # 레지스터별 이상적인 포먼트 범위 (간소화된 버전)
        ideal_ranges = {
            VocalRegister.CHEST: {'f1': (600, 800), 'f2': (1000, 1400)},
            VocalRegister.MIX: {'f1': (400, 600), 'f2': (1400, 1800)},
            VocalRegister.HEAD: {'f1': (300, 500), 'f2': (1800, 2500)},
            VocalRegister.FALSETTO: {'f1': (300, 450), 'f2': (1500, 2200)}
        }
        
        if register not in ideal_ranges:
            return 70  # 기본값
        
        ideal = ideal_ranges[register]
        f1_match = 1.0 if ideal['f1'][0] <= formants.f1 <= ideal['f1'][1] else 0.5
        f2_match = 1.0 if ideal['f2'][0] <= formants.f2 <= ideal['f2'][1] else 0.5
        
        return (f1_match + f2_match) * 50  # 0-100 점수
    
    def _assess_breath_management(self, label: ComprehensiveVocalLabel) -> Dict:
        """호흡 관리 평가"""
        breath_support = label.breath_support
        vocal_health = label.vocal_health
        
        # 호흡 지지력을 숫자로 변환
        support_values = {
            BreathSupport.EXCELLENT: 95,
            BreathSupport.GOOD: 80,
            BreathSupport.ADEQUATE: 65,
            BreathSupport.WEAK: 45,
            BreathSupport.POOR: 25
        }
        
        base_score = support_values.get(breath_support, 50)
        
        # 음성 건강 지표로 조정
        health_adjustment = (1 - vocal_health.vocal_strain) * 10
        efficiency_bonus = vocal_health.breath_efficiency * 5
        
        final_score = min(100, base_score + health_adjustment + efficiency_bonus)
        
        return {
            'score': round(final_score, 1),
            'support_level': breath_support.value,
            'efficiency': vocal_health.breath_efficiency,
            'recommendations': self._generate_breath_recommendations(breath_support)
        }
    
    def _generate_breath_recommendations(self, support: BreathSupport) -> List[str]:
        """호흡 개선 권장사항"""
        recommendations_map = {
            BreathSupport.EXCELLENT: ["현재 호흡 기술을 유지하세요.", "더 긴 프레이즈에 도전해보세요."],
            BreathSupport.GOOD: ["호흡 지지력을 더 일관되게 유지하세요.", "복식호흡을 의식적으로 연습하세요."],
            BreathSupport.ADEQUATE: ["호흡 지지력 강화 운동이 필요합니다.", "립 트릴과 브레스 컨트롤 연습을 하세요."],
            BreathSupport.WEAK: ["기초 호흡 기술부터 다시 연습하세요.", "요가나 필라테스로 코어를 강화하세요."],
            BreathSupport.POOR: ["전문적인 호흡 지도가 필요합니다.", "매일 기본 호흡 운동을 하세요."]
        }
        return recommendations_map.get(support, ["호흡 기술 개선이 필요합니다."])
    
    def _assess_resonance_efficiency(self, label: ComprehensiveVocalLabel) -> Dict:
        """공명 효율성 평가"""
        resonance = label.resonance_pattern
        formants = label.formant_profile
        
        # 각 공명 부위별 점수
        chest_score = min(resonance.chest_resonance * 100, 100)
        oral_score = min(resonance.oral_resonance * 100, 100)
        head_score = min(resonance.head_resonance * 100, 100)
        
        # 가수 포먼트 보너스
        singers_formant_bonus = min(formants.singers_formant * 20, 20)
        
        # 배치 점수
        placement_score = resonance.placement_score * 100
        
        # 종합 효율성
        overall_efficiency = (
            chest_score * 0.25 + 
            oral_score * 0.35 + 
            head_score * 0.25 + 
            placement_score * 0.15 +
            singers_formant_bonus
        )
        
        return {
            'overall_score': round(min(overall_efficiency, 100), 1),
            'chest_resonance': round(chest_score, 1),
            'oral_resonance': round(oral_score, 1),
            'head_resonance': round(head_score, 1),
            'placement_quality': round(placement_score, 1),
            'singers_formant_strength': round(singers_formant_bonus, 1),
            'forward_placement': resonance.forward_placement
        }
    
    def _assess_articulation_precision(self, label: ComprehensiveVocalLabel) -> Dict:
        """조음 정밀도 평가"""
        articulation = label.articulation_quality
        vowel_shape = label.vowel_shape
        
        # 조음 품질 점수화
        quality_scores = {
            ArticulationQuality.EXCELLENT: 95,
            ArticulationQuality.GOOD: 80,
            ArticulationQuality.FAIR: 65,
            ArticulationQuality.POOR: 40,
            ArticulationQuality.UNCLEAR: 20
        }
        
        base_score = quality_scores.get(articulation, 50)
        
        # 모음 명확성 보너스
        vowel_clarity_bonus = 5 if vowel_shape != VowelShape.MIXED else 0
        
        final_score = min(100, base_score + vowel_clarity_bonus)
        
        return {
            'score': round(final_score, 1),
            'quality_level': articulation.value,
            'vowel_identification': vowel_shape.value,
            'clarity_rating': self._rate_articulation_clarity(articulation)
        }
    
    def _rate_articulation_clarity(self, articulation: ArticulationQuality) -> str:
        """조음 명료도 평가"""
        ratings = {
            ArticulationQuality.EXCELLENT: "매우 명확함",
            ArticulationQuality.GOOD: "명확함",
            ArticulationQuality.FAIR: "보통",
            ArticulationQuality.POOR: "불명확함",
            ArticulationQuality.UNCLEAR: "매우 불명확함"
        }
        return ratings.get(articulation, "평가 불가")
    
    def _assess_vocal_agility(self, label: ComprehensiveVocalLabel) -> Dict:
        """성악적 민첩성 평가 (현재는 단일 프레임이므로 제한적)"""
        # 실제로는 여러 프레임에 걸친 변화를 분석해야 함
        vibrato = label.vibrato
        
        if vibrato.detected:
            agility_score = min(vibrato.rate * 10 + vibrato.regularity * 20, 80)
            agility_level = "good" if agility_score > 60 else "moderate"
        else:
            agility_score = 50  # 중간값
            agility_level = "limited"
        
        return {
            'score': round(agility_score, 1),
            'level': agility_level,
            'vibrato_control': vibrato.detected,
            'note': '전체 프레이즈 분석 시 더 정확한 평가 가능'
        }
    
    def _assess_dynamic_control(self, label: ComprehensiveVocalLabel) -> Dict:
        """다이내믹 조절 평가"""
        expression = label.expression
        
        # 다이내믹 레벨 점수화
        dynamic_scores = {
            "pp": 30, "p": 50, "mp": 70, "mf": 85, "f": 80, "ff": 70
        }
        
        base_score = dynamic_scores.get(expression.dynamics, 50)
        
        return {
            'score': base_score,
            'current_dynamic': expression.dynamics,
            'control_quality': "좋음" if base_score > 70 else "보통"
        }
    
    def _assess_phrase_shaping(self, label: ComprehensiveVocalLabel) -> Dict:
        """프레이징 형성 평가"""
        expression = label.expression
        
        return {
            'score': round(expression.phrasing_quality * 100, 1),
            'musicality': round(expression.musicality_score * 100, 1),
            'articulation_style': expression.articulation
        }
    
    def _assess_stylistic_authenticity(self, label: ComprehensiveVocalLabel) -> Dict:
        """양식적 정통성 평가 (현재는 기본 구현)"""
        # 실제로는 장르별 특성 분석 필요
        return {
            'score': 75,  # 기본값
            'style_indicators': ['register_use', 'vibrato_style'],
            'authenticity_level': 'moderate'
        }
    
    def _assess_emotional_connectivity(self, label: ComprehensiveVocalLabel) -> Dict:
        """감정적 연결성 평가"""
        # 음향적 특성으로부터 감정적 표현력 추정
        vibrato_expressiveness = 20 if label.vibrato.detected else 10
        dynamic_range = 15  # 기본값 (실제로는 더 복잡한 계산)
        articulation_expression = 15 if label.articulation_quality in [ArticulationQuality.EXCELLENT, ArticulationQuality.GOOD] else 10
        
        total_score = vibrato_expressiveness + dynamic_range + articulation_expression
        
        return {
            'score': min(total_score, 100),
            'expressiveness_factors': {
                'vibrato_use': label.vibrato.detected,
                'dynamic_variation': True,  # 기본값
                'articulation_clarity': label.articulation_quality.value
            }
        }
    
    def _assess_fatigue_resistance(self, label: ComprehensiveVocalLabel) -> float:
        """피로 저항성 평가"""
        health = label.vocal_health
        
        # 건강 지표들의 조합
        resistance = (
            (1 - health.vocal_strain) * 0.4 +
            health.breath_efficiency * 0.3 +
            health.sustainability * 0.3
        )
        
        return round(resistance, 2)
    
    def _generate_development_priorities(self, label: ComprehensiveVocalLabel) -> List[str]:
        """발전 우선순위 생성"""
        priorities = []
        
        # 음정 정확도
        if label.confidence < 0.8:
            priorities.append("pitch_accuracy")
        
        # 호흡 지지력
        if label.breath_support in [BreathSupport.WEAK, BreathSupport.POOR]:
            priorities.insert(0, "breath_support")  # 최우선
        
        # 조음 명확성
        if label.articulation_quality in [ArticulationQuality.POOR, ArticulationQuality.UNCLEAR]:
            priorities.append("articulation")
        
        # 공명 효율성
        if label.resonance_pattern.placement_score < 0.6:
            priorities.append("resonance_placement")
        
        # 음성 건강
        if label.vocal_health.risk_level == "high":
            priorities.insert(0, "vocal_health")  # 최우선
        
        return priorities[:5]  # 상위 5개만
    
    def _generate_exercise_recommendations(self, label: ComprehensiveVocalLabel) -> List[str]:
        """운동 권장사항 생성"""
        exercises = []
        
        # 호흡 관련
        if label.breath_support in [BreathSupport.WEAK, BreathSupport.POOR]:
            exercises.extend([
                "복식 호흡 연습 (하루 10분)",
                "립 트릴 (Lip trill) - 음계별 5분",
                "Hissing 운동 - 15초씩 5회"
            ])
        
        # 피치 정확도
        if label.confidence < 0.8:
            exercises.extend([
                "피아노와 함께 음계 연습",
                "슬로우 스케일 (반음계 포함)",
                "정확한 음정 귀 훈련"
            ])
        
        # 공명 개선
        if label.resonance_pattern.placement_score < 0.6:
            exercises.extend([
                "허밍 연습 (Humming) - 다양한 모음",
                "Ng 연습 - 공명 개선",
                "전진 배치 운동 (Forward placement)"
            ])
        
        # 조음 개선
        if label.articulation_quality in [ArticulationQuality.POOR, ArticulationQuality.UNCLEAR]:
            exercises.extend([
                "모음 순수성 연습 (Pure vowels)",
                "자음 명확성 훈련",
                "딕션 연습 - 시나 대사 낭독"
            ])
        
        # 비브라토 개발
        if not label.vibrato.detected and label.register != VocalRegister.CHEST:
            exercises.append("자연스러운 비브라토 개발 연습")
        
        return exercises[:8]  # 최대 8개
    
    def _calculate_overall_grade(self, label: ComprehensiveVocalLabel) -> Dict:
        """종합 등급 계산"""
        
        # 각 영역별 점수 계산
        pitch_score = label.confidence * 100
        
        breath_scores = {
            BreathSupport.EXCELLENT: 95, BreathSupport.GOOD: 80,
            BreathSupport.ADEQUATE: 65, BreathSupport.WEAK: 45, BreathSupport.POOR: 25
        }
        breath_score = breath_scores.get(label.breath_support, 50)
        
        articulation_scores = {
            ArticulationQuality.EXCELLENT: 95, ArticulationQuality.GOOD: 80,
            ArticulationQuality.FAIR: 65, ArticulationQuality.POOR: 40, ArticulationQuality.UNCLEAR: 20
        }
        articulation_score = articulation_scores.get(label.articulation_quality, 50)
        
        resonance_score = label.resonance_pattern.placement_score * 100
        health_score = (1 - label.vocal_health.vocal_strain) * 100
        
        # 가중 평균
        overall_score = (
            pitch_score * 0.25 +
            breath_score * 0.25 +
            articulation_score * 0.20 +
            resonance_score * 0.15 +
            health_score * 0.15
        )
        
        # 등급 결정
        if overall_score >= 90:
            grade = "A+"
            description = "Outstanding - 전문가 수준"
        elif overall_score >= 85:
            grade = "A"
            description = "Excellent - 우수한 실력"
        elif overall_score >= 80:
            grade = "A-"
            description = "Very Good - 매우 좋음"
        elif overall_score >= 75:
            grade = "B+"
            description = "Good - 좋은 실력"
        elif overall_score >= 70:
            grade = "B"
            description = "Above Average - 평균 이상"
        elif overall_score >= 65:
            grade = "B-"
            description = "Average - 평균적"
        elif overall_score >= 60:
            grade = "C+"
            description = "Below Average - 평균 이하"
        elif overall_score >= 55:
            grade = "C"
            description = "Fair - 보통"
        elif overall_score >= 50:
            grade = "C-"
            description = "Poor - 미흡"
        else:
            grade = "D"
            description = "Needs Significant Improvement - 대폭 개선 필요"
        
        return {
            'overall_score': round(overall_score, 1),
            'grade': grade,
            'description': description,
            'component_scores': {
                'pitch_accuracy': round(pitch_score, 1),
                'breath_support': round(breath_score, 1),
                'articulation': round(articulation_score, 1),
                'resonance': round(resonance_score, 1),
                'vocal_health': round(health_score, 1)
            }
        }

if __name__ == "__main__":
    print("🎼 Professional Vocal Analysis System")
    print("=" * 50)
    print("✅ 프로페셔널 보컬 분석기 로드 완료")
    print("✅ 발성 구역 분류 시스템 준비")
    print("✅ 음성학적 분석 도구 준비")
    print("✅ 교육학적 평가 시스템 준비")
    print("=" * 50)
    
    # 시스템 특징 출력
    analyzer = ProfessionalVocalAnalyzer()
    print("🎯 분석 기능:")
    print("  - 7가지 발성 구역 분류")
    print("  - 포먼트 기반 모음 분석")
    print("  - 비브라토 전문가 수준 분석")
    print("  - 전환음(Passaggio) 감지")
    print("  - 음성 건강 지표 평가")
    print("  - 교육학적 종합 평가")
    print("  - 개별 맞춤 연습 권장")