--
-- (C) 2021 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

local checks_utils = {}

--- Load the cofigset titles
--- @return table
function checks_utils.load_configset_titles()
    return {
        ["host"] = i18n("config_scripts.granularities.host"),
        ["snmp_device"] = i18n("config_scripts.granularities.snmp_device"),
        ["system"] = i18n("config_scripts.granularities.system"),
        ["flow"] = i18n("config_scripts.granularities.flow"),
        ["interface"] = i18n("config_scripts.granularities.interface"),
        ["network"] = i18n("report.local_networks"),
        ["syslog"] = i18n("config_scripts.granularities.syslog")
     }
end

return checks_utils