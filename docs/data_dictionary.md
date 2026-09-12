# Data Dictionary

Documents the raw PostgreSQL schema built in `sql/01_create_tables.sql` and `sql/02_circular_fk_and_dim_date.sql` — the source tables everything else is built on top of. For how these tables are reshaped into the Power BI star schema, see the **Data Model** section of the main README instead — this file documents the database layer, not the report layer.

Value lists (e.g. what `job_level` actually contains) come from `python/generate_horizon_data.py`, since several fields are plain `VARCHAR`in the DDL with no `CHECK` constraint — the generation script is the only place the real set of values is defined.

---

## res_company

**Grain:** one row — the company itself.

| Column | Type | Description |
|---|---|---|
| `company_id` | INT, PK | Unique identifier. |
| `company_name` | VARCHAR | "Horizon" — the single fictional company this dataset represents. |
| `founded_year` | INT | |
| `headquarters_city` | VARCHAR | |
| `headquarters_country` | VARCHAR | |
| `industry` | VARCHAR | "Professional Services." |

## hr_department

**Grain:** one row per department (7 rows: Consulting, Operations, IT, Human Resources, Finance, Sales, Marketing).

| Column | Type | Description |
|---|---|---|
| `department_id` | INT, PK | |
| `department_name` | VARCHAR | |
| `department_code` | VARCHAR | Short code (e.g. `CONS`, `OPS`, `IT`). |
| `company_id` | INT, FK → res_company | |
| `department_head_employee_id` | INT, FK → hr_employee | Nullable. Added via `ALTER TABLE` after `hr_employee` exists — see `design_decisions.md` for why. |

## hr_job

**Grain:** one row per job title (25 rows), each tied to exactly one department.

| Column | Type | Description |
|---|---|---|
| `job_id` | INT, PK | |
| `job_title` | VARCHAR | e.g. "Senior Consultant," "HR Manager." |
| `department_id` | INT, FK → hr_department | |
| `job_level` | VARCHAR | One of: `Junior`, `Mid`, `Senior`, `Lead`, `Director`. |

## hr_employee

**Grain:** one row per employee's current record (200 rows).

| Column | Type | Description |
|---|---|---|
| `employee_id` | INT, PK | |
| `first_name`, `last_name` | VARCHAR | |
| `gender` | VARCHAR | `Female` or `Male`. |
| `date_of_birth` | DATE | |
| `hire_date` | DATE, NOT NULL | |
| `termination_date` | DATE, nullable | `NULL` = still employed. There is deliberately no separate `employment_status` column — active/terminated is always derived as `termination_date IS NULL`, never stored twice. |
| `department_id` | INT, FK → hr_department | |
| `job_id` | INT, FK → hr_job | |
| `manager_employee_id` | INT, FK → hr_employee (self-referencing) | Nullable — Directors have no manager. |
| `email` | VARCHAR | |
| `company_id` | INT, FK → res_company | |

## hr_contract

**Grain:** one row per contract period per employee. Most employees have exactly one row; ~15% have two, simulating an FTE change or a fixed-term-to-permanent conversion.

| Column | Type | Description |
|---|---|---|
| `contract_id` | INT, PK | |
| `employee_id` | INT, FK → hr_employee | |
| `contract_type` | VARCHAR | `Permanent`, `Fixed-term`, or `Intern`. |
| `fte_percentage` | NUMERIC(5,2) | e.g. 50.00, 80.00, 100.00. |
| `base_salary` | NUMERIC(12,2) | |
| `start_date` | DATE, NOT NULL | |
| `end_date` | DATE, nullable | `NULL` = current contract. |

## hr_leave_type

**Grain:** one row per leave category (4 rows — fixed reference list, not generated).

| Column | Type | Description |
|---|---|---|
| `leave_type_id` | INT, PK | |
| `leave_type_name` | VARCHAR | `Annual`, `Sick`, `Unpaid`, `Parental`. |
| `is_paid` | BOOLEAN | |

## hr_leave

**Grain:** one row per leave request.

| Column | Type | Description |
|---|---|---|
| `leave_id` | INT, PK | |
| `employee_id` | INT, FK → hr_employee | |
| `leave_type_id` | INT, FK → hr_leave_type | |
| `start_date`, `end_date` | DATE, NOT NULL | |
| `days_taken` | NUMERIC(5,2) | |
| `status` | VARCHAR | `Approved`, `Pending`, or `Rejected`. |

## project_project

**Grain:** one row per project (30 rows).

