--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils_get"

-- Server Ports is now the "Server Ports" tab of the live flows (page-flows-route.vue):
-- old links and bookmarks keep their filters. The original page is in attic/scripts/lua/server_ports.lua
local params = { page = "server_ports" }
for _, k in ipairs({ "ifid", "timeframe", "vlan", "l4proto" }) do
   params[k] = _GET[k]
end

print(ntop.httpRedirect(getPageUrl(ntop.getHttpPrefix() .. "/lua/flows_stats.lua", params)))
