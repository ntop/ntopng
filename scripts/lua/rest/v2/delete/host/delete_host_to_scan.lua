--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/host/?.lua;" .. package.path


local rest_utils = require "rest_utils"
local vulnerability_scan_utils = require "vulnerability_scan_utils"

local host = _GET["host"]
local scan_type = _GET["scan_type"]

if isEmptyString(host) or isEmptyString(scan_type) then
    rest_utils.answer(rest_utils.consts.err.bad_content)
end


local function delete_host_to_scan(ip, scan_type) 
    return vulnerability_scan_utils.delete_host_to_scan(ip, scan_type) 
end

local del_result = delete_host_to_scan(host,scan_type)

if del_result == 1 then
    rest_utils.answer(rest_utils.consts.success.ok)
else
    rest_utils.answer(rest_utils.consts.err.internal_error)
end