# Horizon: Workforce, Capacity & Talent Analytics

**Business context:** Horizon is a fictional 200-person consulting/operations
firm. This project answers the questions a CHRO and department heads would
actually ask about headcount, project capacity, hiring, and employee
development.

---

## Executive Summary

Horizon runs at 75% utilization company-wide, but capacity strain is concentrated in one place: HR is logging hours at 415% of its budgeted allocation, nearly triple the next-highest department (Consulting, at 151%), despite holding the smallest budget of any team (697 hours), and its task completion rate (62.5%) is no better than the company average, meaning the overrun isn't buying extra delivery. On the people side, turnover fell to 1.59% (down 9% year-over-year) and training completion rose to 79.2% (+2.3 points), but the average appraisal score slipped slightly to 3.58 (-1.6%), a small dip worth watching alongside the capacity pressure above, not yet a trend.

## Business Questions This Project Answers

- **Workforce:** What does headcount, turnover, and tenure look like across departments and job levels?
- **Capacity:** How efficiently is billable time being used against project budgets?
- **Recruitment:** Where is the hiring pipeline losing candidates, and how fast is time-to-hire?
- **Talent:** Is training completion and performance review coverage keeping pace with headcount?
- **Organisational management:** How flat or hierarchical is the org, and how is leave being used?

## Key Insights & Recommendations

HR's capacity overrun is a budgeting problem, not a delivery one. HR logged 2,895 hours against a 697-hour budget (415% of plan, the only department over 200%), yet its task completion rate (62.5%) is no better than the company average, so the extra hours aren't buying extra output. Recommend HR's hours budget be rebuilt from actuals before the next planning cycle, rather than reallocating time from Operations, IT, or Finance; all three are also running 15–25% over their own budgets, so there's no real spare capacity to redirect.

Manager capacity is thinnest exactly where headcount is growing. Headcount grew 9.9% year-over-year (172 → 189), but Marketing (2.3 direct reports per manager) and HR (2.5) already have the lowest span of control company-wide, against a 3.39 firm average. Recommend prioritizing Lead-level hires in those two departments before adding further headcount, to avoid compressing manager capacity further.

The recruitment pipeline's largest single pool sits untouched at the earliest stage. 149 of 400 applications (37%) are currently in "Applied" status, more than any other stage, while only 30 have reached "Offer." Recommend a dedicated screening sprint targeting Applied-stage candidates, since that's where the biggest backlog of undecided applicants is concentrated.

Training completion is improving on average, but unevenly across categories. Overall completion rose 2.3 points to 79.2%, but within that, Compliance sessions make up only 27.8% of completions versus 41.2% for Soft Skills. Recommend prioritizing Compliance completion specifically next cycle, it typically carries the most regulatory weight, and the healthy topline number is masking it lagging behind.

<img width="1427" height="800" alt="image" src="https://github.com/user-attachments/assets/b78e45c5-55d8-4193-b50c-457fab0514f3" />

## Data Model

The Power BI model is a **starflake**: a star schema with one deliberate
snowflaked branch. Fact tables connect to a small set of dimensions, and the
`Department` lookups sit behind `Employee` rather than joining every
fact table directly.
 
### Tables
 
#### Dimensions
 
| Table | Grain | Source | Notes |
|---|---|---|---|
| `Employee` | One row per employee (200) | `v_workforce_headcount` merged with `v_workforce_org_structure` | Central dimension. Carries department and job attributes denormalized, plus manager and department-head links for the org-structure measures. |
| `dim_date` | One row per calendar day (1,096) | Built in SQL, not generated in Python | Covers 2023-07-01 to 2026-06-30, matching the synthetic data window exactly. |
| `Ops Projects` | One row per project (30) | `v_ops_project_utilization` | Used as a project dimension (name, client, status, budget hours). Its pre-aggregated hour columns are retained from the SQL layer but are not the source of any dashboard figure, see *Known limitations*. |
| `hr_department`, `hr_job` | One row per department (7) / job title (25) | Base tables | Hidden from report view. Present to route relationships, not to be browsed. |
| `hr_training`, `hr_leave_type` | One row per course (15) / leave category (4) | Base tables | Hidden. Their descriptive fields are already denormalized into the corresponding fact views. |
 
#### Facts
 
