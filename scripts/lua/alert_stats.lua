--
-- (C) 2020-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require "page_utils"
local auth = require "auth"

-- Capability guard: every REST endpoint backing this page already refuses
-- without auth.capabilities.alerts, so a user reaching it anyway (typed URL,
-- bookmark) only got a page full of NOT_GRANTED errors.
-- Checked before sendHTTPContentTypeHeader: the redirect must be the first output
if not auth.has_capability(auth.capabilities.alerts) then
    print(ntop.httpRedirect(ntop.getHttpPrefix() .. "/lua/index.lua"))
    return
end

sendHTTPContentTypeHeader('text/html')

-- The page is rendered by the Vue app shell (see PageAlertStatsRoute in router.js)
page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.detected_alerts)
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
