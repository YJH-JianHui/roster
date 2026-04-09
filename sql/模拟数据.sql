-- ============================================================
-- 员工电子档案 - 表单模板初始化数据
-- 公司：昆明鼎承科技有限公司
-- 版本：2.0
-- 变更记录（相对 v1.0）：
--   1. [vw_employee_profile] 完整重建视图
--      - 补全所有缺失字段（证件/任职/证书/地址详情/离退休/跨公司转移）
--      - 修正列名大小写：domicileType→domicile_type, bloodType→blood_type
--      - 新增合并字段 height_weight_vision
--      - 新增 emergency_relation、email_work、id_card_* 等原视图缺失字段
--      - 删除不存在的 emp.non_compete_signed（该字段仅在 employee 主表）
--      - 地址拆分为户籍地/家庭住址/现住址三路 LEFT JOIN
--      - 证书按 cert_category 分三路 LEFT JOIN，各取最新一条
--   2. [form_field] G3 任职信息
--      - non_compete_signed_job 改为 non_compete_signed（直接读主表字段）
--   3. [form_appendix_col] 附表列 field_key 与后端查询字段名严格对齐
--      - work_history 附表列 field_key 全部使用数据库原始列名，无别名
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
-- PART A：视图重建
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
    -- 合并展示字段（field_key = height_weight_vision）
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

    -- ── 任职信息（对齐 G3 field_key，来自当前任职记录）─────────
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
    -- [v2.0 修正] non_compete_signed 来自 employee 主表，不从 emp 取
    -- non_compete_signed 已在基本信息块输出，此处任职块直接复用同名字段

    -- ── 学历信息（对齐 G4 field_key）──────────────────────────
    edu.degree_level            AS education,
    edu.degree_type             AS degree,
    edu.degree_status,
    edu.school_name             AS school,
    edu.school_type,
    edu.is_985_211,
    edu.major,
    edu.minor_major,
    edu.research_direction      AS researchDir,
    edu.graduation_date         AS gradTime,
    edu.diploma_no,
    edu.degree_cert_no,

    -- ── 证书资质（对齐 G5 field_key）──────────────────────────
    cert_title.cert_major       AS title_major,
    cert_title.cert_level       AS title_level,
    cert_title.cert_no          AS title_cert_no,
    cert_voc.cert_class         AS voc_class,
    cert_voc.cert_major         AS voc_major,
    cert_voc.cert_level         AS voc_level,
    cert_voc.cert_no            AS voc_cert_no,
    cert_skill.cert_name        AS skill_cert,
    cert_skill.cert_level       AS skill_level,

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
    sep.family_contact_phone,

    -- ── 跨公司转移信息（对齐 G9 field_key，取最近一次）─────────
    tr.from_company             AS transfer_from_company,
    tr.to_company               AS transfer_to_company,
    tr.transfer_out_date,
    tr.transfer_in_date,
    tr.transfer_path_desc,
    tr.from_position            AS transfer_from_position,
    tr.to_position              AS transfer_to_position

FROM employee e

-- 最高学历（is_highest = 1）
LEFT JOIN education_record edu
    ON e.id = edu.employee_id AND edu.is_highest = 1

-- 当前任职（end_date IS NULL = 仍在岗）
LEFT JOIN employment_record emp
    ON e.id = emp.employee_id AND emp.end_date IS NULL

-- 职称证书（取最新一条）
LEFT JOIN certificate_record cert_title
    ON cert_title.id = (
        SELECT id FROM certificate_record
        WHERE employee_id = e.id AND cert_category = '职称'
        ORDER BY issue_date DESC LIMIT 1
    )

-- 职业资格证书（取最新一条）
LEFT JOIN certificate_record cert_voc
    ON cert_voc.id = (
        SELECT id FROM certificate_record
        WHERE employee_id = e.id AND cert_category = '职业资格'
        ORDER BY issue_date DESC LIMIT 1
    )

-- 职业技能证书（取最新一条）
LEFT JOIN certificate_record cert_skill
    ON cert_skill.id = (
        SELECT id FROM certificate_record
        WHERE employee_id = e.id AND cert_category = '职业技能'
        ORDER BY issue_date DESC LIMIT 1
    )

