#!/usr/bin/env python3
"""
YouTube Auto Labeler for Obi-wan v3
자동으로 YouTube 보컬을 분석하고 라벨링하는 봇
"""

import os
import json
import subprocess
import numpy as np
from datetime import datetime
import requests
import base64
import time
from typing import Dict, List, Tuple

class YouTubeVocalLabeler:
    def __init__(self):
        self.crepe_url = "http://localhost:5002/analyze"
        self.spice_url = "http://localhost:5003/analyze"
        self.output_dir = "youtube_vocals"
        os.makedirs(self.output_dir, exist_ok=True)
        
    def extract_audio(self, youtube_url: str, start_time: float = 0, duration: float = 15) -> str:
        """YouTube에서 오디오 추출 (yt-dlp 사용)"""
        print(f"🎬 YouTube에서 오디오 추출 중: {youtube_url}")
        
        # 고유 파일명 생성
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_file = f"{self.output_dir}/audio_{timestamp}.wav"
        
        # yt-dlp로 오디오 추출 (WAV 형식, 44100Hz)
        cmd = [
            'yt-dlp',
            '-x',  # 오디오만 추출
            '--audio-format', 'wav',
            '--audio-quality', '0',  # 최고 품질
            '-o', output_file.replace('.wav', '.%(ext)s'),
            '--postprocessor-args', f'-ss {start_time} -t {duration} -ar 44100',
            youtube_url
        ]
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            if result.returncode == 0:
                print(f"✅ 오디오 추출 성공: {output_file}")
                return output_file
            else:
                print(f"❌ 추출 실패: {result.stderr}")
                return None
        except subprocess.TimeoutExpired:
            print("❌ 타임아웃: 60초 초과")
            return None
        except Exception as e:
            print(f"❌ 오류: {e}")
            return None
    
    def analyze_with_crepe_spice(self, audio_file: str) -> Dict:
        """CREPE + SPICE로 오디오 분석"""
        print(f"🎵 AI 엔진으로 분석 중: {audio_file}")
        
        # WAV 파일 읽기
        try:
            # ffmpeg로 raw PCM 데이터 추출
            cmd = [
                'ffmpeg', '-i', audio_file,
                '-f', 'f32le',  # 32-bit float PCM
                '-acodec', 'pcm_f32le',
                '-ar', '44100',  # 44.1kHz
                '-ac', '1',  # 모노
                '-'
            ]
            result = subprocess.run(cmd, capture_output=True)
            
            if result.returncode != 0:
                print(f"❌ ffmpeg 오류: {result.stderr.decode()}")
                return None
                
            # Float32 배열로 변환
            audio_data = np.frombuffer(result.stdout, dtype=np.float32)
            
            # Base64 인코딩
            audio_base64 = base64.b64encode(audio_data.tobytes()).decode('utf-8')
            
            # CREPE 분석
            crepe_response = requests.post(
                self.crepe_url,
                json={'audio_base64': audio_base64, 'sample_rate': 44100},
                timeout=30
            )
            
            # SPICE 분석 (옵션)
            spice_response = None
            try:
                spice_response = requests.post(
                    self.spice_url,
                    json={'audio_base64': audio_base64, 'sample_rate': 44100},
                    timeout=30
                )
            except:
                print("⚠️ SPICE 서버 연결 실패, CREPE만 사용")
            
            if crepe_response.status_code == 200:
                crepe_data = crepe_response.json()
                analysis = {
                    'crepe': crepe_data,
                    'spice': spice_response.json() if spice_response and spice_response.status_code == 200 else None
                }
                print("✅ AI 분석 완료")
                return analysis
            else:
                print(f"❌ CREPE 분석 실패: {crepe_response.status_code}")
                return None
                
        except Exception as e:
            print(f"❌ 분석 오류: {e}")
            return None
    
    def generate_auto_label(self, analysis: Dict, artist: str, song: str, url: str) -> Dict:
        """분석 결과를 바탕으로 자동 라벨 생성"""
        print("🏷️ 자동 라벨 생성 중...")
        
        if not analysis or 'crepe' not in analysis:
            return None
            
        crepe_data = analysis['crepe']
        
        # 피치 데이터 추출
        if isinstance(crepe_data, list):
            frequencies = [d.get('frequency', 0) for d in crepe_data if d.get('frequency', 0) > 0]
            confidences = [d.get('confidence', 0) for d in crepe_data if d.get('confidence', 0) > 0]
        else:
            frequencies = []
            confidences = []
        
        if not frequencies:
            print("❌ 유효한 피치 데이터 없음")
            return None
        
        # 통계 계산
        avg_freq = np.mean(frequencies)
        std_freq = np.std(frequencies)
        avg_confidence = np.mean(confidences) if confidences else 0.5
        
        # 자동 라벨링 (통계 기반)
        label = {
            'id': str(int(time.time() * 1000)),
            'youtubeUrl': url,
            'artistName': artist,
            'songTitle': song,
            'startTime': 0,
            'endTime': 15,
            
            # 5개 필수 라벨 자동 생성
            'overallQuality': self._calculate_quality(avg_confidence, std_freq),
            'technique': self._classify_technique(avg_freq),
            'tone': self._classify_tone(frequencies),
            'pitchAccuracy': round(avg_confidence * 100, 1),
            'breathSupport': self._estimate_breath_support(std_freq, avg_confidence),
            
            'notes': '자동 생성된 라벨 (봇)',
            'createdAt': datetime.now().isoformat(),
            'createdBy': 'auto_bot'
        }
        
        print(f"✅ 라벨 생성 완료:")
        print(f"   - 전체 품질: {'⭐' * label['overallQuality']}")
        print(f"   - 발성 기법: {label['technique']}")
        print(f"   - 음색: {label['tone']}")
        print(f"   - 음정 정확도: {label['pitchAccuracy']}%")
        print(f"   - 호흡 지지력: {label['breathSupport']}%")
        
        return label
    
    def _calculate_quality(self, confidence: float, std: float) -> int:
        """전체 품질 계산 (1-5 stars)"""
        # 신뢰도 높고 안정적(표준편차 낮음)일수록 높은 점수
        score = confidence * 3 + (1 - min(std/50, 1)) * 2
        return max(1, min(5, int(score)))
    
    def _classify_technique(self, avg_freq: float) -> str:
        """주파수 대역으로 발성 기법 분류"""
        if avg_freq < 200:
            return 'chest'
        elif avg_freq < 350:
            return 'mix'
        elif avg_freq < 500:
            return 'head'
        else:
            return 'belt'
    
    def _classify_tone(self, frequencies: List[float]) -> str:
        """주파수 분포로 음색 분류"""
        if not frequencies:
            return 'neutral'
        
        avg = np.mean(frequencies)
        if avg < 250:
            return 'dark'
        elif avg < 400:
            return 'warm'
        elif avg < 550:
            return 'neutral'
        else:
            return 'bright'
    
    def _estimate_breath_support(self, std: float, confidence: float) -> float:
        """호흡 지지력 추정 (안정성 기반)"""
        # 표준편차가 낮고 신뢰도가 높을수록 좋은 호흡
        stability = 1 - min(std/100, 1)
        return round((stability * 0.6 + confidence * 0.4) * 100, 1)
    
    def save_label(self, label: Dict):
        """라벨을 JSON 파일로 저장"""
        filename = f"{self.output_dir}/label_{label['id']}.json"
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(label, f, ensure_ascii=False, indent=2)
        print(f"💾 라벨 저장됨: {filename}")
        return filename

