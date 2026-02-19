# 에이전트 실행 브리프 (실내-조용한 환경 튜너 안정화)

목표:
- 6줄 튜너 인식 향상, sustain 유지 강화, tooLow/tooHigh 플리커 감소

고정 조건:
- Preset: Guitar Standard
- Low Latency: OFF (모든 1차 실험 동안 고정)
- Noise Gate: 0.0038
- Sensitivity: Low
- A4: 440Hz
- 환경: 실내-조용한 환경, 마이크 거리/방향 고정

실행:
1. 라운드 1에서 1~6번 줄을 각각 3회 반복 테스트(각 12~15초).
2. 아래 지표 기록: sustain_seconds, flip_count_per_5s, stable/settling/unstable.
3. 판정 기준: sustain >=0.7초, flip_count <=2/5초.
4. 미달 시 재조정 규칙 적용(한 번에 한 변수만 변경):
   - Sustain 부족: hold +100~150 -> sensitivity +0.2~0.4 -> stability +1
   - 플리커 과다: stability +1 -> noise gate -0.0002 -> sensitivity -0.2~0.4
   - 감지 실패: sensitivity +0.3~0.5 -> noise gate -0.0003 -> hold -80~120
   - 오검출: sensitivity -0.2~0.5 -> noise gate +0.0002~0.0005
5. 라운드당 통합 요약 후 다음 라운드 반영. 최대 3라운드.

출력:
- 라운드별 통과 줄 수/6
- 줄별 최종 파라미터
- 실험 기록표(csv) 완성본
- 다음 제안(필요 시 코드 수정 후보: noSignal 보존 로직 완화, cents 히스테리시스, 안정성 가중치 조정)
