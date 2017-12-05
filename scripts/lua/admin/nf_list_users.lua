--
-- (C) 2013-17 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end

require "lua_utils"
local host_pools_utils = require "host_pools_utils"

-- Administrator check
if not isAdministrator() then
  return
end

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print[[<a href="]] print(ntop.getHttpPrefix()) print[[/lua/admin/nf_edit_user.lua">Edit user</a>]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
