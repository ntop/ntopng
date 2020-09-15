--
-- (C) 2020 - ntop.org
--

--
-- This module implements the ICMP probe.
--

local ts_utils = require("ts_utils_core")

local do_trace = false

-- #################################################################

-- This is the script state, which must be manually cleared in the check
-- function. Can be then used in the collect_results function to match the
-- probe requests with probe replies.
local am_hosts = {}
local resolved_hosts = {}

-- #################################################################

-- The function called periodically to send the host probes.
-- hosts contains the list of hosts to probe, The table keys are
-- the hosts identifiers, whereas the table values contain host information
-- see (am_utils.key2host for the details on such format).
local function check_continuous(measurement, hosts, granularity)
  local plugins_utils = require("plugins_utils")
  local am_utils = plugins_utils.loadModule("active_monitoring", "am_utils")

  am_hosts[measurement] = {}
  resolved_hosts[measurement] = {}

  for key, host in pairs(hosts) do
    local domain_name = host.host
    local is_v6 = (host.measurement == "cicmp6")
    local ip_address = am_utils.resolveHost(domain_name, is_v6)

    if not ip_address then
      goto continue
    end

    if do_trace then
      print("[cicmp] Pinging "..ip_address.."/"..domain_name.."\n")
    end

    -- ICMP results are retrieved in batch (see below ntop.collectPingResults)
    ntop.pingHost(ip_address, measurement == "cicmp6", true --[[ continuous ICMP]])

    am_hosts[measurement][ip_address] = {
      key = key,
      info = host,
    }
    resolved_hosts[measurement][key] = {
       resolved_addr = ip_address,
    }

    ::continue::
  end
end

-- #################################################################

-- @brief Async continuous ping (ipv4 icmp)
local function check_icmp_continuous(hosts, granularity)
   check_continuous("cicmp", hosts, granularity)
end

-- #################################################################

-- @brief Async continuous ping (ipv6 icmp)
local function check_icmp6_continuous(hosts, granularity)
   check_continuous("cicmp6", hosts, granularity)
end

-- #################################################################

-- The function responsible for collecting the results.
-- It must return a table containing a list of hosts along with their retrieved
-- measurement. The keys of the table are the host key. The values have the following format:
--  table
--	resolved_addr: (optional) the resolved IP address of the host
--	value: (optional) the measurement numeric value. If unspecified, the host is still considered unreachable.
local function collect_continuous(measurement, granularity)
  -- Collect possible ICMP results
  local res = ntop.collectPingResults(measurement == "cicmp6", true --[[ continuous ICMP]])

  for host, value in pairs(res or {}) do
    local h = am_hosts[measurement][host]

    if(do_trace) then
      print("[cicmp] Reading ICMP response for host ".. host .."\n")
    end

    if h and resolved_hosts[measurement][h.key] then
      local v = resolved_hosts[measurement][h.key]

      -- Report the host as reachable with its value value
      v.value = value.response_rate

      -- Report jitter and mean
      if(value.jitter ~= nil) and (value.mean ~= nil) then
        ts_utils.append("am_host:jitter_stats_" .. granularity, {
          ifid = getSystemInterfaceId(),
          host = h.info.host,
          metric = h.info.measurement,
          latency = value.mean,
          jitter = value.jitter,
        })

        v.mean = value.mean
        v.jitter = value.jitter
      end

      if((value.min_rtt ~= nil) and (value.max_rtt ~= nil)) then
        ts_utils.append("am_host:cicmp_stats_" .. granularity, {
          ifid = getSystemInterfaceId(),
          host = h.info.host,
          metric = h.info.measurement,
          min_rtt = value.min_rtt,
          max_rtt = value.max_rtt,
        })
      end
    end
  end

  -- NOTE: unreachable hosts can still be reported in order to properly
  -- display their resolved address
  return resolved_hosts[measurement]
end

-- #################################################################

-- @brief Collect async ping results (ipv4 icmp)
local function collect_icmp_continuous(granularity)
   return collect_continuous("cicmp", granularity)
end

-- #################################################################

-- @brief Collect async ping results (ipv6 icmp)
local function collect_icmp6_continuous(granularity)
   return collect_continuous("cicmp6", granularity)
end

-- #################################################################

local function check_icmp_available()
  return(ntop.isPingAvailable())
end

-- #################################################################

