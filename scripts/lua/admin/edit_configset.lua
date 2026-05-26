--
-- (C) 2019-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils     = require "page_utils"
local json           = require "dkjson"
local template_utils = require "template_utils"
local rest_utils     = require "rest_utils"
local auth           = require "auth"
local checks_utils   = require "checks_utils"

local current_ifid = interface.getId()

if not auth.has_capability(auth.capabilities.checks) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

if not isAdministratorOrPrintErr() then
   return
end

sendHTTPContentTypeHeader('text/html')

local check_subdir = _GET["subdir"] or "flow"

local sub_menu_entries = {
  ['all']              = { order = 0, entry = page_utils.menu_entries.scripts_config_all },
  ['host']             = { order = 1, entry = page_utils.menu_entries.scripts_config_hosts },
  ['interface']        = { order = 2, entry = page_utils.menu_entries.scripts_config_interfaces },
  ['network']          = { order = 3, entry = page_utils.menu_entries.scripts_config_networks },
  ['snmp_device']      = { order = 4, entry = page_utils.menu_entries.scripts_config_snmp_devices },
  ['flow']             = { order = 5, entry = page_utils.menu_entries.scripts_config_flows },
  ['system']           = { order = 6, entry = page_utils.menu_entries.scripts_config_system },
  ['active_monitoring']= { order = 7, entry = page_utils.menu_entries.scripts_config_active_monitoring },
  ['syslog']           = { order = 8, entry = page_utils.menu_entries.scripts_config_syslog },
  ['as']               = { order = 9, entry = page_utils.menu_entries.scripts_config_as },
}

if tonumber(getSystemInterfaceId()) == tonumber(current_ifid) then
   sub_menu_entries = {
     ['system']           = { order = 0, entry = page_utils.menu_entries.scripts_config_system },
   }
   check_subdir = "system"
end

local active_entry = (sub_menu_entries[check_subdir] and sub_menu_entries[check_subdir].entry)
                     or page_utils.menu_entries.scripts_config
page_utils.print_header_and_set_active_menu_entry(active_entry)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local url = ntop.getHttpPrefix() .. "/lua/admin/edit_configset.lua"
local navbar_menu = {}
for key, sub_menu in pairsByField(sub_menu_entries, 'order', asc) do
   navbar_menu[#navbar_menu + 1] = {
      active    = (check_subdir == key),
      page_name = key,
      label     = i18n(sub_menu.entry.i18n_title),
      url       = url .. "?subdir=" .. key,
   }
end

page_utils.print_navbar(i18n("internals.checks"), url, navbar_menu)

local context = {
   check_subdir = check_subdir,
   page_csrf    = ntop.getRandomCSRFValue(),
   ifid         = interface.getId(),
}

template_utils.render("pages/vue_page.template", {
   vue_page_name = "PageEditConfigset",
   page_context  = json.encode(context),
})

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
