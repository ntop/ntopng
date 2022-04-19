--
-- (C) 2013-22 - ntop.org
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

if _GET["request_discovery"] == "true" then
  discover.requestNetworkDiscovery(ifid)
end

local discovery_requested = discover.networkDiscoveryRequested(ifid)

if discovery_requested then
   refresh_button = ""
end

-- ##############################################

sendHTTPContentTypeHeader('text/html')

-- Setting up navbar
page_utils.set_active_menu_entry(page_utils.menu_entries.network_discovery)
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
local manufactures = {}
local operating_systems = {}
local device_types = {}

for _, device in pairs(discovered["devices"] or {}) do
   local manuf = (device["manufacturer"] or get_manufacturer_mac(device["mac"]))
   if(manuf ~= nil) then
      manufactures[manuf] = manufactures[manuf] or 0
      manufactures[manuf] = manufactures[manuf] + 1
   end

   local dev_os = device["os_type"]
   if(dev_os ~= nil) then
      operating_systems[dev_os] = operating_systems[dev_os] or 0
      operating_systems[dev_os] = operating_systems[dev_os] + 1
   end

   local dev_type = discover.devtype2id(device["device_type"])
   if(dev_type ~= nil) then
      device_types[dev_type] = device_types[dev_type] or 0
      device_types[dev_type] = device_types[dev_type] + 1
   end
end

local messages = {
  discovery_not_enabled = i18n('discover.network_discovery_not_enabled', {url=ntop.getHttpPrefix().."/lua/admin/prefs.lua?tab=discovery", flask_icon="<i class=\"fas fa-flask\"></i>"}),
  discover_message = '&nbsp;' .. discovered["status"]["message"],
  discovery_running = i18n("discover.discovery_running"),
  datetime = i18n("discover.network_discovery_datetime")..": "..formatEpoch(discovered["discovery_timestamp"]),
  start_discovery = i18n("discover.start_discovery"),
  notes = i18n("notes"),
  ghost_descr = i18n("discover.ghost_icon_descr", {ghost_icon='<font color=red>'..discover.ghost_icon..'</font>'}),
  many_devices_descr = i18n("discover.too_many_devices_descr", {max_devices = discover.MAX_DISCOVERED_DEVICES}),
  protocols_note = i18n("discover.protocols_note"),
}

local discover_check = {
  DISCOVERY_REQUESTED = discovery_requested,
  NOCACHE = (discovered["status"]["code"] == "NOCACHE"),
  ERROR = (discovered["status"]["code"] == "ERROR"),
  OK = (discovered["status"]["code"] == "OK"),
  GHOST_FOUND = discovered["ghost_found"],
  MANY_DEVICES = discovered["too_many_devices_discovered"],
}

template_utils.render('pages/discover/discover.template', {
  messages = messages,
  http_prefix = ntop.getHttpPrefix(),
  discover_check = discover_check,
  ifid = ifid,
  page_url = base_url,
  url = getPageUrl(ntop.getHttpPrefix() .. "/lua/rest/v2/get/network/discovery/discover.lua", page_params),
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
