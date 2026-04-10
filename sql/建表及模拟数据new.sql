PRAGMA foreign_keys = false;

-- ============================================================
-- 1. 清理
-- ============================================================
DROP VIEW IF EXISTS vw_employee_profile;
DROP TABLE IF EXISTS feishu_user_map;
DROP TABLE IF EXISTS form_appendix_col;
DROP TABLE IF EXISTS form_appendix;
DROP TABLE IF EXISTS form_field;
DROP TABLE IF EXISTS form_group;
DROP TABLE IF EXISTS form_template;
DROP TABLE IF EXISTS contract_record;
DROP TABLE IF EXISTS work_experience;
DROP TABLE IF EXISTS family_member;
DROP TABLE IF EXISTS education_record;
DROP TABLE IF EXISTS certificate_record;
DROP TABLE IF EXISTS training_record;
DROP TABLE IF EXISTS reward_punishment_record;
DROP TABLE IF EXISTS salary_change_record;
DROP TABLE IF EXISTS employment_record;
DROP TABLE IF EXISTS address_record;
DROP TABLE IF EXISTS employee;

-- ============================================================
-- 2. 业务表
-- ============================================================

-- 员工主表：以身份证号为主键
CREATE TABLE "employee" (
  "id_card_no"               TEXT PRIMARY KEY NOT NULL,
  "real_name"                TEXT NOT NULL,
  "gender"                   TEXT NOT NULL,
  "birth_date"               TEXT,
  "ethnicity"                TEXT,
  "political_status"         TEXT,
  "hometown_type"            TEXT,
  "marital_status"           TEXT,
  "native_place"             TEXT,
  "birthplace"               TEXT,
  "former_name"              TEXT,
  "height"                   REAL,
  "weight"                   REAL,
  "blood_type"               TEXT,
  "id_card_authority"        TEXT,
  "id_card_issue_date"       TEXT,
  "id_card_expire_date"      TEXT,
  "current_status"           TEXT NOT NULL DEFAULT '在职',
  "phone"                    TEXT,
  "email_personal"           TEXT,
  "email_work"               TEXT,
  "emergency_contact_name"   TEXT,
  "emergency_contact_relation" TEXT,
  "emergency_contact_phone"  TEXT,
  "photo_path"               TEXT
);

-- 任职记录：保留自增 id 供合同记录引用
CREATE TABLE "employment_record" (
  "id"                       INTEGER PRIMARY KEY AUTOINCREMENT,
  "id_card_no"               TEXT NOT NULL,
  "record_type"              TEXT NOT NULL,
  "company"                  TEXT NOT NULL,
  "labor_relation_company"   TEXT,
  "dept_level1"              TEXT,
  "dept_level2"              TEXT,
  "dept_level3"              TEXT,
  "group_name"               TEXT,
  "position_name"            TEXT,
  "job_class"                TEXT,
  "job_level"                TEXT,
  "job_level_class"          TEXT,
  "salary_amount"            REAL,
  "change_reason"            TEXT,
  "start_date"               TEXT NOT NULL,
  "end_date"                 TEXT,
  "tenure_base_date"         TEXT,
  "pre_work_years"           REAL DEFAULT 0,
  "end_reason"               TEXT,
  "transfer_from_record_id"  INTEGER,
  "contract_summary_type"    TEXT,
  "contract_expire_date"     TEXT,
  "social_insurance_relation" TEXT,
  "non_compete_signed"       TEXT DEFAULT '否',
  "non_compete_period"       TEXT,
  FOREIGN KEY ("id_card_no") REFERENCES "employee" ("id_card_no") ON DELETE CASCADE,
  FOREIGN KEY ("transfer_from_record_id") REFERENCES "employment_record" ("id") ON DELETE SET NULL,
  UNIQUE ("id_card_no", "start_date")
);

-- 地址信息：联合主键
CREATE TABLE "address_record" (
  "id_card_no"               TEXT NOT NULL,
  "address_type"             TEXT NOT NULL,
  "province"                 TEXT,
  "city"                     TEXT,
  "district"                 TEXT,
  "address_detail"           TEXT,
  "address_detail_extra"     TEXT,
  "postal_code"              TEXT,
  "hukou_type"               TEXT,
  "is_current"               INTEGER NOT NULL DEFAULT 1,
  PRIMARY KEY ("id_card_no", "address_type"),
  FOREIGN KEY ("id_card_no") REFERENCES "employee" ("id_card_no") ON DELETE CASCADE
);

