/*
 Navicat Premium Dump SQL

 Source Server         : HRMS
 Source Server Type    : SQLite
 Source Server Version : 3045000 (3.45.0)
 Source Schema         : main

 Target Server Type    : SQLite
 Target Server Version : 3045000 (3.45.0)
 File Encoding         : 65001

 Date: 08/04/2026 14:23:39
*/

PRAGMA foreign_keys = false;

-- ----------------------------
-- Table structure for address_record
-- ----------------------------
DROP TABLE IF EXISTS "address_record";
CREATE TABLE "address_record" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "employee_id" INTEGER NOT NULL,
  "address_type" TEXT NOT NULL,
  "province" TEXT,
  "city" TEXT,
  "district" TEXT,
  "address_detail" TEXT,
  "address_detail_extra" TEXT,
  "postal_code" TEXT,
  "hukou_type" TEXT,
  "is_current" INTEGER NOT NULL DEFAULT 1,
  "remark" TEXT,
  "created_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  "updated_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  FOREIGN KEY ("employee_id") REFERENCES "employee" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
);

-- ----------------------------
-- Table structure for certificate_record
-- ----------------------------
DROP TABLE IF EXISTS "certificate_record";
CREATE TABLE "certificate_record" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "employee_id" INTEGER NOT NULL,
  "cert_category" TEXT NOT NULL,
  "cert_class" TEXT,
  "cert_major" TEXT,
  "cert_level" TEXT,
  "cert_level_detail" TEXT,
  "cert_no" TEXT,
  "cert_name" TEXT,
  "issue_date" TEXT,
  "expire_date" TEXT,
  "issue_authority" TEXT,
  "remark" TEXT,
  "created_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  "updated_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  FOREIGN KEY ("employee_id") REFERENCES "employee" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
);

-- ----------------------------
-- Table structure for contract_record
-- ----------------------------
DROP TABLE IF EXISTS "contract_record";
CREATE TABLE "contract_record" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "employment_record_id" INTEGER NOT NULL,
  "employee_id" INTEGER NOT NULL,
  "seq" INTEGER NOT NULL,
  "contract_type" TEXT,
  "start_date" TEXT,
  "end_date" TEXT,
  "remark" TEXT,
  "created_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  FOREIGN KEY ("employment_record_id") REFERENCES "employment_record" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
  FOREIGN KEY ("employee_id") REFERENCES "employee" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
  UNIQUE ("employment_record_id" ASC, "seq" ASC)
);

-- ----------------------------
-- Table structure for dict_item
-- ----------------------------
DROP TABLE IF EXISTS "dict_item";
CREATE TABLE "dict_item" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "dict_type" TEXT NOT NULL,
  "dict_type_name" TEXT NOT NULL,
  "item_value" TEXT NOT NULL,
  "item_label" TEXT NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "is_active" INTEGER NOT NULL DEFAULT 1,
  "remark" TEXT,
  "created_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  UNIQUE ("dict_type" ASC, "item_value" ASC)
);

-- ----------------------------
-- Table structure for education_record
-- ----------------------------
DROP TABLE IF EXISTS "education_record";
CREATE TABLE "education_record" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "employee_id" INTEGER NOT NULL,
  "is_highest" INTEGER NOT NULL DEFAULT 0,
  "degree_level" TEXT,
  "degree_type" TEXT,
  "degree_status" TEXT,
  "school_name" TEXT,
  "school_type" TEXT,
  "is_985_211" TEXT DEFAULT '否',
  "major" TEXT,
  "minor_major" TEXT,
  "research_direction" TEXT,
  "start_date" TEXT,
  "study_duration" REAL,
  "graduation_date" TEXT,
  "diploma_no" TEXT,
  "degree_cert_no" TEXT,
  "remark" TEXT,
  "created_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  "updated_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  FOREIGN KEY ("employee_id") REFERENCES "employee" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
);

-- ----------------------------
-- Table structure for employee
-- ----------------------------
DROP TABLE IF EXISTS "employee";
CREATE TABLE "employee" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "real_name" TEXT NOT NULL,
  "id_card_no" TEXT NOT NULL,
  "gender" TEXT NOT NULL,
  "birth_date" TEXT,
  "ethnicity" TEXT,
  "political_status" TEXT,
  "hometown_type" TEXT,
  "marital_status" TEXT,
  "native_place" TEXT,
  "birthplace" TEXT,
  "former_name" TEXT,
  "height" REAL,
  "weight" REAL,
  "blood_type" TEXT,
  "vision" TEXT,
  "id_card_authority" TEXT,
  "id_card_issue_date" TEXT,
  "id_card_expire_date" TEXT,
  "current_status" TEXT NOT NULL DEFAULT '在职',
  "current_company" TEXT,
  "current_dept" TEXT,
  "current_position" TEXT,
  "phone" TEXT,
  "email_personal" TEXT,
  "email_work" TEXT,
  "emergency_contact_name" TEXT,
  "emergency_contact_relation" TEXT,
  "emergency_contact_phone" TEXT,
  "non_compete_signed" TEXT DEFAULT '否',
  "photo_path" TEXT,
  "remark" TEXT,
  "created_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  "updated_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  UNIQUE ("id_card_no" ASC)
);

