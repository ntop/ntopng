/* Sample data for the wazuh_alert_rules table */

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
INSERT INTO wazuh_alert_rules VALUES
('critical-any', 10, 12, [], 1,
 '[CRITICAL] {rule_description} on {agent_name}',
 1, 'Catch-all for any level 12+ alert – sent immediately', now());
@
-- 2. Rootkit / trojan / hidden process detection (rootcheck)
INSERT INTO wazuh_alert_rules VALUES
('rootkit-detected', 20, 7, ['rootcheck'], 1,
 '[CRITICAL] Rootkit/trojan detected on {agent_name}',
 1, 'Wazuh rootcheck positive hit – treat as confirmed compromise until proven otherwise', now());
@
-- 3. Wazuh agent stopped communicating
--    An agent going silent may mean the host is down, the Wazuh process
--    was killed, or an attacker is suppressing telemetry.
INSERT INTO wazuh_alert_rules VALUES
('agent-disconnected', 30, 7, ['ossec', 'agent_disconnected'], 1,
 '[CRITICAL] Wazuh agent disconnected: {agent_name}',
 1, 'Agent heartbeat lost – investigate host availability and possible tamper', now());
@
-- 4. Privilege escalation (sudo / su / setuid abuse)
--    Important for ntopng hosts where capture processes run as root
--    or with CAP_NET_ADMIN; unexpected escalation is a red flag.
INSERT INTO wazuh_alert_rules VALUES
('privilege-escalation', 40, 7, ['syslog', 'sudo', 'pam'], 1,
 '[CRITICAL] Privilege escalation on {agent_name} by user {username}',
 1, 'sudo/su/setuid abuse or unexpected privilege gain', now());
@
-- 5. Web shell / command injection via web server
--    ntopng exposes an HTTPS management interface; this covers
--    any web-layer attack that reaches command execution.
INSERT INTO wazuh_alert_rules VALUES
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
INSERT INTO wazuh_alert_rules VALUES
('ssh-brute-force', 100, 5,
 ['authentication_failed', 'authentication_failures', 'sshd'], 0,
 '[WARN] SSH / PAM authentication failures digest',
 1, 'Batches all SSH/PAM login failures – review src IPs in digest for targeting', now());
@
-- 7. Successful logins (especially after previous failures)
--    A successful login is not inherently bad, but tracking them lets
--    you correlate "brute force then success" sequences in the digest.
INSERT INTO wazuh_alert_rules VALUES
('auth-success', 110, 5, ['authentication_success'], 0,
 '[INFO] Successful authentication events digest',
 1, 'Tracks successful logins for correlation with prior failure events', now());
@
-- 8. File integrity monitoring – configuration / binary changes (FIM)
--    ntopng ships signed binaries (as you know well); any unexpected
--    change to /usr/bin/ntopng, /etc/ntopng, or nDPI libraries is critical.
INSERT INTO wazuh_alert_rules VALUES
('fim-changes', 200, 7, ['syscheck'], 0,
 '[WARN] File integrity changes digest',
 1, 'FIM hits – pay attention to ntopng/nDPI binaries and config files', now());
@
-- 9. Vulnerability detections (Wazuh vulnerability scanner / CVE feed)
INSERT INTO wazuh_alert_rules VALUES
('vulnerability-detected', 300, 7, ['vulnerability-detector'], 0,
 '[WARN] Vulnerability detections digest',
 1, 'CVE matches from Wazuh vuln scanner – triage by severity and CVSS score', now());
@
-- 10. Suspicious process / unexpected command execution
--     Catches shells spawned from web servers, cron abuse, or unusual
--     interpreters (python, perl, php) run from ntopng working directories.
INSERT INTO wazuh_alert_rules VALUES
('suspicious-process', 400, 6, ['process_monitor', 'audit'], 0,
 '[WARN] Suspicious process execution digest on {agent_name}',
 1, 'Unexpected binaries or interpreters; check parent process chain', now());
@
-- 11. Network scan / IDS events
--     Relevant because ntopng/nDPI hosts are often reachable from the
--     network being monitored; port scans against them deserve attention.
--     Also covers Suricata/Snort signatures if forwarded via Wazuh.
INSERT INTO wazuh_alert_rules VALUES
('network-scan-ids', 500, 5, ['ids', 'suricata', 'snort', 'network'], 0,
 '[WARN] Network scan / IDS signature events digest',
 1, 'Port scans and IDS hits batched – look for repeated src IPs targeting management ports', now());
@
-- 12. Firewall / iptables block spikes
--     Useful for detecting DDoS attempts against the capture interface
--     or management plane, and for spotting misconfigured firewall rules.
INSERT INTO wazuh_alert_rules VALUES
('firewall-drops', 600, 5, ['firewall', 'iptables', 'pf'], 0,
 '[WARN] Firewall drop events digest',
 1, 'Blocked traffic – volume spikes may indicate DDoS or misconfiguration', now());
@
-- 13. Docker / container anomalies
--     ntopng ships as Docker containers; privileged containers, unexpected
--     image pulls, or runtime restarts should all be tracked.
INSERT INTO wazuh_alert_rules VALUES
('container-anomaly', 700, 6, ['docker', 'container'], 0,
 '[WARN] Container anomaly digest',
 1, 'Unexpected container starts, privileged flags, image changes on ntopng containers', now());
@
-- 14. System-level errors (OOM killer, disk full, hardware faults)
--     High-bandwidth capture means storage and memory pressure are real;
--     OOM kills affecting ntopng or ClickHouse need immediate awareness.
INSERT INTO wazuh_alert_rules VALUES
('system-errors', 800, 7, ['syslog', 'kernel', 'system_error'], 0,
 '[WARN] System error digest on {agent_name}',
 1, 'OOM kills, disk full, kernel panics, hardware errors – risk to capture continuity', now());
@
-- 15. Wazuh policy / compliance violations (PCI-DSS, GDPR)
--     If ntopng is deployed in a regulated environment or processes
--     payment-adjacent traffic, compliance alerts should surface separately.
INSERT INTO wazuh_alert_rules VALUES
('compliance-violation', 900, 5, ['pci_dss', 'gdpr', 'hipaa', 'nist'], 0,
 '[COMPLIANCE] Policy violation digest',
 1, 'Regulatory framework violations flagged by Wazuh decoders', now());
@
-- 16. High-severity catch-all
--     Safety net: any level 10+ event that did not match a specific rule
--     above still gets batched and sent. Helps discover new event types
--     that warrant their own rule entry.
INSERT INTO wazuh_alert_rules VALUES
('high-level-catchall', 9000, 10, [], 0,
 '[HIGH] Unclassified high-severity alert digest',
 1, 'Safety net for level 10+ events not matched by any specific rule above', now());
@
