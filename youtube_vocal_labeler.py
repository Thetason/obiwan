#!/usr/bin/env python3
"""
YouTube 보컬 자동 라벨링 시스템
실제 YouTube URL에서 오디오를 다운로드하고 CREPE/SPICE로 분석
"""

import os
import json
import subprocess
import tempfile
import requests
import base64
import numpy as np
from datetime import datetime
import sys

# 포먼트 분석기 임포트 시도
sys.path.append('/Users/seoyeongbin/vocal_trainer_ai')
try:
    from formant_analyzer import FormantAnalyzer
    FORMANT_AVAILABLE = True
except:
    print("⚠️ 포먼트 분석기 없음 - 기본 분석만 수행")
    FORMANT_AVAILABLE = False

class YouTubeVocalLabeler:
    """YouTube 보컬 자동 라벨링 봇"""
    
    def __init__(self):
        self.crepe_url = "http://localhost:5002"
        self.spice_url = "http://localhost:5003"
        self.temp_dir = tempfile.mkdtemp(prefix="youtube_vocal_")
        print(f"📁 임시 폴더: {self.temp_dir}")
        
    def download_youtube_audio(self, youtube_url, start_time=None, duration=30):
        """
        YouTube에서 오디오 다운로드
        start_time: 시작 시간 (초)
        duration: 추출할 길이 (초)
        """
        print(f"\n📥 YouTube 다운로드 중: {youtube_url}")
        
        # 출력 파일 경로
        output_path = os.path.join(self.temp_dir, "audio_%(title)s.%(ext)s")
        
        # yt-dlp 명령어 구성
        cmd = [
            'yt-dlp',
            '-x',  # 오디오만 추출
            '--audio-format', 'wav',  # WAV 포맷
            '--audio-quality', '0',  # 최고 품질
            '-o', output_path,
            '--no-playlist',  # 재생목록 무시
            '--quiet',  # 조용히
            '--no-warnings',
        ]
        
        # 시간 범위 지정
        if start_time is not None and duration:
            # ffmpeg 후처리로 특정 구간만 추출
            postprocessor_args = [
                '-ss', str(start_time),
                '-t', str(duration),
            ]
            cmd.extend(['--postprocessor-args', ' '.join(postprocessor_args)])
            
        cmd.append(youtube_url)
        
        try:
            # yt-dlp 실행
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            
            if result.returncode != 0:
                print(f"❌ 다운로드 실패: {result.stderr}")
                return None
                
            # 다운로드된 파일 찾기
            for file in os.listdir(self.temp_dir):
                if file.endswith('.wav'):
                    full_path = os.path.join(self.temp_dir, file)
                    print(f"✅ 다운로드 완료: {file}")
                    print(f"   크기: {os.path.getsize(full_path) / 1024 / 1024:.1f} MB")
                    return full_path
                    
        except subprocess.TimeoutExpired:
            print("❌ 다운로드 시간 초과")
        except Exception as e:
            print(f"❌ 다운로드 오류: {e}")
            
        return None
        
    def analyze_with_servers(self, audio_path):
        """CREPE/SPICE 서버로 오디오 분석"""
        
        print(f"\n🔬 오디오 분석 중...")
        
        # WAV 파일 읽기
        try:
            import wave
            with wave.open(audio_path, 'rb') as wav_file:
                frames = wav_file.readframes(wav_file.getnframes())
                sample_rate = wav_file.getframerate()
                
            # numpy 배열로 변환
            audio_data = np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32768.0
            
            # 30초로 자르기
            max_samples = sample_rate * 30
            if len(audio_data) > max_samples:
                audio_data = audio_data[:max_samples]
                
            print(f"  샘플: {len(audio_data)}, 레이트: {sample_rate}Hz")
            
        except Exception as e:
            print(f"❌ 오디오 읽기 실패: {e}")
            return None
            
        # Base64 인코딩
        audio_bytes = (audio_data * 32767).astype(np.int16).tobytes()
        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
        
        results = {}
        
        # CREPE 분석
        try:
            print("  🎵 CREPE 분석...")
            response = requests.post(
                f"{self.crepe_url}/analyze",
                json={
                    "audio_base64": audio_base64,
                    "sample_rate": sample_rate
                },
                timeout=30
            )
            
            if response.status_code == 200:
                results['crepe'] = response.json()
                print(f"    ✅ CREPE 완료")
            else:
                print(f"    ❌ CREPE 오류: {response.status_code}")
                
        except Exception as e:
            print(f"    ❌ CREPE 실패: {e}")
            
        # SPICE 분석
        try:
            print("  🎵 SPICE 분석...")
            response = requests.post(
                f"{self.spice_url}/analyze",
                json={
                    "audio_base64": audio_base64,
                    "sample_rate": sample_rate
                },
                timeout=30
            )
            
            if response.status_code == 200:
                results['spice'] = response.json()
                print(f"    ✅ SPICE 완료")
                
        except Exception as e:
            print(f"    ⚠️ SPICE 건너뜀: {e}")
            
        # 포먼트 분석
        if FORMANT_AVAILABLE:
            try:
                print("  🎵 포먼트 분석...")
                analyzer = FormantAnalyzer()
                formant_result = analyzer.analyze_audio(audio_data, sample_rate)
                results['formant'] = formant_result
                print(f"    ✅ 포먼트 완료")
            except Exception as e:
                print(f"    ⚠️ 포먼트 건너뜀: {e}")
                
        return results
        
    def generate_label(self, youtube_url, analysis_results, metadata=None):
        """분석 결과로 라벨 생성"""
        
        if not analysis_results:
            return None
            
        # 기본값
        pitch_accuracy = 75.0
        vocal_technique = "unknown"
        timbre = "neutral"
        breath_support = 70.0
        
        # CREPE 데이터 처리
        if 'crepe' in analysis_results:
            crepe = analysis_results['crepe']
            if 'confidence' in crepe:
                pitch_accuracy = min(100, crepe['confidence'] * 100)
            if 'avg_frequency' in crepe:
                freq = crepe['avg_frequency']
                if freq < 250:
                    vocal_technique = 'chest'
                elif freq < 400:
                    vocal_technique = 'mix'
                else:
                    vocal_technique = 'head'
                    
        # 포먼트 데이터 처리
        if 'formant' in analysis_results:
            formant = analysis_results['formant']
            vocal_technique = formant.get('vocal_technique', vocal_technique)
            timbre = formant.get('timbre', timbre)
            breath_support = formant.get('breath_support', breath_support)
            
        # 품질 점수 계산
        overall_quality = round((pitch_accuracy + breath_support) / 40)  # 1-5
        overall_quality = max(1, min(5, overall_quality))
        
        label = {
            "id": f"yt_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            "source": {
                "type": "youtube",
                "url": youtube_url,
                "title": metadata.get('title', 'Unknown') if metadata else 'Unknown',
                "artist": metadata.get('artist', 'Unknown') if metadata else 'Unknown'
            },
            "timestamp": datetime.now().isoformat(),
            "analysis": {
                "overall_quality": overall_quality,
                "vocal_technique": vocal_technique,
                "timbre": timbre,
                "pitch_accuracy": round(pitch_accuracy, 1),
                "breath_support": round(breath_support, 1)
            },
            "confidence": {
                "overall": 0.7 if 'crepe' in analysis_results else 0.3,
                "needs_review": overall_quality <= 3
            }
        }
        
        return label
        
    def process_youtube_url(self, youtube_url, start_time=None, duration=30):
        """YouTube URL 처리 (다운로드 → 분석 → 라벨링)"""
        
        print("\n" + "=" * 60)
        print(f"🎤 YouTube 보컬 분석")
        print(f"URL: {youtube_url}")
        if start_time:
            print(f"구간: {start_time}초 ~ {start_time + duration}초")
        print("=" * 60)
        
        # 1. 다운로드
        audio_path = self.download_youtube_audio(youtube_url, start_time, duration)
        if not audio_path:
            print("❌ 다운로드 실패")
            return None
            
        # 2. 분석
        analysis = self.analyze_with_servers(audio_path)
        if not analysis:
            print("❌ 분석 실패")
            return None
            
        # 3. 메타데이터 추출
        metadata = {
            'title': os.path.basename(audio_path).replace('.wav', ''),
        }
        
        # 4. 라벨 생성
        label = self.generate_label(youtube_url, analysis, metadata)
        
        # 5. 결과 출력
        if label:
            print(f"\n✅ 라벨 생성 완료:")
            print(f"  품질: {'⭐' * label['analysis']['overall_quality']}")
            print(f"  발성: {label['analysis']['vocal_technique']}")
            print(f"  음색: {label['analysis']['timbre']}")
            print(f"  음정: {label['analysis']['pitch_accuracy']}%")
            print(f"  호흡: {label['analysis']['breath_support']}%")
            
        # 임시 파일 정리
        try:
            os.remove(audio_path)
        except:
            pass
            
        return label
        
    def batch_process_urls(self, url_list):
        """여러 YouTube URL 일괄 처리"""
        
        labels = []
        
        for i, url_info in enumerate(url_list, 1):
            if isinstance(url_info, str):
                url = url_info
                start = None
                duration = 30
            else:
                url = url_info.get('url')
                start = url_info.get('start', None)
                duration = url_info.get('duration', 30)
                
            print(f"\n[{i}/{len(url_list)}] 처리 중...")
            
            label = self.process_youtube_url(url, start, duration)
            if label:
                labels.append(label)
                
        return labels
        
    def save_labels(self, labels, output_path=None):
        """라벨 저장"""
        
        if not output_path:
            output_path = f"/Users/seoyeongbin/vocal_trainer_ai/labels/youtube_labels_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(labels, f, ensure_ascii=False, indent=2)
            
        print(f"\n💾 라벨 저장 완료: {output_path}")
        return output_path
        
    def cleanup(self):
        """임시 파일 정리"""
        try:
            import shutil
            shutil.rmtree(self.temp_dir)
            print(f"🧹 임시 폴더 삭제됨")
        except:
            pass