-- 户籍地
LEFT JOIN address_record addr_hukou
    ON e.id = addr_hukou.employee_id
    AND addr_hukou.address_type = '户籍地' AND addr_hukou.is_current = 1

-- 家庭住址
LEFT JOIN address_record addr_home
    ON e.id = addr_home.employee_id
    AND addr_home.address_type = '家庭住址' AND addr_home.is_current = 1

-- 现住址
LEFT JOIN address_record addr_now
    ON e.id = addr_now.employee_id
    AND addr_now.address_type = '现住址' AND addr_now.is_current = 1

-- 离退休记录（取最近一条）
LEFT JOIN separation_record sep
    ON sep.id = (
        SELECT id FROM separation_record
        WHERE employee_id = e.id
        ORDER BY separation_date DESC LIMIT 1
    )

-- 跨公司转移（取最近一次）
LEFT JOIN staff_transfer_record tr
    ON tr.id = (
        SELECT id FROM staff_transfer_record
        WHERE employee_id = e.id
        ORDER BY transfer_out_date DESC LIMIT 1
    );


-- ============================================================
-- PART B：公共模板（清空后重建，保证幂等）
-- ============================================================

DELETE FROM form_appendix_col;
DELETE FROM form_appendix;
DELETE FROM form_field;
DELETE FROM form_group;
DELETE FROM form_template;

-- ------------------------------------------------------------
-- B1. 主模板
-- ------------------------------------------------------------
INSERT INTO form_template (id, template_name, total_columns)
VALUES (1, '员工个人信息登记表', 24);


-- ------------------------------------------------------------
-- B2. 模块分组
-- ------------------------------------------------------------
INSERT INTO form_group (id, template_id, group_key, group_label, sort_order) VALUES
  (1, 1, 'basic',       '基本信息',       10),
  (2, 1, 'id_card',     '证件信息',       20),
  (3, 1, 'job',         '任职信息',       30),
  (4, 1, 'education',   '学历信息',       40),
  (5, 1, 'certificate', '证书资质',       50),
  (6, 1, 'address',     '地址信息',       60),
  (7, 1, 'contract',    '合同信息',       70),
  (8, 1, 'separation',  '离职/退休信息',  80),
  (9, 1, 'transfer',    '跨公司转移信息', 90);


-- ------------------------------------------------------------
-- B3. 字段定义
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
--   行1: 用工公司(2+8) | 劳动关系隶属(3+弹)
--   行2: 一级部门(2+4) | 二级部门(2+4) | 三级部门(2+4) | 组别(2+弹)
--   行3: 岗位名称(2+4) | 职族(2+4) | 职类(2+4) | 职位层级(2+弹)
--   行4: 用工形式(2+5) | 入职时间(2+5) | 司龄基准日(3+弹)
--   行5: 人员类别总公司(3+3) | 人员类别二级(3+3) | 人员类别关联(3+弹)  ← 劳务派遣专用，无数据自动跳过
--   行6: 合同到期日期(2+5) | 合同类型(2+5) | 社保关系(2+弹)
-- [v2.0 修正] non_compete_signed_job → non_compete_signed（直接读主表，视图已输出）
INSERT INTO form_field (group_id, field_key, field_label, lc, vc, min_r, is_photo, sort_order) VALUES
  (3, 'current_company',         '用工公司',         2, 8, 1, 0,  10),
  (3, 'labor_relation_company',  '劳动关系隶属',     3, 0, 1, 0,  20),
  (3, 'dept_level1',             '一级部门',         2, 4, 1, 0,  30),
  (3, 'dept_level2',             '二级部门',         2, 4, 1, 0,  40),
  (3, 'dept_level3',             '三级部门',         2, 4, 1, 0,  50),
  (3, 'group_name',              '组别',             2, 0, 1, 0,  60),
  (3, 'position1',               '岗位名称',         2, 4, 1, 0,  70),
  (3, 'job_family',              '职族',             2, 4, 1, 0,  80),
  (3, 'job_class',               '职类',             2, 4, 1, 0,  90),
  (3, 'job_level',               '职位层级',         2, 0, 1, 0, 100),
  (3, 'record_type',             '用工形式',         2, 5, 1, 0, 110),
  (3, 'start_date',              '入职时间',         2, 5, 1, 0, 120),
  (3, 'tenure_base_date',        '司龄基准日',       3, 0, 1, 0, 130),
  (3, 'staff_category_group',    '人员类别（总公司）', 3, 3, 1, 0, 140),
  (3, 'staff_category_sub',      '人员类别（二级）',   3, 3, 1, 0, 150),
  (3, 'staff_category_related',  '人员类别（关联公司）',3,0, 1, 0, 160),
  (3, 'contract_expire_date',    '合同到期日期',     2, 5, 1, 0, 170),
  (3, 'contract_summary_type',   '合同类型',         2, 5, 1, 0, 180),
  (3, 'social_insurance_relation','社保关系',        2, 0, 1, 0, 190),
  (3, 'non_compete_signed',      '竞业限制签署',     2, 0, 1, 0, 200);

