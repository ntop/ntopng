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
    for _,member in pairs(host_pools_utils.getPoolMembers(ifid, pool_id)) do
      res.data[#res.data + 1] = {
        column_member = member.address,
        column_vlan = member.vlan,
      }
    end
  else
    for _,pool_id in host_pools_utils.listPools(ifid) do
      local pool_name = host_pools_utils.getPoolName(ifid, pool_id)

      res.data[#res.data + 1] = {
        column_pool_id = pool_id,
        column_pool_name = pool_name,
      }
    end
  end
end

res.totalRows = #res.data

return print(json.encode(res, nil, 1))
