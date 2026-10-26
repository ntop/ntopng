--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils" -- discover_utils and presets_utils use its globals
local rest_utils    = require "rest_utils"
local discover      = require "discover_utils"
local presets_utils = require "presets_utils"

--
-- Context of the Admin > Device Protocols page (page-edit-device-protocols.vue),
-- the one admin/edit_device_protocols.lua used to print: the device types, the
-- policy actions and the nEdge policing flags. The policies are read by
-- rest/v2/get/device/protocol_policies.lua.
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/device/protocols_context.lua
--

if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local device_types = {}
for typeid, info in discover.sortedDeviceTypeLabels() do
   device_types[#device_types + 1] = { id = tostring(typeid), label = info[2] }
end

presets_utils.init()

local actions = {}
for _, action in ipairs(presets_utils.actions) do
   local icon_class = string.match(action.icon, 'fa%-([%w%-]+)') or "circle"
   actions[#actions + 1] = {
      id         = action.id,
      text       = action.text,
      icon_class = "fas fa-" .. icon_class,
   }
end

rest_utils.answer(rest_utils.consts.success.ok, {
   is_nedge = (ntop.isnEdge and ntop.isnEdge()) and true or false,
   device_types = device_types,
   nedge_settings_url = ntop.getHttpPrefix() .. "/lua/pro/nedge/admin/nf_edit_user.lua?page=settings",
   device_protocols_policing_enabled = (ntop.getPref("ntopng.prefs.device_protocols_policing") == "1"),
   actions = actions,
   default_action = presets_utils.DEFAULT_ACTION,
})
