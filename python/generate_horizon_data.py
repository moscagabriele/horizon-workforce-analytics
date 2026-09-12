import random
import os
from datetime import date, timedelta

import numpy as np
import pandas as pd
from faker import Faker

SEED = 42
random.seed(SEED)
np.random.seed(SEED)
fake = Faker()
Faker.seed(SEED)

OUTPUT_DIR = "output_csv"
os.makedirs(OUTPUT_DIR, exist_ok=True)

PROJECT_END = date(2026, 6, 30)
PROJECT_START = date(2023, 7, 1)  # 3 years back


def save(df: pd.DataFrame, name: str):
    path = os.path.join(OUTPUT_DIR, f"{name}.csv")
    df.to_csv(path, index=False)
    print(f"  {name:<32} {len(df):>6} rows -> {path}")


def random_date(start: date, end: date) -> date:
    delta_days = (end - start).days
    return start + timedelta(days=random.randint(0, delta_days))


# ===========================================================================
# 1. res_company
# ===========================================================================
print("Generating res_company...")
res_company = pd.DataFrame([{
    "company_id": 1,
    "company_name": "Horizon",
    "founded_year": 2011,
    "headquarters_city": "Brussels",
    "headquarters_country": "Belgium",
    "industry": "Professional Services",
}])
save(res_company, "res_company")

# ===========================================================================
# 2. hr_department
# ===========================================================================
print("Generating hr_department...")
department_defs = [
    ("Consulting", "CONS"),
    ("Operations", "OPS"),
    ("IT", "IT"),
    ("Human Resources", "HR"),
    ("Finance", "FIN"),
    ("Sales", "SALES"),
    ("Marketing", "MKT"),
]
hr_department = pd.DataFrame([
    {
        "department_id": i + 1,
        "department_name": name,
        "department_code": code,
        "company_id": 1,
        "department_head_employee_id": None,
    }
    for i, (name, code) in enumerate(department_defs)
])
department_ids = hr_department["department_id"].tolist()
save(hr_department, "hr_department")

# ===========================================================================
# 3. hr_job
# ===========================================================================
print("Generating hr_job...")
job_catalog = {
    1: [("Junior Consultant", "Junior"), ("Consultant", "Mid"),
        ("Senior Consultant", "Senior"), ("Engagement Manager", "Lead"),
        ("Practice Director", "Director")],
    2: [("Operations Analyst", "Junior"), ("Operations Coordinator", "Mid"),
        ("Operations Manager", "Senior"), ("Head of Operations", "Director")],
    3: [("IT Support Specialist", "Junior"), ("Systems Administrator", "Mid"),
        ("IT Project Lead", "Senior"), ("IT Manager", "Lead"),
        ("Head of IT", "Director")],
    4: [("HR Coordinator", "Junior"), ("HR Business Partner", "Mid"),
        ("HR Manager", "Senior"), ("Head of HR", "Director")],
    5: [("Financial Analyst", "Junior"), ("Accountant", "Mid"),
        ("Finance Manager", "Senior"), ("Head of Finance", "Director")],
    6: [("Sales Development Rep", "Junior"), ("Account Executive", "Mid"),
        ("Senior Account Executive", "Senior"), ("Sales Manager", "Lead")],
    7: [("Marketing Coordinator", "Junior"), ("Marketing Specialist", "Mid"),
        ("Content Strategist", "Mid"), ("Marketing Manager", "Senior")],
}
job_rows = []
job_id = 1
for dept_id, titles in job_catalog.items():
    for title, level in titles:
        job_rows.append({
            "job_id": job_id,
            "job_title": title,
            "department_id": dept_id,
            "job_level": level,
        })
        job_id += 1
hr_job = pd.DataFrame(job_rows)
save(hr_job, "hr_job")

# ===========================================================================
# 4. hr_employee
# ===========================================================================
print("Generating hr_employee...")
N_EMPLOYEES = 200
employees = []
employee_id = 1

jobs_by_level = hr_job.groupby("job_level")["job_id"].apply(list).to_dict()

