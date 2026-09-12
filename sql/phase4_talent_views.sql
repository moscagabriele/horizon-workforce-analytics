-- ============================================================
-- Horizon Phase 4 — Talent domain reporting views
-- ============================================================
-- Domain: Talent
-- Tables used: hr_training, hr_training_attendance, hr_appraisal,
--              hr_recruitment_application, hr_job, hr_employee,
--              hr_department
-- ============================================================

-- ------------------------------------------------------------
-- View 1: v_talent_training_completion
-- ------------------------------------------------------------
-- GRAIN: one row per training attendance record
CREATE OR REPLACE VIEW v_talent_training_completion AS
SELECT
    ta.attendance_id,
    ta.employee_id,
    e.first_name || ' ' || e.last_name  AS employee_name,
    e.department_id,
    d.department_name,
    ta.training_id,
    t.training_name,
    t.category,
    t.delivery_method,
    t.duration_hours,
    ta.attendance_date,
    ta.completion_status
FROM hr_training_attendance ta
JOIN hr_employee e    ON ta.employee_id = e.employee_id
JOIN hr_department d  ON e.department_id = d.department_id
JOIN hr_training t    ON ta.training_id = t.training_id;

-- ------------------------------------------------------------
-- View 2: v_talent_appraisal_summary
-- ------------------------------------------------------------
-- GRAIN: one row per appraisal event — same grain as hr_appraisal.
CREATE OR REPLACE VIEW v_talent_appraisal_summary AS
SELECT
    a.appraisal_id,
    a.employee_id,
    e.first_name || ' ' || e.last_name   AS employee_name,
    d.department_name,
    j.job_title,
    j.job_level,
    a.reviewer_employee_id,
    r.first_name || ' ' || r.last_name   AS reviewer_name,
    a.appraisal_date,
    a.overall_rating,
    a.promotion_recommended,
    ROUND(AVG(a.overall_rating) OVER (PARTITION BY a.employee_id), 2) AS employee_avg_rating
FROM hr_appraisal a
JOIN hr_employee e   ON a.employee_id = e.employee_id
JOIN hr_department d ON e.department_id = d.department_id
JOIN hr_job j         ON e.job_id = j.job_id
JOIN hr_employee r    ON a.reviewer_employee_id = r.employee_id;


-- ------------------------------------------------------------
-- View 3: v_talent_recruitment_funnel
-- ------------------------------------------------------------
-- GRAIN: one row per (department, stage) combination — an aggregate,
-- not a per-application detail view.

CREATE OR REPLACE VIEW v_talent_recruitment_funnel AS
WITH stages AS (
    SELECT *
    FROM (VALUES
        ('Applied',   1),
        ('Interview', 2),
        ('Offer',     3),
        ('Hired',     4),
        ('Rejected',  5)
    ) AS s(stage, stage_sort_order)
),
dept_stage_grid AS (
    SELECT d.department_id, d.department_name, s.stage, s.stage_sort_order
    FROM hr_department d
    CROSS JOIN stages s
),
app_counts AS (
    SELECT j.department_id, ra.stage, COUNT(*) AS application_count
    FROM hr_recruitment_application ra
    JOIN hr_job j ON ra.job_id = j.job_id
    GROUP BY j.department_id, ra.stage
)
SELECT
    g.department_id,
    g.department_name,
    g.stage,
    g.stage_sort_order,
    COALESCE(a.application_count, 0) AS application_count,
    ROUND(
        COALESCE(a.application_count, 0) * 100.0
        / NULLIF(SUM(COALESCE(a.application_count, 0)) OVER (PARTITION BY g.department_id), 0),
        1
    ) AS pct_of_department_applications
FROM dept_stage_grid g
LEFT JOIN app_counts a
    ON g.department_id = a.department_id AND g.stage = a.stage
ORDER BY g.department_id, g.stage_sort_order;

-- ============================================================
-- CHECKPOINT — run these after creating the views above
-- ============================================================

-- 1. Row counts should match their source tables exactly (no rows
--    filtered or duplicated): hr_training_attendance (336),
--    hr_appraisal (459).
SELECT 'v_talent_training_completion' AS view_name, COUNT(*) FROM v_talent_training_completion
UNION ALL
SELECT 'v_talent_appraisal_summary', COUNT(*) FROM v_talent_appraisal_summary;

-- 2. Spot-check the partitioned average: pick any one employee and
--    confirm employee_avg_rating matches a manual AVG() of their rows.
SELECT employee_id, appraisal_date, overall_rating, employee_avg_rating
FROM v_talent_appraisal_summary
WHERE employee_id = 1
ORDER BY appraisal_date;

-- 3. Funnel grid should be exactly 7 departments x 5 stages = 35 rows,
--    regardless of how many of those combinations have zero applications.
SELECT COUNT(*) AS row_count FROM v_talent_recruitment_funnel;

-- 4. Application counts across the whole grid should sum to exactly
--    400 (total rows in hr_recruitment_application) — confirms the
--    grid-fill didn't lose or duplicate any real applications.
SELECT SUM(application_count) AS total_applications FROM v_talent_recruitment_funnel;

-- 5. Percentages within each department should sum to ~100 (allowing
--    for rounding), except departments with zero applications, where
--    NULLIF makes the whole column NULL rather than a divide-by-zero
--    error.
SELECT department_name, SUM(pct_of_department_applications) AS pct_sum
FROM v_talent_recruitment_funnel
GROUP BY department_name;

-- ============================================================
-- End of phase4_talent_views.sql
-- ============================================================