-- ----------------------------
-- Table structure for employment_record
-- ----------------------------
DROP TABLE IF EXISTS "employment_record";
CREATE TABLE "employment_record" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "employee_id" INTEGER NOT NULL,
  "record_type" TEXT NOT NULL,
  "company" TEXT NOT NULL,
  "labor_relation_company" TEXT,
  "dept_level1" TEXT,
  "dept_level2" TEXT,
  "dept_level3" TEXT,
  "group_name" TEXT,
  "position_name" TEXT,
  "job_family" TEXT,
  "job_class" TEXT,
  "job_level" TEXT,
  "staff_category_group" TEXT,
  "staff_category_sub" TEXT,
  "staff_category_related" TEXT,
  "start_date" TEXT NOT NULL,
  "end_date" TEXT,
  "tenure_base_date" TEXT,
  "pre_work_years" REAL DEFAULT 0,
  "end_reason" TEXT,
  "transfer_from_record_id" INTEGER,
  "contract_summary_type" TEXT,
  "contract_expire_date" TEXT,
  "social_insurance_relation" TEXT,
  "remark" TEXT,
  "created_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  "updated_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  FOREIGN KEY ("employee_id") REFERENCES "employee" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
  FOREIGN KEY ("transfer_from_record_id") REFERENCES "employment_record" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- ----------------------------
-- Table structure for family_member
-- ----------------------------
DROP TABLE IF EXISTS "family_member";
CREATE TABLE "family_member" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "employee_id" INTEGER NOT NULL,
  "relation" TEXT NOT NULL,
  "real_name" TEXT NOT NULL,
  "birth_date" TEXT,
  "political_status" TEXT,
  "education_level" TEXT,
  "work_unit" TEXT,
  "position" TEXT,
  "qualification" TEXT,
  "phone" TEXT,
  "remark" TEXT,
  "created_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  "updated_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  FOREIGN KEY ("employee_id") REFERENCES "employee" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
);

-- ----------------------------
-- Table structure for form_appendix
-- ----------------------------
DROP TABLE IF EXISTS "form_appendix";
CREATE TABLE "form_appendix" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "template_id" INTEGER NOT NULL,
  "appendix_key" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY ("template_id") REFERENCES "form_template" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- ----------------------------
-- Table structure for form_appendix_col
-- ----------------------------
DROP TABLE IF EXISTS "form_appendix_col";
CREATE TABLE "form_appendix_col" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "appendix_id" INTEGER NOT NULL,
  "field_key" TEXT NOT NULL,
  "label" TEXT NOT NULL,
  "colspan" INTEGER NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY ("appendix_id") REFERENCES "form_appendix" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- ----------------------------
-- Table structure for form_field
-- ----------------------------
DROP TABLE IF EXISTS "form_field";
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
  FOREIGN KEY ("group_id") REFERENCES "form_group" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
);

-- ----------------------------
-- Table structure for form_group
-- ----------------------------
DROP TABLE IF EXISTS "form_group";
CREATE TABLE "form_group" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "template_id" INTEGER NOT NULL,
  "group_key" TEXT NOT NULL,
  "group_label" TEXT NOT NULL,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY ("template_id") REFERENCES "form_template" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
);

-- ----------------------------
-- Table structure for form_template
-- ----------------------------
DROP TABLE IF EXISTS "form_template";
CREATE TABLE "form_template" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "template_name" TEXT NOT NULL,
  "total_columns" INTEGER NOT NULL DEFAULT 24
);

-- ----------------------------
-- Table structure for reward_punishment_record
-- ----------------------------
DROP TABLE IF EXISTS "reward_punishment_record";
CREATE TABLE "reward_punishment_record" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "employee_id" INTEGER NOT NULL,
  "record_type" TEXT NOT NULL,
  "record_date" TEXT NOT NULL,
  "category" TEXT,
  "reason" TEXT,
  "amount" REAL,
  "issuer" TEXT,
  "document_no" TEXT,
  "remark" TEXT,
  "created_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  "updated_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  FOREIGN KEY ("employee_id") REFERENCES "employee" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
);

