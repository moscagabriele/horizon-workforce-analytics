-- ============================================================
-- Horizon Phase 3 — Table Creation
-- ============================================================

-- ------------------------------------------------------------
-- 1. res_company
-- ------------------------------------------------------------
-- Grain: one row — the company itself.
CREATE TABLE res_company (
    company_id          INT PRIMARY KEY,
    company_name        VARCHAR(100) NOT NULL,
    founded_year         INT,
    headquarters_city    VARCHAR(100),
    headquarters_country VARCHAR(100),
    industry              VARCHAR(100)
);

-- ------------------------------------------------------------
-- 2. hr_department
-- ------------------------------------------------------------
-- Grain: one row — one department.
CREATE TABLE hr_department (
    department_id               INT PRIMARY KEY,
    department_name             VARCHAR(100) NOT NULL,
    department_code             VARCHAR(10),
    company_id                  INT NOT NULL REFERENCES res_company(company_id),
    department_head_employee_id INT  -- FK added later via ALTER TABLE
);

-- ------------------------------------------------------------
-- 3. hr_job
-- ------------------------------------------------------------
-- Grain: one row — one job position/title.
CREATE TABLE hr_job (
    job_id       INT PRIMARY KEY,
    job_title    VARCHAR(150) NOT NULL,
    department_id INT NOT NULL REFERENCES hr_department(department_id),
    job_level     VARCHAR(50)
);

-- ------------------------------------------------------------
-- 4. hr_employee
-- ------------------------------------------------------------
-- Grain: one row — one employee's current record.
CREATE TABLE hr_employee (
    employee_id           INT PRIMARY KEY,
    first_name            VARCHAR(100) NOT NULL,
    last_name             VARCHAR(100) NOT NULL,
    gender                VARCHAR(20),
    date_of_birth         DATE,
    hire_date             DATE NOT NULL,
    termination_date      DATE,  -- NULL = still employed
    department_id         INT NOT NULL REFERENCES hr_department(department_id),
    job_id                INT NOT NULL REFERENCES hr_job(job_id),
    manager_employee_id   INT REFERENCES hr_employee(employee_id),  -- self-referencing FK, nullable (CEO has no manager)
    email                 VARCHAR(150),
    company_id            INT NOT NULL REFERENCES res_company(company_id)
);

-- ------------------------------------------------------------
-- 5. hr_contract
-- ------------------------------------------------------------
-- Grain: one row — one contract period for one employee.
CREATE TABLE hr_contract (
    contract_id      INT PRIMARY KEY,
    employee_id      INT NOT NULL REFERENCES hr_employee(employee_id),
    contract_type    VARCHAR(50),
    fte_percentage   NUMERIC(5,2),
    base_salary      NUMERIC(12,2),
    start_date       DATE NOT NULL,
    end_date         DATE  -- NULL = current contract
);

-- ------------------------------------------------------------
-- 6. hr_leave_type
-- ------------------------------------------------------------
-- Grain: one row — one category of leave.
CREATE TABLE hr_leave_type (
    leave_type_id   INT PRIMARY KEY,
    leave_type_name VARCHAR(50) NOT NULL,
    is_paid         BOOLEAN
);

-- ------------------------------------------------------------
-- 7. hr_leave
-- ------------------------------------------------------------
-- Grain: one row — one leave request.
CREATE TABLE hr_leave (
    leave_id       INT PRIMARY KEY,
    employee_id    INT NOT NULL REFERENCES hr_employee(employee_id),
    leave_type_id  INT NOT NULL REFERENCES hr_leave_type(leave_type_id),
    start_date     DATE NOT NULL,
    end_date       DATE NOT NULL,
    days_taken     NUMERIC(5,2),
    status         VARCHAR(30)
);

-- ------------------------------------------------------------
-- 8. project_project
-- ------------------------------------------------------------
-- Grain: one row — one project.
CREATE TABLE project_project (
    project_id     INT PRIMARY KEY,
    project_name   VARCHAR(200) NOT NULL,
    client_name    VARCHAR(150),
    department_id  INT NOT NULL REFERENCES hr_department(department_id),
    start_date     DATE NOT NULL,
    end_date       DATE,
    status         VARCHAR(30),
    budget_hours   NUMERIC(10,2)
);

-- ------------------------------------------------------------
-- 9. project_task
-- ------------------------------------------------------------
-- Grain: one row — one task within a project.
CREATE TABLE project_task (
    task_id              INT PRIMARY KEY,
    project_id           INT NOT NULL REFERENCES project_project(project_id),
    task_name            VARCHAR(200) NOT NULL,
    assigned_employee_id INT REFERENCES hr_employee(employee_id),  -- nullable: unassigned tasks allowed
    status               VARCHAR(30),
    planned_hours        NUMERIC(8,2),
    created_date         DATE NOT NULL,
    due_date             DATE
);

-- ------------------------------------------------------------
-- 10. timesheet_line
-- ------------------------------------------------------------
-- Grain: one row — one person logging hours against one task on one day.
CREATE TABLE timesheet_line (
    timesheet_id  BIGINT PRIMARY KEY,
    employee_id   INT NOT NULL REFERENCES hr_employee(employee_id),
    project_id    INT NOT NULL REFERENCES project_project(project_id),
    task_id       INT REFERENCES project_task(task_id),  -- nullable: time logged before a task exists
    work_date     DATE NOT NULL,
    hours_logged  NUMERIC(5,2),
    billable      BOOLEAN
);

-- ------------------------------------------------------------
-- 11. hr_appraisal
-- ------------------------------------------------------------
-- Grain: one row — one performance review event.
CREATE TABLE hr_appraisal (
    appraisal_id            INT PRIMARY KEY,
    employee_id              INT NOT NULL REFERENCES hr_employee(employee_id),
    reviewer_employee_id     INT NOT NULL REFERENCES hr_employee(employee_id),
    appraisal_date           DATE NOT NULL,
    overall_rating           INT,
    promotion_recommended    BOOLEAN
);

-- ------------------------------------------------------------
-- 12. hr_training
-- ------------------------------------------------------------
-- Grain: one row — one training course in the catalogue.
CREATE TABLE hr_training (
    training_id      INT PRIMARY KEY,
    training_name    VARCHAR(200) NOT NULL,
    category         VARCHAR(50),
    delivery_method  VARCHAR(30),
    duration_hours   NUMERIC(5,2)
);

-- ------------------------------------------------------------
-- 13. hr_training_attendance
-- ------------------------------------------------------------
-- Grain: one row — one employee attending one training.
CREATE TABLE hr_training_attendance (
    attendance_id      INT PRIMARY KEY,
    training_id        INT NOT NULL REFERENCES hr_training(training_id),
    employee_id        INT NOT NULL REFERENCES hr_employee(employee_id),
    attendance_date    DATE NOT NULL,
    completion_status  VARCHAR(30)
);

-- ------------------------------------------------------------
-- 14. hr_recruitment_application
-- ------------------------------------------------------------
-- Grain: one row — one job application.
CREATE TABLE hr_recruitment_application (
    application_id      INT PRIMARY KEY,
    job_id               INT NOT NULL REFERENCES hr_job(job_id),
    candidate_name        VARCHAR(150),
    application_date      DATE NOT NULL,
    stage                 VARCHAR(30),
    hired_employee_id     INT REFERENCES hr_employee(employee_id)  -- nullable: most applications aren't hired
);

-- ============================================================
-- End of 01_create_tables.sql
-- ============================================================