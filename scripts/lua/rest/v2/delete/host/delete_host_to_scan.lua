--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/host/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/vulnerability_scan/?.lua;" .. package.path



local rest_utils = require "rest_utils"
local vs_utils = require "vs_utils"

local host = _GET["host"]
local scan_type = _GET["scan_type"]
local delete_all_scan_hosts = _GET["delete_all_scan_hosts"]

if not delete_all_scan_hosts then
    if isEmptyString(host) or isEmptyString(scan_type) then
        rest_utils.answer(rest_utils.consts.err.bad_content)
    end
end


local function delete_host_to_scan(ip, scan_type) 
    return vs_utils.delete_host_to_scan(ip, scan_type) 
end

local function delete_all_hosts_to_scan()
    return vs_utils.delete_host_to_scan(nil, nil, true) 
end

local del_result = 0
if not delete_all_scan_hosts then
    del_result = delete_host_to_scan(host,scan_type)
else 
    del_result = delete_all_hosts_to_scan()
end

if del_result == 1 then
    rest_utils.answer(rest_utils.consts.success.ok)
else
    rest_utils.answer(rest_utils.consts.err.internal_error)
end
