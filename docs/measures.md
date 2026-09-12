# DAX Measures

Every measure in the Horizon semantic model, grouped by the dashboard page it
serves.

---

## Conventions

**All measures live in one hidden table.** `Key measures` is an empty table
(a single blank column, removed) that exists purely to hold measures.

**Display folders group by domain,** not by table: `Workforce`, `Capacity`,
`Talent`, `Recruitment`, `Leave`, `Management`. These match the dashboard pages,
so finding the measure behind a visual is a one-step lookup.

**Base measures are defined once and reused.** Three chains run through this
model:

```
Total Hours Logged
  └─ Billable Hours ─────┐
  └─ Non-Billable Hours  ├─ Utilization %
                         └─ Budget Hours Used %
                         └─ Avg Hours Logged per Employee

Total Tasks
  └─ Tasks Done ─────────── Task Completion Rate %

Total Applications
  └─ Hires Count
  └─ Rejection Rate %
```

Changing how an hour is counted is therefore a one-place edit in
`Total Hours Logged`, not a search-and-replace across eight measures.

**Percentages use `DIVIDE()` rather than `/`.** `DIVIDE` returns blank (or a
specified alternate) instead of an error when the denominator is zero. Four
measures pass an explicit `0` as the third argument — `Training Completion`,
`No-Show Rate %`, `% Promotion Recommended` — so an empty selection reads as
0% rather than blank. The remaining percentage measures return blank instead.

**Year-over-year measures come in pairs**: a `PY` measure that shifts the
period back, and a `YoY %` measure that computes the change. They exist for
the five Executive Overview cards only, not for every measure.

As the model stands:

**Connected to `dim_date` (active):** `Ops Timesheets` (work_date),
`Orgmgmt Leave` (start_date), `Talent Training` (attendance_date),
`Talent Appraisal` (appraisal_date).

**Connected to `dim_date` (inactive, activated on demand):**
`Employee[hire_date]` and `Employee[termination_date]`. Both are switched on
inside specific measures with `USERELATIONSHIP` — see `New Hires` and
`Terminations`.

**Connected to `Employee`:** `Orgmgmt Leave`, `Talent Appraisal`,
`Talent Training`, `hr_contract`, and `Recruitment Applications` (via
`hired_employee_id`).

---

## 1. Workforce

### Total Headcount

```dax
Total Headcount =
VAR AsOfDate = MAX ( dim_date[date_key] )
RETURN
CALCULATE (
    COUNTROWS ( Employee ),
    KEEPFILTERS (
        FILTER (
            Employee,
            Employee[hire_date] <= AsOfDate
                && ( ISBLANK ( Employee[termination_date] )
                     || Employee[termination_date] > AsOfDate )
        )
    )
)
```

**Returns:** employees on the books at the last date in the current filter
context. **Format:** whole number.

**Why this way:** headcount is a point-in-time measure, not an additive one.
Summing headcount across months is meaningless. `MAX(dim_date[date_key])` takes the end of whatever period is
selected, and the filter keeps employees hired on or before that date who
either never left or left afterwards.

**`KEEPFILTERS`** preserves any filter already applied to `Employee` (a
department or job-level slicer) rather than replacing it, which is what a bare
`FILTER` inside `CALCULATE` would do.

### Total Headcount PY

```dax
Total Headcount PY =
VAR AsOfDate = MAX ( dim_date[date_key] )
VAR PYDate = DATE ( YEAR ( AsOfDate ) - 1, MONTH ( AsOfDate ), DAY ( AsOfDate ) )
RETURN
CALCULATE (
    COUNTROWS ( Employee ),
    FILTER (
        ALL ( Employee ),
        Employee[hire_date] <= PYDate
            && ( ISBLANK ( Employee[termination_date] )
                 || Employee[termination_date] > PYDate )
    )
)
```

**Returns:** the same snapshot, taken exactly one year earlier.
**Format:** whole number.

**Why not `SAMEPERIODLASTYEAR`:** every other PY measure in this model uses it,
and this one deliberately doesn't. `SAMEPERIODLASTYEAR` shifts the whole
*period* back a year, which is correct for a measure that sums over a period
(terminations, appraisals). Headcount isn't summed over a period — it's read at
a single instant — so what's needed is the same *anniversary date*, which is
what the manual `DATE()` shift produces. Using `SAMEPERIODLASTYEAR` here would
give the headcount at the end of the prior-year period, which is nearly right
but drifts whenever the selected period isn't a full calendar year.

