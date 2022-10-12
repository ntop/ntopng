--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")

--
-- Read list of active hosts
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1", "host": "192.168.1.1", "vlan": "1"}' http://localhost:3000/lua/rest/v2/get/host/active.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local rsp = {}

local ifid = _GET["ifid"] or interface.getId()
local host_ip     = _GET["host"]
local host_vlan   = _GET["vlan"] or 0
local host = interface.getHostInfo(host_ip, host_vlan)

local total = 0
local proto_info = {}
local timeseries_not_available = (host["localhost"] == false or host["is_multicast"] == true or host["is_broadcast"] == true)

-- Calculate total bytes
for id, _ in ipairs(l4_keys) do
	local k = l4_keys[id][2]
  total = total + (host[k..".bytes.sent"] or 0) + (host[k..".bytes.rcvd"] or 0)
end

-- Getting l4 protocols info
for id, _ in ipairs(l4_keys) do
	local k = l4_keys[id][2]
  
  if host[k..".bytes.sent"] or host[k..".bytes.rcvd"] then
    local proto_stats = {}

    if host[k..".bytes.sent"] then
      proto_stats["bytesSent"] = host[k..".bytes.sent"] or 0
    end

    if host[k..".bytes.rcvd"] then
      proto_stats["bytesRcvd"] = host[k..".bytes.rcvd"] or 0
    end

    proto_stats["protocol"] = l4_keys[id][1] or "" .. " " .. historicalProtoHostHref(ifid, host_ip, l4_keys[id][1], nil, nil, host_vlan, true) or ""
    proto_stats["totalBytes"] = (host[k..".bytes.sent"] or 0) + (host[k..".bytes.rcvd"] or 0)
    proto_stats["totalPctg"] = round((proto_stats["totalBytes"] * 100) / total, 2)
    proto_stats["breakdown"] = round((proto_stats["bytesSent"] * 100) / (proto_stats["bytesSent"] + proto_stats["bytesRcvd"]), 0)

    if(areHostTimeseriesEnabled(ifId) and ntop.getPref("ntopng.prefs.hosts_ts_creation") == "full") and not timeseries_not_available then -- Check if the host timeseries are enabled
      proto_stats["historical"] = hostinfo2detailshref(host, {page = "historical", ts_schema = "host:l4protos", l4proto = k}, '<i class="fas fa-chart-area"></i>')
    end

    if proto_stats["totalBytes"] > 0 then
      -- Add the stats only if greater then 0
      proto_info[#proto_info + 1] = proto_stats
    end
  end
end

if table.len(proto_info) > 0 then
  rsp["records"] = proto_info
end

if(total > 0) then
  if(host.cardinality) then
    rsp["contactedHostsAsCli"] = formatValue(host.cardinality.num_contacted_hosts_as_client)
    rsp["contactedHostsAsSrv"] = formatValue(host.cardinality.num_contacted_hosts_as_server)
  end
end

rest_utils.answer(rc, rsp)
