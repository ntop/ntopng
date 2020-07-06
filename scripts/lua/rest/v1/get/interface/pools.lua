--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"
local rest_utils = require "rest_utils"
local interface_pools = require "interface_pools"

--
-- Pools getter
--

local pool_id = _GET["pool"]

sendHTTPHeader('application/json')

-- pool_id as number
pool_id = tonumber(pool_id)

local res = {}

local s = interface_pools:create()

if pool_id then
   -- Return only one pool
   local cur_pool = s:get_pool(pool_id)

   if cur_pool then
      res[pool_id] = cur_pool
   else
      print(rest_utils.rc(rest_utils.consts_pool_not_found))
      return
   end
else
   -- Return all pool ids
   res = s:get_all_pools()
end

local rc = rest_utils.consts_ok
print(rest_utils.rc(rc, res))
