--
-- (C) 2020 - ntop.org
--

local do_trace = false

local pinged_hosts = {}
local resolved_hosts = {}

-- #################################################################

-- Resolve the domain name into an IP if necessary
local function resolveRttHost(domain_name, is_v6)
   local ip_address = nil

   if not isIPv4(domain_name) and not is_v6 then
     ip_address = ntop.resolveHost(domain_name, true --[[IPv4 --]])

     if not ip_address then
	if do_trace then
	   print("[RTT] Could not resolve IPv4 host: ".. domain_name .."\n")
	end
     end
   elseif not isIPv6(domain_name) and is_v6 then
      ip_address = ntop.resolveHost(domain_name, false --[[IPv6 --]])

      if not ip_address then
	if do_trace then
	   print("[RTT] Could not resolve IPv6 host: ".. domain_name .."\n")
	end
      end
   else
     ip_address = domain_name
   end

  return(ip_address)
end

-- #################################################################

local function check_icmp(icmp_hosts, granularity)
  pinged_hosts = {}
  resolved_hosts = {}

  for key, host in pairs(icmp_hosts) do
    local domain_name = host.host
    local is_v6 = (host.measurement == "icmp6")
    local ip_address = resolveRttHost(domain_name, is_v6)

    if not ip_address then
      goto continue
    end

    if do_trace then
      print("[RTT] Pinging "..ip_address.."/"..domain_name.."\n")
    end

    -- ICMP results are retrieved in batch (see below ntop.collectPingResults)
    ntop.pingHost(ip_address, is_v6)

    pinged_hosts[ip_address] = key
    resolved_hosts[key] = ip_address

    ::continue::
  end
end

-- #################################################################

-- The collect function returns a table in the following format:
--	["hello.com"] = {
--	  resolved_addr = "1.2.3.4",
--	  value = 456,
--  	}
local function collect_icmp(granularity)
  local rv = {}

  -- Collect possible ICMP results
  local res = ntop.collectPingResults()

  for host, rtt in pairs(res or {}) do
    local key = pinged_hosts[host]

    if(do_trace) then
      print("[RTT] Reading ICMP response for host ".. host .."\n")
    end

    rv[key] = {
      resolved_addr = resolved_hosts[key],
      value = tonumber(rtt),
    }
  end

  return(rv)
end

-- #################################################################

return {
  measurements = {
    {
      key = "icmp",
      check = check_icmp,
      collect_results = collect_icmp,
      granularities = {"min", "5mins", "hour"},
      i18n_unit = "rtt_stats.msec",
      operator = "gt",
      additional_timeseries = {},
      value_js_formatter = "fmillis",
      i18n_chart_notes = {},
    }, {
      key = "icmp6",
      check = check_icmp,
      collect_results = collect_icmp,
      granularities = {"min", "5mins", "hour"},
      i18n_unit = "rtt_stats.msec",
      operator = "gt",
      additional_timeseries = {},
      value_js_formatter = "fmillis",
      i18n_chart_notes = {},
    },
  },
}
