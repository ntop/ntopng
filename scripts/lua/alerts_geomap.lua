--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local template_utils = require("template_utils")
local json = require("dkjson")
local ifid = interface.getId() 

sendHTTPContentTypeHeader('text/html')

-- If it's not enterprise or it's not authorized, return
if (not (ntop.isEnterpriseL and ntop.isEnterpriseL()) and not (ntop.isnEdgeEnterprise and ntop.isnEdgeEnterprise())) then
    return
end

-- ######################################
local base_url = ntop.getHttpPrefix() .. "/pro/lua/alerts_geomap.lua"

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.alerts_geomap)
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local context = {
    ifid = ifid,
    csrf = ntop.getRandomCSRFValue()
}

local json_context = json.encode(context)

template_utils.render("pages/vue_page.template", { vue_page_name = "PageAlertsGeoMap", page_context = json_context })

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")