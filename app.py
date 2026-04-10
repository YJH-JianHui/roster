import sqlite3
from flask import Flask, render_template, jsonify
from import_routes import import_bp

app = Flask(__name__)
DB_FILE = 'data/DB.db'
app.register_blueprint(import_bp)

def get_db_connection():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    return conn


@app.route('/')
def index():
    return "<h1>HR 系统运行中</h1><p>请访问 <a href='/profile/1'>/profile/1</a> 查看员工完整档案。</p>"


@app.route('/profile/<int:emp_id>')
def show_profile(emp_id):
    return render_template('profile.html', emp_id=emp_id)


@app.route('/api/employee/<int:emp_id>')
def get_employee_data(emp_id):
    conn = get_db_connection()

    # 1. 查主表快照视图
    profile_row = conn.execute(
        "SELECT * FROM vw_employee_profile WHERE employee_id = ?", (emp_id,)
    ).fetchone()
    if not profile_row:
        conn.close()
        return jsonify({"error": "Employee not found"}), 404
    profile_data = dict(profile_row)

    # 2. 查主表排版规则
    layout_groups = []
    groups_raw = conn.execute(
        "SELECT id, group_key, group_label FROM form_group "
        "WHERE template_id = 1 ORDER BY sort_order"
    ).fetchall()

    for g in groups_raw:
        fields_raw = conn.execute("""
            SELECT field_key AS key, field_label AS label,
                   lc, vc, min_r AS minR, is_photo AS isPhoto
            FROM form_field WHERE group_id = ? ORDER BY sort_order
        """, (g['id'],)).fetchall()

        fields = []
        for f in fields_raw:
            fd = dict(f)
            fd['isPhoto'] = bool(fd['isPhoto'])
            fields.append(fd)

        layout_groups.append({
            "id": g['group_key'],
            "title": g['group_label'],
            "fields": fields
        })

    # 3. 查各附表真实数据 (查询字段需严格对应 form_appendix_col 的 field_key)

    family_data = [dict(r) for r in conn.execute("""
        SELECT relation, real_name, birth_date, political_status,
               education_level, work_unit, position, phone
        FROM family_member WHERE employee_id = ? ORDER BY id
    """, (emp_id,)).fetchall()]

    work_exp_data = [dict(r) for r in conn.execute("""
        SELECT start_date, end_date, company_name, industry, company_type, position, 
               leave_reason, reference_person, reference_phone
        FROM work_experience WHERE employee_id = ? ORDER BY start_date
    """, (emp_id,)).fetchall()]

    contracts_data = [dict(r) for r in conn.execute("""
        SELECT seq, contract_type, start_date, end_date, remark
        FROM contract_record WHERE employee_id = ? ORDER BY seq
    """, (emp_id,)).fetchall()]

    training_data = [dict(r) for r in conn.execute("""
        SELECT start_date, end_date, training_name, training_type, training_org, result, cert_obtained
        FROM training_record WHERE employee_id = ? ORDER BY start_date
    """, (emp_id,)).fetchall()]

    # (已修改) 奖惩记录不再查询 amount 和 document_no
    rewards_data = [dict(r) for r in conn.execute("""
        SELECT record_date, record_type, category, reason, issuer
        FROM reward_punishment_record WHERE employee_id = ? ORDER BY record_date
    """, (emp_id,)).fetchall()]

    education_data = [dict(r) for r in conn.execute("""
        SELECT start_date, graduation_date, school_name, major, degree_level, degree_type, 
               degree_status, school_type, study_duration, is_highest
        FROM education_record WHERE employee_id = ? ORDER BY start_date
    """, (emp_id,)).fetchall()]

    certificates_data = [dict(r) for r in conn.execute("""
        SELECT issue_date, expire_date, cert_category, cert_class, cert_major, cert_level, cert_name
        FROM certificate_record WHERE employee_id = ? ORDER BY cert_category, issue_date DESC
    """, (emp_id,)).fetchall()]

    career_data = [dict(r) for r in conn.execute("""
        SELECT
            start_date || ' ~ ' || COALESCE(end_date, '至今') AS period,
            company,
            COALESCE(dept_level1, '') ||
                CASE WHEN dept_level2 IS NOT NULL THEN ' > ' || dept_level2 ELSE '' END ||
                CASE WHEN dept_level3 IS NOT NULL THEN ' > ' || dept_level3 ELSE '' END AS dept,
            position_name AS position,
            job_level_class,
            record_type,
            change_reason AS change_type
        FROM employment_record
        WHERE employee_id = ? ORDER BY start_date
    """, (emp_id,)).fetchall()]

    # (新增) 薪酬调整附表
    salary_changes_data = [dict(r) for r in conn.execute("""
        SELECT period, company, dept, position, job_level, job_class, job_level_class, change_reason
        FROM salary_change_record WHERE employee_id = ? ORDER BY period
    """, (emp_id,)).fetchall()]

    # 4. 查附表动态排版规则
    appendix_layout = []
    appx_raw = conn.execute(
        "SELECT id, appendix_key, title FROM form_appendix "
        "WHERE template_id = 1 ORDER BY sort_order"
    ).fetchall()

    for ax in appx_raw:
        cols = [dict(c) for c in conn.execute(
            "SELECT field_key AS key, label, colspan "
            "FROM form_appendix_col WHERE appendix_id = ? ORDER BY sort_order",
            (ax['id'],)
        ).fetchall()]
        appendix_layout.append({
            "key": ax['appendix_key'],
            "title": ax['title'],
            "columns": cols
        })

    conn.close()

    return jsonify({
        "data": profile_data,
        "layout": layout_groups,
        "appendixData": {
            "contracts":     contracts_data,
            "work_history":  work_exp_data,
            "family":        family_data,
            "education":     education_data,
            "certificates":  certificates_data,
            "training":      training_data,
            "rewards":       rewards_data,
            "career":        career_data,
            "salary_changes": salary_changes_data
        },
        "appendixLayout": appendix_layout
    })


if __name__ == '__main__':
    app.run(debug=True, use_reloader=False, port=5000)