-- 教育经历：联合主键
CREATE TABLE "education_record" (
  "id_card_no"               TEXT NOT NULL,
  "school_name"              TEXT NOT NULL,
  "start_date"               TEXT NOT NULL,
  "is_highest"               INTEGER NOT NULL DEFAULT 0,
  "degree_level"             TEXT,
  "degree_type"              TEXT,
  "degree_status"            TEXT,
  "school_type"              TEXT,
  "is_985_211"               TEXT DEFAULT '否',
  "major"                    TEXT,
  "minor_major"              TEXT,
  "research_direction"       TEXT,
  "study_duration"           REAL,
  "graduation_date"          TEXT,
  "diploma_no"               TEXT,
  "degree_cert_no"           TEXT,
  PRIMARY KEY ("id_card_no", "school_name", "start_date"),
  FOREIGN KEY ("id_card_no") REFERENCES "employee" ("id_card_no") ON DELETE CASCADE
);

-- 合同记录：联合主键（保留 employment_record_id 引用任职段）
CREATE TABLE "contract_record" (
  "id_card_no"               TEXT NOT NULL,
  "seq"                      INTEGER NOT NULL,
  "start_date"               TEXT NOT NULL,
  "employment_record_id"     INTEGER,
  "contract_type"            TEXT,
  "end_date"                 TEXT,
  "remark"                   TEXT,
  PRIMARY KEY ("id_card_no", "seq", "start_date"),
  FOREIGN KEY ("id_card_no") REFERENCES "employee" ("id_card_no") ON DELETE CASCADE,
  FOREIGN KEY ("employment_record_id") REFERENCES "employment_record" ("id") ON DELETE SET NULL
);

-- 家庭成员：联合主键
CREATE TABLE "family_member" (
  "id_card_no"               TEXT NOT NULL,
  "relation"                 TEXT NOT NULL,
  "real_name"                TEXT NOT NULL,
  "birth_date"               TEXT,
  "political_status"         TEXT,
  "education_level"          TEXT,
  "work_unit"                TEXT,
  "position"                 TEXT,
  "phone"                    TEXT,
  PRIMARY KEY ("id_card_no", "relation", "real_name"),
  FOREIGN KEY ("id_card_no") REFERENCES "employee" ("id_card_no") ON DELETE CASCADE
);

-- 职称资质：联合主键
CREATE TABLE "certificate_record" (
  "id_card_no"               TEXT NOT NULL,
  "cert_name"                TEXT NOT NULL,
  "cert_category"            TEXT NOT NULL,
  "issue_date"               TEXT,  -- 允许为空
  "cert_major"               TEXT,
  "cert_level"               TEXT,
  "cert_no"                  TEXT,
  "expire_date"              TEXT,  -- 允许为空
  PRIMARY KEY ("id_card_no", "cert_name", "cert_category"),
  FOREIGN KEY ("id_card_no") REFERENCES "employee" ("id_card_no") ON DELETE CASCADE
);

-- 培训记录：联合主键
CREATE TABLE "training_record" (
  "id_card_no"               TEXT NOT NULL,
  "training_name"            TEXT NOT NULL,
  "start_date"               TEXT NOT NULL,
  "training_type"            TEXT,
  "training_org"             TEXT,
  "end_date"                 TEXT,
  "result"                   TEXT,
  "cert_obtained"            TEXT,
  PRIMARY KEY ("id_card_no", "training_name", "start_date"),
  FOREIGN KEY ("id_card_no") REFERENCES "employee" ("id_card_no") ON DELETE CASCADE
);

-- 奖惩记录：联合主键
CREATE TABLE "reward_punishment_record" (
  "id_card_no"               TEXT NOT NULL,
  "record_date"              TEXT NOT NULL,
  "record_type"              TEXT NOT NULL,
  "category"                 TEXT,
  "reason"                   TEXT,
  "issuer"                   TEXT,
  PRIMARY KEY ("id_card_no", "record_date", "record_type"),
  FOREIGN KEY ("id_card_no") REFERENCES "employee" ("id_card_no") ON DELETE CASCADE
);

