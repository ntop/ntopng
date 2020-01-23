--
-- (C) 2019-20 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local ts_utils = require("ts_utils")
local info = ntop.getInfo() 
local page_utils = require("page_utils")
local format_utils = require("format_utils")
local os_utils = require "os_utils"
local template = require "template_utils"
local user_scripts = require "user_scripts"
local json = require "dkjson"

sendHTTPContentTypeHeader('text/html')

active_page = "admin"

-- get config parameters like the id and name
local script_subdir = _GET["subdir"]
local confset_id = _GET["confset_id"]
local script_filter = _GET["user_script"]
local configset = user_scripts.getConfigsets()[tonumber(confset_id)]

if not haveAdminPrivileges() or not configset then
  return
end

local confset_name = configset.name

-- create a table that holds localization about hooks name
local titles = {
   ["host"] = i18n("config_scripts.granularities.host"),
   ["snmp_device"] = i18n("config_scripts.granularities.snmp_device"),
   ["system"] = i18n("config_scripts.granularities.system"),
   ["flow"] = i18n("config_scripts.granularities.flow"),
   ["interface"] = i18n("config_scripts.granularities.interface"),
   ["network"] = i18n("report.local_networks"),
   ["syslog"] = i18n("config_scripts.granularities.syslog")
}

page_utils.print_header(i18n("scripts_list.scripts_x", { subdir=titles[script_subdir], config=confset_name }))

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- Initialize apps_and_categories
-- Check out generate_multi_select in scripts-list-utils.js for the format
local cat_groups = {label = i18n("categories"), elements = {}}
local app_groups = {label = i18n("applications"), elements = {}}
local elems = {}

for cat, _ in pairsByKeys(interface.getnDPICategories(), asc_insensitive) do
  cat_groups.elements[#cat_groups.elements + 1] = cat
end

for app, _ in pairsByKeys(interface.getnDPIProtocols(), asc_insensitive) do
  app_groups.elements[#app_groups.elements + 1] = app
end

apps_and_categories = {cat_groups, app_groups}

-- print config_list.html template
print(template.gen("script_list.html", {
   script_list = {
       subdir = script_subdir,
       template_utils = template,
       hooks_localizated = titles,
       confset_id = confset_id,
       script_subdir = script_subdir,
       confset_name = confset_name,
       timeout_csrf = timeout_csrf,
       script_filter = script_filter,
       page_url = ntop.getHttpPrefix() .. string.format("/lua/admin/edit_configset.lua?confset_id=%u&subdir=%s", confset_id, script_subdir),
       apps_and_categories = json.encode(apps_and_categories),
   }
}))

-- append the menu below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
