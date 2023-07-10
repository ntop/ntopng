--
-- (C) 2013-23 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/host/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local scan_utils = require "scan_utils"


local function retrieve_host_scan_result(host, scan_type) 
    return scan_utils.retrieve_hosts_scan_result(host, scan_type)
end

local host = _GET["host"]
local scan_type = _GET["scan_type"]

tprint("HERE1")


if isEmptyString(host) or isEmptyString(scan_type) then
    rest_utils.answer(rest_utils.consts.err.invalid_args)
end

local result = retrieve_host_scan_result(host, scan_type)
if result == {} then
    tprint("HERE2")
    rest_utils.answer(rest_utils.consts.success.ok, result )
else
    local extra_headers = {}
    tprint("HERE3")
    extra_headers["Content-Disposition"] = "attachment;filename=\"scan_result_export_"..os.time()..".txt\""
    rest_utils.vanilla_payload_response(rest_utils.consts.success.ok, result, "application/octet-stream", extra_headers)
end