def main():
    """메인 실행"""
    
    # YouTube URL 리스트 (한국 발라드 예시)
    youtube_urls = [
        {
            "url": "https://www.youtube.com/watch?v=eaW1jh7p11o",  # 박효신 - 야생화
            "start": 60,  # 1분부터
            "duration": 30  # 30초간
        },
        {
            "url": "https://www.youtube.com/watch?v=Q5mB2scQpqo",  # 이소라 - 바람이 분다
            "start": 45,
            "duration": 30
        },
        {
            "url": "https://www.youtube.com/watch?v=vnS_jn2uibs",  # 아이유 - 밤편지
            "start": 30,
            "duration": 30
        }
    ]
    
    print("🤖 YouTube 보컬 자동 라벨링 시작!")
    print(f"📝 {len(youtube_urls)}개 URL 처리 예정\n")
    
    # 라벨러 생성
    labeler = YouTubeVocalLabeler()
    
    try:
        # 서버 확인
        print("🔍 서버 상태 확인...")
        try:
            r = requests.get(f"{labeler.crepe_url}/health", timeout=2)
            print(f"  ✅ CREPE 서버: 정상")
        except:
            print(f"  ⚠️ CREPE 서버: 연결 실패 (계속 진행)")
            
        try:
            r = requests.get(f"{labeler.spice_url}/health", timeout=2)
            print(f"  ✅ SPICE 서버: 정상")
        except:
            print(f"  ⚠️ SPICE 서버: 연결 실패 (계속 진행)")
            
        # 일괄 처리
        labels = labeler.batch_process_urls(youtube_urls)
        
        # 결과 저장
        if labels:
            output_path = labeler.save_labels(labels)
            
            print("\n" + "=" * 60)
            print(f"🎉 완료! {len(labels)}개 라벨 생성됨")
            print(f"📊 평균 품질: {sum(l['analysis']['overall_quality'] for l in labels) / len(labels):.1f}/5.0")
            print("=" * 60)
        else:
            print("\n❌ 라벨 생성 실패")
            
    finally:
        # 정리
        labeler.cleanup()


if __name__ == "__main__":
    main()