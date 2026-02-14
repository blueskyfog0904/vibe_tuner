# VibeTuner 프로젝트 아키텍처 문서 (Project Architecture Documentation)

## 개요 (Overview)
VibeTuner는 Flutter로 제작된 전문 악기 튜닝 및 청음 훈련 애플리케이션입니다. 이 프로젝트는 **Clean Architecture** 패턴을 기반으로 설계되어 있으며, 오디오 처리(Native/DSP), 비즈니스 로직(튜닝/게임 엔진), UI 프레젠테이션 계층이 철저히 분리되어 있습니다.

이 문서는 시스템의 핵심 구조와 구현 원리를 설명하여, 향후 개발자가 기존 기능을 망가뜨리지 않고 새로운 기능을 추가하거나 유지보수할 수 있도록 돕는 것을 목적으로 합니다.

---

## 🏗️ 아키텍처 패턴 (Architectural Patterns)

### 1. 클린 아키텍처 (Clean Architecture)
프로젝트는 다음과 같은 계층(Layer)으로 구분됩니다:
- **Presentation (프레젠테이션)**: UI 화면(`Pages`, `Widgets`)과 상태 관리(`riverpod` Providers, `Controllers`)를 담당합니다.
- **Domain (도메인)**: 순수 비즈니스 로직(`Entities`, `UseCases`)과 인터페이스(`Repositories`)를 정의합니다. 이곳에는 Flutter 의존성(Widget 등)이 없어야 합니다.
- **Data (데이터)**: 도메인 계층의 인터페이스를 실제로 구현(`Repositories Impl`), 데이터 소스(API, DB, DSP) 접근, 데이터 모델(DTO)을 담당합니다.

### 2. 상태 관리 (State Management)
- **Riverpod**: 의존성 주입(DI) 및 전역 상태 관리에 사용됩니다.
- **StateNotifier**: 복잡한 로직을 가진 컨트롤러(`GameController`, `TunerStateNotifier`)의 상태를 관리합니다.
- **Streams**: 실시간으로 쏟아지는 오디오 데이터(PCM Buffer, Pitch Result)를 처리하기 위해 적극적으로 사용됩니다.

---

## 🧩 Phase 1: 핵심 오디오 엔진 (`lib/features/audio_processing`)

### 목적 (Purpose)
마이크로부터 원시(Raw) 오디오 데이터를 입력받고, 디지털 신호 처리(DSP)를 수행하는 기반을 마련합니다.

### 주요 컴포넌트 (Key Components)
1.  **`AudioStreamSource`** (`data/datasources/`)
    *   **역할**: `flutter_audio_capture` 패키지를 감싸서 마이크로부터 PCM(Pulse Code Modulation) 데이터를 실시간으로 가져옵니다.
    *   **주의사항**: iOS의 `Info.plist` (NSMicrophoneUsageDescription)와 Android의 권한 설정이 필수적입니다.
2.  **`AudioProcessor`** (`domain/dsp/`)
    *   **역할**: 입력된 오디오 데이터에 필터링(노이즈 제거 등)을 수행합니다.
    *   **최적화**: UI 버벅임(Jank)을 방지하기 위해, 무거운 연산이 추가될 경우 **Isolate(백그라운드 스레드)** 로 분리할 수 있도록 설계되어 있습니다.
3.  **`AudioStateProvider`** (`presentation/providers/`)
    *   **역할**: 오디오 스트림을 앱 전체에 공급(Broadcast)하는 파이프라인 역할을 합니다.

---

## 🎸 Phase 2: 튜너 엔진 (`lib/features/tuner_engine`)

### 목적 (Purpose)
오디오 데이터에서 주파수(Frequency)와 음계(Note)를 검출하고, 사용자에게 튜닝 상태를 알려줍니다.

### 주요 컴포넌트 (Key Components)
1.  **`PitchRepository`** (`domain/repositories/` & `data/repositories/`)
    *   **역할**: 튜너의 두뇌입니다.
    *   **알고리즘**: `pitch_detector_dart`의 **YIN 알고리즘**을 사용하여 PCM 버퍼를 주파수(Hz)로 변환합니다.
    *   **성능 최적화 (중요)**: YIN 알고리즘은 연산량이 많으므로, **별도의 Isolate (`_pitchProcessorEntryPoint`)** 에서 실행됩니다. 메인 스레드와 `SendPort`/`ReceivePort`를 통해 통신합니다.
    *   **출력**: `TuningResult` (주파수, 음계 이름, 옥타브, Cents 오차, 상태) 스트림을 방출합니다.
2.  **`NoteCalculator`** (`core/math/`)
    *   **역할**: 순수 수학 계산 모듈입니다. 주파수(Hz)를 입력받아 가장 가까운 음계(예: 440Hz -> A4)와 오차(Cents)를 계산합니다.
3.  **`TunerStateNotifier`** (`presentation/providers/`)
    *   **역할**: 오디오 엔진과 튜너 UI를 연결합니다.
    *   **핵심 로직**: 바늘이 너무 심하게 떨리는 것을 방지하기 위해 **이동 평균 필터 (Moving Average Filter)** 가 적용되어 있습니다.
4.  **`HapticManager`** (`services/`)
    *   **역할**: 튜닝이 정확하게 맞았을 때 진동을 줍니다.
    *   **디바운싱 (Debouncing)**: 진동이 연속으로 `드드드득` 울리지 않도록, 한 번 울리면 일정 시간(예: 0.5초) 동안은 다시 울리지 않도록 제한합니다.

