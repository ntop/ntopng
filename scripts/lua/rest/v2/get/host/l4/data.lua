--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")
local ts_utils = require("ts_utils")

--
-- Read list of active hosts
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1", "host": "192.168.1.1", "vlan": "1"}' http://localhost:3000/lua/rest/v2/get/host/active.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local rsp = {}

local ifid = _GET["ifid"] or interface.getId()
local host_data   = hostkey2hostinfo(_GET["host"]) -- In case host@vlan is given, create a table with host and vlan data
local host_ip     = host_data.host 
local host_vlan   = _GET["vlan"] or host_data.vlan -- Put the correct vlan
local available_ts = ts_utils.listSeries("host:l4protos", table.clone({ ifid = ifid, host = host_ip, vlan = host_vlan }), os.time() - 1800 --[[ 30 min is the default time ]])

local host = interface.getHostInfo(host_ip, host_vlan)
if host then 
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
        proto_stats["bytes_sent"] = host[k..".bytes.sent"] or 0
      end

      if host[k..".bytes.rcvd"] then
        proto_stats["bytes_rcvd"] = host[k..".bytes.rcvd"] or 0
      end

      proto_stats["protocol"] = l4_keys[id][1] or "" .. " " .. historicalProtoHostHref(ifid, host_ip, l4_keys[id][1], nil, nil, host_vlan, true) or ""
      proto_stats["total_bytes"] = (proto_stats["bytes_sent"] or 0) + (proto_stats["bytes_rcvd"] or 0)
      proto_stats["total_percentage"] = round((proto_stats["total_bytes"] * 100) / total, 2)

      if(areHostTimeseriesEnabled(ifId) and ntop.getPref("ntopng.prefs.hosts_ts_creation") == "full") and not timeseries_not_available then -- Check if the host timeseries are enabled
        local host_label = host_ip
        if tonumber(host_vlan) ~= 0 then
          host_label = host_label .. "@" .. host_vlan
        end

        if available_ts and table.len(available_ts) > 0 then
          for _, timeseries_info in pairs(available_ts or {}) do
            if timeseries_info.l4proto == string.lower(l4_keys[id][1]) then
              proto_stats["historical"] = hostinfo2detailshref(host, {page = "historical", ts_schema = "top:host:l4protos", ts_query = "ifid:" .. ifid .. ",host:" .. host_label .. ",l4proto:" .. k, zoom = '1d'}, '<i class="fas fa-chart-area"></i>')
            end
          end
        end
      end

      if proto_stats["total_bytes"] > 0 then
        -- Add the stats only if greater then 0
        proto_info[#proto_info + 1] = proto_stats
      end
    end
  end

  if table.len(proto_info) > 0 then
    rsp = proto_info
  end
end

rest_utils.answer(rc, rsp)
