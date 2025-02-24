--
-- (C) 2013-24 - ntop.org
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

tprint(host)
tprint(scan_type)
tprint(delete_all_scan_hosts)
tprint("--------")

if not delete_all_scan_hosts then
if isEmptyString(host) or isEmptyString(scan_type) then
    rest_utils.answer(rest_utils.consts.err.bad_content)
end
end

local del_result = 0

if delete_all_scan_hosts then
-- Delete all hosts to scan
del_result = vs_utils.delete_host_to_scan(nil, nil, true)
else 
-- Only delete a host and a scan type
del_result = vs_utils.delete_host_to_scan(host, scan_type, false)
end

if del_result then
rest_utils.answer(rest_utils.consts.success.ok)
else
rest_utils.answer(rest_utils.consts.err.internal_error)
end
