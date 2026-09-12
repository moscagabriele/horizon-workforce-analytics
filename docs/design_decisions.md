# Design Decisions

Explains the non-obvious choices in the database and reporting layer. For the Power BI star-vs-starflake decision specifically, see the **Data Model** section of the main README.

## The circular foreign key: `hr_department` ↔ `hr_employee`

**The problem:** each table logically needs to reference the other. A department needs to point to its head (an employee), and an employee needs to point to their department. Whichever table you try to `CREATE` first, the other one doesn't exist yet, so a normal `FOREIGN KEY` clause can't be written for it.

**The fix:** break the cycle in two steps, matched exactly between the SQL and the Python generation script:

1. In `01_create_tables.sql`, `hr_department.department_head_employee_id` is created as a plain `INT` column with no `REFERENCES` clause at all.
2. Once `hr_employee` exists and is loaded, `02_circular_fk_and_dim_date.sql` adds the constraint retroactively with `ALTER TABLE ... ADD CONSTRAINT`.

`generate_horizon_data.py` does the same thing in Python: it generates `hr_department` with `department_head_employee_id` left `None`, generates `hr_employee` afterwards, then goes back and fills the column in. Python can't resolve a genuine circular dependency any more than SQL can, the two-step pattern is identical in both places on purpose.

**Alternative rejected:** Postgres supports `DEFERRABLE INITIALLY DEFERRED` constraints, which would let both `FOREIGN KEY`s be declared upfront and only checked at transaction commit. This would work, but adds a concept (deferred constraint checking) that isn't needed anywhere else in this schema, for a problem a two-step `ALTER TABLE` already solves plainly.

## Grain discipline in the Phase 4 views

Every `CREATE TABLE` and every `CREATE VIEW` in this project states its grain (what one row represents) in a comment directly above it. This isn't decorative, it's the check used while writing every join: a join is only safe if it can't silently duplicate or drop rows relative to the grain being started from.

Where a view needed to show a per-row detail *and* an aggregate over that same group without collapsing rows, a window function (`OVER (PARTITION BY ...)`) was used instead of `GROUP BY`, e.g. `v_talent_appraisal_summary` shows every individual appraisal row alongside that employee's running average rating; a `GROUP BY` could give one or the other, not both without a second query.

## Deliberate denormalization: `timesheet_line.project_id`

`project_id` is duplicated on `timesheet_line` even though it's derivable via `task_id → project_task.project_id`.

**Why the duplication is kept anyway:** `task_id` is nullable, about 10% of timesheet lines are logged before a task exists yet (reflecting real timesheet behavior: people log hours against a project before its task breakdown is finalized). Without a duplicated `project_id`, those rows would have no way to attribute hours to a project at all, which would break every capacity/utilization measure for exactly the rows most likely to represent early-stage project work. The trade-off is a small amount of redundant data against keeping the fact table fully usable on its own.

## Why SQL views instead of ad-hoc queries per report

Phase 4 built views (`v_workforce_headcount`, `v_ops_timesheet_detail`, etc.) rather than leaving the joins to be written fresh in Power Query or DAX. A view is a saved, reusable `SELECT`, Power Query and Power BI connect to something that already has the joins resolved, instead of every downstream tool re-deriving the same logic independently. If a join needs to change, it changes in one place (the view definition) instead of needing to be found and fixed in Power Query M code, DAX, and any other consumer separately.

## Fixed reference date instead of `CURRENT_DATE`

`v_workforce_headcount`'s tenure calculation uses a hard-coded date (`2026-06-30`) rather than `CURRENT_DATE`. This dataset has a fixed synthetic timeline, `PROJECT_END` in `generate_horizon_data.py` and tenure should be measured against *that* endpoint, not against whatever day someone happens to run the query. Using `CURRENT_DATE` would make every tenure figure silently drift a little further every day the query is run, which would make two people running the same view on different days see different, both "correct," numbers, a reproducibility problem for a project whose whole point is a fixed, seeded dataset.

## Recruitment funnel: reporting a snapshot, not a conversion rate

`hr_recruitment_application.stage` stores each application's *current* status (`Applied`, `Interview`, `Offer`, `Hired`, `Rejected`), it is not a logged history of very stage an application passed through. This means the data can answer "what does the pipeline look like right now" (a distribution across stages) but cannot answer "of everyone who reached Interview, what percentage advanced to Offer" (a true funnel conversion rate), because the transition history that question needs doesn't exist in the source data. Every place this shows up in the SQL, the views, and the README is deliberately worded as a distribution, never as a
conversion rate, a small wording choice, but one that keeps the project from claiming a precision the underlying data doesn't support.