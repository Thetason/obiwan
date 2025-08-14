#!/usr/bin/env python3
"""간단한 YouTube 테스트"""

import subprocess
import os

# 테스트용 YouTube URL (공개 음악)
test_url = "https://www.youtube.com/watch?v=YQHsXMglC9A"  # Adele - Hello

print("🎵 YouTube 오디오 다운로드 테스트")
print(f"URL: {test_url}\n")

# yt-dlp 명령어 (ffmpeg 없이 시도)
cmd = [
    'yt-dlp',
    '--extract-audio',  # 오디오만
    '--audio-format', 'best',  # 가능한 최고 포맷
    '--no-playlist',
    '-o', '/tmp/test_audio.%(ext)s',
    test_url
]

print("📥 다운로드 시작...")
try:
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    
    if result.returncode == 0:
        print("✅ 다운로드 성공!")
        print("\n다운로드된 파일:")
        for f in os.listdir('/tmp'):
            if f.startswith('test_audio'):
                path = f'/tmp/{f}'
                size = os.path.getsize(path) / 1024 / 1024
                print(f"  - {f} ({size:.1f} MB)")
                
                # 파일 타입 확인
                file_cmd = ['file', path]
                file_result = subprocess.run(file_cmd, capture_output=True, text=True)
                print(f"    타입: {file_result.stdout.strip()}")
    else:
        print(f"❌ 다운로드 실패:")
        print(result.stderr)
        
except subprocess.TimeoutExpired:
    print("❌ 시간 초과")
except Exception as e:
    print(f"❌ 오류: {e}")

print("\n💡 ffmpeg 설치 확인...")
ffmpeg_check = subprocess.run(['which', 'ffmpeg'], capture_output=True, text=True)
if ffmpeg_check.returncode == 0:
    print(f"✅ ffmpeg 설치됨: {ffmpeg_check.stdout.strip()}")
else:
    print("❌ ffmpeg 없음 - brew install ffmpeg 필요")
    
    # brew 설치 상태 확인
    brew_check = subprocess.run(['brew', 'list', 'ffmpeg'], capture_output=True, text=True)
    if 'ffmpeg' in brew_check.stdout:
        print("  ⚠️ ffmpeg가 brew에 있지만 PATH에 없음")
        print("  실행: export PATH=/opt/homebrew/bin:$PATH")