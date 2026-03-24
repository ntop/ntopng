--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils_generic"

local delete_data_utils = require "delete_data_utils"
local template_utils    = require "template_utils"
local page_utils        = require "page_utils"
local json              = require "dkjson"

-- Handle the delete active interface POST action (called by the Vue component)
if _POST and table.len(_POST) > 0 and isAdministrator() then
   if _POST["delete_active_if_data"] ~= nil then
      delete_data_utils.request_delete_active_interface_data(_POST["ifid"])
   end
end

local info = ntop.getInfo()

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.manage_data)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local context = {
   ifid   = interface.getId(),
   ifname = ifname,
   product = info.product,
   csrf    = ntop.getRandomCSRFValue(),
   delete_active_interface_requested = delete_data_utils.delete_active_interface_data_requested(ifname),
   is_edge      = ntop.isnEdge(),
   has_clickhouse = interfaceHasClickHouseSupport(),
}

template_utils.render("pages/vue_page.template", {
   vue_page_name = "PageManageData",
   page_context  = json.encode(context),
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
