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
-- Add a new pool
--

local name = _GET["pool_name"]
local members = _GET["pool_members"]
local confset_id = _GET["confset_id"]

sendHTTPHeader('application/json')

if not isAdministrator() then
   print(rest_utils.rc(rest_utils.consts_not_granted))
   return
end

if not name or not members or not confset_id then
   print(rest_utils.rc(rest_utils.consts_invalid_args))
   return
end

-- Unfold the members csv
members = members:split(",") or {members}
-- confset_id as number
confset_id = tonumber(confset_id)

local s = interface_pools:create()
local new_pool_id = s:add_pool(name, members --[[ an array of valid interface ids]], confset_id --[[ a valid configset_id --]])

if not new_pool_id then
   print(rest_utils.rc(rest_utils.consts_add_pool_failed))
end

local rc = rest_utils.consts_ok
local res = {
   pool_id = new_pool_id
}

print(rest_utils.rc(rc, res))

