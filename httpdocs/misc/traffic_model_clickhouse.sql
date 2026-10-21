-- MODEL_TYPE encoding:
--   1 = working-hours bidirectional      2 = non-working-hours bidirectional
--   3 = working-hours unidirectional     4 = non-working-hours unidirectional
-- Working hours = 09:00 <= t < 18:00 (yesterday); non-working = the rest of yesterday.
-- AVG_KB_PER_FLOW / STDDEV_KB_PER_FLOW are plain Float64 (population stddev), computed once per key at insert time.
-- They are NOT summed by SummingMergeTree: insert each (WHEN, key) only once per day.

-- DROP TABLE `traffic_model_daily_v4`;
-- DROP TABLE `traffic_model_daily_v6`;

CREATE TABLE IF NOT EXISTS `traffic_model_daily_v4` (
`WHEN` Date,
`INTERFACE_ID` UInt16,
`IPV4_SRC_ADDR` IPv4,
`IPV4_DST_ADDR` IPv4,
`L7_PROTO` UInt16,
`IP_DST_PORT` UInt16,
`PROTOCOL` UInt8,
`MODEL_TYPE` UInt8,
`NUM_FLOWS` UInt64,
`TOT_KB` Float64,
`AVG_KB_PER_FLOW` Float64,
`STDDEV_KB_PER_FLOW` Float64
)
ENGINE = SummingMergeTree((NUM_FLOWS, TOT_KB))
PARTITION BY toYYYYMM(WHEN)
ORDER BY (WHEN, INTERFACE_ID, L7_PROTO, IP_DST_PORT, PROTOCOL, IPV4_SRC_ADDR, IPV4_DST_ADDR, MODEL_TYPE);

@

CREATE TABLE IF NOT EXISTS `traffic_model_daily_v6` (
`WHEN` Date,
`INTERFACE_ID` UInt16,
`IPV6_SRC_ADDR` IPv6,
`IPV6_DST_ADDR` IPv6,
`L7_PROTO` UInt16,
`IP_DST_PORT` UInt16,
`PROTOCOL` UInt8,
`MODEL_TYPE` UInt8,
`NUM_FLOWS` UInt64,
`TOT_KB` Float64,
`AVG_KB_PER_FLOW` Float64,
`STDDEV_KB_PER_FLOW` Float64
)
ENGINE = SummingMergeTree((NUM_FLOWS, TOT_KB))
PARTITION BY toYYYYMM(WHEN)
ORDER BY (WHEN, INTERFACE_ID, L7_PROTO, IP_DST_PORT, PROTOCOL, IPV6_SRC_ADDR, IPV6_DST_ADDR, MODEL_TYPE);

@

-- Daily server model: which hosts acted as which type of server (see scripts/lua/modules/server_types.lua for the enum)
--
-- MODEL_TYPE encoding (same as traffic_model_daily_*, bidirectional only):
--   1 = working-hours bidirectional      2 = non-working-hours bidirectional
-- SERVER_TYPE: server_types.lua server_type_id (1 DNS, 2 NTP, 3 DHCP, 4 SMTP, 5 FTP, 6 Windows DC, 7 SSH, 8 PowerShell, 9 Gateway)
-- Insert each (WHEN, key) only once per day: the table is a SummingMergeTree.

-- DROP TABLE `server_model_daily_v4`;
-- DROP TABLE `server_model_daily_v6`;

CREATE TABLE IF NOT EXISTS `server_model_daily_v4` (
`WHEN` Date,
`INTERFACE_ID` UInt16,
`IPV4_ADDR` IPv4,
`MODEL_TYPE` UInt8,
`SERVER_TYPE` UInt8,
`NUM_FLOWS` UInt64,
`TOT_KB` Float64
)
ENGINE = SummingMergeTree((NUM_FLOWS, TOT_KB))
PARTITION BY toYYYYMM(WHEN)
ORDER BY (WHEN, INTERFACE_ID, SERVER_TYPE, IPV4_ADDR, MODEL_TYPE);

@

CREATE TABLE IF NOT EXISTS `server_model_daily_v6` (
`WHEN` Date,
`INTERFACE_ID` UInt16,
`IPV6_ADDR` IPv6,
`MODEL_TYPE` UInt8,
`SERVER_TYPE` UInt8,
`NUM_FLOWS` UInt64,
`TOT_KB` Float64
)
ENGINE = SummingMergeTree((NUM_FLOWS, TOT_KB))
PARTITION BY toYYYYMM(WHEN)
ORDER BY (WHEN, INTERFACE_ID, SERVER_TYPE, IPV6_ADDR, MODEL_TYPE);

@

