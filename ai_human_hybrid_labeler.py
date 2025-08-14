#!/usr/bin/env python3
"""
AI-Human Hybrid Labeler
AI가 초벌구이, 인간이 시어링하는 하이브리드 시스템
"""

import json
import os
from datetime import datetime
import numpy as np
from typing import Dict, List

class HybridLabeler:
    def __init__(self):
        self.raw_labels_dir = "labels_raw"      # AI 초벌
        self.refined_labels_dir = "labels_refined"  # 인간 시어링
        self.review_queue_dir = "labels_review"     # 검토 대기
        
        for dir in [self.raw_labels_dir, self.refined_labels_dir, self.review_queue_dir]:
            os.makedirs(dir, exist_ok=True)
    
    def ai_rough_labeling(self, youtube_urls: List[Dict]) -> List[Dict]:
        """
        Step 1: AI가 초벌 라벨링 (빠르지만 부정확)
        """
        print("\n🤖 STEP 1: AI 초벌구이 시작")
        print("="*60)
        
        raw_labels = []
        
        for idx, item in enumerate(youtube_urls, 1):
            print(f"[{idx}/100] {item['artist']} - {item['song']}")
            
            # AI 분석 시뮬레이션 (실제로는 CREPE/SPICE + 포먼트)
            label = self._ai_analyze(item)
            
            # 신뢰도 계산
            confidence = self._calculate_confidence(label)
            label['ai_confidence'] = confidence
            
            # 신뢰도에 따라 분류
            if confidence > 0.8:
                label['status'] = 'high_confidence'
                print(f"  ✅ 높은 신뢰도 ({confidence:.1%})")
            elif confidence > 0.6:
                label['status'] = 'medium_confidence'
                print(f"  ⚠️  중간 신뢰도 ({confidence:.1%})")
            else:
                label['status'] = 'low_confidence'
                print(f"  ❌ 낮은 신뢰도 ({confidence:.1%}) - 검토 필요")
            
            raw_labels.append(label)
            self._save_raw_label(label)
        
        return raw_labels
    
    def human_review_interface(self, raw_labels: List[Dict]):
        """
        Step 2: 인간이 시어링 (정밀 조정)
        """
        print("\n👨‍🍳 STEP 2: 인간 시어링 인터페이스")
        print("="*60)
        
        # 신뢰도 낮은 것부터 우선 검토
        review_priority = sorted(raw_labels, key=lambda x: x['ai_confidence'])
        
        print("\n📋 검토 우선순위 (신뢰도 낮은 순):")
        print("-"*60)
        
        for idx, label in enumerate(review_priority[:20], 1):
            print(f"\n[{idx}] {label['artistName']} - {label['songTitle']}")
            print(f"   YouTube: {label['youtubeUrl']}")
            print(f"   구간: {label['startTime']}-{label['endTime']}초")
            print(f"   AI 신뢰도: {label['ai_confidence']:.1%}")
            print("\n   📊 AI 초벌 라벨:")
            print(f"   - 전체 품질: {'⭐' * label['overallQuality']}")
            print(f"   - 발성 기법: {label['technique']}")
            print(f"   - 음색: {label['tone']}")
            print(f"   - 음정 정확도: {label['pitchAccuracy']}%")
            print(f"   - 호흡 지지력: {label['breathSupport']}%")
            
            if label['ai_confidence'] < 0.6:
                print("\n   ⚠️  AI가 확신하지 못한 부분:")
                if 'uncertain_aspects' in label:
                    for aspect in label['uncertain_aspects']:
                        print(f"      - {aspect}")
            
            # 수정 제안
            print("\n   💡 검토 포인트:")
            print("   1. 발성 기법이 맞나? (chest/mix/head/belt)")
            print("   2. 음색이 정확한가? (dark/warm/neutral/bright)")
            print("   3. 품질 점수가 적절한가?")
            
            # 검토 대기 큐에 저장
            self._save_for_review(label)
    
    def _ai_analyze(self, item: Dict) -> Dict:
        """AI 분석 (포먼트 기반 개선 버전)"""
        # 시뮬레이션 - 실제로는 오디오 분석
        import random
        
        # 기본 주파수 (음높이)
        pitch = 200 + random.uniform(0, 300)
        
        # 포먼트 시뮬레이션
        f1 = 400 + random.uniform(-100, 200)
        f2 = 1500 + random.uniform(-300, 500)
        singers_formant = random.uniform(0, 1)
        
        # 포먼트 기반 발성 기법 판별
        if f1 > 600 and singers_formant < 0.3:
            technique = 'chest'
        elif f1 < 400 and f2 > 2000:
            technique = 'head'
        elif singers_formant > 0.7:
            technique = 'belt'
        else:
            technique = 'mix'
        
        # 스펙트럴 중심으로 음색 판별
        spectral_centroid = 1000 + random.uniform(0, 3000)
        if spectral_centroid < 1500:
            tone = 'dark'
        elif spectral_centroid < 2500:
            tone = 'warm'
        elif spectral_centroid < 3500:
            tone = 'neutral'
        else:
            tone = 'bright'
        
        # 신뢰도 높은 측정값들
        pitch_accuracy = 70 + random.uniform(0, 30)
        breath_support = 60 + random.uniform(0, 40)
        
        return {
            'id': f"{datetime.now().strftime('%Y%m%d%H%M%S')}_{item['artist']}",
            'youtubeUrl': item['url'],
            'artistName': item['artist'],
            'songTitle': item['song'],
            'startTime': item.get('start', 0),
            'endTime': item.get('end', 15),
            'overallQuality': min(5, max(1, int(pitch_accuracy/20))),
            'technique': technique,
            'tone': tone,
            'pitchAccuracy': round(pitch_accuracy, 1),
            'breathSupport': round(breath_support, 1),
            'createdAt': datetime.now().isoformat(),
            'createdBy': 'ai_bot',
            # 분석 메타데이터
            'analysis_metadata': {
                'f1': f1,
                'f2': f2,
                'singers_formant': singers_formant,
                'spectral_centroid': spectral_centroid,
                'base_pitch': pitch
            }
        }
    
    def _calculate_confidence(self, label: Dict) -> float:
        """AI 신뢰도 계산"""
        confidence = 0.5  # 기본값
        
        # 음정 정확도가 높으면 신뢰도 상승
        if label['pitchAccuracy'] > 90:
            confidence += 0.2
        elif label['pitchAccuracy'] > 80:
            confidence += 0.1
        
        # 메타데이터가 명확하면 신뢰도 상승
        if 'analysis_metadata' in label:
            meta = label['analysis_metadata']
            # Singer's formant가 명확하면
            if meta['singers_formant'] > 0.8 or meta['singers_formant'] < 0.2:
                confidence += 0.1
            # 포먼트가 전형적인 범위면
            if 300 < meta['f1'] < 700:
                confidence += 0.1
        
        # 불확실한 부분 표시
        uncertain = []
        if 0.4 < confidence < 0.7:
            uncertain.append("발성 기법이 애매함")
        if label['pitchAccuracy'] < 75:
            uncertain.append("음정 분석 신뢰도 낮음")
        
        if uncertain:
            label['uncertain_aspects'] = uncertain
        
        return min(1.0, confidence)
    
    def _save_raw_label(self, label: Dict):
        """AI 초벌 라벨 저장"""
        filename = f"{self.raw_labels_dir}/{label['id']}.json"
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(label, f, ensure_ascii=False, indent=2)
    
    def _save_for_review(self, label: Dict):
        """검토 대기 큐에 저장"""
        filename = f"{self.review_queue_dir}/{label['id']}_review.json"
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(label, f, ensure_ascii=False, indent=2)
    
    def generate_review_report(self, raw_labels: List[Dict]):
        """검토 보고서 생성"""
        print("\n📊 초벌 라벨링 통계 보고서")
        print("="*60)
        
        total = len(raw_labels)
        high_conf = sum(1 for l in raw_labels if l['ai_confidence'] > 0.8)
        med_conf = sum(1 for l in raw_labels if 0.6 < l['ai_confidence'] <= 0.8)
        low_conf = sum(1 for l in raw_labels if l['ai_confidence'] <= 0.6)
        
        print(f"총 라벨: {total}개")
        print(f"✅ 높은 신뢰도: {high_conf}개 ({high_conf/total:.1%})")
        print(f"⚠️  중간 신뢰도: {med_conf}개 ({med_conf/total:.1%})")
        print(f"❌ 낮은 신뢰도: {low_conf}개 ({low_conf/total:.1%})")
        
        print(f"\n🎯 인간 검토 필요: {low_conf + med_conf}개")
        print(f"⏱️  예상 검토 시간: {(low_conf + med_conf) * 30}초 ({(low_conf + med_conf) * 0.5:.0f}분)")
        
        # 발성 기법 분포
        techniques = {}
        for label in raw_labels:
            tech = label['technique']
            techniques[tech] = techniques.get(tech, 0) + 1
        
        print(f"\n📊 발성 기법 분포:")
        for tech, count in techniques.items():
            print(f"   {tech}: {count}개 ({count/total:.1%})")
        
        print("\n💡 다음 단계:")
        print("1. 낮은 신뢰도 라벨부터 검토")
        print("2. Admin Mode에서 수정")
        print("3. 수정된 라벨로 AI 재학습")