def test_auto_labeling():
    """테스트 실행"""
    print("🤖 YouTube 자동 라벨링 봇 테스트 시작!")
    print("=" * 50)
    
    bot = YouTubeVocalLabeler()
    
    # 테스트할 YouTube 영상 (Sam Smith - Burning)
    test_cases = [
        {
            'url': 'https://youtu.be/Df-Wo48P-M8',
            'artist': 'Sam Smith',
            'song': 'Burning',
            'start': 24,  # 24초부터
            'duration': 11  # 11초간
        }
    ]
    
    for case in test_cases:
        print(f"\n📺 처리 중: {case['artist']} - {case['song']}")
        print("-" * 40)
        
        # 1. YouTube에서 오디오 추출
        audio_file = bot.extract_audio(
            case['url'], 
            start_time=case['start'],
            duration=case['duration']
        )
        
        if not audio_file:
            print("⚠️ 오디오 추출 실패, 다음 영상으로...")
            continue
        
        # 2. CREPE/SPICE 분석
        analysis = bot.analyze_with_crepe_spice(audio_file)
        
        if not analysis:
            print("⚠️ AI 분석 실패, 다음 영상으로...")
            continue
        
        # 3. 자동 라벨 생성
        label = bot.generate_auto_label(
            analysis,
            case['artist'],
            case['song'],
            case['url']
        )
        
        if label:
            # 4. 라벨 저장
            bot.save_label(label)
            print("\n🎉 성공! 자동 라벨링 완료")
        else:
            print("\n⚠️ 라벨 생성 실패")
    
    print("\n" + "=" * 50)
    print("✅ 테스트 완료!")

if __name__ == "__main__":
    # 필요한 도구 확인
    print("🔍 필수 도구 확인 중...")
    
    # yt-dlp 설치 확인
    try:
        subprocess.run(['yt-dlp', '--version'], capture_output=True, check=True)
        print("✅ yt-dlp 설치됨")
    except:
        print("❌ yt-dlp가 설치되지 않음. 설치 중...")
        subprocess.run(['pip3', 'install', 'yt-dlp'], check=True)
    
    # ffmpeg 확인
    try:
        subprocess.run(['ffmpeg', '-version'], capture_output=True, check=True)
        print("✅ ffmpeg 설치됨")
    except:
        print("❌ ffmpeg가 필요합니다. 'brew install ffmpeg'로 설치하세요")
        exit(1)
    
    # 테스트 실행
    test_auto_labeling()