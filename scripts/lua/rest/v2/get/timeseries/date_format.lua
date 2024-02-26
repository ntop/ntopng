--
-- (C) 2013-24 - ntop.org
--

--
-- Read actually date format selected by the user on the user preferences
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/get/timseries/date_format.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require("rest_utils")
require "lua_utils_generic"

local is_range_picker = toboolean(_GET["is_range_picker"]) or false


local key, time
if _SESSION then
    key = ntop.getPref('ntopng.user.' .. (_SESSION["user"] or "") .. '.date_format')
end

--dateFormat: "d/m/Y H:i", (for timerange_picker)

if(key == "big_endian") then
-- do NOT specify the ! to indicate UTC time; the time must be in Local Server Time
    if (is_range_picker) then
        time = "Y/m/d H:i"
    else
        time = "YYYY/MM/DD HH:mm"
    end
elseif( key == "middle_endian") then
-- do NOT specify the ! to indicate UTC time; the time must be in Local Server Time
    if (is_range_picker) then
        time = "m/d/Y H:i"
    else
        time = "MM/DD/YYYY HH:mm"
    end
else
-- do NOT specify the ! to indicate UTC time; the time must be in Local Server Time
    if (is_range_picker) then
        time = "d/m/Y H:i"
    else    
        time = "DD/MM/YYYY HH:mm"
    end
end

rest_utils.answer(rest_utils.consts.success.ok, time)