-- 入职前工作经历：联合主键
CREATE TABLE "work_experience" (
  "id_card_no"               TEXT NOT NULL,
  "company_name"             TEXT NOT NULL,
  "start_date"               TEXT NOT NULL,
  "industry"                 TEXT,
  "company_type"             TEXT,
  "position"                 TEXT,
  "end_date"                 TEXT,
  "leave_reason"             TEXT,
  "reference_person"         TEXT,
  "reference_phone"          TEXT,
  PRIMARY KEY ("id_card_no", "company_name", "start_date"),
  FOREIGN KEY ("id_card_no") REFERENCES "employee" ("id_card_no") ON DELETE CASCADE
);

-- 薪酬调整记录：联合主键
CREATE TABLE "salary_change_record" (
  "id_card_no"               TEXT NOT NULL,
  "period"                   TEXT NOT NULL,
  "company"                  TEXT NOT NULL,
  "dept"                     TEXT,
  "position"                 TEXT,
  "job_level"                TEXT,
  "job_class"                TEXT,
  "job_level_class"          TEXT,
  "change_reason"            TEXT,
  PRIMARY KEY ("id_card_no", "period"),
  FOREIGN KEY ("id_card_no") REFERENCES "employee" ("id_card_no") ON DELETE CASCADE
);

-- 飞书账号映射：三字段，身份证号为主键
CREATE TABLE "feishu_user_map" (
  "id_card_no"               TEXT PRIMARY KEY NOT NULL,
  "feishu_user_id"           TEXT NOT NULL UNIQUE,
  "real_name"                TEXT,
  FOREIGN KEY ("id_card_no") REFERENCES "employee" ("id_card_no") ON DELETE CASCADE
);

-- ============================================================
-- 3. 表单配置表（结构不变）
-- ============================================================
CREATE TABLE "form_template" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "template_name" TEXT NOT NULL,
  "total_columns" INTEGER NOT NULL DEFAULT 24
);

CREATE TABLE "form_group" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "template_id" INTEGER NOT NULL,
  "group_key" TEXT NOT NULL,
  "group_label" TEXT NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY ("template_id") REFERENCES "form_template" ("id") ON DELETE CASCADE
);

CREATE TABLE "form_field" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "group_id" INTEGER NOT NULL,
  "field_key" TEXT NOT NULL,
  "field_label" TEXT NOT NULL,
  "lc" INTEGER DEFAULT 2,
  "vc" INTEGER,
  "min_r" INTEGER DEFAULT 1,
  "is_photo" INTEGER DEFAULT 0,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY ("group_id") REFERENCES "form_group" ("id") ON DELETE CASCADE
);

CREATE TABLE "form_appendix" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "template_id" INTEGER NOT NULL,
  "appendix_key" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY ("template_id") REFERENCES "form_template" ("id") ON DELETE CASCADE
);

CREATE TABLE "form_appendix_col" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "appendix_id" INTEGER NOT NULL,
  "field_key" TEXT NOT NULL,
  "label" TEXT NOT NULL,
  "colspan" INTEGER NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY ("appendix_id") REFERENCES "form_appendix" ("id") ON DELETE CASCADE
);

-- ============================================================
-- 4. 视图（用 id_card_no 关联，去掉所有 employee_id）
-- ============================================================
CREATE VIEW vw_employee_profile AS
SELECT
    e.id_card_no,
    e.photo_path AS photo,
    e.real_name AS name,
    e.gender,
    CAST((julianday('now') - julianday(e.birth_date || '-01')) / 365.25 AS INTEGER) AS age,
    e.birth_date, e.ethnicity,
    e.native_place AS native, e.birthplace, e.former_name AS alias,
    e.marital_status AS marital, e.political_status AS party,
    e.hometown_type AS domicile_type,
    e.height, e.weight, e.blood_type,
    e.phone AS mobile, e.email_personal AS email, e.email_work,
    e.emergency_contact_name AS emergency,
    e.emergency_contact_relation AS emergency_relation,
    e.emergency_contact_phone AS emergencyTel,
    e.current_status,
    e.id_card_no AS idNumber,
    e.id_card_authority, e.id_card_issue_date, e.id_card_expire_date,
    COALESCE(CAST(e.height AS TEXT), '') || 'cm / ' ||
    COALESCE(CAST(e.weight AS TEXT), '') || 'kg' AS height_weight,

    emp.company AS current_company, emp.labor_relation_company,
    emp.dept_level1, emp.dept_level2, emp.dept_level3, emp.group_name,
    emp.position_name AS position,
    emp.job_class, emp.job_level, emp.job_level_class,
    emp.record_type, emp.start_date, emp.tenure_base_date,
    emp.contract_expire_date, emp.contract_summary_type,
    emp.social_insurance_relation, emp.non_compete_signed, emp.non_compete_period,

    edu.degree_level AS education, edu.degree_type AS degree, edu.degree_status,
    edu.school_name AS school, edu.school_type, edu.is_985_211, edu.major,
    edu.minor_major, edu.research_direction AS researchDir,
    edu.start_date AS edu_start_date,
    edu.graduation_date AS gradTime,
    edu.study_duration AS edu_study_duration,
    edu.diploma_no, edu.degree_cert_no,

    COALESCE(ah.province,'') || COALESCE(ah.city,'') || COALESCE(ah.district,'') AS domicile,
    ah.address_detail_extra AS domicile_detail,
    ah.hukou_type AS domicile_type_hukou,
    ah.postal_code AS domicileZip,

    COALESCE(an.province,'') || COALESCE(an.city,'') ||
    COALESCE(an.district,'') || COALESCE(an.address_detail,'') AS currentAddr,
    an.postal_code AS currentZip

