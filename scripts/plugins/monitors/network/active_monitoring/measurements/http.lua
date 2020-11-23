--
-- (C) 2020 - ntop.org
--

--
-- This module implements the HTTP probe.
--

local ts_utils = require("ts_utils_core")

local do_trace = false

-- #################################################################

-- This is the script state, which must be manually cleared in the check
-- function. Can be then used in the collect_results function to match the
-- probe requests with probe replies.
local result = {}

-- #################################################################

-- The function called periodically to send the host probes.
-- hosts contains the list of hosts to probe, The table keys are
-- the hosts identifiers, whereas the table values contain host information
-- see (am_utils.key2host for the details on such format).
local function check(measurement, hosts, granularity)
  result[measurement] = {}

  for key, host in pairs(hosts) do
    local domain_name = host.host
    local full_url = string.format("%s://%s", host.measurement, domain_name)

    if do_trace then
      print("[ActiveMonitoring] GET "..full_url.."\n")
    end

    -- HTTP results are retrieved immediately
    local rv
    if host.token then
       rv = ntop.httpGetAuthToken(full_url, host.token, 10 --[[ timeout ]], host.save_result == true --[[ whether to return the content --]],
				  nil, true --[[ follow redirects ]])
    else
       rv = ntop.httpGet(full_url, nil, nil, 10 --[[ timeout ]], host.save_result == true --[[ whether to return the content --]],
			 nil, false --[[ don't follow redirects ]])
    end

    if(rv and rv.HTTP_STATS and (rv.HTTP_STATS.TOTAL_TIME > 0)) then
      local total_time = rv.HTTP_STATS.TOTAL_TIME * 1000
      local lookup_time = (rv.HTTP_STATS.NAMELOOKUP_TIME or 0) * 1000
      local connect_time = (rv.HTTP_STATS.APPCONNECT_TIME or 0) * 1000

      result[measurement][key] = {
	resolved_addr = rv.RESOLVED_IP,
	value = total_time,
      }

      -- Check if the result of the measurement has to be saved
      if host.save_result and not isEmptyString(rv.CONTENT) then
	 local plugins_utils = require "plugins_utils"
	 local am_utils = plugins_utils.loadModule("active_monitoring", "am_utils")
	 am_utils.setLastResult(key, rv.CONTENT)
      end

      -- HTTP/S specific metrics
      if(host.measurement == "https") then
	ts_utils.append("am_host:https_stats_" .. granularity, {
	    ifid = getSystemInterfaceId(),
	    host = host.host,
	    metric = host.measurement,
	    lookup_ms = lookup_time,
	    connect_ms = connect_time,
	    other_ms = (total_time - lookup_time - connect_time),
	}, when)
      else
	ts_utils.append("am_host:http_stats_" .. granularity, {
	    ifid = getSystemInterfaceId(),
	    host = host.host,
	    metric = host.measurement,
	    lookup_ms = lookup_time,
	    other_ms = (total_time - lookup_time),
	}, when)
      end
    end
  end
end

-- #################################################################

-- @brief HTTPS check
local function check_http(hosts, granularity)
   check("http", hosts, granularity)
end

-- #################################################################

-- @brief HTTP check
local function check_https(hosts, granularity)
   check("https", hosts, granularity)
end

-- #################################################################

-- The function responsible for collecting the results.
-- It must return a table containing a list of hosts along with their retrieved
-- measurement. The keys of the table are the host key. The values have the following format:
--  table
--	resolved_addr: (optional) the resolved IP address of the host
--	value: (optional) the measurement numeric value. If unspecified, the host is still considered unreachable.
local function collect(measurement, granularity)
  -- TODO: curl_multi_perform could be used to perform the requests
  -- asynchronously, see https://curl.haxx.se/libcurl/c/curl_multi_perform.html
  return result[measurement]
end

-- #################################################################

local function collect_http(granularity)
   -- TODO: curl_multi_perform could be used to perform the requests
   -- asynchronously, see https://curl.haxx.se/libcurl/c/curl_multi_perform.html
   return collect("http", granularity)
end

-- #################################################################

local function collect_https(granularity)
   -- TODO: curl_multi_perform could be used to perform the requests
   -- asynchronously, see https://curl.haxx.se/libcurl/c/curl_multi_perform.html
   return collect("https", granularity)
end

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
      key = "http",
      -- The localization string for this measurement
      i18n_label = "http",
      -- The function called periodically to send the host probes
      check = check_http,
      -- The function responsible for collecting the results
      collect_results = collect_http,
      -- The granularities allowed for the probe. See supported_granularities in active_monitoring.lua
      granularities = {"min", "5mins", "hour"},
      -- The localization string for the measurement unit (e.g. "ms", "Mbits")
      i18n_unit = "active_monitoring_stats.msec",
      -- The localization string for the Jitter unit (e.g. "ms", "Mbits")
      i18n_jitter_unit = nil,
      -- The localization string for the Active Monitoring timeseries menu entry
      i18n_am_ts_label = "graphs.num_ms_rtt",
      -- The localization string for the Active Monitoring metric in the chart
      i18n_am_ts_metric = "flow_details.round_trip_time",
      -- The operator to use when comparing the measurement with the threshold, "gt" for ">" or "lt" for "<".
      operator = "gt",
      -- If set, indicates the default threshold value
      default_threshold = nil,
      -- If set, indicates a maximum threshold value
      max_threshold = 10000,
      -- A list of additional timeseries (the am_host:val_* is always shown) to show in the charts.
      -- See https://www.ntop.org/guides/ntopng/api/timeseries/adding_new_timeseries.html#charting-new-metrics .
      additional_timeseries = {{
	schema="am_host:http_stats",
	label=i18n("graphs.http_stats"),
	metrics_labels = { i18n("graphs.name_lookup"), i18n("other")},
      }},
      -- The raw measurement value is multiplied by this factor before being written into the chart
      chart_scaling_value = 1,
      -- Js function to call to format the measurement value. See ntopng_utils.js .
      value_js_formatter = "NtopUtils.fmillis",
      -- A list of additional notes (localization strings) to show into the timeseries charts
      i18n_chart_notes = {
	"active_monitoring_stats.other_http_descr",
      },
      -- If set, the user cannot change the host
      force_host = nil,
      -- An alternative localization string for the unrachable alert message
      unreachable_alert_i18n = nil,
    }, {
      key = "https",
      i18n_label = "https",
      check = check_https,
      collect_results = collect_https,
      granularities = {"min", "5mins", "hour"},
      i18n_unit = "active_monitoring_stats.msec",
      i18n_jitter_unit = nil,
      i18n_am_ts_label = "graphs.num_ms_rtt",
      i18n_am_ts_metric = "flow_details.round_trip_time",
      operator = "gt",
      default_threshold = nil,
      max_threshold = 10000,
      additional_timeseries = {{
	    schema="am_host:https_stats",
	    label=i18n("graphs.http_stats"),
	    metrics_labels = { i18n("graphs.name_lookup"), i18n("graphs.app_connect"), i18n("other") },
      }},
      chart_scaling_value = 1,
      value_js_formatter = "NtopUtils.fmillis",
      i18n_chart_notes = {
	      "active_monitoring_stats.app_connect_descr",
	      "active_monitoring_stats.other_https_descr"
      },
      force_host = nil,
      unreachable_alert_i18n = nil,
    },
  },

  -- A setup function to possibly disable the plugin
  setup = nil,
}
