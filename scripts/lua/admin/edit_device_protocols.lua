--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local template = require "template_utils"
local os_utils = require "os_utils"
local page_utils = require("page_utils")
active_page = "admin"

sendHTTPContentTypeHeader('text/html')

page_utils.print_header(i18n("device_protocols.device_protocols"))

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print[[<hr>]]
dofile(dirs.installdir .. "/scripts/lua/inc/edit_presets.lua");

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
