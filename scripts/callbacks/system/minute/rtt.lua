--
-- (C) 2013-19 - ntop.org
--

local ts_utils = require("ts_utils_core")

local probe = {
  name = "RTT Monitor",
  description = "Monitors the round trip time of an host",
}

-- ##############################################

function probe.isEnabled()
  return(true)
end

-- ##############################################

function probe.loadSchemas(ts_utils)
  local schema

  schema = ts_utils.newSchema("host:rtt", {label = i18n("graphs.num_ms_rtt"), metrics_type = ts_utils.metrics.gauge})
  schema:addTag("host")
  schema:addMetric("millis_rtt")
end

-- ##############################################

function probe.runTask(when, ts_utils)
  local hosts = ntop.getHashAllCache("ntopng.prefs.rtt_hosts")

  if table.empty(hosts) then
    return
  end

  for host, max_rtt in pairs(hosts) do
    ntop.pingHost(host)
  end

  ntop.msleep(1000) -- wait results for 1 second

  local res = ntop.collectPingResults()

  for host, rtt in pairs(res) do
    local max_rtt = hosts[address]
    ts_utils.append("host:rtt", {host = host, millis_rtt = rtt}, when)

    if(max_rtt and (rtt > max_rtt)) then
      -- TODO alert
    end
  end
end

-- ##############################################

return probe
