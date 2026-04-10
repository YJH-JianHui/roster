import sqlite3
import traceback
from flask import Blueprint, request, jsonify, render_template
from openpyxl import load_workbook

import_bp = Blueprint('import_bp', __name__)
DB_FILE = 'data/DB.db'

# ── 唯一键定义 ────────────────────────────────────────────────────────────────
# 每张 Sheet 对应的数据库表名 + 业务唯一键字段列表（数据库字段名）
SHEET_CONFIG = {
    '员工主表': {
        'table': 'employee',
        'unique_keys': ['id_card_no'],
        'ignore_cols': [],          # 导入时忽略的列（英文 field_key）
    },
    '任职记录': {
        'table': 'employment_record',
        'unique_keys': ['employee_id', 'start_date'],
        'ignore_cols': ['real_name'],
        'fk_map': {'id_card_no': ('employee', 'id_card_no', 'id', 'employee_id')},
    },
    '教育经历': {
        'table': 'education_record',
        'unique_keys': ['employee_id', 'school_name', 'start_date'],
        'ignore_cols': ['real_name'],
        'fk_map': {'id_card_no': ('employee', 'id_card_no', 'id', 'employee_id')},
    },
    '地址信息': {
        'table': 'address_record',
        'unique_keys': ['employee_id', 'address_type'],
        'ignore_cols': ['real_name'],
        'fk_map': {'id_card_no': ('employee', 'id_card_no', 'id', 'employee_id')},
    },
    '合同记录': {
        'table': 'contract_record',
        'unique_keys': ['employee_id', 'seq', 'start_date'],
        'ignore_cols': ['real_name'],
        'fk_map': {'id_card_no': ('employee', 'id_card_no', 'id', 'employee_id')},
        'extra_fk': {
            # employment_record_id: 根据 employee_id + start_date 查最早一条
            'employment_record_id': 'SELECT id FROM employment_record WHERE employee_id=? ORDER BY start_date LIMIT 1'
        }
    },
    '家庭成员': {
        'table': 'family_member',
        'unique_keys': ['employee_id', 'relation', 'real_name'],
        'ignore_cols': [],          # real_name 在家庭成员里是真实字段，不忽略
        'fk_map': {'id_card_no': ('employee', 'id_card_no', 'id', 'employee_id')},
        'name_is_member': True,     # real_name 列头在该表是成员姓名，不是员工姓名
    },
    '职称资质': {
        'table': 'certificate_record',
        'unique_keys': ['employee_id', 'cert_name', 'issue_date'],
        'ignore_cols': ['real_name'],
        'fk_map': {'id_card_no': ('employee', 'id_card_no', 'id', 'employee_id')},
    },
    '培训记录': {
        'table': 'training_record',
        'unique_keys': ['employee_id', 'training_name', 'start_date'],
        'ignore_cols': ['real_name'],
        'fk_map': {'id_card_no': ('employee', 'id_card_no', 'id', 'employee_id')},
    },
    '奖惩记录': {
        'table': 'reward_punishment_record',
        'unique_keys': ['employee_id', 'record_date', 'record_type'],
        'ignore_cols': ['real_name'],
        'fk_map': {'id_card_no': ('employee', 'id_card_no', 'id', 'employee_id')},
    },
    '入职前工作经历': {
        'table': 'work_experience',
        'unique_keys': ['employee_id', 'company_name', 'start_date'],
        'ignore_cols': ['real_name'],
        'fk_map': {'id_card_no': ('employee', 'id_card_no', 'id', 'employee_id')},
    },
    '薪酬调整记录': {
        'table': 'salary_change_record',
        'unique_keys': ['employee_id', 'period'],
        'ignore_cols': ['real_name'],
        'fk_map': {'id_card_no': ('employee', 'id_card_no', 'id', 'employee_id')},
    },
}

# 导入顺序（员工主表必须第一个）
IMPORT_ORDER = [
    '员工主表', '任职记录', '教育经历', '地址信息', '合同记录',
    '家庭成员', '职称资质', '培训记录', '奖惩记录', '入职前工作经历', '薪酬调整记录'
]


def parse_header(row):
    """解析列头行：'中文_英文' -> 返回 field_key 列表"""
    keys = []
    for cell in row:
        val = str(cell.value).strip() if cell.value else ''
        if '_' in val:
            keys.append(val.split('_', 1)[1].strip())
        else:
            keys.append(val)
    return keys


def get_db():
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def resolve_fk(conn, id_card_no, fk_map):
    """通过身份证号查出 employee_id"""
    resolved = {}
    if not fk_map:
        return resolved
    for src_col, (ref_table, ref_src, ref_dst, target_col) in fk_map.items():
        row = conn.execute(
            f"SELECT {ref_dst} FROM {ref_table} WHERE {ref_src}=?", (id_card_no,)
        ).fetchone()
        if row:
            resolved[target_col] = row[0]
        else:
            resolved[target_col] = None
    return resolved


