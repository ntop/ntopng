/* Keep table definitions in sync with: */
/* - httpdocs/misc/db_schema_syslog.sql */

/* Stores table definition for syslog ingestion */

CREATE TABLE IF NOT EXISTS `syslog_rules` ON CLUSTER '$CLUSTER' (
    id           String        COMMENT 'Unique syslog rule identifier',
    enabled      UInt8         DEFAULT 1   COMMENT '0 = disabled',
    min_severity UInt8         DEFAULT 7   COMMENT 'Least severe level matched (inclusive): the rule matches messages with severity <= min_severity. 0 = Emergency, 1 = Alert, 2 = Critical, 3 = Error, 4 = Warning, 5 = Notice, 6 = Informational, 7 = Debug (any severity)',
    source       String        DEFAULT ''  COMMENT 'If not empty, sender IP address or CIDR network (e.g. 10.0.0.1 or 10.0.0.0/24) the message must come from',
    pattern      String        DEFAULT ''  COMMENT 'If not empty, RE2 regular expression that must match the message',
    comment      String        DEFAULT ''  COMMENT 'Free-text description',
    discard      UInt8         DEFAULT 0   COMMENT '1 = if case of match this rule discards the message (i.e. it is not logged to the DB)'
)
ENGINE = ReplicatedReplacingMergeTree('/clickhouse/{cluster}/tables/{database}/{table}', '{replica}', min_severity)
ORDER BY id;

@
ALTER TABLE `syslog_rules` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `discard` UInt8 DEFAULT 0 COMMENT '1 = if case of match this rule discards the message (i.e. it is not logged to the DB)' AFTER comment;
@
ALTER TABLE `syslog_rules` ON CLUSTER '$CLUSTER' ADD COLUMN IF NOT EXISTS `source` String DEFAULT '' COMMENT 'If not empty, sender IP address or CIDR network (e.g. 10.0.0.1 or 10.0.0.0/24) the message must come from' AFTER min_severity;
@

INSERT INTO syslog_rules (id, enabled, min_severity, source, pattern, comment)
SELECT '00000000-0000-4000-8000-000000000001', 1, 7, '', '', 'Default rule: store all the syslog messages'
WHERE (SELECT count() FROM syslog_rules) = 0;

@

CREATE TABLE IF NOT EXISTS syslog_messages ON CLUSTER '$CLUSTER' (
    received_at DateTime64(3, 'UTC')   COMMENT 'Time the collector received the message',
    source_ip   IPv6                   COMMENT 'Sender IP address (IPv4 stored as IPv4-mapped IPv6)',
    hostname    LowCardinality(String) DEFAULT '' COMMENT 'Hostname reported in the syslog header',
    facility    LowCardinality(String) DEFAULT '' COMMENT 'Syslog facility (e.g. auth, kern, daemon)',
    severity    UInt8                  COMMENT '0 = Emergency, 1 = Alert, 2 = Critical, 3 = Error, 4 = Warning, 5 = Notice, 6 = Informational, 7 = Debug',
    app_name    LowCardinality(String) DEFAULT '' COMMENT 'Application name (e.g. sshd), empty if not reported',
    message     String CODEC(ZSTD(3))
)
ENGINE = ReplicatedMergeTree('/clickhouse/{cluster}/tables/{database}/{table}', '{replica}')
PARTITION BY toYYYYMMDD(received_at)
ORDER BY (source_ip, received_at);