level_targets = {
    "Director": 7,    
    "Lead": 15,
    "Senior": 40,
    "Mid": 80,
    "Junior": N_EMPLOYEES - (7 + 15 + 40 + 80),
}

senior_pool_ids = [] 

for level in ["Director", "Lead", "Senior", "Mid", "Junior"]:
    count = level_targets[level]
    available_jobs = jobs_by_level.get(level, jobs_by_level["Mid"])
    for _ in range(count):
        job_id_choice = random.choice(available_jobs)
        dept_id_choice = int(hr_job.loc[hr_job.job_id == job_id_choice, "department_id"].iloc[0])

        hire_date = random_date(PROJECT_START - timedelta(days=365 * 5), PROJECT_END)
        dob = fake.date_of_birth(minimum_age=23, maximum_age=62)

        is_terminated = random.random() < 0.08 and hire_date < PROJECT_END - timedelta(days=90)
        termination_date = (
            random_date(hire_date + timedelta(days=90), PROJECT_END) if is_terminated else None
        )

        if level == "Director" or not senior_pool_ids:
            manager_id = None
        else:
            manager_id = random.choice(senior_pool_ids)

        first = fake.first_name()
        last = fake.last_name()
        employees.append({
            "employee_id": employee_id,
            "first_name": first,
            "last_name": last,
            "gender": random.choice(["Female", "Male"]),
            "date_of_birth": dob,
            "hire_date": hire_date,
            "termination_date": termination_date,
            "department_id": dept_id_choice,
            "job_id": job_id_choice,
            "manager_employee_id": manager_id,
            "email": f"{first.lower()}.{last.lower()}@horizon.com",
            "company_id": 1,
        })
       
        if level in ("Director", "Lead", "Senior"):
            senior_pool_ids.append(employee_id)
        employee_id += 1

hr_employee = pd.DataFrame(employees)
hr_employee['manager_employee_id'] = hr_employee['manager_employee_id'].astype('Int64')
save(hr_employee, "hr_employee")

active_employee_ids = hr_employee.loc[hr_employee.termination_date.isna(), "employee_id"].tolist()
all_employee_ids = hr_employee["employee_id"].tolist()


print("Backfilling hr_department.department_head_employee_id...")
for dept_id in department_ids:
    candidates = hr_employee[
        (hr_employee.department_id == dept_id)
        & (hr_employee.job_id.isin(hr_job.loc[hr_job.job_level.isin(["Director", "Lead"]), "job_id"]))
    ]
    head_id = int(candidates.iloc[0]["employee_id"]) if len(candidates) else None
    hr_department.loc[hr_department.department_id == dept_id, "department_head_employee_id"] = head_id
hr_department['department_head_employee_id'] = hr_department['department_head_employee_id'].astype('Int64')
save(hr_department, "hr_department")

# ===========================================================================
# 5. hr_contract
# ===========================================================================

print("Generating hr_contract...")

SALARY_BANDS = {
    "Junior":   (32000, 46000),
    "Mid":      (43000, 63000),
    "Senior":   (58000, 84000),
    "Lead":     (78000, 105000),
    "Director": (98000, 130000),
}

job_level_by_job_id = hr_job.set_index("job_id")["job_level"].to_dict()

contracts = []
contract_id = 1
for _, emp in hr_employee.iterrows():
    emp_id = emp["employee_id"]
    hire = emp["hire_date"]
    term = emp["termination_date"] if pd.notna(emp["termination_date"]) else None

    level = job_level_by_job_id[emp["job_id"]]
    band_low, band_high = SALARY_BANDS[level]

    has_second_contract = random.random() < 0.15 and (term is None or (term - hire).days > 200)

    if has_second_contract:

        split_point = random_date(hire + timedelta(days=60), term - timedelta(days=30) if term else PROJECT_END - timedelta(days=30))
        contracts.append({
            "contract_id": contract_id,
            "employee_id": emp_id,
            "contract_type": "Fixed-term",
            "fte_percentage": random.choice([80.00, 100.00]),
            "base_salary": round(random.uniform(band_low, band_low + (band_high - band_low) * 0.7), 2),
            "start_date": hire,
            "end_date": split_point,
        })
        contract_id += 1
        contracts.append({
            "contract_id": contract_id,
            "employee_id": emp_id,
            "contract_type": "Permanent",
            "fte_percentage": random.choice([80.00, 100.00]),
            "base_salary": round(random.uniform(band_low, band_high), 2),
            "start_date": split_point,
            "end_date": term,
        })
        contract_id += 1
    else:
        contracts.append({
            "contract_id": contract_id,
            "employee_id": emp_id,
            "contract_type": random.choice(["Permanent", "Permanent", "Permanent", "Fixed-term", "Intern"]),
            "fte_percentage": random.choice([50.00, 80.00, 100.00, 100.00, 100.00]),
            "base_salary": round(random.uniform(band_low, band_high), 2),
            "start_date": hire,
            "end_date": term,
        })
        contract_id += 1