-- ── G4 学历信息 ──────────────────────────────────────────────
--   行1: 学历(2+4) | 学历学位状态(3+4) | 学位(2+弹)
--   行2: 毕业院校(2+5) | 院校属性(2+4) | 是否985/211(3+弹)
--   行3: 专业(2+5) | 辅修专业(2+5) | 研究方向(2+弹)
--   行4: 毕业时间(2+5) | 毕业证书编号(3+5) | 学位证书编号(3+弹)
INSERT INTO form_field (group_id, field_key, field_label, lc, vc, min_r, is_photo, sort_order) VALUES
  (4, 'education',      '学历',         2, 4, 1, 0,  10),
  (4, 'degree_status',  '学历学位状态', 3, 4, 1, 0,  20),
  (4, 'degree',         '学位',         2, 0, 1, 0,  30),
  (4, 'school',         '毕业院校',     2, 5, 1, 0,  40),
  (4, 'school_type',    '院校属性',     2, 4, 1, 0,  50),
  (4, 'is_985_211',     '是否985/211',  3, 0, 1, 0,  60),
  (4, 'major',          '专业',         2, 5, 1, 0,  70),
  (4, 'minor_major',    '辅修专业',     2, 5, 1, 0,  80),
  (4, 'researchDir',    '研究方向',     2, 0, 1, 0,  90),
  (4, 'gradTime',       '毕业时间',     2, 5, 1, 0, 100),
  (4, 'diploma_no',     '毕业证书编号', 3, 5, 1, 0, 110),
  (4, 'degree_cert_no', '学位证书编号', 3, 0, 1, 0, 120);

-- ── G5 证书资质 ──────────────────────────────────────────────
--   行1（职称）:     职称专业(2+5) | 职称等级(2+5) | 职称证书编号(3+弹)
--   行2（职业资格）: 职业资格类别(3+4) | 职业资格专业(3+4) | 职业资格等级(3+4) | 证书编号(2+弹)
--   行3（职业技能）: 职业技能证书(2+6) | 职业技能等级(3+弹)
INSERT INTO form_field (group_id, field_key, field_label, lc, vc, min_r, is_photo, sort_order) VALUES
  (5, 'title_major',   '职称专业',       2, 5, 1, 0,  10),
  (5, 'title_level',   '职称等级',       2, 5, 1, 0,  20),
  (5, 'title_cert_no', '职称证书编号',   3, 0, 1, 0,  30),
  (5, 'voc_class',     '职业资格类别',   3, 4, 1, 0,  40),
  (5, 'voc_major',     '职业资格专业',   3, 4, 1, 0,  50),
  (5, 'voc_level',     '职业资格等级',   3, 4, 1, 0,  60),
  (5, 'voc_cert_no',   '职业资格证书编号',2,0, 1, 0,  70),
  (5, 'skill_cert',    '职业技能证书',   2, 6, 1, 0,  80),
  (5, 'skill_level',   '职业技能等级',   3, 0, 1, 0,  90);

