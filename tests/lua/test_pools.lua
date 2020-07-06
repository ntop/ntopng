--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

if ntop.isPro() then
   package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
   package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
end
require "lua_utils"

package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
local interface_pools = require "interface_pools"
-- interface_pools.get_available_members()

-- test interface pools
local s = interface_pools:create()

-- Cleanup
s:cleanup()

-- Creation
local new_pool_id = s:add_pool('my_pool', {"0"} --[[ an array of valid interface ids]], 0 --[[ a valid configset_id --]])
assert(new_pool_id == 1)

-- Getter (by id)
local pool_details = s:get_pool(new_pool_id)
assert(pool_details["name"] == "my_pool")

-- Getter (a non-existing id)
assert(not s:get_pool(999))

-- Getter (by name)
pool_details = s:get_pool_by_name('my_pool')
assert(pool_details["name"] == "my_pool")

-- Getter (a non-existing name)
assert(not s:get_pool_by_name('my_non_existing_name'))

-- Edit
s:edit_pool(new_pool_id, 'my_renewed_pool', {"0"}, 0)
pool_details = s:get_pool(new_pool_id)
assert(pool_details["name"] == "my_renewed_pool")

-- Delete
s:delete_pool(new_pool_id)
pool_details = s:get_pool(new_pool_id)
assert(pool_details == nil)

-- Addition of another pool
local second_pool_id = s:add_pool('my_second_pool', {"0"} --[[ an array of valid interface ids]], 0 --[[ a valid configset_id --]])
assert(second_pool_id == 2)

-- Edit of the second pool
s:edit_pool(second_pool_id, 'my_second_pool_edited', {"0"}, 0)
pool_details = s:get_pool(second_pool_id)
assert(second_pool_id == 2)

-- tprint(s:get_all_members())
-- tprint(s:get_available_members())
-- tprint(pool_details)
-- tprint(s:get_available_configset_ids())
-- s:delete_pool(new_pool_id)
-- s:cleanup()

s:cleanup()

print("OK\n")

