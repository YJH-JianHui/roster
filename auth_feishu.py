"""
飞书网页免登认证模块
依赖：pip install lark-oapi flask

流程：
  1. 用户访问受保护页面 → require_login 检查 session
  2. 未登录 → 重定向到飞书授权页
  3. 飞书回调 /auth/callback?code=xxx
  4. 用 code 换 user_access_token，再获取 open_id
  5. 查 feishu_user_map → 写入 session → 跳回原页面
"""

import functools
import lark_oapi as lark
from lark_oapi.api.authen.v1 import (
    CreateOidcAccessTokenRequest,
    CreateOidcAccessTokenRequestBody,
    GetUserInfoRequest,
)
from flask import (
    Blueprint, redirect, request, session, jsonify, current_app
)

auth_bp = Blueprint('auth_bp', __name__)

# ── 飞书客户端（在 create_app / app.py 中调用 init_lark_client 初始化）──
_lark_client: lark.Client = None
_app_id: str = None
_redirect_uri: str = None   # 必须与飞书开发者后台"重定向URL"完全一致


def init_lark_client(app_id: str, app_secret: str, redirect_uri: str):
    """在 app.py 启动时调用一次"""
    global _lark_client, _app_id, _redirect_uri
    _app_id = app_id
    _redirect_uri = redirect_uri
    _lark_client = (
        lark.Client.builder()
        .app_id(app_id)
        .app_secret(app_secret)
        .log_level(lark.LogLevel.WARNING)
        .build()
    )


# ════════════════════════════════════════════════════════
#  工具函数
# ════════════════════════════════════════════════════════

def _feishu_auth_url(state: str = '') -> str:
    """拼接飞书OAuth授权页地址"""
    from urllib.parse import urlencode
    params = {
        'app_id':       _app_id,
        'redirect_uri': _redirect_uri,
        'response_type':'code',
        'state':        state,
    }
    return 'https://open.feishu.cn/open-apis/authen/v1/authorize?' + urlencode(params)


def _code_to_open_id(code: str) -> str | None:
    """
    用授权码换 user_access_token，再获取 open_id。
    成功返回 open_id 字符串，失败返回 None。
    """
    # Step1：code → user_access_token
    req = (
        CreateOidcAccessTokenRequest.builder()
        .request_body(
            CreateOidcAccessTokenRequestBody.builder()
            .grant_type('authorization_code')
            .code(code)
            .build()
        )
        .build()
    )
    resp = _lark_client.authen.v1.oidc_access_token.create(req)
    if not resp.success():
        current_app.logger.error(
            f'[飞书免登] 换取 user_access_token 失败: {resp.code} {resp.msg}'
        )
        return None

    user_access_token = resp.data.access_token

    # Step2：user_access_token → 用户信息
    info_req = (
        GetUserInfoRequest.builder()
        .build()
    )
    # 需要用 user_access_token 而非 app_access_token，手动传 Option
    info_resp = _lark_client.authen.v1.user_info.get(
        info_req,
        lark.RequestOption.builder()
        .user_access_token(user_access_token)
        .build()
    )
    if not info_resp.success():
        current_app.logger.error(
            f'[飞书免登] 获取用户信息失败: {info_resp.code} {info_resp.msg}'
        )
        return None

    return info_resp.data.open_id


# ════════════════════════════════════════════════════════
#  路由
# ════════════════════════════════════════════════════════

@auth_bp.route('/auth/login')
def login():
    """手动触发登录（或未登录时被 require_login 重定向到此）"""
    next_url = request.args.get('next', '/')
    return redirect(_feishu_auth_url(state=next_url))


@auth_bp.route('/auth/callback')
def callback():
    code = request.args.get('code')
    next_url = request.args.get('state', '/')

    if not code:
        return '授权失败：缺少 code 参数', 400

    open_id = _code_to_open_id(code)
    if not open_id:
        return '授权失败：无法获取用户信息，请联系管理员', 500

    # ✅ 只要能换到 open_id 就说明是合法的飞书企业成员，直接写 session
    # 不再查 feishu_user_map，登录者身份仅用于鉴权，不绑定具体档案
    session.permanent = True
    session['open_id']   = open_id
    session['logged_in'] = True

    return redirect(next_url)


@auth_bp.route('/auth/logout')
def logout():
    session.clear()
    return redirect('/')


@auth_bp.route('/auth/me')
def me():
    """调试用：查看当前登录信息"""
    if 'open_id' not in session:
        return jsonify({'logged_in': False})
    return jsonify({
        'logged_in':  True,
        'open_id':    session['open_id'],
        'id_card_no': session['id_card_no'],
        'real_name':  session['real_name'],
    })


# ════════════════════════════════════════════════════════
#  装饰器：保护路由
# ════════════════════════════════════════════════════════

def require_login(f):
    """
    用法：
        @app.route('/profile/<feishu_user_id>')
        @require_login
        def show_profile(feishu_user_id): ...
    """
    @functools.wraps(f)
    def wrapper(*args, **kwargs):
        if not session.get('logged_in'):   # ← 改这里
            if request.path.startswith('/api/'):
                return jsonify({'error': '未登录，请先完成飞书授权'}), 401
            return redirect(f'/auth/login?next={request.url}')
        return f(*args, **kwargs)
    return wrapper