-- IPv4: one scan of yesterday's flows produces all 4 model types
INSERT INTO traffic_model_daily_v4
SELECT
    yesterday() AS WHEN,
    INTERFACE_ID,
    IPV4_SRC_ADDR,
    IPV4_DST_ADDR,
    L7_PROTO,
    IP_DST_PORT,
    PROTOCOL,
    -- (bidirectional ? 0 : 2) + (working hours ? 1 : 2)
    toUInt8(if(DST2SRC_PACKETS > 0, 0, 2) + if(toHour(FIRST_SEEN) BETWEEN 9 AND 17, 1, 2)) AS MODEL_TYPE,
    count() AS NUM_FLOWS,
    sum(TOTAL_BYTES) / 1024 AS TOT_KB,
    avg(TOTAL_BYTES) / 1024 AS AVG_KB_PER_FLOW,
    stddevPop(TOTAL_BYTES) / 1024 AS STDDEV_KB_PER_FLOW
FROM flows
WHERE CLIENT_LOCATION = 1
  AND SERVER_LOCATION = 1
  AND IP_PROTOCOL_VERSION = 4
  AND FIRST_SEEN >= toDateTime(yesterday())
  AND FIRST_SEEN <  toDateTime(today())
GROUP BY INTERFACE_ID, IPV4_SRC_ADDR, IPV4_DST_ADDR, L7_PROTO, IP_DST_PORT, PROTOCOL, MODEL_TYPE;

@

-- IPv6: same, excluding link-local (fe80::/10) on either side
INSERT INTO traffic_model_daily_v6
SELECT
    yesterday() AS WHEN,
    INTERFACE_ID,
    IPV6_SRC_ADDR,
    IPV6_DST_ADDR,
    L7_PROTO,
    IP_DST_PORT,
    PROTOCOL,
    toUInt8(if(DST2SRC_PACKETS > 0, 0, 2) + if(toHour(FIRST_SEEN) BETWEEN 9 AND 17, 1, 2)) AS MODEL_TYPE,
    count() AS NUM_FLOWS,
    sum(TOTAL_BYTES) / 1024 AS TOT_KB,
    avg(TOTAL_BYTES) / 1024 AS AVG_KB_PER_FLOW,
    stddevPop(TOTAL_BYTES) / 1024 AS STDDEV_KB_PER_FLOW
FROM flows
WHERE CLIENT_LOCATION = 1
  AND SERVER_LOCATION = 1
  AND IP_PROTOCOL_VERSION = 6
  AND FIRST_SEEN >= toDateTime(yesterday())
  AND FIRST_SEEN <  toDateTime(today())
  AND NOT (IPV6_SRC_ADDR BETWEEN toIPv6('fe80::') AND toIPv6('febf:ffff:ffff:ffff:ffff:ffff:ffff:ffff'))
  AND NOT (IPV6_DST_ADDR BETWEEN toIPv6('fe80::') AND toIPv6('febf:ffff:ffff:ffff:ffff:ffff:ffff:ffff'))
GROUP BY INTERFACE_ID, IPV6_SRC_ADDR, IPV6_DST_ADDR, L7_PROTO, IP_DST_PORT, PROTOCOL, MODEL_TYPE;

@

-- Detect server type based on the daily traffic model for IPV4 and IPV6

-- 1 DNS - IPv4
INSERT INTO server_model_daily_v4
  SELECT
      WHEN,
      INTERFACE_ID,
      IPV4_DST_ADDR AS ADDR,
      MODEL_TYPE,
      toUInt8(1) AS SERVER_TYPE,
      sum(NUM_FLOWS) AS FLOWS,
      sum(TOT_KB) AS KB
  FROM traffic_model_daily_v4
WHERE WHEN = yesterday()
  AND MODEL_TYPE IN (1, 2)
  AND L7_PROTO IN (5)
GROUP BY WHEN, INTERFACE_ID, ADDR, MODEL_TYPE;

@

-- 1 DNS - IPv6
INSERT INTO server_model_daily_v6
SELECT
    WHEN,
    INTERFACE_ID,
    IPV6_DST_ADDR AS ADDR,
    MODEL_TYPE,
    toUInt8(1) AS SERVER_TYPE,
    sum(NUM_FLOWS) AS FLOWS,
    sum(TOT_KB) AS KB
FROM traffic_model_daily_v6
WHERE WHEN = yesterday()
  AND MODEL_TYPE IN (1, 2)
  AND L7_PROTO IN (5)
GROUP BY WHEN, INTERFACE_ID, ADDR, MODEL_TYPE;

@

-- 2 NTP - IPv4
INSERT INTO server_model_daily_v4
SELECT
    WHEN,
    INTERFACE_ID,
    IPV4_DST_ADDR AS ADDR,
    MODEL_TYPE,
    toUInt8(2) AS SERVER_TYPE,
    sum(NUM_FLOWS) AS FLOWS,
    sum(TOT_KB) AS KB
