-- ============================================================
-- 员工电子档案 - 表单模板初始化数据
-- 公司：昆明鼎承科技有限公司
-- 版本：4.0
-- 变更记录（相对 v3.0）：
--   1. [G5 证书资质] 主表块完全删除，不再在主表展示摘要；
--      全量记录统一走附表 certificates（appendix_key = 'certificates'）
--   2. [G9 跨公司转移信息] 主表块完全删除，跨公司信息已通过
--      career 附表的 transfer_flag 字段区分，无需单独模块
--   3. [vw_employee_profile] 移除 G5 三路 cert LEFT JOIN 及其字段输出；
--      移除 G9 staff_transfer_record LEFT JOIN 及其字段输出
--   4. [form_group] 删除 id=5（certificate）和 id=9（transfer）两个分组
--
-- 主表模块（form_group）：
--   G1 基本信息 / G2 证件信息 / G3 任职信息 / G4 学历信息（最高学历摘要）
--   G6 地址信息 / G7 合同信息 / G8 离职/退休信息
--
-- 附表 appendix_key 汇总（须与后端 appendixData key 完全一致）：
--   contracts    劳动合同签订记录
--   work_history 入职前工作经历
--   family       家庭成员情况
--   education    教育经历
--   certificates 职称/职业资格（含职称、职业资格、职业技能，按 cert_category 区分）
--   training     培训记录
--   rewards      奖惩记录
--   career       职业生涯时间线（含 job_class/job_level/transfer_flag）
--
-- 排版规则（24列栅格）：
--   lc     = 标签列宽（栅格数），建议 2~4
--   vc     = 值列宽（栅格数），0=弹性自动补满当行剩余
--   min_r  = 照片跨行行数（is_photo=1 专用）
--   is_photo = 1 表示照片格，独占右侧 vc 列，竖向跨 min_r 行
--   sort_order 步长 10，方便在任意位置插入新字段
-- ============================================================

PRAGMA foreign_keys = ON;

-- ============================================================
-- PART B：视图重建（完整重建，与 v2.0 保持字段兼容并扩展）
-- ============================================================

DROP VIEW IF EXISTS vw_employee_profile;
CREATE VIEW vw_employee_profile AS
SELECT
    e.id                        AS employee_id,
    e.photo_path                AS photo,

    -- ── 基本信息（对齐 G1 field_key）──────────────────────────
    e.real_name                 AS name,
    e.gender,
    CAST((julianday('now') - julianday(e.birth_date || '-01')) / 365.25 AS INTEGER)
                                AS age,
    e.birth_date,
    e.ethnicity,
    e.native_place              AS native,
    e.birthplace,
    e.former_name               AS alias,
    e.marital_status            AS marital,
    e.political_status          AS party,
    e.hometown_type             AS domicile_type,
    e.height,
    e.weight,
    e.blood_type,
    e.vision,
    COALESCE(CAST(e.height AS TEXT), '') || 'cm / ' ||
    COALESCE(CAST(e.weight AS TEXT), '') || 'kg / ' ||
    COALESCE(e.vision, '')      AS height_weight_vision,
    e.phone                     AS mobile,
    e.email_personal            AS email,
    e.email_work,
    e.emergency_contact_name    AS emergency,
    e.emergency_contact_relation AS emergency_relation,
    e.emergency_contact_phone   AS emergencyTel,
    e.non_compete_signed,
    e.current_status,

    -- ── 证件信息（对齐 G2 field_key）──────────────────────────
    e.id_card_no                AS idNumber,
    e.id_card_authority,
    e.id_card_issue_date,
    e.id_card_expire_date,

    -- ── 任职信息（对齐 G3 field_key）──────────────────────────
    e.current_company,
    emp.labor_relation_company,
    emp.dept_level1,
    emp.dept_level2,
    emp.dept_level3,
    emp.group_name,
    emp.position_name           AS position1,
    emp.job_family,
    emp.job_class,
    emp.job_level,
    emp.record_type,
    emp.start_date,
    emp.tenure_base_date,
    emp.staff_category_group,
    emp.staff_category_sub,
    emp.staff_category_related,
    emp.contract_expire_date,
    emp.contract_summary_type,
    emp.social_insurance_relation,

    -- ── 最高学历摘要（对齐 G4 field_key，供主表快速预览）────────
    edu.degree_level            AS education,
    edu.degree_type             AS degree,
    edu.degree_status,
    edu.school_name             AS school,
    edu.school_type,
    edu.is_985_211,
    edu.major,
    edu.minor_major,
    edu.research_direction      AS researchDir,
    edu.start_date              AS edu_start_date,      -- v3.0 新增
    edu.graduation_date         AS gradTime,
    edu.study_duration          AS edu_study_duration,  -- v3.0 新增
    edu.diploma_no,
    edu.degree_cert_no,

    -- ── 地址信息（对齐 G6 field_key）──────────────────────────
    COALESCE(addr_hukou.province, '') ||
    COALESCE(addr_hukou.city,     '') ||
    COALESCE(addr_hukou.district, '')
                                AS domicile,
    addr_hukou.address_detail_extra AS domicile_detail,
    addr_hukou.hukou_type       AS domicile_type_hukou,
    addr_hukou.postal_code      AS domicileZip,
    addr_home.address_detail    AS home_addr,
    COALESCE(addr_now.province,  '') ||
    COALESCE(addr_now.city,      '') ||
    COALESCE(addr_now.district,  '') ||
    COALESCE(addr_now.address_detail, '')
                                AS currentAddr,
    addr_now.postal_code        AS currentZip,

    -- ── 离职/退休信息（对齐 G8 field_key）─────────────────────
    sep.separation_date,
    sep.separation_type,
    sep.separation_project,
    sep.separation_reason,
    sep.separation_reason_detail,
    sep.compensation_paid,
    sep.compensation_items,
    sep.compensation_amount,
    sep.non_compete_enforced,
    sep.non_compete_period,
    sep.retirement_type,
    sep.retirement_company,
    sep.retirement_status,
    sep.family_contact_phone

