# VS Code + Live Server 설정 가이드

## 1단계: VS Code에서 폴더 열기

1. **VS Code 실행**
2. **File → Open Folder** 클릭
3. 다음 폴더 선택: `/Users/seoyeongbin/vocal_trainer_ai/build/web`
4. **Open** 클릭

## 2단계: Live Server 확장 설치

1. VS Code 좌측 사이드바에서 **Extensions** (확장) 아이콘 클릭 (네모 4개 모양)
2. 검색창에 **"Live Server"** 입력
3. **"Live Server" by Ritwick Dey** 찾기
4. **Install** 클릭
5. 설치 완료 기다리기

## 3단계: Live Server로 앱 실행

1. VS Code에서 **index.html** 파일 클릭
2. 파일이 열리면 **우클릭**
3. **"Open with Live Server"** 선택
4. 브라우저가 자동으로 열리며 앱 실행!

## 예상 결과

- 브라우저에서 `http://127.0.0.1:5500` 또는 `http://localhost:5500` 주소로 앱 실행
- 3D 모델들이 정상적으로 로드됨
- 모든 UI 컴포넌트가 작동함

## 확인 사항

✅ 3D 모델 파일들이 정상 로드되는지 확인
✅ 오디오 시각화 패널 작동 확인  
✅ 피치 분석 그래프 확인
✅ AI 코칭 조언 확인

## 문제 해결

**Live Server가 없다면:**
- Extensions에서 "Live Server" 검색
- Ritwick Dey 작성자 확인
- Install 버튼 클릭

**포트 충돌시:**
- VS Code 하단 상태바에서 "Go Live" 클릭하여 중지
- 다시 "Go Live" 클릭하여 재시작