from __future__ import annotations

import sqlite3
from pathlib import Path
from functools import wraps
from flask import Flask, g, redirect, render_template, request, session, url_for, flash

BASE_DIR = Path(__file__).resolve().parent
DB_PATH = BASE_DIR / "app.db"

app = Flask(__name__)
app.config["SECRET_KEY"] = "change-me-in-production"


def get_db() -> sqlite3.Connection:
    if "db" not in g:
        g.db = sqlite3.connect(DB_PATH)
        g.db.row_factory = sqlite3.Row
    return g.db


@app.teardown_appcontext
def close_db(exc: Exception | None) -> None:
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_db() -> None:
    db = sqlite3.connect(DB_PATH)
    with open(BASE_DIR / "web_schema.sql", "r", encoding="utf-8") as f:
        db.executescript(f.read())
    db.commit()
    db.close()


def login_required(view_func):
    @wraps(view_func)
    def wrapped(*args, **kwargs):
        if "user_id" not in session:
            return redirect(url_for("login"))
        return view_func(*args, **kwargs)

    return wrapped


def manager_required(view_func):
    @wraps(view_func)
    def wrapped(*args, **kwargs):
        if session.get("role") not in ("manager", "admin"):
            flash("此功能僅主管可使用")
            return redirect(url_for("dashboard"))
        return view_func(*args, **kwargs)

    return wrapped


@app.route("/")
def index():
    if "user_id" in session:
        return redirect(url_for("dashboard"))
    return redirect(url_for("login"))


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form["username"].strip()
        password = request.form["password"].strip()
        db = get_db()
        user = db.execute(
            """
            SELECT u.id, u.username, u.password, u.role, e.id as employee_id, e.name
            FROM users u
            JOIN employees e ON e.id = u.employee_id
            WHERE u.username = ?
            """,
            (username,),
        ).fetchone()
        if user and user["password"] == password:
            session.clear()
            session["user_id"] = user["id"]
            session["employee_id"] = user["employee_id"]
            session["username"] = user["username"]
            session["name"] = user["name"]
            session["role"] = user["role"]
            return redirect(url_for("dashboard"))
        flash("帳號或密碼錯誤")
    return render_template("login.html")


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


@app.route("/dashboard")
@login_required
def dashboard():
    db = get_db()
    year = request.args.get("year", "2026")

    if session.get("role") in ("manager", "admin"):
        employees = db.execute(
            """
            SELECT e.id, e.name, e.department
            FROM employees e
            ORDER BY e.department, e.name
            """
        ).fetchall()
        goal_stats = db.execute(
            """
            SELECT employee_id, COUNT(*) as cnt
            FROM goals
            WHERE year = ?
            GROUP BY employee_id
            """,
            (year,),
        ).fetchall()
        stats_map = {row["employee_id"]: row["cnt"] for row in goal_stats}
        return render_template("dashboard_manager.html", employees=employees, year=year, stats_map=stats_map)

    goals = db.execute(
        """
        SELECT g.*, e.name as owner_name
        FROM goals g
        JOIN employees e ON e.id = g.employee_id
        WHERE g.employee_id = ? AND g.year = ?
        ORDER BY g.created_at DESC
        """,
        (session["employee_id"], year),
    ).fetchall()
    return render_template("dashboard_employee.html", goals=goals, year=year)


@app.route("/employee/<int:employee_id>")
@login_required
@manager_required
def employee_goals(employee_id: int):
    db = get_db()
    year = request.args.get("year", "2026")
    employee = db.execute("SELECT * FROM employees WHERE id = ?", (employee_id,)).fetchone()
    if not employee:
        flash("找不到員工")
        return redirect(url_for("dashboard"))

    goals = db.execute(
        """
        SELECT * FROM goals
        WHERE employee_id = ? AND year = ?
        ORDER BY id DESC
        """,
        (employee_id, year),
    ).fetchall()
    return render_template("employee_goals.html", employee=employee, goals=goals, year=year)


@app.route("/goals/create", methods=["POST"])
@login_required
@manager_required
def create_goal():
    db = get_db()
    employee_id = request.form["employee_id"]
    year = request.form["year"]
    objective = request.form["objective"].strip()
    key_result = request.form["key_result"].strip()
    target = request.form["target"].strip()

    db.execute(
        """
        INSERT INTO goals (employee_id, year, objective, key_result, target, mid_progress, end_progress, score)
        VALUES (?, ?, ?, ?, ?, 0, 0, NULL)
        """,
        (employee_id, year, objective, key_result, target),
    )
    db.commit()
    flash("已新增 OKR 目標")
    return redirect(url_for("employee_goals", employee_id=employee_id, year=year))


@app.route("/goals/<int:goal_id>/update", methods=["POST"])
@login_required
@manager_required
def update_goal(goal_id: int):
    db = get_db()
    mid_progress = float(request.form.get("mid_progress", 0))
    end_progress = float(request.form.get("end_progress", 0))
    score = int(request.form.get("score", 1))

    db.execute(
        """
        UPDATE goals
        SET mid_progress = ?, end_progress = ?, score = ?
        WHERE id = ?
        """,
        (mid_progress, end_progress, score, goal_id),
    )
    db.commit()

    row = db.execute("SELECT employee_id, year FROM goals WHERE id = ?", (goal_id,)).fetchone()
    flash("已更新進度與評分")
    return redirect(url_for("employee_goals", employee_id=row["employee_id"], year=row["year"]))


if __name__ == "__main__":
    if not DB_PATH.exists():
        init_db()
    app.run(debug=True, host="0.0.0.0", port=5000)
