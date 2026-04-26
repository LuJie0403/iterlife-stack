-- 统一身份层用户主档与国家字典基线
-- 创建日期：2026-04-26
-- 最后更新：2026-04-26
--
-- 目的：
--   1. 新增 system_country 国家/地区配置表并初始化基础数据；
--   2. 新增 user_profile 用户主档；
--   3. 为 user_account 增加 user_id，并将历史账号一对一回填到用户主档；
--   4. 允许历史账号与首次第三方登录先生成待补全的用户主档，证件字段暂时可为空。
--
-- 说明：
--   1. 国家/地区基础数据根据公开国家数据集生成，包含 ISO 代码、常用名称和电话区号；
--   2. user_profile 的自然人唯一识别键为 country_region_code + certificate_type + certificate_number_hash；
--   3. 在资料补全前，历史回填用户允许上述证件字段为空。

CREATE TABLE IF NOT EXISTS system_country (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    country_code VARCHAR(8) NOT NULL COMMENT '国家/地区代码（ISO alpha-2）',
    country_name VARCHAR(128) NOT NULL COMMENT '国家/地区英文名称',
    country_name_zh VARCHAR(128) NULL COMMENT '国家/地区中文名称',
    country_short_name VARCHAR(160) NULL COMMENT '国家/地区显示名称',
    phone_code VARCHAR(16) NULL COMMENT '国际电话区号（不含加号）',
    iso3_code VARCHAR(8) NULL COMMENT '国家/地区代码（ISO alpha-3）',
    default_locale VARCHAR(16) NULL COMMENT '默认语言区域',
    status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE' COMMENT '状态',
    display_order INT NOT NULL DEFAULT 100 COMMENT '展示顺序',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_system_country_code (country_code)
) COMMENT='国家/地区配置表';

CREATE TABLE IF NOT EXISTS user_profile (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(32) NOT NULL COMMENT '用户主键',
    user_name VARCHAR(128) NOT NULL COMMENT '用户名称',
    country_region_code VARCHAR(8) NULL COMMENT '所属国家/地区',
    certificate_type VARCHAR(32) NULL COMMENT '证件类型',
    certificate_number_hash VARCHAR(128) NULL COMMENT '证件号码哈希',
    certificate_number_ciphertext VARCHAR(512) NULL COMMENT '证件号码密文',
    phone_country_code VARCHAR(16) NULL COMMENT '手机号国家区号',
    phone_number VARCHAR(32) NULL COMMENT '手机号',
    email VARCHAR(255) NULL COMMENT '电子邮箱',
    status VARCHAR(16) NOT NULL DEFAULT 'ACTIVE' COMMENT '状态',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_user_profile_user_id (user_id),
    UNIQUE KEY uk_user_profile_natural_key (country_region_code, certificate_type, certificate_number_hash),
    KEY idx_user_profile_country (country_region_code)
) COMMENT='统一用户主档';