FROM employee e

LEFT JOIN education_record edu
    ON e.id = edu.employee_id AND edu.is_highest = 1

LEFT JOIN employment_record emp
    ON e.id = emp.employee_id AND emp.end_date IS NULL

LEFT JOIN address_record addr_hukou
    ON e.id = addr_hukou.employee_id
    AND addr_hukou.address_type = '户籍地' AND addr_hukou.is_current = 1

LEFT JOIN address_record addr_home
    ON e.id = addr_home.employee_id
    AND addr_home.address_type = '家庭住址' AND addr_home.is_current = 1

LEFT JOIN address_record addr_now
    ON e.id = addr_now.employee_id
    AND addr_now.address_type = '现住址' AND addr_now.is_current = 1

LEFT JOIN separation_record sep
    ON sep.id = (
        SELECT id FROM separation_record
        WHERE employee_id = e.id
        ORDER BY separation_date DESC LIMIT 1
    )
;


-- ============================================================
-- PART C：公共模板（清空后重建，保证幂等）
-- ============================================================

DELETE FROM form_appendix_col;
DELETE FROM form_appendix;
DELETE FROM form_field;
DELETE FROM form_group;
DELETE FROM form_template;

-- ------------------------------------------------------------
-- C1. 主模板
-- ------------------------------------------------------------
INSERT INTO form_template (id, template_name, total_columns)
VALUES (1, '员工个人信息登记表', 24);


-- ------------------------------------------------------------
-- C2. 模块分组
-- ------------------------------------------------------------
INSERT INTO form_group (id, template_id, group_key, group_label, sort_order) VALUES
  (1, 1, 'basic',      '基本信息',      10),
  (2, 1, 'id_card',    '证件信息',      20),
  (3, 1, 'job',        '任职信息',      30),
  (4, 1, 'education',  '学历信息',      40),
  (6, 1, 'address',    '地址信息',      60),
  (7, 1, 'contract',   '合同信息',      70),
  (8, 1, 'separation', '离职/退休信息', 80);
-- ⚠️ id=5（证书资质）和 id=9（跨公司转移信息）已删除：
--    证书资质详情走附表 certificates；跨公司信息走 career.transfer_flag。


-- ------------------------------------------------------------
-- C3. 字段定义
-- ------------------------------------------------------------

-- ── G1 基本信息 ──────────────────────────────────────────────
-- 照片块（右侧 4 列，跨 4 行），左侧 20 列流式布局：
--   行1: 姓名(2+5) | 曾用名(2+3) | 性别(2+3) | 民族(2+弹) | [照片4列]
--   行2: 出生年月(2+5) | 籍贯(2+3) | 出生地(2+3) | 政治面貌(2+弹) | [照片续]
--   行3: 婚姻状况(2+5) | 户籍属性(2+3) | 血型(2+3) | 身高/体重/视力(2+弹) | [照片续]
--   行4: 联系方式(2+5) | 个人邮箱(2+5) | 工作邮箱(2+弹) | [照片续]
--   行5: 紧急联系人(2+4) | 与本人关系(2+3) | 紧急联系电话(2+弹)
--   行6: 竞业限制签署(2+4) | 当前状态(2+弹)
INSERT INTO form_field (group_id, field_key, field_label, lc, vc, min_r, is_photo, sort_order) VALUES
  (1, 'photo',               '照片',           0, 4, 4, 1,  10),
  (1, 'name',                '姓名',           2, 5, 1, 0,  20),
  (1, 'alias',               '曾用名',         2, 3, 1, 0,  30),
  (1, 'gender',              '性别',           2, 3, 1, 0,  40),
  (1, 'ethnicity',           '民族',           2, 0, 1, 0,  50),
  (1, 'birth_date',          '出生年月',       2, 5, 1, 0,  60),
  (1, 'native',              '籍贯',           2, 3, 1, 0,  70),
  (1, 'birthplace',          '出生地',         2, 3, 1, 0,  80),
  (1, 'party',               '政治面貌',       2, 0, 1, 0,  90),
  (1, 'marital',             '婚姻状况',       2, 5, 1, 0, 100),
  (1, 'domicile_type',       '户籍属性',       2, 3, 1, 0, 110),
  (1, 'blood_type',          '血型',           2, 3, 1, 0, 120),
  (1, 'height_weight_vision','身高/体重/视力', 2, 0, 1, 0, 130),
  (1, 'mobile',              '联系方式',       2, 5, 1, 0, 140),
  (1, 'email',               '个人邮箱',       2, 5, 1, 0, 150),
  (1, 'email_work',          '工作邮箱',       2, 0, 1, 0, 160),
  (1, 'emergency',           '紧急联系人',     2, 4, 1, 0, 170),
  (1, 'emergency_relation',  '与本人关系',     2, 3, 1, 0, 180),
  (1, 'emergencyTel',        '紧急联系电话',   2, 0, 1, 0, 190),
  (1, 'non_compete_signed',  '竞业限制签署',   2, 4, 1, 0, 200),
  (1, 'current_status',      '当前状态',       2, 0, 1, 0, 210);

