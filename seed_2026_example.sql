-- Example seed data based on provided org chart

insert into companies (id, name) values (1, '範例公司');

insert into departments (id, company_id, name, parent_department_id) values
(1, 1, '總經理室', null),
(2, 1, '稽核室', null),
(3, 1, '財會部', null),
(4, 1, '管理部', null),
(5, 1, '製造部', null),
(6, 1, '採購部', null),
(7, 1, '工程部', null),
(8, 1, '行銷業務部', null);

insert into teams (department_id, name) values
(3, '會計課'), (3, '財務課'),
(4, '人資課'), (4, '總務課'), (4, '資訊課'),
(5, '製造課'), (5, '生管課'), (5, '廠務課'), (5, '品管課'),
(6, '採購課'), (6, '倉管課'),
(7, '設備維護課'), (7, '技術課'),
(8, '行銷課'), (8, '公關課'), (8, '業務課');

insert into okr_cycles (year, cycle_name, start_date, mid_review_date, end_date, is_active)
values (2026, 'annual', '2026-01-01', '2026-06-30', '2026-12-31', true);

-- Optional: template competency standards (sample)
insert into competency_standards (job_family, level_name, competency_name, target_level, effective_year) values
('製造', '專員', '流程遵循', 4, 2026),
('製造', '專員', '品質意識', 4, 2026),
('採購', '專員', '成本控管', 4, 2026),
('工程', '專員', '問題分析', 4, 2026),
('行銷業務', '專員', '客戶經營', 4, 2026),
('管理', '專員', '跨部門協作', 4, 2026),
('財會', '專員', '合規與精確性', 5, 2026);
