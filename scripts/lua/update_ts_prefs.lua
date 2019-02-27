--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require "dkjson"

local res = {success = false}

sendHTTPHeader('application/json')

if isAdministrator() then
  if _POST["action"] == "disable" then
    ntop.setPref("ntopng.prefs.disable_ts_migration_message", "1")
    res.success = true
  end
end

print(json.encode(res))
