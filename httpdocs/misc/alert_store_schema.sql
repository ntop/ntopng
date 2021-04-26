-- -----------------------------------------------------
-- Table `active_monitoring_alerts`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `active_monitoring_alerts` (
`rowid` INTEGER PRIMARY KEY AUTOINCREMENT,
`alert_id` INTEGER NOT NULL CHECK(`alert_id` >= 0),
`resolved_ip` TEXT NULL,
`resolved_name` TEXT NULL,
`interface_id` INTEGER NULL,
`measure_threshold` INTEGER NULL DEFAULT 0,
`measure_value` REAL NULL DEFAULT 0,
`tstamp` DATETIME NOT NULL,
`tstamp_end` DATETIME NULL DEFAULT 0,
`severity` INTEGER NOT NULL CHECK(`severity` >= 0),
`counter` INTEGER NOT NULL DEFAULT 0 CHECK(`counter` >= 0),
`description` TEXT NULL,
`json` TEXT NULL);

CREATE INDEX IF NOT EXISTS `i_id` ON `active_monitoring_alerts`(alert_id);
CREATE INDEX IF NOT EXISTS `i_severity` ON `active_monitoring_alerts`(severity);
CREATE INDEX IF NOT EXISTS `i_tstamp` ON `active_monitoring_alerts`(tstamp);

