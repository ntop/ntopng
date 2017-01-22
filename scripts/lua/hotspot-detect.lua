--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

print [[
<html>
<head>
<title>...</title>
<meta http-equiv="refresh" Content="0; url=]] 

print(ntop.getHttpPrefix().."/lua/captive_portal.lua")

if(_SERVER["REFERER"] ~= "") then
   print("?referer=".._SERVER["REFERER"])
end

print [[">
<meta http-equiv="pragma" content="no-cache">
<meta http-equiv="expires" content="-1">
</head>
<body>
</body>
</html>
]]