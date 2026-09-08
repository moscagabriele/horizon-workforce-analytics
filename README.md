# Horizon: Workforce, Capacity & Talent Analytics

**Business context:** Horizon is a fictional 200-person consulting/operations
firm. This project answers the questions a CHRO and department heads would
actually ask about headcount, project capacity, hiring, and employee
development — not a technical exercise in SQL or Power BI syntax.

> ⚠️ Fill in the bracketed placeholders below once Phase 7 (dashboard) is
> finished and you've looked at the real output. Don't publish this file
> with placeholders still in it — an unfilled template is worse than no
> README, because it signals the project was left unfinished.

---

## Executive Summary

[2-4 sentences, written LAST after you've seen your own dashboard. State the
single most interesting/surprising insight your data actually shows, in
plain business language, with a number attached. Example shape only —
replace entirely: "Utilization sits at 68% company-wide, but Consulting
runs 15 points above every other department while Marketing sits at 51% —
a capacity imbalance worth ~[X] hours/month if rebalanced."]

## Business Questions This Project Answers

- **Workforce:** What does headcount, turnover, and tenure look like across departments and job levels?
- **Capacity:** How efficiently is billable time being used against project budgets?
- **Recruitment:** Where is the hiring pipeline losing candidates, and how fast is time-to-hire?
- **Talent:** Is training completion and performance review coverage keeping pace with headcount?
- **Organisational management:** How flat or hierarchical is the org, and how is leave being used?

## Key Insights & Recommendations

[This is the section a hiring manager actually reads. 3-5 bullets, each
one insight + one quantified, specific recommendation — not "improve
retention" but "reduce Marketing's 51% utilization gap by reallocating
X hours/month, worth approximately $Y in recovered billable capacity."
Write these only after building the Phase 7 dashboard.]

## Data Model

[Insert a screenshot or link to your Power BI star schema / ERD here once
Phase 6 is finalized. One sentence on why a star schema was chosen over
querying the normalized OLTP tables directly.]

## Data Quality

Every load is validated against a standalone script before being trusted
in the dashboard — see [`sql/00_data_quality_checks.sql`](sql/00_data_quality_checks.sql).
It checks row-count reconciliation against the source CSVs, referential
integrity on the two joins not covered by a database-level foreign key
(the `dim_date` joins), and business-logic sanity checks (rating ranges,
date ordering, tenure bounds).

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
├── README.md                  <- you are here (business narrative)
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
├── docs/
│   ├── data_dictionary.md     <- [to write: one row per table/column]
│   └── design_decisions.md    <- [to write: grain, circular FK, why views]
└── dashboard/
    └── horizon_dashboard.pbix (or screenshots, if file size is an issue)
```

## How to Reproduce

1. Run `python/generate_horizon_data.py` to regenerate the CSVs (seeded — output is deterministic).
2. Run `sql/01_create_tables.sql`, then `sql/03_load_data_psql.sql`, then `sql/02_circular_fk_and_dim_date.sql` in a fresh PostgreSQL database.
3. Run `sql/phase4_*.sql` to build the reporting views.
4. Run `sql/00_data_quality_checks.sql` and confirm all results match the expected values noted in its comments.
5. Open `dashboard/horizon_dashboard.pbix` in Power BI Desktop and point it at your local database.

## About This Project

[One or two sentences on what you built and why — state it as work you did,
not as an aspiration. No "aspiring analyst" framing, no "built for my
portfolio using fictional data" disclaimer buried in the intro — the
business framing above already makes that context clear without
undermining it.]