| Column | Type | Description |
|---|---|---|
| `project_id` | INT, PK | |
| `project_name` | VARCHAR | |
| `client_name` | VARCHAR | |
| `department_id` | INT, FK → hr_department | Owning department. |
| `start_date` | DATE, NOT NULL | |
| `end_date` | DATE, nullable | `NULL` = still open. |
| `status` | VARCHAR | `Active`, `Completed`, or `On Hold`. |
| `budget_hours` | NUMERIC(10,2) | |

## project_task

**Grain:** one row per task within a project.

| Column | Type | Description |
|---|---|---|
| `task_id` | INT, PK | |
| `project_id` | INT, FK → project_project | |
| `task_name` | VARCHAR | |
| `assigned_employee_id` | INT, FK → hr_employee | Nullable — unassigned tasks are allowed. |
| `status` | VARCHAR | `To Do`, `In Progress`, or `Done`. |
| `planned_hours` | NUMERIC(8,2) | |
| `created_date`, `due_date` | DATE | |

## timesheet_line

**Grain:** one row per person, per task (or no task), per day. The largest table (~19,800 rows).

| Column | Type | Description |
|---|---|---|
| `timesheet_id` | BIGINT, PK | `BIGINT` rather than `INT`, for headroom on the biggest table. |
| `employee_id` | INT, FK → hr_employee | Who logged the hours. |
| `project_id` | INT, FK → project_project | Deliberately duplicated here even though it's derivable via `task_id → project_task.project_id` — see `design_decisions.md`. |
| `task_id` | INT, FK → project_task | Nullable — ~10% of lines are logged before a task exists yet. |
| `work_date` | DATE, NOT NULL | |
| `hours_logged` | NUMERIC(5,2) | |
| `billable` | BOOLEAN | |

## hr_appraisal

**Grain:** one row per performance review event.

| Column | Type | Description |
|---|---|---|
| `appraisal_id` | INT, PK | |
| `employee_id` | INT, FK → hr_employee | The person being reviewed. |
| `reviewer_employee_id` | INT, FK → hr_employee | The reviewer — usually the employee's manager. |
| `appraisal_date` | DATE, NOT NULL | |
| `overall_rating` | INT | 1–5. Not `CHECK`-constrained at the database level. |
| `promotion_recommended` | BOOLEAN | |

## hr_training

**Grain:** one row per course in the catalogue (15 rows — fixed reference list).

| Column | Type | Description |
|---|---|---|
| `training_id` | INT, PK | |
| `training_name` | VARCHAR | |
| `category` | VARCHAR | `Technical`, `Compliance`, or `Soft Skills`. |
| `delivery_method` | VARCHAR | `Online` or `In-person`. |
| `duration_hours` | NUMERIC(5,2) | |

## hr_training_attendance

**Grain:** one row per employee attending one training. Junction/bridge table resolving the many-to-many between `hr_training` and `hr_employee`.

| Column | Type | Description |
|---|---|---|
| `attendance_id` | INT, PK | |
| `training_id` | INT, FK → hr_training | |
| `employee_id` | INT, FK → hr_employee | |
| `attendance_date` | DATE, NOT NULL | |
| `completion_status` | VARCHAR | `Completed`, `In Progress`, or `No-show`. |

## hr_recruitment_application

**Grain:** one row per job application (400 rows).

| Column | Type | Description |
|---|---|---|
| `application_id` | INT, PK | |
| `job_id` | INT, FK → hr_job | |
| `candidate_name` | VARCHAR | |
| `application_date` | DATE, NOT NULL | |
| `stage` | VARCHAR | `Applied`, `Interview`, `Offer`, `Hired`, or `Rejected`. A current snapshot per application, not a logged history — see *Known limitations* in the README. |
| `hired_employee_id` | INT, FK → hr_employee | Nullable — set only when `stage = 'Hired'`. |

## dim_date

**Grain:** one row per calendar day (1,096 rows, 2023-07-01 to 2026-06-30).

| Column | Type | Description |
|---|---|---|
| `date_key` | DATE, PK | |
| `year`, `quarter`, `month`, `day` | INT | |
| `month_name`, `day_name` | VARCHAR | |
| `day_of_week` | INT | 0–6. |
| `is_weekend` | BOOLEAN | |
| `fiscal_year` | INT | Fiscal year starts July 1, named for the year it ends in (Jul 2023–Jun 2024 = fiscal year 2024). |
| `fiscal_quarter` | INT | 1–4, aligned to the fiscal year above. |