FROM traffic_model_daily_v4
WHERE WHEN = yesterday()
  AND MODEL_TYPE IN (1, 2)
  AND L7_PROTO IN (9)
GROUP BY WHEN, INTERFACE_ID, ADDR, MODEL_TYPE;

@

-- 2 NTP - IPv6
INSERT INTO server_model_daily_v6
SELECT
    WHEN,
    INTERFACE_ID,
    IPV6_DST_ADDR AS ADDR,
    MODEL_TYPE,
    toUInt8(2) AS SERVER_TYPE,
    sum(NUM_FLOWS) AS FLOWS,
    sum(TOT_KB) AS KB
FROM traffic_model_daily_v6
WHERE WHEN = yesterday()
  AND MODEL_TYPE IN (1, 2)
  AND L7_PROTO IN (9)
GROUP BY WHEN, INTERFACE_ID, ADDR, MODEL_TYPE;

@

-- 3 DHCP (DHCP, DHCPV6) - IPv4
INSERT INTO server_model_daily_v4
SELECT
    WHEN,
    INTERFACE_ID,
    IPV4_DST_ADDR AS ADDR,
    MODEL_TYPE,
    toUInt8(3) AS SERVER_TYPE,
    sum(NUM_FLOWS) AS FLOWS,
    sum(TOT_KB) AS KB
FROM traffic_model_daily_v4
WHERE WHEN = yesterday()
  AND MODEL_TYPE IN (1, 2)
  AND L7_PROTO IN (18,103)
GROUP BY WHEN, INTERFACE_ID, ADDR, MODEL_TYPE;

@

-- 3 DHCP (DHCP, DHCPV6) - IPv6
INSERT INTO server_model_daily_v6
SELECT
    WHEN,
    INTERFACE_ID,
    IPV6_DST_ADDR AS ADDR,
    MODEL_TYPE,
    toUInt8(3) AS SERVER_TYPE,
    sum(NUM_FLOWS) AS FLOWS,
    sum(TOT_KB) AS KB
FROM traffic_model_daily_v6
WHERE WHEN = yesterday()
  AND MODEL_TYPE IN (1, 2)
  AND L7_PROTO IN (18,103)
GROUP BY WHEN, INTERFACE_ID, ADDR, MODEL_TYPE;

@

-- 4 SMTP (SMTP, SMTPS) - IPv4
INSERT INTO server_model_daily_v4
SELECT
    WHEN,
    INTERFACE_ID,
    IPV4_DST_ADDR AS ADDR,
    MODEL_TYPE,
    toUInt8(4) AS SERVER_TYPE,
    sum(NUM_FLOWS) AS FLOWS,
    sum(TOT_KB) AS KB
FROM traffic_model_daily_v4
WHERE WHEN = yesterday()
  AND MODEL_TYPE IN (1, 2)
  AND L7_PROTO IN (3,29)
GROUP BY WHEN, INTERFACE_ID, ADDR, MODEL_TYPE;

@

-- 4 SMTP (SMTP, SMTPS) - IPv6
INSERT INTO server_model_daily_v6
SELECT
    WHEN,
    INTERFACE_ID,
    IPV6_DST_ADDR AS ADDR,
    MODEL_TYPE,
    toUInt8(4) AS SERVER_TYPE,
    sum(NUM_FLOWS) AS FLOWS,
    sum(TOT_KB) AS KB
FROM traffic_model_daily_v6
WHERE WHEN = yesterday()
  AND MODEL_TYPE IN (1, 2)
  AND L7_PROTO IN (3,29)
GROUP BY WHEN, INTERFACE_ID, ADDR, MODEL_TYPE;

@

-- 5 FTP (control, data) - IPv4
INSERT INTO server_model_daily_v4
SELECT
    WHEN,
    INTERFACE_ID,
    IPV4_DST_ADDR AS ADDR,
    MODEL_TYPE,
    toUInt8(5) AS SERVER_TYPE,
    sum(NUM_FLOWS) AS FLOWS,
    sum(TOT_KB) AS KB
FROM traffic_model_daily_v4
WHERE WHEN = yesterday()
  AND MODEL_TYPE IN (1, 2)
  AND L7_PROTO IN (1,175)
GROUP BY WHEN, INTERFACE_ID, ADDR, MODEL_TYPE;

@

-- 5 FTP (control, data) - IPv6
INSERT INTO server_model_daily_v6
SELECT
    WHEN,
    INTERFACE_ID,
    IPV6_DST_ADDR AS ADDR,
    MODEL_TYPE,
    toUInt8(5) AS SERVER_TYPE,
    sum(NUM_FLOWS) AS FLOWS,
    sum(TOT_KB) AS KB
FROM traffic_model_daily_v6
WHERE WHEN = yesterday()
  AND MODEL_TYPE IN (1, 2)
  AND L7_PROTO IN (1,175)
