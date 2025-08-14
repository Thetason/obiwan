#!/usr/bin/env python3
"""
Formant Analysis API Server
Flutter 앱에서 호출할 수 있는 포먼트 분석 REST API
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
import base64
import numpy as np
import tempfile
import os
import librosa
from formant_analyzer import FormantAnalyzer

app = Flask(__name__)
CORS(app)  # Flutter 웹에서 접근 가능하도록

# FormantAnalyzer 인스턴스
analyzer = FormantAnalyzer()

@app.route('/health', methods=['GET'])
def health_check():
    """서버 상태 확인"""
    return jsonify({
        'status': 'healthy',
        'service': 'Formant Analysis Server',
        'version': '1.0.0'
    })

@app.route('/analyze', methods=['POST'])
def analyze_formants():
    """
    오디오 파일의 포먼트 분석
    
    Request Body:
    {
        "audio_base64": "base64 encoded audio data",
        "sample_rate": 44100,
        "start_time": 0,
        "duration": 15
    }
    
    Response:
    {
        "formants": {
            "f1": 520.5,
            "f2": 1750.3,
            "f3": 2800.7,
            "singers_formant": 0.45
        },
        "vocal_technique": {
            "technique": "mix",
            "confidence": 0.85,
            "description": "Mix Voice: 균형잡힌 공명"
        },
        "timbre": {
            "timbre": "warm",
            "confidence": 0.78,
            "description": "중간 온도, 균형잡힌 배음"
        },
        "breath_support": {
            "score": 82,
            "interpretation": "좋은 호흡 지지력"
        }
    }
    """
    try:
        data = request.json
        
        # Base64 디코딩
        audio_base64 = data.get('audio_base64', '')
        sample_rate = data.get('sample_rate', 44100)
        start_time = data.get('start_time', 0)
        duration = data.get('duration', 15)
        
        if not audio_base64:
            return jsonify({'error': 'No audio data provided'}), 400
        
        # Base64를 오디오 데이터로 변환
        audio_bytes = base64.b64decode(audio_base64)
        
        # 임시 파일로 저장
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as tmp_file:
            tmp_file.write(audio_bytes)
            tmp_path = tmp_file.name
        
        try:
            # 포먼트 분석 수행
            result = analyzer.analyze_audio(tmp_path, start_time, duration)
            
            # 응답 데이터 구성
            response = {
                'formants': {
                    'f1': result['formants']['f1'],
                    'f2': result['formants']['f2'],
                    'f3': result['formants']['f3'],
                    'singers_formant': result['singers_formant']
                },
                'vocal_technique': result['vocal_technique'],
                'timbre': result['timbre'],
                'breath_support': result['breath_support'],
                'spectral_features': result['spectral_features'],
                'insights': result['insights']
            }
            
            return jsonify(response)
            
        finally:
            # 임시 파일 삭제
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
                
    except Exception as e:
        return jsonify({
            'error': str(e),
            'type': 'analysis_error'
        }), 500

@app.route('/analyze_simple', methods=['POST'])
def analyze_simple():
    """
    간단한 포먼트 분석 (시뮬레이션 모드)
    실제 오디오 없이 테스트용
    """
    try:
        data = request.json
        
        # 시뮬레이션 데이터 생성
        technique = data.get('expected_technique', 'mix')
        tone = data.get('expected_tone', 'warm')
        
        # 기법에 따른 포먼트 값 시뮬레이션
        if technique == 'belt':
            f1 = 750 + np.random.uniform(-30, 30)
            f2 = 1800 + np.random.uniform(-100, 100)
            singers_formant = 0.75
        elif technique == 'head':
            f1 = 320 + np.random.uniform(-20, 20)
            f2 = 2400 + np.random.uniform(-100, 100)
            singers_formant = 0.6
        elif technique == 'chest':
            f1 = 700 + np.random.uniform(-30, 30)
            f2 = 1300 + np.random.uniform(-50, 50)
            singers_formant = 0.2
        else:  # mix
            f1 = 500 + np.random.uniform(-30, 30)
            f2 = 1750 + np.random.uniform(-50, 50)
            singers_formant = 0.45
        
        # 음색에 따른 스펙트럴 중심
        if tone == 'bright':
            spectral_centroid = 3000
        elif tone == 'dark':
            spectral_centroid = 1200
        elif tone == 'warm':
            spectral_centroid = 2000
        else:  # neutral
            spectral_centroid = 2500
        
        # 포먼트 데이터
        formants = {
            'f1': f1,
            'f2': f2,
            'f3': 2800 + np.random.uniform(-200, 200),
            'singersFormant': singers_formant,
            'spectralCentroid': spectral_centroid,
            'hnr': 15
        }
        
        # 분석 수행
        vocal_technique = analyzer._classify_vocal_technique(formants, singers_formant)
        spectral_features = {
            'spectral_centroid': spectral_centroid,
            'brightness': spectral_centroid / 1000
        }
        timbre = analyzer._classify_timbre(spectral_features, formants)
        
        # 응답
        return jsonify({
            'formants': {
                'f1': f1,
                'f2': f2,
                'f3': formants['f3'],
                'singers_formant': singers_formant
            },
            'vocal_technique': vocal_technique,
            'timbre': timbre,
            'breath_support': {
                'score': 75 + np.random.uniform(0, 15),
                'interpretation': '좋은 호흡 지지력'
            },
            'spectral_features': spectral_features
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'type': 'simulation_error'
        }), 500

@app.route('/batch_analyze', methods=['POST'])
def batch_analyze():
    """
    여러 오디오 파일 일괄 분석
    """
    try:
        data = request.json
        audio_list = data.get('audio_list', [])
        
        if not audio_list:
            return jsonify({'error': 'No audio list provided'}), 400
        
        results = []
        
        for item in audio_list:
            # 각 항목 분석
            audio_base64 = item.get('audio_base64', '')
            metadata = item.get('metadata', {})
            
            if audio_base64:
                # 실제 분석 (구현 생략)
                pass
            
            # 시뮬레이션 결과 추가
            results.append({
                'id': metadata.get('id', ''),
                'artist': metadata.get('artist', ''),
                'song': metadata.get('song', ''),
                'technique': 'mix',
                'tone': 'warm',
                'confidence': 0.85
            })
        
        return jsonify({
            'results': results,
            'total': len(results)
        })
        
    except Exception as e:
        return jsonify({
            'error': str(e),
            'type': 'batch_error'
        }), 500

if __name__ == '__main__':
    print("🎵 Formant Analysis Server")
    print("=" * 40)
    print("서버 시작 중...")
    print("포트: 5004")
    print("엔드포인트:")
    print("  - GET  /health           - 서버 상태 확인")
    print("  - POST /analyze          - 포먼트 분석")
    print("  - POST /analyze_simple   - 시뮬레이션 분석")
    print("  - POST /batch_analyze    - 일괄 분석")
    print("=" * 40)
    print("Flutter 앱에서 연결 가능합니다.")
    print("중지: Ctrl+C")
    print()
    
    app.run(host='0.0.0.0', port=5004, debug=True)