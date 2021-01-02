--
-- (C) 2013-21 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/toasts/?.lua;" .. package.path

require ("lua_utils")
local dkjson = require("dkjson")
local toasts_manager = require("toasts_manager")

sendHTTPHeader('application/json')

local result = {success = false}
local toast_id = _POST["toast_id"]

-- check if the toast id is significan
if isEmptyString(toast_id) then
    result.error = "The toast ID is null!"
    print(dkjson.encode(result))
    return
end

-- try to dismiss the toast
local success, message = toasts_manager.dismiss_toast(tonumber(toast_id))
result.success = success

if not success then
    result.error = message
else
    result.message = message
end

-- tell the result to the web client
print(dkjson.encode(result))