local timeseries = {{
  schema="am_host:cicmp_stats",
  label=i18n("flow_details.round_trip_time"),
  metrics_labels = { i18n("graphs.min_rtt"), i18n("graphs.max_rtt") },
  value_formatter = {"NtopUtils.fmillis", "NtopUtils.fmillis"},
  split_directions = true,
  show_unreachable = true,
}, {
  schema="am_host:jitter_stats",
  label=i18n("active_monitoring_stats.rtt_vs_jitter"),
  metrics_labels = { i18n("flow_details.mean_rtt"), i18n("flow_details.rtt_jitter") },
  value_formatter = {"NtopUtils.fmillis", "NtopUtils.fmillis"},
  split_directions = true,
  show_unreachable = true,
}}

-- #################################################################

return {
  -- Defines a list of measurements implemented by this script.
  -- The probing logic is implemented into the check() and collect_results().
  --
  -- Here is how the probing occurs:
  --	1. The check function is called with the list of hosts to probe. Ideally this
  --	   call should not block (e.g. should not wait for the results)
  --	2. The active_monitoring.lua code sleeps for some seconds
  --	3. The collect_results function is called. This should retrieve the results
  --       for the hosts checked in the check() function and return the results.
  --
  -- The alerts for non-responding hosts and the Active Monitoring timeseries are automatically
  -- generated by active_monitoring.lua . The timeseries are saved in the following schemas:
  -- "am_host:val_min", "am_host:val_5mins", "am_host:val_hour".
  measurements = {
    {
      -- The unique key for the measurement
      key = "cicmp",
      -- The localization string for this measurement
      i18n_label = "active_monitoring_stats.icmp_continuous",
      -- The function called periodically to send the host probes
      check = check_icmp_continuous,
      -- The function responsible for collecting the results
      collect_results = collect_icmp_continuous,
      -- The granularities allowed for the probe. See supported_granularities in active_monitoring.lua
      granularities = {"min"},
      -- The localization string for the measurement unit (e.g. "ms", "Mbits")
      i18n_unit = "field_units.percentage",
      -- The localization string for the Jitter unit (e.g. "ms", "Mbits")
      i18n_jitter_unit = "active_monitoring_stats.msec",
      -- The localization string for the Active Monitoring timeseries menu entry
      i18n_am_ts_label = "active_monitoring_stats.availability",
      -- The operator to use when comparing the measurement with the threshold, "gt" for ">" or "lt" for "<".
      operator = "lt",
      -- If set, indicates a maximum threshold value
      max_threshold = 100,
      -- If set, indicates the default threshold value
      default_threshold = 99,
      -- A list of additional timeseries (the am_host:val_* is always shown) to show in the charts.
      -- See https://www.ntop.org/guides/ntopng/api/timeseries/adding_new_timeseries.html#charting-new-metrics .
      additional_timeseries = timeseries,
      -- Js function to call to format the measurement value. See ntopng_utils.js .
      value_js_formatter = "NtopUtils.fpercent",
      -- The raw measurement value is multiplied by this factor before being written into the chart
      chart_scaling_value = 1,
      -- The localization string for the Active Monitoring metric in the chart
      i18n_am_ts_metric = "active_monitoring_stats.availability",
      -- A list of additional notes (localization strings) to show into the timeseries charts
      i18n_chart_notes = {},
      -- If set, the user cannot change the host
      force_host = nil,
      -- An alternative localization string for the unrachable alert message
      unreachable_alert_i18n = nil,
    }, {
      key = "cicmp6",
      i18n_label = "active_monitoring_stats.icmp_continuous_v6",
      check = check_icmp6_continuous,
      collect_results = collect_icmp6_continuous,
      granularities = {"min"},
      i18n_unit = "field_units.percentage",
      i18n_jitter_unit = "active_monitoring_stats.msec",
      i18n_am_ts_label = "active_monitoring_stats.response_rate",
      i18n_am_ts_metric = "active_monitoring_stats.response_rate",
      operator = "lt",
      max_threshold = 100,
      default_threshold = 99,
      additional_timeseries = timeseries,
      value_js_formatter = "NtopUtils.fpercent",
      chart_scaling_value = 1,
      i18n_chart_notes = {},
      force_host = nil,
      unreachable_alert_i18n = nil,
    },
  },

  -- A setup function to possibly disable the plugin
  setup = check_icmp_available,
}
