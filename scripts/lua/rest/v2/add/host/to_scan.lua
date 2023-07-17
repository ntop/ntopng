--
-- (C) 2013-23 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/host/?.lua;" .. package.path

local rest_utils = require "rest_utils"
local scan_utils = require "scan_utils"


local host = _GET["host"]
local scan_type = _GET["scan_type"]
local scan_params = _GET["scan_params"]

if isEmptyString(host) or isEmptyString(scan_type) then
    tprint("HOST: ")
    tprint(host)
    tprint("SCAN_TYPE: ")
    tprint(scan_type)
    rest_utils.answer(rest_utils.consts.err.bad_content)
end

local function set_host_to_scan(ip, scan_type, scan_params) 
    return scan_utils.save_host_to_scan(scan_type, scan_params, ip)
end


local result = set_host_to_scan(host, scan_type, scan_params)

if result == 1 then
    rest_utils.answer(rest_utils.consts.success.ok)
else
    rest_utils.answer(rest_utils.consts.err.internal_error)
end