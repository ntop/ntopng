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
-- Delete an existing pool
--

local pool_id = _GET["pool"]

sendHTTPHeader('application/json')

if not isAdministrator() then
   print(rest_utils.rc(rest_utils.consts_not_granted))
   return
end

if not pool_id then
   print(rest_utils.rc(rest_utils.consts_invalid_args))
   return
end

-- pool_id as number
pool_id = tonumber(pool_id)

local s = interface_pools:create()
local res = s:delete_pool(pool_id)

if not res then
   print(rest_utils.rc(rest_utils.consts_delete_pool_failed))
   return
end

local rc = rest_utils.consts_ok
local res = {
   pool_id = new_pool_id
}

print(rest_utils.rc(rc, res))

