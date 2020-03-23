--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local template = require "template_utils"
local os_utils = require "os_utils"
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html', nil, nil, getBothViewFlag())

page_utils.set_active_menu_entry(page_utils.menu_entries.device_protocols)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

dofile(dirs.installdir .. "/scripts/lua/inc/edit_presets.lua");

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
