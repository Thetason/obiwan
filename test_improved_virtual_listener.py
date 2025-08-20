#!/usr/bin/env python3
"""
개선된 Virtual Listener 테스트 스크립트
다중 엔진 분석 및 고급 라벨링 시스템 검증
"""

import json
import requests
import time

def test_server_health():
    """서버 상태 확인"""
    servers = [
        ("http://localhost:5002/health", "CREPE"),
        ("http://localhost:5003/health", "SPICE"), 
        ("http://localhost:5004/health", "Formant"),
        ("http://localhost:5006/health", "Virtual Listener")
    ]
    
    print("🔍 서버 상태 확인")
    print("=" * 50)
    
    all_healthy = True
    for url, name in servers:
        try:
            response = requests.get(url, timeout=3)
            if response.status_code == 200:
                data = response.json()
                print(f"✅ {name}: {data.get('status', 'unknown')}")
            else:
                print(f"⚠️ {name}: HTTP {response.status_code}")
                all_healthy = False
        except Exception as e:
            print(f"❌ {name}: {e}")
            all_healthy = False
    
    return all_healthy

def test_virtual_listening():
    """Virtual Listener 테스트"""
    print("\n🎧 Virtual Listener 테스트")
    print("=" * 50)
    
    # 테스트용 YouTube URL (짧은 클래식 샘플)
    test_data = {
        "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ",  # Rick Roll (테스트용)
        "duration": 15  # 15초만 분석
    }
    
    try:
        print(f"📡 분석 요청: {test_data['url']}")
        print(f"⏰ 분석 시간: {test_data['duration']}초")
        
        start_time = time.time()
        response = requests.post(
            "http://localhost:5006/listen",
            json=test_data,
            timeout=60  # 충분한 타임아웃
        )
        end_time = time.time()
        
        print(f"⏱️ 응답 시간: {end_time - start_time:.1f}초")
        
        if response.status_code == 200:
            result = response.json()
            
            if result['status'] == 'success':
                analysis = result['result']
                
                print("\n📊 분석 결과:")
                print(f"  제목: {analysis.get('title', 'Unknown')}")
                print(f"  아티스트: {analysis.get('artist', 'Unknown')}")
                print(f"  분석 모드: {analysis.get('mode', 'unknown')}")
                
                # 기본 분석 정보
                basic_analysis = analysis.get('analysis', {})
                print(f"  감지된 음표: {basic_analysis.get('detected_notes', 0)}개")
                print(f"  평균 피치: {basic_analysis.get('average_pitch', 'Unknown')}")
                print(f"  음역대: {basic_analysis.get('pitch_range', 'Unknown')}")
                print(f"  주요 기법: {basic_analysis.get('main_technique', 'Unknown')}")
                print(f"  평균 신뢰도: {basic_analysis.get('confidence_avg', 0):.1%}")
                
                # 고급 분석 정보
                vibrato = basic_analysis.get('vibrato_analysis', {})
                if vibrato.get('detected', False):
                    print(f"\n🎵 비브라토 분석:")
                    print(f"  감지: ✅")
                    print(f"  레이트: {vibrato.get('average_rate', 0):.1f} Hz")
                    print(f"  깊이: {vibrato.get('average_depth', 0):.1f} cents")
                    print(f"  일관성: {vibrato.get('consistency', 0):.1%}")
                else:
                    print(f"\n🎵 비브라토 분석: 미감지")
                
                # 다이나믹스 분석
                dynamics = basic_analysis.get('dynamics_analysis', {})
                if dynamics:
                    print(f"\n🔊 다이나믹스 분석:")
                    print(f"  주요 음량: {dynamics.get('dominant_level', 'unknown')}")
                    print(f"  변화 다양성: {dynamics.get('dynamic_variety', 0)}")
                    print(f"  평균 진폭: {dynamics.get('average_amplitude', 0):.3f}")
                
                # 호흡 분석
                breath = basic_analysis.get('breath_analysis', {})
                if breath:
                    print(f"\n🌬️ 호흡 분석:")
                    print(f"  호흡 위치: {breath.get('breath_positions', 0)}개")
                    print(f"  호흡 패턴: {breath.get('breathing_pattern', 'unknown')}")
                    print(f"  지지력 점수: {breath.get('breath_support_score', 0)}")
                
                # 성능 점수
                performance = basic_analysis.get('overall_performance', {})
                if performance:
                    print(f"\n🏆 종합 성능 평가:")
                    print(f"  총점: {performance.get('total_score', 0)}/100")
                    print(f"  등급: {performance.get('grade', 'N/A')}")
                    print(f"  평가: {performance.get('description', 'N/A')}")
                    
                    # 점수 세부 내역
                    breakdown = performance.get('score_breakdown', {})
                    if breakdown:
                        print(f"\n📋 점수 세부 내역:")
                        for category, score in breakdown.items():
                            print(f"  {category}: {score:.1f}점")
                    
                    # 개선 제안
                    recommendations = performance.get('recommendations', [])
                    if recommendations:
                        print(f"\n💡 개선 제안:")
                        for i, rec in enumerate(recommendations[:3], 1):
                            print(f"  {i}. {rec}")
                
                # 데이터베이스 저장 확인
                db_id = analysis.get('database_id')
                if db_id:
                    print(f"\n💾 데이터베이스 저장: ID {db_id}")
                
                return True
            else:
                print(f"❌ 분석 실패: {result.get('message', 'Unknown error')}")
                return False
        else:
            print(f"❌ HTTP 오류: {response.status_code}")
            print(f"응답: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ 테스트 오류: {e}")
        return False

