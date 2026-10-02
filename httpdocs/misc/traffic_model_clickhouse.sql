-- MODEL_TYPE encoding:
--   1 = working-hours bidirectional      2 = non-working-hours bidirectional
--   3 = working-hours unidirectional     4 = non-working-hours unidirectional
-- Working hours = 09:00 <= t < 18:00 (yesterday); non-working = the rest of yesterday.
-- Average KB/flow can be derived at read time: sum(TOT_KB) / sum(NUM_FLOWS)

CREATE TABLE IF NOT EXISTS `traffic_model_daily_v4` (
`WHEN` Date,
`IPV4_SRC_ADDR` IPv4,
`IPV4_DST_ADDR` IPv4,
`L7_PROTO` UInt16,
`IP_DST_PORT` UInt16,
`PROTOCOL` UInt8,
`MODEL_TYPE` UInt8,
`NUM_FLOWS` UInt64,
`TOT_KB` UInt64
)
ENGINE = SummingMergeTree((NUM_FLOWS, TOT_KB))
PARTITION BY toYYYYMM(WHEN)
ORDER BY (WHEN, L7_PROTO, IP_DST_PORT, PROTOCOL, IPV4_SRC_ADDR, IPV4_DST_ADDR, MODEL_TYPE)
TTL WHEN + INTERVAL 90 DAY; -- 3 months retention

@

CREATE TABLE IF NOT EXISTS `traffic_model_daily_v6` (
`WHEN` Date,
`IPV6_SRC_ADDR` IPv6,
`IPV6_DST_ADDR` IPv6,
`L7_PROTO` UInt16,
`IP_DST_PORT` UInt16,
`PROTOCOL` UInt8,
`MODEL_TYPE` UInt8,
`NUM_FLOWS` UInt64,
`TOT_KB` UInt64
)
ENGINE = SummingMergeTree((NUM_FLOWS, TOT_KB))
PARTITION BY toYYYYMM(WHEN)
ORDER BY (WHEN, L7_PROTO, IP_DST_PORT, PROTOCOL, IPV6_SRC_ADDR, IPV6_DST_ADDR, MODEL_TYPE)
TTL WHEN + INTERVAL 90 DAY; -- 3 months retention

@

-- IPv4: one scan of yesterday's flows produces all 4 model types
INSERT INTO traffic_model_daily_v4
SELECT
    today() AS WHEN,
    IPV4_SRC_ADDR,
    IPV4_DST_ADDR,
    L7_PROTO,
    IP_DST_PORT,
    PROTOCOL,
    -- (bidirectional ? 0 : 2) + (working hours ? 1 : 2)
    toUInt8(if(DST2SRC_PACKETS > 0, 0, 2) + if(toHour(FIRST_SEEN) BETWEEN 9 AND 17, 1, 2)) AS MODEL_TYPE,
    count() AS NUM_FLOWS,
    toUInt64(intDiv(sum(TOTAL_BYTES), 1024)) AS TOT_KB
FROM flows
WHERE CLIENT_LOCATION = 1
  AND SERVER_LOCATION = 1
  AND IP_PROTOCOL_VERSION = 4
  AND FIRST_SEEN >= toDateTime(yesterday())
  AND FIRST_SEEN <  toDateTime(today())
GROUP BY IPV4_SRC_ADDR, IPV4_DST_ADDR, L7_PROTO, IP_DST_PORT, PROTOCOL, MODEL_TYPE;

@

-- IPv6: same, excluding link-local (fe80::/10) on either side
INSERT INTO traffic_model_daily_v6
SELECT
    today() AS WHEN,
    IPV6_SRC_ADDR,
    IPV6_DST_ADDR,
    L7_PROTO,
    IP_DST_PORT,
    PROTOCOL,
    toUInt8(if(DST2SRC_PACKETS > 0, 0, 2) + if(toHour(FIRST_SEEN) BETWEEN 9 AND 17, 1, 2)) AS MODEL_TYPE,
    count() AS NUM_FLOWS,
    toUInt64(intDiv(sum(TOTAL_BYTES), 1024)) AS TOT_KB
FROM flows
WHERE CLIENT_LOCATION = 1
  AND SERVER_LOCATION = 1
  AND IP_PROTOCOL_VERSION = 6
  AND FIRST_SEEN >= toDateTime(yesterday())
  AND FIRST_SEEN <  toDateTime(today())
  AND NOT (IPV6_SRC_ADDR BETWEEN toIPv6('fe80::') AND toIPv6('febf:ffff:ffff:ffff:ffff:ffff:ffff:ffff'))
  AND NOT (IPV6_DST_ADDR BETWEEN toIPv6('fe80::') AND toIPv6('febf:ffff:ffff:ffff:ffff:ffff:ffff:ffff'))
GROUP BY IPV6_SRC_ADDR, IPV6_DST_ADDR, L7_PROTO, IP_DST_PORT, PROTOCOL, MODEL_TYPE;
