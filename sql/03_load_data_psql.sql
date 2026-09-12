-- ============================================================
-- Horizon Phase 3 — Load CSV data into tables (psql \copy version)
-- ============================================================

-- ============================================================
-- STEP 1 -- LOAD THE TABLES, IN FOREIGN-KEY DEPENDENCY ORDER
-- ============================================================

\copy res_company (company_id, company_name, founded_year, headquarters_city, headquarters_country, industry) FROM 'output_csv/res_company.csv' DELIMITER ',' CSV HEADER

\copy hr_department (department_id, department_name, department_code, company_id, department_head_employee_id) FROM 'output_csv/hr_department.csv' DELIMITER ',' CSV HEADER

\copy hr_job (job_id, job_title, department_id, job_level) FROM 'output_csv/hr_job.csv' DELIMITER ',' CSV HEADER

\copy hr_employee (employee_id, first_name, last_name, gender, date_of_birth, hire_date, termination_date, department_id, job_id, manager_employee_id, email, company_id) FROM 'output_csv/hr_employee.csv' DELIMITER ',' CSV HEADER

\copy hr_contract (contract_id, employee_id, contract_type, fte_percentage, base_salary, start_date, end_date) FROM 'output_csv/hr_contract.csv' DELIMITER ',' CSV HEADER

\copy project_project (project_id, project_name, client_name, department_id, start_date, end_date, status, budget_hours) FROM 'output_csv/project_project.csv' DELIMITER ',' CSV HEADER

\copy project_task (task_id, project_id, task_name, assigned_employee_id, status, planned_hours, created_date, due_date) FROM 'output_csv/project_task.csv' DELIMITER ',' CSV HEADER

\copy timesheet_line (timesheet_id, employee_id, project_id, task_id, work_date, hours_logged, billable) FROM 'output_csv/timesheet_line.csv' DELIMITER ',' CSV HEADER

\copy hr_leave_type (leave_type_id, leave_type_name, is_paid) FROM 'output_csv/hr_leave_type.csv' DELIMITER ',' CSV HEADER

\copy hr_leave (leave_id, employee_id, leave_type_id, start_date, end_date, days_taken, status) FROM 'output_csv/hr_leave.csv' DELIMITER ',' CSV HEADER

\copy hr_appraisal (appraisal_id, employee_id, reviewer_employee_id, appraisal_date, overall_rating, promotion_recommended) FROM 'output_csv/hr_appraisal.csv' DELIMITER ',' CSV HEADER

\copy hr_training (training_id, training_name, category, delivery_method, duration_hours) FROM 'output_csv/hr_training.csv' DELIMITER ',' CSV HEADER

\copy hr_training_attendance (attendance_id, training_id, employee_id, attendance_date, completion_status) FROM 'output_csv/hr_training_attendance.csv' DELIMITER ',' CSV HEADER

\copy hr_recruitment_application (application_id, job_id, candidate_name, application_date, stage, hired_employee_id) FROM 'output_csv/hr_recruitment_application.csv' DELIMITER ',' CSV HEADER

-- ============================================================
-- dim_date has no CSV -- it's built entirely in SQL in script 02.
-- ============================================================

-- ============================================================
-- STEP 2 -- POST-LOAD VERIFICATION
-- ============================================================

SELECT 'res_company' AS table_name, COUNT(*) FROM res_company
UNION ALL SELECT 'hr_department', COUNT(*) FROM hr_department
UNION ALL SELECT 'hr_job', COUNT(*) FROM hr_job
UNION ALL SELECT 'hr_employee', COUNT(*) FROM hr_employee
UNION ALL SELECT 'hr_contract', COUNT(*) FROM hr_contract
UNION ALL SELECT 'project_project', COUNT(*) FROM project_project
UNION ALL SELECT 'project_task', COUNT(*) FROM project_task
UNION ALL SELECT 'timesheet_line', COUNT(*) FROM timesheet_line
UNION ALL SELECT 'hr_leave_type', COUNT(*) FROM hr_leave_type
UNION ALL SELECT 'hr_leave', COUNT(*) FROM hr_leave
UNION ALL SELECT 'hr_appraisal', COUNT(*) FROM hr_appraisal
UNION ALL SELECT 'hr_training', COUNT(*) FROM hr_training
UNION ALL SELECT 'hr_training_attendance', COUNT(*) FROM hr_training_attendance
UNION ALL SELECT 'hr_recruitment_application', COUNT(*) FROM hr_recruitment_application;

SELECT e.employee_id, e.department_id
FROM hr_employee e
LEFT JOIN hr_department d ON e.department_id = d.department_id
WHERE d.department_id IS NULL;