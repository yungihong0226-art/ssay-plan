-- 디데이플랜 Calendar (dday-plan-vercel) — 사용 데이터 테이블
-- 이 사이트 전용 Supabase 프로젝트("dday plan", kvpbctapwesdqznnrsqv)에서 실행합니다.
-- mvp-service 프로젝트(gxyctacjrvuxudxukksi)의 plan_snapshots / daily_logs와는 무관한 별개 프로젝트입니다.
-- Supabase 대시보드 > SQL Editor 에서 그대로 실행하세요. (처음 세팅하는 경우 이 파일 하나만 실행하면 됩니다.
-- 이미 예전 버전(스키마)으로 만들어져 있다면 대신 migrate_allow_multiple_rows.sql /
-- migrate_add_completion_streak_rates.sql 을 순서대로 실행하세요.)
--
-- 로그인 기능이 없는 앱이라 사용자는 브라우저에 저장된 랜덤 device_id로 구분합니다.
-- 다섯 지표(하루 평균 공부시간 / 공부 진행률 / 시험까지 남은 기간 평균 /
-- 당일 체크 완료율 평균 / 연속 사용률 평균)를 여러 표로 나누지 않고 한 표
-- (study_stats)의 컬럼으로 합쳐서 저장합니다.
--
-- 같은 기기가 여러 번 접속해서 계획을 새로 만들거나 체크인해도 기존 행을 덮어쓰지
-- 않고 매번 새 행을 추가합니다 (기기당 여러 스냅샷이 쌓이는 이력 로그).
--
-- "다른 이용자들의 공부량과 목표 달성량을 보여주어 동기부여"가 목적이라 이 표는
-- 익명 사용자도 전체를 읽을(SELECT) 수 있게 열어둡니다 — 공개 리더보드 성격의
-- 데이터라는 뜻이며, 개인 식별 정보는 담지 않습니다. 리더보드는 기기별 최신 값만
-- 보여줘야 자연스러우므로, 기기별 최신 행만 모아주는 study_stats_latest 뷰를 함께 만듭니다.

create extension if not exists pgcrypto;

create table if not exists study_stats (
  id uuid primary key default gen_random_uuid(),
  device_id text not null,
  avg_daily_hours numeric not null default 0,             -- 하루 평균 공부시간
  progress_rate numeric not null default 0,                -- 공부 진행률(%)
  avg_days_before_exam numeric not null default 0,         -- 계획 수립 시 시험들까지 남은 기간 평균(일)
  daily_check_completion_rate numeric not null default 0,  -- 당일 체크 완료율 평균(%): 지난 날 중 그날 목표를 100% 채운 날의 비율
  consecutive_usage_rate numeric not null default 0,        -- 연속 사용률 평균(%): 어제부터 거슬러 끊기지 않고 체크인한 연속일수 ÷ 경과일수
  created_at timestamptz not null default now()
);

create index if not exists study_stats_device_created_idx on study_stats (device_id, created_at desc);

alter table study_stats enable row level security;

-- 익명 클라이언트는 새 행만 추가할 수 있음(insert-only). 기존 행을 고치거나 지울 수 없어
-- 이력이 그대로 보존됩니다.
create policy "anon can insert study_stats" on study_stats
  for insert to anon with check (true);

-- 원본 로그 자체도 누구나 조회 가능 (민감 정보 없음).
create policy "anyone can read study_stats" on study_stats
  for select to anon using (true);

-- 기기별 가장 최근 스냅샷만 모은 뷰. 앱의 "다른 이용자 현황" 패널은 이 뷰를 읽습니다.
create or replace view study_stats_latest
with (security_invoker = true) as
select distinct on (device_id)
  device_id, avg_daily_hours, progress_rate, avg_days_before_exam,
  daily_check_completion_rate, consecutive_usage_rate, created_at
from study_stats
order by device_id, created_at desc;

grant select on study_stats_latest to anon;

-- ---------------------------------------------------------------------
-- 참고용 쿼리
-- ---------------------------------------------------------------------

-- 전체 평균치 확인 (기기별 최신 값 기준)
-- select
--   round(avg(avg_daily_hours)::numeric, 2) as avg_daily_hours_overall,
--   round(avg(progress_rate)::numeric, 1) as avg_progress_rate_overall,
--   round(avg(avg_days_before_exam)::numeric, 1) as avg_days_before_exam_overall,
--   round(avg(daily_check_completion_rate)::numeric, 1) as avg_check_completion_rate_overall,
--   round(avg(consecutive_usage_rate)::numeric, 1) as avg_consecutive_usage_rate_overall,
--   count(*) as user_count
-- from study_stats_latest;

-- 진행률 상위 10명 (앱의 "다른 이용자 현황" 패널과 동일한 쿼리)
-- select avg_daily_hours, progress_rate, avg_days_before_exam, daily_check_completion_rate, consecutive_usage_rate
-- from study_stats_latest order by progress_rate desc limit 10;

-- 특정 기기의 전체 이력(시간에 따른 변화) 보기
-- select * from study_stats where device_id = '...' order by created_at;