hr_contract = pd.DataFrame(contracts)
save(hr_contract, "hr_contract")

# ===========================================================================
# 6. project_project
# ===========================================================================
print("Generating project_project...")
N_PROJECTS = 30
projects = []
for i in range(1, N_PROJECTS + 1):
    start = random_date(PROJECT_START, PROJECT_END - timedelta(days=30))
    is_open = random.random() < 0.3
    end = None if is_open else min(start + timedelta(days=random.randint(30, 270)), PROJECT_END)
    if is_open:
        status = "Active"
    else:
        status = random.choice(["Completed", "Completed", "Completed", "On Hold"])
    projects.append({
        "project_id": i,
        "project_name": f"{fake.bs().title()} Initiative",
        "client_name": fake.company(),
        "department_id": random.choice(department_ids),
        "start_date": start,
        "end_date": end,
        "status": status,
        "budget_hours": round(random.uniform(200, 4000), 2),
    })
project_project = pd.DataFrame(projects)
save(project_project, "project_project")
project_ids = project_project["project_id"].tolist()

# ===========================================================================
# 7. project_task
# ===========================================================================
print("Generating project_task...")
tasks = []
task_id = 1
for _, proj in project_project.iterrows():
    n_tasks = random.randint(3, 8)
    proj_start = proj["start_date"]
    proj_end = proj["end_date"] if pd.notna(proj["end_date"]) else PROJECT_END
    for _ in range(n_tasks):
        created = random_date(proj_start, proj_end)
        due = created + timedelta(days=random.randint(5, 45))
        status = random.choice(["To Do", "In Progress", "Done", "Done", "Done"])
        tasks.append({
            "task_id": task_id,
            "project_id": int(proj["project_id"]),
            "task_name": fake.catch_phrase(),
            "assigned_employee_id": random.choice(active_employee_ids),
            "status": status,
            "planned_hours": round(random.uniform(8, 200), 2),
            "created_date": created,
            "due_date": due,
        })
        task_id += 1
        
project_task = pd.DataFrame(tasks)
project_task['assigned_employee_id'] = project_task['assigned_employee_id'].astype('Int64')
save(project_task, "project_task")

# ===========================================================================
# 8. timesheet_line
# ===========================================================================
print("Generating timesheet_line (this table is the largest)...")
TARGET_ROWS = 20000
timesheet_rows = []
timesheet_id = 1

tasks_by_project = project_task.groupby("project_id")["task_id"].apply(list).to_dict()