-- ── G2 证件信息 ──────────────────────────────────────────────
--   行1: 身份证号(2+10) | 发证机关(2+弹)
--   行2: 发证日期(2+5)  | 证件到期日(2+弹)
INSERT INTO form_field (group_id, field_key, field_label, lc, vc, min_r, is_photo, sort_order) VALUES
  (2, 'idNumber',            '身份证号',   2, 10, 1, 0, 10),
  (2, 'id_card_authority',   '发证机关',   2,  0, 1, 0, 20),
  (2, 'id_card_issue_date',  '发证日期',   2,  5, 1, 0, 30),
  (2, 'id_card_expire_date', '证件到期日', 2,  0, 1, 0, 40);

-- ── G3 任职信息 ──────────────────────────────────────────────
INSERT INTO form_field (group_id, field_key, field_label, lc, vc, min_r, is_photo, sort_order) VALUES
  (3, 'current_company',          '用工公司',           2, 8, 1, 0,  10),
  (3, 'labor_relation_company',   '劳动关系隶属',       3, 0, 1, 0,  20),
  (3, 'dept_level1',              '一级部门',           2, 4, 1, 0,  30),
  (3, 'dept_level2',              '二级部门',           2, 4, 1, 0,  40),
  (3, 'dept_level3',              '三级部门',           2, 4, 1, 0,  50),
  (3, 'group_name',               '组别',               2, 0, 1, 0,  60),
  (3, 'position1',                '岗位名称',           2, 4, 1, 0,  70),
  (3, 'job_family',               '职族',               2, 4, 1, 0,  80),
  (3, 'job_class',                '职类',               2, 4, 1, 0,  90),
  (3, 'job_level',                '职位层级',           2, 0, 1, 0, 100),
  (3, 'record_type',              '用工形式',           2, 5, 1, 0, 110),
  (3, 'start_date',               '入职时间',           2, 5, 1, 0, 120),
  (3, 'tenure_base_date',         '司龄基准日',         3, 0, 1, 0, 130),
  (3, 'staff_category_group',     '人员类别（总公司）', 3, 3, 1, 0, 140),
  (3, 'staff_category_sub',       '人员类别（二级）',   3, 3, 1, 0, 150),
  (3, 'staff_category_related',   '人员类别（关联公司）',3,0, 1, 0, 160),
  (3, 'contract_expire_date',     '合同到期日期',       2, 5, 1, 0, 170),
  (3, 'contract_summary_type',    '合同类型',           2, 5, 1, 0, 180),
  (3, 'social_insurance_relation','社保关系',           2, 0, 1, 0, 190),
  (3, 'non_compete_signed',       '竞业限制签署',       2, 0, 1, 0, 200);

-- ── G4 学历信息（最高学历摘要，供主表快速预览）────────────────
--   详细多条学历记录走附表 education（appendix_key = 'education'）
--   行1: 学历(2+4) | 学历学位状态(3+4) | 学位(2+弹)
--   行2: 毕业院校(2+5) | 院校属性(2+4) | 是否985/211(3+弹)
--   行3: 专业(2+5) | 辅修专业(2+5) | 研究方向(2+弹)
--   行4: 入学时间(2+4) | 毕业时间(2+4) | 学制(2+弹)         ← v3.0 新增入学/学制
--   行5: 毕业证书编号(3+5) | 学位证书编号(3+弹)
INSERT INTO form_field (group_id, field_key, field_label, lc, vc, min_r, is_photo, sort_order) VALUES
  (4, 'education',       '学历',         2, 4, 1, 0,  10),
  (4, 'degree_status',   '学历学位状态', 3, 4, 1, 0,  20),
  (4, 'degree',          '学位',         2, 0, 1, 0,  30),
  (4, 'school',          '毕业院校',     2, 5, 1, 0,  40),
  (4, 'school_type',     '院校属性',     2, 4, 1, 0,  50),
  (4, 'is_985_211',      '是否985/211',  3, 0, 1, 0,  60),
  (4, 'major',           '专业',         2, 5, 1, 0,  70),
  (4, 'minor_major',     '辅修专业',     2, 5, 1, 0,  80),
  (4, 'researchDir',     '研究方向',     2, 0, 1, 0,  90),
  (4, 'edu_start_date',  '入学时间',     2, 4, 1, 0, 100),
  (4, 'gradTime',        '毕业时间',     2, 4, 1, 0, 110),
  (4, 'edu_study_duration','学制（年）', 2, 0, 1, 0, 120),
  (4, 'diploma_no',      '毕业证书编号', 3, 5, 1, 0, 130),
  (4, 'degree_cert_no',  '学位证书编号', 3, 0, 1, 0, 140);

