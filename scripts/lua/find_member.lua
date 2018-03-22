--
-- (C) 2017-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local host_pools_utils = require "host_pools_utils"
local json = require "dkjson"

sendHTTPHeader('application/json')

local max_num_to_find = 5
local res = {interface=ifname, results={}}
local results = res.results

local query = _GET["query"] or ""
query = string.lower(query)
local pool_id = _GET["pool"] or host_pools_utils.DEFAULT_POOL_ID

interface.select(ifname)
local members = host_pools_utils.getPoolMembers(getInterfaceId(ifname), pool_id)
local matched_manufacturers = {}

for _,member in ipairs(members) do
  local is_mac = isMacAddress(member.address)
  local hostkey, is_network = host_pools_utils.getMemberKey(member.address)
  local is_host = (not is_network) and (not is_mac)
  local matching = false

  if is_host then
    local info = interface.getHostInfo(hostkey)

    if (info ~= nil) then
      -- by DHCP/DNS name
      if (info.name ~= nil) and string.contains(string.lower(info.name), query) then
        results[#results + 1] = {name=info.name, key=member.key}
        matching = true
      -- by NBNS name
      elseif (info.info ~= nil) and string.contains(string.lower(info.info), query) then
        results[#results + 1] = {name=info.info, key=member.key}
        matching = true
      -- by MAC
      elseif (info.mac ~= nil) and string.contains(string.lower(info.mac), query) then
        results[#results + 1] = {name=info.mac, key=member.key}
        matching = true
      else
        -- by IP/MAC altName
        local altname = getHostAltName(info["ip"], info.mac)

        if (altname ~= nil) and  string.contains(string.lower(altname), query) then
          results[#results + 1] = {name=altname, key=member.key}
          matching = true
        end
      end
    end
  elseif is_mac then
    -- by MAC altName
    local altname = getHostAltName(member.address)

    if (altname ~= nil) and string.contains(string.lower(altname), query) then
      results[#results + 1] = {name=altname, key=member.key}
      matching = true
    end

    -- by Manufacturer: always count the members, even if we matched above
    local manuf = ntop.getMacManufacturer(member.address)
    if (manuf ~= nil) and string.contains(string.lower(manuf.extended), query) then
      local name
      if matched_manufacturers[manuf.extended] == nil then
        matched_manufacturers[manuf.extended] = {idx=#results+1, count=1}
        name = manuf.extended
      else
        matched_manufacturers[manuf.extended].count = matched_manufacturers[manuf.extended].count + 1
        name = manuf.extended .. " (" .. matched_manufacturers[manuf.extended].count .. ")"
      end

      results[matched_manufacturers[manuf.extended].idx] = {name=name, key="manuf:"..manuf.extended}
      matching = true
    end
  end

  if (not matching) and string.contains(string.lower(member.address), query) then
    local name = member.address

    if tonumber(member.vlan) > 0 then
      name = name .. " [VLAN " .. member.vlan .. "]"
    end

    -- Note: the 'name' field is used by typeahead
    results[#results + 1] = {name=name, key=member.key}
    matching = true
  end

  if #results == max_num_to_find then
    break
  end
end

print(json.encode(res, nil, 1))
