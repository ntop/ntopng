--
-- (C) 2017-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local host_pools_utils = require "host_pools_utils"
local discover = require "discover_utils"
local json = require "dkjson"

sendHTTPContentTypeHeader('text/html')

local ifid = _GET["ifid"]
local pool_id = _GET["pool"]
local res = {data={}, sort={{"column_", "asc"}}, totalRows=0}
local curpage = tonumber(_GET["currentPage"]) or 1
local perpage = tonumber(_GET["perPage"]) or 10
local members_filter = _GET["members_filter"]

local start_i = (curpage-1) * perpage
local stop_i = start_i + perpage - 1
local i = 0

local function matches_members_filter(member_key, is_mac)
  if isEmptyString(members_filter) then
    return true
  end

  if starts(members_filter, "manuf:") then
    local m = string.sub(members_filter, string.len("manuf:") + 1)
    if is_mac then
      local manuf = ntop.getMacManufacturer(member_key)
      if (manuf ~= nil) and (manuf.extended == m) then
        return true
      end
    end
  else
    return member_key == members_filter
  end

  return false
end

if((ifid ~= nil) and (isAdministrator())) then
  interface.select(getInterfaceName(ifid))

  if pool_id ~= nil then
    local active_hosts = interface.getHostsInfo(false, nil, nil, nil, nil, nil, nil, nil, nil, nil, true--[[no macs]], tonumber(pool_id)).hosts
    local network_stats = interface.getNetworksStats()

    for _,member in ipairs(host_pools_utils.getPoolMembers(ifid, pool_id)) do
      local is_mac = isMacAddress(member.address)

      if matches_members_filter(member.key, is_mac) then
        if (i >= start_i) and (i <= stop_i) then
          local host_key, is_network = host_pools_utils.getMemberKey(member.key)
          local is_host = (not is_network) and (not is_mac)
          local mac_info = interface.getMacInfo(host_key)
          local link

          if active_hosts[host_key] then
            link = ntop.getHttpPrefix() .. "/lua/host_details.lua?" .. hostinfo2url(active_hosts[host_key])
          elseif is_mac and mac_info ~= nil then
            link = ntop.getHttpPrefix() .. "/lua/mac_details.lua?host=" .. host_key
          elseif is_network and network_stats[host_key] ~= nil then
            link = ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?network=" .. network_stats[host_key].network_id
          else
            link = ""
          end

          local alias = ""
          local icon = ""
          if is_mac then
            alias = getDeviceName(member.address)
            icon = getCustomDeviceType(member.key)

            if (icon == nil) and (mac_info ~= nil) then
              icon = mac_info["devtype"]
            end

            if alias == host_key then
              alias = ""
            end
          elseif is_host then
            alias = getHostAltName(host_key)

            if alias == host_key then
              alias = ""
            end

            if active_hosts[host_key] and active_hosts[host_key].mac then
              if isEmptyString(alias) then
                alias = getHostAltName(active_hosts[host_key].mac)
                if alias == active_hosts[host_key].mac then
                  alias = ""
                end
              end
            end
          end

          if is_mac and isEmptyString(alias) then
            -- Show the MAC manufacturer instead
            local manuf = ntop.getMacManufacturer(member.address)
            if manuf ~= nil then
              alias = manuf.extended
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
            column_icon_label = discover.devtype2string(icon),
            column_member_key = member.key,
            column_member_label = member2visual(member.key),
          }
        end
        i = i + 1
      end
    end

    tablePreferences("hostPoolMembers", perpage)
  else
    local by_pool_name = {}

    for _,pool in pairs(host_pools_utils.getPoolsList(ifid)) do
      if pool.id ~= host_pools_utils.DEFAULT_POOL_ID then
        by_pool_name[pool.name] = pool
      end
    end

    for _,pool in pairsByKeys(by_pool_name, asc_insensitive) do
      if (i >= start_i) and (i <= stop_i) then
        local undeletable_pools = host_pools_utils.getUndeletablePools(ifid)

        res.data[#res.data + 1] = {
          column_pool_id = pool.id,
          column_pool_name = pool.name,
          column_pool_undeletable = undeletable_pools[pool.id] or false,
          column_children_safe = pool.children_safe,
          column_enforce_quotas_per_pool_member = pool.enforce_quotas_per_pool_member,
	  column_enforce_shapers_per_pool_member = pool.enforce_shapers_per_pool_member,
          column_pool_link = ntop.getHttpPrefix() .. "/lua/if_stats.lua?page=pools&pool=" .. pool.id
        }
      end

      i = i + 1
    end
  end
end

res.totalRows = i

return print(json.encode(res, nil, 1))
