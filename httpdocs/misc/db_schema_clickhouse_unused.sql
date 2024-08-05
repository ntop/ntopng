@

DROP VIEW IF EXISTS `active_monitoring_alerts_view`;

@

CREATE VIEW IF NOT EXISTS `active_monitoring_alerts_view` AS
SELECT
  am.rowid,
  am.alert_id,
  am.alert_status,
  am.interface_id,
  am.resolved_ip,
  am.resolved_name,
  am.measurement,
  am.measure_threshold,
  am.measure_value,
  am.tstamp,
  am.tstamp_end,
  am.severity,
  am.score,
  am.counter,
  am.description,
  am.json,
  am.user_label,
  am.user_label_tstamp,
  mitre.TACTIC AS mitre_tactic,
  mitre.TECHNIQUE AS mitre_technique,
  mitre.SUB_TECHNIQUE AS mitre_subtechnique,
  mitre.MITRE_ID AS mitre_id
FROM
  `active_monitoring_alerts` AS am
LEFT JOIN
  `mitre_table_info` AS mitre
ON
  am.alert_id = mitre.ALERT_ID
WHERE
  mitre.ENTITY_ID = 8; -- entity id can be found in: scripts/lua/modules/alert_entities.lua to join based on the type of alerts (etity_id of host alerts is 1)

@

DROP VIEW IF EXISTS `mac_alerts_view`;

@

CREATE VIEW IF NOT EXISTS `mac_alerts_view` AS
SELECT
  ma.rowid,
  ma.alert_id,
  ma.alert_category,
  ma.alert_status,
  ma.interface_id,
  ma.address,
  ma.device_type,
  ma.name,
  ma.is_attacker,
  ma.is_victim,
  ma.tstamp,
  ma.tstamp_end,
  ma.severity,
  ma.score,
  ma.granularity,
  ma.counter,
  ma.description,
  ma.json,
  ma.user_label,
  ma.user_label_tstamp,
  mitre.TACTIC AS mitre_tactic,
  mitre.TECHNIQUE AS mitre_technique,
  mitre.SUB_TECHNIQUE AS mitre_subtechnique,
  mitre.MITRE_ID AS mitre_id
FROM
  `mac_alerts` ma
LEFT JOIN
  `mitre_table_info` mitre
ON
  ma.alert_id = mitre.ALERT_ID
WHERE
  mitre.ENTITY_ID = 5; -- entity id can be found in: scripts/lua/modules/alert_entities.lua to join based on the type of alerts (etity_id of host alerts is 1)

@

DROP VIEW IF EXISTS `snmp_alerts_view`;

@

CREATE VIEW IF NOT EXISTS `snmp_alerts_view` AS
SELECT
  snmp.rowid,
  snmp.alert_id,
  snmp.alert_status,
  snmp.interface_id,
  snmp.ip,
  snmp.port,
  snmp.name,
  snmp.port_name,
  snmp.tstamp,
  snmp.tstamp_end,
  snmp.severity,
  snmp.score,
  snmp.granularity,
  snmp.counter,
  snmp.description,
  snmp.json,
  snmp.user_label,
  snmp.user_label_tstamp,
  mitre.TACTIC AS mitre_tactic,
  mitre.TECHNIQUE AS mitre_technique,
  mitre.SUB_TECHNIQUE AS mitre_subtechnique,
  mitre.MITRE_ID AS mitre_id
FROM
  `snmp_alerts` AS snmp
LEFT JOIN
  `mitre_table_info` AS mitre
ON
  snmp.alert_id = mitre.ALERT_ID
WHERE
  mitre.ENTITY_ID = 3; -- entity id can be found in: scripts/lua/modules/alert_entities.lua to join based on the type of alerts (etity_id of host alerts is 1)

@

DROP VIEW IF EXISTS `network_alerts_view`;

@

