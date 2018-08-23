require "lua_utils"

local rrd_dump = {}
local callback_utils = require("callback_utils")
local ts_utils = require "ts_utils_core"
require "ts_5min"

-- ########################################################

function rrd_dump.host_update_stats_rrds(when, hostname, host, ifstats, verbose)
  ts_utils.append("host:traffic", {ifid=ifstats.id, host=hostname,
            bytes_sent=host["bytes.sent"], bytes_rcvd=host["bytes.rcvd"]}, when, verbose)

  -- Number of flows
  ts_utils.append("host:flows", {ifid=ifstats.id, host=hostname,
            num_flows=host["active_flows.as_client"] + host["active_flows.as_server"]}, when, verbose)

  -- L4 Protocols
  for id, _ in ipairs(l4_keys) do
    k = l4_keys[id][2]
    if((host[k..".bytes.sent"] ~= nil) and (host[k..".bytes.rcvd"] ~= nil)) then
      ts_utils.append("host:l4protos", {ifid=ifstats.id, host=hostname,
                l4proto=tostring(k), bytes_sent=host[k..".bytes.sent"], bytes_rcvd=host[k..".bytes.rcvd"]}, when, verbose)
    else
      -- L2 host
      --io.write("Discarding "..k.."@"..hostname.."\n")
    end
  end
end

function rrd_dump.host_update_ndpi_rrds(when, hostname, host, ifstats, verbose)
  -- nDPI Protocols
  for k in pairs(host["ndpi"] or {}) do
    ts_utils.append("host:ndpi", {ifid=ifstats.id, host=hostname, protocol=k,
              bytes_sent=host["ndpi"][k]["bytes.sent"], bytes_rcvd=host["ndpi"][k]["bytes.rcvd"]}, when, verbose)
  end
end

function rrd_dump.host_update_categories_rrds(when, hostname, host, ifstats, verbose)
  -- nDPI Protocol CATEGORIES
  for k, cat in pairs(host["ndpi_categories"] or {}) do
    ts_utils.append("host:ndpi_categories", {ifid=ifstats.id, host=hostname, category=k,
              bytes=cat["bytes"]}, when, verbose)
  end
end

-- ########################################################

function rrd_dump.host_update_rrd(when, hostname, host, ifstats, verbose, config)
  -- Crunch additional stats for local hosts only
  if config.host_rrd_creation ~= "0" then
    -- Traffic stats
    if(config.host_rrd_creation == "1") then
      rrd_dump.host_update_stats_rrds(when, hostname, host, ifstats, verbose)
    end

    if(config.host_ndpi_timeseries_creation == "per_protocol" or config.host_ndpi_timeseries_creation == "both") then
      rrd_dump.host_update_ndpi_rrds(when, hostname, host, ifstats, verbose)
    end

    if(config.host_ndpi_timeseries_creation == "per_category" or config.host_ndpi_timeseries_creation == "both") then
      rrd_dump.host_update_categories_rrds(when, hostname, host, ifstats, verbose)
    end
  end
end

-- ########################################################

function rrd_dump.getConfig()
  local config = {}

  config.host_rrd_creation = ntop.getPref("ntopng.prefs.host_rrd_creation")
  config.host_ndpi_timeseries_creation = ntop.getPref("ntopng.prefs.host_ndpi_timeseries_creation")

  -- ########################################################

  -- Local hosts RRD creation is on, with no nDPI rrd creation
  if isEmptyString(config.host_rrd_creation) then config.host_rrd_creation = "1" end
  if isEmptyString(config.host_ndpi_timeseries_creation) then config.host_ndpi_timeseries_creation = "none" end

  return config
end

-- ########################################################

function rrd_dump.run_30sec_dump(_ifname, ifstats, config, when, time_threshold, verbose)
  local is_rrd_creation_enabled = (ntop.getPref("ntopng.prefs.ifid_"..ifstats.id..".interface_rrd_creation") ~= "false")
  local is_30sec_dump_enabled = is_rrd_creation_enabled and callback_utils.is30SecDumpEnabled()
  local num_processed_hosts = 0
  local min_instant = when - (when % 30) - 30

  if not is_30sec_dump_enabled then
    return
  end

  local in_time = callback_utils.foreachLocalRRDHost(_ifname, time_threshold, function (hostname, host_ts)
    for _, host_point in ipairs(host_ts) do
      local instant = host_point.instant

      if instant >= min_instant then
        rrd_dump.host_update_rrd(instant, hostname, host_point, ifstats, verbose, config)
      end
    end

    num_processed_hosts = num_processed_hosts + 1
  end)

  --tprint("Dump of ".. num_processed_hosts .. ": completed in " .. (os.time() - when) .. " seconds")
end

-- ########################################################

return rrd_dump