-- ── G6 地址信息 ──────────────────────────────────────────────
--   行1: 户籍地(2+弹)
--   行2: 户口所在地详情(3+弹)
--   行3: 家庭住址(2+弹)
--   行4: 现住址(2+弹)
INSERT INTO form_field (group_id, field_key, field_label, lc, vc, min_r, is_photo, sort_order) VALUES
  (6, 'domicile',        '户籍地',         2, 0, 1, 0, 10),
  (6, 'domicile_detail', '户口所在地详情', 3, 0, 1, 0, 20),
  (6, 'home_addr',       '家庭住址',       2, 0, 1, 0, 30),
  (6, 'currentAddr',     '现住址',         2, 0, 1, 0, 40);

-- ── G7 合同信息（明细在附表，此处仅竞业限制跟进）─────────────
INSERT INTO form_field (group_id, field_key, field_label, lc, vc, min_r, is_photo, sort_order) VALUES
  (7, 'non_compete_enforced', '是否执行竞业限制', 3, 4, 1, 0, 10),
  (7, 'non_compete_period',   '竞业限制期间',     3, 0, 1, 0, 20);

-- ── G8 离职/退休信息 ─────────────────────────────────────────
--   行1: 离/退日期(2+5) | 离/退类型(2+5) | 离职项目(2+弹)
--   行2: 离职原因(2+5) | 离职原因明细(3+弹)
--   行3: 是否支付补偿金(3+3) | 支付项目(2+4) | 补偿金金额(3+弹)
--   行4: 退休类型(2+5) | 退休时公司(3+弹)
--   行5: 存续情况(2+5) | 家属联系方式(3+弹)
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

-- ── G9 跨公司转移信息 ────────────────────────────────────────
--   行1: 转移前公司(2+8) | 转移后公司(2+弹)
--   行2: 转出时间(2+5) | 转入日期(2+5) | 转移路径(2+弹)
--   行3: 转出前岗位(2+8) | 转入后岗位(2+弹)
INSERT INTO form_field (group_id, field_key, field_label, lc, vc, min_r, is_photo, sort_order) VALUES
  (9, 'transfer_from_company',  '转移前公司', 2, 8, 1, 0, 10),
  (9, 'transfer_to_company',    '转移后公司', 2, 0, 1, 0, 20),
  (9, 'transfer_out_date',      '转出时间',   2, 5, 1, 0, 30),
  (9, 'transfer_in_date',       '转入日期',   2, 5, 1, 0, 40),
  (9, 'transfer_path_desc',     '转移路径',   2, 0, 1, 0, 50),
  (9, 'transfer_from_position', '转出前岗位', 2, 8, 1, 0, 60),
  (9, 'transfer_to_position',   '转入后岗位', 2, 0, 1, 0, 70);


-- ------------------------------------------------------------
-- B4. 附表定义
--     appendix_key 须与后端 appendixData 的 key 完全一致
-- ------------------------------------------------------------
INSERT INTO form_appendix (id, template_id, appendix_key, title, sort_order) VALUES
  (1, 1, 'contracts',    '劳动合同签订记录', 10),
  (2, 1, 'work_history', '入职前工作经历',   20),
  (3, 1, 'family',       '家庭成员情况',     30),
  (4, 1, 'training',     '培训记录',         40),
  (5, 1, 'rewards',      '奖惩记录',         50),
  (6, 1, 'career',       '职业生涯时间线',   60);


-- ------------------------------------------------------------
-- B5. 附表列定义
--     ⚠️ field_key 须与后端 SELECT 查询返回的字段名完全一致（不能有别名差异）
--     每张附表 colspan 之和 = 24
-- ------------------------------------------------------------

-- 劳动合同签订记录（附表1）  2+4+4+4+10 = 24
INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
  (1, 'seq',           '签订次数', 2,  10),
  (1, 'contract_type', '合同类型', 4,  20),
  (1, 'start_date',    '起始日期', 4,  30),
  (1, 'end_date',      '到期日期', 4,  40),
  (1, 'remark',        '备注',    10,  50);

