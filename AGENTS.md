# 저장소 가이드라인

## 프로젝트 구조 및 모듈 구성
- 앱 코드는 `lib/`에 있으며, 기능별 모듈과 공용 코어 모듈로 구성됩니다.
- 기능 모듈: `lib/features/audio_processing`, `lib/features/tuner_engine`, `lib/features/chord_library`, `lib/features/ear_training`.
- 공용 코드: `lib/core`(상수, 수학, 에러, 유틸리티), `lib/config`(테마), 앱 진입점은 `lib/main.dart` 및 `lib/presentation/`.
- 테스트는 주로 `test/`에 위치합니다(예: `test/widget_test.dart`). 별도 프레임워크 요구가 없다면 신규 자동화 테스트도 이 경로를 사용하세요.
- 정적 에셋은 `assets/data/`, `assets/audio/`에 두고, 신규 파일은 `pubspec.yaml`에 등록하세요.
- 플랫폼 래퍼 코드는 `android/`, `ios/`에 있습니다.

## 빌드, 테스트, 개발 명령어
- `flutter pub get`: 의존성 설치/업데이트.
- `flutter run`: 선택한 시뮬레이터/디바이스에서 앱 실행.
- `flutter analyze`: `analysis_options.yaml` 기준 정적 분석 및 린트 검사.
- `flutter test`: 단위/위젯 테스트 실행.
- `flutter build apk` 또는 `flutter build ios`: 릴리스 산출물 생성.

## 코딩 스타일 및 네이밍 규칙
- Dart 기본 규칙을 따르며 들여쓰기는 2칸을 사용하고, 포맷 가독성을 높이는 trailing comma를 권장합니다.
- 제출 전 `dart format .`을 실행하세요.
- 린트 기준은 `analysis_options.yaml`에서 `package:flutter_lints/flutter.yaml`을 포함해 정의됩니다. PR 생성 전 analyzer 경고를 해결하세요.
- 네이밍: 파일은 `snake_case.dart`, 클래스/위젯은 `PascalCase`, 변수/메서드는 `camelCase`, Riverpod provider는 `Provider` 접미사를 사용하세요.

## 테스트 가이드라인
- 테스트 프레임워크는 `flutter_test`를 사용합니다.
- 테스트 파일은 `_test.dart` 접미사를 사용하고, 대상 모듈 기준으로 분류하세요(예: 튜너 로직 테스트는 튜너 관련 동작 중심).
- 버그 수정 및 신규 비즈니스 로직에는 테스트를 추가하고, 특히 `core/` 수학 로직과 기능 도메인 로직을 우선 검증하세요.
- PR 전 로컬에서 `flutter test`와 `flutter analyze`를 실행하세요.

## 커밋 및 Pull Request 가이드라인
- 최근 히스토리는 `feat: ...`, `Fix: ...`, 자유 형식 메시지가 혼재되어 있습니다. 가능하면 명령형의 간결한 커밋 메시지와 Conventional Commit 스타일(`feat:`, `fix:`, `refactor:`)을 권장합니다.
- 커밋은 단일 목적에 집중하고, 리팩터링과 동작 변경을 한 커밋에 섞지 마세요.
- PR에는 다음을 포함하세요: 변경 요약, 핵심 변경사항, 테스트/분석 실행 결과, 관련 이슈/티켓, UI 변경 시 스크린샷 또는 화면 녹화.
