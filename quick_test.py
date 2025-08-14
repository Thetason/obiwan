#!/usr/bin/env python3
"""빠른 YouTube 라벨링 테스트"""

import subprocess
import json
import os
from datetime import datetime

print("🚀 빠른 YouTube 라벨링 테스트")
print("=" * 60)

# 프리셋 URL 리스트
preset_urls = [
    {"artist": "Adele", "song": "Hello", "url": "https://www.youtube.com/watch?v=YQHsXMglC9A"},
    {"artist": "Sam Smith", "song": "Stay With Me", "url": "https://www.youtube.com/watch?v=pB-5XG-DbAA"},
    {"artist": "Bruno Mars", "song": "When I Was Your Man", "url": "https://www.youtube.com/watch?v=ekzHIouo8Q4"},
    {"artist": "아이유", "song": "밤편지", "url": "https://www.youtube.com/watch?v=BzYnNdJhZQw"},
    {"artist": "박효신", "song": "야생화", "url": "https://www.youtube.com/watch?v=_hsrsmwHv0A"},
]

print(f"✅ {len(preset_urls)}개 프리셋 URL 로드됨:")
for i, item in enumerate(preset_urls, 1):
    print(f"  {i}. {item['artist']} - {item['song']}")

# ffmpeg 확인
print("\n🔍 ffmpeg 상태 확인...")
result = subprocess.run(['which', 'ffmpeg'], capture_output=True, text=True)
if result.returncode == 0:
    print(f"✅ ffmpeg 설치됨: {result.stdout.strip()}")
    ffmpeg_ready = True
else:
    print("⚠️ ffmpeg 없음 - 시뮬레이션 모드")
    ffmpeg_ready = False

# CREPE/SPICE 서버 상태
print("\n🔍 AI 서버 상태...")
import requests
try:
    r = requests.get("http://localhost:5002/health", timeout=1)
    print("✅ CREPE 서버: 온라인")
except:
    print("⚠️ CREPE 서버: 오프라인")

try:
    r = requests.get("http://localhost:5003/health", timeout=1) 
    print("✅ SPICE 서버: 온라인")
except:
    print("⚠️ SPICE 서버: 오프라인")

# 라벨 생성 (시뮬레이션)
print("\n🤖 라벨 생성 중...")
labels = []
for url_info in preset_urls:
    label = {
        "artist": url_info["artist"],
        "song": url_info["song"],
        "url": url_info["url"],
        "quality": "⭐" * (4 if "아이유" in url_info["artist"] else 5),
        "technique": "belt" if "Adele" in url_info["artist"] else "mix",
        "timestamp": datetime.now().isoformat()
    }
    labels.append(label)
    print(f"  ✅ {url_info['artist']} - {label['quality']}")

# 결과 저장
output_dir = "/Users/seoyeongbin/vocal_trainer_ai/labels"
os.makedirs(output_dir, exist_ok=True)
output_file = f"{output_dir}/quick_test_{datetime.now().strftime('%H%M%S')}.json"

with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(labels, f, ensure_ascii=False, indent=2)

print("\n" + "=" * 60)
print(f"📊 테스트 완료!")
print(f"📁 결과: {output_file}")
print(f"🎯 총 {len(labels)}개 라벨 생성")
print("=" * 60)