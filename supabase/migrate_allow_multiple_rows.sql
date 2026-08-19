-- 이미 schema.sql(이전 버전)을 실행해서 study_stats가 device_id UNIQUE + upsert 방식으로
-- 만들어져 있는 프로젝트용 마이그레이션입니다. 기존 데이터는 그대로 두고, 같은 기기가
-- 여러 번 접속해도 매번 새 행이 쌓이도록 구조만 바꿉니다. SQL Editor에서 한 번만 실행하세요.

alter table study_stats drop constraint if exists study_stats_device_id_key;

create index if not exists study_stats_device_created_idx on study_stats (device_id, created_at desc);

-- 더 이상 upsert(update)로 갱신하지 않으므로 이 정책은 필요 없음.
drop policy if exists "anon can update study_stats" on study_stats;

create or replace view study_stats_latest
with (security_invoker = true) as
select distinct on (device_id)
  device_id, avg_daily_hours, progress_rate, avg_days_before_exam, created_at
from study_stats
order by device_id, created_at desc;

grant select on study_stats_latest to anon;

-- updated_at 컬럼은 더 이상 값이 갱신되지 않아 의미가 없어졌지만(항상 created_at과 동일),
-- 기존 데이터를 보존하기 위해 그대로 둡니다. 지우고 싶다면 아래 주석을 해제하세요.
-- alter table study_stats drop column if exists updated_at;
