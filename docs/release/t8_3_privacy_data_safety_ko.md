# T8-3 Privacy & Data Safety Answers (KO)

> 기준일: 2026-02-13  
> 현재 코드베이스 기준 초안이며, 실제 배포 전 최종 법무/정책 검토 필요

## 1) 권한 사용 목적
- 마이크(`RECORD_AUDIO`, `NSMicrophoneUsageDescription`)
  - 목적: 실시간 음정 분석 및 튜닝 기능 제공
  - 사용 시점: 튜너 기능 진입 후 권한 요청 시

## 2) 데이터 처리 요약
- 계정/로그인: 없음
- 서버 전송: 없음(현재 구현 기준)
- 결제/구독: 없음
- 위치/연락처/사진 접근: 없음
- 앱 내 저장:
  - 코드 즐겨찾기/최근 본 코드(`shared_preferences`, 로컬 저장)
  - 튜너 설정값(A4, 감도, 노이즈 게이트, 프리셋)
  - 에러 로그(앱 메모리 내 최근 이력, 재시작 시 초기화)

## 3) Google Play Data Safety 응답 초안
- 데이터 수집: `수집하지 않음` (현재 구현 기준)
- 데이터 공유: `공유하지 않음`
- 보안 관행:
  - 전송 데이터 없음
  - 로컬 설정 저장만 수행

## 4) Apple App Privacy 응답 초안
- “Data Used to Track You”: `No`
- “Data Linked to You”: `No` (현재 구현 기준)
- “Data Not Linked to You”: `No` (현재 구현 기준)
- 권한:
  - Microphone: `Yes` (튜닝 기능 제공 목적)

## 5) 앱 내/스토어 고지 문구 예시
- `VibeTuner는 실시간 튜닝 기능 제공을 위해 마이크 권한을 사용합니다.`
- `오디오 데이터는 기기 내에서 처리되며, 현재 버전에서 서버로 전송하지 않습니다.`