-- 入职前工作经历（附表2）  7+5+3+3+4+2 = 24
-- [v2.0 确认] field_key 全部使用 work_experience 表原始列名，无别名
INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
  (2, 'company_name',     '工作单位', 7, 10),
  (2, 'position',         '职务',     5, 20),
  (2, 'start_date',       '开始时间', 3, 30),
  (2, 'end_date',         '结束时间', 3, 40),
  (2, 'leave_reason',     '离职原因', 4, 50),
  (2, 'reference_person', '证明人',   2, 60);

-- 家庭成员情况（附表3）  3+4+3+3+2+5+2+2 = 24
-- [v2.0 确认] field_key 全部使用 family_member 表原始列名，无别名
INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
  (3, 'relation',         '称谓',     3, 10),
  (3, 'real_name',        '姓名',     4, 20),
  (3, 'birth_date',       '出生年月', 3, 30),
  (3, 'political_status', '政治面貌', 3, 40),
  (3, 'education_level',  '学历',     2, 50),
  (3, 'work_unit',        '工作单位', 5, 60),
  (3, 'position',         '职务',     2, 70),
  (3, 'phone',            '联系方式', 2, 80);

-- 培训记录（附表4）  6+3+4+3+3+3+2 = 24
-- [v2.0 确认] field_key 使用 training_record 表原始列名
INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
  (4, 'training_name', '培训项目', 6, 10),
  (4, 'training_type', '类型',     3, 20),
  (4, 'training_org',  '培训机构', 4, 30),
  (4, 'start_date',    '开始日期', 3, 40),
  (4, 'end_date',      '结束日期', 3, 50),
  (4, 'result',        '培训结果', 3, 60),
  (4, 'cost',          '费用(元)', 2, 70);

-- 奖惩记录（附表5）  2+3+5+8+3+3 = 24
-- [v2.0 确认] field_key 使用 reward_punishment_record 表原始列名
INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
  (5, 'record_type', '类型',     2, 10),
  (5, 'record_date', '日期',     3, 20),
  (5, 'category',    '类别',     5, 30),
  (5, 'reason',      '原因',     8, 40),
  (5, 'amount',      '金额(元)', 3, 50),
  (5, 'issuer',      '发起单位', 3, 60);

-- 职业生涯时间线（附表6）  4+5+4+4+3+4 = 24
-- [v2.0 确认] field_key 对应后端动态拼接的别名（career_data 查询中的 AS 名称）
INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
  (6, 'period',      '时期',     4, 10),
  (6, 'company',     '用工公司', 5, 20),
  (6, 'dept',        '部门',     4, 30),
  (6, 'position',    '岗位',     4, 40),
  (6, 'record_type', '用工形式', 3, 50),
  (6, 'end_reason',  '变动原因', 4, 60);


-- ============================================================
-- PART C：员工样例数据（以"张伟"为示范）
-- 身份证号作为全局定位锚点，子查询引用外键，可重复执行
-- ============================================================

-- ------------------------------------------------------------
-- C1. 员工主表
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
-- C2. 任职记录（两段：劳务派遣 → 正式员工）
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
    'Java开发工程师', '技术', '软件开发', '初级',
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
    '高级Java工程师', '技术', '软件开发', '高级',
    '2014-07-01', NULL, '2012-03-01', 1.5,
    NULL,
    (SELECT id FROM employment_record
     WHERE employee_id = (SELECT id FROM employee WHERE id_card_no = '530102198805151234')
       AND start_date = '2012-03-01'),
    '固定期限', '2026-12-31', '昆明鼎承科技有限公司'
);

-- ------------------------------------------------------------
-- C3. 合同签订记录（4次）
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
-- C4. 教育经历
-- ------------------------------------------------------------
INSERT INTO education_record (
    employee_id, is_highest,
    degree_level, degree_type, degree_status,
    school_name, school_type, is_985_211,
    major, minor_major, research_direction,
    graduation_date, diploma_no, degree_cert_no
) VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    1,
    '本科', '学士', '统招全日制',
    '云南大学', '普通本科', '否',
    '软件工程', NULL, NULL,
    '2010-06', 'YD20100615001', 'XW20100615001'
);

