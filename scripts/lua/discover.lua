--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local discover = require "discover_utils"
local template_utils = require "template_utils"
local page_utils = require "page_utils"
local ifid = getInterfaceId(ifname)
local base_url = ntop.getHttpPrefix() .. "/lua/discover.lua"
local page_params = {}

-- ##############################################

sendHTTPContentTypeHeader('text/html')

-- Setting up navbar
page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.network_discovery)
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
page_utils.print_navbar(i18n('discover.network_discovery'), base_url, {
  {
    active = true,
    page_name = "network_discovery",
    label = '<i class="fas fa-lg fa-project-diagram"></i>',
    url = base_url,
  },
})

-- ##############################################

local discovered = discover.discover2table(ifname)

-- ##############################################

template_utils.render('pages/discover/discover.template', {
  ifid = ifid,
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
