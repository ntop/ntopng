-- Testing schema for Wazuh alerts handling
--
--
-- Wazuh Alert Levels Breakdown
--
-- Level 0 — Ignored: No action is taken. These rules are processed first to filter out false positives and events with no security impact. They do not appear on the dashboard
-- Level 1 — System Log / Information: Logging events of low importance with no security relevance.
-- Level 2 — System Low Priority Notification: Routine system notifications, such as a normal system reboot or expected service status updates.
-- Level 3 — Successful / Authorized Event: Standard successful events. This includes a successful user login or a normal policy check. (This is the default logging threshold).
-- Level 4 — System Error: Standard system errors, such as a missing file or an application throwing an unhandled exception.
-- Level 5 — User Generated Error: Misconfiguration or human error, such as typing a wrong password once or attempting to access a non-existent URL.
-- Level 6 — Low Relevance Attack: Events that look slightly suspicious but are likely false positives or unsuccessful scanning attempts.
-- Level 7 — Information Contextual Alerts: Alerts that gain relevance when correlated over time or combined with other rules.
-- Level 8 — First -- Level Anomalies: Deviations from normal behavior, such as a user logging in at an unusual hour or an unknown application launching.
-- Level 9 — Error from Invalid Source: Repeated minor errors or errors caused by an invalid or unknown source, often indicating automated reconnaissance tools.
-- Level 10 — Multiple User Errors / Misuse: Multiple authentication failures, standard automated attacks, or explicit exploitation patterns like directory traversal attempts.
-- Level 11 — Increased Priority SecurityLevel: Repeated attempts to bypass security controls or an accumulation of several lower-level alerts on the same host.
-- Level 12 — High Importance Event: Error or warning messages indicating a highly probable attack on a specific application, or major system alterations. (This is the default email notification threshold).
-- Level 13 — Unusual Error (High Importance): Events matching clear, documented attack signatures or critical system infrastructure failures.
-- Level 14 — High Importance Security Event: Highly accurate security indicators. These usually indicate a successful attack confirmed through multi-event correlation.
-- Level 15 — Severe Attack: Active, confirmed attacks where there is virtually zero chance of a false positive. These demand immediate incident response actions.
--  Level 16 — Critical Event: Reserved for catastrophic events, massive continuous attacks, or total compromise of a foundational security module.
@
CREATE DATABASE IF NOT EXISTS wazuh;
@
CREATE TABLE IF NOT EXISTS wazuh.alerts
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
CREATE TABLE IF NOT EXISTS wazuh.alert_rules
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
CREATE TABLE IF NOT EXISTS wazuh.alert_exceptions
(
    id          String  COMMENT 'Unique exception identifier',
    rule_id     UInt32  DEFAULT 0  COMMENT 'Wazuh rule_id to match (0 = any)',
    agent_name  String  DEFAULT '' COMMENT 'Glob pattern for agent name (empty = any)',
    src_ip      String  DEFAULT '' COMMENT 'Source IP to match (empty = any)',
    dst_ip      String  DEFAULT '' COMMENT 'Destination IP to match (empty = any)',
    username    String  DEFAULT '' COMMENT 'Glob pattern for username (empty = any)',
    process     String  DEFAULT '' COMMENT 'Glob pattern for process name (empty = any)',
    rule_group  String  DEFAULT '' COMMENT 'Glob pattern for rule group (empty = any)',
    enabled     UInt8   DEFAULT 1   COMMENT '0 = disabled',
    comment     String  DEFAULT ''  COMMENT 'Free-text description',
    updated_at  DateTime DEFAULT now() COMMENT 'Last modification time'
)
ENGINE = ReplacingMergeTree(updated_at)
ORDER BY id;
@
-- ==========================================================================
-- Wazuh alert_rules for ntopng / SOC-NOC environment
-- ==========================================================================
-- Priority order: lower number = evaluated first.
-- Put the most specific / highest-urgency rules at the top.
-- The engine walks the list top-down and stops at the FIRST match,
-- so a catch-all like 'high-level-catchall' must always be last.
-- ==========================================================================

