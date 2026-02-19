# 튜너 안정화 실행 계획서 (실내-조용한 환경)

## 1) 목표
- 6개 줄(EADGBE) 인식률 향상
- Sustain 유지 시간 증가 (줄 떼는 순간 바로 No Signal이 되지 않게)
- tooLow/tooHigh 왕복(플리커) 감소

## 2) 실행 전제
- Preset: Guitar Standard
- Low Latency: OFF(기본)
- Noise Gate: 0.0038
- Sensitivity: Low
- A4: 440Hz
- 환경: 실내-조용한 환경, 마이크 거리/위치 고정

## 3) 1차 초기값 (Round 0)
| 줄 | Sensitivity | Hold(ms) | Stability |
|---|---:|---:|---:|
| 1번(E4) | 3.8 | 900 | 6 |
| 2번(B3) | 2.4 | 800 | 6 |
| 3번(G3) | 2.1 | 720 | 6 |
| 4번(D3) | 1.5 | 580 | 6 |
| 5번(A2) | 1.2 | 500 | 6 |
| 6번(E2) | 2.0 | 650 | 6 |

## 4) 판정 기준
- Sustain 유지: **>= 0.7초**
- 5초 구간 flip_count(tooLow↔tooHigh): **<= 1~2**
- 안정성: STABLE > UNSTABLE 우세

## 5) 재조정 규칙 (한 번에 하나만 변경)
### A. Sustain이 너무 빨리 끊김
1. Hold +100~150ms
2. 그래도 부족: 해당 줄 Sensitivity +0.2~0.4
3. 그래도 부족: Stability +1

### B. low/high 플래핑 심함
1. Stability +1
2. 여전하면 noise gate -0.0002
3. 여전하면 해당 줄 Sensitivity -0.2~0.4

### C. 줄이 안 잡힘
1. 해당 줄 Sensitivity +0.3~0.5
2. Noise gate -0.0003
3. 필요 시 Hold -80~120ms

### D. 오검출(다른 줄로 전환)
1. 해당 줄 Sensitivity -0.2~0.5
2. 필요 시 Noise gate +0.0002~0.0005

## 6) 실험 순서
- 각 줄당 3회 반복, 각 반복 12~15초
- 동일 줄에서만 값 변경
- 라운드 종료마다 전체 줄 요약 기록
- 목표 미달 시 2차 라운드 진행 (최대 3라운드)
