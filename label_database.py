#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
🎵 오비완 v3 - 라벨링 데이터베이스
YouTube 음악을 들은 데이터를 저장하고 관리하는 시스템
"""

import json
import sqlite3
from datetime import datetime
from pathlib import Path
import numpy as np
from typing import List, Dict, Optional

class LabelDatabase:
    def __init__(self, db_path: str = "vocal_labels.db"):
        """라벨링 데이터베이스 초기화"""
        self.db_path = Path(db_path)
        self.conn = None
        self.init_database()
    
    def init_database(self):
        """데이터베이스 초기화 및 테이블 생성"""
        self.conn = sqlite3.connect(str(self.db_path), check_same_thread=False)
        cursor = self.conn.cursor()
        
        # 라벨 테이블 생성
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS vocal_labels (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                youtube_url TEXT NOT NULL,
                title TEXT,
                artist TEXT,
                song_name TEXT,
                duration_analyzed REAL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                
                -- 음성 분석 데이터
                detected_notes INTEGER,
                average_pitch REAL,
                pitch_range TEXT,
                main_technique TEXT,
                confidence_avg REAL,
                
                -- 상세 분석 데이터 (JSON)
                pitch_data TEXT,
                note_sequence TEXT,
                vibrato_analysis TEXT,
                dynamics_data TEXT,
                breath_analysis TEXT,
                passaggio_analysis TEXT,
                technique_analysis TEXT,
                performance_score TEXT,
                
                -- 메타데이터
                category TEXT,
                difficulty_level INTEGER,
                genre TEXT,
                language TEXT,
                user_rating REAL,
                notes TEXT
            )
        ''')
        
        # 학습 세션 테이블
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS learning_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                label_id INTEGER,
                user_id TEXT,
                session_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                practice_duration REAL,
                accuracy_score REAL,
                pitch_match_score REAL,
                timing_score REAL,
                expression_score REAL,
                notes TEXT,
                FOREIGN KEY (label_id) REFERENCES vocal_labels (id)
            )
        ''')
        
        # 인덱스 생성
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_youtube_url ON vocal_labels(youtube_url)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_artist ON vocal_labels(artist)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_created_at ON vocal_labels(created_at)')
        
        self.conn.commit()
        print("✅ 라벨링 데이터베이스 초기화 완료")
    
    def save_label(self, label_data: Dict) -> int:
        """라벨 데이터 저장"""
        cursor = self.conn.cursor()
        
        # JSON 데이터 직렬화
        pitch_data = json.dumps(label_data.get('pitch_data', []))
        note_sequence = json.dumps(label_data.get('note_sequence', []))
        vibrato_analysis = json.dumps(label_data.get('vibrato_analysis', {}))
        dynamics_data = json.dumps(label_data.get('dynamics_data', {}))
        breath_analysis = json.dumps(label_data.get('breath_analysis', {}))
        passaggio_analysis = json.dumps(label_data.get('passaggio_analysis', {}))
        technique_analysis = json.dumps(label_data.get('technique_analysis', {}))
        performance_score = json.dumps(label_data.get('performance_score', {}))
        
        cursor.execute('''
            INSERT INTO vocal_labels (
                youtube_url, title, artist, song_name, duration_analyzed,
                detected_notes, average_pitch, pitch_range, main_technique, confidence_avg,
                pitch_data, note_sequence, vibrato_analysis, dynamics_data,
                breath_analysis, passaggio_analysis, technique_analysis, performance_score,
                category, difficulty_level, genre, language
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            label_data.get('youtube_url', ''),
            label_data.get('title', ''),
            label_data.get('artist', ''),
            label_data.get('song_name', ''),
            label_data.get('duration_analyzed', 30),
            label_data.get('detected_notes', 0),
            label_data.get('average_pitch', 0),
            label_data.get('pitch_range', ''),
            label_data.get('main_technique', ''),
            label_data.get('confidence_avg', 0),
            pitch_data,
            note_sequence,
            vibrato_analysis,
            dynamics_data,
            breath_analysis,
            passaggio_analysis,
            technique_analysis,
            performance_score,
            label_data.get('category', ''),
            label_data.get('difficulty_level', 1),
            label_data.get('genre', ''),
            label_data.get('language', 'ko')
        ))
        
        self.conn.commit()
        label_id = cursor.lastrowid
        print(f"💾 라벨 저장 완료 (ID: {label_id})")
        return label_id
    
    def get_label(self, label_id: int) -> Optional[Dict]:
        """라벨 ID로 데이터 조회"""
        cursor = self.conn.cursor()
        cursor.execute('SELECT * FROM vocal_labels WHERE id = ?', (label_id,))
        row = cursor.fetchone()
        
        if row:
            return self._row_to_dict(cursor, row)
        return None
    
    def get_labels_by_artist(self, artist: str) -> List[Dict]:
        """아티스트별 라벨 조회"""
        cursor = self.conn.cursor()
        cursor.execute('SELECT * FROM vocal_labels WHERE artist LIKE ?', (f'%{artist}%',))
        rows = cursor.fetchall()
        
        return [self._row_to_dict(cursor, row) for row in rows]
    
    def get_recent_labels(self, limit: int = 10) -> List[Dict]:
        """최근 라벨 조회"""
        cursor = self.conn.cursor()
        cursor.execute('''
            SELECT * FROM vocal_labels 
            ORDER BY created_at DESC 
            LIMIT ?
        ''', (limit,))
        rows = cursor.fetchall()
        
        return [self._row_to_dict(cursor, row) for row in rows]
    
    def save_learning_session(self, session_data: Dict) -> int:
        """학습 세션 저장"""
        cursor = self.conn.cursor()
        
        cursor.execute('''
            INSERT INTO learning_sessions (
                label_id, user_id, practice_duration,
                accuracy_score, pitch_match_score, timing_score, expression_score,
                notes
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            session_data.get('label_id'),
            session_data.get('user_id', 'default'),
            session_data.get('practice_duration', 0),
            session_data.get('accuracy_score', 0),
            session_data.get('pitch_match_score', 0),
            session_data.get('timing_score', 0),
            session_data.get('expression_score', 0),
            session_data.get('notes', '')
        ))
        
        self.conn.commit()
        session_id = cursor.lastrowid
        print(f"📚 학습 세션 저장 완료 (ID: {session_id})")
        return session_id
    
    def get_learning_stats(self, label_id: int) -> Dict:
        """라벨별 학습 통계"""
        cursor = self.conn.cursor()
        
        cursor.execute('''
            SELECT 
                COUNT(*) as total_sessions,
                AVG(practice_duration) as avg_duration,
                AVG(accuracy_score) as avg_accuracy,
                AVG(pitch_match_score) as avg_pitch_match,
                MAX(accuracy_score) as best_accuracy
            FROM learning_sessions
            WHERE label_id = ?
        ''', (label_id,))
        
        row = cursor.fetchone()
        if row:
            return {
                'total_sessions': row[0],
                'avg_duration': row[1] or 0,
                'avg_accuracy': row[2] or 0,
                'avg_pitch_match': row[3] or 0,
                'best_accuracy': row[4] or 0
            }
        return {}
    
    def export_to_json(self, output_path: str = "vocal_labels_export.json"):
        """전체 데이터 JSON으로 내보내기"""
        labels = self.get_recent_labels(limit=1000)
        
        export_data = {
            'export_date': datetime.now().isoformat(),
            'total_labels': len(labels),
            'labels': labels
        }
        
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(export_data, f, ensure_ascii=False, indent=2)
        
        print(f"📤 데이터 내보내기 완료: {output_path}")
        return output_path
    
    def _row_to_dict(self, cursor, row) -> Dict:
        """SQLite row를 딕셔너리로 변환"""
        columns = [column[0] for column in cursor.description]
        data = dict(zip(columns, row))
        
        # JSON 필드 파싱
        if data.get('pitch_data'):
            data['pitch_data'] = json.loads(data['pitch_data'])
        if data.get('note_sequence'):
            data['note_sequence'] = json.loads(data['note_sequence'])
        if data.get('vibrato_analysis'):
            data['vibrato_analysis'] = json.loads(data['vibrato_analysis'])
        if data.get('dynamics_data'):
            data['dynamics_data'] = json.loads(data['dynamics_data'])
        
        return data
    
    def close(self):
        """데이터베이스 연결 종료"""
        if self.conn:
            self.conn.close()
            print("🔒 데이터베이스 연결 종료")


# 테스트 및 예제
if __name__ == "__main__":
    # 데이터베이스 생성
    db = LabelDatabase()
    
    # 샘플 라벨 데이터
    sample_label = {
        'youtube_url': 'https://youtu.be/example',
        'title': 'Adele - Hello',
        'artist': 'Adele',
        'song_name': 'Hello',
        'duration_analyzed': 30,
        'detected_notes': 24,
        'average_pitch': 220.5,
        'pitch_range': 'A3-E5',
        'main_technique': 'Chest Voice',
        'confidence_avg': 0.85,
        'pitch_data': [
            {'time': 0.5, 'pitch': 220.0, 'note': 'A3', 'confidence': 0.9},
            {'time': 1.0, 'pitch': 246.9, 'note': 'B3', 'confidence': 0.87}
        ],
        'note_sequence': ['A3', 'B3', 'C4', 'D4', 'E4'],
        'category': 'Pop Ballad',
        'difficulty_level': 3,
        'genre': 'Pop',
        'language': 'en'
    }
    
    # 라벨 저장
    label_id = db.save_label(sample_label)
    
    # 라벨 조회
    retrieved = db.get_label(label_id)
    print(f"\n📖 저장된 라벨: {retrieved['title']}")
    
    # 최근 라벨 조회
    recent = db.get_recent_labels(5)
    print(f"\n📋 최근 라벨 {len(recent)}개")
    
    # JSON 내보내기
    db.export_to_json()
    
    db.close()