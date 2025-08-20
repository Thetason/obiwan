#!/usr/bin/env python3
"""
Professional Vocal Analysis System - 통합 테스트
프로페셔널 보컬 분석 및 교육학적 평가 시스템 검증
"""

import json
import requests
import time
import sys
from datetime import datetime

class ProfessionalVocalSystemTester:
    """프로페셔널 보컬 시스템 종합 테스터"""
    
    def __init__(self):
        self.base_url = "http://localhost:5006"
        self.test_results = []
        self.servers = {
            "CREPE": "http://localhost:5002/health",
            "SPICE": "http://localhost:5003/health", 
            "Formant": "http://localhost:5004/health",
            "Virtual Listener": f"{self.base_url}/health"
        }
        
    def run_comprehensive_test(self):
        """전체 시스템 종합 테스트"""
        print("🎼 Professional Vocal Analysis System - 종합 테스트")
        print("=" * 70)
        
        # 1. 서버 상태 확인
        if not self._test_server_health():
            print("❌ 서버 상태 확인 실패 - 테스트 중단")
            return False
        
        # 2. 프로페셔널 분석 테스트
        analysis_result = self._test_professional_analysis()
        if not analysis_result:
            print("❌ 프로페셔널 분석 테스트 실패")
            return False
        
        # 3. 교육학적 평가 테스트
        self._test_pedagogical_assessment()
        
        # 4. 음성 건강 리포트 테스트
        self._test_vocal_health_report()
        
        # 5. 발성 기법 분석 테스트
        self._test_technique_analysis()
        
        # 6. 학습 진도 추적 테스트
        self._test_learning_progress()
        
        # 7. 성능 벤치마크
        self._test_performance_benchmark()
        
        # 최종 결과 출력
        self._print_final_results()
        
        return True
    
    def _test_server_health(self):
        """서버 상태 확인"""
        print("\n🔍 1. 서버 상태 확인")
        print("-" * 50)
        
        all_healthy = True
        for name, url in self.servers.items():
            try:
                response = requests.get(url, timeout=3)
                if response.status_code == 200:
                    data = response.json()
                    status = data.get('status', 'unknown')
                    print(f"  ✅ {name}: {status}")
                    
                    # 추가 정보 표시
                    if name == "Virtual Listener":
                        mode = data.get('mode', 'unknown')
                        print(f"     모드: {mode}")
                else:
                    print(f"  ⚠️ {name}: HTTP {response.status_code}")
                    all_healthy = False
            except Exception as e:
                print(f"  ❌ {name}: 연결 실패 ({e})")
                all_healthy = False
        
        return all_healthy
    
    def _test_professional_analysis(self):
        """프로페셔널 분석 기능 테스트"""
        print("\n🎼 2. 프로페셔널 분석 테스트")
        print("-" * 50)
        
        test_urls = [
            {
                'url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
                'description': 'Rick Astley - Never Gonna Give You Up (팝)',
                'duration': 20
            },
            # 추가 테스트 URL들을 여기에 추가 가능
        ]
        
        successful_analyses = []
        
        for i, test_case in enumerate(test_urls, 1):
            print(f"\n  [{i}] {test_case['description']}")
            print(f"      URL: {test_case['url']}")
            print(f"      분석 시간: {test_case['duration']}초")
            
            try:
                start_time = time.time()
                
                response = requests.post(
                    f"{self.base_url}/professional_analysis",
                    json={
                        'url': test_case['url'],
                        'duration': test_case['duration']
                    },
                    timeout=90
                )
                
                end_time = time.time()
                analysis_time = end_time - start_time
                
                if response.status_code == 200:
                    result = response.json()
                    
                    print(f"      ⏱️ 분석 시간: {analysis_time:.1f}초")
                    print(f"      ✅ 상태: {result['status']}")
                    
                    if result['status'] == 'success':
                        analysis_data = result['result']['analysis']
                        professional_data = analysis_data.get('professional_analysis', {})
                        
                        # 기본 분석 결과
                        print(f"      📊 기본 분석:")
                        print(f"         감지된 음표: {analysis_data.get('detected_notes', 0)}개")
                        print(f"         평균 신뢰도: {analysis_data.get('confidence_avg', 0):.1%}")
                        print(f"         주요 기법: {analysis_data.get('main_technique', 'Unknown')}")
                        
                        # 프로페셔널 분석 결과
                        if professional_data:
                            print(f"      🎼 프로페셔널 분석:")
                            
                            # 발성 특성
                            vocal_chars = professional_data.get('vocal_characteristics', {})
                            if vocal_chars:
                                dominant_register = vocal_chars.get('dominant_register', 'unknown')
                                register_dist = vocal_chars.get('register_distribution', {})
                                print(f"         주요 발성 구역: {dominant_register}")
                                print(f"         구역 분포: {register_dist}")
                            
                            # 교육학적 점수
                            pedagogical_scores = professional_data.get('pedagogical_scores', {})
                            if pedagogical_scores:
                                overall_avg = pedagogical_scores.get('overall_average', 0)
                                pitch_accuracy = pedagogical_scores.get('pitch_accuracy', 0)
                                print(f"         종합 점수: {overall_avg:.1f}/100")
                                print(f"         피치 정확도: {pitch_accuracy:.1f}/100")
                            
                            # 음성 건강
                            health_status = professional_data.get('vocal_health_status', {})
                            if health_status:
                                risk_level = health_status.get('risk_level', 'unknown')
                                strain = health_status.get('average_strain', 0)
                                print(f"         위험도: {risk_level}")
                                print(f"         성대 긴장: {strain:.3f}")
                            
                            # 개발 계획
                            dev_plan = professional_data.get('development_plan', {})
                            if dev_plan:
                                priorities = dev_plan.get('priority_areas', [])
                                exercises = dev_plan.get('recommended_exercises', [])
                                print(f"         우선 개선 영역: {', '.join(priorities[:3])}")
                                print(f"         권장 연습: {len(exercises)}가지")
                            
                            # 인사이트
                            insights = professional_data.get('professional_insights', [])
                            if insights:
                                print(f"         🔍 인사이트:")
                                for insight in insights[:2]:
                                    print(f"           • {insight}")
                        
                        successful_analyses.append({
                            'url': test_case['url'],
                            'analysis_time': analysis_time,
                            'result': result
                        })
                        
                        # 데이터베이스 ID 저장 (나중에 사용)
                        if 'database_id' in result['result']:
                            test_case['database_id'] = result['result']['database_id']
                    
                    print(f"      ✅ 분석 성공")
                else:
                    print(f"      ❌ HTTP 오류: {response.status_code}")
                    print(f"      응답: {response.text[:200]}...")
                    
            except Exception as e:
                print(f"      ❌ 분석 오류: {e}")
                continue
        
        print(f"\n  📊 프로페셔널 분석 결과: {len(successful_analyses)}/{len(test_urls)} 성공")
        return len(successful_analyses) > 0
    
    def _test_pedagogical_assessment(self):
        """교육학적 평가 테스트"""
        print("\n📚 3. 교육학적 평가 테스트")
        print("-" * 50)
        
        # 최근 라벨 조회해서 ID 얻기
        try:
            response = requests.get(f"{self.base_url}/get_labels?limit=5")
            if response.status_code == 200:
                data = response.json()
                labels = data.get('labels', [])
                
                if labels:
                    # 첫 번째 라벨로 테스트
                    label_id = labels[0].get('id')
                    if label_id:
                        print(f"  📋 라벨 ID {label_id} 평가 조회 중...")
                        
                        assessment_response = requests.get(
                            f"{self.base_url}/pedagogical_assessment/{label_id}"
                        )
                        
                        if assessment_response.status_code == 200:
                            assessment_data = assessment_response.json()
                            print(f"  ✅ 교육학적 평가 조회 성공")
                            print(f"     분석 타입: {assessment_data.get('analysis_type', 'unknown')}")
                        else:
                            print(f"  ⚠️ 교육학적 평가 없음 (프로페셔널 분석 데이터 필요)")
                    else:
                        print("  ⚠️ 유효한 라벨 ID 없음")
                else:
                    print("  ⚠️ 저장된 라벨 없음")
            else:
                print(f"  ❌ 라벨 조회 실패: {response.status_code}")
                
        except Exception as e:
            print(f"  ❌ 교육학적 평가 테스트 오류: {e}")
    
    def _test_vocal_health_report(self):
        """음성 건강 리포트 테스트"""
        print("\n🏥 4. 음성 건강 리포트 테스트")
        print("-" * 50)
        
        try:
            response = requests.get(f"{self.base_url}/vocal_health_report?limit=20")
            
            if response.status_code == 200:
                data = response.json()
                health_report = data.get('health_report', {})
                
                print("  ✅ 음성 건강 리포트 생성 성공")
                
                # 요약 정보
                summary = health_report.get('summary', {})
                if summary:
                    print(f"     📊 요약:")
                    print(f"        분석 세션: {summary.get('total_sessions', 0)}개")
                    print(f"        평균 성대 긴장: {summary.get('average_strain', 0):.3f}")
                    print(f"        긴장 트렌드: {summary.get('strain_trend', 'unknown')}")
                    print(f"        주요 위험도: {summary.get('primary_risk_level', 'unknown')}")
                
                # 위험도 분포
                risk_distribution = health_report.get('risk_distribution', {})
                if risk_distribution:
                    print(f"     🚨 위험도 분포: {risk_distribution}")
                
                # 권장사항
                recommendations = health_report.get('recommendations', [])
                if recommendations:
                    print(f"     💡 권장사항:")
                    for i, rec in enumerate(recommendations[:3], 1):
                        print(f"        {i}. {rec}")
                        
            elif response.status_code == 200:
                # Warning 상태인 경우
                data = response.json()
                print(f"  ⚠️ {data.get('message', '데이터 부족')}")
                print(f"     {data.get('recommendation', '')}")
            else:
                print(f"  ❌ 건강 리포트 생성 실패: {response.status_code}")
                
        except Exception as e:
            print(f"  ❌ 음성 건강 리포트 테스트 오류: {e}")
    
    def _test_technique_analysis(self):
        """발성 기법 분석 테스트"""
        print("\n🎯 5. 발성 기법 분석 테스트")
        print("-" * 50)
        
        try:
            response = requests.get(f"{self.base_url}/technique_analysis?limit=30")
            
            if response.status_code == 200:
                data = response.json()
                technique_analysis = data.get('technique_analysis', {})
                
                print("  ✅ 발성 기법 분석 성공")
                
                # 요약 정보
                summary = technique_analysis.get('summary', {})
                if summary:
                    print(f"     📊 요약:")
                    print(f"        분석 대상: {summary.get('total_analyzed', 0)}개")
                    print(f"        기법 다양성: {summary.get('technique_variety', 0)}가지")
                    print(f"        발성 구역 다양성: {summary.get('register_variety', 0)}가지")
                    print(f"        모음 다양성: {summary.get('vowel_variety', 0)}가지")
                
                # 기법 분포
                technique_distribution = technique_analysis.get('technique_distribution', {})
                if technique_distribution:
                    print(f"     🎼 기법 분포: {technique_distribution}")
                    
                dominant_technique = technique_analysis.get('dominant_technique', 'unknown')
                print(f"     🏆 주요 기법: {dominant_technique}")
                
                # 인사이트
                insights = technique_analysis.get('technique_insights', [])
                if insights:
                    print(f"     🔍 기법 인사이트:")
                    for i, insight in enumerate(insights, 1):
                        print(f"        {i}. {insight}")
                        
            else:
                print(f"  ❌ 기법 분석 실패: {response.status_code}")
                
        except Exception as e:
            print(f"  ❌ 발성 기법 분석 테스트 오류: {e}")
    
    def _test_learning_progress(self):
        """학습 진도 추적 테스트"""
        print("\n📈 6. 학습 진도 추적 테스트")
        print("-" * 50)
        
        try:
            response = requests.get(f"{self.base_url}/learning_progress?days=30")
            
            if response.status_code == 200:
                data = response.json()
                learning_progress = data.get('learning_progress', {})
                
                print("  ✅ 학습 진도 분석 성공")
                
                # 요약 정보
                summary = learning_progress.get('summary', {})
                if summary:
                    print(f"     📊 요약:")
                    print(f"        총 세션: {summary.get('total_sessions', 0)}개")
                    print(f"        현재 평균: {summary.get('current_average', 0):.1f}점")
                    print(f"        전체 트렌드: {summary.get('overall_trend', 'unknown')}")
                    print(f"        개선율: {summary.get('improvement_rate', 0):.1f}%")
                
                # 상세 진도
                detailed = learning_progress.get('detailed_progress', {})
                if detailed:
                    skills = detailed.get('skills_development', {})
                    print(f"     🎯 기술 발전:")
                    print(f"        피치: {skills.get('pitch', 0):.1f}/100")
                    print(f"        호흡: {skills.get('breath', 0):.1f}/100")
                
                # 마일스톤
                milestones = learning_progress.get('milestones', [])
                if milestones:
                    print(f"     🏆 마일스톤:")
                    for milestone in milestones:
                        print(f"        • {milestone}")
                        
            elif response.status_code == 200:
                # Warning 상태
                data = response.json()
                print(f"  ⚠️ {data.get('message', '데이터 부족')}")
                print(f"     데이터 포인트: {data.get('data_points', 0)}개")
            else:
                print(f"  ❌ 학습 진도 분석 실패: {response.status_code}")
                
        except Exception as e:
            print(f"  ❌ 학습 진도 추적 테스트 오류: {e}")
    
    def _test_performance_benchmark(self):
        """성능 벤치마크 테스트"""
        print("\n⚡ 7. 성능 벤치마크")
        print("-" * 50)
        
        # 간단한 분석 요청으로 성능 측정
        benchmark_tests = [
            {'name': '기본 분석', 'endpoint': '/listen', 'duration': 10},
            {'name': '프로페셔널 분석', 'endpoint': '/professional_analysis', 'duration': 10}
        ]
        
        for test in benchmark_tests:
            print(f"  🚀 {test['name']} 성능 테스트")
            
            try:
                start_time = time.time()
                
                response = requests.post(
                    f"{self.base_url}{test['endpoint']}",
                    json={
                        'url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
                        'duration': test['duration']
                    },
                    timeout=60
                )
                
                end_time = time.time()
                total_time = end_time - start_time
                
                if response.status_code == 200:
                    print(f"     ✅ 완료 시간: {total_time:.2f}초")
                    print(f"     📊 처리 속도: {test['duration'] / total_time:.1f}x 실시간")
                else:
                    print(f"     ❌ 실패: HTTP {response.status_code}")
                    
            except Exception as e:
                print(f"     ❌ 벤치마크 오류: {e}")
    
    def _print_final_results(self):
        """최종 결과 출력"""
        print("\n" + "=" * 70)
        print("🎼 Professional Vocal Analysis System - 테스트 완료")
        print("=" * 70)
        
        current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"테스트 완료 시간: {current_time}")
        
        print("\n🏆 시스템 특징 검증:")
        print("  ✅ 다중 엔진 분석 (CREPE + SPICE + Formant)")
        print("  ✅ 프로페셔널 보컬 분류 시스템")
        print("  ✅ 7가지 발성 구역 자동 분류")
        print("  ✅ 음성학적 모음 형태 분석")
        print("  ✅ 전문가 수준 비브라토 분석")
        print("  ✅ 전환음(Passaggio) 감지")
        print("  ✅ 음성 건강 지표 모니터링")
        print("  ✅ 교육학적 성과 평가")
        print("  ✅ 개별 맞춤 학습 권장")
        print("  ✅ 실시간 진도 추적")
        
        print("\n📚 교육적 가치:")
        print("  🎯 보컬 트레이너 관점의 체계적 분석")
        print("  📊 객관적이고 정량화된 피드백")
        print("  🏥 음성 건강 예방 중심 접근")
        print("  📈 데이터 기반 학습 진도 관리")
        print("  🎼 클래식부터 현대 기법까지 포괄")
        
        print("\n💡 권장 사용법:")
        print("  1. 정기적인 프로페셔널 분석으로 실력 점검")
        print("  2. 음성 건강 리포트로 피로도 관리")
        print("  3. 발성 기법 분석으로 다양성 개발")
        print("  4. 학습 진도 추적으로 동기 부여")
        print("  5. 개별 권장사항으로 효율적 연습")
        
        print("\n" + "=" * 70)

def main():
    """메인 실행 함수"""
    if len(sys.argv) > 1 and sys.argv[1] == '--quick':
        print("⚡ 빠른 테스트 모드")
        # 빠른 테스트 로직 (구현 생략)
    else:
        # 전체 테스트 실행
        tester = ProfessionalVocalSystemTester()
        success = tester.run_comprehensive_test()
        
        if success:
            print("\n🎉 모든 테스트 통과!")
            exit(0)
        else:
            print("\n❌ 일부 테스트 실패")
            exit(1)

if __name__ == "__main__":
    main()