rows_per_employee = int((TARGET_ROWS // len(active_employee_ids)) * 7 / 5)

for emp_id in active_employee_ids:
    emp_row = hr_employee.loc[hr_employee.employee_id == emp_id].iloc[0]
    log_start = max(emp_row["hire_date"], PROJECT_START)
    log_end = emp_row["termination_date"] if pd.notna(emp_row["termination_date"]) else PROJECT_END
    if log_start >= log_end:
        continue
    for _ in range(rows_per_employee):
        proj_id = random.choice(project_ids)
        candidate_tasks = tasks_by_project.get(proj_id, [])
        use_task = candidate_tasks and random.random() > 0.10
        task_id_val = random.choice(candidate_tasks) if use_task else None

        work_date = random_date(log_start, log_end)
        if work_date.weekday() >= 5:
            continue

        timesheet_rows.append({
            "timesheet_id": timesheet_id,
            "employee_id": emp_id,
            "project_id": proj_id,
            "task_id": task_id_val,
            "work_date": work_date,
            "hours_logged": round(random.uniform(0.5, 8.0), 2),
            "billable": random.random() < 0.75,
        })
        timesheet_id += 1

timesheet_line = pd.DataFrame(timesheet_rows)
timesheet_line['task_id'] = timesheet_line['task_id'].astype('Int64')
save(timesheet_line, "timesheet_line")

# ===========================================================================
# 9. hr_leave_type — 4 fixed categories
# ===========================================================================
print("Generating hr_leave_type...")
hr_leave_type = pd.DataFrame([
    {"leave_type_id": 1, "leave_type_name": "Annual", "is_paid": True},
    {"leave_type_id": 2, "leave_type_name": "Sick", "is_paid": True},
    {"leave_type_id": 3, "leave_type_name": "Unpaid", "is_paid": False},
    {"leave_type_id": 4, "leave_type_name": "Parental", "is_paid": True},
])
save(hr_leave_type, "hr_leave_type")
leave_type_ids = hr_leave_type["leave_type_id"].tolist()

# ===========================================================================
# 10. hr_leave — ~3 leave requests per active employee per year
# ===========================================================================
print("Generating hr_leave...")
leave_rows = []
leave_id = 1
for emp_id in active_employee_ids:
    emp_row = hr_employee.loc[hr_employee.employee_id == emp_id].iloc[0]
    log_start = max(emp_row["hire_date"], PROJECT_START)
    log_end = emp_row["termination_date"] if pd.notna(emp_row["termination_date"]) else PROJECT_END
    if log_start >= log_end:
        continue
    n_leaves = random.randint(2, 8)
    for _ in range(n_leaves):
        start = random_date(log_start, log_end)
        days_taken = random.choice([1, 1, 2, 3, 5, 5, 10])
        end = start + timedelta(days=int(days_taken) - 1)
        leave_rows.append({
            "leave_id": leave_id,
            "employee_id": emp_id,
            "leave_type_id": random.choices(leave_type_ids, weights=[55, 25, 10, 10])[0],
            "start_date": start,
            "end_date": end,
            "days_taken": days_taken,
            "status": random.choices(["Approved", "Pending", "Rejected"], weights=[85, 10, 5])[0],
        })
        leave_id += 1
hr_leave = pd.DataFrame(leave_rows)
save(hr_leave, "hr_leave")

# ===========================================================================
# 11. hr_appraisal
# ===========================================================================
print("Generating hr_appraisal...")
appraisal_rows = []
appraisal_id = 1
fallback_reviewers = hr_employee.loc[
    hr_employee.job_id.isin(hr_job.loc[hr_job.job_level.isin(["Director", "Lead"]), "job_id"]),
    "employee_id",
].tolist()

for _, emp in hr_employee.iterrows():
    emp_id = emp["employee_id"]
    hire = emp["hire_date"]
    term = emp["termination_date"] if pd.notna(emp["termination_date"]) else PROJECT_END
    tenure_days = (term - max(hire, PROJECT_START)).days
    if tenure_days < 180:
        continue
    n_reviews = max(1, tenure_days // 365)
    reviewer = emp["manager_employee_id"]
    if pd.isna(reviewer):
        reviewer = random.choice(fallback_reviewers) if fallback_reviewers else emp_id
    for _ in range(int(n_reviews)):
        review_date = random_date(max(hire, PROJECT_START), term)
        rating = random.choices([1, 2, 3, 4, 5], weights=[3, 7, 35, 40, 15])[0]
        appraisal_rows.append({
            "appraisal_id": appraisal_id,
            "employee_id": emp_id,
            "reviewer_employee_id": int(reviewer),
            "appraisal_date": review_date,
            "overall_rating": rating,
            "promotion_recommended": rating >= 4 and random.random() < 0.3,
        })
        appraisal_id += 1
hr_appraisal = pd.DataFrame(appraisal_rows)
save(hr_appraisal, "hr_appraisal")

# ===========================================================================
# 12. hr_training
# ===========================================================================
print("Generating hr_training...")
training_catalog = [
    ("Excel for Analysts", "Technical", "Online", 4),
    ("SQL Fundamentals", "Technical", "Online", 8),
    ("Power BI Essentials", "Technical", "Online", 6),
    ("Project Management Basics", "Technical", "In-person", 8),
    ("Cybersecurity Awareness", "Compliance", "Online", 2),
    ("GDPR & Data Privacy", "Compliance", "Online", 3),
    ("Workplace Health & Safety", "Compliance", "In-person", 2),
    ("Anti-Harassment Training", "Compliance", "Online", 2),
    ("Effective Communication", "Soft Skills", "In-person", 4),
    ("Leadership Fundamentals", "Soft Skills", "In-person", 12),
    ("Negotiation Skills", "Soft Skills", "In-person", 6),
    ("Time Management", "Soft Skills", "Online", 3),
    ("Client Relationship Management", "Soft Skills", "In-person", 6),
    ("Public Speaking", "Soft Skills", "In-person", 4),
    ("Advanced Python for Data", "Technical", "Online", 10),
]
hr_training = pd.DataFrame([
    {
        "training_id": i + 1,
        "training_name": name,
        "category": cat,
        "delivery_method": method,
        "duration_hours": hours,
    }
    for i, (name, cat, method, hours) in enumerate(training_catalog)
])
save(hr_training, "hr_training")
training_ids = hr_training["training_id"].tolist()

# ===========================================================================
# 13. hr_training_attendance
# ===========================================================================
print("Generating hr_training_attendance...")
attendance_rows = []
attendance_id = 1
for emp_id in active_employee_ids:
    if random.random() < 0.7:
        n_courses = random.randint(1, 4)
        chosen = random.sample(training_ids, min(n_courses, len(training_ids)))
        for t_id in chosen:
            emp_row = hr_employee.loc[hr_employee.employee_id == emp_id].iloc[0]
            att_date = random_date(max(emp_row["hire_date"], PROJECT_START), PROJECT_END)
            attendance_rows.append({
                "attendance_id": attendance_id,
                "training_id": t_id,
                "employee_id": emp_id,
                "attendance_date": att_date,
                "completion_status": random.choices(
                    ["Completed", "In Progress", "No-show"], weights=[75, 15, 10]
                )[0],
            })
            attendance_id += 1
hr_training_attendance = pd.DataFrame(attendance_rows)
save(hr_training_attendance, "hr_training_attendance")

# ===========================================================================
# 14. hr_recruitment_application
# ===========================================================================
print("Generating hr_recruitment_application...")
job_ids = hr_job["job_id"].tolist()
N_APPLICATIONS = 400
application_rows = []

employees_by_job = hr_employee.groupby("job_id")["employee_id"].apply(list).to_dict()
used_employee_ids_as_hires = set()

for app_id in range(1, N_APPLICATIONS + 1):
    job_id_choice = random.choice(job_ids)
    app_date = random_date(PROJECT_START, PROJECT_END - timedelta(days=14))
    stage = random.choices(
        ["Applied", "Interview", "Offer", "Hired", "Rejected"],
        weights=[35, 25, 8, 12, 20],
    )[0]

    hired_employee_id = None
    if stage == "Hired":
        candidates = [
            e for e in employees_by_job.get(job_id_choice, [])
            if e not in used_employee_ids_as_hires
        ]
        if candidates:
            hired_employee_id = random.choice(candidates)
            used_employee_ids_as_hires.add(hired_employee_id)
        else:
            stage = "Offer"

    application_rows.append({
        "application_id": app_id,
        "job_id": job_id_choice,
        "candidate_name": fake.name(),
        "application_date": app_date,
        "stage": stage,
        "hired_employee_id": hired_employee_id,
    })

hr_recruitment_application = pd.DataFrame(application_rows)
hr_recruitment_application['hired_employee_id'] = hr_recruitment_application['hired_employee_id'].astype('Int64')
save(hr_recruitment_application, "hr_recruitment_application")

print("\nDone. All 14 tables written to ./output_csv/")
print("(dim_date is intentionally NOT generated here — it's built in SQL in Phase 3.)")