-- --------------------------------------------------------------------------
-- TIER 1 – IMMEDIATE  (immediate = 1 → one email per event, no batching)
-- --------------------------------------------------------------------------

-- 1. Any critical severity alert (Wazuh level 12+)
--    Acts as a safety net before any specific rule; covers zero-day
--    detections, active exploits and anything Wazuh deems critical.
INSERT INTO wazuh.alert_rules VALUES
('critical-any', 10, 12, [], 1,
 '[CRITICAL] {rule_description} on {agent_name}',
 1, 'Catch-all for any level 12+ alert – sent immediately', now());
@
-- 2. Rootkit / trojan / hidden process detection (rootcheck)
INSERT INTO wazuh.alert_rules VALUES
('rootkit-detected', 20, 7, ['rootcheck'], 1,
 '[CRITICAL] Rootkit/trojan detected on {agent_name}',
 1, 'Wazuh rootcheck positive hit – treat as confirmed compromise until proven otherwise', now());
@
-- 3. Wazuh agent stopped communicating
--    An agent going silent may mean the host is down, the Wazuh process
--    was killed, or an attacker is suppressing telemetry.
INSERT INTO wazuh.alert_rules VALUES
('agent-disconnected', 30, 7, ['ossec', 'agent_disconnected'], 1,
 '[CRITICAL] Wazuh agent disconnected: {agent_name}',
 1, 'Agent heartbeat lost – investigate host availability and possible tamper', now());
@
-- 4. Privilege escalation (sudo / su / setuid abuse)
--    Important for ntopng hosts where capture processes run as root
--    or with CAP_NET_ADMIN; unexpected escalation is a red flag.
INSERT INTO wazuh.alert_rules VALUES
('privilege-escalation', 40, 7, ['syslog', 'sudo', 'pam'], 1,
 '[CRITICAL] Privilege escalation on {agent_name} by user {username}',
 1, 'sudo/su/setuid abuse or unexpected privilege gain', now());
@
-- 5. Web shell / command injection via web server
--    ntopng exposes an HTTPS management interface; this covers
--    any web-layer attack that reaches command execution.
INSERT INTO wazuh.alert_rules VALUES
('web-shell', 50, 7, ['web', 'attack', 'appsec'], 1,
 '[CRITICAL] Web shell / injection attempt on {agent_name} from {src_ip}',
 1, 'Web application attack with command execution risk on management interface', now());
@
-- --------------------------------------------------------------------------
-- TIER 2 – BATCHED  (immediate = 0 → digest email every batch_window_seconds)
-- --------------------------------------------------------------------------

-- 6. SSH brute-force / authentication failures
--    The highest-volume event type in any internet-exposed environment.
--    Batching avoids flooding the inbox; the digest still shows src IPs
--    so you can spot a targeted campaign vs random noise.
INSERT INTO wazuh.alert_rules VALUES
('ssh-brute-force', 100, 5,
 ['authentication_failed', 'authentication_failures', 'sshd'], 0,
 '[WARN] SSH / PAM authentication failures digest',
 1, 'Batches all SSH/PAM login failures – review src IPs in digest for targeting', now());
@
-- 7. Successful logins (especially after previous failures)
--    A successful login is not inherently bad, but tracking them lets
--    you correlate "brute force then success" sequences in the digest.
INSERT INTO wazuh.alert_rules VALUES
('auth-success', 110, 5, ['authentication_success'], 0,
 '[INFO] Successful authentication events digest',
 1, 'Tracks successful logins for correlation with prior failure events', now());
@
-- 8. File integrity monitoring – configuration / binary changes (FIM)
--    ntopng ships signed binaries (as you know well); any unexpected
--    change to /usr/bin/ntopng, /etc/ntopng, or nDPI libraries is critical.
INSERT INTO wazuh.alert_rules VALUES
('fim-changes', 200, 7, ['syscheck'], 0,
 '[WARN] File integrity changes digest',
 1, 'FIM hits – pay attention to ntopng/nDPI binaries and config files', now());