-- -----------------------------------------------------
-- Table `flow_alerts`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `flow_alerts` (
`rowid` INTEGER PRIMARY KEY AUTOINCREMENT,
`alert_id` INTEGER NOT NULL CHECK(`alert_id` >= 0),
`tstamp` DATETIME NOT NULL,
`tstamp_end` DATETIME NULL DEFAULT 0,
`severity` INTEGER NOT NULL CHECK(`severity` >= 0),
`counter` INTEGER NOT NULL DEFAULT 0 CHECK(`counter` >= 0),
`json` TEXT NULL,
`cli_ip` TEXT NOT NULL,
`srv_ip` TEXT NOT NULL,
`cli_port` INTEGER NOT NULL DEFAULT 0 CHECK(`cli_port` BETWEEN 0 AND 65535),
`srv_port` INTEGER NOT NULL DEFAULT 0 CHECK(`srv_port` BETWEEN 0 AND 65535),
`vlan_id` INTEGER NOT NULL DEFAULT 0 CHECK(`vlan_id` >= 0),
`is_attacker_to_victim` INTEGER NOT NULL DEFAULT 0 CHECK(`is_attacker_to_victim` IN (0,1)),
`is_victim_to_attacker` INTEGER NOT NULL DEFAULT 0 CHECK(`is_victim_to_attacker` IN (0,1)),
`proto` INTEGER NOT NULL DEFAULT 0 CHECK(`proto` >= 0),
`l7_proto` INTEGER NOT NULL DEFAULT 0 CHECK(`l7_proto` >= 0),
`l7_master_proto` INTEGER NOT NULL DEFAULT 0 CHECK(`l7_master_proto` >= 0),
`l7_cat` INTEGER NOT NULL DEFAULT 0 CHECK(`l7_cat` >= 0),
`cli_name` TEXT NULL,
`srv_name` TEXT NULL,
`cli_country` TEXT NULL,
`srv_country` TEXT NULL,
`cli_blacklisted` INTEGER NOT NULL DEFAULT 0 CHECK(`cli_blacklisted` IN (0,1)),
`srv_blacklisted` INTEGER NOT NULL DEFAULT 0 CHECK(`srv_blacklisted` IN (0,1)),
`cli2srv_bytes` INTEGER NOT NULL DEFAULT 0 CHECK(`cli2srv_bytes` >= 0),
`srv2cli_bytes` INTEGER NOT NULL DEFAULT 0 CHECK(`srv2cli_bytes` >= 0),
`cli2srv_pkts` INTEGER NOT NULL DEFAULT 0 CHECK(`cli2srv_pkts` >= 0),
`srv2cli_pkts` INTEGER NOT NULL DEFAULT 0 CHECK(`srv2cli_pkts` >= 0),
`first_seen` DATETIME NOT NULL DEFAULT 0,
`community_id` TEXT NULL,
`score` INTEGER NOT NULL DEFAULT 0 CHECK(`score` >= 0),
`flow_risk_bitmap` INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS `i_id` ON `flow_alerts`(alert_id);
CREATE INDEX IF NOT EXISTS `i_severity` ON `flow_alerts`(severity);
CREATE INDEX IF NOT EXISTS `i_tstamp` ON `flow_alerts`(tstamp);
CREATE INDEX IF NOT EXISTS `i_cli_ip` ON `flow_alerts`(`vlan_id`,`cli_ip`);
CREATE INDEX IF NOT EXISTS `i_srv_ip` ON `flow_alerts`(`vlan_id`,`srv_ip`);
CREATE INDEX IF NOT EXISTS `i_cli_port` ON `flow_alerts`(`cli_port`);
CREATE INDEX IF NOT EXISTS `i_srv_port` ON `flow_alerts`(`srv_port`);
CREATE INDEX IF NOT EXISTS `i_l7_proto` ON `flow_alerts`(`l7_proto`);
CREATE INDEX IF NOT EXISTS `i_l7_master_proto` ON `flow_alerts`(`l7_master_proto`);
CREATE INDEX IF NOT EXISTS `i_l7_cat` ON `flow_alerts`(`l7_cat`);
CREATE INDEX IF NOT EXISTS `i_flow_risk_bitmap` ON `flow_alerts`(`flow_risk_bitmap`);

-- -----------------------------------------------------
-- Table `host_alerts`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `host_alerts` (
`rowid` INTEGER PRIMARY KEY AUTOINCREMENT,
`alert_id` INTEGER NOT NULL CHECK(`alert_id` >= 0),
`ip` TEXT NOT NULL,
`vlan_id` INTEGER NULL DEFAULT 0 CHECK(`vlan_id` >= 0),
`name` TEXT NULL,
`is_attacker` INTEGER NULL CHECK(`is_attacker` IN (0,1)),
`is_victim` INTEGER NULL CHECK(`is_victim` IN (0,1)),
`tstamp` DATETIME NOT NULL,
`tstamp_end` DATETIME NULL DEFAULT 0,
`severity` INTEGER NOT NULL CHECK(`severity` >= 0),
`granularity` INTEGER NOT NULL DEFAULT 0 CHECK(`granularity` >= 0),
`counter` INTEGER NOT NULL DEFAULT 0 CHECK(`counter` >= 0),
`description` TEXT NULL,
`json` TEXT NULL);

CREATE INDEX IF NOT EXISTS `i_id` ON `host_alerts`(`alert_id`);
CREATE INDEX IF NOT EXISTS `i_severity` ON `host_alerts`(`severity`);
CREATE INDEX IF NOT EXISTS `i_tstamp` ON `host_alerts`(`tstamp`);
CREATE INDEX IF NOT EXISTS `i_ip` ON `host_alerts`(`vlan_id`,`ip`);
CREATE INDEX IF NOT EXISTS `i_is_attacker` ON `host_alerts`(`is_attacker`);
CREATE INDEX IF NOT EXISTS `i_is_victim` ON `host_alerts`(`is_victim`);

-- -----------------------------------------------------
-- Table `mac_alerts`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `mac_alerts` (
`rowid` INTEGER PRIMARY KEY AUTOINCREMENT,
`alert_id` INTEGER NOT NULL CHECK(`alert_id` >= 0),
`address` TEXT NULL DEFAULT 0,
`device_type` INTEGER NULL CHECK(`device_type` >= 0),
`name` TEXT NULL,
`is_attacker` INTEGER NULL CHECK(`is_attacker` IN (0,1)),
`is_victim` INTEGER NULL CHECK(`is_victim` IN (0,1)),
`tstamp` DATETIME NOT NULL,
`tstamp_end` DATETIME NULL DEFAULT 0,
`severity` INTEGER NOT NULL CHECK(`severity` >= 0),
`granularity` INTEGER NOT NULL DEFAULT 0 CHECK(`granularity` >= 0),
`counter` INTEGER NOT NULL DEFAULT 0 CHECK(`counter` >= 0),
`description` TEXT NULL,
`json` TEXT NULL);

CREATE INDEX IF NOT EXISTS `i_id` ON `mac_alerts`(alert_id);
CREATE INDEX IF NOT EXISTS `i_severity` ON `mac_alerts`(severity);
CREATE INDEX IF NOT EXISTS `i_tstamp` ON `mac_alerts`(tstamp);
CREATE INDEX IF NOT EXISTS `i_address` ON `mac_alerts`(`address`);
CREATE INDEX IF NOT EXISTS `i_is_attacker` ON `mac_alerts`(`is_attacker`);
CREATE INDEX IF NOT EXISTS `i_is_victim` ON `mac_alerts`(`is_victim`);

-- -----------------------------------------------------
-- Table `snmp_alerts`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `snmp_alerts` (
`rowid` INTEGER PRIMARY KEY AUTOINCREMENT,
`alert_id` INTEGER NOT NULL CHECK(`alert_id` >= 0),
`ip` TEXT NOT NULL,
`port` INTEGER NULL,
`name` TEXT NULL,
`port_name` TEXT NULL,
`tstamp` DATETIME NOT NULL,
`tstamp_end` DATETIME NULL DEFAULT 0,
`severity` INTEGER NOT NULL CHECK(`severity` >= 0),
`granularity` INTEGER NOT NULL DEFAULT 0 CHECK(`granularity` >= 0),
`counter` INTEGER NOT NULL DEFAULT 0 CHECK(`counter` >= 0),
`description` TEXT NULL,
`json` TEXT NULL);

CREATE INDEX IF NOT EXISTS `i_id` ON `snmp_alerts`(alert_id);
CREATE INDEX IF NOT EXISTS `i_severity` ON `snmp_alerts`(severity);
CREATE INDEX IF NOT EXISTS `i_tstamp` ON `snmp_alerts`(tstamp);
CREATE INDEX IF NOT EXISTS `i_ip` ON `snmp_alerts`(`ip`);

-- -----------------------------------------------------
-- Table `network_alerts`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `network_alerts` (
`rowid` INTEGER PRIMARY KEY AUTOINCREMENT,
`local_network_id` INTEGER NOT NULL CHECK(`local_network_id` >= 0),
`alert_id` INTEGER NOT NULL CHECK(`alert_id` >= 0),
`name` TEXT NULL,
`alias` TEXT NULL,
`tstamp` DATETIME NOT NULL,
`tstamp_end` DATETIME NULL DEFAULT 0,
`severity` INTEGER NOT NULL CHECK(`severity` >= 0),
`granularity` INTEGER NOT NULL DEFAULT 0 CHECK(`granularity` >= 0),
`counter` INTEGER NOT NULL DEFAULT 0 CHECK(`counter` >= 0),
`description` TEXT NULL,
`json` TEXT NULL);

CREATE INDEX IF NOT EXISTS `i_id` ON `network_alerts`(alert_id);
CREATE INDEX IF NOT EXISTS `i_severity` ON `network_alerts`(severity);
CREATE INDEX IF NOT EXISTS `i_tstamp` ON `network_alerts`(tstamp);

-- -----------------------------------------------------
-- Table `interface_alerts`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `interface_alerts` (
`rowid` INTEGER PRIMARY KEY AUTOINCREMENT,
`ifid` INTEGER NOT NULL CHECK(`ifid` >= 0),
`alert_id` INTEGER NOT NULL CHECK(`alert_id` >= 0),
`name` TEXT NULL,
`alias` TEXT NULL,
`tstamp` DATETIME NOT NULL,
`tstamp_end` DATETIME NULL DEFAULT 0,
`severity` INTEGER NOT NULL CHECK(`severity` >= 0),
`granularity` INTEGER NOT NULL DEFAULT 0 CHECK(`granularity` >= 0),
`counter` INTEGER NOT NULL DEFAULT 0 CHECK(`counter` >= 0),
`description` TEXT NULL,
`json` TEXT NULL);

CREATE INDEX IF NOT EXISTS `i_id` ON `interface_alerts`(alert_id);
CREATE INDEX IF NOT EXISTS `i_severity` ON `interface_alerts`(severity);
CREATE INDEX IF NOT EXISTS `i_tstamp` ON `interface_alerts`(tstamp);

-- -----------------------------------------------------
-- Table `user_alerts`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `user_alerts` (
`rowid` INTEGER PRIMARY KEY AUTOINCREMENT,
`alert_id` INTEGER NOT NULL CHECK(`alert_id` >= 0),
`user` TEXT NULL,
`tstamp` DATETIME NOT NULL,
`tstamp_end` DATETIME NULL DEFAULT 0,
`severity` INTEGER NOT NULL CHECK(`severity` >= 0),
`granularity` INTEGER NOT NULL DEFAULT 0 CHECK(`granularity` >= 0),
`counter` INTEGER NOT NULL DEFAULT 0 CHECK(`counter` >= 0),
`description` TEXT NULL,
`json` TEXT NULL);

CREATE INDEX IF NOT EXISTS `i_id` ON `interface_alerts`(alert_id);
CREATE INDEX IF NOT EXISTS `i_severity` ON `interface_alerts`(severity);
CREATE INDEX IF NOT EXISTS `i_tstamp` ON `interface_alerts`(tstamp);

-- -----------------------------------------------------
-- Table `system_alerts`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `system_alerts` (
`rowid` INTEGER PRIMARY KEY AUTOINCREMENT,
`alert_id` INTEGER NOT NULL CHECK(`alert_id` >= 0),
`name` TEXT NULL,
`tstamp` DATETIME NOT NULL,
`tstamp_end` DATETIME NULL DEFAULT 0,
`severity` INTEGER NOT NULL CHECK(`severity` >= 0),
`granularity` INTEGER NOT NULL DEFAULT 0 CHECK(`granularity` >= 0),
`counter` INTEGER NOT NULL DEFAULT 0 CHECK(`counter` >= 0),
`description` TEXT NULL,
`json` TEXT NULL);

CREATE INDEX IF NOT EXISTS `i_id` ON `system_alerts`(alert_id);
CREATE INDEX IF NOT EXISTS `i_severity` ON `system_alerts`(severity);
CREATE INDEX IF NOT EXISTS `i_tstamp` ON `system_alerts`(tstamp);
