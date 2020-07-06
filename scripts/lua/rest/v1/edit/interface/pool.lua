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
-- Edit an existing pool
--

local pool_id = _GET["pool"]
local name = _GET["pool_name"]
local members = _GET["pool_members"]
local confset_id = _GET["confset_id"]

sendHTTPHeader('application/json')

if not isAdministrator() then
   print(rest_utils.rc(rest_utils.consts_not_granted))
   return
end

if not pool_id or not name or not members or not confset_id then
   print(rest_utils.rc(rest_utils.consts_invalid_args))
   return
end

-- pool_id as number
pool_id = tonumber(pool_id)
-- Unfold the members csv
members = members:split(",") or {members}
-- confset_id as number
confset_id = tonumber(confset_id)

local s = interface_pools:create()
local res = s:edit_pool(pool_id, name, members --[[ an array of valid interface ids]], confset_id --[[ a valid configset_id --]])

if not res then
   print(rest_utils.rc(rest_utils.consts_edit_pool_failed))
end

local rc = rest_utils.consts_ok
print(rest_utils.rc(rc))