-- ------------------------------------------------------------
-- C5. 证书资质（职称 + 职业资格）
-- ------------------------------------------------------------
INSERT INTO certificate_record (
    employee_id, cert_category, cert_class, cert_major,
    cert_level, cert_level_detail, cert_no, cert_name,
    issue_date, expire_date, issue_authority
) VALUES (
    (SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
    '职称', NULL, '计算机软件',
    '中级', NULL, 'ZC2018CN001', '工程师（中级）',
    '2018-09-01', '9999-12-31', '云南省人力资源和社会保障厅'
);

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

-- ------------------------------------------------------------
-- C6. 地址信息（户籍地 + 家庭住址 + 现住址）
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
-- C7. 家庭成员
-- ------------------------------------------------------------
INSERT INTO family_member (employee_id, relation, real_name, birth_date, political_status, education_level, work_unit, position, qualification, phone)
VALUES ((SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
        '配偶', '李霞', '1990-03', '群众', '本科', '昆明某医院', '护士', NULL, '13666666666');

INSERT INTO family_member (employee_id, relation, real_name, birth_date, political_status, education_level, work_unit, position, qualification, phone)
VALUES ((SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
        '子女', '张小宝', '2018-07', NULL, NULL, NULL, NULL, NULL, NULL);

INSERT INTO family_member (employee_id, relation, real_name, birth_date, political_status, education_level, work_unit, position, qualification, phone)
VALUES ((SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
        '母亲', '王秀英', '1962-11', '群众', '高中', '已退休', NULL, NULL, '13777777777');

-- ------------------------------------------------------------
-- C8. 入职前工作经历
-- ------------------------------------------------------------
INSERT INTO work_experience (employee_id, company_name, position, start_date, end_date, leave_reason, reference_person, reference_phone)
VALUES ((SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
        '昆明某网络科技有限公司', 'Java开发实习生', '2010-07', '2011-12', '寻求更好发展', '陈经理', '13500000001');

INSERT INTO work_experience (employee_id, company_name, position, start_date, end_date, leave_reason, reference_person, reference_phone)
VALUES ((SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
        '云南某软件开发公司', 'Java开发工程师', '2012-01', '2012-02', '加入现公司', '刘总监', '13500000002');

-- ------------------------------------------------------------
-- C9. 培训记录
-- ------------------------------------------------------------
INSERT INTO training_record (employee_id, training_name, training_type, training_org, start_date, end_date, training_days, training_content, result, cert_obtained, cost, cost_bearer)
VALUES ((SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
        'Spring Cloud微服务架构培训', '外训', '某培训机构', '2019-03-01', '2019-03-05', 5.0,
        'Spring Cloud全家桶实战应用', '通过', NULL, 3000.00, '公司');

INSERT INTO training_record (employee_id, training_name, training_type, training_org, start_date, end_date, training_days, training_content, result, cert_obtained, cost, cost_bearer)
VALUES ((SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
        '软件设计师备考培训', '外训', '某培训机构', '2017-03-01', '2017-04-30', 20.0,
        '系统架构、数据库、算法', '获证', '软件设计师证书', 5000.00, '公司');

-- ------------------------------------------------------------
-- C10. 奖惩记录
-- ------------------------------------------------------------
INSERT INTO reward_punishment_record (employee_id, record_type, record_date, category, reason, amount, issuer, document_no)
VALUES ((SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
        '奖励', '2020-12-31', '年度优秀员工', '全年技术攻关贡献突出，带领团队完成核心模块重构', 5000.00, '人力资源部', 'AWARD-2020-012');

INSERT INTO reward_punishment_record (employee_id, record_type, record_date, category, reason, amount, issuer, document_no)
VALUES ((SELECT id FROM employee WHERE id_card_no = '530102198805151234'),
        '奖励', '2023-12-31', '年度优秀员工', '主导完成国产化适配项目，提前两周交付', 8000.00, '人力资源部', 'AWARD-2023-008');

-- ------------------------------------------------------------
-- C11. 跨公司劳动关系转移记录
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
