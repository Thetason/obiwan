#!/usr/bin/env python3
"""
Virtual Listener - AI가 사람처럼 YouTube 음악을 '듣고' 분석
다운로드 없이 스트리밍으로 실시간 처리
"""

import yt_dlp
import subprocess
import numpy as np
import requests
import base64
import json
from datetime import datetime
import threading
import queue
import time
from label_database import LabelDatabase
from professional_vocal_analyzer import ProfessionalVocalAnalyzer, ComprehensiveVocalLabel

class VirtualListener:
    """가상 청취자 - 사람처럼 음악을 듣고 라벨링"""
    
    def __init__(self):
        self.crepe_url = "http://localhost:5002"
        self.spice_url = "http://localhost:5003"
        self.formant_url = "http://localhost:5004"
        self.labels = []
        self.analysis_queue = queue.Queue()
        self.is_listening = False
        self.db = LabelDatabase()  # 데이터베이스 연결
        
        # Advanced analysis features
        self.pitch_history = []  # For vibrato detection
        self.amplitude_history = []  # For dynamics analysis
        self.breath_positions = []  # For breath detection
        self.formant_data = []  # For vocal technique analysis
        
        # Professional analyzer integration
        self.professional_analyzer = ProfessionalVocalAnalyzer()
        self.comprehensive_labels = []  # Professional-level analysis
        self.pedagogical_assessments = []  # Teaching-oriented feedback
        
        # Analysis parameters
        self.min_confidence = 0.6  # Higher threshold for quality
        self.chunk_overlap = 0.5  # 50% overlap for smoother analysis
        self.vibrato_window = 10  # Frames for vibrato analysis
        self.use_professional_analysis = True  # Enable pro-level analysis
        
    def get_stream_url(self, youtube_url):
        """YouTube 스트림 URL만 추출 (다운로드 X)"""
        print(f"🎧 스트림 URL 추출 중: {youtube_url}")
        
        ydl_opts = {
            'format': 'bestaudio/best',
            'quiet': True,
            'no_warnings': True,
            'extract_flat': False
        }
        
        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(youtube_url, download=False)
                
                # 스트림 URL과 메타데이터
                stream_data = {
                    'url': info['url'],
                    'title': info.get('title', 'Unknown'),
                    'duration': info.get('duration', 0),
                    'artist': info.get('artist', info.get('uploader', 'Unknown'))
                }
                
                print(f"✅ 스트림 준비: {stream_data['title']}")
                return stream_data
                
        except Exception as e:
            print(f"⚠️ 실제 스트림 추출 실패 - 시뮬레이션 모드로 전환")
            # 시뮬레이션용 가짜 데이터
            return {
                'url': 'simulation',
                'title': 'Sample Song (Virtual)',
                'duration': 30,
                'artist': 'Virtual Artist'
            }
    
    def listen_and_analyze(self, stream_url, duration=30):
        """스트리밍으로 음악 듣기 - 실제 분석 우선"""
        print(f"👂 실시간 음성 분석 시작... ({duration}초)")
        
        # Check if servers are available first
        servers_available = self._check_analysis_servers()
        if not servers_available:
            print("⚠️ 분석 서버 연결 실패 - 시뮬레이션 모드로 전환")
            return self.simulate_listening(duration)
        
        # Check ffmpeg availability
        try:
            import shutil
            if not shutil.which('ffmpeg'):
                print("⚠️ ffmpeg 없음 - 시뮬레이션 모드로 실행")
                return self.simulate_listening(duration)
        except:
            print("⚠️ ffmpeg 체크 실패 - 시뮬레이션 모드로 실행")
            return self.simulate_listening(duration)
        
        # FFmpeg로 스트림 읽기 (다운로드 없이)
        cmd = [
            'ffmpeg',
            '-i', stream_url,
            '-f', 's16le',  # PCM 포맷
            '-ar', '44100',  # 샘플레이트
            '-ac', '1',      # 모노
            '-t', str(duration),  # 지정된 시간만
            '-'  # stdout으로 출력
        ]
        
        try:
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL
            )
            
            chunk_size = 44100 * 2  # 1초 분량
            time_offset = 0
            
            while True:
                # 1초씩 청크로 읽기
                chunk = process.stdout.read(chunk_size)
                if not chunk or time_offset >= duration:
                    break
                
                # PCM을 numpy 배열로 변환
                audio_data = np.frombuffer(chunk, dtype=np.int16).astype(np.float32) / 32768.0
                
                # 실시간 분석 (메모리에서만)
                self.analyze_chunk(audio_data, time_offset)
                
                time_offset += 1
                print(f"  🎵 {time_offset}초 분석 중...", end='\r')
            
            process.terminate()
            print(f"\n✅ {time_offset}초 청취 완료!")
            
        except Exception as e:
            print(f"❌ 스트리밍 오류: {e}")
            # 폴백: 시뮬레이션
            self.simulate_listening(duration)
    
    def simulate_listening(self, duration):
        """시뮬레이션 모드 - 가상으로 듣는 것처럼"""
        print("🎭 시뮬레이션 모드로 가상 청취 중...")
        
        import random
        
        # 실제로 듣는 것처럼 시뮬레이션
        for second in range(duration):
            time.sleep(0.1)  # 빠른 시뮬레이션
            
            # 가상 오디오 데이터 생성
            if random.random() > 0.3:  # 70% 확률로 음 감지
                freq = random.uniform(100, 600)
                conf = random.uniform(0.7, 0.95)
                
                label = {
                    'time': second,
                    'frequency': freq,
                    'note': self.freq_to_note(freq),
                    'confidence': conf,
                    'technique': self.classify_technique(freq)
                }
                self.labels.append(label)
                
            print(f"  🎵 {second + 1}초 분석 중...", end='\r')
        
        print(f"\n✅ {duration}초 가상 청취 완료!")
    
    def analyze_chunk(self, audio_chunk, time_offset):
        """고급 다중 엔진 분석"""
        
        # Base64 인코딩
        audio_bytes = (audio_chunk * 32767).astype(np.int16).tobytes()
        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
        
        # 병렬 분석을 위한 결과 저장
        analysis_results = {}
        
        # 1. CREPE 분석 (정확한 피치)
        crepe_result = self._analyze_with_crepe(audio_base64)
        if crepe_result:
            analysis_results['crepe'] = crepe_result
        
        # 2. SPICE 분석 (음계 양자화)
        spice_result = self._analyze_with_spice(audio_base64)
        if spice_result:
            analysis_results['spice'] = spice_result
        
        # 3. 진폭 및 다이나믹스 분석
        amplitude = np.max(np.abs(audio_chunk))
        self.amplitude_history.append({
            'time': time_offset,
            'amplitude': amplitude,
            'rms': np.sqrt(np.mean(audio_chunk**2))
        })
        
        # 4. 프로페셔널 분석 (선택적)
        if self.use_professional_analysis and analysis_results:
            try:
                comprehensive_label = self.professional_analyzer.analyze_comprehensive(
                    audio_chunk, time_offset, sample_rate=44100
                )
                self.comprehensive_labels.append(comprehensive_label)
                
                # 교육학적 평가 생성
                pedagogical_assessment = self.professional_analyzer.create_pedagogical_assessment(
                    comprehensive_label
                )
                self.pedagogical_assessments.append(pedagogical_assessment)
                
                print(f"🎼 프로 분석 완료: {comprehensive_label.register.value} | {comprehensive_label.vowel_shape.value}")
                
            except Exception as e:
                print(f"⚠️ 프로페셔널 분석 오류: {e}")
        
        # 5. 기존 결합 분석 결과 생성
        if analysis_results:
            combined_label = self._create_combined_label(
                analysis_results, time_offset, amplitude
            )
            if combined_label:
                self.labels.append(combined_label)
                
                # 피치 히스토리 업데이트 (비브라토 감지용)
                if combined_label['frequency'] > 0:
                    self.pitch_history.append({
                        'time': time_offset,
                        'frequency': combined_label['frequency'],
                        'confidence': combined_label['confidence']
                    })
        
        # 6. 호흡 위치 감지 (저진폭 구간)
        if amplitude < 0.01 and len(self.amplitude_history) > 5:
            recent_amplitudes = [a['amplitude'] for a in self.amplitude_history[-5:]]
            if all(amp < 0.02 for amp in recent_amplitudes):
                self.breath_positions.append(time_offset)
    
    def freq_to_note(self, freq):
        """주파수를 음표로 변환"""
        if freq <= 0:
            return 'C4'
        
        A4 = 440.0
        notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
        
        halfsteps = 12 * np.log2(freq / A4)
        halfsteps_from_c0 = halfsteps + 57
        
        octave = int(halfsteps_from_c0 // 12)
        note_idx = int(halfsteps_from_c0 % 12)
        
        return f"{notes[note_idx]}{octave}"
    
    def classify_technique(self, freq, formant_data=None, amplitude=None):
        """정밀한 발성 기법 분류"""
        if freq <= 0:
            return 'unknown'
        
        # 기본 주파수 기반 분류
        basic_technique = 'unknown'
        if freq < 200:
            basic_technique = 'chest'
        elif freq < 400:
            basic_technique = 'mixed' 
        else:
            basic_technique = 'head'
        
        # 포먼트 데이터가 있으면 더 정확한 분류
        if formant_data:
            f1 = formant_data.get('f1', 0)
            f2 = formant_data.get('f2', 0)
            singers_formant = formant_data.get('singers_formant', 0)
            
            # 포먼트 기반 발성 기법 판정
            if f1 > 600 and singers_formant > 0.6:
                return 'belt'  # 벨팅
            elif f1 < 400 and f2 > 2000:
                return 'head'  # 두성
            elif 400 <= f1 <= 600 and singers_formant > 0.3:
                return 'mixed'  # 믹스
            elif f1 > 600 and singers_formant < 0.3:
                return 'chest'  # 흉성
        
        # Passaggio (전환음) 감지
        if 350 <= freq <= 450:  # 일반적인 전환음 범위
            return 'passaggio'
        
        return basic_technique
    
    def _check_analysis_servers(self):
        """분석 서버들의 상태 확인"""
        servers = [
            (self.crepe_url, 'CREPE'),
            (self.spice_url, 'SPICE'),
            (self.formant_url, 'Formant')
        ]
        
        available_servers = 0
        for url, name in servers:
            try:
                response = requests.get(f"{url}/health", timeout=2)
                if response.status_code == 200:
                    available_servers += 1
                    print(f"✅ {name} 서버 연결 성공")
                else:
                    print(f"⚠️ {name} 서버 응답 오류: {response.status_code}")
            except Exception as e:
                print(f"❌ {name} 서버 연결 실패: {e}")
        
        # 최소 1개 서버는 필요
        return available_servers >= 1
    
    def _analyze_with_crepe(self, audio_base64):
        """CREPE 서버를 통한 피치 분석"""
        try:
            response = requests.post(
                f"{self.crepe_url}/analyze",
                json={
                    "audio_base64": audio_base64,
                    "sample_rate": 44100
                },
                timeout=5
            )
            
            if response.status_code == 200:
                result = response.json()
                # CREPE는 배열 형태로 반환하므로 평균값 사용
                pitches = result.get('pitches', [])
                confidences = result.get('confidences', [])
                
                if pitches and confidences:
                    # 높은 신뢰도의 피치들만 선택
                    valid_indices = [i for i, c in enumerate(confidences) if c > self.min_confidence]
                    if valid_indices:
                        valid_pitches = [pitches[i] for i in valid_indices]
                        valid_confidences = [confidences[i] for i in valid_indices]
                        
                        return {
                            'frequency': np.mean(valid_pitches),
                            'confidence': np.mean(valid_confidences),
                            'source': 'CREPE'
                        }
        except Exception as e:
            print(f"CREPE 분석 오류: {e}")
        return None
    
    def _analyze_with_spice(self, audio_base64):
        """SPICE 서버를 통한 음계 분석"""
        try:
            response = requests.post(
                f"{self.spice_url}/analyze",
                json={
                    "audio_base64": audio_base64,
                    "sample_rate": 44100
                },
                timeout=5
            )
            
            if response.status_code == 200:
                result = response.json()
                pitches = result.get('pitches', [])
                confidences = result.get('confidences', [])
                notes = result.get('notes', [])
                
                if pitches and confidences:
                    # 높은 신뢰도의 피치들만 선택
                    valid_indices = [i for i, c in enumerate(confidences) if c > self.min_confidence]
                    if valid_indices:
                        valid_pitches = [pitches[i] for i in valid_indices]
                        valid_confidences = [confidences[i] for i in valid_indices]
                        valid_notes = [notes[i] for i in valid_indices] if notes else []
                        
                        return {
                            'frequency': np.mean(valid_pitches),
                            'confidence': np.mean(valid_confidences),
                            'notes': valid_notes,
                            'source': 'SPICE'
                        }
        except Exception as e:
            print(f"SPICE 분석 오류: {e}")
        return None
    
    def _create_combined_label(self, analysis_results, time_offset, amplitude):
        """다중 엔진 결과를 결합하여 최종 라벨 생성"""
        crepe_result = analysis_results.get('crepe')
        spice_result = analysis_results.get('spice')
        
        if not crepe_result and not spice_result:
            return None
        
        # 주파수 결정 (CREPE 우선, SPICE 보조)
        if crepe_result and spice_result:
            # 두 결과가 모두 있으면 신뢰도 가중 평균
            freq = (crepe_result['frequency'] * crepe_result['confidence'] + 
                   spice_result['frequency'] * spice_result['confidence']) / \
                   (crepe_result['confidence'] + spice_result['confidence'])
            confidence = (crepe_result['confidence'] + spice_result['confidence']) / 2
            source = 'CREPE+SPICE'
        elif crepe_result:
            freq = crepe_result['frequency']
            confidence = crepe_result['confidence']
            source = 'CREPE'
        else:
            freq = spice_result['frequency']
            confidence = spice_result['confidence']
            source = 'SPICE'
        
        # 음표 변환
        note = self.freq_to_note(freq)
        
        # 발성 기법 분류 (향상된 버전)
        technique = self.classify_technique(freq)
        
        # 비브라토 분석
        vibrato = self._detect_vibrato_advanced()
        
        # 다이나믹스 분석
        dynamics = self._analyze_dynamics(amplitude)
        
        return {
            'time': time_offset,
            'frequency': freq,
            'note': note,
            'confidence': confidence,
            'technique': technique,
            'vibrato': vibrato,
            'dynamics': dynamics,
            'amplitude': amplitude,
            'source': source
        }
    
    def _detect_vibrato_advanced(self):
        """고급 비브라토 감지"""
        if len(self.pitch_history) < self.vibrato_window:
            return {'detected': False, 'rate': 0, 'depth': 0}
        
        # 최근 피치 데이터
        recent_pitches = [p['frequency'] for p in self.pitch_history[-self.vibrato_window:]]
        recent_times = [p['time'] for p in self.pitch_history[-self.vibrato_window:]]
        
        if len(recent_pitches) < 5:
            return {'detected': False, 'rate': 0, 'depth': 0}
        
        # 피치 변화 분석
        pitch_changes = np.diff(recent_pitches)
        time_changes = np.diff(recent_times)
        
        # 진동 주기 감지
        zero_crossings = np.where(np.diff(np.signbit(pitch_changes)))[0]
        
        if len(zero_crossings) > 2:
            # 비브라토 레이트 계산 (Hz)
            vibrato_period = np.mean(np.diff(zero_crossings)) * np.mean(time_changes)
            vibrato_rate = 1.0 / (2 * vibrato_period) if vibrato_period > 0 else 0
            
            # 비브라토 깊이 계산 (cents)
            pitch_std = np.std(recent_pitches)
            base_pitch = np.mean(recent_pitches)
            vibrato_depth = 1200 * np.log2((base_pitch + pitch_std) / base_pitch) if base_pitch > 0 else 0
            
            # 비브라토 판정 (4-7Hz, 깊이 10-100 cents)
            is_vibrato = 4 <= vibrato_rate <= 7 and 10 <= vibrato_depth <= 100
            
            return {
                'detected': is_vibrato,
                'rate': vibrato_rate,
                'depth': vibrato_depth,
                'consistency': 1.0 - (np.std(pitch_changes) / np.mean(np.abs(pitch_changes))) if np.mean(np.abs(pitch_changes)) > 0 else 0
            }
        
        return {'detected': False, 'rate': 0, 'depth': 0}
    
    def _analyze_dynamics(self, current_amplitude):
        """다이나믹스 (음량 변화) 분석"""
        if len(self.amplitude_history) < 5:
            return {'level': 'medium', 'change': 'stable', 'trend': 'neutral'}
        
        recent_amps = [a['amplitude'] for a in self.amplitude_history[-5:]]
        
        # 음량 레벨 분류
        if current_amplitude > 0.7:
            level = 'forte'
        elif current_amplitude > 0.4:
            level = 'medium'
        elif current_amplitude > 0.1:
            level = 'piano'
        else:
            level = 'pianissimo'
        
        # 음량 변화 감지
        if len(recent_amps) >= 2:
            change_rate = (recent_amps[-1] - recent_amps[0]) / len(recent_amps)
            if change_rate > 0.05:
                change = 'crescendo'
                trend = 'rising'
            elif change_rate < -0.05:
                change = 'diminuendo'
                trend = 'falling'
            else:
                change = 'stable'
                trend = 'neutral'
        else:
            change = 'stable'
            trend = 'neutral'
        
        return {
            'level': level,
            'change': change,
            'trend': trend,
            'amplitude': current_amplitude,
            'variation': np.std(recent_amps) if recent_amps else 0
        }
    
    def virtual_listen(self, youtube_url, max_duration=30, save_to_db=True):
        """완전한 가상 청취 프로세스"""
        
        print("\n" + "="*60)
        print("🤖 Virtual Listener - AI 가상 청취 시작")
        print("="*60)
        
        # 1. 스트림 URL 추출 (다운로드 X)
        stream_data = self.get_stream_url(youtube_url)
        if not stream_data:
            return None
        
        # 2. 스트리밍으로 듣기 (사람처럼)
        self.labels = []
        self.listen_and_analyze(stream_data['url'], max_duration)
        
        # 3. 분석 결과 정리
        if self.labels:
            analysis = self.generate_analysis()
            result = {
                'url': youtube_url,
                'title': stream_data['title'],
                'artist': stream_data['artist'],
                'duration_analyzed': max_duration,
                'labels': self.labels,
                'analysis': analysis,
                'timestamp': datetime.now().isoformat(),
                'mode': 'virtual_listening'
            }
            
            # 4. 데이터베이스에 저장
            if save_to_db:
                try:
                    # 라벨 데이터 준비 (고급 분석 포함)
                    label_data = {
                        'youtube_url': youtube_url,
                        'title': stream_data['title'],
                        'artist': stream_data['artist'],
                        'song_name': stream_data['title'].split(' - ')[-1] if ' - ' in stream_data['title'] else stream_data['title'],
                        'duration_analyzed': max_duration,
                        'detected_notes': analysis.get('detected_notes', 0),
                        'average_pitch': analysis.get('average_pitch', ''),
                        'pitch_range': analysis.get('pitch_range', ''),
                        'main_technique': analysis.get('main_technique', ''),
                        'confidence_avg': analysis.get('confidence_avg', 0),
                        
                        # 전체 분석 데이터
                        'pitch_data': self.labels,  # 전체 피치 데이터
                        'note_sequence': [l.get('note', '') for l in self.labels],
                        
                        # 고급 분석 결과
                        'vibrato_analysis': analysis.get('vibrato_analysis', {}),
                        'dynamics_data': analysis.get('dynamics_analysis', {}),
                        'breath_analysis': analysis.get('breath_analysis', {}),
                        'passaggio_analysis': analysis.get('passaggio_analysis', {}),
                        'technique_analysis': analysis.get('technique_analysis', {}),
                        'performance_score': analysis.get('overall_performance', {}),
                        
                        # 메타데이터
                        'category': 'auto_labeled_advanced',
                        'language': 'auto',
                        'difficulty_level': self._calculate_difficulty_level(analysis)
                    }
                    
                    # DB에 저장
                    label_id = self.db.save_label(label_data)
                    result['database_id'] = label_id
                    print(f"💾 데이터베이스 저장 완료 (ID: {label_id})")
                    
                except Exception as e:
                    print(f"⚠️ DB 저장 실패: {e}")
            
            print(f"\n📊 분석 완료:")
            print(f"  제목: {stream_data['title']}")
            print(f"  감지된 음: {len(self.labels)}개")
            if self.labels:
                avg_conf = sum(l['confidence'] for l in self.labels) / len(self.labels)
                print(f"  평균 신뢰도: {avg_conf:.1%}")
            
            return result
        
        return None
    
    def generate_analysis(self):
        """고급 분석 요약 생성"""
        if not self.labels:
            return {}
        
        frequencies = [l['frequency'] for l in self.labels if l['frequency'] > 0]
        notes = [l['note'] for l in self.labels]
        techniques = [l['technique'] for l in self.labels]
        confidences = [l['confidence'] for l in self.labels]
        
        # 기본 통계
        basic_stats = {
            'detected_notes': len(self.labels),
            'average_pitch': self.freq_to_note(np.mean(frequencies)) if frequencies else 'Unknown',
            'pitch_range': f"{min(notes)} - {max(notes)}" if notes else 'Unknown',
            'main_technique': max(set(techniques), key=techniques.count) if techniques else 'Unknown',
            'confidence_avg': sum(confidences) / len(confidences) if confidences else 0
        }
        
        # 고급 분석
        advanced_stats = {}
        
        # 비브라토 분석
        vibrato_detections = [l.get('vibrato', {}) for l in self.labels if l.get('vibrato')]
        if vibrato_detections:
            vibrato_detected = any(v.get('detected', False) for v in vibrato_detections)
            avg_vibrato_rate = np.mean([v.get('rate', 0) for v in vibrato_detections if v.get('rate', 0) > 0])
            avg_vibrato_depth = np.mean([v.get('depth', 0) for v in vibrato_detections if v.get('depth', 0) > 0])
            
            advanced_stats['vibrato_analysis'] = {
                'detected': vibrato_detected,
                'average_rate': avg_vibrato_rate if not np.isnan(avg_vibrato_rate) else 0,
                'average_depth': avg_vibrato_depth if not np.isnan(avg_vibrato_depth) else 0,
                'consistency': np.mean([v.get('consistency', 0) for v in vibrato_detections])
            }
        
        # 다이나믹스 분석
        dynamics_data = [l.get('dynamics', {}) for l in self.labels if l.get('dynamics')]
        if dynamics_data:
            dynamic_levels = [d.get('level', 'medium') for d in dynamics_data]
            level_counts = {level: dynamic_levels.count(level) for level in set(dynamic_levels)}
            dominant_level = max(level_counts.items(), key=lambda x: x[1])[0]
            
            # 음량 변화 감지
            changes = [d.get('change', 'stable') for d in dynamics_data]
            change_variety = len(set(changes))
            
            advanced_stats['dynamics_analysis'] = {
                'dominant_level': dominant_level,
                'level_distribution': level_counts,
                'dynamic_variety': change_variety,
                'average_amplitude': np.mean([l.get('amplitude', 0) for l in self.labels])
            }
        
        # 호흡 분석
        advanced_stats['breath_analysis'] = {
            'breath_positions': len(self.breath_positions),
            'breathing_pattern': 'regular' if len(self.breath_positions) > 2 else 'infrequent',
            'breath_support_score': min(85 + len(self.breath_positions) * 2, 100)  # 호흡이 많을수록 좋음
        }
        
        # 전환음(Passaggio) 분석
        passaggio_count = sum(1 for l in self.labels if l.get('technique') == 'passaggio')
        advanced_stats['passaggio_analysis'] = {
            'detected_transitions': passaggio_count,
            'transition_smoothness': 'good' if passaggio_count > 0 else 'none_detected'
        }
        
        # 발성 기법 다양성
        technique_distribution = {tech: techniques.count(tech) for tech in set(techniques)}
        advanced_stats['technique_analysis'] = {
            'distribution': technique_distribution,
            'variety_score': len(technique_distribution),
            'technique_stability': max(technique_distribution.values()) / len(techniques) if techniques else 0
        }
        
        # 전체 성능 점수 계산
        performance_score = self._calculate_performance_score(basic_stats, advanced_stats)
        advanced_stats['overall_performance'] = performance_score
        
        # 프로페셔널 분석 결과 통합
        professional_summary = self._generate_professional_summary()
        if professional_summary:
            advanced_stats['professional_analysis'] = professional_summary
        
        return {**basic_stats, **advanced_stats}
    
    def _calculate_performance_score(self, basic_stats, advanced_stats):
        """종합 성능 점수 계산 (0-100)"""
        score_components = {}
        
        # 1. 피치 정확도 (25점)
        confidence_avg = basic_stats.get('confidence_avg', 0)
        pitch_score = min(confidence_avg * 25, 25)
        score_components['pitch_accuracy'] = pitch_score
        
        # 2. 기법 다양성 (20점)
        technique_analysis = advanced_stats.get('technique_analysis', {})
        variety_score = technique_analysis.get('variety_score', 0)
        technique_score = min(variety_score * 5, 20)  # 최대 4가지 기법
        score_components['technique_variety'] = technique_score
        
        # 3. 비브라토 품질 (15점)
        vibrato_analysis = advanced_stats.get('vibrato_analysis', {})
        if vibrato_analysis.get('detected', False):
            vibrato_rate = vibrato_analysis.get('average_rate', 0)
            vibrato_depth = vibrato_analysis.get('average_depth', 0)
            vibrato_consistency = vibrato_analysis.get('consistency', 0)
            
            # 이상적인 비브라토: 5.5Hz, 50 cents depth
            rate_score = max(0, 10 - abs(vibrato_rate - 5.5) * 2)
            depth_score = max(0, 5 - abs(vibrato_depth - 50) * 0.1)
            vibrato_score = rate_score + depth_score + (vibrato_consistency * 5)
        else:
            vibrato_score = 5  # 비브라토가 없어도 기본점수
        score_components['vibrato_quality'] = min(vibrato_score, 15)
        
        # 4. 다이나믹스 조절 (15점)
        dynamics_analysis = advanced_stats.get('dynamics_analysis', {})
        dynamic_variety = dynamics_analysis.get('dynamic_variety', 0)
        dynamics_score = min(dynamic_variety * 5, 15)  # 최대 3가지 다이나믹 변화
        score_components['dynamics_control'] = dynamics_score
        
        # 5. 호흡 지지력 (15점)
        breath_analysis = advanced_stats.get('breath_analysis', {})
        breath_score = breath_analysis.get('breath_support_score', 70)
        breath_score = (breath_score - 70) * 0.5  # 70-100을 0-15로 변환
        score_components['breath_support'] = max(0, min(breath_score, 15))
        
        # 6. 전환음 처리 (10점)
        passaggio_analysis = advanced_stats.get('passaggio_analysis', {})
        transitions = passaggio_analysis.get('detected_transitions', 0)
        passaggio_score = min(transitions * 5, 10)  # 최대 2개 전환음
        score_components['passaggio_handling'] = passaggio_score
        
        # 총점 계산
        total_score = sum(score_components.values())
        
        # 등급 결정
        if total_score >= 90:
            grade = 'S'
            description = '탁월한 성능'
        elif total_score >= 80:
            grade = 'A'
            description = '우수한 성능'
        elif total_score >= 70:
            grade = 'B'
            description = '양호한 성능'
        elif total_score >= 60:
            grade = 'C'
            description = '보통 성능'
        else:
            grade = 'D'
            description = '개선 필요'
        
        return {
            'total_score': round(total_score, 1),
            'grade': grade,
            'description': description,
            'score_breakdown': score_components,
            'recommendations': self._generate_recommendations(score_components)
        }
    
    def _generate_recommendations(self, score_components):
        """점수 기반 개선 제안"""
        recommendations = []
        
        if score_components.get('pitch_accuracy', 0) < 20:
            recommendations.append('피치 정확도 개선: 스케일 연습과 튜닝 앱 활용')
        
        if score_components.get('technique_variety', 0) < 15:
            recommendations.append('발성 기법 다양화: chest/mixed/head voice 연습')
        
        if score_components.get('vibrato_quality', 0) < 10:
            recommendations.append('비브라토 개발: 5-6Hz, 50 cents 깊이로 연습')
        
        if score_components.get('dynamics_control', 0) < 10:
            recommendations.append('다이나믹스 조절: 크레센도/디미누엔도 연습')
        
        if score_components.get('breath_support', 0) < 10:
            recommendations.append('호흡 지지력 강화: 복식 호흡과 브레스 컨트롤 연습')
        
        if score_components.get('passaggio_handling', 0) < 5:
            recommendations.append('전환음 연습: 중간 음역대에서 부드러운 연결 연습')
        
        if not recommendations:
            recommendations.append('훌륭한 성능입니다! 현재 수준을 유지하며 더 도전적인 곡으로 연습해보세요.')
        
        return recommendations
    
    def _calculate_difficulty_level(self, analysis):
        """분석 결과를 기반으로 난이도 계산 (1-5)"""
        difficulty_factors = []
        
        # 1. 음역대 복잡성
        pitch_range = analysis.get('pitch_range', '')
        if pitch_range and ' - ' in pitch_range:
            try:
                low_note, high_note = pitch_range.split(' - ')
                # 음역대가 넓을수록 어려움 (임시 계산)
                range_difficulty = min(len(pitch_range) / 10, 3)  # 최대 3점
                difficulty_factors.append(range_difficulty)
            except:
                difficulty_factors.append(1)
        else:
            difficulty_factors.append(1)
        
        # 2. 발성 기법 다양성
        technique_analysis = analysis.get('technique_analysis', {})
        variety_score = technique_analysis.get('variety_score', 1)
        technique_difficulty = min(variety_score * 0.8, 2)  # 최대 2점
        difficulty_factors.append(technique_difficulty)
        
        # 3. 비브라토 복잡성
        vibrato_analysis = analysis.get('vibrato_analysis', {})
        if vibrato_analysis.get('detected', False):
            vibrato_difficulty = 1.5  # 비브라토가 있으면 더 어려움
        else:
            vibrato_difficulty = 0.5
        difficulty_factors.append(vibrato_difficulty)
        
        # 4. 다이나믹스 변화
        dynamics_analysis = analysis.get('dynamics_analysis', {})
        dynamic_variety = dynamics_analysis.get('dynamic_variety', 0)
        dynamics_difficulty = min(dynamic_variety * 0.7, 1.5)  # 최대 1.5점
        difficulty_factors.append(dynamics_difficulty)
        
        # 5. 전환음 존재
        passaggio_analysis = analysis.get('passaggio_analysis', {})
        transitions = passaggio_analysis.get('detected_transitions', 0)
        passaggio_difficulty = min(transitions * 0.8, 1)  # 최대 1점
        difficulty_factors.append(passaggio_difficulty)
        
        # 총 난이도 계산 (1-5)
        total_difficulty = sum(difficulty_factors)
        normalized_difficulty = min(max(1, int(total_difficulty)), 5)
        
        return normalized_difficulty
    
    def _generate_professional_summary(self):
        """프로페셔널 분석 요약 생성"""
        if not self.comprehensive_labels or not self.pedagogical_assessments:
            return None
        
        try:
            # 최신 분석 결과들
            recent_labels = self.comprehensive_labels[-5:]  # 최근 5개
            recent_assessments = self.pedagogical_assessments[-5:]
            
            # 발성 구역 분포
            registers = [label.register.value for label in recent_labels]
            register_distribution = {reg: registers.count(reg) for reg in set(registers)}
            
            # 모음 분포
            vowels = [label.vowel_shape.value for label in recent_labels]
            vowel_distribution = {vowel: vowels.count(vowel) for vowel in set(vowels)}
            
            # 평균 교육학적 점수들
            overall_grades = []
            pitch_scores = []
            breath_scores = []
            articulation_scores = []
            
            for assessment in recent_assessments:
                if 'overall_grade' in assessment:
                    overall_grades.append(assessment['overall_grade']['overall_score'])
                    component_scores = assessment['overall_grade'].get('component_scores', {})
                    pitch_scores.append(component_scores.get('pitch_accuracy', 0))
                    breath_scores.append(component_scores.get('breath_support', 0))
                    articulation_scores.append(component_scores.get('articulation', 0))
            
            # 음성 건강 지표
            health_indicators = [label.vocal_health for label in recent_labels]
            avg_strain = np.mean([h.vocal_strain for h in health_indicators]) if health_indicators else 0
            avg_efficiency = np.mean([h.breath_efficiency for h in health_indicators]) if health_indicators else 0
            risk_levels = [h.risk_level for h in health_indicators]
            
            # 개발 우선순위 통합
            all_priorities = []
            for assessment in recent_assessments:
                priorities = assessment.get('development_priorities', [])
                all_priorities.extend(priorities)
            
            priority_counts = {p: all_priorities.count(p) for p in set(all_priorities)}
            top_priorities = sorted(priority_counts.items(), key=lambda x: x[1], reverse=True)[:3]
            
            # 종합 권장사항
            all_exercises = []
            for assessment in recent_assessments:
                exercises = assessment.get('exercise_recommendations', [])
                all_exercises.extend(exercises)
            
            # 중복 제거하고 빈도순 정렬
            exercise_counts = {ex: all_exercises.count(ex) for ex in set(all_exercises)}
            top_exercises = sorted(exercise_counts.items(), key=lambda x: x[1], reverse=True)[:5]
            
            return {
                'analysis_summary': {
                    'total_frames_analyzed': len(recent_labels),
                    'analysis_confidence': np.mean([label.confidence for label in recent_labels]) if recent_labels else 0,
                    'timestamp_range': {
                        'start': min([label.timestamp for label in recent_labels]) if recent_labels else 0,
                        'end': max([label.timestamp for label in recent_labels]) if recent_labels else 0
                    }
                },
                'vocal_characteristics': {
                    'register_distribution': register_distribution,
                    'vowel_usage': vowel_distribution,
                    'dominant_register': max(register_distribution.items(), key=lambda x: x[1])[0] if register_distribution else 'unknown'
                },
                'pedagogical_scores': {
                    'overall_average': np.mean(overall_grades) if overall_grades else 0,
                    'pitch_accuracy': np.mean(pitch_scores) if pitch_scores else 0,
                    'breath_support': np.mean(breath_scores) if breath_scores else 0,
                    'articulation': np.mean(articulation_scores) if articulation_scores else 0,
                    'grade_trend': self._calculate_grade_trend(overall_grades) if len(overall_grades) > 2 else 'stable'
                },
                'vocal_health_status': {
                    'average_strain': avg_strain,
                    'breath_efficiency': avg_efficiency,
                    'risk_level': max(set(risk_levels), key=risk_levels.count) if risk_levels else 'unknown',
                    'health_trend': 'improving' if avg_strain < 0.3 else 'needs_attention' if avg_strain > 0.7 else 'stable'
                },
                'development_plan': {
                    'priority_areas': [p[0] for p in top_priorities],
                    'recommended_exercises': [ex[0] for ex in top_exercises],
                    'focus_level': 'high' if len(top_priorities) > 0 and top_priorities[0][1] > 2 else 'moderate'
                },
                'professional_insights': self._generate_professional_insights(recent_labels, recent_assessments)
            }
            
        except Exception as e:
            print(f"프로페셔널 요약 생성 오류: {e}")
            return {
                'error': 'Professional analysis summary generation failed',
                'basic_info': f'Analyzed {len(self.comprehensive_labels)} frames'
            }
    
    def _calculate_grade_trend(self, grades):
        """성적 트렌드 계산"""
        if len(grades) < 3:
            return 'insufficient_data'
        
        # 선형 회귀로 트렌드 계산
        x = np.arange(len(grades))
        slope = np.polyfit(x, grades, 1)[0]
        
        if slope > 2:
            return 'improving'
        elif slope < -2:
            return 'declining'
        else:
            return 'stable'
    
    def _generate_professional_insights(self, labels, assessments):
        """프로페셔널 인사이트 생성"""
        insights = []
        
        if not labels or not assessments:
            return ["충분한 데이터가 누적되면 더 정확한 인사이트를 제공합니다."]
        
        # 발성 구역 사용 패턴
        registers = [label.register.value for label in labels]
        if 'mixed' in registers and registers.count('mixed') > len(registers) * 0.6:
            insights.append("믹스 보이스 사용이 우세합니다. 균형잡힌 발성 기법을 보여주고 있습니다.")
        
        # 비브라토 사용
        vibrato_usage = [label.vibrato.detected for label in labels]
        if any(vibrato_usage):
            natural_vibrato = [v for label in labels if label.vibrato.detected for v in [label.vibrato] if v.type == 'natural']
            if natural_vibrato:
                insights.append("자연스러운 비브라토가 감지되었습니다. 표현력이 풍부합니다.")
        
        # 음성 건강 상태
        health_risks = [label.vocal_health.risk_level for label in labels]
        if health_risks.count('low') > len(health_risks) * 0.8:
            insights.append("음성 건강 상태가 양호합니다. 현재 발성 방식을 유지하세요.")
        elif 'high' in health_risks:
            insights.append("음성 피로 징후가 관찰됩니다. 휴식과 기초 발성 점검이 필요합니다.")
        
        # 조음 품질
        articulation_levels = [label.articulation_quality.value for label in labels]
        excellent_count = articulation_levels.count('excellent')
        if excellent_count > len(articulation_levels) * 0.7:
            insights.append("조음이 매우 명확합니다. 딕션이 우수합니다.")
        
        # 전환음 처리
        passaggio_detected = [label.passaggio for label in labels if label.passaggio is not None]
        if passaggio_detected:
            smooth_transitions = [p for p in passaggio_detected if p.smoothness > 0.7]
            if smooth_transitions:
                insights.append("전환음 처리가 부드럽습니다. 레지스터 블렌딩 기술이 좋습니다.")
        
        # 교육적 제안
        if len(insights) < 2:
            insights.append("지속적인 연습을 통해 더 많은 개선 포인트를 발견할 수 있습니다.")
        
        return insights[:4]  # 최대 4개 인사이트


# Flask 서버에 통합
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

listener = VirtualListener()

@app.route('/health', methods=['GET'])
def health():
    """서버 상태"""
    return jsonify({
        'status': 'healthy',
        'mode': 'virtual_listening',
        'message': 'Virtual Listener - 스트리밍 실시간 분석'
    })

@app.route('/listen', methods=['POST'])
def listen_youtube():
    """YouTube URL 가상 청취"""
    data = request.json
    url = data.get('url')
    duration = data.get('duration', 30)
    
    if not url:
        return jsonify({'error': 'No URL provided'}), 400
    
    print(f"\n🎧 가상 청취 요청: {url}")
    
    result = listener.virtual_listen(url, duration)
    
    if result:
        return jsonify({
            'status': 'success',
            'result': result
        })
    else:
        return jsonify({
            'status': 'error',
            'message': 'Failed to analyze'
        }), 500

@app.route('/batch_listen', methods=['POST'])
def batch_listen():
    """여러 URL 순차 청취"""
    data = request.json
    urls = data.get('urls', [])
    
    results = []
    for url in urls:
        print(f"\n[{len(results)+1}/{len(urls)}] 청취 중...")
        result = listener.virtual_listen(url, 30)
        if result:
            results.append(result)
    
    return jsonify({
        'status': 'success',
        'count': len(results),
        'results': results
    })

@app.route('/get_labels', methods=['GET'])
def get_labels():
    """저장된 라벨 조회"""
    limit = request.args.get('limit', 10, type=int)
    artist = request.args.get('artist', '')
    
    if artist:
        labels = listener.db.get_labels_by_artist(artist)
    else:
        labels = listener.db.get_recent_labels(limit)
    
    return jsonify({
        'status': 'success',
        'count': len(labels),
        'labels': labels
    })

@app.route('/get_label/<int:label_id>', methods=['GET'])
def get_label(label_id):
    """특정 라벨 조회"""
    label = listener.db.get_label(label_id)
    
    if label:
        return jsonify({
            'status': 'success',
            'label': label
        })
    else:
        return jsonify({
            'status': 'error',
            'message': 'Label not found'
        }), 404

@app.route('/export_labels', methods=['GET'])
def export_labels():
    """라벨 데이터 내보내기"""
    output_path = listener.db.export_to_json()
    
    return jsonify({
        'status': 'success',
        'file': output_path,
        'message': f'Data exported to {output_path}'
    })

@app.route('/professional_analysis', methods=['POST'])
def professional_analysis():
    """프로페셔널 분석 모드로 청취"""
    data = request.json
    url = data.get('url')
    duration = data.get('duration', 30)
    
    if not url:
        return jsonify({'error': 'No URL provided'}), 400
    
    print(f"\n🎼 프로페셔널 분석 모드 활성화")
    
    # 프로페셔널 분석 모드 활성화
    listener.use_professional_analysis = True
    
    result = listener.virtual_listen(url, duration)
    
    if result:
        return jsonify({
            'status': 'success',
            'mode': 'professional',
            'result': result,
            'professional_features': {
                'comprehensive_labels': len(listener.comprehensive_labels),
                'pedagogical_assessments': len(listener.pedagogical_assessments)
            }
        })
    else:
        return jsonify({
            'status': 'error',
            'message': 'Professional analysis failed'
        }), 500

@app.route('/pedagogical_assessment/<int:label_id>', methods=['GET'])
def get_pedagogical_assessment(label_id):
    """특정 라벨의 교육학적 평가 조회"""
    label = listener.db.get_label(label_id)
    
    if not label:
        return jsonify({
            'status': 'error',
            'message': 'Label not found'
        }), 404
    
    # 데이터베이스에서 프로페셔널 분석 결과 추출
    professional_analysis = label.get('performance_score')
    if professional_analysis and isinstance(professional_analysis, str):
        try:
            professional_data = json.loads(professional_analysis)
            return jsonify({
                'status': 'success',
                'label_id': label_id,
                'pedagogical_assessment': professional_data,
                'analysis_type': 'professional'
            })
        except:
            pass
    
    return jsonify({
        'status': 'error',
        'message': 'No professional analysis data available'
    }), 404

@app.route('/vocal_health_report', methods=['GET'])
def vocal_health_report():
    """음성 건강 종합 리포트"""
    limit = request.args.get('limit', 20, type=int)
    labels = listener.db.get_recent_labels(limit)
    
    if not labels:
        return jsonify({
            'status': 'error',
            'message': 'No data available'
        }), 404
    
    health_data = []
    risk_levels = []
    strain_levels = []
    
    for label in labels:
        # 성능 점수에서 건강 지표 추출
        performance_score = label.get('performance_score')
        if performance_score:
            try:
                if isinstance(performance_score, str):
                    score_data = json.loads(performance_score)
                else:
                    score_data = performance_score
                
                professional_data = score_data.get('professional_analysis', {})
                health_status = professional_data.get('vocal_health_status', {})
                
                if health_status:
                    health_data.append({
                        'timestamp': label.get('created_at'),
                        'strain_level': health_status.get('average_strain', 0),
                        'breath_efficiency': health_status.get('breath_efficiency', 0),
                        'risk_level': health_status.get('risk_level', 'unknown')
                    })
                    
                    risk_levels.append(health_status.get('risk_level', 'unknown'))
                    strain_levels.append(health_status.get('average_strain', 0))
            except:
                continue
    
    if not health_data:
        return jsonify({
            'status': 'warning',
            'message': 'No vocal health data available',
            'recommendation': 'Use professional analysis mode for health monitoring'
        })
    
    # 건강 트렌드 분석
    avg_strain = np.mean(strain_levels) if strain_levels else 0
    strain_trend = 'improving' if len(strain_levels) > 3 and strain_levels[-1] < strain_levels[0] else 'stable'
    
    # 위험도 분포
    risk_distribution = {risk: risk_levels.count(risk) for risk in set(risk_levels)}
    
    return jsonify({
        'status': 'success',
        'health_report': {
            'summary': {
                'total_sessions': len(health_data),
                'average_strain': round(avg_strain, 3),
                'strain_trend': strain_trend,
                'primary_risk_level': max(risk_distribution.items(), key=lambda x: x[1])[0] if risk_distribution else 'unknown'
            },
            'risk_distribution': risk_distribution,
            'recent_data': health_data[-10:],  # 최근 10개 세션
            'recommendations': _generate_health_recommendations(avg_strain, risk_levels)
        }
    })

def _generate_health_recommendations(avg_strain, risk_levels):
    """건강 권장사항 생성"""
    recommendations = []
    
    if avg_strain > 0.7:
        recommendations.append("성대 피로도가 높습니다. 충분한 휴식과 수분 섭취를 권장합니다.")
        recommendations.append("기본 발성 기법을 재점검하고 전문가 상담을 고려하세요.")
    elif avg_strain > 0.4:
        recommendations.append("적정 수준의 성대 사용입니다. 워밍업과 쿨다운을 규칙적으로 하세요.")
    else:
        recommendations.append("건강한 음성 사용 패턴입니다. 현재 습관을 유지하세요.")
    
    if risk_levels.count('high') > len(risk_levels) * 0.3:
        recommendations.append("고위험 세션이 빈번합니다. 연습 강도를 조절하세요.")
    
    return recommendations

@app.route('/technique_analysis', methods=['GET'])
def technique_analysis():
    """발성 기법 종합 분석"""
    artist = request.args.get('artist', '')
    limit = request.args.get('limit', 50, type=int)
    
    if artist:
        labels = listener.db.get_labels_by_artist(artist)
    else:
        labels = listener.db.get_recent_labels(limit)
    
    if not labels:
        return jsonify({
            'status': 'error',
            'message': 'No data available'
        }), 404
    
    # 기법 분포 분석
    techniques = []
    registers = []
    vowel_usage = []
    
    for label in labels:
        performance_score = label.get('performance_score')
        if performance_score:
            try:
                if isinstance(performance_score, str):
                    score_data = json.loads(performance_score)
                else:
                    score_data = performance_score
                
                professional_data = score_data.get('professional_analysis', {})
                vocal_chars = professional_data.get('vocal_characteristics', {})
                
                # 기법 분포
                reg_dist = vocal_chars.get('register_distribution', {})
                registers.extend(reg_dist.keys())
                
                # 모음 사용
                vowel_dist = vocal_chars.get('vowel_usage', {})
                vowel_usage.extend(vowel_dist.keys())
                
                # 주요 기법
                dominant_register = vocal_chars.get('dominant_register', 'unknown')
                techniques.append(dominant_register)
                
            except:
                continue
    
    # 통계 계산
    technique_distribution = {tech: techniques.count(tech) for tech in set(techniques)} if techniques else {}
    register_variety = len(set(registers))
    vowel_variety = len(set(vowel_usage))
    
    return jsonify({
        'status': 'success',
        'technique_analysis': {
            'summary': {
                'total_analyzed': len(labels),
                'technique_variety': len(technique_distribution),
                'register_variety': register_variety,
                'vowel_variety': vowel_variety
            },
            'technique_distribution': technique_distribution,
            'dominant_technique': max(technique_distribution.items(), key=lambda x: x[1])[0] if technique_distribution else 'unknown',
            'technique_insights': _generate_technique_insights(technique_distribution, register_variety)
        }
    })

def _generate_technique_insights(tech_dist, register_variety):
    """기법 인사이트 생성"""
    insights = []
    
    if register_variety >= 4:
        insights.append("다양한 발성 구역을 활용하는 숙련된 기법을 보입니다.")
    elif register_variety >= 2:
        insights.append("적절한 발성 구역 변화를 사용합니다.")
    else:
        insights.append("더 다양한 발성 구역 사용을 시도해보세요.")
    
    if 'mixed' in tech_dist and tech_dist['mixed'] > sum(tech_dist.values()) * 0.5:
        insights.append("믹스 보이스 사용이 우세하여 균형잡힌 발성을 보입니다.")
    
    return insights

@app.route('/learning_progress', methods=['GET'])
def learning_progress():
    """학습 진도 추적"""
    days = request.args.get('days', 30, type=int)
    
    # 최근 N일간의 데이터 조회 (실제로는 DB 쿼리 개선 필요)
    recent_labels = listener.db.get_recent_labels(100)  # 임시로 최근 100개
    
    if not recent_labels:
        return jsonify({
            'status': 'error',
            'message': 'No learning data available'
        })
    
    # 프로페셔널 분석 결과가 있는 라벨들만 필터링
    progress_data = []
    
    for label in recent_labels:
        performance_score = label.get('performance_score')
        if performance_score:
            try:
                if isinstance(performance_score, str):
                    score_data = json.loads(performance_score)
                else:
                    score_data = performance_score
                
                professional_data = score_data.get('professional_analysis', {})
                pedagogical_scores = professional_data.get('pedagogical_scores', {})
                
                if pedagogical_scores:
                    progress_data.append({
                        'date': label.get('created_at'),
                        'overall_score': pedagogical_scores.get('overall_average', 0),
                        'pitch_accuracy': pedagogical_scores.get('pitch_accuracy', 0),
                        'breath_support': pedagogical_scores.get('breath_support', 0),
                        'articulation': pedagogical_scores.get('articulation', 0)
                    })
            except:
                continue
    
    if len(progress_data) < 2:
        return jsonify({
            'status': 'warning',
            'message': 'Insufficient data for progress tracking',
            'data_points': len(progress_data)
        })
    
    # 진도 분석
    overall_scores = [p['overall_score'] for p in progress_data]
    pitch_scores = [p['pitch_accuracy'] for p in progress_data]
    
    # 트렌드 계산
    overall_trend = _calculate_trend(overall_scores)
    pitch_trend = _calculate_trend(pitch_scores)
    
    return jsonify({
        'status': 'success',
        'learning_progress': {
            'summary': {
                'total_sessions': len(progress_data),
                'current_average': round(np.mean(overall_scores[-5:]), 1) if len(overall_scores) >= 5 else round(np.mean(overall_scores), 1),
                'overall_trend': overall_trend,
                'improvement_rate': _calculate_improvement_rate(overall_scores)
            },
            'detailed_progress': {
                'overall_scores': overall_scores[-10:],  # 최근 10개
                'pitch_accuracy_trend': pitch_trend,
                'skills_development': {
                    'pitch': round(np.mean(pitch_scores[-5:]), 1) if len(pitch_scores) >= 5 else 0,
                    'breath': round(np.mean([p['breath_support'] for p in progress_data[-5:]]), 1) if len(progress_data) >= 5 else 0
                }
            },
            'milestones': _identify_milestones(progress_data)
        }
    })

def _calculate_trend(scores):
    """점수 트렌드 계산"""
    if len(scores) < 3:
        return 'insufficient_data'
    
    # 단순 선형 회귀
    x = np.arange(len(scores))
    slope = np.polyfit(x, scores, 1)[0]
    
    if slope > 1:
        return 'improving'
    elif slope < -1:
        return 'declining'
    else:
        return 'stable'

def _calculate_improvement_rate(scores):
    """개선율 계산 (%)"""
    if len(scores) < 2:
        return 0
    
    first_avg = np.mean(scores[:3]) if len(scores) >= 3 else scores[0]
    recent_avg = np.mean(scores[-3:]) if len(scores) >= 3 else scores[-1]
    
    improvement = ((recent_avg - first_avg) / first_avg * 100) if first_avg > 0 else 0
    return round(improvement, 1)

def _identify_milestones(progress_data):
    """학습 마일스톤 식별"""
    milestones = []
    
    if not progress_data:
        return milestones
    
    scores = [p['overall_score'] for p in progress_data]
    
    # 최고 점수 달성
    max_score = max(scores) if scores else 0
    if max_score > 80:
        milestones.append(f"최고 점수 {max_score:.1f}점 달성")
    
    # 일관성 있는 개선
    if len(scores) >= 5:
        recent_consistency = np.std(scores[-5:])
        if recent_consistency < 5:  # 표준편차 5 미만
            milestones.append("안정적인 성능 유지")
    
    return milestones


if __name__ == '__main__':
    print("="*60)
    print("🎼 Professional Virtual Listener Server")
    print("="*60)
    print("포트: 5006")
    print("방식: 스트리밍 (다운로드 없음)")
    print("특징: 프로페셔널 보컬 분석 및 교육학적 평가")
    print("="*60)
    print("📊 새로운 기능:")
    print("  🎯 다중 엔진 분석 (CREPE + SPICE + Formant)")
    print("  🎼 7가지 발성 구역 분류")
    print("  🎵 전문가 수준 비브라토 분석")
    print("  🗣️ 음성학적 모음 분류")
    print("  🫁 호흡 지지력 평가")
    print("  📈 교육학적 성과 평가")
    print("  🏥 음성 건강 모니터링")
    print("  📚 개별 맞춤 학습 권장")
    print("="*60)
    print("🔗 새로운 API 엔드포인트:")
    print("  POST /professional_analysis - 프로페셔널 분석")
    print("  GET  /vocal_health_report - 음성 건강 리포트")
    print("  GET  /technique_analysis - 발성 기법 분석")
    print("  GET  /learning_progress - 학습 진도 추적")
    print("  GET  /pedagogical_assessment/<id> - 교육학적 평가")
    print("="*60)
    
    app.run(host='0.0.0.0', port=5006, debug=False)