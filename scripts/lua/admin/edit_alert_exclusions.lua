--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local page_utils = require("page_utils")
local format_utils = require("format_utils")
local template = require "template_utils"
local user_scripts = require "user_scripts"
local json = require "dkjson"
local alert_exclusions = require "alert_exclusions"
local alert_consts = require "alert_consts"
local rest_utils = require "rest_utils"
local auth = require "auth"
local user_scripts_utils = require("user_scripts_utils")

if not auth.has_capability(auth.capabilities.user_scripts) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

sendHTTPContentTypeHeader('text/html')

-- get config parameters like the id and name
local script_subdir = _GET["subdir"]
local script_filter = _GET["user_script"]
local search_filter = _GET["search_script"]

local configset = user_scripts.getConfigset()
local script_type = user_scripts.getScriptType(script_subdir)

local scripts = user_scripts.load(getSystemInterfaceId(), script_type, script_subdir)

if not haveAdminPrivileges() or not configset then
  return
end


-- create a table that holds localization about hooks name
local titles = user_scripts_utils.load_configset_titles()

local sub_menu_entries = {
  ['host'] = {
     order = 0,
     entry = page_utils.menu_entries.alert_exclusions_hosts
  },
  ['flow'] = {
     order = 1,
     entry = page_utils.menu_entries.alert_exclusions_flows
  },
}
local active_entry = sub_menu_entries[script_subdir].entry or page_utils.menu_entries.alert_exclusions
page_utils.set_active_menu_entry(active_entry)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local url = ntop.getHttpPrefix() .. "/lua/admin/edit_alert_exclusions.lua"
local navbar_menu = {}
for key, sub_menu in pairsByField(sub_menu_entries, 'order', asc) do
   navbar_menu[#navbar_menu+1] = {
      active = (script_subdir == key),
      page_name = key,
      label = i18n(sub_menu.entry.i18n_title),
      url = url .. "?subdir="..key
  }
end

page_utils.print_navbar(i18n("edit_user_script.exclusion_list"), '#', navbar_menu)

local context = {
   script_list = {
      subdir = script_subdir,
      template_utils = template,
      script_subdir = script_subdir,
      page_url = ntop.getHttpPrefix() .. string.format("/lua/admin/edit_alert_exclusions.lua?subdir=%s", script_subdir),
   },
   alert_exclusions = alert_exclusions,
   alert_consts = alert_consts
}

-- print config_list.html template
template.render("pages/edit_alert_exclusions.template", context)

-- append the menu below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