def generate_test_urls():
    """테스트용 100개 YouTube URL 생성"""
    artists = [
        'Sam Smith', 'Adele', 'Bruno Mars', 'Ed Sheeran', 'Billie Eilish',
        'Ariana Grande', 'The Weeknd', 'Dua Lipa', 'Charlie Puth', 'Shawn Mendes',
        'Taylor Swift', 'Justin Bieber', 'Olivia Rodrigo', 'Harry Styles', 'Doja Cat'
    ]
    
    urls = []
    for i in range(100):
        artist = artists[i % len(artists)]
        urls.append({
            'artist': artist,
            'song': f'Song {i+1}',
            'url': f'https://youtu.be/example_{i+1}',
            'start': 30,
            'end': 45
        })
    
    return urls

if __name__ == "__main__":
    print("🍳 AI-Human Hybrid Labeler")
    print("AI가 초벌구이, 인간이 시어링")
    print("="*60)
    
    # 하이브리드 라벨러 초기화
    labeler = HybridLabeler()
    
    # 100개 테스트 URL
    youtube_urls = generate_test_urls()
    
    print(f"\n📋 준비된 YouTube 영상: {len(youtube_urls)}개")
    print("AI 초벌 라벨링을 시작합니다...\n")
    
    # Step 1: AI 초벌구이
    raw_labels = labeler.ai_rough_labeling(youtube_urls)
    
    # Step 2: 인간 검토 인터페이스
    labeler.human_review_interface(raw_labels)
    
    # Step 3: 통계 보고서
    labeler.generate_review_report(raw_labels)
    
    print("\n✅ 초벌 라벨링 완료!")
    print("📁 파일 위치:")
    print(f"   - AI 초벌: {labeler.raw_labels_dir}/")
    print(f"   - 검토 대기: {labeler.review_queue_dir}/")
    print(f"   - 최종 라벨: {labeler.refined_labels_dir}/")
    print("\n다음 단계: Admin Mode에서 검토 대기 라벨들을 확인하고 수정하세요!")