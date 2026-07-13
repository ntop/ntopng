/* 
Testing schema for Wazuh alerts handling


Wazuh Alert Levels Breakdown

Level 0 — Ignored: No action is taken. These rules are processed first to filter out false positives and events with no security impact. They do not appear on the dashboard
 1 — System Log / Information: Logging events of low importance with no security relevance.
Level 2 — System Low Priority Notification: Routine system notifications, such as a normal system reboot or expected service status updates.
Level 3 — Successful / Authorized Event: Standard successful events. This includes a successful user login or a normal policy check. (This is the default logging threshold).
Level 4 — System Error: Standard system errors, such as a missing file or an application throwing an unhandled exception.
Level 5 — User Generated Error: Misconfiguration or human error, such as typing a wrong password once or attempting to access a non-existent URL.
Level 6 — Low Relevance Attack: Events that look slightly suspicious but are likely false positives or unsuccessful scanning attempts.
Level 7 — Information Contextual Alerts: Alerts that gain relevance when correlated over time or combined with other rules.
Level 8 — First Level Anomalies: Deviations from normal behavior, such as a user logging in at an unusual hour or an unknown application launching.
Level 9 — Error from Invalid Source: Repeated minor errors or errors caused by an invalid or unknown source, often indicating automated reconnaissance tools.
Level 10 — Multiple User Errors / Misuse: Multiple authentication failures, standard automated attacks, or explicit exploitation patterns like directory traversal attempts.
Level 11 — Increased Priority Security Level: Repeated attempts to bypass security controls or an accumulation of several lower-level alerts on the same host.
Level 12 — High Importance Event: Error or warning messages indicating a highly probable attack on a specific application, or major system alterations. (This is the default email notification threshold).
Level 13 — Unusual Error (High Importance): Events matching clear, documented attack signatures or critical system infrastructure failures.
Level 14 — High Importance Security Event: Highly accurate security indicators. These usually indicate a successful attack confirmed through multi-event correlation.
Level 15 — Severe Attack: Active, confirmed attacks where there is virtually zero chance of a false positive. These demand immediate incident response actions.
Level 16 — Critical Event: Reserved for catastrophic events, massive continuous attacks, or total compromise of a foundational security module.
*/

CREATE TABLE IF NOT EXISTS wazuh_alerts
(
    ingested_at          DateTime64(3, 'UTC')  DEFAULT now64(),
    alert_id             String,
    timestamp            DateTime64(3, 'UTC'),
    alert_action         String,
    rule_id              UInt32,
    rule_level           UInt8,
    rule_description     String,
    rule_groups          Array(String),
    rule_mitre_id        Array(String),
    rule_mitre_tactic    Array(String),
    rule_mitre_technique Array(String),
    rule_pci_dss         Array(String),
    rule_gdpr            Array(String),
    rule_hipaa           Array(String),
    agent_id             String,
    agent_name           String,
    agent_ip             IPv4,
    manager_name         String,
    src_ip               IPv4,
    src_port             UInt16,
    src_hostname         String,
    src_country          String,
    src_city             String,
    dst_ip               IPv4,
    dst_port             UInt16,
    dst_hostname         String,
    username             String,
    username_dst         String,
    effective_user       String,
    domain               String,
    process              String,
    process_id           UInt32,
    command              String,
    file_path            String,
    file_hash_md5        String,
    file_hash_sha1       String,
    file_hash_sha256     String,
    protocol             String,
    url                  String,
    url_path             String,
    vuln_cve             String,
    vuln_severity        String,
    vuln_package         String,
    vuln_version         String,
    geo_country_src      String,
    geo_city_src         String,
    geo_lat_src          Float32,
    geo_lon_src          Float32,
    full_log             String,
    raw_json             String
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, agent_id, rule_id)
TTL toDateTime(timestamp) + INTERVAL 1 YEAR
SETTINGS index_granularity = 8192;
@
CREATE TABLE IF NOT EXISTS wazuh_alert_rules
(
    id          String        COMMENT 'Unique rule identifier',
    priority    Int32         DEFAULT 100 COMMENT 'Evaluation order – lower runs first',
    min_level   UInt8         DEFAULT 0   COMMENT 'Minimum Wazuh rule level (0 = any).',
    groups      Array(String) DEFAULT []  COMMENT 'Wazuh rule groups that trigger this rule (empty = any). Example syslog,sshd,authentication_success',
    immediate   UInt8         DEFAULT 0   COMMENT '1 = send immediately; 0 = batch',
    subject     String        DEFAULT '[Wazuh] Alert digest' COMMENT 'Email subject template',
    enabled     UInt8         DEFAULT 1   COMMENT '0 = disabled',
    comment     String        DEFAULT ''  COMMENT 'Free-text description',
    updated_at  DateTime      DEFAULT now() COMMENT 'Last modification time'
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY id;
@