SET @has_user_id := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'user_account'
      AND COLUMN_NAME = 'user_id'
);
SET @sql := IF(
    @has_user_id = 0,
    'ALTER TABLE user_account ADD COLUMN user_id VARCHAR(32) NULL COMMENT ''归属用户主键'' AFTER id',
    'SELECT ''user_account.user_id already exists'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_user_id_idx := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'user_account'
      AND INDEX_NAME = 'idx_user_account_user_id'
);
SET @sql := IF(
    @has_user_id_idx = 0,
    'ALTER TABLE user_account ADD KEY idx_user_account_user_id (user_id)',
    'SELECT ''idx_user_account_user_id already exists'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

INSERT INTO system_country (
    country_code,
    country_name,
    country_name_zh,
    country_short_name,
    phone_code,
    iso3_code,
    default_locale,
    status,
    display_order
)
VALUES
    ('BT', 'Bhutan', '不丹', 'Kingdom of Bhutan', '975', 'BTN', 'en-US', 'ACTIVE', '1'),
    ('TL', 'Timor-Leste', '东帝汶', 'Democratic Republic of Timor-Leste', '670', 'TLS', 'en-US', 'ACTIVE', '2'),
    ('CN', 'China', '中国', 'People''s Republic of China', '86', 'CHN', 'zh-CN', 'ACTIVE', '3'),
    ('CF', 'Central African Republic', '中非共和国', 'Central African Republic', '236', 'CAF', 'en-US', 'ACTIVE', '4'),
    ('DK', 'Denmark', '丹麦', 'Kingdom of Denmark', '45', 'DNK', 'en-US', 'ACTIVE', '5'),
    ('UA', 'Ukraine', '乌克兰', 'Ukraine', '380', 'UKR', 'en-US', 'ACTIVE', '6'),
    ('UZ', 'Uzbekistan', '乌兹别克斯坦', 'Republic of Uzbekistan', '998', 'UZB', 'en-US', 'ACTIVE', '7'),
    ('UG', 'Uganda', '乌干达', 'Republic of Uganda', '256', 'UGA', 'en-US', 'ACTIVE', '8'),
    ('UY', 'Uruguay', '乌拉圭', 'Oriental Republic of Uruguay', '598', 'URY', 'en-US', 'ACTIVE', '9'),
    ('TD', 'Chad', '乍得', 'Republic of Chad', '235', 'TCD', 'en-US', 'ACTIVE', '10'),
    ('YE', 'Yemen', '也门', 'Republic of Yemen', '967', 'YEM', 'en-US', 'ACTIVE', '11'),
    ('AM', 'Armenia', '亚美尼亚', 'Republic of Armenia', '374', 'ARM', 'en-US', 'ACTIVE', '12'),
    ('IL', 'Israel', '以色列', 'State of Israel', '972', 'ISR', 'en-US', 'ACTIVE', '13'),
    ('IQ', 'Iraq', '伊拉克', 'Republic of Iraq', '964', 'IRQ', 'en-US', 'ACTIVE', '14'),
    ('IR', 'Iran', '伊朗', 'Islamic Republic of Iran', '98', 'IRN', 'en-US', 'ACTIVE', '15'),
    ('BZ', 'Belize', '伯利兹', 'Belize', '501', 'BLZ', 'en-US', 'ACTIVE', '16'),
    ('CV', 'Cape Verde', '佛得角', 'Republic of Cabo Verde', '238', 'CPV', 'en-US', 'ACTIVE', '17'),
    ('RU', 'Russia', '俄罗斯', 'Russian Federation', '7', 'RUS', 'ru-RU', 'ACTIVE', '18'),
    ('BG', 'Bulgaria', '保加利亚', 'Republic of Bulgaria', '359', 'BGR', 'en-US', 'ACTIVE', '19'),
    ('HR', 'Croatia', '克罗地亚', 'Republic of Croatia', '385', 'HRV', 'en-US', 'ACTIVE', '20'),
    ('GU', 'Guam', '关岛', 'Guam', '1671', 'GUM', 'en-US', 'ACTIVE', '21'),
    ('GM', 'Gambia', '冈比亚', 'Republic of the Gambia', '220', 'GMB', 'en-US', 'ACTIVE', '22'),
    ('IS', 'Iceland', '冰岛', 'Iceland', '354', 'ISL', 'en-US', 'ACTIVE', '23'),
    ('GN', 'Guinea', '几内亚', 'Republic of Guinea', '224', 'GIN', 'en-US', 'ACTIVE', '24'),
    ('GW', 'Guinea-Bissau', '几内亚比绍', 'Republic of Guinea-Bissau', '245', 'GNB', 'en-US', 'ACTIVE', '25'),
    ('LI', 'Liechtenstein', '列支敦士登', 'Principality of Liechtenstein', '423', 'LIE', 'en-US', 'ACTIVE', '26'),
    ('CG', 'Congo', '刚果', 'Republic of the Congo', '242', 'COG', 'en-US', 'ACTIVE', '27'),
    ('LY', 'Libya', '利比亚', 'State of Libya', '218', 'LBY', 'en-US', 'ACTIVE', '28'),
    ('LR', 'Liberia', '利比里亚', 'Republic of Liberia', '231', 'LBR', 'en-US', 'ACTIVE', '29'),
    ('CA', 'Canada', '加拿大', 'Canada', '1', 'CAN', 'en-CA', 'ACTIVE', '30'),
    ('GH', 'Ghana', '加纳', 'Republic of Ghana', '233', 'GHA', 'en-US', 'ACTIVE', '31'),
    ('GA', 'Gabon', '加蓬', 'Gabonese Republic', '241', 'GAB', 'en-US', 'ACTIVE', '32'),
    ('HU', 'Hungary', '匈牙利', 'Hungary', '36', 'HUN', 'en-US', 'ACTIVE', '33'),
    ('MK', 'North Macedonia', '北馬其頓', 'Republic of North Macedonia', '389', 'MKD', 'en-US', 'ACTIVE', '34'),
    ('MP', 'Northern Mariana Islands', '北马里亚纳群岛', 'Commonwealth of the Northern Mariana Islands', '1670', 'MNP', 'en-US', 'ACTIVE', '35'),
    ('GS', 'South Georgia', '南乔治亚', 'South Georgia and the South Sandwich Islands', '500', 'SGS', 'en-US', 'ACTIVE', '36'),
    ('AQ', 'Antarctica', '南极洲', 'Antarctica', NULL, 'ATA', 'en-US', 'ACTIVE', '37'),
    ('SS', 'South Sudan', '南苏丹', 'Republic of South Sudan', '211', 'SSD', 'en-US', 'ACTIVE', '38'),
    ('ZA', 'South Africa', '南非', 'Republic of South Africa', '27', 'ZAF', 'en-US', 'ACTIVE', '39'),
    ('BW', 'Botswana', '博茨瓦纳', 'Republic of Botswana', '267', 'BWA', 'en-US', 'ACTIVE', '40'),
    ('QA', 'Qatar', '卡塔尔', 'State of Qatar', '974', 'QAT', 'en-US', 'ACTIVE', '41'),
    ('RW', 'Rwanda', '卢旺达', 'Republic of Rwanda', '250', 'RWA', 'en-US', 'ACTIVE', '42'),
    ('LU', 'Luxembourg', '卢森堡', 'Grand Duchy of Luxembourg', '352', 'LUX', 'en-US', 'ACTIVE', '43'),
    ('IN', 'India', '印度', 'Republic of India', '91', 'IND', 'en-IN', 'ACTIVE', '44'),
    ('ID', 'Indonesia', '印度尼西亚', 'Republic of Indonesia', '62', 'IDN', 'id-ID', 'ACTIVE', '45'),
    ('GT', 'Guatemala', '危地马拉', 'Republic of Guatemala', '502', 'GTM', 'en-US', 'ACTIVE', '46'),
    ('EC', 'Ecuador', '厄瓜多尔', 'Republic of Ecuador', '593', 'ECU', 'en-US', 'ACTIVE', '47'),
    ('ER', 'Eritrea', '厄立特里亚', 'State of Eritrea', '291', 'ERI', 'en-US', 'ACTIVE', '48'),
    ('SY', 'Syria', '叙利亚', 'Syrian Arab Republic', '963', 'SYR', 'en-US', 'ACTIVE', '49'),
    ('CU', 'Cuba', '古巴', 'Republic of Cuba', '53', 'CUB', 'en-US', 'ACTIVE', '50'),
    ('TW', 'Taiwan', '台灣', 'Republic of China (Taiwan)', '886', 'TWN', 'zh-TW', 'ACTIVE', '51'),
    ('KG', 'Kyrgyzstan', '吉尔吉斯斯坦', 'Kyrgyz Republic', '996', 'KGZ', 'en-US', 'ACTIVE', '52'),
    ('DJ', 'Djibouti', '吉布提', 'Republic of Djibouti', '253', 'DJI', 'en-US', 'ACTIVE', '53'),
    ('KZ', 'Kazakhstan', '哈萨克斯坦', 'Republic of Kazakhstan', '7', 'KAZ', 'en-US', 'ACTIVE', '54'),
    ('CO', 'Colombia', '哥伦比亚', 'Republic of Colombia', '57', 'COL', 'en-US', 'ACTIVE', '55'),
    ('CR', 'Costa Rica', '哥斯达黎加', 'Republic of Costa Rica', '506', 'CRI', 'en-US', 'ACTIVE', '56'),
    ('CM', 'Cameroon', '喀麦隆', 'Republic of Cameroon', '237', 'CMR', 'en-US', 'ACTIVE', '57'),
    ('TV', 'Tuvalu', '图瓦卢', 'Tuvalu', '688', 'TUV', 'en-US', 'ACTIVE', '58'),
    ('TM', 'Turkmenistan', '土库曼斯坦', 'Turkmenistan', '993', 'TKM', 'en-US', 'ACTIVE', '59'),
    ('TR', 'Türkiye', '土耳其', 'Republic of Türkiye', '90', 'TUR', 'en-US', 'ACTIVE', '60'),
    ('LC', 'Saint Lucia', '圣卢西亚', 'Saint Lucia', '1758', 'LCA', 'en-US', 'ACTIVE', '61'),
    ('KN', 'Saint Kitts and Nevis', '圣基茨和尼维斯', 'Federation of Saint Christopher and Nevis', '1869', 'KNA', 'en-US', 'ACTIVE', '62'),
    ('ST', 'São Tomé and Príncipe', '圣多美和普林西比', 'Democratic Republic of São Tomé and Príncipe', '239', 'STP', 'en-US', 'ACTIVE', '63'),
    ('BL', 'Saint Barthélemy', '圣巴泰勒米', 'Collectivity of Saint Barthélemy', '590', 'BLM', 'en-US', 'ACTIVE', '64'),
    ('VC', 'Saint Vincent and the Grenadines', '圣文森特和格林纳丁斯', 'Saint Vincent and the Grenadines', '1784', 'VCT', 'en-US', 'ACTIVE', '65'),
    ('PM', 'Saint Pierre and Miquelon', '圣皮埃尔和密克隆', 'Saint Pierre and Miquelon', '508', 'SPM', 'en-US', 'ACTIVE', '66'),
    ('CX', 'Christmas Island', '圣诞岛', 'Territory of Christmas Island', '61', 'CXR', 'en-US', 'ACTIVE', '67'),
    ('SH', 'Saint Helena, Ascension and Tristan da Cunha', '圣赫勒拿、阿森松和特里斯坦-达库尼亚', 'Saint Helena, Ascension and Tristan da Cunha', '2', 'SHN', 'en-US', 'ACTIVE', '68'),
    ('MF', 'Saint Martin', '圣马丁', 'Saint Martin', '590', 'MAF', 'en-US', 'ACTIVE', '69'),
    ('SX', 'Sint Maarten', '圣马丁岛', 'Sint Maarten', '1721', 'SXM', 'en-US', 'ACTIVE', '70'),
    ('SM', 'San Marino', '圣马力诺', 'Most Serene Republic of San Marino', '378', 'SMR', 'en-US', 'ACTIVE', '71'),
    ('GY', 'Guyana', '圭亚那', 'Co-operative Republic of Guyana', '592', 'GUY', 'en-US', 'ACTIVE', '72'),
    ('TZ', 'Tanzania', '坦桑尼亚', 'United Republic of Tanzania', '255', 'TZA', 'en-US', 'ACTIVE', '73'),
    ('EG', 'Egypt', '埃及', 'Arab Republic of Egypt', '20', 'EGY', 'en-US', 'ACTIVE', '74'),
    ('ET', 'Ethiopia', '埃塞俄比亚', 'Federal Democratic Republic of Ethiopia', '251', 'ETH', 'en-US', 'ACTIVE', '75'),
    ('KI', 'Kiribati', '基里巴斯', 'Independent and Sovereign Republic of Kiribati', '686', 'KIR', 'en-US', 'ACTIVE', '76'),
    ('TJ', 'Tajikistan', '塔吉克斯坦', 'Republic of Tajikistan', '992', 'TJK', 'en-US', 'ACTIVE', '77'),
    ('SN', 'Senegal', '塞内加尔', 'Republic of Senegal', '221', 'SEN', 'en-US', 'ACTIVE', '78'),
    ('RS', 'Serbia', '塞尔维亚', 'Republic of Serbia', '381', 'SRB', 'en-US', 'ACTIVE', '79'),
    ('SL', 'Sierra Leone', '塞拉利昂', 'Republic of Sierra Leone', '232', 'SLE', 'en-US', 'ACTIVE', '80'),
    ('CY', 'Cyprus', '塞浦路斯', 'Republic of Cyprus', '357', 'CYP', 'en-US', 'ACTIVE', '81'),
    ('SC', 'Seychelles', '塞舌尔', 'Republic of Seychelles', '248', 'SYC', 'en-US', 'ACTIVE', '82'),
    ('MX', 'Mexico', '墨西哥', 'United Mexican States', '52', 'MEX', 'en-US', 'ACTIVE', '83'),
    ('TG', 'Togo', '多哥', 'Togolese Republic', '228', 'TGO', 'en-US', 'ACTIVE', '84'),
    ('DO', 'Dominican Republic', '多明尼加', 'Dominican Republic', '1', 'DOM', 'en-US', 'ACTIVE', '85'),
    ('DM', 'Dominica', '多米尼加', 'Commonwealth of Dominica', '1767', 'DMA', 'en-US', 'ACTIVE', '86'),
    ('AX', 'Åland Islands', '奥兰群岛', 'Åland Islands', '35818', 'ALA', 'en-US', 'ACTIVE', '87'),
    ('AT', 'Austria', '奥地利', 'Republic of Austria', '43', 'AUT', 'en-US', 'ACTIVE', '88'),
    ('VE', 'Venezuela', '委内瑞拉', 'Bolivarian Republic of Venezuela', '58', 'VEN', 'en-US', 'ACTIVE', '89'),
    ('BD', 'Bangladesh', '孟加拉国', 'People''s Republic of Bangladesh', '880', 'BGD', 'en-US', 'ACTIVE', '90'),
    ('AO', 'Angola', '安哥拉', 'Republic of Angola', '244', 'AGO', 'en-US', 'ACTIVE', '91'),
    ('AI', 'Anguilla', '安圭拉', 'Anguilla', '1264', 'AIA', 'en-US', 'ACTIVE', '92'),
    ('AG', 'Antigua and Barbuda', '安提瓜和巴布达', 'Antigua and Barbuda', '1268', 'ATG', 'en-US', 'ACTIVE', '93'),
    ('AD', 'Andorra', '安道尔', 'Principality of Andorra', '376', 'AND', 'en-US', 'ACTIVE', '94'),
    ('FM', 'Micronesia', '密克罗尼西亚', 'Federated States of Micronesia', '691', 'FSM', 'en-US', 'ACTIVE', '95'),
    ('NI', 'Nicaragua', '尼加拉瓜', 'Republic of Nicaragua', '505', 'NIC', 'en-US', 'ACTIVE', '96'),
    ('NG', 'Nigeria', '尼日利亚', 'Federal Republic of Nigeria', '234', 'NGA', 'en-US', 'ACTIVE', '97'),
    ('NE', 'Niger', '尼日尔', 'Republic of Niger', '227', 'NER', 'en-US', 'ACTIVE', '98'),
    ('NP', 'Nepal', '尼泊尔', 'Federal Democratic Republic of Nepal', '977', 'NPL', 'en-US', 'ACTIVE', '99'),
    ('PS', 'Palestine', '巴勒斯坦', 'State of Palestine', '970', 'PSE', 'en-US', 'ACTIVE', '100'),
    ('BS', 'Bahamas', '巴哈马', 'Commonwealth of the Bahamas', '1242', 'BHS', 'en-US', 'ACTIVE', '101'),
    ('PK', 'Pakistan', '巴基斯坦', 'Islamic Republic of Pakistan', '92', 'PAK', 'en-US', 'ACTIVE', '102'),
    ('BB', 'Barbados', '巴巴多斯', 'Barbados', '1246', 'BRB', 'en-US', 'ACTIVE', '103'),
    ('PG', 'Papua New Guinea', '巴布亚新几内亚', 'Independent State of Papua New Guinea', '675', 'PNG', 'en-US', 'ACTIVE', '104'),
    ('PY', 'Paraguay', '巴拉圭', 'Republic of Paraguay', '595', 'PRY', 'en-US', 'ACTIVE', '105'),
    ('PA', 'Panama', '巴拿马', 'Republic of Panama', '507', 'PAN', 'en-US', 'ACTIVE', '106'),
    ('BH', 'Bahrain', '巴林', 'Kingdom of Bahrain', '973', 'BHR', 'en-US', 'ACTIVE', '107'),
    ('BR', 'Brazil', '巴西', 'Federative Republic of Brazil', '55', 'BRA', 'pt-BR', 'ACTIVE', '108'),
    ('BF', 'Burkina Faso', '布基纳法索', 'Burkina Faso', '226', 'BFA', 'en-US', 'ACTIVE', '109'),
    ('BV', 'Bouvet Island', '布维岛', 'Bouvet Island', '47', 'BVT', 'en-US', 'ACTIVE', '110'),
    ('BI', 'Burundi', '布隆迪', 'Republic of Burundi', '257', 'BDI', 'en-US', 'ACTIVE', '111'),
    ('GR', 'Greece', '希腊', 'Hellenic Republic', '30', 'GRC', 'en-US', 'ACTIVE', '112'),
    ('PW', 'Palau', '帕劳', 'Republic of Palau', '680', 'PLW', 'en-US', 'ACTIVE', '113'),
    ('CK', 'Cook Islands', '库克群岛', 'Cook Islands', '682', 'COK', 'en-US', 'ACTIVE', '114'),
    ('CW', 'Curaçao', '库拉索', 'Country of Curaçao', '599', 'CUW', 'en-US', 'ACTIVE', '115'),
    ('KY', 'Cayman Islands', '开曼群岛', 'Cayman Islands', '1345', 'CYM', 'en-US', 'ACTIVE', '116'),
    ('DE', 'Germany', '德国', 'Federal Republic of Germany', '49', 'DEU', 'de-DE', 'ACTIVE', '117'),
    ('IT', 'Italy', '意大利', 'Italian Republic', '39', 'ITA', 'it-IT', 'ACTIVE', '118'),
    ('SB', 'Solomon Islands', '所罗门群岛', 'Solomon Islands', '677', 'SLB', 'en-US', 'ACTIVE', '119'),
    ('TK', 'Tokelau', '托克劳', 'Tokelau', '690', 'TKL', 'en-US', 'ACTIVE', '120'),
    ('LV', 'Latvia', '拉脱维亚', 'Republic of Latvia', '371', 'LVA', 'en-US', 'ACTIVE', '121'),
    ('NO', 'Norway', '挪威', 'Kingdom of Norway', '47', 'NOR', 'en-US', 'ACTIVE', '122'),
    ('CZ', 'Czechia', '捷克', 'Czech Republic', '420', 'CZE', 'en-US', 'ACTIVE', '123'),
    ('MD', 'Moldova', '摩尔多瓦', 'Republic of Moldova', '373', 'MDA', 'en-US', 'ACTIVE', '124'),
    ('MA', 'Morocco', '摩洛哥', 'Kingdom of Morocco', '212', 'MAR', 'en-US', 'ACTIVE', '125'),
    ('MC', 'Monaco', '摩纳哥', 'Principality of Monaco', '377', 'MCO', 'en-US', 'ACTIVE', '126'),
    ('BN', 'Brunei', '文莱', 'Nation of Brunei, Abode of Peace', '673', 'BRN', 'en-US', 'ACTIVE', '127'),
    ('FJ', 'Fiji', '斐济', 'Republic of Fiji', '679', 'FJI', 'en-US', 'ACTIVE', '128'),
    ('SZ', 'Eswatini', '斯威士兰', 'Kingdom of Eswatini', '268', 'SWZ', 'en-US', 'ACTIVE', '129'),
    ('SK', 'Slovakia', '斯洛伐克', 'Slovak Republic', '421', 'SVK', 'en-US', 'ACTIVE', '130'),
    ('SI', 'Slovenia', '斯洛文尼亚', 'Republic of Slovenia', '386', 'SVN', 'en-US', 'ACTIVE', '131'),
    ('SJ', 'Svalbard and Jan Mayen', '斯瓦尔巴特', 'Svalbard og Jan Mayen', '4779', 'SJM', 'en-US', 'ACTIVE', '132'),
    ('LK', 'Sri Lanka', '斯里兰卡', 'Democratic Socialist Republic of Sri Lanka', '94', 'LKA', 'en-US', 'ACTIVE', '133'),
    ('SG', 'Singapore', '新加坡', 'Republic of Singapore', '65', 'SGP', 'en-SG', 'ACTIVE', '134'),
    ('NC', 'New Caledonia', '新喀里多尼亚', 'New Caledonia', '687', 'NCL', 'en-US', 'ACTIVE', '135'),
    ('NZ', 'New Zealand', '新西兰', 'New Zealand', '64', 'NZL', 'en-NZ', 'ACTIVE', '136'),
    ('JP', 'Japan', '日本', 'Japan', '81', 'JPN', 'ja-JP', 'ACTIVE', '137'),
    ('CL', 'Chile', '智利', 'Republic of Chile', '56', 'CHL', 'en-US', 'ACTIVE', '138'),
    ('KP', 'North Korea', '朝鲜', 'Democratic People''s Republic of Korea', '850', 'PRK', 'en-US', 'ACTIVE', '139'),
    ('KH', 'Cambodia', '柬埔寨', 'Kingdom of Cambodia', '855', 'KHM', 'en-US', 'ACTIVE', '140'),
    ('GG', 'Guernsey', '根西岛', 'Bailiwick of Guernsey', '44', 'GGY', 'en-US', 'ACTIVE', '141'),
    ('GD', 'Grenada', '格林纳达', 'Grenada', '1473', 'GRD', 'en-US', 'ACTIVE', '142'),
    ('GL', 'Greenland', '格陵兰', 'Greenland', '299', 'GRL', 'en-US', 'ACTIVE', '143'),
    ('GE', 'Georgia', '格鲁吉亚', 'Georgia', '995', 'GEO', 'en-US', 'ACTIVE', '144'),
    ('VA', 'Vatican City', '梵蒂冈', 'Vatican City State', '3', 'VAT', 'en-US', 'ACTIVE', '145'),
    ('BE', 'Belgium', '比利时', 'Kingdom of Belgium', '32', 'BEL', 'en-US', 'ACTIVE', '146'),
    ('MR', 'Mauritania', '毛里塔尼亚', 'Islamic Republic of Mauritania', '222', 'MRT', 'en-US', 'ACTIVE', '147'),
    ('MU', 'Mauritius', '毛里求斯', 'Republic of Mauritius', '230', 'MUS', 'en-US', 'ACTIVE', '148'),
    ('CD', 'DR Congo', '民主刚果', 'Democratic Republic of the Congo', '243', 'COD', 'en-US', 'ACTIVE', '149'),
    ('TO', 'Tonga', '汤加', 'Kingdom of Tonga', '676', 'TON', 'en-US', 'ACTIVE', '150'),
    ('SA', 'Saudi Arabia', '沙特阿拉伯', 'Kingdom of Saudi Arabia', '966', 'SAU', 'en-US', 'ACTIVE', '151'),
    ('FR', 'France', '法国', 'French Republic', '33', 'FRA', 'fr-FR', 'ACTIVE', '152'),
    ('TF', 'French Southern and Antarctic Lands', '法国南部和南极土地', 'Territory of the French Southern and Antarctic Lands', '262', 'ATF', 'en-US', 'ACTIVE', '153'),
    ('GF', 'French Guiana', '法属圭亚那', 'Guiana', '594', 'GUF', 'en-US', 'ACTIVE', '154'),
    ('PF', 'French Polynesia', '法属波利尼西亚', 'French Polynesia', '689', 'PYF', 'en-US', 'ACTIVE', '155'),
    ('FO', 'Faroe Islands', '法罗群岛', 'Faroe Islands', '298', 'FRO', 'en-US', 'ACTIVE', '156'),
    ('PL', 'Poland', '波兰', 'Republic of Poland', '48', 'POL', 'en-US', 'ACTIVE', '157'),
    ('PR', 'Puerto Rico', '波多黎各', 'Commonwealth of Puerto Rico', '1', 'PRI', 'en-US', 'ACTIVE', '158'),
    ('BA', 'Bosnia and Herzegovina', '波斯尼亚和黑塞哥维那', 'Bosnia and Herzegovina', '387', 'BIH', 'en-US', 'ACTIVE', '159'),
    ('TH', 'Thailand', '泰国', 'Kingdom of Thailand', '66', 'THA', 'th-TH', 'ACTIVE', '160'),
    ('JE', 'Jersey', '泽西岛', 'Bailiwick of Jersey', '44', 'JEY', 'en-US', 'ACTIVE', '161'),
    ('ZW', 'Zimbabwe', '津巴布韦', 'Republic of Zimbabwe', '263', 'ZWE', 'en-US', 'ACTIVE', '162'),
    ('HN', 'Honduras', '洪都拉斯', 'Republic of Honduras', '504', 'HND', 'en-US', 'ACTIVE', '163'),
    ('HT', 'Haiti', '海地', 'Republic of Haiti', '509', 'HTI', 'en-US', 'ACTIVE', '164'),
    ('AU', 'Australia', '澳大利亚', 'Commonwealth of Australia', '61', 'AUS', 'en-AU', 'ACTIVE', '165'),
    ('MO', 'Macau', '澳门', 'Macao Special Administrative Region of the People''s Republic of China', '853', 'MAC', 'zh-MO', 'ACTIVE', '166'),
    ('IE', 'Ireland', '爱尔兰', 'Republic of Ireland', '353', 'IRL', 'en-US', 'ACTIVE', '167'),
    ('EE', 'Estonia', '爱沙尼亚', 'Republic of Estonia', '372', 'EST', 'en-US', 'ACTIVE', '168'),
    ('JM', 'Jamaica', '牙买加', 'Jamaica', '1876', 'JAM', 'en-US', 'ACTIVE', '169'),
    ('TC', 'Turks and Caicos Islands', '特克斯和凯科斯群岛', 'Turks and Caicos Islands', '1649', 'TCA', 'en-US', 'ACTIVE', '170'),
    ('TT', 'Trinidad and Tobago', '特立尼达和多巴哥', 'Republic of Trinidad and Tobago', '1868', 'TTO', 'en-US', 'ACTIVE', '171'),
    ('BO', 'Bolivia', '玻利维亚', 'Plurinational State of Bolivia', '591', 'BOL', 'en-US', 'ACTIVE', '172'),
    ('NR', 'Nauru', '瑙鲁', 'Republic of Nauru', '674', 'NRU', 'en-US', 'ACTIVE', '173'),
    ('SE', 'Sweden', '瑞典', 'Kingdom of Sweden', '46', 'SWE', 'en-US', 'ACTIVE', '174'),
    ('CH', 'Switzerland', '瑞士', 'Swiss Confederation', '41', 'CHE', 'en-US', 'ACTIVE', '175'),
    ('GP', 'Guadeloupe', '瓜德罗普岛', 'Guadeloupe', '590', 'GLP', 'en-US', 'ACTIVE', '176'),
    ('WF', 'Wallis and Futuna', '瓦利斯和富图纳群岛', 'Territory of the Wallis and Futuna Islands', '681', 'WLF', 'en-US', 'ACTIVE', '177'),
    ('VU', 'Vanuatu', '瓦努阿图', 'Republic of Vanuatu', '678', 'VUT', 'en-US', 'ACTIVE', '178'),
    ('RE', 'Réunion', '留尼旺岛', 'Réunion Island', '262', 'REU', 'en-US', 'ACTIVE', '179'),
    ('BY', 'Belarus', '白俄罗斯', 'Republic of Belarus', '375', 'BLR', 'en-US', 'ACTIVE', '180'),
    ('BM', 'Bermuda', '百慕大', 'Bermuda', '1441', 'BMU', 'en-US', 'ACTIVE', '181'),
    ('PN', 'Pitcairn Islands', '皮特凯恩群岛', 'Pitcairn Group of Islands', '64', 'PCN', 'en-US', 'ACTIVE', '182'),
    ('GI', 'Gibraltar', '直布罗陀', 'Gibraltar', '350', 'GIB', 'en-US', 'ACTIVE', '183'),
    ('FK', 'Falkland Islands', '福克兰群岛', 'Falkland Islands', '500', 'FLK', 'en-US', 'ACTIVE', '184'),
    ('KW', 'Kuwait', '科威特', 'State of Kuwait', '965', 'KWT', 'en-US', 'ACTIVE', '185'),
    ('KM', 'Comoros', '科摩罗', 'Union of the Comoros', '269', 'COM', 'en-US', 'ACTIVE', '186'),
    ('CI', 'Ivory Coast', '科特迪瓦', 'Republic of Côte d''Ivoire', '225', 'CIV', 'en-US', 'ACTIVE', '187'),
    ('CC', 'Cocos (Keeling) Islands', '科科斯', 'Territory of the Cocos (Keeling) Islands', '61', 'CCK', 'en-US', 'ACTIVE', '188'),
    ('XK', 'Kosovo', '科索沃', 'Republic of Kosovo', '383', 'UNK', 'en-US', 'ACTIVE', '189'),
    ('PE', 'Peru', '秘鲁', 'Republic of Peru', '51', 'PER', 'en-US', 'ACTIVE', '190'),
    ('TN', 'Tunisia', '突尼斯', 'Tunisian Republic', '216', 'TUN', 'en-US', 'ACTIVE', '191'),
    ('LT', 'Lithuania', '立陶宛', 'Republic of Lithuania', '370', 'LTU', 'en-US', 'ACTIVE', '192'),
    ('SO', 'Somalia', '索马里', 'Federal Republic of Somalia', '252', 'SOM', 'en-US', 'ACTIVE', '193'),
    ('JO', 'Jordan', '约旦', 'Hashemite Kingdom of Jordan', '962', 'JOR', 'en-US', 'ACTIVE', '194'),
    ('NA', 'Namibia', '纳米比亚', 'Republic of Namibia', '264', 'NAM', 'en-US', 'ACTIVE', '195'),
    ('NU', 'Niue', '纽埃', 'Niue', '683', 'NIU', 'en-US', 'ACTIVE', '196'),
    ('MM', 'Myanmar', '缅甸', 'Republic of the Union of Myanmar', '95', 'MMR', 'en-US', 'ACTIVE', '197'),
    ('RO', 'Romania', '罗马尼亚', 'Romania', '40', 'ROU', 'en-US', 'ACTIVE', '198'),
    ('US', 'United States', '美国', 'United States of America', '1', 'USA', 'en-US', 'ACTIVE', '199'),
    ('UM', 'United States Minor Outlying Islands', '美国本土外小岛屿', 'United States Minor Outlying Islands', '268', 'UMI', 'en-US', 'ACTIVE', '200'),
    ('VI', 'United States Virgin Islands', '美属维尔京群岛', 'Virgin Islands of the United States', '1340', 'VIR', 'en-US', 'ACTIVE', '201'),
    ('AS', 'American Samoa', '美属萨摩亚', 'American Samoa', '1684', 'ASM', 'en-US', 'ACTIVE', '202'),
    ('LA', 'Laos', '老挝', 'Lao People''s Democratic Republic', '856', 'LAO', 'en-US', 'ACTIVE', '203'),
    ('KE', 'Kenya', '肯尼亚', 'Republic of Kenya', '254', 'KEN', 'en-US', 'ACTIVE', '204'),
    ('FI', 'Finland', '芬兰', 'Republic of Finland', '358', 'FIN', 'en-US', 'ACTIVE', '205'),
    ('SD', 'Sudan', '苏丹', 'Republic of the Sudan', '249', 'SDN', 'en-US', 'ACTIVE', '206'),
    ('SR', 'Suriname', '苏里南', 'Republic of Suriname', '597', 'SUR', 'en-US', 'ACTIVE', '207'),
    ('GB', 'United Kingdom', '英国', 'United Kingdom of Great Britain and Northern Ireland', '44', 'GBR', 'en-GB', 'ACTIVE', '208'),
    ('IO', 'British Indian Ocean Territory', '英属印度洋领地', 'British Indian Ocean Territory', '246', 'IOT', 'en-US', 'ACTIVE', '209'),
    ('VG', 'British Virgin Islands', '英属维尔京群岛', 'Virgin Islands', '1284', 'VGB', 'en-US', 'ACTIVE', '210'),
    ('NL', 'Netherlands', '荷兰', 'Kingdom of the Netherlands', '31', 'NLD', 'en-US', 'ACTIVE', '211'),
    ('BQ', 'Caribbean Netherlands', '荷蘭加勒比區', 'Bonaire, Sint Eustatius and Saba', '599', 'BES', 'en-US', 'ACTIVE', '212'),
    ('MZ', 'Mozambique', '莫桑比克', 'Republic of Mozambique', '258', 'MOZ', 'en-US', 'ACTIVE', '213'),
    ('LS', 'Lesotho', '莱索托', 'Kingdom of Lesotho', '266', 'LSO', 'en-US', 'ACTIVE', '214'),
    ('PH', 'Philippines', '菲律宾', 'Republic of the Philippines', '63', 'PHL', 'en-US', 'ACTIVE', '215'),
    ('SV', 'El Salvador', '萨尔瓦多', 'Republic of El Salvador', '503', 'SLV', 'en-US', 'ACTIVE', '216'),
    ('WS', 'Samoa', '萨摩亚', 'Independent State of Samoa', '685', 'WSM', 'en-US', 'ACTIVE', '217'),
    ('PT', 'Portugal', '葡萄牙', 'Portuguese Republic', '351', 'PRT', 'pt-PT', 'ACTIVE', '218'),
    ('MN', 'Mongolia', '蒙古', 'Mongolia', '976', 'MNG', 'en-US', 'ACTIVE', '219'),
    ('MS', 'Montserrat', '蒙特塞拉特', 'Montserrat', '1664', 'MSR', 'en-US', 'ACTIVE', '220'),
    ('EH', 'Western Sahara', '西撒哈拉', 'Sahrawi Arab Democratic Republic', '2', 'ESH', 'en-US', 'ACTIVE', '221'),
    ('ES', 'Spain', '西班牙', 'Kingdom of Spain', '34', 'ESP', 'es-ES', 'ACTIVE', '222'),
    ('NF', 'Norfolk Island', '诺福克岛', 'Territory of Norfolk Island', '672', 'NFK', 'en-US', 'ACTIVE', '223'),
    ('BJ', 'Benin', '贝宁', 'Republic of Benin', '229', 'BEN', 'en-US', 'ACTIVE', '224'),
    ('ZM', 'Zambia', '赞比亚', 'Republic of Zambia', '260', 'ZMB', 'en-US', 'ACTIVE', '225'),
    ('GQ', 'Equatorial Guinea', '赤道几内亚', 'Republic of Equatorial Guinea', '240', 'GNQ', 'en-US', 'ACTIVE', '226'),
    ('HM', 'Heard Island and McDonald Islands', '赫德岛和麦当劳群岛', 'Heard Island and McDonald Islands', NULL, 'HMD', 'en-US', 'ACTIVE', '227'),
    ('VN', 'Vietnam', '越南', 'Socialist Republic of Vietnam', '84', 'VNM', 'vi-VN', 'ACTIVE', '228'),
    ('AZ', 'Azerbaijan', '阿塞拜疆', 'Republic of Azerbaijan', '994', 'AZE', 'en-US', 'ACTIVE', '229'),
    ('AF', 'Afghanistan', '阿富汗', 'Islamic Republic of Afghanistan', '93', 'AFG', 'en-US', 'ACTIVE', '230'),
    ('DZ', 'Algeria', '阿尔及利亚', 'People''s Democratic Republic of Algeria', '213', 'DZA', 'en-US', 'ACTIVE', '231'),
    ('AL', 'Albania', '阿尔巴尼亚', 'Republic of Albania', '355', 'ALB', 'en-US', 'ACTIVE', '232'),
    ('AE', 'United Arab Emirates', '阿拉伯联合酋长国', 'United Arab Emirates', '971', 'ARE', 'en-US', 'ACTIVE', '233'),
    ('OM', 'Oman', '阿曼', 'Sultanate of Oman', '968', 'OMN', 'en-US', 'ACTIVE', '234'),
    ('AR', 'Argentina', '阿根廷', 'Argentine Republic', '54', 'ARG', 'en-US', 'ACTIVE', '235'),
    ('AW', 'Aruba', '阿鲁巴', 'Aruba', '297', 'ABW', 'en-US', 'ACTIVE', '236'),
    ('KR', 'South Korea', '韩国', 'Republic of Korea', '82', 'KOR', 'ko-KR', 'ACTIVE', '237'),
    ('HK', 'Hong Kong', '香港', 'Hong Kong Special Administrative Region of the People''s Republic of China', '852', 'HKG', 'zh-HK', 'ACTIVE', '238'),
    ('MV', 'Maldives', '马尔代夫', 'Republic of the Maldives', '960', 'MDV', 'en-US', 'ACTIVE', '239'),
    ('IM', 'Isle of Man', '马恩岛', 'Isle of Man', '44', 'IMN', 'en-US', 'ACTIVE', '240'),
    ('MW', 'Malawi', '马拉维', 'Republic of Malawi', '265', 'MWI', 'en-US', 'ACTIVE', '241'),
    ('MQ', 'Martinique', '马提尼克', 'Martinique', '596', 'MTQ', 'en-US', 'ACTIVE', '242'),
    ('MY', 'Malaysia', '马来西亚', 'Malaysia', '60', 'MYS', 'ms-MY', 'ACTIVE', '243'),
    ('YT', 'Mayotte', '马约特', 'Department of Mayotte', '262', 'MYT', 'en-US', 'ACTIVE', '244'),
    ('MH', 'Marshall Islands', '马绍尔群岛', 'Republic of the Marshall Islands', '692', 'MHL', 'en-US', 'ACTIVE', '245'),
    ('MT', 'Malta', '马耳他', 'Republic of Malta', '356', 'MLT', 'en-US', 'ACTIVE', '246'),
    ('MG', 'Madagascar', '马达加斯加', 'Republic of Madagascar', '261', 'MDG', 'en-US', 'ACTIVE', '247'),
    ('ML', 'Mali', '马里', 'Republic of Mali', '223', 'MLI', 'en-US', 'ACTIVE', '248'),
    ('LB', 'Lebanon', '黎巴嫩', 'Lebanese Republic', '961', 'LBN', 'en-US', 'ACTIVE', '249'),
    ('ME', 'Montenegro', '黑山', 'Montenegro', '382', 'MNE', 'en-US', 'ACTIVE', '250')
ON DUPLICATE KEY UPDATE
    country_name = VALUES(country_name),
    country_name_zh = VALUES(country_name_zh),
    country_short_name = VALUES(country_short_name),
    phone_code = VALUES(phone_code),
    iso3_code = VALUES(iso3_code),
    default_locale = VALUES(default_locale),
    status = VALUES(status),
    display_order = VALUES(display_order),
    updated_at = CURRENT_TIMESTAMP;

UPDATE user_account
SET user_id = CONCAT('usr_', SUBSTRING(SHA2(CONCAT('iterlife:', COALESCE(account_id, ''), ':', COALESCE(account_name, ''), ':', COALESCE(CAST(id AS CHAR), '')), 256), 1, 24))
WHERE user_id IS NULL OR TRIM(user_id) = '';

INSERT INTO user_profile (
    user_id,
    user_name,
    email,
    status,
    created_at,
    updated_at
)
SELECT
    ua.user_id,
    COALESCE(NULLIF(TRIM(ua.display_name), ''), NULLIF(TRIM(ua.account_name), ''), ua.account_id),
    email_seed.provider_email,
    COALESCE(NULLIF(TRIM(ua.status), ''), 'ACTIVE'),
    COALESCE(ua.created_at, CURRENT_TIMESTAMP),
    CURRENT_TIMESTAMP
FROM user_account ua
LEFT JOIN user_profile up
    ON up.user_id = ua.user_id
LEFT JOIN (
    SELECT ai.account_id, ai.provider_email
    FROM authenticate_identity ai
    JOIN (
        SELECT account_id, MIN(id) AS first_email_identity_id
        FROM authenticate_identity
        WHERE provider_email IS NOT NULL
          AND TRIM(provider_email) <> ''
        GROUP BY account_id
    ) first_email
        ON first_email.first_email_identity_id = ai.id
) email_seed
    ON email_seed.account_id = ua.account_id
WHERE up.user_id IS NULL;

UPDATE user_profile up
JOIN user_account ua
    ON ua.user_id = up.user_id
LEFT JOIN (
    SELECT ai.account_id, ai.provider_email
    FROM authenticate_identity ai
    JOIN (
        SELECT account_id, MIN(id) AS first_email_identity_id
        FROM authenticate_identity
        WHERE provider_email IS NOT NULL
          AND TRIM(provider_email) <> ''
        GROUP BY account_id
    ) first_email
        ON first_email.first_email_identity_id = ai.id
) email_seed
    ON email_seed.account_id = ua.account_id
SET
    up.user_name = COALESCE(NULLIF(TRIM(up.user_name), ''), NULLIF(TRIM(ua.display_name), ''), NULLIF(TRIM(ua.account_name), ''), ua.account_id),
    up.email = COALESCE(NULLIF(TRIM(up.email), ''), email_seed.provider_email),
    up.status = COALESCE(NULLIF(TRIM(up.status), ''), COALESCE(NULLIF(TRIM(ua.status), ''), 'ACTIVE')),
    up.updated_at = CURRENT_TIMESTAMP
WHERE up.user_id = ua.user_id;