CREATE VIEW IF NOT EXISTS `network_alerts_view` AS
SELECT
  na.rowid,
  na.local_network_id,
  na.alert_id,
  na.alert_status,
  na.alert_category,
  na.interface_id,
  na.name,
  na.alias,
  na.tstamp,
  na.tstamp_end,
  na.severity,
  na.score,
  na.granularity,
  na.counter,
  na.description,
  na.json,
  na.user_label,
  na.user_label_tstamp,
  mitre.TACTIC AS mitre_tactic,
  mitre.TECHNIQUE AS mitre_technique,
  mitre.SUB_TECHNIQUE AS mitre_subtechnique,
  mitre.MITRE_ID AS mitre_id
FROM
  `network_alerts` AS na
LEFT JOIN
  `mitre_table_info` AS mitre
ON
  na.alert_id = mitre.ALERT_ID
WHERE
  mitre.ENTITY_ID = 2; -- entity id can be found in: scripts/lua/modules/alert_entities.lua to join based on the type of alerts (etity_id of host alerts is 1)

@

DROP VIEW IF EXISTS `interface_alerts_view`;

@

CREATE VIEW IF NOT EXISTS `interface_alerts_view` AS
SELECT
  ia.rowid,
  ia.ifid,
  ia.alert_id,
  ia.alert_status,
  ia.interface_id,
  ia.subtype,
  ia.name,
  ia.alias,
  ia.tstamp,
  ia.tstamp_end,
  ia.severity,
  ia.score,
  ia.granularity,
  ia.counter,
  ia.description,
  ia.json,
  ia.user_label,
  ia.user_label_tstamp,
  mitre.TACTIC AS mitre_tactic,
  mitre.TECHNIQUE AS mitre_technique,
  mitre.SUB_TECHNIQUE AS mitre_subtechnique,
  mitre.MITRE_ID AS mitre_id
FROM
  `interface_alerts` AS ia
LEFT JOIN
  `mitre_table_info` AS mitre
ON
  ia.alert_id = mitre.ALERT_ID
WHERE
  mitre.ENTITY_ID = 0; -- entity id can be found in: scripts/lua/modules/alert_entities.lua to join based on the type of alerts (etity_id of host alerts is 1)

@

DROP VIEW IF EXISTS `user_alerts_view`;

@

CREATE VIEW IF NOT EXISTS `user_alerts_view` AS
SELECT
  ua.rowid,
  ua.alert_id,
  ua.alert_status,
  ua.interface_id,
  ua.user,
  ua.tstamp,
  ua.tstamp_end,
  ua.severity,
  ua.score,
  ua.granularity,
  ua.counter,
  ua.description,
  ua.json,
  ua.user_label,
  ua.user_label_tstamp,
  mitre.TACTIC AS mitre_tactic,
  mitre.TECHNIQUE AS mitre_technique,
  mitre.SUB_TECHNIQUE AS mitre_subtechnique,
  mitre.MITRE_ID AS mitre_id
FROM
  `user_alerts` AS ua
LEFT JOIN
  `mitre_table_info` AS mitre
ON
  ua.alert_id = mitre.ALERT_ID
WHERE
  mitre.ENTITY_ID = 7; -- entity id can be found in: scripts/lua/modules/alert_entities.lua to join based on the type of alerts (etity_id of host alerts is 1)

@

DROP VIEW IF EXISTS `system_alerts_view`;

@

CREATE VIEW IF NOT EXISTS `system_alerts_view` AS
SELECT
  sa.rowid,
  sa.alert_id,
  sa.alert_status,
  sa.interface_id,
  sa.name,
  sa.tstamp,
  sa.tstamp_end,
  sa.severity,
  sa.score,
  sa.granularity,
  sa.counter,
  sa.description,
  sa.json,
  sa.user_label,
  sa.user_label_tstamp,
  mitre.TACTIC AS mitre_tactic,
  mitre.TECHNIQUE AS mitre_technique,
  mitre.SUB_TECHNIQUE AS mitre_subtechnique,
  mitre.MITRE_ID AS mitre_id
FROM
  `system_alerts` AS sa
LEFT JOIN
  `mitre_table_info` AS mitre
ON
  sa.alert_id = mitre.ALERT_ID
WHERE
  mitre.ENTITY_ID = 9; -- entity id can be found in: scripts/lua/modules/alert_entities.lua to join based on the type of alerts (etity_id of host alerts is 1)
