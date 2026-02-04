--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local template_utils = require "template_utils"
local page_utils = require "page_utils"
local json = require "dkjson"

-- Initialize interface
interface.select(ifname)

-- ##############################################

sendHTTPContentTypeHeader('text/html')

-- Setting up navbar
local info = ntop.getInfo()
page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.about, {
   product = info.product
})
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- ##############################################

local context = {
  ifid = interface.getId(),
  csrf = ntop.getRandomCSRFValue()
}

local json_context = json.encode(context)

template_utils.render("pages/vue_page.template", {
  vue_page_name = "PageChordTest",
  page_context = json_context
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
