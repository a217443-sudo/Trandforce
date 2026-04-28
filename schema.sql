-- PostgreSQL schema for OKR tracking & performance scoring

create table companies (
  id bigserial primary key,
  name text not null,
  created_at timestamptz not null default now()
);

create table departments (
  id bigserial primary key,
  company_id bigint not null references companies(id),
  name text not null,
  parent_department_id bigint references departments(id),
  created_at timestamptz not null default now()
);

create table teams (
  id bigserial primary key,
  department_id bigint not null references departments(id),
  name text not null,
  created_at timestamptz not null default now()
);

create table employees (
  id bigserial primary key,
  employee_no text unique not null,
  name text not null,
  email text unique,
  title text,
  department_id bigint references departments(id),
  team_id bigint references teams(id),
  manager_id bigint references employees(id),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table user_accounts (
  id bigserial primary key,
  employee_id bigint unique not null references employees(id),
  login_name text unique not null,
  password_hash text not null,
  role text not null check (role in ('admin','gm','manager','employee')),
  created_at timestamptz not null default now()
);

create table okr_cycles (
  id bigserial primary key,
  year int not null check (year >= 2026),
  cycle_name text not null default 'annual',
  start_date date not null,
  mid_review_date date not null,
  end_date date not null,
  is_active boolean not null default true,
  unique(year, cycle_name)
);

create table objectives (
  id bigserial primary key,
  cycle_id bigint not null references okr_cycles(id),
  owner_type text not null check (owner_type in ('company','department','employee')),
  company_id bigint references companies(id),
  department_id bigint references departments(id),
  employee_id bigint references employees(id),
  parent_objective_id bigint references objectives(id),
  title text not null,
  description text,
  weight numeric(5,2) not null default 100,
  created_by bigint references employees(id),
  created_at timestamptz not null default now()
);

create table key_results (
  id bigserial primary key,
  objective_id bigint not null references objectives(id),
  name text not null,
  metric_name text not null,
  metric_unit text,
  metric_direction text not null check (metric_direction in ('higher_better','lower_better')),
  baseline_value numeric(12,2) not null,
  target_value numeric(12,2) not null,
  mid_actual_value numeric(12,2),
  end_actual_value numeric(12,2),
  weight numeric(5,2) not null,
  created_at timestamptz not null default now(),
  check (weight >= 0 and weight <= 100)
);

create table competency_standards (
  id bigserial primary key,
  job_family text not null,
  level_name text not null,
  competency_name text not null,
  target_level int not null check (target_level between 1 and 5),
  effective_year int not null check (effective_year >= 2026),
  unique(job_family, level_name, competency_name, effective_year)
);

create table competency_reviews (
  id bigserial primary key,
  cycle_id bigint not null references okr_cycles(id),
  employee_id bigint not null references employees(id),
  competency_standard_id bigint not null references competency_standards(id),
  mid_score int check (mid_score between 1 and 5),
  end_score int check (end_score between 1 and 5),
  reviewer_id bigint references employees(id),
  comment text,
  unique(cycle_id, employee_id, competency_standard_id)
);

create table annual_performance_scores (
  id bigserial primary key,
  cycle_id bigint not null references okr_cycles(id),
  employee_id bigint not null references employees(id),
  okr_score numeric(4,2) not null,
  competency_score numeric(4,2) not null,
  behavior_score numeric(4,2) not null,
  final_score numeric(4,2) not null,
  calculated_at timestamptz not null default now(),
  unique(cycle_id, employee_id)
);

-- View: KR achievement at mid-year and year-end
-- Formula for higher_better:
--   achievement = (actual - baseline) / nullif(target - baseline,0)
-- Formula for lower_better:
--   achievement = (baseline - actual) / nullif(baseline - target,0)
create or replace view v_kr_achievement as
select
  kr.id as key_result_id,
  o.cycle_id,
  o.employee_id,
  kr.metric_direction,
  kr.weight,
  case
    when kr.metric_direction = 'higher_better' then
      (kr.mid_actual_value - kr.baseline_value) / nullif(kr.target_value - kr.baseline_value, 0)
    else
      (kr.baseline_value - kr.mid_actual_value) / nullif(kr.baseline_value - kr.target_value, 0)
  end as mid_achievement,
  case
    when kr.metric_direction = 'higher_better' then
      (kr.end_actual_value - kr.baseline_value) / nullif(kr.target_value - kr.baseline_value, 0)
    else
      (kr.baseline_value - kr.end_actual_value) / nullif(kr.baseline_value - kr.target_value, 0)
  end as end_achievement
from key_results kr
join objectives o on o.id = kr.objective_id
where o.owner_type = 'employee';

-- Convert achievement to 1-5 score
create or replace function fn_achievement_to_score(rate numeric)
returns int as $$
begin
  if rate is null then return null; end if;
  if rate < 0.40 then return 1;
  elsif rate < 0.60 then return 2;
  elsif rate < 0.80 then return 3;
  elsif rate < 1.00 then return 4;
  else return 5;
  end if;
end;
$$ language plpgsql;