### Total Headcount YoY %

```dax
Total Headcount YoY % = DIVIDE ( [Total Headcount] - [Total Headcount PY], [Total Headcount PY] )
```

### Terminated Headcount

```dax
Terminated Headcount =
CALCULATE(
    COUNTROWS(Employee),
    NOT ISBLANK(Employee[termination_date])
)
```

**Returns:** everyone in the table who has ever left, with no date bound.
**Format:** whole number.

**Note:** unlike `Terminations` below, this has no relationship to the date
slicer. It answers "how many former employees are in the dataset", not "how
many left this year". Both are useful; they are not interchangeable.

### New Hires

```dax
New Hires =
CALCULATE(
    COUNTROWS(Employee),
    USERELATIONSHIP(dim_date[date_key], Employee[hire_date])
)
```

**Returns:** employees whose hire date falls in the selected period.
**Format:** whole number.

### Terminations

```dax
Terminations =
CALCULATE(
    COUNTROWS(Employee),
    USERELATIONSHIP(dim_date[date_key], Employee[termination_date]),
    NOT ISBLANK(Employee[termination_date])
)
```

**Returns:** employees whose termination date falls in the selected period.
**Format:** whole number.

### Terminations PY / Terminations YoY %

```dax
Terminations PY = CALCULATE ( [Terminations], SAMEPERIODLASTYEAR ( dim_date[date_key] ) )

Terminations YoY % = DIVIDE ( [Terminations] - [Terminations PY], [Terminations PY] )
```

### Turnover Rate

```dax
Turnover Rate = DIVIDE([Terminations], [Total Headcount])
```

**Returns:** leavers in the period as a share of headcount.
**Format:** percentage to two decimals.

**Known deviation from the standard definition:** conventional HR turnover
divides by *average* headcount over the period — usually
`(opening + closing) / 2` — not by closing headcount. This measure uses
closing headcount, which understates turnover in a growing organisation,
because the denominator has already absorbed the year's hires. Horizon's
headcount grew roughly 10% year over year, so the reported figure is
correspondingly low. This is a simplification, not an oversight.

### Turnover Rate PY / Turnover Rate YoY %

```dax
Turnover Rate PY = CALCULATE ( [Turnover Rate], SAMEPERIODLASTYEAR ( dim_date[date_key] ) )

Turnover Rate YoY % = DIVIDE ( [Turnover Rate] - [Turnover Rate PY], [Turnover Rate PY] )
```

### Average Tenure (Years)

```dax
Average Tenure (Years) = AVERAGE(Employee[tenure_years_full])
```

**Returns:** mean tenure across employees in the current filter context.

`tenure_years_full` is computed in SQL, in `v_workforce_headcount`, against a
fixed reference date of 2026-06-30 rather than `CURRENT_DATE` — see
`design_decisions.md`. That means this figure is stable no matter when the
model refreshes, which is the point for a fixed synthetic dataset.

**Note:** this averages every employee in context, including leavers, whose
tenure was frozen at their termination date. Whether that's wanted depends on
the question. Filtering to active employees gives "how experienced is the
current workforce"; leaving leavers in gives "how long do people stay".

### Average Base Salary

```dax
Average Base Salary =
AVERAGEX(
    FILTER(hr_contract, ISBLANK(hr_contract[end_date])),
    hr_contract[base_salary]
)
```

**Returns:** mean base salary across current contracts only.
**Format:** euro, two decimals.

**Why the filter:** roughly 15% of employees have two contract rows, a
historical one and a current one. Averaging all rows would double-count those
people and mix an old salary with a current one. `end_date IS BLANK` is the
model's definition of "current contract", matching the database convention
documented in `data_dictionary.md`.

---

## 2. Capacity

### Total Hours Logged

```dax
Total Hours Logged = SUM('Ops Timesheets'[hours_logged])
```

The base measure for the whole capacity page. Responds to the date slicer via
`Ops Timesheets[work_date]` → `dim_date[date_key]`.

### Billable Hours / Non-Billable Hours

```dax
Billable Hours =
CALCULATE(
    [Total Hours Logged],
    'Ops Timesheets'[billable] = TRUE
)

Non-Billable Hours =
CALCULATE(
    [Total Hours Logged],
    'Ops Timesheets'[billable] = FALSE
)
```


### Utilization %

```dax
Utilization % = DIVIDE([Billable Hours], [Total Hours Logged])
```

