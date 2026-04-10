import sqlite3
from datetime import timedelta
from flask import Flask, render_template, jsonify, session, redirect
from import_routes import import_bp
from auth_feishu import auth_bp, init_lark_client, require_login
from feishu_sync import sync_bp, init_sync_config

app = Flask(__name__)

# ── 必填：Flask session 加密密钥，生产环境改成随机长字符串 ──
app.secret_key = 'CHANGE_ME_TO_A_RANDOM_SECRET'
app.permanent_session_lifetime = timedelta(hours=8)

# ── 飞书应用配置（从飞书开发者后台"凭证与基础信息"页获取）──
FEISHU_APP_ID      = 'cli_a952d58519fb9bc4'
FEISHU_APP_SECRET  = 'fI0doVKtNWNwv4SVTyxjPgZEFDwsh3vG'
FEISHU_REDIRECT_URI = 'http://127.0.0.1:5000/auth/callback'

# 飞书自定义字段的基础URL
BASE_PROFILE_URL = 'http://127.0.0.1:5000'

DB_FILE = 'data/DB.db'

init_lark_client(FEISHU_APP_ID, FEISHU_APP_SECRET, FEISHU_REDIRECT_URI)

init_sync_config(
    app_id=FEISHU_APP_ID,
    app_secret=FEISHU_APP_SECRET,
    base_profile_url=BASE_PROFILE_URL,
    db_file=DB_FILE,
)

app.register_blueprint(auth_bp)
app.register_blueprint(import_bp)

app.register_blueprint(sync_bp)


def get_db_connection():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    return conn


@app.route('/')
@app.route('/')
def index():
    if not session.get('logged_in'):
        return redirect('/auth/login')
    # 登录后跳到一个列表页或提示页，而不是某个具体员工
    return '<h1>登录成功</h1><p>请输入员工飞书ID访问档案，例如：/profile/123456</p>'


@app.route('/profile/<feishu_user_id>')
@require_login
def show_profile(feishu_user_id):
    return render_template('profile.html', id_card_no=feishu_user_id)


@app.route('/api/employee/<feishu_user_id>')
@require_login
def get_employee_data(feishu_user_id):
    conn = get_db_connection()

    # ── 第一步：飞书ID → 身份证号 ──────────────────────────
    map_row = conn.execute(
        'SELECT id_card_no FROM feishu_user_map WHERE feishu_user_id = ?',
        (feishu_user_id,)
    ).fetchone()
    if not map_row:
        conn.close()
        return jsonify({'error': f'未找到该飞书用户对应的员工档案: {feishu_user_id}'}), 404

    id_card_no = map_row['id_card_no']

    # ── 第二步：身份证号查视图（以下全部不变）──────────────
    profile_row = conn.execute(
        'SELECT * FROM vw_employee_profile WHERE id_card_no = ?', (id_card_no,)
    ).fetchone()
    if not profile_row:
        conn.close()
        return jsonify({'error': 'Employee not found'}), 404
    profile_data = dict(profile_row)

    layout_groups = []
    groups_raw = conn.execute(
        'SELECT id, group_key, group_label FROM form_group '
        'WHERE template_id = 1 ORDER BY sort_order'
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
        layout_groups.append({'id': g['group_key'], 'title': g['group_label'], 'fields': fields})

    education_data = [dict(r) for r in conn.execute("""
        SELECT start_date, graduation_date, school_name, major,
               degree_level, degree_type, degree_status, school_type,
               study_duration, is_highest
        FROM education_record WHERE id_card_no = ? ORDER BY start_date
    """, (id_card_no,)).fetchall()]

    work_exp_data = [dict(r) for r in conn.execute("""
        SELECT start_date, end_date, company_name, industry, company_type,
               position, leave_reason, reference_person, reference_phone
        FROM work_experience WHERE id_card_no = ? ORDER BY start_date
    """, (id_card_no,)).fetchall()]

    contracts_data = [dict(r) for r in conn.execute("""
        SELECT seq, contract_type, start_date, end_date, remark
        FROM contract_record WHERE id_card_no = ? ORDER BY seq, start_date
    """, (id_card_no,)).fetchall()]

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
            COALESCE(change_reason, COALESCE(end_reason, '在职')) AS change_type
        FROM employment_record WHERE id_card_no = ? ORDER BY start_date
    """, (id_card_no,)).fetchall()]

    salary_changes_data = [dict(r) for r in conn.execute("""
        SELECT period, company, dept, position,
               job_level, job_class, job_level_class, change_reason
        FROM salary_change_record WHERE id_card_no = ? ORDER BY period
    """, (id_card_no,)).fetchall()]

    certificates_data = [dict(r) for r in conn.execute("""
            SELECT cert_category, cert_name, cert_major, cert_level, cert_no, issue_date, expire_date
            FROM certificate_record WHERE id_card_no = ? ORDER BY cert_category, issue_date DESC
        """, (id_card_no,)).fetchall()]

    training_data = [dict(r) for r in conn.execute("""
        SELECT start_date, end_date, training_name, training_type,
               training_org, result, cert_obtained
        FROM training_record WHERE id_card_no = ? ORDER BY start_date
    """, (id_card_no,)).fetchall()]

    rewards_data = [dict(r) for r in conn.execute("""
        SELECT record_date, record_type, category, reason, issuer
        FROM reward_punishment_record WHERE id_card_no = ? ORDER BY record_date
    """, (id_card_no,)).fetchall()]

    family_data = [dict(r) for r in conn.execute("""
        SELECT relation, real_name, birth_date, political_status,
               education_level, work_unit, position, phone
        FROM family_member WHERE id_card_no = ? ORDER BY rowid
    """, (id_card_no,)).fetchall()]

    appendix_layout = []
    appx_raw = conn.execute(
        'SELECT id, appendix_key, title FROM form_appendix '
        'WHERE template_id = 1 ORDER BY sort_order'
    ).fetchall()
    for ax in appx_raw:
        cols = [dict(c) for c in conn.execute(
            'SELECT field_key AS key, label, colspan '
            'FROM form_appendix_col WHERE appendix_id = ? ORDER BY sort_order',
            (ax['id'],)
        ).fetchall()]
        appendix_layout.append({'key': ax['appendix_key'], 'title': ax['title'], 'columns': cols})

    conn.close()

    return jsonify({
        'data':   profile_data,
        'layout': layout_groups,
        'appendixData': {
            'education':      education_data,
            'work_history':   work_exp_data,
            'contracts':      contracts_data,
            'career':         career_data,
            'salary_changes': salary_changes_data,
            'certificates':   certificates_data,
            'training':       training_data,
            'rewards':        rewards_data,
            'family':         family_data,
        },
        'appendixLayout': appendix_layout,
    })


if __name__ == '__main__':
    app.run(debug=True, use_reloader=False, port=5000)
