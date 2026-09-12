-- ============================================================
-- Horizon — Consolidated Data Quality Checks
-- ============================================================
-- SECTION 1: ROW-COUNT RECONCILIATION
-- ============================================================
-- Expected counts:
--   res_company: 1, hr_department: 7, hr_job: 25, hr_employee: 200,
--   project_project: 30, hr_leave_type: 4, hr_recruitment_application: 400
--   (hr_contract, project_task, timesheet_line, hr_leave, hr_appraisal,
--   hr_training_attendance are randomized in count)
SELECT 'res_company' AS table_name, COUNT(*) AS row_count FROM res_company
UNION ALL SELECT 'hr_department', COUNT(*) FROM hr_department
UNION ALL SELECT 'hr_job', COUNT(*) FROM hr_job
UNION ALL SELECT 'hr_employee', COUNT(*) FROM hr_employee
UNION ALL SELECT 'hr_contract', COUNT(*) FROM hr_contract
UNION ALL SELECT 'project_project', COUNT(*) FROM project_project
UNION ALL SELECT 'project_task', COUNT(*) FROM project_task
UNION ALL SELECT 'timesheet_line', COUNT(*) FROM timesheet_line          -- expect ~19,000-20,000
UNION ALL SELECT 'hr_leave_type', COUNT(*) FROM hr_leave_type
UNION ALL SELECT 'hr_leave', COUNT(*) FROM hr_leave
UNION ALL SELECT 'hr_appraisal', COUNT(*) FROM hr_appraisal
UNION ALL SELECT 'hr_training', COUNT(*) FROM hr_training
UNION ALL SELECT 'hr_training_attendance', COUNT(*) FROM hr_training_attendance
UNION ALL SELECT 'hr_recruitment_application', COUNT(*) FROM hr_recruitment_application
UNION ALL SELECT 'dim_date', COUNT(*) FROM dim_date;                     -- expect 1,096 (2023-07-01 to 2026-06-30 inclusive)


-- ============================================================
-- SECTION 2: ORPHAN / REFERENTIAL INTEGRITY CHECKS
-- ============================================================
-- 
-- 2a. Any timesheet_line.work_date NOT covered by dim_date?
-- Expected: 0 rows.
SELECT tl.timesheet_id, tl.work_date
FROM timesheet_line tl
LEFT JOIN dim_date dd ON tl.work_date = dd.date_key
WHERE dd.date_key IS NULL;

-- 2b. Any hr_leave.start_date NOT covered by dim_date?
-- Expected: 0 rows.
SELECT l.leave_id, l.start_date
FROM hr_leave l
LEFT JOIN dim_date dd ON l.start_date = dd.date_key
WHERE dd.date_key IS NULL;

-- 2c. Cross-check row counts of the Phase 4 views that join to
-- dim_date against their source tables directly.
-- Expected: each pair of numbers matches exactly.
SELECT
    (SELECT COUNT(*) FROM timesheet_line)          AS timesheet_line_rows,
    (SELECT COUNT(*) FROM v_ops_timesheet_detail)  AS view_rows;

SELECT
    (SELECT COUNT(*) FROM hr_leave)                AS hr_leave_rows,
    (SELECT COUNT(*) FROM v_orgmgmt_leave_summary) AS view_rows;


-- ============================================================
-- SECTION 3: NULL-RATE CHECKS ON KEY FIELDS
-- ============================================================

-- 3a. termination_date: expect roughly 8% NULL-complement (i.e. ~8%
-- of employees SHOULD have a non-NULL termination_date, matching the
-- 8% attrition rate hard-coded in generate_horizon_data.py).
SELECT
    COUNT(*) FILTER (WHERE termination_date IS NOT NULL) * 100.0 / COUNT(*) AS pct_terminated
FROM hr_employee;

-- 3b. manager_employee_id: expect NULL only for Directors (~7 of 200
-- employees, i.e. ~3.5%).
SELECT
    COUNT(*) FILTER (WHERE manager_employee_id IS NULL) AS employees_with_no_manager,
    COUNT(*) FILTER (WHERE manager_employee_id IS NULL) * 100.0 / COUNT(*) AS pct
FROM hr_employee;

-- 3c. task_id in timesheet_line: expect ~10% NULL, matching the
-- generation script's deliberate "logged before a task exists" case.
SELECT
    COUNT(*) FILTER (WHERE task_id IS NULL) * 100.0 / COUNT(*) AS pct_null_task_id
FROM timesheet_line;


-- ============================================================
-- SECTION 4: BUSINESS-LOGIC SANITY CHECKS
-- ============================================================

-- 4a. Any appraisal rating outside the valid 1-5 scale?
-- Expected: 0 rows.
SELECT appraisal_id, overall_rating FROM hr_appraisal
WHERE overall_rating NOT BETWEEN 1 AND 5;

-- 4b. Any leave record where end_date is before start_date?
-- Expected: 0 rows.
SELECT leave_id, start_date, end_date FROM hr_leave
WHERE end_date < start_date;

-- 4c. Any contract where end_date is before start_date?
-- Expected: 0 rows.
SELECT contract_id, start_date, end_date FROM hr_contract
WHERE end_date IS NOT NULL AND end_date < start_date;

-- 4d. Any employee terminated BEFORE they were hired?
-- Expected: 0 rows.
SELECT employee_id, hire_date, termination_date FROM hr_employee
WHERE termination_date IS NOT NULL AND termination_date < hire_date;

-- 4e. Negative or implausibly large tenure.
-- Expected: 0 rows.
SELECT employee_id, employee_name, hire_date, tenure_years_full
FROM v_workforce_headcount
WHERE tenure_years_full < 0 OR tenure_years_full > 8;

-- 4f. Any timesheet_line with zero or negative hours_logged, or
-- above a 24-hour implausibility ceiling for a single day/task line?
-- Expected: 0 rows.
SELECT timesheet_id, hours_logged FROM timesheet_line
WHERE hours_logged <= 0 OR hours_logged > 24;

-- ============================================================
-- End of 00_data_quality_checks.sql
-- ============================================================