--
-- (C) 2013-26 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local debug = false

sendHTTPHeaderLogout('text/html')

ntop.delCache("ntopng.cache.sessions.".._SESSION["session"])
if (debug) then io.write("Deleting ".."ntopng.cache.sessions.".._SESSION["session"].."\n") end

print [[
<meta http-equiv="refresh" content="1; URL=]] print(ntop.getHttpPrefix()) print [[/">
<html>
<body>
 ]] print(i18n("login.logging_out")) print[[
</body>
</html>

]]