FROM employee e
LEFT JOIN education_record edu
       ON e.id_card_no = edu.id_card_no AND edu.is_highest = 1
LEFT JOIN employment_record emp
       ON e.id_card_no = emp.id_card_no AND emp.end_date IS NULL
LEFT JOIN address_record ah
       ON e.id_card_no = ah.id_card_no AND ah.address_type = '户籍地' AND ah.is_current = 1
LEFT JOIN address_record an
       ON e.id_card_no = an.id_card_no AND an.address_type = '现住址' AND an.is_current = 1;

-- ============================================================
-- 5. 表单配置数据（与原版完全一致）
-- ============================================================
INSERT INTO form_template (id, template_name, total_columns) VALUES (1, '员工个人信息登记表', 24);

INSERT INTO form_group (id, template_id, group_key, group_label, sort_order) VALUES
  (1, 1, 'basic',     '基本信息', 10),
  (2, 1, 'job',       '任职信息', 20),
  (3, 1, 'education', '学历信息', 30),
  (4, 1, 'id_card',   '证件信息', 40),
  (5, 1, 'address',   '地址信息', 50);

INSERT INTO form_field (group_id, field_key, field_label, lc, vc, min_r, is_photo, sort_order) VALUES
(1,'photo','照片',0,4,6,1,10),(1,'name','姓名',2,4,1,0,20),(1,'alias','曾用名',2,4,1,0,30),
(1,'gender','性别',2,4,1,0,40),(1,'ethnicity','民族',2,4,1,0,50),(1,'birth_date','出生年月',2,4,1,0,60),
(1,'native','籍贯',2,4,1,0,70),(1,'birthplace','出生地',2,4,1,0,80),(1,'party','政治面貌',2,4,1,0,90),
(1,'marital','婚姻状况',2,4,1,0,100),(1,'domicile_type','户籍属性',2,4,1,0,110),(1,'blood_type','血型',2,4,1,0,120),
(1,'height_weight','身高/体重',2,4,1,0,130),(1,'mobile','联系方式',2,4,1,0,140),(1,'email','个人邮箱',3,9,1,0,150),
(1,'email_work','工作邮箱',3,9,1,0,160),(1,'emergency','紧急联系人',3,9,1,0,170),(1,'emergency_relation','与本人关系',3,9,1,0,180),
(1,'emergencyTel','紧急联系电话',3,9,1,0,190);

INSERT INTO form_field (group_id, field_key, field_label, lc, vc, min_r, is_photo, sort_order) VALUES
(2,'current_company','用工公司',3,9,1,0,10),(2,'labor_relation_company','劳动关系隶属',3,9,1,0,20),
(2,'dept_level1','一级部门',2,4,1,0,30),(2,'dept_level2','二级部门',2,4,1,0,40),
(2,'dept_level3','三级部门',2,4,1,0,50),(2,'group_name','组别',2,4,1,0,60),
(2,'position','岗位名称',2,4,1,0,70),(2,'job_level','职级',2,4,1,0,80),
(2,'job_class','职类',2,4,1,0,90),(2,'job_level_class','职级职类',2,4,1,0,100),
(2,'record_type','用工形式',2,4,1,0,110),(2,'start_date','入职时间',2,4,1,0,120),
(2,'tenure_base_date','司龄基准日',2,4,1,0,130),(2,'contract_expire_date','合同到期日',2,4,1,0,140),
(2,'contract_summary_type','合同类型',2,4,1,0,150),(2,'social_insurance_relation','社保关系',2,4,1,0,160),
(2,'non_compete_signed','是否签署《竞业限制协议》',6,6,1,0,170),(2,'non_compete_period','竞业限制期限',3,9,1,0,180);

