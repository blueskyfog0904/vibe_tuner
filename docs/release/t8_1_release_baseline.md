# T8-1 Release Baseline

## Scope
- 앱 기본 식별자/표기 정리
- 마이크 권한 설명 문구 정리
- 스토어 등록용 기본 문안 초안 준비

## Applied Changes
- Android 앱 이름: `VibeTuner` (`android/app/src/main/res/values/strings.xml`)
- Android 앱 라벨을 리소스 참조로 통일 (`android/app/src/main/AndroidManifest.xml`)
- Android 마이크 하드웨어 요구사항 선언 추가 (`android.hardware.microphone`)
- iOS 표시 이름 통일: `VibeTuner` (`ios/Runner/Info.plist`)
- iOS 마이크 권한 문구 개선 (`ios/Runner/Info.plist`)
- 앱 내 권한 안내 문구 보강 (`lib/features/tuner_engine/presentation/pages/tuner_page.dart`)

## Store Copy Draft (KO)
- 앱 이름: `VibeTuner`
- 한 줄 소개: `실시간 튜너, 코드 라이브러리, 메트로놈을 한 번에.`
- 짧은 설명(80자 내):
  `마이크 기반 실시간 튜닝, 코드 검색/즐겨찾기, 메트로놈과 이어 트레이닝을 한 앱에서.`
- 상세 설명:
  `VibeTuner는 연습에 필요한 핵심 도구를 하나로 모은 악기 연습 앱입니다.`
  `실시간 튜너로 음정을 맞추고, 코드 라이브러리에서 폼을 찾고, 메트로놈으로 박자를 유지하세요.`

## Done Criteria
- Android/iOS에서 앱 이름이 `VibeTuner`로 표시된다.
- 마이크 권한 요청 전/후 문구가 사용자에게 이유를 명확히 전달한다.
- 스토어 등록 시 바로 사용할 수 있는 기본 문안이 저장소에 존재한다.