---

## 🎼 Phase 3: 인터랙티브 코드 라이브러리 (`lib/features/chord_library`)

### 목적 (Purpose)
기타와 우쿨렐레의 코드 운지법(Finger Position)을 시각적으로 보여주는 사전 기능입니다.

### 주요 컴포넌트 (Key Components)
1.  **`chord_db.json`** (`assets/data/`)
    *   **역할**: 모든 코드 데이터의 원천(Source of Truth)입니다. JSON 형식으로 정의되어 있어, 데이터를 추가하기 위해 코드를 수정할 필요가 없습니다.
2.  **`ChordRepository`** (`data/repositories/`)
    *   **역할**: JSON 파일을 로딩하고 파싱합니다. 악기(Instrument), 루트(Root), 퀄리티(Quality - Major, minor 등)에 따라 코드를 필터링합니다.
3.  **`FretboardPainter`** (`presentation/painters/`)
    *   **역할**: **벡터 그래픽 렌더링**을 담당합니다.
    *   **기술**: Flutter의 `CustomPainter`를 사용하여 넥(Neck), 프렛(Fret), 줄(String), 손가락 위치를 직접 그립니다.
    *   **중요**: **상대 좌표계** (`size.width`, `size.height` 비율 기반)를 사용하여, 아이폰 SE부터 아이패드까지 모든 화면 크기에서 깨짐 없이 완벽하게 표시됩니다.

---

## 👂 Phase 4: 청음 훈련 게임 (Ear Training Game) (`lib/features/ear_training`)

### 목적 (Purpose)
앱이 들려주는 기준음(Reference Tone)을 듣고, 사용자가 악기로 똑같은 음을 연주하여 맞추는 게임입니다.

### 주요 컴포넌트 (Key Components)
1.  **`ToneGenerator`** (`data/sources/`)
    *   **기술**: `flutter_soloud` (C++ 기반 저지연 오디오 엔진)를 사용합니다.
    *   **전략**: **샘플 기반 합성 (Sample-based Synthesis)** 방식을 채택했습니다.
        *   **작동 원리**: 실제 기타의 '도(C4, 261.63Hz)' 소리가 녹음된 `guitar_c4.mp3` 파일을 로딩합니다.
        *   다른 음(예: G4)을 낼 때는 재생 속도(Pitch)를 조절합니다. (예: 1.5배 속도로 재생 -> 주파수가 1.5배 높아짐 -> G4 소리가 남).
    *   **폴백 (Fallback)**: 만약 mp3 파일이 없거나 로딩에 실패하면, 자동으로 `Sawtooth`(톱니파) 웨이브를 합성하여 소리가 끊기지 않도록 방어 로직이 구현되어 있습니다.
2.  **`GameEngine`** (`domain/logic/`)
    *   **역할**: 사용자가 낸 소리가 정답인지 판별합니다.
    *   **로직**: 입력된 주파수와 정답 주파수의 차이(Cents)를 계산하여, 난이도별 허용 오차(Easy: ±50, Hard: ±10) 이내면 정답 처리합니다.
3.  **`GameController`** (`presentation/providers/`)
    *   **역할**: 게임의 상태 머신 (대기 -> 문제 출제/소리 재생 -> 듣기/채점 -> 정답/오답)을 관리합니다.
    *   **핵심 기능**: **오디오 세션 관리 (Audio Session Management)**
        *   iOS에서는 기본적으로 마이크를 켜면 스피커 볼륨이 줄어들거나 수화기로 소리가 나갑니다.
        *   이를 방지하기 위해 `audio_session` 패키지를 사용하여 **`AVAudioSessionCategory.playAndRecord`** 모드와 **`defaultToSpeaker`** 옵션을 강제로 설정했습니다. 이로써 **입력(마이크)과 출력(스피커)을 동시에** 사용할 수 있습니다.

---

## ⚠️ 핵심 유지보수 노트 (Critical Maintenance Notes)

코드를 수정할 때 반드시 주의해야 할 사항들입니다.

1.  **iOS 오디오 세션 (Audio Session)**:
    *   마이크와 스피커를 동시에 써야 한다면, `GameController`의 `_initialize` 메서드에 있는 `AudioSession.configure` 설정을 절대 삭제하거나 변경하지 마세요.
    *   특히 `defaultToSpeaker` 옵션이 빠지면, 소리가 귀를 대야 들리는 '통화 모드'로 바뀝니다.
2.  **Isolates (백그라운드 처리)**:
    *   튜너의 성능을 위해 `PitchRepositoryImpl`은 별도 Isolate에서 돕니다.
    *   따라서 `TuningResult` 클래스는 복잡한 메서드나 Flutter 의존성을 가지면 안 되며, 순수한 데이터 클래스(DTO)여야만 프로세스 간 전송이 가능합니다.
3.  **에셋 관리 (Assets)**:
    *   `assets/audio/guitar_c4.mp3` 파일은 리얼한 기타 소리의 핵심입니다.
    *   이 파일을 교체할 때는 **C4 (Middle C, 261.63Hz)** 음정으로 정확하게 녹음된, 리버브(울림)가 적은(Dry) 파일을 사용해야 피치 시프트가 자연스럽습니다.
