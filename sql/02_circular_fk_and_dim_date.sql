-- ============================================================
-- Horizon Phase 3 — Circular FK fix + dim_date build
-- Run this AFTER 01_create_tables.sql and AFTER hr_employee has data
-- loaded (the circular FK check needs real employee rows to validate
-- against).
-- ============================================================

-- ------------------------------------------------------------
-- Circular FK fix: hr_department -> hr_employee
-- ------------------------------------------------------------
-- hr_department.department_head_employee_id was created without a FK
-- constraint in 01_create_tables.sql, because hr_employee didn't exist
-- yet at that point.
ALTER TABLE hr_department
ADD CONSTRAINT fk_hr_department_head
FOREIGN KEY (department_head_employee_id) REFERENCES hr_employee(employee_id);

-- ------------------------------------------------------------
-- dim_date: table + population
-- ------------------------------------------------------------
-- Grain: one row per calendar day. Built entirely in SQL (not Python)
-- since it's mechanical/formulaic, not something that benefits from
-- randomized synthetic generation.
CREATE TABLE dim_date (
    date_key       DATE PRIMARY KEY,
    year           INT,
    quarter        INT,
    month          INT,
    month_name     VARCHAR,
    day            INT,
    day_of_week    INT,
    day_name       VARCHAR,
    is_weekend     BOOLEAN,
    fiscal_year    INT,
    fiscal_quarter INT
);

-- Populate one row per day across the project's date range.

-- Populate one row per day across the project's date range.
-- FIX: generate_series() is called ONCE here, in the FROM clause,
-- and aliased as "d". Every column below just reads from "d" instead
-- of calling generate_series() again. This avoids the Postgres error
-- "argument of CASE/WHEN must not return a set" — Postgres doesn't
-- allow a set-returning function like generate_series() to be called
-- again inside a CASE expression.
INSERT INTO dim_date (
    date_key, year, quarter, month, day,
    month_name, day_of_week, day_name, is_weekend,
    fiscal_year, fiscal_quarter
)
SELECT
    d::date                          AS date_key,
    EXTRACT(YEAR FROM d)::INT        AS year,
    EXTRACT(QUARTER FROM d)::INT     AS quarter,
    EXTRACT(MONTH FROM d)::INT       AS month,
    EXTRACT(DAY FROM d)::INT         AS day,
    TRIM(TO_CHAR(d, 'Month'))        AS month_name,
    EXTRACT(DOW FROM d)::INT         AS day_of_week,
    TRIM(TO_CHAR(d, 'Day'))          AS day_name,
    CASE WHEN EXTRACT(DOW FROM d) IN (0, 6)
         THEN true ELSE false END   AS is_weekend,
    -- Fiscal year starts July 1, named for the year it ends in
    -- (Jul 2023-Jun 2024 = fiscal year 2024)
    CASE WHEN EXTRACT(MONTH FROM d) >= 7
         THEN EXTRACT(YEAR FROM d)::INT + 1
         ELSE EXTRACT(YEAR FROM d)::INT
    END                               AS fiscal_year,
    CASE
        WHEN EXTRACT(MONTH FROM d) IN (7,8,9)   THEN 1
        WHEN EXTRACT(MONTH FROM d) IN (10,11,12) THEN 2
        WHEN EXTRACT(MONTH FROM d) IN (1,2,3)    THEN 3
        ELSE 4
    END                               AS fiscal_quarter
FROM generate_series('2023-07-01'::date, '2026-06-30'::date, '1 day'::interval) AS d;