-- ----------------------------
-- Table structure for separation_record
-- ----------------------------
DROP TABLE IF EXISTS "separation_record";
CREATE TABLE "separation_record" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "employment_record_id" INTEGER NOT NULL,
  "employee_id" INTEGER NOT NULL,
  "separation_type" TEXT NOT NULL,
  "separation_date" TEXT NOT NULL,
  "separation_reason" TEXT,
  "separation_reason_detail" TEXT,
  "separation_project" TEXT,
  "compensation_paid" TEXT DEFAULT '否',
  "compensation_items" TEXT,
  "compensation_amount" REAL,
  "non_compete_enforced" TEXT DEFAULT '否',
  "non_compete_period" TEXT,
  "retirement_type" TEXT,
  "retirement_company" TEXT,
  "retirement_status" TEXT,
  "family_contact_phone" TEXT,
  "remark" TEXT,
  "created_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  "updated_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  FOREIGN KEY ("employment_record_id") REFERENCES "employment_record" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
  FOREIGN KEY ("employee_id") REFERENCES "employee" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
  UNIQUE ("employment_record_id" ASC)
);

-- ----------------------------
-- Table structure for staff_transfer_record
-- ----------------------------
DROP TABLE IF EXISTS "staff_transfer_record";
CREATE TABLE "staff_transfer_record" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "employee_id" INTEGER NOT NULL,
  "from_record_id" INTEGER,
  "to_record_id" INTEGER,
  "from_company" TEXT NOT NULL,
  "to_company" TEXT NOT NULL,
  "transfer_out_date" TEXT NOT NULL,
  "transfer_in_date" TEXT NOT NULL,
  "from_position" TEXT,
  "from_dept_level1" TEXT,
  "from_dept_level2" TEXT,
  "from_dept_level3" TEXT,
  "from_group_name" TEXT,
  "from_staff_category" TEXT,
  "to_position" TEXT,
  "tenure_base_date" TEXT,
  "pre_work_years" REAL DEFAULT 0,
  "record_type" TEXT,
  "non_compete_signed" TEXT DEFAULT '否',
  "contract_expire_date" TEXT,
  "contract_summary_type" TEXT,
  "social_insurance_relation" TEXT,
  "transfer_path_desc" TEXT,
  "remark" TEXT,
  "created_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  "updated_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  FOREIGN KEY ("employee_id") REFERENCES "employee" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
  FOREIGN KEY ("from_record_id") REFERENCES "employment_record" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
  FOREIGN KEY ("to_record_id") REFERENCES "employment_record" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
);

-- ----------------------------
-- Table structure for training_record
-- ----------------------------
DROP TABLE IF EXISTS "training_record";
CREATE TABLE "training_record" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "employee_id" INTEGER NOT NULL,
  "training_name" TEXT NOT NULL,
  "training_type" TEXT,
  "training_org" TEXT,
  "start_date" TEXT,
  "end_date" TEXT,
  "training_days" REAL,
  "training_content" TEXT,
  "result" TEXT,
  "cert_obtained" TEXT,
  "cost" REAL,
  "cost_bearer" TEXT,
  "remark" TEXT,
  "created_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  "updated_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  FOREIGN KEY ("employee_id") REFERENCES "employee" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
);

-- ----------------------------
-- Table structure for work_experience
-- ----------------------------
DROP TABLE IF EXISTS "work_experience";
CREATE TABLE "work_experience" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
  "employee_id" INTEGER NOT NULL,
  "company_name" TEXT NOT NULL,
  "position" TEXT,
  "start_date" TEXT,
  "end_date" TEXT,
  "leave_reason" TEXT,
  "reference_person" TEXT,
  "reference_phone" TEXT,
  "remark" TEXT,
  "created_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  "updated_at" TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
  FOREIGN KEY ("employee_id") REFERENCES "employee" ("id") ON DELETE CASCADE ON UPDATE NO ACTION
);

