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
local user_scripts = require "user_scripts"
local template = require "template_utils"

sendHTTPContentTypeHeader('text/html')

if not haveAdminPrivileges() then
  return
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
    ["network"] = i18n("config_scripts.granularities.network"),
    ["syslog"] = i18n("config_scripts.granularities.syslog")
 }

-- append headers to config_list
page_utils.print_header(i18n("config_scripts.config_x", { product=titles[subdir] }))

active_page = "admin"

-- append menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

-- print config_list.html template
print(template.gen("config_list.html", {
    config_list = {
        user_scripts = user_scripts,
        subdir = subdir,
        template_utils = template,
        hooks_localizated = titles,
        timeout_csrf = timeout_csrf,
        import_csrf = ntop.getRandomCSRFValue(),
    }
}))

-- append footer beloew the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
