--
-- (C) 2017 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local host_pools_utils = require "host_pools_utils"
local json = require "dkjson"

sendHTTPContentTypeHeader('text/html')

local ifid = _GET["ifid"]
local pool_id = _GET["pool"]
local res = {data={}, sort={{"column_", "asc"}}, totalRows=0}
local curpage = tonumber(_GET["currentPage"]) or 1
local perpage = tonumber(_GET["perPage"]) or 10
local member_filter = _GET["member"]

local start_i = (curpage-1) * perpage
local stop_i = start_i + perpage - 1
local i = 0

if((ifid ~= nil) and (isAdministrator())) then
  interface.select(getInterfaceName(ifid))

  if pool_id ~= nil then
    local active_hosts = interface.getHostsInfo(false, nil, nil, nil, nil, nil, nil, nil, nil, nil, true--[[no macs]], tonumber(pool_id)).hosts
    local network_stats = interface.getNetworksStats()

    for _,member in ipairs(host_pools_utils.getPoolMembers(ifid, pool_id)) do
      if(isEmptyString(member_filter) or (member.key == member_filter)) then
        if (i >= start_i) and (i <= stop_i) then
          local host_key, is_network = host_pools_utils.getMemberKey(member.key)
          local link

          if active_hosts[host_key] then
            link = ntop.getHttpPrefix() .. "/lua/host_details.lua?" .. hostinfo2url(active_hosts[host_key])
          elseif interface.getMacInfo(host_key) ~= nil then
            link = ntop.getHttpPrefix() .. "/lua/mac_details.lua?host=" .. host_key
          elseif network_stats[host_key] ~= nil then
            link = ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?network=" .. network_stats[host_key].network_id
          else
            link = ""
          end

          local alias = ""
          local icon = ""
          if not is_network then
            icon = getHostIconName(host_key)
            alias = getHostAltName(host_key)

            if alias == host_key then
              alias = ""
            end
          end

          res.data[#res.data + 1] = {
            column_member = member.address,
            column_alias = alias,
            column_icon = icon,
            column_vlan = tostring(member.vlan),
            column_link = link,
            column_editable = tostring(tonumber(member.residual) == nil),
            column_residual = tonumber(member.residual) and secondsToTime(member.residual) or "Persistent",
          }
        end
        i = i + 1
      end
    end

    tablePreferences("hostPoolMembers", perpage)
  else
    for _,pool in ipairs(host_pools_utils.getPoolsList(ifid)) do
      if (i >= start_i) and (i <= stop_i) then
        local undeletable_pools = host_pools_utils.getUndeletablePools(ifid)

        if pool.id ~= host_pools_utils.DEFAULT_POOL_ID then
          res.data[#res.data + 1] = {
            column_pool_id = pool.id,
            column_pool_name = pool.name,
            column_pool_undeletable = undeletable_pools[pool.id] or false,
            column_children_safe = pool.children_safe,
            column_pool_link = ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?pool=" .. pool.id
          }
        end
      end
      i = i + 1
    end
  end
end

res.totalRows = i

return print(json.encode(res, nil, 1))
