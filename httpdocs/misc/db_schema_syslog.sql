 /* Keep table definitions in sync with: */
/* - httpdocs/misc/db_schema_syslog_cluster.sql */

/* Stores table definition for syslog ingestion */

/*
   Rules are evaluated by the collector before writing to the DB, and reloaded every 10 seconds.
   Enabled rules are an allowlist: a message is stored only if it matches at least one of them
   (when there are no enabled rules every message is stored).
   A rule matches when min_severity <= severity <= max_severity and, if set, source matches the sender IP
   (single IP or CIDR network) and, if set, pattern (RE2) matches the message.
*/
CREATE TABLE IF NOT EXISTS `syslog_rules` (
    id           String        COMMENT 'Unique syslog rule identifier',
    enabled      UInt8         DEFAULT 1   COMMENT '0 = disabled',
    min_severity UInt8         DEFAULT 0   COMMENT 'Inclusive lower bound. 0 = Emergency, 1 = Alert, 2 = Critical, 3 = Error, 4 = Warning, 5 = Notice, 6 = Informational, 7 = Debug',
    source       String        DEFAULT ''  COMMENT 'If not empty, sender IP address or CIDR network (e.g. 10.0.0.1 or 10.0.0.0/24) the message must come from',
    pattern      String        DEFAULT ''  COMMENT 'If not empty, RE2 regular expression that must match the message',
    comment      String        DEFAULT ''  COMMENT 'Free-text description',
    discard      UInt8         DEFAULT 0   COMMENT '1 = if case of match this rule discards the message (i.e. it is not logged to the DB)'
)
ENGINE = ReplacingMergeTree(updated_at, is_deleted)
ORDER BY id;

@
ALTER TABLE `syslog_rules` ADD COLUMN IF NOT EXISTS `discard` String DEFAULT '' COMMENT '1 = if case of match this rule discards the message (i.e. it is not logged to the DB)' AFTER is_deleted;
@
ALTER TABLE `syslog_rules` ADD COLUMN IF NOT EXISTS `source` String DEFAULT '' COMMENT 'If not empty, sender IP address or CIDR network (e.g. 10.0.0.1 or 10.0.0.0/24) the message must come from' AFTER min_severity;

@

/* Default rule matching every message (any severity, any sender) */
INSERT INTO syslog_rules (id, enabled, min_severity, source, pattern, comment)
SELECT '00000000-0000-4000-8000-000000000001', 1, 0, '', '', 'Default rule: store all the syslog messages'
WHERE (SELECT count() FROM syslog_rules) = 0;

@

CREATE TABLE IF NOT EXISTS `syslog_messages` (
    received_at DateTime64(3, 'UTC')   COMMENT 'Time the collector received the message',
    source_ip   IPv6                   COMMENT 'Sender IP address (IPv4 stored as IPv4-mapped IPv6)',
    hostname    LowCardinality(String) DEFAULT '' COMMENT 'Hostname reported in the syslog header',
    facility    LowCardinality(String) DEFAULT '' COMMENT 'Syslog facility (e.g. auth, kern, daemon)',
    severity    UInt8                  COMMENT '0 = Emergency, 1 = Alert, 2 = Critical, 3 = Error, 4 = Warning, 5 = Notice, 6 = Informational, 7 = Debug',
    app_name    LowCardinality(String) DEFAULT '' COMMENT 'Application name (e.g. sshd), empty if not reported',
    message     String CODEC(ZSTD(3)),
)
ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(received_at)
ORDER BY (source_ip, received_at);
