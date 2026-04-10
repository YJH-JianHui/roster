import sqlite3
import traceback
from flask import Blueprint, request, jsonify, render_template
from openpyxl import load_workbook

import_bp = Blueprint('import_bp', __name__)
DB_FILE = 'data/DB.db'

# ══════════════════════════════════════════════════════════════
#  Sheet 配置
#
#  去掉所有 fk_map / employee_id 逻辑：
#  各子表直接以 id_card_no 作为外键列写入，数据库主键也全部
#  使用联合主键，不再需要任何 id 转换。
#
#  字段说明：
#    table           → 目标数据库表名
#    unique_keys     → 业务唯一键（同时也是数据库联合主键）
#    ignore_cols     → Excel 中存在但导入时跳过的列（英文 field_key）
#    name_is_member  → 家庭成员表特殊处理（real_name 是成员姓名）
#    resolve_emp_record → 合同记录需自动填充 employment_record_id
# ══════════════════════════════════════════════════════════════
SHEET_CONFIG = {
    '员工主表': {
        'table': 'employee',
        'unique_keys': ['id_card_no'],
        'ignore_cols': [],
    },
    '任职记录': {
        'table': 'employment_record',
        'unique_keys': ['id_card_no', 'start_date'],
        'ignore_cols': ['real_name'],
    },
    '教育经历': {
        'table': 'education_record',
        'unique_keys': ['id_card_no', 'school_name', 'start_date'],
        'ignore_cols': ['real_name'],
    },
    '地址信息': {
        'table': 'address_record',
        'unique_keys': ['id_card_no', 'address_type'],
        'ignore_cols': ['real_name'],
    },
    '合同记录': {
        'table': 'contract_record',
        'unique_keys': ['id_card_no', 'seq', 'start_date'],
        'ignore_cols': ['real_name'],
        'resolve_emp_record': True,
    },
    '家庭成员': {
        'table': 'family_member',
        'unique_keys': ['id_card_no', 'relation', 'real_name'],
        'ignore_cols': [],
        'name_is_member': True,
    },
    '职称资质': {
        'table': 'certificate_record',
        'unique_keys': ['id_card_no', 'cert_name', 'issue_date'],
        'ignore_cols': ['real_name'],
    },
    '培训记录': {
        'table': 'training_record',
        'unique_keys': ['id_card_no', 'training_name', 'start_date'],
        'ignore_cols': ['real_name'],
    },
    '奖惩记录': {
        'table': 'reward_punishment_record',
        'unique_keys': ['id_card_no', 'record_date', 'record_type'],
        'ignore_cols': ['real_name'],
    },
    '入职前工作经历': {
        'table': 'work_experience',
        'unique_keys': ['id_card_no', 'company_name', 'start_date'],
        'ignore_cols': ['real_name'],
    },
    '薪酬调整记录': {
        'table': 'salary_change_record',
        'unique_keys': ['id_card_no', 'period'],
        'ignore_cols': ['real_name'],
    },
    '飞书账号映射': {
        'table': 'feishu_user_map',
        'unique_keys': ['id_card_no'],
        'ignore_cols': [],
    },
}

IMPORT_ORDER = [
    '员工主表', '任职记录', '教育经历', '地址信息', '合同记录',
    '家庭成员', '职称资质', '培训记录', '奖惩记录', '入职前工作经历',
    '薪酬调整记录', '飞书账号映射',
]


def parse_header(row):
    """解析列头：'中文_英文' → 返回 field_key 列表"""
    keys = []
    for cell in row:
        val = str(cell.value).strip() if cell.value else ''
        keys.append(val.split('_', 1)[1].strip() if '_' in val else val)
    return keys


