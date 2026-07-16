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

local output

if ntop.isLinux() then
   output = ntop.execCmd("journalctl -u ntopng --since '"..since.."' 2>/dev/null")
end

if isEmptyString(output) then
   -- Check if ntopng.log is present (log to file configured or daemonized on non-linux platforms)
   local f = io.open(dirs.workingdir .. "/ntopng.log", "r")

   if f then
      output = f:read("*all")
      f:close()
   end
end

if isEmptyString(output) then
   rest_utils.answer(rest_utils.consts.err.not_found)
   return
end

rest_utils.vanilla_payload_response(rest_utils.consts.success.ok, output, "text/plain;charset=UTF-8", extra_headers)