**Returns:** billable share of hours actually logged.
**Format:** percentage to two decimals.

### Budget Hours Used %

```dax
Budget Hours Used % = DIVIDE([Total Hours Logged], SUM('Ops Projects'[budget_hours]))
```

**Returns:** hours logged against a project as a share of its budgeted hours.
**Format:** percentage to two decimals.

### Total Tasks / Tasks Done / Task Completion Rate %

```dax
Total Tasks = COUNTROWS('Ops Tasks')

Tasks Done =
CALCULATE(
    [Total Tasks],
    'Ops Tasks'[status] = "Done"
)

Task Completion Rate % = DIVIDE([Tasks Done], [Total Tasks])
```

### Total Projects / Active Projects Count

```dax
Total Projects = COUNTROWS('Ops Projects')

Active Projects Count =
CALCULATE(
    [Total Projects],
    'Ops Projects'[status] = "Active"
)
```

### Avg Hours Logged per Employee

```dax
Avg Hours Logged per Employee =
DIVIDE(
    [Total Hours Logged],
    DISTINCTCOUNT('Ops Timesheets'[employee_id])
)
```

**Returns:** mean hours per person who logged anything in the period.

---

## 3. Talent

### Training Completion

```dax
Training Completion =
DIVIDE(
    CALCULATE(COUNTROWS('Talent Training'), 'Talent Training'[completion_status] = "Completed"),
    COUNTROWS('Talent Training'),
    0
)
```

**Returns:** completed attendance records as a share of all attendance records.
**Format:** percentage to two decimals.

### Training Completion PY / Training Completion YoY %

```dax
Training Completion PY = CALCULATE ( [Training Completion], SAMEPERIODLASTYEAR ( dim_date[date_key] ) )

Training Completion YoY % = DIVIDE ( [Training Completion] - [Training Completion PY], [Training Completion PY] )
```

### Total Training Hours Delivered

```dax
Total Training Hours Delivered =
CALCULATE(
    SUM('Talent Training'[duration_hours]),
    'Talent Training'[completion_status] = "Completed"
)
```

**Returns:** course hours summed across completed attendances only.

"Delivered" here means consumed by an attendee, so a 4-hour course with 10
completions counts as 40 hours, not 4. No-shows and in-progress records are
excluded, which is why this is investment actually realised rather than
investment scheduled.

### No-Show Rate %

```dax
No-Show Rate % =
DIVIDE(
    CALCULATE(COUNTROWS('Talent Training'), 'Talent Training'[completion_status] = "No-show"),
    COUNTROWS('Talent Training'),
    0
)
```

### Avg Appraisal / Avg Appraisal PY / Avg Appraisal YoY %

```dax
Avg Appraisal = AVERAGE('Talent Appraisal'[overall_rating])

Avg Appraisal PY = CALCULATE ( [Avg Appraisal], SAMEPERIODLASTYEAR ( dim_date[date_key] ) )

Avg Appraisal YoY % = DIVIDE ( [Avg Appraisal] - [Avg Appraisal PY], [Avg Appraisal PY] )
```

Mean of an ordinal 1–5 rating. Averaging ordinal scales is standard practice in
HR reporting but is formally questionable: it assumes the gap between 3 and 4
equals the gap between 4 and 5. A distribution chart alongside the average is
the honest presentation, and the Talent page carries one.

### % Promotion Recommended

```dax
% Promotion Recommended =
DIVIDE(
    CALCULATE(COUNTROWS('Talent Appraisal'), 'Talent Appraisal'[promotion_recommended] = TRUE()),
    COUNTROWS('Talent Appraisal'),
    0
)
```

Share of appraisal *events*, not of employees. Someone reviewed three times
with one promotion recommendation contributes three rows and one positive.

### Appraisal Count (period)

```dax
Appraisal Count (period) = COUNTROWS('Talent Appraisal')
```

Review coverage. Responds to the date slicer via `appraisal_date`.

---

## 4. Recruitment

### Total Applications

```dax
Total Applications = COUNTROWS ( 'Recruitment Applications' )
```

### Hires Count

```dax
Hires Count =
CALCULATE (
    [Total Applications],
    NOT ISBLANK ( 'Recruitment Applications'[hired_employee_id] )
)
```

### Rejection Rate %

```dax
Rejection Rate % =
DIVIDE (
    CALCULATE ( [Total Applications], 'Recruitment Applications'[stage] = "Rejected" ),
    [Total Applications]
)
```

