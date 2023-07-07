--
-- (C) 2013-23 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/host/?.lua;" .. package.path

local rest_utils = require "rest_utils"
local json = require("dkjson")
local vulnerability_scan = require "vulnerability_scan"


local host = _GET["host"]
local scan_type = _GET["scan_type"]
local scan_params = _GET["scan_params"]
local single_host = toboolean(_GET["scan_single_host"]) or false

local debug = false
debug = true


if single_host then 
    if isEmptyString(host) or isEmptyString(scan_type) then
        rest_utils.answer(rest_utils.consts.err.invalid_args)
    end

    local res = vulnerability_scan.scan_host(scan_type, scan_params, host, true)

    if res == 1 then
        if debug then
            tprint("SENDING BACK RESPO")
        end
        rest_utils.answer(rest_utils.consts.success.ok)
    end
else 

    local res = vulnerability_scan.scan_all_host(true)

    if res == 1 then
        if debug then
            tprint("SENDING BACK ALLs RESPO")
        end
        rest_utils.answer(rest_utils.consts.success.ok)
    end
end

rest_utils.answer(rest_utils.consts.err.internal_error)

