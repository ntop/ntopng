--
-- (C) 2013-26 - ntop.org
--
-- trace_script_duration = true
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local page = _GET["page"] or 'overview'
local base_url = ntop.getHttpPrefix() .. "/lua/admin/blacklists.lua"
sendHTTPContentTypeHeader('text/html')

-- Check permissions. This has to come BEFORE the page header and the menu:
-- isAdministratorOrPrintErr() renders its own shell plus an "Access forbidden"
-- notice, whereas bailing out after them left the user on a blank page.
if not isAdministratorOrPrintErr() then
  return
end

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.category_lists)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- The overview is pro/http_src/vue/page-blacklists.vue (SPA route). The charts
-- tab is drawn here (legacyOnly tab of the route: the SPA renders nothing for
-- it, navbar included)
if page == "charts" then
  page_utils.print_navbar(i18n("category_lists.category_lists"), base_url .. "?", {{
      active = false,
      page_name = "overview",
      label = "<i class=\"fas fa-lg fa-home\"></i>"
  }, {
      active = true,
      page_name = "charts",
      label = "<i class='fas fa-lg fa-chart-area' title='" .. i18n("historical") .. "'></i>"
  }})

  local graph_utils = require("graph_utils")
  graph_utils.drawNewGraphs({
      ifid = getSystemInterfaceId()
  })
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