### Avg Time to Hire (days)

```dax
Avg Time to Hire (days) =
AVERAGEX (
    FILTER (
        'Recruitment Applications',
        NOT ISBLANK ( 'Recruitment Applications'[hired_employee_id] )
    ),
    RELATED ( Employee[hire_date] ) - 'Recruitment Applications'[application_date]
)
```

**Returns:** mean days between application and hire date, across hired
applications only.

### Negative Time to Hire Count

```dax
Negative Time to Hire Count =
COUNTROWS (
    FILTER (
        'Recruitment Applications',
        NOT ISBLANK ( 'Recruitment Applications'[hired_employee_id] )
            && RELATED ( Employee[hire_date] ) - 'Recruitment Applications'[application_date] < 0
    )
)
```

**Returns:** hired applications where the hire date precedes the application
date, which is impossible in reality.

This is a data quality guard, not a business metric. The synthetic generator
links a hired application to a randomly chosen employee in the same job, with
no constraint that the employee's hire date falls after the application date,
so negative intervals occur. This measure counts them so the reader can judge
how much of `Avg Time to Hire` is contaminated. If this returns anything other
than zero, treat the time-to-hire figure as directional at best.

---

## 5. Leave

### Total Leave Days Taken

```dax
Total Leave Days Taken = SUM ( 'Orgmgmt Leave'[days_taken] )
```

Sums every leave record in context, regardless of approval status. Pending and
rejected requests are included. If the intent is days actually taken rather
than days requested, this needs a filter on `status = "Approved"`.

### Leave Request Count

```dax
Leave Request Count = COUNTROWS ( 'Orgmgmt Leave' )
```

Request volume, useful as a denominator and for the status split.

### Avg Leave Days per Employee

```dax
Avg Leave Days per Employee =
DIVIDE (
    [Total Leave Days Taken],
    DISTINCTCOUNT ( Employee[employee_id] )
)
```

---

## 6. Management

### Avg Span of Control

```dax
Avg Span of Control =
VAR ManagerIDs =
    VALUES ( Employee[employee_id] )
VAR SpansTable =
    ADDCOLUMNS (
        ManagerIDs,
        "@Reports",
        VAR ThisManagerID = Employee[employee_id]
        RETURN
            CALCULATE (
                COUNTROWS ( Employee ),
                REMOVEFILTERS ( Employee ),
                Employee[manager_employee_id] = ThisManagerID
            )
    )
VAR ManagersWithReports =
    FILTER ( SpansTable, [@Reports] > 0 )
RETURN
    AVERAGEX ( ManagersWithReports, [@Reports] )
```

**Returns:** mean number of direct reports, across people who have at least one.

### Number of Managers

```dax
Number of Managers =
CALCULATE(
    DISTINCTCOUNT(Employee[manager_employee_id]),
    Employee[manager_employee_id] <> BLANK()
)
```

Counts distinct people who appear as somebody's manager. Note this counts
managers *referenced by* employees in context, so a manager whose only reports
are filtered out disappears from the count.

### % Employees with No Manager

```dax
% Employees with No Manager =
DIVIDE(
    CALCULATE(
        COUNTROWS(Employee),
        ISBLANK(Employee[manager_employee_id]),
        Employee[is_active] = TRUE
    ),
    [Total Headcount]
)
```

**Returns:** share of the workforce reporting to nobody.

**Read it as a structural fact, not a trend.** In this dataset, employees with
no manager are exactly the Directors, one per department. The measure therefore
reports how many departments exist relative to headcount. It would become a
genuine flatness metric only in an organisation where top-level reporting
varies.


### Max Hierarchy Depth

```dax
Max Hierarchy Depth = MAX(Employee[Hierarchy Level])
```

**Returns:** the deepest level in the reporting chain within the current filter.


### Avg Manager Tenure

```dax
Avg Manager Tenure =
VAR ManagersOfActiveStaff =
    CALCULATETABLE(
        VALUES(Employee[manager_employee_id]),
        Employee[is_active] = TRUE,
        NOT ISBLANK(Employee[manager_employee_id])
    )
RETURN
    AVERAGEX(
        ManagersOfActiveStaff,
        LOOKUPVALUE(
            Employee[tenure_years_full],
            Employee[employee_id], Employee[manager_employee_id]
        )
    )
```

**Returns:** mean tenure of the people currently managing active staff.

---