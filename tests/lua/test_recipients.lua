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

package.path = dirs.installdir .. "/scripts/lua/modules/recipients/?.lua;" .. package.path
local json = require "dkjson"
local recipients_lua_utils = require "recipients_lua_utils"

local dummy_notification = json.encode({})

assert(recipients_lua_utils.dispatch_trigger_notification(dummy_notification))
assert(recipients_lua_utils.dispatch_release_notification(dummy_notification))
assert(recipients_lua_utils.dispatch_store_notification(dummy_notification))
--assert(recipients_lua_utils.process_notifications())

print("OK\n")
