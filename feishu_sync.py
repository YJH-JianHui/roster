"""
飞书自定义字段同步模块
将档案URL批量写入飞书用户自定义字段（HREF类型）

注册方式（在 app.py 中）：
    from feishu_sync import sync_bp, init_sync_config
    init_sync_config(
        app_id=FEISHU_APP_ID,
        app_secret=FEISHU_APP_SECRET,
        base_profile_url=BASE_PROFILE_URL,
        db_file=DB_FILE,
    )
    app.register_blueprint(sync_bp)

接口：
    GET /api/sync/feishu-profile-url
    可选参数：?user_id=xxx  只更新单个用户
    无参数时更新全部用户

返回示例：
    { "total": 322, "success": 320, "fail": 2,
      "errors": [{"user_id": "xxx", "code": 41050, "msg": "..."}] }
"""

import sqlite3
import time
import requests
from flask import Blueprint, jsonify, request, current_app
from auth_feishu import require_login

sync_bp = Blueprint('sync_bp', __name__)

# ── 模块级配置（由 init_sync_config 写入）──
_cfg: dict = {}

CUSTOM_ATTR_ID  = 'C-7626971181569493969'
USER_ID_TYPE    = 'user_id'
REQUEST_INTERVAL = 0.01   # 秒，防止触发飞书频控


def init_sync_config(app_id: str, app_secret: str,
                     base_profile_url: str, db_file: str):
    """在 app.py 启动时调用一次，与 init_lark_client 同级"""
    _cfg.update({
        'app_id':           app_id,
        'app_secret':       app_secret,
        'base_profile_url': base_profile_url.rstrip('/'),
        'db_file':          db_file,
    })


# ════════════════════════════════════════════════════════
#  内部工具函数
# ════════════════════════════════════════════════════════

def _get_tenant_access_token() -> str:
    resp = requests.post(
        'https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal',
        json={'app_id': _cfg['app_id'], 'app_secret': _cfg['app_secret']},
        timeout=10,
    )
    resp.raise_for_status()
    data = resp.json()
    if data.get('code') != 0:
        raise RuntimeError(f'获取 tenant_access_token 失败: {data}')
    return data['tenant_access_token']


def _load_user_ids(single_id: str | None = None) -> list[str]:
    conn = sqlite3.connect(_cfg['db_file'])
    if single_id:
        rows = conn.execute(
            'SELECT feishu_user_id FROM feishu_user_map WHERE feishu_user_id = ?',
            (single_id,)
        ).fetchall()
    else:
        rows = conn.execute(
            'SELECT feishu_user_id FROM feishu_user_map'
        ).fetchall()
    conn.close()
    return [r[0] for r in rows if r[0]]


def _patch_user(token: str, feishu_user_id: str) -> dict:
    """返回飞书响应 JSON，调用方判断 code"""
    url = f'https://open.feishu.cn/open-apis/contact/v3/users/{feishu_user_id}'
    resp = requests.patch(
        url,
        params={'user_id_type': USER_ID_TYPE},
        headers={
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json; charset=utf-8',
        },
        json={
            'custom_attrs': [{
                'type': 'HREF',
                'id':   CUSTOM_ATTR_ID,
                'value': {
                    'text': '点击查看',
                    'url':  f'{_cfg["base_profile_url"]}/profile/{feishu_user_id}',
                },
            }]
        },
        timeout=10,
    )
    return resp.json()


# ════════════════════════════════════════════════════════
#  路由
# ════════════════════════════════════════════════════════

@sync_bp.route('/api/sync/feishu-profile-url')
@require_login
def sync_feishu_profile_url():
    """
    GET /api/sync/feishu-profile-url          → 更新全部用户
    GET /api/sync/feishu-profile-url?user_id=xxx → 只更新指定用户
    """
    if not _cfg:
        return jsonify({'error': '同步模块未初始化，请检查 init_sync_config'}), 500

    single_id = request.args.get('user_id')

    try:
        token = _get_tenant_access_token()
    except Exception as e:
        current_app.logger.error(f'[飞书同步] 获取 token 失败: {e}')
        return jsonify({'error': f'获取飞书 token 失败: {e}'}), 500

    user_ids = _load_user_ids(single_id)
    if not user_ids:
        msg = f'未找到用户: {single_id}' if single_id else '映射表中无用户数据'
        return jsonify({'error': msg}), 404

    success, errors = 0, []

    for idx, uid in enumerate(user_ids):
        try:
            result = _patch_user(token, uid)
            if result.get('code') == 0:
                success += 1
                print(result, success)
            else:
                errors.append({
                    'user_id': uid,
                    'code':    result.get('code'),
                    'msg':     result.get('msg'),
                })
                current_app.logger.warning(
                    f'[飞书同步] {uid} 更新失败: {result.get("code")} {result.get("msg")}'
                )
        except Exception as e:
            errors.append({'user_id': uid, 'error': str(e)})
            current_app.logger.error(f'[飞书同步] {uid} 请求异常: {e}')

        if idx < len(user_ids) - 1:
            time.sleep(REQUEST_INTERVAL)

    return jsonify({
        'total':   len(user_ids),
        'success': success,
        'fail':    len(errors),
        'errors':  errors,
    })
