#!/usr/bin/env python3
"""
Simple Auto Labeler Test - YouTube 없이 테스트
기존 오디오 파일로 자동 라벨링 시뮬레이션
"""

import json
import numpy as np
from datetime import datetime
import random

class SimpleAutoLabeler:
    def __init__(self):
        self.labels = []
        
    def simulate_analysis(self) -> dict:
        """AI 분석 시뮬레이션 (실제 값과 유사하게)"""
        # 실제 CREPE/SPICE가 반환하는 것과 유사한 데이터
        num_windows = 50
        base_freq = 220 + random.uniform(-50, 150)  # A3 주변
        
        frequencies = []
        confidences = []
        
        for i in range(num_windows):
            # 주파수는 약간씩 변동
            freq = base_freq + random.uniform(-20, 20)
            # 신뢰도는 높게 유지
            conf = 0.7 + random.uniform(0, 0.3)
            
            frequencies.append(freq)
            confidences.append(min(conf, 1.0))
        
        return {
            'frequencies': frequencies,
            'confidences': confidences,
            'avg_frequency': np.mean(frequencies),
            'std_frequency': np.std(frequencies),
            'avg_confidence': np.mean(confidences)
        }
    
    def generate_auto_label(self, artist: str, song: str, url: str) -> dict:
        """자동 라벨 생성"""
        print(f"\n🎵 분석 중: {artist} - {song}")
        
        # AI 분석 시뮬레이션
        analysis = self.simulate_analysis()
        
        # 통계 기반 자동 라벨링
        avg_freq = analysis['avg_frequency']
        std_freq = analysis['std_frequency']
        avg_conf = analysis['avg_confidence']
        
        # 전체 품질 (신뢰도와 안정성 기반)
        quality_score = avg_conf * 3 + (1 - min(std_freq/50, 1)) * 2
        quality = max(1, min(5, int(quality_score)))
        
        # 발성 기법 (주파수 대역 기반)
        if avg_freq < 200:
            technique = 'chest'
        elif avg_freq < 350:
            technique = 'mix'
        elif avg_freq < 500:
            technique = 'head'
        else:
            technique = 'belt'
        
        # 음색 (주파수 분포 기반)
        if avg_freq < 250:
            tone = 'dark'
        elif avg_freq < 400:
            tone = 'warm'
        elif avg_freq < 550:
            tone = 'neutral'
        else:
            tone = 'bright'
        
        # 음정 정확도 (신뢰도 기반)
        pitch_accuracy = round(avg_conf * 100, 1)
        
        # 호흡 지지력 (안정성 기반)
        stability = 1 - min(std_freq/100, 1)
        breath_support = round((stability * 0.6 + avg_conf * 0.4) * 100, 1)
        
        label = {
            'id': datetime.now().strftime('%Y%m%d%H%M%S'),
            'youtubeUrl': url,
            'artistName': artist,
            'songTitle': song,
            'startTime': 0,
            'endTime': 15,
            'overallQuality': quality,
            'technique': technique,
            'tone': tone,
            'pitchAccuracy': pitch_accuracy,
            'breathSupport': breath_support,
            'notes': '자동 생성된 라벨 (봇 시뮬레이션)',
            'createdAt': datetime.now().isoformat(),
            'createdBy': 'auto_bot',
            # 추가 통계 정보
            'stats': {
                'avgFrequency': round(avg_freq, 2),
                'stdFrequency': round(std_freq, 2),
                'avgConfidence': round(avg_conf, 3)
            }
        }
        
        return label
    
    def display_label(self, label: dict):
        """라벨을 보기 좋게 출력"""
        print("\n" + "="*50)
        print("🏷️  자동 생성된 라벨")
        print("="*50)
        print(f"🎤 아티스트: {label['artistName']}")
        print(f"🎵 곡명: {label['songTitle']}")
        print(f"🔗 URL: {label['youtubeUrl']}")
        print(f"⏱️  구간: {label['startTime']}초 - {label['endTime']}초")
        print("\n📊 5개 필수 라벨:")
        print(f"  1. 전체 품질: {'⭐' * label['overallQuality']} ({label['overallQuality']}/5)")
        print(f"  2. 발성 기법: {label['technique'].upper()}")
        print(f"  3. 음색: {label['tone'].upper()}")
        print(f"  4. 음정 정확도: {label['pitchAccuracy']}%")
        print(f"  5. 호흡 지지력: {label['breathSupport']}%")
        
        if 'stats' in label:
            print("\n📈 통계 정보:")
            print(f"  - 평균 주파수: {label['stats']['avgFrequency']} Hz")
            print(f"  - 주파수 표준편차: {label['stats']['stdFrequency']}")
            print(f"  - 평균 신뢰도: {label['stats']['avgConfidence']}")
        
        print("\n💾 생성 시간:", label['createdAt'])
        print("🤖 생성자:", label['createdBy'])
        print("="*50)
    
    def compare_with_manual(self, auto_label: dict, manual_label: dict):
        """수동 라벨과 자동 라벨 비교"""
        print("\n" + "="*50)
        print("🔍 수동 vs 자동 라벨 비교")
        print("="*50)
        
        print(f"항목                수동 라벨        자동 라벨        일치도")
        print("-"*60)
        
        # 전체 품질
        manual_q = manual_label['overallQuality']
        auto_q = auto_label['overallQuality']
        q_match = "✅" if manual_q == auto_q else f"Δ{abs(manual_q-auto_q)}"
        print(f"전체 품질:          {manual_q}/5            {auto_q}/5            {q_match}")
        
        # 발성 기법
        manual_t = manual_label['technique']
        auto_t = auto_label['technique']
        t_match = "✅" if manual_t == auto_t else "❌"
        print(f"발성 기법:          {manual_t:8}       {auto_t:8}       {t_match}")
        
        # 음색
        manual_tone = manual_label['tone']
        auto_tone = auto_label['tone']
        tone_match = "✅" if manual_tone == auto_tone else "❌"
        print(f"음색:               {manual_tone:8}       {auto_tone:8}       {tone_match}")
        
        # 음정 정확도
        manual_p = manual_label['pitchAccuracy']
        auto_p = auto_label['pitchAccuracy']
        p_diff = abs(manual_p - auto_p)
        p_match = "✅" if p_diff < 10 else f"Δ{p_diff:.1f}%"
        print(f"음정 정확도:        {manual_p}%         {auto_p}%         {p_match}")
        
        # 호흡 지지력
        manual_b = manual_label['breathSupport']
        auto_b = auto_label['breathSupport']
        b_diff = abs(manual_b - auto_b)
        b_match = "✅" if b_diff < 10 else f"Δ{b_diff:.1f}%"
        print(f"호흡 지지력:        {manual_b}%         {auto_b}%         {b_match}")
        
        print("="*50)
        
        # 전체 정확도 계산
        total_score = 0
        if manual_q == auto_q: total_score += 20
        elif abs(manual_q - auto_q) == 1: total_score += 10
        
        if manual_t == auto_t: total_score += 20
        if manual_tone == auto_tone: total_score += 20
        
        if p_diff < 5: total_score += 20
        elif p_diff < 10: total_score += 10
        
        if b_diff < 5: total_score += 20
        elif b_diff < 10: total_score += 10
        
        print(f"\n🎯 전체 일치도: {total_score}%")
        
        if total_score >= 80:
            print("✨ 훌륭합니다! 자동 라벨링이 매우 정확합니다.")
        elif total_score >= 60:
            print("👍 좋습니다! 자동 라벨링이 대체로 정확합니다.")
        else:
            print("🔧 개선이 필요합니다. 더 많은 학습 데이터가 필요할 수 있습니다.")

