-- ============================================================
-- Horizon Phase 4 — Operations/Capacity domain reporting views
-- ============================================================
-- Domain: Operations/Capacity
-- Tables used: project_project, project_task, timesheet_line, dim_date
--
-- RUN THIS AFTER: phase4_workforce_views.sql (not a hard dependency,
-- but keeps a consistent build order) and after confirming dim_date
-- is populated — these views join to it directly, unlike the
-- Workforce views.
-- ============================================================

-- ------------------------------------------------------------
-- View 1: v_ops_timesheet_detail
-- ------------------------------------------------------------
-- GRAIN: one row per timesheet line
CREATE OR REPLACE VIEW v_ops_timesheet_detail AS
SELECT
    tl.timesheet_id,

    -- Employee (who logged the hours) and their department
    tl.employee_id,
    e.first_name || ' ' || e.last_name          AS employee_name,
    e.department_id                              AS employee_department_id,
    ed.department_name                           AS employee_department_name,

    -- Project (what the hours were for) and its department
    tl.project_id,
    p.project_name,
    p.client_name,
    p.department_id                               AS project_department_id,
    pd.department_name                            AS project_department_name,

    -- Task (nullable)
    tl.task_id,
    pt.task_name,

    -- Calendar attributes, pulled from dim_date instead of recomputed
    -- with EXTRACT() every time
    tl.work_date,
    dd.year,
    dd.quarter,
    dd.month,
    dd.month_name,
    dd.day_name,
    dd.is_weekend,

    tl.hours_logged,
    tl.billable
FROM timesheet_line tl
JOIN hr_employee e        ON tl.employee_id = e.employee_id
JOIN hr_department ed     ON e.department_id = ed.department_id
JOIN project_project p    ON tl.project_id = p.project_id
JOIN hr_department pd     ON p.department_id = pd.department_id
LEFT JOIN project_task pt ON tl.task_id = pt.task_id
JOIN dim_date dd          ON tl.work_date = dd.date_key;

-- ------------------------------------------------------------
-- View 2: v_ops_project_utilization
-- ------------------------------------------------------------
-- GRAIN: one row per project — aggregates timesheet_line and
-- project_task down to project level
CREATE OR REPLACE VIEW v_ops_project_utilization AS
WITH task_counts AS (
    -- One row per project: how many tasks it has, and how many are Done.
    SELECT
        project_id,
        COUNT(*)                                   AS task_count,
        COUNT(*) FILTER (WHERE status = 'Done')     AS tasks_done_count
    FROM project_task
    GROUP BY project_id
),
hours_agg AS (
    -- One row per project: total hours, split into billable/non-billable
    -- using FILTER instead of two separate subqueries.
    SELECT
        project_id,
        SUM(hours_logged)                                 AS total_hours_logged,
        SUM(hours_logged) FILTER (WHERE billable)          AS billable_hours,
        SUM(hours_logged) FILTER (WHERE NOT billable)      AS non_billable_hours
    FROM timesheet_line
    GROUP BY project_id
)
SELECT
    p.project_id,
    p.project_name,
    p.client_name,
    d.department_name,
    p.status,
    p.start_date,
    p.end_date,
    p.budget_hours,

    -- COALESCE to 0 here (not left as NULL) because "no timesheet
    -- lines yet" should read as zero hours, not missing data
    COALESCE(h.total_hours_logged, 0)                  AS total_hours_logged,
    COALESCE(h.billable_hours, 0)                       AS billable_hours,
    COALESCE(h.non_billable_hours, 0)                   AS non_billable_hours,

    -- NULLIF turns budget_hours = 0 into NULL before the division
    ROUND(
        COALESCE(h.total_hours_logged, 0) / NULLIF(p.budget_hours, 0) * 100,
        1
    )                                                    AS pct_budget_used,

    COALESCE(t.task_count, 0)                            AS task_count,
    COALESCE(t.tasks_done_count, 0)                       AS tasks_done_count,

    -- Window function: ranks every project by hours logged, without
    -- collapsing the other columns the way a GROUP BY would.
    RANK() OVER (ORDER BY COALESCE(h.total_hours_logged, 0) DESC) AS hours_rank

    d.department_id,        -- ADDED: relationship key for Power BI

FROM project_project p
JOIN hr_department d      ON p.department_id = d.department_id
LEFT JOIN hours_agg h     ON p.project_id = h.project_id
LEFT JOIN task_counts t   ON p.project_id = t.project_id;

-- ============================================================
-- CHECKPOINT — run these after creating the views above
-- ============================================================

-- 1. Row count should match timesheet_line exactly (~19,791)
SELECT COUNT(*) AS row_count FROM v_ops_timesheet_detail;

-- 2. Orphan check
SELECT
    (SELECT COUNT(*) FROM timesheet_line)        AS timesheet_line_rows,
    (SELECT COUNT(*) FROM v_ops_timesheet_detail) AS view_rows;

-- 3. Task nullability sanity check: roughly 10% of rows should have a
--    NULL task_id, matching the Phase 2 generation logic.
SELECT
    COUNT(*) FILTER (WHERE task_id IS NULL) * 100.0 / COUNT(*) AS pct_null_task_id
FROM v_ops_timesheet_detail;

-- 4. Row count for utilization view should match project_project exactly (30)
SELECT COUNT(*) AS row_count FROM v_ops_project_utilization;

-- 5. Sanity check: no project should show more billable + non-billable
--    hours than total_hours_logged (they should sum to it exactly).
--    A row here means the FILTER logic has a bug.
SELECT project_id, project_name, total_hours_logged, billable_hours, non_billable_hours
FROM v_ops_project_utilization
WHERE ROUND(billable_hours + non_billable_hours, 2) != ROUND(total_hours_logged, 2);

-- ============================================================
-- End of phase4_operations_views.sql
-- ============================================================