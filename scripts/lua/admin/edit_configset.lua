--
-- (C) 2019-20 - ntop.org
--

local dirs = ntop.getDirs()
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
local discover = require "discover_utils"
local rest_utils = require "rest_utils"
local auth = require "auth"

if not auth.has_capability(auth.capabilities.user_scripts) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

sendHTTPContentTypeHeader('text/html')


-- get config parameters like the id and name
local script_subdir = _GET["subdir"]
local confset_id = _GET["confset_id"]
local script_filter = _GET["user_script"]
local configset = user_scripts.getConfigsets()[tonumber(confset_id)]
local script_type = user_scripts.getScriptType(script_subdir)
interface.select(getSystemInterfaceId())
local scripts = user_scripts.load(getSystemInterfaceId(), script_type, script_subdir)

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

page_utils.set_active_menu_entry(page_utils.menu_entries.scripts_config)
--page_utils.print_header(i18n("scripts_list.scripts_x", { subdir=titles[script_subdir], config=confset_name }))

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- APP/Categories types

-- Initialize apps_and_categories
-- Check out generate_multi_select in scripts-list-utils.js for the format
local cat_groups = {label = i18n("categories"), elements = {}}
local app_groups = {label = i18n("applications"), elements = {}}
local elems = {}

for cat, _ in pairsByKeys(interface.getnDPICategories(), asc_insensitive) do
  cat_groups.elements[#cat_groups.elements + 1] = {cat, getCategoryLabel(cat)}
end

for app, _ in pairsByKeys(interface.getnDPIProtocols(), asc_insensitive) do
  app_groups.elements[#app_groups.elements + 1] = {app, app}
end

apps_and_categories = {cat_groups, app_groups}

--tprint(user_scripts.script_categories)
local script_categories = {}
for script_name, script in pairs(scripts.modules) do
   for cat_k, cat_v in pairs(user_scripts.script_categories) do
      if script["category"]["id"] == cat_v["id"] and not script_categories[cat_k] then
	 script_categories[cat_k] = cat_v
	 break
      end
   end
end

-- Device types

local device_types = {}

for type_id in discover.sortedDeviceTypeLabels() do
   local label = discover.devtype2string(type_id)
   local devtype = discover.id2devtype(type_id)

   device_types[#device_types + 1] = {devtype, label}
end

local device_types_list = {{elements = device_types}}

local context = {
   script_list = {
      subdir = script_subdir,
      template_utils = template,
      hooks_localizated = titles,
      confset_id = confset_id,
      script_subdir = script_subdir,
      confset_name = confset_name,
      script_filter = script_filter,
      page_url = ntop.getHttpPrefix() .. string.format("/lua/admin/edit_configset.lua?confset_id=%u&subdir=%s", confset_id, script_subdir),
      apps_and_categories = json.encode(apps_and_categories),
      device_types = json.encode(device_types_list),
   },
   script_categories = script_categories,
   info = ntop.getInfo(),
}

-- print config_list.html template
print(template.gen("pages/edit_configset.html", context))

-- append the menu below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
