--
-- (C) 2017 - ntop.org
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
local pool_id = _GET["pool"] or host_pools_utils.DEFAULT_POOL_ID

interface.select(ifname)
local members = host_pools_utils.getPoolMembers(getInterfaceId(ifname), pool_id)

for _,member in ipairs(members) do
  local name = member.address

  if tonumber(member.vlan) > 0 then
    name = name .. " [VLAN " .. member.vlan .. "]"
  end

  -- Note: the 'name' field is used by typeahead
  results[#results + 1] = {name=name, key=member.key}

  if #results == max_num_to_find then
    break
  end
end

print(json.encode(res, nil, 1))
