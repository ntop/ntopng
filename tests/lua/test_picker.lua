--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local template_utils = require("template_utils")
local ui_utils = require("ui_utils")

sendHTTPContentTypeHeader('text/html')

page_utils.print_header(i18n("about.about_x", { product = ":)" }))

if not isAdministrator() then return end


dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

template_utils.render("pages/test_picker.template", {
    ui_utils = ui_utils
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