-- ── G6 地址信息 ──────────────────────────────────────────────
INSERT INTO form_field (group_id, field_key, field_label, lc, vc, min_r, is_photo, sort_order) VALUES
  (6, 'domicile',        '户籍地',         2, 0, 1, 0, 10),
  (6, 'domicile_detail', '户口所在地详情', 3, 0, 1, 0, 20),
  (6, 'home_addr',       '家庭住址',       2, 0, 1, 0, 30),
  (6, 'currentAddr',     '现住址',         2, 0, 1, 0, 40);

-- ── G7 合同信息（竞业限制跟进，明细走附表 contracts）───────────
INSERT INTO form_field (group_id, field_key, field_label, lc, vc, min_r, is_photo, sort_order) VALUES
  (7, 'non_compete_enforced', '是否执行竞业限制', 3, 4, 1, 0, 10),
  (7, 'non_compete_period',   '竞业限制期间',     3, 0, 1, 0, 20);

-- ── G8 离职/退休信息 ─────────────────────────────────────────
INSERT INTO form_field (group_id, field_key, field_label, lc, vc, min_r, is_photo, sort_order) VALUES
  (8, 'separation_date',          '离职/退休日期',  2, 5, 1, 0,  10),
  (8, 'separation_type',          '离/退类型',      2, 5, 1, 0,  20),
  (8, 'separation_project',       '离职项目',       2, 0, 1, 0,  30),
  (8, 'separation_reason',        '离职原因',       2, 5, 1, 0,  40),
  (8, 'separation_reason_detail', '离职原因明细',   3, 0, 1, 0,  50),
  (8, 'compensation_paid',        '是否支付补偿金', 3, 3, 1, 0,  60),
  (8, 'compensation_items',       '支付项目',       2, 4, 1, 0,  70),
  (8, 'compensation_amount',      '补偿金金额(元)', 3, 0, 1, 0,  80),
  (8, 'retirement_type',          '退休类型',       2, 5, 1, 0,  90),
  (8, 'retirement_company',       '退休时公司',     3, 0, 1, 0, 100),
  (8, 'retirement_status',        '存续情况',       2, 5, 1, 0, 110),
  (8, 'family_contact_phone',     '家属联系方式',   3, 0, 1, 0, 120);



-- ------------------------------------------------------------
-- C4. 附表定义
--     appendix_key 须与后端 appendixData 的 key 完全一致
-- ------------------------------------------------------------
INSERT INTO form_appendix (id, template_id, appendix_key, title, sort_order) VALUES
  (1, 1, 'contracts',    '劳动合同签订记录',   10),
  (2, 1, 'work_history', '入职前工作经历',     20),
  (3, 1, 'family',       '家庭成员情况',       30),
  (4, 1, 'education',    '教育经历',           40),   -- v3.0 新增
  (5, 1, 'certificates', '职称/职业资格',      50),   -- v3.0 新增（合并 G5）
  (6, 1, 'training',     '培训记录',           60),
  (7, 1, 'rewards',      '奖惩记录',           70),
  (8, 1, 'career',       '职业生涯时间线',     80);


-- ------------------------------------------------------------
-- C5. 附表列定义
--     ⚠️ field_key 须与后端 SELECT 查询返回的字段名完全一致
--     每张附表 colspan 之和 = 24
-- ------------------------------------------------------------

-- 附表1：劳动合同签订记录  2+4+4+4+10 = 24
INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
  (1, 'seq',           '签订次数', 2,  10),
  (1, 'contract_type', '合同类型', 4,  20),
  (1, 'start_date',    '起始日期', 4,  30),
  (1, 'end_date',      '到期日期', 4,  40),
  (1, 'remark',        '备注',    10,  50);

-- 附表2：入职前工作经历  7+5+3+3+4+2 = 24
INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
  (2, 'company_name',     '工作单位', 7, 10),
  (2, 'position',         '职务',     5, 20),
  (2, 'start_date',       '开始时间', 3, 30),
  (2, 'end_date',         '结束时间', 3, 40),
  (2, 'leave_reason',     '离职原因', 4, 50),
  (2, 'reference_person', '证明人',   2, 60);

-- 附表3：家庭成员情况  3+4+3+3+2+5+2+2 = 24
INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
  (3, 'relation',         '称谓',     3, 10),
  (3, 'real_name',        '姓名',     4, 20),
  (3, 'birth_date',       '出生年月', 3, 30),
  (3, 'political_status', '政治面貌', 3, 40),
  (3, 'education_level',  '学历',     2, 50),
  (3, 'work_unit',        '工作单位', 5, 60),
  (3, 'position',         '职务',     2, 70),
  (3, 'phone',            '联系方式', 2, 80);

