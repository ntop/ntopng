--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require "page_utils"

local info = ntop.getInfo()

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.about, { product = info.product })

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- http_src/vue/router.js: AppShell's <router-view> renders
-- PageAbout, so this page's own mount is skipped here to avoid
-- a duplicate render.

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
