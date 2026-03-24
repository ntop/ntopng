--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path

require "lua_utils"
local template_utils = require "template_utils"
local page_utils     = require "page_utils"
local discover       = require "discover_utils"
local json           = require "dkjson"

sendHTTPContentTypeHeader('text/html')

page_utils.print_header_and_set_active_menu_entry(page_utils.menu_entries.device_protocols)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local is_nedge = ntop.isnEdge()

-- Build device types list for the selector
local device_types = {}
for typeid, info in discover.sortedDeviceTypeLabels() do
   device_types[#device_types + 1] = { id = tostring(typeid), label = info[2] }
end

-- nEdge: redirect to nEdge page if coming from there
local base_url
if is_nedge then
   base_url = ntop.getHttpPrefix() .. "/lua/pro/nedge/admin/nf_edit_user.lua"
else
   base_url = ntop.getHttpPrefix() .. "/lua/admin/edit_device_protocols.lua"
end

local nedge_settings_url = ntop.getHttpPrefix() .. "/lua/pro/nedge/admin/nf_edit_user.lua?page=settings"
local device_protocols_policing_enabled = (ntop.getPref("ntopng.prefs.device_protocols_policing") == "1")

local presets_utils = require "presets_utils"
presets_utils.init()

local actions_ctx = {}
for _, action in ipairs(presets_utils.actions) do
   local icon_class = string.match(action.icon, 'fa%-([%w%-]+)') or "circle"
   actions_ctx[#actions_ctx + 1] = {
      id         = action.id,
      text       = action.text,
      icon_class = "fas fa-" .. icon_class,
   }
end

local context = {
   is_admin    = isAdministrator(),
   is_nedge    = is_nedge,
   device_types = device_types,
   device_type  = _GET["device_type"] or "0",
   csrf         = ntop.getRandomCSRFValue(),
   nedge_settings_url = nedge_settings_url,
   device_protocols_policing_enabled = device_protocols_policing_enabled,
   actions        = actions_ctx,
   default_action = presets_utils.DEFAULT_ACTION,
}

template_utils.render("pages/vue_page.template", {
   vue_page_name = "PageEditDeviceProtocols",
   page_context  = json.encode(context),
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
