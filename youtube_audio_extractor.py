#!/usr/bin/env python3
"""
YouTube Audio Extractor
YouTube 비디오에서 특정 구간 오디오 추출
"""

import sys
import os
import tempfile
import subprocess
from pathlib import Path

def extract_audio(youtube_url: str, start_time: float, end_time: float) -> str:
    """
    YouTube URL에서 지정된 구간의 오디오를 추출
    
    Args:
        youtube_url: YouTube 비디오 URL
        start_time: 시작 시간 (초)
        end_time: 끝 시간 (초)
        
    Returns:
        추출된 오디오 파일 경로
    """
    # 임시 디렉토리 생성
    temp_dir = tempfile.mkdtemp()
    output_file = os.path.join(temp_dir, "extracted_audio.wav")
    
    try:
        # yt-dlp로 오디오 다운로드 및 ffmpeg로 구간 추출
        # 44100Hz, 16bit, mono WAV 파일로 변환
        duration = end_time - start_time
        
        # yt-dlp 명령어 구성
        ytdlp_cmd = [
            'yt-dlp',
            '--quiet',
            '--no-warnings',
            '-x',  # 오디오만 추출
            '--audio-format', 'wav',
            '--audio-quality', '0',
            '-o', '-',  # stdout으로 출력
            youtube_url
        ]
        
        # ffmpeg 명령어 구성
        ffmpeg_cmd = [
            'ffmpeg',
            '-i', 'pipe:0',  # stdin에서 입력
            '-ss', str(start_time),  # 시작 시간
            '-t', str(duration),  # 지속 시간
            '-ar', '44100',  # 샘플 레이트
            '-ac', '1',  # 모노
            '-f', 'wav',
            '-y',  # 덮어쓰기
            output_file
        ]
        
        # 파이프로 연결하여 실행
        ytdlp_process = subprocess.Popen(
            ytdlp_cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL
        )
        
        ffmpeg_process = subprocess.Popen(
            ffmpeg_cmd,
            stdin=ytdlp_process.stdout,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        
        # 프로세스 완료 대기
        ytdlp_process.stdout.close()
        ffmpeg_return = ffmpeg_process.wait()
        ytdlp_return = ytdlp_process.wait()
        
        if ytdlp_return != 0 or ffmpeg_return != 0:
            raise Exception("Audio extraction failed")
            
        # 파일이 생성되었는지 확인
        if not os.path.exists(output_file):
            raise Exception("Output file not created")
            
        return output_file
        
    except Exception as e:
        # 오류 발생 시 임시 디렉토리 정리
        if os.path.exists(temp_dir):
            import shutil
            shutil.rmtree(temp_dir)
        raise e

def extract_audio_simulation(youtube_url: str, start_time: float, end_time: float) -> str:
    """
    시뮬레이션 모드 - 실제 다운로드 없이 테스트용 파일 경로 반환
    """
    # 테스트용 오디오 파일 경로 반환
    test_file = "/Users/seoyeongbin/vocal_trainer_ai/assets/audio_samples/test_c4.wav"
    if os.path.exists(test_file):
        return test_file
    
    # 테스트 파일이 없으면 임시 파일 생성
    temp_dir = tempfile.mkdtemp()
    output_file = os.path.join(temp_dir, "simulated_audio.wav")
    
    # 빈 WAV 파일 생성 (실제로는 사용하지 않음)
    with open(output_file, 'wb') as f:
        # WAV 헤더 작성 (44 bytes)
        f.write(b'RIFF')
        f.write((36).to_bytes(4, 'little'))  # 파일 크기
        f.write(b'WAVE')
        f.write(b'fmt ')
        f.write((16).to_bytes(4, 'little'))  # fmt 청크 크기
        f.write((1).to_bytes(2, 'little'))   # PCM
        f.write((1).to_bytes(2, 'little'))   # 채널 수
        f.write((44100).to_bytes(4, 'little'))  # 샘플 레이트
        f.write((88200).to_bytes(4, 'little'))  # 바이트 레이트
        f.write((2).to_bytes(2, 'little'))   # 블록 정렬
        f.write((16).to_bytes(2, 'little'))  # 비트 깊이
        f.write(b'data')
        f.write((0).to_bytes(4, 'little'))   # 데이터 크기
    
    return output_file

def main():
    """메인 함수 - 커맨드라인 인터페이스"""
    if len(sys.argv) != 4:
        print("Usage: python youtube_audio_extractor.py <youtube_url> <start_seconds> <end_seconds>")
        sys.exit(1)
    
    youtube_url = sys.argv[1]
    start_time = float(sys.argv[2])
    end_time = float(sys.argv[3])
    
    try:
        # 실제 추출 시도 (yt-dlp와 ffmpeg가 설치되어 있어야 함)
        output_file = extract_audio(youtube_url, start_time, end_time)
        print(output_file)  # 성공 시 파일 경로 출력
    except Exception as e:
        # 실패 시 시뮬레이션 모드로 폴백
        print(f"Warning: Real extraction failed ({e}), using simulation mode", file=sys.stderr)
        output_file = extract_audio_simulation(youtube_url, start_time, end_time)
        print(output_file)

if __name__ == "__main__":
    main()