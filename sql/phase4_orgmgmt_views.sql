-- ============================================================
-- Horizon Phase 4 — Organisational management domain reporting view
-- ============================================================
-- Domain: Organisational management
-- Tables used: hr_leave, hr_leave_type, hr_employee, hr_department,
--              dim_date
-- ============================================================

-- ------------------------------------------------------------
-- View: v_orgmgmt_leave_summary
-- ------------------------------------------------------------
-- GRAIN: one row per leave request

CREATE OR REPLACE VIEW v_orgmgmt_leave_summary AS
SELECT
    l.leave_id,
    l.employee_id,
    e.first_name || ' ' || e.last_name  AS employee_name,
    e.department_id,
    d.department_name,
    l.leave_type_id,
    lt.leave_type_name,
    lt.is_paid,
    l.start_date,
    l.end_date,
    l.days_taken,
    l.status,

    -- Calendar attributes from dim_date, keyed off start_date.
    dd.year,
    dd.quarter,
    dd.month,
    dd.month_name,


    SUM(l.days_taken) FILTER (WHERE l.status = 'Approved')
        OVER (PARTITION BY l.employee_id, EXTRACT(YEAR FROM l.start_date))
        AS employee_approved_days_this_year

FROM hr_leave l
JOIN hr_employee e    ON l.employee_id = e.employee_id
JOIN hr_department d  ON e.department_id = d.department_id
JOIN hr_leave_type lt ON l.leave_type_id = lt.leave_type_id
JOIN dim_date dd      ON l.start_date = dd.date_key;


-- ============================================================
-- CHECKPOINT — run these after creating the view above
-- ============================================================

-- 1. Row count should match hr_leave exactly (946)
SELECT COUNT(*) AS row_count FROM v_orgmgmt_leave_summary;

-- 2. Orphan check on the dim_date join: compare against hr_leave's own
--    row count directly
SELECT
    (SELECT COUNT(*) FROM hr_leave)              AS hr_leave_rows,
    (SELECT COUNT(*) FROM v_orgmgmt_leave_summary) AS view_rows;

SELECT employee_id, start_date, status, days_taken, employee_approved_days_this_year
FROM v_orgmgmt_leave_summary
WHERE employee_id = 1
ORDER BY start_date;

SELECT
    employee_id,
    EXTRACT(YEAR FROM start_date) AS leave_year,
    SUM(days_taken) AS manual_approved_sum
FROM v_orgmgmt_leave_summary
WHERE employee_id = 1 AND status = 'Approved'
GROUP BY employee_id, EXTRACT(YEAR FROM start_date)
ORDER BY leave_year;

-- ============================================================
-- End of phase4_orgmgmt_views.sql
-- ============================================================
