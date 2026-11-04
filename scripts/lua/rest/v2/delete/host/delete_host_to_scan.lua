--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/host/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/active_scan/?.lua;" .. package.path



require "http_lint"
local rest_utils = require "rest_utils"
local ascan_utils = require "ascan_utils"

if not isAdministrator() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

-- A write: _POST (filled only with a valid CSRF). The flags are "true"/"false" strings:
-- "false" is true in Lua, a single delete removed every host
local host = _POST["host"]
local scan_type = _POST["scan_type"]
local delete_all_scan_hosts = toboolean(_POST["delete_all_scan_hosts"])
local delete_failed_scan_hosts = toboolean(_POST["delete_failed_scan_hosts"])

if not delete_all_scan_hosts and not delete_failed_scan_hosts then
    if isEmptyString(host) or isEmptyString(scan_type) then
        rest_utils.answer(rest_utils.consts.err.bad_content)
        return
    end
end

local del_result = 0

if delete_all_scan_hosts then
    -- Delete all hosts to scan
    del_result = ascan_utils.delete_host_to_scan(nil, nil, true)
elseif delete_failed_scan_hosts then
    -- Only delete hosts whose last scan failed (host down or unreachable)
    del_result = ascan_utils.delete_failed_hosts_to_scan()
else
    -- Only delete a host and a scan type
    del_result = ascan_utils.delete_host_to_scan(host, scan_type, false)
end

if del_result then
    rest_utils.answer(rest_utils.consts.success.ok)
else
    rest_utils.answer(rest_utils.consts.err.internal_error)
end
