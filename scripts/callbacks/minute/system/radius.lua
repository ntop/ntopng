--
-- (C) 2019-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

-- This callback is used to check if the radius authentication
-- info are changed, in case they are changed, 
-- reload those info and reset the key
if (ntop.getCache('ntopng.prefs.radius_auth_changed') == '1') then
  ntop.updateRadiusLoginInfo()
  ntop.setCache('ntopng.prefs.radius_auth_changed', '0')
end