| Table | Grain | Source | Rows |
|---|---|---|---|
| `Ops Timesheets` | One row per person, per task, per day | `v_ops_timesheet_detail` | ~19,800 |
| `Ops Tasks` | One row per task within a project | `project_task` | ~165 |
| `Orgmgmt Leave` | One row per leave request | `v_orgmgmt_leave_summary` | 946 |
| `Talent Appraisal` | One row per performance review event | `v_talent_appraisal_summary` | 459 |
| `Talent Training` | One row per employee attending one course | `v_talent_training_completion` | 336 |
| `Recruitment Applications` | One row per job application | `hr_recruitment_application` | 400 |
| `hr_contract` | One row per contract period per employee | `hr_contract` | ~230 |

<img width="1181" height="718" alt="image" src="https://github.com/user-attachments/assets/c1e8b495-85fd-436a-a254-bc71fc2906ac" />

## Data Quality

Every load is validated against a standalone script before being trusted
in the dashboard: see [`sql/00_data_quality_checks.sql`](sql/00_data_quality_checks.sql).
It checks row-count reconciliation against the source CSVs, referential
integrity on the two joins not covered by a database-level foreign key
(the `dim_date` joins), and business-logic sanity checks (rating ranges,
date ordering, tenure bounds). Full check-by-check results from an actual
run are recorded in [`docs/data_quality_results.md`](docs/data_quality_results.md) —
every check currently passes.
 
**Known limitations** (stated up front, not discovered by a reviewer):
- The recruitment `stage` field is a current snapshot per application, not
  a logged history of stage transitions — this dataset can report the
  *distribution* of applications across stages, not a true funnel
  conversion rate.
- Salary-by-gender and salary-by-job-level breakdowns are computed on a
  200-person, 7-department, 5-level dataset — some cells are thin enough
  that the pattern should be treated as directional, not statistically
  robust.
- All data is synthetic, generated with a fixed random seed for
  reproducibility — this is a modeling and analysis exercise, not a
  claim about a real organization.
- `Ops Projects` retains the pre-aggregated hour columns from
  `v_ops_project_utilization` (total/billable/non-billable hours, %
  budget used) for reference, but every dashboard figure is computed
  live from `Ops Timesheets` instead — keeping one source of truth for
  capacity numbers rather than two that could drift apart.

## Tech Stack

| Layer | Tool |
|---|---|
| Synthetic data generation | Python (pandas, Faker) |
| Database | PostgreSQL |
| Transformation / reporting layer | SQL (views) |
| Data loading | Power Query |
| Semantic model | Power BI (star schema) |
| Measures | DAX |

## Repository Structure
 
```
├── README.md <- you are here (business narrative)
├── sql/
│   ├── 01_create_tables.sql
│   ├── 02_circular_fk_and_dim_date.sql
│   ├── 03_load_data_psql.sql
│   ├── phase4_workforce_views.sql
│   ├── phase4_operations_views.sql
│   ├── phase4_talent_views.sql
│   ├── phase4_orgmgmt_views.sql
│   └── 00_data_quality_checks.sql
├── python/
│   └── generate_horizon_data.py
├── output_csv/
│   └── (14 CSVs — one per table, regenerable via generate_horizon_data.py)
├── docs/
│   ├── data_dictionary.md
│   ├── design_decisions.md
│   └── data_quality_results.md
└── dashboard/
    ├── horizon_dashboard.pbix (and PDF)
```

## How to Reproduce

1. Run `python/generate_horizon_data.py` to regenerate the CSVs (seeded, output is deterministic).
2. Run `sql/01_create_tables.sql`, then `sql/03_load_data_psql.sql`, then `sql/02_circular_fk_and_dim_date.sql` in a fresh PostgreSQL database.
3. Run `sql/phase4_*.sql` to build the reporting views.
4. Run `sql/00_data_quality_checks.sql` and confirm all results match the expected values noted in its comments.
5. Open `dashboard/horizon_dashboard.pbix` in Power BI Desktop and point it at your local database.

## About This Project

This project grew directly out of my day job running HR and workforce reporting as a BI Analyst: building department-level headcount, capacity dashboards for real stakeholders made clear how much of that value comes from the data model and pipeline underneath the dashboard, not the dashboard alone. 

Horizon lets me go deeper into the parts of that stack a day job built on an existing ERP and pre-built data sources doesn't require: schema design from scratch, a full PostgreSQL and SQL transformation layer, and Python-based data generation, all built end to end and validated with an explicit data quality process. All data here is synthetic, generated independently for this project: it doesn't use or represent any employer's data.