-- 附表4：教育经历（v3.0 新增）
-- 对应图2"教育经历"表格
-- 列：院校名称(5) | 院校等级(3) | 专业(4) | 学历(2) | 学位(2) | 学习方式(2) | 学制(2) | 入学时间(2) | 毕业时间(2) | 是否最高学历(0→弹) = 5+3+4+2+2+2+2+2+2 = 24
-- ⚠️ field_key 与后端 SELECT 查询 education_record 返回的字段名对应
INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
  (4, 'school_name',     '院校名称',     5, 10),
  (4, 'school_type',     '院校等级',     3, 20),
  (4, 'major',           '专业',         4, 30),
  (4, 'degree_level',    '学历',         2, 40),
  (4, 'degree_type',     '学位',         2, 50),
  (4, 'degree_status',   '学习方式',     2, 60),
  (4, 'study_duration',  '学制（年）',   2, 70),
  (4, 'start_date',      '入学时间',     2, 80),
  (4, 'graduation_date', '毕业时间',     2, 90);
-- is_highest 单独占最后列凑满24：5+3+4+2+2+2+2+2+2 = 24 已满，不再加列
-- 如需展示"是否最高学历"可临时调整 colspan，这里保持24精确。

-- 附表5：职称/职业资格（v3.0 新增，对应图2"职称/职业资格"表格）
-- 列：资质类别(4) | 资质名称(7) | 所属专业(6) | 资质等级(4) | 取证时间(3) = 24
-- ⚠️ field_key 与后端 SELECT 查询 certificate_record 返回的字段名对应
INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
  (5, 'cert_category', '资质类别', 4, 10),
  (5, 'cert_name',     '资质名称', 7, 20),
  (5, 'cert_major',    '所属专业', 6, 30),
  (5, 'cert_level',    '资质等级', 4, 40),
  (5, 'issue_date',    '取证时间', 3, 50);

-- 附表6：培训记录  6+3+4+3+3+3+2 = 24
INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
  (6, 'training_name', '培训项目', 6, 10),
  (6, 'training_type', '类型',     3, 20),
  (6, 'training_org',  '培训机构', 4, 30),
  (6, 'start_date',    '开始日期', 3, 40),
  (6, 'end_date',      '结束日期', 3, 50),
  (6, 'result',        '培训结果', 3, 60),
  (6, 'cost',          '费用(元)', 2, 70);

-- 附表7：奖惩记录  2+3+5+8+3+3 = 24
INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
  (7, 'record_type', '类型',     2, 10),
  (7, 'record_date', '日期',     3, 20),
  (7, 'category',    '类别',     5, 30),
  (7, 'reason',      '原因',     8, 40),
  (7, 'amount',      '金额(元)', 3, 50),
  (7, 'issuer',      '发起单位', 3, 60);

-- 附表8：职业生涯时间线（v3.0 扩展，新增职类/职级/跨公司标记）
-- 对应图1"入职公司后岗位及薪酬职级职类变动情况"
-- 列：时期(4) | 用工公司(4) | 部门(3) | 岗位(3) | 职类(3) | 职级(3) | 用工形式(2) | 变动原因/标记(2) = 4+4+3+3+3+3+2+2 = 24
-- transfer_flag 字段：'跨公司转入' / '跨公司转出' / NULL（普通在岗）
INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
  (8, 'period',         '时期',     4, 10),
  (8, 'company',        '用工公司', 4, 20),
  (8, 'dept',           '部门',     3, 30),
  (8, 'position',       '岗位',     3, 40),
  (8, 'job_class',      '职类',     3, 50),   -- v3.0 新增
  (8, 'job_level',      '职级',     3, 60),   -- v3.0 新增
  (8, 'record_type',    '用工形式', 2, 70),
  (8, 'transfer_flag',  '变动类型', 2, 80);   -- v3.0 新增，区分跨公司/在岗/晋升


-- ============================================================
-- PART D：员工样例数据（张伟）
-- 以身份证号作为定位锚点，子查询引用外键，可重复执行
-- ============================================================

-- ------------------------------------------------------------
-- D1. 员工主表
-- ------------------------------------------------------------
INSERT INTO employee (
    real_name, id_card_no, gender, birth_date, ethnicity, political_status,
    hometown_type, marital_status, native_place, birthplace, former_name,
    height, weight, blood_type, vision,
    id_card_authority, id_card_issue_date, id_card_expire_date,
    current_status, current_company, current_dept, current_position,
    phone, email_personal, email_work,
    emergency_contact_name, emergency_contact_relation, emergency_contact_phone,
    non_compete_signed, photo_path, remark
) VALUES (
    '张伟', '530102198805151234', '男', '1988-05', '汉族', '中共党员',
    '城镇', '已婚', '云南省昆明市', '云南省昆明市', NULL,
    175.0, 70.0, 'A', '5.0/5.0',
    '昆明市公安局五华分局', '2010-06-01', '2030-06-01',
    '在职', '昆明鼎承科技有限公司', '技术部 > 研发中心 > 后端组', '高级Java工程师',
    '13888888888', 'zhangwei@gmail.com', 'zhangwei@dingcheng.com',
    '张母', '母子', '13777777777',
    '是', NULL, NULL
);

