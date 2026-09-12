# Power Query (M) Transformations

Every query in the Horizon semantic model, with its M code and the reasoning
behind it.

Seventeen queries: fifteen loaded as tables, two used only as inputs to
others.

---

## The rule this layer follows

**Transformation happens in SQL. Power Query connects, renames, and drops.**

`design_decisions.md` explains why the joins live in PostgreSQL views rather
than being re-derived per report: one definition, one place to change it, and
every consumer sees the same logic. That decision is what makes this layer
thin. Most queries here are four lines, and that is the intended outcome, not
an unfinished job.

The working test used at each step: *would another consumer of this database
need the same thing?* If yes, it belongs in a view. If it exists only because
Power BI wants it (a friendlier column name, a sort-order helper, a column the
report will never show), it belongs here.
---

## The connection pattern

Every query opens the same way:

```m
Source = PostgreSQL.Database("localhost", "HORIZON"),
#"Navigation 1" = Source{[Schema = "public", Item = "<view or table>"]}[Data]
```

`PostgreSQL.Database` opens the connection; the `Source{[...]}[Data]` step
navigates to one object inside it. The server and database names are hard-coded
in all seventeen queries. To point the model at a different database you would
edit seventeen places. Parameterising them — two Power Query parameters
referenced by every query — is the standard fix and is not yet done.

A second, purely cosmetic inconsistency: five queries use the older navigation
style Power Query generates when you pick a table from the navigator
(`public_hr_contract = Source{[Schema="public",Item="hr_contract"]}[Data]`)
while the rest use `#"Navigation 1"`. Same behaviour, two spellings.

---

## Query inventory

| Query | Source object | Role | Loaded |
|---|---|---|---|
| `Employee` | `v_workforce_headcount` + `Workforce Org` | Dimension | Yes |
| `dim_date` | `dim_date` | Dimension | Yes |
| `Ops Projects` | `v_ops_project_utilization` | Dimension | Yes |
| `hr_department` | `hr_department` | Dimension (hidden) | Yes |
| `hr_job` | `hr_job` | Dimension (hidden) | Yes |
| `hr_leave_type` | `hr_leave_type` | Dimension (hidden) | Yes |
| `hr_training` | `hr_training` | Dimension (hidden) | Yes |
| `hr_contract` | `hr_contract` | Fact | Yes |
| `Ops Timesheets` | `v_ops_timesheet_detail` | Fact | Yes |
| `Ops Tasks` | `project_task` | Fact | Yes |
| `Orgmgmt Leave` | `v_orgmgmt_leave_summary` | Fact | Yes |
| `Talent Appraisal` | `v_talent_appraisal_summary` | Fact | Yes |
| `Talent Training` | `v_talent_training_completion` | Fact | Yes |
| `Recruitment Applications` | `hr_recruitment_application` | Fact | Yes |
| `Key measures` | (empty table) | Measure container | Yes |
| `Workforce Org` | `v_workforce_org_structure` | Input to `Employee` | No |
| `Talent Recruitment` | `v_talent_recruitment_funnel` | Unused | No |

Queries are organised into two query groups, `Dimensions` and `Facts`, which
appear as folders in the Power Query editor.

---

## The one transformation: the `Employee` dimension

This is the only query that changes the shape of anything.

```m
let
  Source = PostgreSQL.Database("localhost", "HORIZON"),
  #"Navigation 1" = Source{[Schema = "public", Item = "v_workforce_headcount"]}[Data],
  #"Renamed Columns" = Table.RenameColumns(
      #"Navigation 1",
      {{"employee_name", "Employee"}, {"department_name", "Department"}}),
  #"Merged Queries" = Table.NestedJoin(
      #"Renamed Columns", {"employee_id"},
      #"Workforce Org", {"employee_id"},
      "Workforce Org", JoinKind.LeftOuter),
  #"Expanded Workforce Org" = Table.ExpandTableColumn(
      #"Merged Queries", "Workforce Org",
      {"manager_employee_id", "Manager", "department_head_employee_id",
       "Department head", "is_department_head"},
      {"manager_employee_id", "Manager", "department_head_employee_id",
       "Department head", "is_department_head"}),
  #"Replaced Value" = Table.ReplaceValue(
      #"Expanded Workforce Org", "Human Resources", "HR",
      Replacer.ReplaceText, {"Department"})
in
  #"Replaced Value"
```
---

## Column removal as modelling discipline


```m
// Talent Appraisal
#"Removed Columns" = Table.RemoveColumns(
    #"Renamed Columns", {"department_name", "job_title", "job_level"})

// Talent Training
#"Removed Columns" = Table.RemoveColumns(
    #"Renamed Columns", {"department_name", "training_name", "category",
                         "delivery_method"})

// Ops Timesheets
#"Removed Columns" = Table.RemoveColumns(
    #"Renamed Columns1", {"employee_department_name", "project_department_name"})
```

```m
// hr_department
#"Removed Columns" = Table.RemoveColumns(
    #"Renamed Columns",
    {"public.hr_employee(department_head_employee_id)",
     "public.hr_employee(department_id)", "public.hr_job",
     "public.project_project", "public.res_company"})
```

---

## The sort-order pattern

```m
// Recruitment Applications
#"Added Custom" = Table.AddColumn(
    public_hr_recruitment_application, "Stage Sort Order",
    each if [stage] = "Applied" then 1
    else if [stage] = "Interview" then 2
    else if [stage] = "Offer" then 3
    else if [stage] = "Hired" then 4
    else if [stage] = "Rejected" then 5
    else null)
```
---

## Queries that aren't loaded

```m
// Workforce Org — input to the Employee merge, not a table in its own right
let
  Source = PostgreSQL.Database("localhost", "HORIZON"),
  #"Navigation 1" = Source{[Schema = "public", Item = "v_workforce_org_structure"]}[Data],
  #"Renamed Columns" = Table.RenameColumns(
      #"Navigation 1",
      {{"employee_name", "Employee"}, {"department_name", "Deparment"},
       {"manager_name", "Manager"}, {"department_head_name", "Department head"}})
in
  #"Renamed Columns"
```

Loading this as a table would create a second, competing employee dimension.
It exists only to feed the merge, so **Enable load** is switched off and it
lives in the model as an expression rather than a table.

```m
// Talent Recruitment — currently unused
let
  Source = PostgreSQL.Database("localhost", "HORIZON"),
  #"Navigation 1" = Source{[Schema = "public", Item = "v_talent_recruitment_funnel"]}[Data],
  #"Renamed Columns" = Table.RenameColumns(#"Navigation 1", {{"department_name", "Department"}})
in
  #"Renamed Columns"
```

---

**The department label.**

```m
// in Employee
Table.ReplaceValue(..., "Human Resources", "HR", Replacer.ReplaceText, {"Department"})
// in hr_department
Table.ReplaceValue(..., "Human Resources", "HR", Replacer.ReplaceText, {"Department"})
```

**Trimming project names.**

```m
// in Ops Timesheets and again in Ops Projects
Table.ReplaceValue(..., "Initiative", "", Replacer.ReplaceText, {"project_name"})
```
---