INSERT INTO form_field (group_id, field_key, field_label, lc, vc, min_r, is_photo, sort_order) VALUES
(3,'education','学历',2,4,1,0,10),(3,'degree','学位',2,4,1,0,20),
(3,'degree_status','学历学位状态',3,9,1,0,30),(3,'school','毕业院校',3,9,1,0,40),
(3,'school_type','院校属性',2,4,1,0,50),(3,'is_985_211','是否985/211',3,3,1,0,60),
(3,'major','专业',3,9,1,0,70),(3,'minor_major','辅修专业',3,9,1,0,80),
(3,'researchDir','研究方向',3,9,1,0,90),(3,'edu_start_date','入学时间',3,9,1,0,100),
(3,'gradTime','毕业时间',2,4,1,0,110),(3,'edu_study_duration','学制（年）',2,4,1,0,120),
(3,'diploma_no','毕业证书编号',3,9,1,0,130),(3,'degree_cert_no','学位证书编号',3,9,1,0,140);

INSERT INTO form_field (group_id, field_key, field_label, lc, vc, min_r, is_photo, sort_order) VALUES
(4,'idNumber','身份证号',3,9,1,0,10),(4,'id_card_authority','发证机关',3,9,1,0,20),
(4,'id_card_issue_date','发证日期',3,9,1,0,30),(4,'id_card_expire_date','证件到期日',3,9,1,0,40);

INSERT INTO form_field (group_id, field_key, field_label, lc, vc, min_r, is_photo, sort_order) VALUES
(5,'domicile','户籍地',3,9,1,0,10),(5,'domicile_detail','户口所在地详情',3,9,1,0,20),
(5,'currentAddr','现住址',3,9,1,0,30),(5,'currentZip','现住址邮编',3,9,1,0,40);

INSERT INTO form_appendix (id, template_id, appendix_key, title, sort_order) VALUES
  (1,1,'education',    '教育经历',       10),
  (2,1,'work_history', '入职前工作经历', 20),
  (3,1,'contracts',    '劳动合同签订记录',30),
  (4,1,'career',       '职业生涯时间线', 40),
  (5,1,'salary_changes','薪酬调整记录',  50),
  (6,1,'certificates', '职称/职业资格',  60),
  (7,1,'training',     '培训记录',       70),
  (8,1,'rewards',      '奖惩记录',       80),
  (9,1,'family',       '家庭成员情况',   90);

INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
(1,'start_date','入学时间',3,10),(1,'graduation_date','毕业时间',3,20),(1,'school_name','院校名称',4,30),
(1,'major','专业',3,40),(1,'degree_level','学历',2,50),(1,'degree_type','学位',2,60),
(1,'degree_status','学习方式',3,70),(1,'school_type','院校属性',2,80),
(1,'study_duration','学制',1,90),(1,'is_highest','最高学历',1,100);

INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
(2,'start_date','开始时间',3,10),(2,'end_date','结束时间',3,20),(2,'company_name','工作单位',3,30),
(2,'industry','行业',2,40),(2,'company_type','单位属性',2,50),(2,'position','职务',3,60),
(2,'leave_reason','离职原因',3,70),(2,'reference_person','证明人',2,80),(2,'reference_phone','证明电话',3,90);

INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
(3,'seq','签订次数',2,10),(3,'contract_type','合同类型',4,20),(3,'start_date','起始日期',4,30),
(3,'end_date','到期日期',4,40),(3,'remark','备注',10,50);

INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
(4,'period','时期',5,10),(4,'company','用工公司',4,20),(4,'dept','部门',4,30),
(4,'position','岗位',3,40),(4,'job_level_class','职级职类',2,50),
(4,'record_type','用工形式',2,60),(4,'change_type','变动类型',4,70);

INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
(5,'period','时间',4,10),(5,'company','公司',4,20),(5,'dept','部门',4,30),
(5,'position','岗位',3,40),(5,'job_level','职级',2,50),(5,'job_class','职类',2,60),
(5,'job_level_class','职级职类',2,70),(5,'change_reason','调整原因',3,80);

INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
(6,'cert_category','资质类别',3,10),(6,'cert_name','资质名称',4,20),(6,'cert_major','所属专业',4,30),
(6,'cert_level','资质等级',3,40),(6,'cert_no','证书编号',4,50),(6,'issue_date','取证时间',3,60),
(6,'expire_date','到期时间',3,70);

INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
(7,'start_date','开始时间',3,10),(7,'end_date','结束时间',3,20),(7,'training_name','项目名称',6,30),
(7,'training_type','培训类型',3,40),(7,'training_org','培训机构',4,50),
(7,'result','考核结果',2,60),(7,'cert_obtained','获得证书',3,70);

INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
(8,'record_date','日期',3,10),(8,'record_type','类型',3,20),(8,'category','类别',4,30),
(8,'reason','原因',10,40),(8,'issuer','签发单位',4,50);

INSERT INTO form_appendix_col (appendix_id, field_key, label, colspan, sort_order) VALUES
(9,'relation','称谓',2,10),(9,'real_name','姓名',3,20),(9,'birth_date','出生年月',3,30),
(9,'political_status','政治面貌',3,40),(9,'education_level','学历',2,50),
(9,'work_unit','工作单位',5,60),(9,'position','职务',3,70),(9,'phone','联系方式',3,80);

-- ============================================================
-- 6. 模拟数据
-- ============================================================

INSERT INTO employee (
    id_card_no, real_name, gender, birth_date, ethnicity, political_status, hometown_type,
    marital_status, native_place, birthplace, former_name, height, weight, blood_type,
    id_card_authority, id_card_issue_date, id_card_expire_date, current_status,
    phone, email_personal, email_work,
    emergency_contact_name, emergency_contact_relation, emergency_contact_phone, photo_path
) VALUES (
    '530102198805151234','张伟','男','1988-05','汉族','中共党员','城镇',
    '已婚','云南省昆明市','云南省昆明市','张小伟',175.5,70.2,'A',
    '昆明市公安局五华分局','2010-06-01','2030-06-01','在职',
    '13888888888','zhangwei@gmail.com','zhangwei@dingcheng.com',
    '王秀英','母子','13777777777','/uploads/avatars/zhangwei.png'
);

INSERT INTO employment_record (
    id_card_no, record_type, company, labor_relation_company,
    dept_level1, dept_level2, dept_level3, group_name,
    position_name, job_level, job_class, job_level_class,
    salary_amount, change_reason,
    start_date, end_date, tenure_base_date, pre_work_years, end_reason,
    transfer_from_record_id, contract_summary_type, contract_expire_date,
    social_insurance_relation, non_compete_signed, non_compete_period
) VALUES
(
    '530102198805151234','劳务派遣','关联公司A','关联公司A',
    '技术部','基础平台组','外包支持组','派遣一组',
    'Java开发工程师','5','T2','1-T1',
    6000.00,'首次入职',
    '2012-03-01','2014-06-30','2012-03-01',1.5,'转正调岗',
    NULL,'劳务协议','2014-06-30','关联公司A','否','无'
),
(
    '530102198805151234','正式员工','昆明鼎承科技','昆明鼎承科技',
    '技术部','研发中心','后端组','核心开发组',
    '高级Java工程师','4','T3','1-T3',
    15000.00,'跨公司转入',
    '2014-07-01','2020-12-31','2012-03-01',1.5,'内部晋升',
    (SELECT id FROM employment_record WHERE id_card_no='530102198805151234' AND start_date='2012-03-01'),
    '固定期限','2020-12-31','昆明鼎承科技','是','1年'
),
(
    '530102198805151234','正式员工','昆明鼎承科技','昆明鼎承科技',
    '技术部','研发中心','后端组','架构小组',
    '高级架构师','3','T4','2-T5',
    35000.00,'内部晋升',
    '2021-01-01',NULL,'2012-03-01',1.5,NULL,
    (SELECT id FROM employment_record WHERE id_card_no='530102198805151234' AND start_date='2014-07-01'),
    '无固定期限','2099-12-31','昆明鼎承科技','是','2年'
);

