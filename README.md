# 디데이플랜 Calendar (dday-plan-vercel)

시험 D-day, 시험 범위, 난이도·중요도·현재 진행도, 하루 공부 가능 시간을 입력하면
알고리즘이 매일 권장 학습량을 자동으로 배분하고, 달력에서 완료 여부를 체크하면
못한 만큼을 자동으로 재배분해주는 정적 웹 서비스입니다.

- `index.html` — 단일 파일 웹 앱 (별도 빌드/서버 불필요, 정적 호스팅 가능). https://dday-plan-vercel.vercel.app/ 배포 대상. 과목별 진행률 바(progress-overview)와, 오늘 목표를 다 채우면 순서대로 다음 날 계획도 미리 진행할 수 있는 기능(canEditDate)이 포함된 디자인입니다.
- 계획 자체는 브라우저 저장소에만 저장되며 별도 백엔드가 없습니다.
- 대신 사용 데이터(하루 평균 공부시간 / 공부 진행률 / 시험까지 남은 기간 평균 / 당일 체크 완료율 / 연속 사용률)는 [Supabase](https://supabase.com)에 저장되고, 다른 이용자들의 현황을 앱 안에서 보여줘 동기부여 역할을 합니다.

## 사용 데이터 & 리더보드 (Supabase)

로그인 없이 브라우저에 저장된 임의의 기기 ID로만 이용자를 구분합니다. 다섯 지표를
표 여러 개로 나누지 않고 `study_stats` 한 표의 컬럼으로 합쳐서 저장합니다.

| 컬럼 | 의미 |
|---|---|
| `avg_daily_hours` | 하루 평균 공부시간 (계획 시작일~오늘 실제 학습시간 합 ÷ 경과일수) |
| `progress_rate` | 공부 진행률(%) (전체 필요 시간 대비 완료한 비율) |
| `avg_days_before_exam` | 계획 수립 시 시험들까지 남은 기간의 평균(일) |
| `daily_check_completion_rate` | 당일 체크 완료율 평균(%) — 계획 시작일부터 어제까지 중 그날 권장 학습량을 100% 채운 날의 비율 |
| `consecutive_usage_rate` | 연속 사용률 평균(%) — 어제부터 거슬러 올라가며 끊기지 않고 체크인한 연속 일수 ÷ 전체 경과일수 |

계획을 만들거나 수정할 때, 그리고 하루를 체크인할 때마다 이 값들을 다시 계산해서
새 행으로 추가(insert)합니다. **같은 기기가 여러 번 접속해도 기존 행을 덮어쓰지
않고 매번 쌓이는 이력 로그**입니다. 앱 하단 "다른 이용자들의 학습 현황" 패널은
기기별 최신 값만 모은 `study_stats_latest` 뷰를 진행률 순으로 상위 10개 읽어와
보여줍니다.

`study_stats`/`study_stats_latest`는 리더보드 목적이라 **누구나 조회(SELECT)할
수 있게** 열어뒀습니다 (개인 식별 정보는 담지 않음). 기존 mvp-service 프로젝트의
`plan_snapshots`/`daily_logs`(그쪽은 조회 자체가 막힌 내부 분석용 테이블)와는
성격이 다릅니다.

### 설정 방법

1. Supabase 대시보드(이 사이트 전용 프로젝트 "dday plan", `kvpbctapwesdqznnrsqv`)의 SQL Editor에서:
   - 처음 세팅하는 경우: [`supabase/schema.sql`](supabase/schema.sql) 실행
   - 이미 이전 버전(device_id UNIQUE + upsert 방식)으로 만들어져 있는 경우: [`supabase/migrate_allow_multiple_rows.sql`](supabase/migrate_allow_multiple_rows.sql) 먼저 실행
   - `study_stats`가 이미 있는데 `daily_check_completion_rate`/`consecutive_usage_rate` 컬럼이 없는 경우: [`supabase/migrate_add_completion_streak_rates.sql`](supabase/migrate_add_completion_streak_rates.sql) 실행
2. `index.html`의 `SUPABASE_URL`/`SUPABASE_ANON_KEY`는 이미 이 프로젝트 값으로 채워져 있습니다.
3. Vercel 프로젝트(`dday-plan-vercel`)를 이 저장소에 연결하면 push할 때마다 자동 배포됩니다.
