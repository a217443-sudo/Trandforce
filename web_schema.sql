DROP TABLE IF EXISTS goals;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS employees;

CREATE TABLE employees (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  department TEXT NOT NULL
);

CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id INTEGER NOT NULL UNIQUE,
  username TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  role TEXT NOT NULL CHECK(role IN ('admin', 'manager', 'employee')),
  FOREIGN KEY (employee_id) REFERENCES employees(id)
);

CREATE TABLE goals (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_id INTEGER NOT NULL,
  year INTEGER NOT NULL CHECK(year >= 2026),
  objective TEXT NOT NULL,
  key_result TEXT NOT NULL,
  target TEXT NOT NULL,
  mid_progress REAL DEFAULT 0,
  end_progress REAL DEFAULT 0,
  score INTEGER CHECK(score BETWEEN 1 AND 5),
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (employee_id) REFERENCES employees(id)
);

INSERT INTO employees (name, department) VALUES
('王經理', '管理部'),
('陳專員', '財會部'),
('林專員', '製造部');

INSERT INTO users (employee_id, username, password, role) VALUES
(1, 'manager1', '123456', 'manager'),
(2, 'staff1', '123456', 'employee'),
(3, 'staff2', '123456', 'employee');
