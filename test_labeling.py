#!/usr/bin/env python3
"""간단한 라벨링 테스트"""

import json
import requests
from datetime import datetime

# 서버 상태 확인
print("🔍 서버 상태 확인...")
try:
    response = requests.get("http://localhost:5002/health", timeout=2)
    print(f"✅ CREPE 서버: {response.status_code}")
except:
    print("❌ CREPE 서버 연결 실패")

try:
    response = requests.get("http://localhost:5003/health", timeout=2)
    print(f"✅ SPICE 서버: {response.status_code}")
except:
    print("❌ SPICE 서버 연결 실패")

# 시뮬레이션 라벨 생성
print("\n🤖 시뮬레이션 라벨 생성...")

labels = []
for i in range(3):
    label = {
        "id": f"test_{i}",
        "timestamp": datetime.now().isoformat(),
        "audio_name": f"test_audio_{i}.wav",
        "analysis": {
            "overall_quality": 3 + i,
            "vocal_technique": ["chest", "mix", "head"][i],
            "timbre": ["warm", "neutral", "bright"][i],
            "pitch_accuracy": 85 + i * 5,
            "breath_support": 75 + i * 8
        },
        "confidence": {
            "overall": 0.7 + i * 0.1,
            "needs_review": i == 0
        }
    }
    labels.append(label)
    
    print(f"\n📊 라벨 #{i+1}:")
    print(f"  품질: {'⭐' * label['analysis']['overall_quality']}")
    print(f"  발성: {label['analysis']['vocal_technique']}")
    print(f"  음정: {label['analysis']['pitch_accuracy']}%")

# 저장
output_path = f"/Users/seoyeongbin/vocal_trainer_ai/labels/test_labels_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"

import os
os.makedirs(os.path.dirname(output_path), exist_ok=True)

with open(output_path, 'w') as f:
    json.dump(labels, f, indent=2)
    
print(f"\n✅ 라벨 저장 완료: {output_path}")
print("\n이제 Flutter 앱에서 이 라벨을 읽어서 사용할 수 있습니다!")