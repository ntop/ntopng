--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")

-- #######################################

if not isAdministrator() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return 
end

local extra_headers = {}

extra_headers["Content-Disposition"] = "attachment;filename=\"ntopng_logs_"..os.time()..".log\""

local days
if not isEmptyString(_GET["days"]) then
   days = tonumber(_GET["days"])
end
if not days then
   days = 1
end

local since = days .. " days ago"

local output = ntop.execCmd("journalctl -u ntopng --since '"..since.."'")

rest_utils.vanilla_payload_response(rest_utils.consts.success.ok, output, "text/plain;charset=UTF-8", extra_headers)