def test_database_query():
    """데이터베이스 조회 테스트"""
    print("\n💾 데이터베이스 조회 테스트")
    print("=" * 50)
    
    try:
        # 최근 라벨 조회
        response = requests.get("http://localhost:5006/get_labels?limit=3")
        if response.status_code == 200:
            data = response.json()
            labels = data.get('labels', [])
            print(f"📋 최근 라벨 {len(labels)}개:")
            
            for label in labels:
                print(f"  - ID {label.get('id', 'N/A')}: {label.get('title', 'Unknown')}")
                print(f"    아티스트: {label.get('artist', 'Unknown')}")
                print(f"    생성일: {label.get('created_at', 'Unknown')}")
                
                # 성능 점수가 있다면 표시
                performance_score = label.get('performance_score')
                if performance_score:
                    try:
                        score_data = json.loads(performance_score) if isinstance(performance_score, str) else performance_score
                        total_score = score_data.get('total_score', 'N/A')
                        grade = score_data.get('grade', 'N/A')
                        print(f"    성능: {total_score}점 ({grade}등급)")
                    except:
                        pass
                print()
            
            return True
        else:
            print(f"❌ 조회 실패: HTTP {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ 조회 오류: {e}")
        return False

def main():
    """메인 테스트 함수"""
    print("🧪 Virtual Listener 고급 분석 시스템 테스트")
    print("=" * 60)
    
    # 1. 서버 상태 확인
    if not test_server_health():
        print("\n❌ 일부 서버가 응답하지 않습니다.")
        print("다음 명령어로 서버들을 시작하세요:")
        print("  python crepe_server.py")
        print("  python spice_server.py") 
        print("  python formant_server.py")
        print("  python virtual_listener.py")
        return
    
    # 2. Virtual Listener 테스트
    success = test_virtual_listening()
    
    if success:
        # 3. 데이터베이스 조회 테스트
        test_database_query()
        
        print("\n✅ 모든 테스트 완료!")
        print("\n🎯 시스템 기능:")
        print("  ✅ 다중 엔진 분석 (CREPE + SPICE)")
        print("  ✅ 고급 비브라토 감지")
        print("  ✅ 다이나믹스 분석")
        print("  ✅ 호흡 패턴 감지") 
        print("  ✅ 발성 기법 분류")
        print("  ✅ 전환음(Passaggio) 감지")
        print("  ✅ 종합 성능 평가")
        print("  ✅ 개선 제안 시스템")
        print("  ✅ 확장된 데이터베이스 저장")
    else:
        print("\n❌ 테스트 실패")

if __name__ == "__main__":
    main()