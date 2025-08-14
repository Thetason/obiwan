#!/usr/bin/env python3
"""YouTube 라벨링 시뮬레이션 - ffmpeg 없이"""

import json
from datetime import datetime

# YouTube URL 예시 (실제로는 다운로드 불가)
youtube_samples = [
    {
        "title": "Adele - Hello",
        "url": "https://www.youtube.com/watch?v=YQHsXMglC9A",
        "artist": "Adele",
        "expected_quality": 5,
        "expected_technique": "belt"
    },
    {
        "title": "Sam Smith - Stay With Me",
        "url": "https://www.youtube.com/watch?v=pB-5XG-DbAA",
        "artist": "Sam Smith",
        "expected_quality": 4,
        "expected_technique": "mix"
    },
    {
        "title": "Bruno Mars - When I Was Your Man",
        "url": "https://www.youtube.com/watch?v=ekzHIouo8Q4",
        "artist": "Bruno Mars",
        "expected_quality": 4,
        "expected_technique": "chest"
    }
]

print("🤖 YouTube 라벨링 시뮬레이션")
print("=" * 60)
print("⚠️ ffmpeg 설치 중... 시뮬레이션 모드로 실행합니다")
print("=" * 60)

labels = []

for i, sample in enumerate(youtube_samples, 1):
    print(f"\n[{i}/{len(youtube_samples)}] {sample['title']}")
    print(f"  URL: {sample['url']}")
    print(f"  아티스트: {sample['artist']}")
    
    # 시뮬레이션 라벨 생성
    label = {
        "id": f"yt_sim_{i}",
        "timestamp": datetime.now().isoformat(),
        "source": {
            "type": "youtube",
            "url": sample['url'],
            "title": sample['title'],
            "artist": sample['artist']
        },
        "analysis": {
            "overall_quality": sample['expected_quality'],
            "vocal_technique": sample['expected_technique'],
            "timbre": "warm" if sample['expected_technique'] == "chest" else "bright",
            "pitch_accuracy": 85 + sample['expected_quality'] * 2,
            "breath_support": 80 + sample['expected_quality'] * 3
        },
        "confidence": {
            "overall": 0.8,
            "needs_review": False
        },
        "note": "시뮬레이션 데이터 - ffmpeg 설치 후 실제 분석 가능"
    }
    
    labels.append(label)
    
    print(f"  ✅ 라벨 생성:")
    print(f"     품질: {'⭐' * label['analysis']['overall_quality']}")
    print(f"     발성: {label['analysis']['vocal_technique']}")
    print(f"     음정: {label['analysis']['pitch_accuracy']}%")

# 저장
output_path = f"/Users/seoyeongbin/vocal_trainer_ai/labels/youtube_sim_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"

import os
os.makedirs(os.path.dirname(output_path), exist_ok=True)

with open(output_path, 'w', encoding='utf-8') as f:
    json.dump(labels, f, ensure_ascii=False, indent=2)

print(f"\n" + "=" * 60)
print(f"✅ 시뮬레이션 완료!")
print(f"📁 라벨 저장: {output_path}")
print(f"📊 총 {len(labels)}개 라벨 생성")
print("=" * 60)

print("\n💡 실제 YouTube 다운로드를 위해서는:")
print("1. ffmpeg 설치 완료 대기")
print("2. brew install ffmpeg")
print("3. python3 youtube_vocal_labeler.py 실행")

print("\n🎯 현재 가능한 작업:")
print("- Flutter 앱에서 시뮬레이션 라벨 확인")
print("- 라벨 구조 및 형식 검증")
print("- UI/UX 테스트")