def test():
    """테스트 실행"""
    print("🤖 자동 라벨링 봇 시뮬레이션 시작!")
    print("YouTube 다운로드 없이 자동 라벨링 알고리즘을 테스트합니다.")
    
    labeler = SimpleAutoLabeler()
    
    # 테스트 케이스들
    test_cases = [
        {
            'artist': 'Sam Smith',
            'song': 'Burning',
            'url': 'https://youtu.be/Df-Wo48P-M8',
            # 수동으로 입력한 라벨 (비교용)
            'manual_label': {
                'overallQuality': 5,
                'technique': 'mix',
                'tone': 'warm',
                'pitchAccuracy': 95.0,
                'breathSupport': 90.0
            }
        },
        {
            'artist': 'Adele',
            'song': 'Hello',
            'url': 'https://youtu.be/YQHsXMglC9A',
            'manual_label': {
                'overallQuality': 5,
                'technique': 'chest',
                'tone': 'dark',
                'pitchAccuracy': 98.0,
                'breathSupport': 95.0
            }
        },
        {
            'artist': 'Bruno Mars',
            'song': 'When I Was Your Man',
            'url': 'https://youtu.be/ekzHIouo8Q4',
            'manual_label': {
                'overallQuality': 4,
                'technique': 'mix',
                'tone': 'warm',
                'pitchAccuracy': 92.0,
                'breathSupport': 85.0
            }
        }
    ]
    
    all_labels = []
    
    for case in test_cases:
        # 자동 라벨 생성
        auto_label = labeler.generate_auto_label(
            case['artist'],
            case['song'],
            case['url']
        )
        
        # 라벨 표시
        labeler.display_label(auto_label)
        
        # 수동 라벨과 비교
        if 'manual_label' in case:
            # 수동 라벨에 필요한 필드 추가
            manual = case['manual_label']
            manual.update({
                'artistName': case['artist'],
                'songTitle': case['song'],
                'youtubeUrl': case['url']
            })
            labeler.compare_with_manual(auto_label, manual)
        
        all_labels.append(auto_label)
        print("\n" + "🎵"*25 + "\n")
    
    # 전체 통계
    print("\n" + "="*50)
    print("📊 전체 자동 라벨링 통계")
    print("="*50)
    print(f"총 {len(all_labels)}개 라벨 생성")
    
    avg_quality = np.mean([l['overallQuality'] for l in all_labels])
    avg_pitch = np.mean([l['pitchAccuracy'] for l in all_labels])
    avg_breath = np.mean([l['breathSupport'] for l in all_labels])
    
    print(f"평균 품질: {avg_quality:.1f}/5")
    print(f"평균 음정 정확도: {avg_pitch:.1f}%")
    print(f"평균 호흡 지지력: {avg_breath:.1f}%")
    
    techniques = {}
    tones = {}
    for label in all_labels:
        techniques[label['technique']] = techniques.get(label['technique'], 0) + 1
        tones[label['tone']] = tones.get(label['tone'], 0) + 1
    
    print(f"\n발성 기법 분포: {techniques}")
    print(f"음색 분포: {tones}")
    
    # JSON 파일로 저장
    output_file = 'auto_labels_test.json'
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(all_labels, f, ensure_ascii=False, indent=2)
    print(f"\n💾 라벨 저장 완료: {output_file}")
    
    print("\n✅ 테스트 완료!")
    print("이제 실제 YouTube 영상으로 테스트할 준비가 되었습니다.")
    print("ffmpeg 설치 후 youtube_auto_labeler.py를 실행하세요.")

if __name__ == "__main__":
    test()