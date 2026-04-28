-- Create next year cycle by copying structure
-- Example: create 2027 from 2026

insert into okr_cycles (year, cycle_name, start_date, mid_review_date, end_date, is_active)
select
  2027,
  cycle_name,
  date '2027-01-01',
  date '2027-06-30',
  date '2027-12-31',
  true
from okr_cycles
where year = 2026 and cycle_name = 'annual'
on conflict (year, cycle_name) do nothing;

-- Copy employee objectives and KR skeleton (without actual values)
with src_cycle as (
  select id from okr_cycles where year = 2026 and cycle_name = 'annual'
),
dst_cycle as (
  select id from okr_cycles where year = 2027 and cycle_name = 'annual'
),
new_obj as (
  insert into objectives (
    cycle_id, owner_type, company_id, department_id, employee_id,
    parent_objective_id, title, description, weight, created_by
  )
  select
    (select id from dst_cycle),
    o.owner_type,
    o.company_id,
    o.department_id,
    o.employee_id,
    null,
    o.title,
    o.description,
    o.weight,
    o.created_by
  from objectives o
  where o.cycle_id = (select id from src_cycle)
    and o.owner_type = 'employee'
  returning id, title, employee_id
)
insert into key_results (
  objective_id, name, metric_name, metric_unit, metric_direction,
  baseline_value, target_value, mid_actual_value, end_actual_value, weight
)
select
  n.id,
  kr.name,
  kr.metric_name,
  kr.metric_unit,
  kr.metric_direction,
  kr.baseline_value,
  kr.target_value,
  null,
  null,
  kr.weight
from new_obj n
join objectives src_o
  on src_o.title = n.title and src_o.employee_id = n.employee_id
join key_results kr on kr.objective_id = src_o.id;