def get_db():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def import_sheet(conn, ws, sheet_name, cfg):
    stats = {'inserted': 0, 'updated': 0, 'skipped': 0, 'errors': []}

    rows = list(ws.iter_rows(min_row=3))
    if not rows:
        return stats

    field_keys     = parse_header(rows[0])
    data_rows      = rows[1:]

    table          = cfg['table']
    unique_keys    = cfg['unique_keys']
    ignore_cols    = set(cfg.get('ignore_cols', []))
    name_is_member = cfg.get('name_is_member', False)
    resolve_emp    = cfg.get('resolve_emp_record', False)

    for row_idx, row in enumerate(data_rows, start=4):
        raw = {}
        for col_idx, cell in enumerate(row):
            if col_idx >= len(field_keys):
                break
            key = field_keys[col_idx]
            val = cell.value
            if val is not None and str(val).strip() == '':
                val = None
            raw[key] = val

        if all(v is None for v in raw.values()):
            stats['skipped'] += 1
            continue

        try:
            id_card_no = raw.get('id_card_no')
            if not id_card_no:
                raise ValueError("缺少身份证号 id_card_no")

            if table != 'employee':
                exists = conn.execute(
                    "SELECT 1 FROM employee WHERE id_card_no=?", (id_card_no,)
                ).fetchone()
                if not exists:
                    raise ValueError(
                        f"身份证号 {id_card_no} 在员工主表中不存在，请先导入员工主表"
                    )

            # 构建写入字段
            record = {k: v for k, v in raw.items() if k and k not in ignore_cols}

            # 家庭成员：Excel 中 member_name → 数据库 real_name
            if name_is_member and 'member_name' in record:
                record['real_name'] = record.pop('member_name')

            # 合同记录：按 id_card_no + start_date 找最近的任职段
            if resolve_emp:
                emp_row = conn.execute(
                    "SELECT id FROM employment_record "
                    "WHERE id_card_no=? AND start_date<=? "
                    "ORDER BY start_date DESC LIMIT 1",
                    (id_card_no, record.get('start_date', ''))
                ).fetchone()
                record['employment_record_id'] = emp_row[0] if emp_row else None

            # Upsert
            where_parts  = [f"{k}=?" for k in unique_keys]
            where_vals   = [record[k] for k in unique_keys]
            where_clause = ' AND '.join(where_parts)

            existing = conn.execute(
                f"SELECT 1 FROM {table} WHERE {where_clause}", where_vals
            ).fetchone()

            if existing:
                update_fields = {k: v for k, v in record.items()
                                 if k not in unique_keys}
                if update_fields:
                    set_clause = ', '.join(f"{k}=?" for k in update_fields)
                    conn.execute(
                        f"UPDATE {table} SET {set_clause} WHERE {where_clause}",
                        list(update_fields.values()) + where_vals
                    )
                    stats['updated'] += 1
                else:
                    stats['skipped'] += 1
            else:
                cols         = ', '.join(record.keys())
                placeholders = ', '.join('?' for _ in record)
                conn.execute(
                    f"INSERT INTO {table} ({cols}) VALUES ({placeholders})",
                    list(record.values())
                )
                stats['inserted'] += 1

        except Exception as e:
            stats['errors'].append({
                'row':    row_idx,
                'msg':    str(e),
                'detail': traceback.format_exc().splitlines()[-1],
            })

    return stats


@import_bp.route('/import')
def import_page():
    return render_template('import.html')


@import_bp.route('/api/import', methods=['POST'])
def do_import():
    if 'file' not in request.files:
        return jsonify({'success': False, 'message': '未收到文件'}), 400

    file = request.files['file']
    if not file.filename.endswith('.xlsx'):
        return jsonify({'success': False, 'message': '仅支持 .xlsx 格式'}), 400

    try:
        wb = load_workbook(file, data_only=True)
    except Exception as e:
        return jsonify({'success': False, 'message': f'文件解析失败：{e}'}), 400

    sheet_names_in_file = set(wb.sheetnames)
    results = {}
    total   = {'inserted': 0, 'updated': 0, 'skipped': 0, 'error_count': 0}

    conn = get_db()
    try:
        conn.execute("BEGIN")
        for sheet_name in IMPORT_ORDER:
            if sheet_name not in sheet_names_in_file:
                continue
            stats = import_sheet(
                conn, wb[sheet_name], sheet_name, SHEET_CONFIG[sheet_name]
            )
            results[sheet_name]   = stats
            total['inserted']    += stats['inserted']
            total['updated']     += stats['updated']
            total['skipped']     += stats['skipped']
            total['error_count'] += len(stats['errors'])

        if total['error_count'] == 0:
            conn.execute("COMMIT")
            success = True
            message = '导入成功，所有数据已写入数据库。'
        else:
            conn.execute("ROLLBACK")
            success = False
            message = (f'存在 {total["error_count"]} 处错误，已全部回滚，'
                       f'数据库未做任何修改。请修正后重新导入。')

    except Exception as e:
        conn.execute("ROLLBACK")
        conn.close()
        return jsonify({'success': False, 'message': f'导入过程异常：{e}', 'results': {}}), 500

    conn.close()
    return jsonify({
        'success': success,
        'message': message,
        'total':   total,
        'results': {
            k: {
                'inserted': v['inserted'],
                'updated':  v['updated'],
                'skipped':  v['skipped'],
                'errors':   v['errors'],
            } for k, v in results.items()
        }
    })