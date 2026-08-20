-- 이미 study_stats가 만들어져 있는 프로젝트(kvpbctapwesdqznnrsqv)에 두 지표를
-- 추가하는 마이그레이션입니다. 기존 데이터는 그대로 두고 컬럼만 추가합니다.
-- Supabase SQL Editor에서 한 번만 실행하세요.

alter table study_stats
  add column if not exists daily_check_completion_rate numeric not null default 0,
  add column if not exists consecutive_usage_rate numeric not null default 0;

-- 새 컬럼을 포함하도록 리더보드용 뷰를 다시 만든다.
create or replace view study_stats_latest
with (security_invoker = true) as
select distinct on (device_id)
  device_id, avg_daily_hours, progress_rate, avg_days_before_exam,
  daily_check_completion_rate, consecutive_usage_rate, created_at
from study_stats
order by device_id, created_at desc;

grant select on study_stats_latest to anon;
