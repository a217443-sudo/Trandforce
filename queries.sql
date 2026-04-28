-- Mid-year achievement by employee
select
  e.employee_no,
  e.name,
  round(sum(greatest(least(v.mid_achievement, 1.2), 0) * v.weight) / nullif(sum(v.weight),0) * 100, 2) as mid_achievement_pct,
  round(avg(fn_achievement_to_score(v.mid_achievement)), 2) as mid_score_1_5
from v_kr_achievement v
join employees e on e.id = v.employee_id
group by e.employee_no, e.name
order by mid_achievement_pct desc;

-- Year-end achievement by employee
select
  e.employee_no,
  e.name,
  round(sum(greatest(least(v.end_achievement, 1.2), 0) * v.weight) / nullif(sum(v.weight),0) * 100, 2) as end_achievement_pct,
  round(avg(fn_achievement_to_score(v.end_achievement)), 2) as end_score_1_5
from v_kr_achievement v
join employees e on e.id = v.employee_id
group by e.employee_no, e.name
order by end_achievement_pct desc;

-- Department year-end attainment summary
select
  d.name as department,
  round(avg(greatest(least(v.end_achievement, 1.2), 0)) * 100, 2) as dept_end_achievement_pct,
  round(avg(fn_achievement_to_score(v.end_achievement)), 2) as dept_score_1_5
from v_kr_achievement v
join employees e on e.id = v.employee_id
join departments d on d.id = e.department_id
group by d.name
order by dept_end_achievement_pct desc;

-- Risk KR list for mid-year (below 60%)
select
  e.name as employee_name,
  o.title as objective_title,
  kr.name as key_result_name,
  round(v.mid_achievement * 100, 2) as mid_achievement_pct
from v_kr_achievement v
join key_results kr on kr.id = v.key_result_id
join objectives o on o.id = kr.objective_id
join employees e on e.id = v.employee_id
where v.mid_achievement < 0.60
order by v.mid_achievement asc;

-- Annual final score generation template (70/20/10)
insert into annual_performance_scores (
  cycle_id, employee_id, okr_score, competency_score, behavior_score, final_score
)
select
  c.id as cycle_id,
  e.id as employee_id,
  coalesce(avg(fn_achievement_to_score(v.end_achievement))::numeric, 0) as okr_score,
  coalesce(avg(cr.end_score)::numeric, 0) as competency_score,
  4.00 as behavior_score,
  round(
    coalesce(avg(fn_achievement_to_score(v.end_achievement))::numeric, 0) * 0.70 +
    coalesce(avg(cr.end_score)::numeric, 0) * 0.20 +
    4.00 * 0.10
  ,2) as final_score
from okr_cycles c
join employees e on e.active = true
left join v_kr_achievement v on v.cycle_id = c.id and v.employee_id = e.id
left join competency_reviews cr on cr.cycle_id = c.id and cr.employee_id = e.id
where c.year = 2026
group by c.id, e.id;