@
-- 9. Vulnerability detections (Wazuh vulnerability scanner / CVE feed)
INSERT INTO wazuh.alert_rules VALUES
('vulnerability-detected', 300, 7, ['vulnerability-detector'], 0,
 '[WARN] Vulnerability detections digest',
 1, 'CVE matches from Wazuh vuln scanner – triage by severity and CVSS score', now());
@
-- 10. Suspicious process / unexpected command execution
--     Catches shells spawned from web servers, cron abuse, or unusual
--     interpreters (python, perl, php) run from ntopng working directories.
INSERT INTO wazuh.alert_rules VALUES
('suspicious-process', 400, 6, ['process_monitor', 'audit'], 0,
 '[WARN] Suspicious process execution digest on {agent_name}',
 1, 'Unexpected binaries or interpreters; check parent process chain', now());
@
-- 11. Network scan / IDS events
--     Relevant because ntopng/nDPI hosts are often reachable from the
--     network being monitored; port scans against them deserve attention.
--     Also covers Suricata/Snort signatures if forwarded via Wazuh.
INSERT INTO wazuh.alert_rules VALUES
('network-scan-ids', 500, 5, ['ids', 'suricata', 'snort', 'network'], 0,
 '[WARN] Network scan / IDS signature events digest',
 1, 'Port scans and IDS hits batched – look for repeated src IPs targeting management ports', now());
@
-- 12. Firewall / iptables block spikes
--     Useful for detecting DDoS attempts against the capture interface
--     or management plane, and for spotting misconfigured firewall rules.
INSERT INTO wazuh.alert_rules VALUES
('firewall-drops', 600, 5, ['firewall', 'iptables', 'pf'], 0,
 '[WARN] Firewall drop events digest',
 1, 'Blocked traffic – volume spikes may indicate DDoS or misconfiguration', now());
@
-- 13. Docker / container anomalies
--     ntopng ships as Docker containers; privileged containers, unexpected
--     image pulls, or runtime restarts should all be tracked.
INSERT INTO wazuh.alert_rules VALUES
('container-anomaly', 700, 6, ['docker', 'container'], 0,
 '[WARN] Container anomaly digest',
 1, 'Unexpected container starts, privileged flags, image changes on ntopng containers', now());
@
-- 14. System-level errors (OOM killer, disk full, hardware faults)
--     High-bandwidth capture means storage and memory pressure are real;
--     OOM kills affecting ntopng or ClickHouse need immediate awareness.
INSERT INTO wazuh.alert_rules VALUES
('system-errors', 800, 7, ['syslog', 'kernel', 'system_error'], 0,
 '[WARN] System error digest on {agent_name}',
 1, 'OOM kills, disk full, kernel panics, hardware errors – risk to capture continuity', now());
@
-- 15. Wazuh policy / compliance violations (PCI-DSS, GDPR)
--     If ntopng is deployed in a regulated environment or processes
--     payment-adjacent traffic, compliance alerts should surface separately.
INSERT INTO wazuh.alert_rules VALUES
('compliance-violation', 900, 5, ['pci_dss', 'gdpr', 'hipaa', 'nist'], 0,
 '[COMPLIANCE] Policy violation digest',
 1, 'Regulatory framework violations flagged by Wazuh decoders', now());
@
-- 16. High-severity catch-all
--     Safety net: any level 10+ event that did not match a specific rule
--     above still gets batched and sent. Helps discover new event types
--     that warrant their own rule entry.
INSERT INTO wazuh.alert_rules VALUES
('high-level-catchall', 9000, 10, [], 0,
 '[HIGH] Unclassified high-severity alert digest',
 1, 'Safety net for level 10+ events not matched by any specific rule above', now());
@
