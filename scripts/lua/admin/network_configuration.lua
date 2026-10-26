--
-- (C) 2020 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require "page_utils"

sendHTTPContentTypeHeader('text/html')

-- All the views save through administrator only REST APIs (before the header: it prints its own page)
if not isAdministratorOrPrintErr() then
   return
end

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.network_config)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- Servers, Network Policy and ASN Configuration are SPA views
-- (page-network-configuration.vue, page-network-policy.vue,
-- page-asn-configuration.vue), see router.js

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