-- ------------------------------------------------------------
-- D2. 任职记录（两段：劳务派遣 → 正式员工）
-- ------------------------------------------------------------
-- 第一段：劳务派遣（2012-03 ~ 2014-06）
INSERT INTO employment_record (
    employee_id, record_type, company, labor_relation_company,
    dept_level1, dept_level2, dept_level3, group_name,
    position_name, job_family, job_class, job_level,
    staff_category_group, staff_category_sub, staff_category_related,
    start_date, end_date, tenure_base_date, pre_work_years,
    end_reason, contract_summary_type, contract_expire_date, social_insurance_relation
) VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    '劳务派遣', '关联公司A（劳务输出）', '昆明鼎承科技有限公司',
    '技术部', '基础平台组', NULL, '派遣一组',
    'Java开发工程师', '技术', '软件开发类', '初级工程师',
    '派遣人员', '技术类', '关联公司A',
    '2012-03-01', '2014-06-30', '2012-03-01', 1.5,
    '跨公司调动', '劳务协议', '2014-06-30', '关联公司A'
);

-- 第二段：正式员工（2014-07 ~ 至今）
INSERT INTO employment_record (
    employee_id, record_type, company, labor_relation_company,
    dept_level1, dept_level2, dept_level3, group_name,
    position_name, job_family, job_class, job_level,
    start_date, end_date, tenure_base_date, pre_work_years,
    end_reason, transfer_from_record_id,
    contract_summary_type, contract_expire_date, social_insurance_relation
) VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    '正式员工', '昆明鼎承科技有限公司', '昆明鼎承科技有限公司',
    '技术部', '研发中心', '后端组', NULL,
    '高级Java工程师', '技术', '软件开发类', '高级工程师',
    '2014-07-01', NULL, '2012-03-01', 1.5,
    NULL,
    (SELECT id FROM employment_record
     WHERE employee_id = (SELECT id FROM employee WHERE id_card_no = '530102198805151234')
       AND start_date = '2012-03-01'),
    '固定期限', '2026-12-31', '昆明鼎承科技有限公司'
);

-- ------------------------------------------------------------
-- D3. 合同签订记录（4次）
-- ------------------------------------------------------------
-- 第一段：劳务派遣合同（1次）
INSERT INTO contract_record (employment_record_id, employee_id, seq, contract_type, start_date, end_date)
VALUES (
    (SELECT id FROM employment_record
     WHERE employee_id = (SELECT id FROM employee WHERE id_card_no = '530102198805151234')
       AND start_date = '2012-03-01'),
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    1, '劳务协议', '2012-03-01', '2014-06-30'
);

-- 第二段：固定期限合同（3次续签）
INSERT INTO contract_record (employment_record_id, employee_id, seq, contract_type, start_date, end_date)
VALUES (
    (SELECT id FROM employment_record
     WHERE employee_id = (SELECT id FROM employee WHERE id_card_no = '530102198805151234')
       AND start_date = '2014-07-01'),
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    1, '固定期限', '2014-07-01', '2016-12-31'
);

INSERT INTO contract_record (employment_record_id, employee_id, seq, contract_type, start_date, end_date)
VALUES (
    (SELECT id FROM employment_record
     WHERE employee_id = (SELECT id FROM employee WHERE id_card_no = '530102198805151234')
       AND start_date = '2014-07-01'),
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    2, '固定期限', '2017-01-01', '2020-12-31'
);

INSERT INTO contract_record (employment_record_id, employee_id, seq, contract_type, start_date, end_date)
VALUES (
    (SELECT id FROM employment_record
     WHERE employee_id = (SELECT id FROM employee WHERE id_card_no = '530102198805151234')
       AND start_date = '2014-07-01'),
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    3, '固定期限', '2021-01-01', '2026-12-31'
);

-- ------------------------------------------------------------
-- D4. 教育经历（多条，含入学时间、学制）
-- 对应图2"教育经历"：哈尔滨工程技术学院、云南财贸学院
-- ------------------------------------------------------------

-- 记录1：哈尔滨工程技术学院（机械设计及其自动化，未填学历学位，非最高学历）
INSERT INTO education_record (
    employee_id, is_highest,
    degree_level, degree_type, degree_status,
    school_name, school_type, is_985_211,
    major, minor_major, research_direction,
    start_date, graduation_date, study_duration,
    diploma_no, degree_cert_no
) VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    0,
    NULL, NULL, NULL,
    '哈尔滨工程技术学院', '普通专科', '否',
    '机械设计及其自动化', NULL, NULL,
    NULL, NULL, NULL,
    NULL, NULL
);

-- 记录2：云南财贸学院（商业经济管理，夜大，学制4年，1996-2000，最高学历）
-- 对应图2数据：学习方式=夜大，学制=4.0，入学=1996/9/1，毕业=2000/12/1
INSERT INTO education_record (
    employee_id, is_highest,
    degree_level, degree_type, degree_status,
    school_name, school_type, is_985_211,
    major, minor_major, research_direction,
    start_date, graduation_date, study_duration,
    diploma_no, degree_cert_no
) VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    0,
    NULL, NULL, '夜大',
    '云南财贸学院', NULL, '否',
    '商业经济管理', NULL, NULL,
    '1996-09-01', '2000-12-01', 4.0,
    NULL, NULL
);