GROUP BY WHEN, INTERFACE_ID, ADDR, MODEL_TYPE;

@

-- 6 Windows Domain Controller (Kerberos AND LDAP) - IPv4
INSERT INTO server_model_daily_v4
SELECT
    WHEN,
    INTERFACE_ID,
    IPV4_DST_ADDR AS ADDR,
    MODEL_TYPE,
    toUInt8(6) AS SERVER_TYPE,
    sum(NUM_FLOWS) AS FLOWS,
    sum(TOT_KB) AS KB
FROM traffic_model_daily_v4
WHERE WHEN = yesterday()
  AND MODEL_TYPE IN (1, 2)
  AND L7_PROTO IN (111,112)
  AND IPV4_DST_ADDR IN (
      SELECT IPV4_DST_ADDR
      FROM traffic_model_daily_v4
      WHERE WHEN = yesterday()
        AND MODEL_TYPE IN (1, 2)
        AND L7_PROTO IN (111,112)
      GROUP BY IPV4_DST_ADDR
      HAVING uniqExact(L7_PROTO) = 2
  )
GROUP BY WHEN, INTERFACE_ID, ADDR, MODEL_TYPE;

@

-- 6 Windows Domain Controller (Kerberos AND LDAP) - IPv6
INSERT INTO server_model_daily_v6
SELECT
    WHEN,
    INTERFACE_ID,
    IPV6_DST_ADDR AS ADDR,
    MODEL_TYPE,
    toUInt8(6) AS SERVER_TYPE,
    sum(NUM_FLOWS) AS FLOWS,
    sum(TOT_KB) AS KB
FROM traffic_model_daily_v6
WHERE WHEN = yesterday()
  AND MODEL_TYPE IN (1, 2)
  AND L7_PROTO IN (111,112)
  AND IPV6_DST_ADDR IN (
      SELECT IPV6_DST_ADDR
      FROM traffic_model_daily_v6
      WHERE WHEN = yesterday()
        AND MODEL_TYPE IN (1, 2)
        AND L7_PROTO IN (111,112)
      GROUP BY IPV6_DST_ADDR
      HAVING uniqExact(L7_PROTO) = 2
  )
GROUP BY WHEN, INTERFACE_ID, ADDR, MODEL_TYPE;

@

-- 7 SSH - IPv4
INSERT INTO server_model_daily_v4
SELECT
    WHEN,
    INTERFACE_ID,
    IPV4_DST_ADDR AS ADDR,
    MODEL_TYPE,
    toUInt8(7) AS SERVER_TYPE,
    sum(NUM_FLOWS) AS FLOWS,
    sum(TOT_KB) AS KB
FROM traffic_model_daily_v4
WHERE WHEN = yesterday()
  AND MODEL_TYPE IN (1, 2)
  AND L7_PROTO IN (92)
GROUP BY WHEN, INTERFACE_ID, ADDR, MODEL_TYPE;

@

-- 7 SSH - IPv6
INSERT INTO server_model_daily_v6
SELECT
    WHEN,
    INTERFACE_ID,
    IPV6_DST_ADDR AS ADDR,
    MODEL_TYPE,
    toUInt8(7) AS SERVER_TYPE,
    sum(NUM_FLOWS) AS FLOWS,
    sum(TOT_KB) AS KB
FROM traffic_model_daily_v6
WHERE WHEN = yesterday()
  AND MODEL_TYPE IN (1, 2)
  AND L7_PROTO IN (92)
GROUP BY WHEN, INTERFACE_ID, ADDR, MODEL_TYPE;

@

-- 8 PowerShell - IPv4
INSERT INTO server_model_daily_v4
SELECT
    WHEN,
    INTERFACE_ID,
    IPV4_DST_ADDR AS ADDR,
    MODEL_TYPE,
    toUInt8(8) AS SERVER_TYPE,
    sum(NUM_FLOWS) AS FLOWS,
    sum(TOT_KB) AS KB
FROM traffic_model_daily_v4
WHERE WHEN = yesterday()
  AND MODEL_TYPE IN (1, 2)
  AND L7_PROTO IN (496)
GROUP BY WHEN, INTERFACE_ID, ADDR, MODEL_TYPE;

@

-- 8 PowerShell - IPv6
INSERT INTO server_model_daily_v6
SELECT
    WHEN,
    INTERFACE_ID,
    IPV6_DST_ADDR AS ADDR,
    MODEL_TYPE,
    toUInt8(8) AS SERVER_TYPE,
    sum(NUM_FLOWS) AS FLOWS,
    sum(TOT_KB) AS KB
FROM traffic_model_daily_v6
WHERE WHEN = yesterday()
  AND MODEL_TYPE IN (1, 2)
  AND L7_PROTO IN (496)
GROUP BY WHEN, INTERFACE_ID, ADDR, MODEL_TYPE;
