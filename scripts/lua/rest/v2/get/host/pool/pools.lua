--
-- (C) 2013-23 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

local host_pools = require "host_pools"
require "lua_utils"
local rest_utils = require "rest_utils"

local host_pools_instance = host_pools:create()
local pools_stats = interface.getHostPoolsStats()

local res = {}
for pool_id,item in ipairs(pools_stats) do

    if (pool_id ~= 0 and pool_id ~= 1) then
        local name = host_pools_instance:get_pool_name(pool_id)
        local id = pool_id    
        res[#res+1] = {
            id = id,
            label = name
        }
    end
end

rest_utils.answer(rest_utils.consts.success.ok, res)