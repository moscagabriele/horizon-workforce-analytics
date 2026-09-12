-- ============================================================
-- Horizon Phase 4 — Workforce domain reporting views
-- ============================================================
-- Domain: Workforce
-- Tables used: hr_employee, hr_department, hr_job
--
-- RUN THIS AFTER: 01_create_tables.sql, 02_circular_fk_and_dim_date.sql,

-- ============================================================

-- ------------------------------------------------------------
-- View 1: v_workforce_headcount
-- ------------------------------------------------------------
-- GRAIN: one row per employee (current record)

CREATE OR REPLACE VIEW v_workforce_headcount AS
WITH reference_date AS (
      SELECT DATE '2026-06-30' AS as_of_date
)
SELECT
    e.employee_id,
    e.first_name,
    e.last_name,
    e.first_name || ' ' || e.last_name AS employee_name,                        
    d.department_id,
    d.department_name,
    j.job_id,
    j.job_title,
    j.job_level,
    e.hire_date,
    e.termination_date,

    (e.termination_date IS NULL) AS is_active,
  
    EXTRACT(
        YEAR FROM AGE(
            COALESCE(e.termination_date, r.as_of_date),
            e.hire_date
        )
    )::INT AS tenure_years_full,
    AGE(COALESCE(e.termination_date, r.as_of_date), e.hire_date) AS tenure_interval

    e.date_of_birth,
    e.gender  

FROM hr_employee e
JOIN hr_department d ON e.department_id = d.department_id
JOIN hr_job j        ON e.job_id = j.job_id
CROSS JOIN reference_date r;

-- ------------------------------------------------------------
-- View 2: v_workforce_org_structure
-- ------------------------------------------------------------
-- GRAIN: one row per employee, showing their manager and their
-- department's head
CREATE OR REPLACE VIEW v_workforce_org_structure AS
SELECT
    e.employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    j.job_title,
    j.job_level,
    d.department_id,
    d.department_name,
    e.manager_employee_id,
    mgr.first_name || ' ' || mgr.last_name AS manager_name,
    d.department_head_employee_id,
    head.first_name || ' ' || head.last_name AS department_head_name,
    -- Convenience flag: is this employee their own department's head?
    (e.employee_id = d.department_head_employee_id) AS is_department_head
FROM hr_employee e
JOIN hr_department d       ON e.department_id = d.department_id
JOIN hr_job j               ON e.job_id = j.job_id
LEFT JOIN hr_employee mgr   ON e.manager_employee_id = mgr.employee_id
LEFT JOIN hr_employee head  ON d.department_head_employee_id = head.employee_id;


-- ============================================================
-- CHECKPOINT — run these after creating the views above
-- ============================================================

-- 1. Row counts should match hr_employee exactly (200) for both views,
--    since neither view filters any rows out — they only add columns.
SELECT 'v_workforce_headcount' AS view_name, COUNT(*) FROM v_workforce_headcount
UNION ALL
SELECT 'v_workforce_org_structure', COUNT(*) FROM v_workforce_org_structure;

-- 2. Sanity check on tenure: nobody should have a negative tenure. A row here means a data or logic bug.
SELECT employee_id, employee_name, hire_date, tenure_years_full
FROM v_workforce_headcount
WHERE tenure_years_full < 0 OR tenure_years_full > 8;

-- 3. Confirm Directors correctly show NULL managers (expected — this
--    should return rows, not zero rows). If it returns zero, the
--    LEFT JOIN got swapped for an INNER JOIN somewhere.
SELECT employee_name, job_level, manager_employee_id
FROM v_workforce_org_structure
WHERE job_level = 'Director';

-- 4. Confirm every department has exactly one head, and that head is a
--    Director or Lead
SELECT department_name, department_head_name
FROM v_workforce_org_structure
WHERE is_department_head = true;

-- ============================================================
-- End of phase4_workforce_views.sql
-- ============================================================
