--
-- (C) 2014-15-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

if(mode ~= "embed") then
   sendHTTPContentTypeHeader('text/html')
   ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
   active_page = "hosts"
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
end

print [[   <div id="sprobe"></div> ]]


width = 1024
height = 768
url = ntop.getHttpPrefix().."/lua/sprobe_data.lua"
-- url = ntop.getHttpPrefix().."/lua/sprobe_flow_data.lua?flow_key=4261522881"
dofile(dirs.installdir .. "/scripts/lua/inc/sprobe.lua")

if(mode ~= "embed") then
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
end
