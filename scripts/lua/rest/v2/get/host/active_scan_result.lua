--
-- (C) 2013-26 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/host/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/active_scan/?.lua;" .. package.path


require "lua_utils"
local rest_utils = require "rest_utils"

if not isAdministrator() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end
local ascan_utils = require "ascan_utils"

local host = _GET["host"]
local scan_type = _GET["scan_type"]
local scan_return_result = toboolean(_GET["scan_return_result"]) or false
local epoch = tonumber(_GET["epoch"])

-- The scan type is a module name (and goes into the ClickHouse query)
if isEmptyString(host) or not ascan_utils.is_valid_scan_type(scan_type) then
    rest_utils.answer(rest_utils.consts.err.invalid_args)
    return
end

local result = ascan_utils.retrieve_hosts_scan_result(scan_type, host, epoch)
if scan_return_result then
    rest_utils.answer(rest_utils.consts.success.ok, {rsp=result});
else
    local extra_headers = {}

    extra_headers["Content-Disposition"] = "attachment;filename=\"scan_result_export_"..os.time().."_".. host .."_".. scan_type..".txt\""
    rest_utils.vanilla_payload_response(rest_utils.consts.success.ok, result, "application/octet-stream", extra_headers)
end