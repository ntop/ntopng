--
-- (C) 2020 - ntop.org
--

local ts_utils = require("ts_utils_core")

local do_trace = false

local result = {}

-- The check function returns a table in the following format:
--	["hello.com"] = {
--	  resolved_addr = "1.2.3.4",
--	  value = 456,
--  	}
local function check_http(http_hosts, granularity)
  result = {}

  for key, host in pairs(http_hosts) do
    local domain_name = host.host
    local full_url = string.format("%s://%s", host.measurement, domain_name)

    if do_trace then
      print("[RTT] GET "..full_url.."\n")
    end

    -- HTTP results are retrieved immediately
    local rv = ntop.httpGet(full_url, nil, nil, 10 --[[ timeout ]], false --[[ don't return content ]],
      nil, false --[[ don't follow redirects ]])

    if(rv and rv.HTTP_STATS and (rv.HTTP_STATS.TOTAL_TIME > 0)) then
      local total_time = rv.HTTP_STATS.TOTAL_TIME * 1000
      local lookup_time = (rv.HTTP_STATS.NAMELOOKUP_TIME or 0) * 1000
      local connect_time = (rv.HTTP_STATS.APPCONNECT_TIME or 0) * 1000

      result[key] = {
	resolved_addr = rv.RESOLVED_IP,
	value = total_time,
      }

      -- HTTP/S specific metrics
      if(host.measurement == "https") then
	ts_utils.append("rtt_host:https_stats_" .. granularity, {
	    ifid = getSystemInterfaceId(),
	    host = host.host,
	    measure = host.measurement,
	    lookup_ms = lookup_time,
	    connect_ms = connect_time,
	    other_ms = (total_time - lookup_time - connect_time),
	}, when)
      else
	ts_utils.append("rtt_host:http_stats_" .. granularity, {
	    ifid = getSystemInterfaceId(),
	    host = host.host,
	    measure = host.measurement,
	    lookup_ms = lookup_time,
	    other_ms = (total_time - lookup_time),
	}, when)
      end
    end
  end
end

-- #################################################################

local function collect_http(granularity)
  -- TODO: curl_multi_perform could be used to perform the requests
  -- asynchronously, see https://curl.haxx.se/libcurl/c/curl_multi_perform.html
  return(result)
end

-- #################################################################

return {
  measurements = {
    {
      key = "http",
      check = check_http,
      collect_results = collect_http,
      granularities = {"min", "5mins", "hour"},
      i18n_unit = "rtt_stats.msec",
      operator = "gt",
      additional_timeseries = {{
	schema="rtt_host:http_stats",
	label=i18n("graphs.http_stats"),
	metrics_labels = { i18n("graphs.name_lookup"), i18n("other")},
      }},
      value_js_formatter = "fmillis",
      i18n_chart_notes = {
	"rtt_stats.other_http_descr",
      }
    }, {
      key = "https",
      check = check_http,
      collect_results = collect_http,
      granularities = {"min", "5mins", "hour"},
      i18n_unit = "rtt_stats.msec",
      operator = "gt",
      additional_timeseries = {{
	schema="rtt_host:https_stats",
	label=i18n("graphs.http_stats"),
	metrics_labels = { i18n("graphs.name_lookup"), i18n("graphs.app_connect"), i18n("other") },
      }},
      value_js_formatter = "fmillis",
      i18n_chart_notes = {
	"rtt_stats.app_connect_descr",
	"rtt_stats.other_https_descr"
      }
    },
  },
}