def import_sheet(conn, ws, sheet_name, cfg):
    stats = {'inserted': 0, 'updated': 0, 'skipped': 0, 'errors': []}

    rows = list(ws.iter_rows(min_row=3))   # 第3行是列头
    if not rows:
        return stats

    header_row = rows[0]
    field_keys = parse_header(header_row)
    data_rows = rows[1:]                   # 第4行起是数据（跳过第2行说明行）

    table = cfg['table']
    unique_keys = cfg['unique_keys']
    ignore_cols = set(cfg.get('ignore_cols', []))
    fk_map = cfg.get('fk_map', {})
    name_is_member = cfg.get('name_is_member', False)

    for row_idx, row in enumerate(data_rows, start=4):
        # 构建字段字典
        raw = {}
        for col_idx, cell in enumerate(row):
            if col_idx >= len(field_keys):
                break
            key = field_keys[col_idx]
            val = cell.value
            if val is not None and str(val).strip() == '':
                val = None
            raw[key] = val

        # 跳过空行
        if all(v is None for v in raw.values()):
            stats['skipped'] += 1
            continue

        try:
            # 提取身份证号用于外键解析
            id_card_no = raw.get('id_card_no')
            if not id_card_no and table != 'employee':
                raise ValueError("缺少身份证号 id_card_no")

            # 解析外键（employee_id）
            fk_resolved = resolve_fk(conn, id_card_no, fk_map) if fk_map else {}
            if fk_map and None in fk_resolved.values():
                raise ValueError(f"身份证号 {id_card_no} 在员工主表中不存在，请先导入员工主表")

            # 处理合同记录额外外键
            if 'extra_fk' in cfg:
                emp_id = fk_resolved.get('employee_id')
                for fk_col, sql in cfg['extra_fk'].items():
                    row_r = conn.execute(sql, (emp_id,)).fetchone()
                    fk_resolved[fk_col] = row_r[0] if row_r else None

            # 构建最终写入字段（排除忽略列和来源外键列）
            record = {}
            skip_src = set(fk_map.keys()) if fk_map else set()

            for k, v in raw.items():
                if k in ignore_cols:
                    continue
                if k in skip_src:
                    continue
                record[k] = v

            # 注入外键
            record.update(fk_resolved)

            # 家庭成员特殊处理：Excel 里 member_name -> real_name
            if name_is_member and 'member_name' in record:
                record['real_name'] = record.pop('member_name')

            # 去掉 None 键名
            record = {k: v for k, v in record.items() if k}

            # 构建唯一键查询条件
            where_parts = []
            where_vals = []
            for uk in unique_keys:
                if uk not in record:
                    raise ValueError(f"唯一键字段 {uk} 缺失")
                where_parts.append(f"{uk}=?")
                where_vals.append(record[uk])

            where_clause = ' AND '.join(where_parts)
            existing = conn.execute(
                f"SELECT id FROM {table} WHERE {where_clause}", where_vals
            ).fetchone()

            if existing:
                # UPDATE
                update_fields = {k: v for k, v in record.items() if k not in unique_keys and k != 'id'}
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
                # INSERT
                cols = ', '.join(record.keys())
                placeholders = ', '.join('?' for _ in record)
                conn.execute(
                    f"INSERT INTO {table} ({cols}) VALUES ({placeholders})",
                    list(record.values())
                )
                stats['inserted'] += 1

        except Exception as e:
            stats['errors'].append({
                'row': row_idx,
                'msg': str(e),
                'detail': traceback.format_exc().splitlines()[-1]
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
    total = {'inserted': 0, 'updated': 0, 'skipped': 0, 'error_count': 0}

    conn = get_db()
    try:
        conn.execute("BEGIN")
        for sheet_name in IMPORT_ORDER:
            if sheet_name not in sheet_names_in_file:
                continue
            cfg = SHEET_CONFIG[sheet_name]
            ws = wb[sheet_name]
            stats = import_sheet(conn, ws, sheet_name, cfg)
            results[sheet_name] = stats
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
            message = f'存在 {total["error_count"]} 处错误，已全部回滚，数据库未做任何修改。请修正后重新导入。'

    except Exception as e:
        conn.execute("ROLLBACK")
        conn.close()
        return jsonify({'success': False, 'message': f'导入过程异常：{e}', 'results': {}}), 500

    conn.close()
    return jsonify({
        'success': success,
        'message': message,
        'total': total,
        'results': {
            k: {
                'inserted': v['inserted'],
                'updated':  v['updated'],
                'skipped':  v['skipped'],
                'errors':   v['errors'],
            } for k, v in results.items()
        }
    })
