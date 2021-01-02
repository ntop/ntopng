--
-- (C) 2019-21 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local ui_utils = require("ui_utils")
local page_utils = require("page_utils")
local user_scripts = require "user_scripts"
local template = require "template_utils"

sendHTTPContentTypeHeader('text/html')

if not haveAdminPrivileges() then
  return
end

if(_POST["action"] == "reset_config") then
    user_scripts.resetConfigsets()
end

-- get subdir form url
local subdir = _GET["subdir"]
-- set default value for subdir if its empty
if subdir == nil or subdir == "" then
    subdir = "host"
end

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

page_utils.set_active_menu_entry(page_utils.menu_entries.scripts_config, { product=titles[subdir] })

-- append menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local default_config_only = user_scripts.getScriptType(subdir).default_config_only

if default_config_only == nil then
    default_config_only = false
end

-- print scripts_config template
print(template.gen("pages/scripts_config.template", {
    ui_utils = ui_utils,
    config_list = {
        user_scripts = user_scripts,
        subdir = subdir,
        template_utils = template,
        hooks_localizated = titles,
        default_config_only_subdir = default_config_only,
        import_csrf = ntop.getRandomCSRFValue(),
    }
}))

-- append footer beloew the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
