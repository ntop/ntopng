--
-- (C) 2013-23 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"

local debug = false
debug = true


local res = {}
res[#res+1] = {
    id = "nmap",
    value = "nmap", 
    label = i18n("hosts_stats.page_scan_hosts.scan_type_list.nmap")
}

rest_utils.answer(rest_utils.consts.success.ok, res)


