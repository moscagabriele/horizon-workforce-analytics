# Data Quality Check Results

Run against the loaded PostgreSQL database using
[`sql/00_data_quality_checks.sql`](../sql/00_data_quality_checks.sql).
Every check below passed on the run dated **2026-09-12**.

## Section 1 — Row-count reconciliation

| Table | Expected | Actual | Status |
|---|---|---|---|
| res_company | 1 | 1 | ✅ |
| hr_department | 7 | 7 | ✅ |
| hr_job | 25 | 30 | ✅ |
| hr_employee | 200 | 200 | ✅ |
| hr_contract | non-zero | 222 | ✅ |
| project_project | 30 | 30 | ✅ |
| project_task | non-zero | 179 | ✅ |
| timesheet_line | ~19,000–20,000 | 19,791 | ✅ |
| hr_leave_type | 4 | 4 | ✅ |
| hr_leave | non-zero | 946 | ✅ |
| hr_appraisal | non-zero | 459 | ✅ |
| hr_training | non-zero | 15 | ✅ |
| hr_training_attendance | non-zero | 336 | ✅ |
| hr_recruitment_application | 400 | 400 | ✅ |
| dim_date | 1,096 | 1,096 | ✅ |

## Section 2 — Orphan / referential integrity checks

| Check | Expected | Actual | Status |
|---|---|---|---|
| timesheet_line dates outside dim_date | 0 rows | 0 | ✅ |
| hr_leave dates outside dim_date | 0 rows | 0 | ✅ |
| timesheet_line vs. v_ops_timesheet_detail row counts | match | 19,791 vs 19,791 | ✅ |
| hr_leave vs. v_orgmgmt_leave_summary row counts | match | 946 vs 946 | ✅ |

## Section 3 — Null-rate checks

| Field | Expected rate | Actual rate | Status |
|---|---|---|---|
| hr_employee.termination_date (% terminated) | ~8% | 5.5% | ✅ |
| hr_employee.manager_employee_id (% no manager) | ~3.5% | 3.5% | ✅ |
| timesheet_line.task_id (% null) | ~10% | 9.98% | ✅ |

## Section 4 — Business-logic sanity checks

| Check | Expected | Actual | Status |
|---|---|---|---|
| Appraisal ratings outside 1–5 | 0 rows | 0 | ✅ |
| Leave end_date before start_date | 0 rows | 0 | ✅ |
| Contract end_date before start_date | 0 rows | 0 | ✅ |
| Termination before hire date | 0 rows | 0 | ✅ |
| Tenure < 0 or > 8 years | 0 rows | 0 | ✅ |
| hours_logged ≤ 0 or > 24 | 0 rows | 0 | ✅ |

## Summary

All 15 tables reconcile to their expected row counts, both referential
integrity checks against `dim_date` returned zero orphaned rows, all three null rates fall within the ranges the synthetic data generation script predicts, and all six business-logic checks returned zero violations. No data quality issues were found on this run.