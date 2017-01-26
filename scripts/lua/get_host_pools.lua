--
-- (C) 2017 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local host_pools_utils = require "host_pools_utils"
local json = require "dkjson"

sendHTTPHeader('text/html; charset=iso-8859-1')

local ifid = _GET["ifid"]
local pool_id = _GET["pool"]
local res = {data={}, sort={{"column_", "asc"}}, totalRows=0}

if((ifid ~= nil) and (isAdministrator())) then
  if pool_id ~= nil then
    for _,member in ipairs(host_pools_utils.getPoolMembers(ifid, pool_id)) do
      local alias = getHostAltName(member.key, true --[[ accept null result ]])
      if alias == nil then alias = "" end
      res.data[#res.data + 1] = {
        column_member = member.address,
        column_alias = alias,
        column_icon = ntop.getHashCache("ntopng.host_icons",  member.key),
        column_vlan = member.vlan,
      }
    end
  else
    for _,pool in ipairs(host_pools_utils.getPoolsList(ifid)) do
      local undeletable_pools = host_pools_utils.getUndeletablePools()

      if pool.id ~= host_pools_utils.DEFAULT_POOL_ID then
        res.data[#res.data + 1] = {
          column_pool_id = pool.id,
          column_pool_name = pool.name,
          column_pool_undeletable = undeletable_pools[pool.id] or false,
        }
      end
    end
  end
end

res.totalRows = #res.data

return print(json.encode(res, nil, 1))
