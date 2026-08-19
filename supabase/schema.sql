-- 디데이플랜 Calendar (dday-plan-vercel) — 사용 데이터 테이블
-- 기존 mvp-service Supabase 프로젝트(gxyctacjrvuxudxukksi)를 그대로 재사용합니다.
-- 이 사이트 전용 테이블이라 기존 plan_snapshots / daily_logs 테이블과는 무관합니다.
-- Supabase 대시보드 > SQL Editor 에서 그대로 실행하세요.
--
-- 로그인 기능이 없는 앱이라 사용자는 브라우저에 저장된 랜덤 device_id로 구분합니다.
-- 요청대로 세 지표(하루 평균 공부시간 / 공부 진행률 / 시험까지 남은 기간 평균)를
-- 여러 표로 나누지 않고, 기기(=이용자) 한 명당 한 행으로 한 표에 합쳐서 저장합니다.
--
-- "다른 이용자들의 공부량과 목표 달성량을 보여주어 동기부여"가 목적이라 이 표는
-- 익명 사용자도 전체를 읽을(SELECT) 수 있게 열어둡니다 — 공개 리더보드 성격의
-- 데이터라는 뜻이며, 개인 식별 정보는 담지 않습니다.

create extension if not exists pgcrypto;

create table if not exists study_stats (
  id uuid primary key default gen_random_uuid(),
  device_id text not null unique,
  avg_daily_hours numeric not null default 0,      -- 하루 평균 공부시간
  progress_rate numeric not null default 0,          -- 공부 진행률(%)
  avg_days_before_exam numeric not null default 0,   -- 계획 수립 시 시험들까지 남은 기간 평균(일)
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists study_stats_progress_idx on study_stats (progress_rate desc);

alter table study_stats enable row level security;

-- 익명 클라이언트가 자기 device_id로 새 행을 만들거나(insert), 기존 행을 갱신(upsert)할 수 있음.
-- device_id 소유권을 서버가 검증할 방법이 없는(로그인 없는) 구조라 위조가 이론상 가능하지만,
-- 민감하지 않은 학습 통계이므로 이 MVP 단계에서는 허용합니다.
create policy "anon can insert study_stats" on study_stats
  for insert to anon with check (true);

create policy "anon can update study_stats" on study_stats
  for update to anon using (true) with check (true);

-- 누구나 리더보드 목적으로 전체 조회 가능.
create policy "anyone can read study_stats" on study_stats
  for select to anon using (true);

-- ---------------------------------------------------------------------
-- 참고용 쿼리
-- ---------------------------------------------------------------------

-- 전체 평균치 확인
-- select
--   round(avg(avg_daily_hours)::numeric, 2) as avg_daily_hours_overall,
--   round(avg(progress_rate)::numeric, 1) as avg_progress_rate_overall,
--   round(avg(avg_days_before_exam)::numeric, 1) as avg_days_before_exam_overall,
--   count(*) as user_count
-- from study_stats;

-- 진행률 상위 10명 (앱의 "다른 이용자 현황" 패널과 동일한 쿼리)
-- select avg_daily_hours, progress_rate, avg_days_before_exam
-- from study_stats order by progress_rate desc limit 10;