INSERT INTO contract_record (id_card_no, seq, start_date, employment_record_id, contract_type, end_date, remark) VALUES
(
    '530102198805151234',1,'2012-03-01',
    (SELECT id FROM employment_record WHERE id_card_no='530102198805151234' AND start_date='2012-03-01'),
    '劳务协议','2014-06-30','外包支持协议'
),
(
    '530102198805151234',1,'2014-07-01',
    (SELECT id FROM employment_record WHERE id_card_no='530102198805151234' AND start_date='2014-07-01'),
    '固定期限','2017-06-30','首次正式签约3年'
),
(
    '530102198805151234',2,'2017-07-01',
    (SELECT id FROM employment_record WHERE id_card_no='530102198805151234' AND start_date='2014-07-01'),
    '无固定期限','2099-12-31','符合无固条件续签'
);

INSERT INTO address_record (id_card_no, address_type, province, city, district, address_detail, address_detail_extra, postal_code, hukou_type, is_current) VALUES
('530102198805151234','户籍地','云南省','昆明市','五华区','护国路','某街道某社区12号','650031','城镇',1),
('530102198805151234','现住址','云南省','昆明市','官渡区','星耀路某公寓A栋602室','近地铁站','650200','非农业',1);

INSERT INTO education_record (id_card_no, school_name, start_date, is_highest, degree_level, degree_type, degree_status, school_type, is_985_211, major, minor_major, research_direction, study_duration, graduation_date, diploma_no, degree_cert_no) VALUES
('530102198805151234','云南大学','2006-09-01',0,'本科','学士','统招全日制','普通本科','是','软件工程','工商管理','基础软件开发',4.0,'2010-06-30','YD1001','XW1001'),
('530102198805151234','电子科技大学','2016-09-01',1,'硕士','硕士','在职研究生','双一流','是','计算机科学','无','分布式计算',3.0,'2019-06-30','YD2001','XW2001');

INSERT INTO certificate_record (id_card_no, cert_name, cert_category, issue_date, cert_major, cert_level, cert_no, expire_date) VALUES
('530102198805151234','中级工程师','职称','2018-09-01','软件工程','中级','ZC201809001', NULL),
('530102198805151234','系统架构设计师','职业资格', NULL,'系统架构设计','高级','ZG202005002', NULL),
('530102198805151234','PMP项目管理师','职业技能','2019-10-10','敏捷开发','国际认证','PMP12345678','2025-10-10');

INSERT INTO family_member (id_card_no, relation, real_name, birth_date, political_status, education_level, work_unit, position, phone) VALUES
('530102198805151234','配偶','李霞','1990-03-12','群众','本科','市第一人民医院','护士长','13666666666'),
('530102198805151234','父亲','张建国','1960-05-01','中共党员','高中','昆明钢铁厂','退休职工','13555555555');

INSERT INTO reward_punishment_record (id_card_no, record_date, record_type, category, reason, issuer) VALUES
('530102198805151234','2023-12-31','奖励','优秀员工','主导核心系统国产化，提前交付','人力资源部'),
('530102198805151234','2015-06-15','惩罚','生产事故','误删环境导致停机','技术部');

INSERT INTO training_record (id_card_no, training_name, start_date, training_type, training_org, end_date, result, cert_obtained) VALUES
('530102198805151234','Spring Cloud实战','2019-03-01','外训','极客时间','2019-03-05','优秀','结业证'),
('530102198805151234','高并发架构营','2022-05-01','内训','公司技委会','2022-05-30','合格','无');

INSERT INTO work_experience (id_card_no, company_name, start_date, industry, company_type, position, end_date, leave_reason, reference_person, reference_phone) VALUES
('530102198805151234','科海网络','2010-07-01','互联网IT','民营企业','初级Java','2011-02-28','公司解散','周杰伦','13000000001'),
('530102198805151234','云软开发','2011-10-01','企业软件','合资企业','Java开发','2012-02-28','寻求更好发展','刘德华','13000000002');

INSERT INTO salary_change_record (id_card_no, period, company, dept, position, job_level, job_class, job_level_class, change_reason) VALUES
('530102198805151234','2014-07-01','昆明鼎承科技','技术部','高级Java工程师','4','T3','1-T3','转正调薪'),
('530102198805151234','2021-01-01','昆明鼎承科技','技术部','高级架构师','3','T4','2-T5','年度晋升调薪');

INSERT INTO feishu_user_map (id_card_no, feishu_user_id, real_name) VALUES
('530102198805151234','ou_xxxxxxxxxxxxxxxxxxxxxxxx','张伟');

PRAGMA foreign_keys = true;