-- ----------------------------
-- View structure for vw_employee_profile
-- ----------------------------
DROP VIEW IF EXISTS "vw_employee_profile";
CREATE VIEW "vw_employee_profile" AS SELECT 
    e.id AS employee_id, e.photo_path AS photo, e.real_name AS name, e.gender,
    CAST((julianday('now') - julianday(e.birth_date || '-01')) / 365.25 AS INTEGER) AS age, -- 动态计算年龄
    e.native_place AS native, e.ethnicity, e.former_name AS alias, e.birthplace, e.marital_status AS marital,
    e.political_status AS party, e.height, e.weight, e.blood_type AS bloodType, e.vision,
    e.phone AS mobile, e.email_personal AS email, e.id_card_no AS idNumber,
    e.emergency_contact_name AS emergency, e.emergency_contact_phone AS emergencyTel,
    
    -- 最高学历信息
    edu.degree_level AS education, edu.degree_type AS degree, edu.major, edu.research_direction AS researchDir,
    edu.graduation_date AS gradTime, edu.school_name AS school,
    
    -- 户籍地址
    addr_hukou.province || addr_hukou.city || addr_hukou.district || IFNULL(addr_hukou.address_detail_extra, '') AS domicile,
    addr_hukou.hukou_type AS domicileType, addr_hukou.postal_code AS domicileZip,
    
    -- 家庭/现住址
    addr_now.province || addr_now.city || addr_now.district || IFNULL(addr_now.address_detail, '') AS currentAddr,
    addr_now.postal_code AS currentZip,
    
    -- 最新岗位
    emp_rec.position_name AS position1,
    e.current_status AS currentStatus
FROM employee e
LEFT JOIN education_record edu ON e.id = edu.employee_id AND edu.is_highest = 1
LEFT JOIN address_record addr_hukou ON e.id = addr_hukou.employee_id AND addr_hukou.address_type = '户籍地' AND addr_hukou.is_current = 1
LEFT JOIN address_record addr_now ON e.id = addr_now.employee_id AND addr_now.address_type = '现住址' AND addr_now.is_current = 1
LEFT JOIN employment_record emp_rec ON e.id = emp_rec.employee_id AND emp_rec.end_date IS NULL;

-- ----------------------------
-- Auto increment value for address_record
-- ----------------------------
UPDATE "sqlite_sequence" SET seq = 4 WHERE name = 'address_record';

-- ----------------------------
-- Auto increment value for certificate_record
-- ----------------------------
UPDATE "sqlite_sequence" SET seq = 3 WHERE name = 'certificate_record';

-- ----------------------------
-- Auto increment value for contract_record
-- ----------------------------
UPDATE "sqlite_sequence" SET seq = 2 WHERE name = 'contract_record';

-- ----------------------------
-- Auto increment value for dict_item
-- ----------------------------
UPDATE "sqlite_sequence" SET seq = 4 WHERE name = 'dict_item';

-- ----------------------------
-- Auto increment value for education_record
-- ----------------------------
UPDATE "sqlite_sequence" SET seq = 4 WHERE name = 'education_record';

-- ----------------------------
-- Auto increment value for employee
-- ----------------------------
UPDATE "sqlite_sequence" SET seq = 4 WHERE name = 'employee';

-- ----------------------------
-- Auto increment value for employment_record
-- ----------------------------
UPDATE "sqlite_sequence" SET seq = 5 WHERE name = 'employment_record';

-- ----------------------------
-- Auto increment value for family_member
-- ----------------------------
UPDATE "sqlite_sequence" SET seq = 5 WHERE name = 'family_member';

-- ----------------------------
-- Auto increment value for form_appendix
-- ----------------------------
UPDATE "sqlite_sequence" SET seq = 2 WHERE name = 'form_appendix';

-- ----------------------------
-- Auto increment value for form_appendix_col
-- ----------------------------
UPDATE "sqlite_sequence" SET seq = 10 WHERE name = 'form_appendix_col';

-- ----------------------------
-- Auto increment value for form_field
-- ----------------------------
UPDATE "sqlite_sequence" SET seq = 36 WHERE name = 'form_field';

-- ----------------------------
-- Auto increment value for form_group
-- ----------------------------
UPDATE "sqlite_sequence" SET seq = 3 WHERE name = 'form_group';

-- ----------------------------
-- Auto increment value for form_template
-- ----------------------------
UPDATE "sqlite_sequence" SET seq = 1 WHERE name = 'form_template';

-- ----------------------------
-- Auto increment value for reward_punishment_record
-- ----------------------------
UPDATE "sqlite_sequence" SET seq = 1 WHERE name = 'reward_punishment_record';

-- ----------------------------
-- Auto increment value for separation_record
-- ----------------------------
UPDATE "sqlite_sequence" SET seq = 1 WHERE name = 'separation_record';

-- ----------------------------
-- Auto increment value for staff_transfer_record
-- ----------------------------
UPDATE "sqlite_sequence" SET seq = 1 WHERE name = 'staff_transfer_record';

-- ----------------------------
-- Auto increment value for training_record
-- ----------------------------
UPDATE "sqlite_sequence" SET seq = 1 WHERE name = 'training_record';

-- ----------------------------
-- Auto increment value for work_experience
-- ----------------------------
UPDATE "sqlite_sequence" SET seq = 3 WHERE name = 'work_experience';

PRAGMA foreign_keys = true;