-- 记录3：云南大学（软件工程，统招全日制，is_highest=1）
INSERT INTO education_record (
    employee_id, is_highest,
    degree_level, degree_type, degree_status,
    school_name, school_type, is_985_211,
    major, minor_major, research_direction,
    start_date, graduation_date, study_duration,
    diploma_no, degree_cert_no
) VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    1,
    '本科', '学士', '统招全日制',
    '云南大学', '普通本科', '否',
    '软件工程', NULL, NULL,
    '2006-09-01', '2010-06-30', 4.0,
    'YD20100615001', 'XW20100615001'
);

-- ------------------------------------------------------------
-- D5. 证书资质（职称 + 职业资格 + 职业技能）
-- 对应图2"职称/职业资格"：工程师(电气工程)、助理工程师(机械工程)、人力资源师
-- ------------------------------------------------------------

-- 职称1：工程师（电气工程）
INSERT INTO certificate_record (
    employee_id, cert_category, cert_class, cert_major,
    cert_level, cert_level_detail, cert_no, cert_name,
    issue_date, expire_date, issue_authority
) VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    '职称', NULL, '电气工程',
    '中级', '工程师', 'ZC2018EE001', '工程师',
    '2018-09-01', '9999-12-31', '云南省人力资源和社会保障厅'
);

-- 职称2：助理工程师（机械工程）
INSERT INTO certificate_record (
    employee_id, cert_category, cert_class, cert_major,
    cert_level, cert_level_detail, cert_no, cert_name,
    issue_date, expire_date, issue_authority
) VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    '职称', NULL, '机械工程',
    '初级', '助理工程师', 'ZC2010ME001', '助理工程师',
    '2010-12-01', '9999-12-31', '云南省人力资源和社会保障厅'
);

-- 职业资格：软件设计师
INSERT INTO certificate_record (
    employee_id, cert_category, cert_class, cert_major,
    cert_level, cert_level_detail, cert_no, cert_name,
    issue_date, expire_date, issue_authority
) VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    '职业资格', '计算机技术', '软件设计',
    '中级', NULL, 'RUANKAO2017001', '软件设计师',
    '2017-05-01', '9999-12-31', '工业和信息化部'
);

-- 职业资格：人力资源师（对应图2数据）
INSERT INTO certificate_record (
    employee_id, cert_category, cert_class, cert_major,
    cert_level, cert_level_detail, cert_no, cert_name,
    issue_date, expire_date, issue_authority
) VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    '职业资格', '人力资源管理', '人力资源管理',
    '三级', NULL, 'HR2015001', '人力资源师',
    '2015-08-01', '9999-12-31', '人力资源和社会保障部'
);

-- ------------------------------------------------------------
-- D6. 地址信息（户籍地 + 家庭住址 + 现住址）
-- ------------------------------------------------------------
INSERT INTO address_record (
    employee_id, address_type, province, city, district,
    address_detail, address_detail_extra, postal_code, hukou_type, is_current
) VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    '户籍地', '云南省', '昆明市', '五华区',
    NULL, '某街道某社区某号', '650031', '城镇', 1
);

INSERT INTO address_record (
    employee_id, address_type, province, city, district,
    address_detail, address_detail_extra, postal_code, hukou_type, is_current
) VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    '家庭住址', '云南省', '昆明市', '盘龙区',
    '某小区某栋某号', NULL, '650224', NULL, 1
);

INSERT INTO address_record (
    employee_id, address_type, province, city, district,
    address_detail, address_detail_extra, postal_code, hukou_type, is_current
) VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    '现住址', '云南省', '昆明市', '官渡区',
    '某公寓某栋某号', NULL, '650200', NULL, 1
);

-- ------------------------------------------------------------
-- D7. 家庭成员
-- ------------------------------------------------------------
INSERT INTO family_member (employee_id, relation, real_name, birth_date, political_status, education_level, work_unit, position, qualification, phone)
VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    '配偶', '李霞', '1990-03', '群众', '本科', '昆明某医院', '护士', NULL, '13666666666'
);

INSERT INTO family_member (employee_id, relation, real_name, birth_date, political_status, education_level, work_unit, position, qualification, phone)
VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    '子女', '张小宝', '2018-07', NULL, NULL, NULL, NULL, NULL, NULL
);

INSERT INTO family_member (employee_id, relation, real_name, birth_date, political_status, education_level, work_unit, position, qualification, phone)
VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    '母亲', '王秀英', '1962-11', '群众', '高中', '已退休', NULL, NULL, '13777777777'
);

-- ------------------------------------------------------------
-- D8. 入职前工作经历
-- ------------------------------------------------------------
INSERT INTO work_experience (employee_id, company_name, position, start_date, end_date, leave_reason, reference_person, reference_phone)
VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    '昆明某网络科技有限公司', 'Java开发实习生', '2010-07', '2011-12', '寻求更好发展', '陈经理', '13500000001'
);

INSERT INTO work_experience (employee_id, company_name, position, start_date, end_date, leave_reason, reference_person, reference_phone)
VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    '云南某软件开发公司', 'Java开发工程师', '2012-01', '2012-02', '加入现公司', '刘总监', '13500000002'
);

