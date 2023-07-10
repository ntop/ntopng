--
-- (C) 2013-23 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/host/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local scan_utils = require "scan_utils"
local debug = false

--debug = true

local function retrieve_host() 
    return scan_utils.retrieve_hosts_to_scan(debug)
end

rest_utils.answer(rest_utils.consts.success.ok, retrieve_host())