-- ------------------------------------------------------------
-- D9. 培训记录
-- ------------------------------------------------------------
INSERT INTO training_record (employee_id, training_name, training_type, training_org, start_date, end_date, training_days, training_content, result, cert_obtained, cost, cost_bearer)
VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    'Spring Cloud微服务架构培训', '外训', '某培训机构', '2019-03-01', '2019-03-05', 5.0,
    'Spring Cloud全家桶实战应用', '通过', NULL, 3000.00, '公司'
);

INSERT INTO training_record (employee_id, training_name, training_type, training_org, start_date, end_date, training_days, training_content, result, cert_obtained, cost, cost_bearer)
VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    '软件设计师备考培训', '外训', '某培训机构', '2017-03-01', '2017-04-30', 20.0,
    '系统架构、数据库、算法', '获证', '软件设计师证书', 5000.00, '公司'
);

-- ------------------------------------------------------------
-- D10. 奖惩记录
-- ------------------------------------------------------------
INSERT INTO reward_punishment_record (employee_id, record_type, record_date, category, reason, amount, issuer, document_no)
VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    '奖励', '2020-12-31', '年度优秀员工', '全年技术攻关贡献突出，带领团队完成核心模块重构', 5000.00, '人力资源部', 'AWARD-2020-012'
);

INSERT INTO reward_punishment_record (employee_id, record_type, record_date, category, reason, amount, issuer, document_no)
VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    '奖励', '2023-12-31', '年度优秀员工', '主导完成国产化适配项目，提前两周交付', 8000.00, '人力资源部', 'AWARD-2023-008'
);

-- ------------------------------------------------------------
-- D11. 跨公司劳动关系转移记录
-- ------------------------------------------------------------
INSERT INTO staff_transfer_record (
    employee_id, from_record_id, to_record_id,
    from_company, to_company, transfer_out_date, transfer_in_date,
    from_position, to_position,
    from_dept_level1, from_dept_level2, from_dept_level3, from_group_name,
    from_staff_category, tenure_base_date, pre_work_years,
    record_type, non_compete_signed,
    contract_expire_date, contract_summary_type, social_insurance_relation,
    transfer_path_desc
) VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    (SELECT id FROM employment_record
     WHERE employee_id = (SELECT id FROM employee WHERE id_card_no = '530102198805151234')
       AND start_date = '2012-03-01'),
    (SELECT id FROM employment_record
     WHERE employee_id = (SELECT id FROM employee WHERE id_card_no = '530102198805151234')
       AND start_date = '2014-07-01'),
    '关联公司A（劳务输出）', '昆明鼎承科技有限公司',
    '2014-06-30', '2014-07-01',
    'Java开发工程师', '高级Java工程师',
    '技术部', '基础平台组', NULL, '派遣一组',
    '派遣人员', '2012-03-01', 1.5,
    '正式员工', '是',
    '2016-12-31', '固定期限', '昆明鼎承科技有限公司',
    '关联公司A→昆明鼎承科技有限公司'
);


-- ============================================================
-- PART E：后端 app.py 查询变更备注（v4.0）
-- ============================================================
-- app.py 中 appendixData 需包含以下 key，对应 SQL 如下：
--
-- ① education（教育经历）
--    education_data = [dict(r) for r in conn.execute("""
--        SELECT school_name, school_type, major, degree_level, degree_type,
--               degree_status, study_duration, start_date, graduation_date
--        FROM education_record WHERE employee_id = ? ORDER BY start_date
--    """, (emp_id,)).fetchall()]
--
-- ② certificates（职称/职业资格，含所有 cert_category）
--    certificates_data = [dict(r) for r in conn.execute("""
--        SELECT cert_category, cert_name, cert_major, cert_level, issue_date
--        FROM certificate_record WHERE employee_id = ?
--        ORDER BY cert_category, issue_date DESC
--    """, (emp_id,)).fetchall()]
--
-- ③ career（职业生涯时间线，含 job_class/job_level/transfer_flag）
--    career_data = [dict(r) for r in conn.execute("""
--        SELECT
--            start_date || ' ~ ' || COALESCE(end_date, '至今') AS period,
--            company,
--            COALESCE(dept_level1, '') ||
--                CASE WHEN dept_level2 IS NOT NULL THEN ' > ' || dept_level2 ELSE '' END ||
--                CASE WHEN dept_level3 IS NOT NULL THEN ' > ' || dept_level3 ELSE '' END AS dept,
--            position_name AS position,
--            job_class,
--            job_level,
--            record_type,
--            COALESCE(end_reason, '在职') AS end_reason,
--            CASE
--                WHEN transfer_from_record_id IS NOT NULL THEN '跨公司转入'
--                WHEN end_reason = '跨公司调动'          THEN '跨公司转出'
--                ELSE NULL
--            END AS transfer_flag
--        FROM employment_record
--        WHERE employee_id = ? ORDER BY start_date
--    """, (emp_id,)).fetchall()]
--
-- ④ app.py 中 appendixData 字典去掉原来的 career key，改为包含：
--    "appendixData": {
--        "contracts":    contracts_data,
--        "work_history": work_exp_data,
--        "family":       family_data,
--        "education":    education_data,     # 新增
--        "certificates": certificates_data,  # 新增（替代原 G5 摘要）
--        "training":     training_data,
--        "rewards":      rewards_data,
--        "career":       career_data,        # 扩展字段
--    }
-- ============================================================
