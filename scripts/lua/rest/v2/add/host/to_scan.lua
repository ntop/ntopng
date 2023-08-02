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
local scan_ports = _GET["scan_ports"]
local scan_frequency = _GET["auto_scan_frequency"]

local cidr = _GET["cidr"]

if isEmptyString(host) or isEmptyString(scan_type) then
    rest_utils.answer(rest_utils.consts.err.bad_content)
    return
end
local result = nil

if isEmptyString(cidr) then
    result = vs_utils.save_host_to_scan(scan_type, host, nil, nil, nil, 5, scan_ports, scan_frequency)
else 
    local hosts_to_save = vs_utils.get_active_hosts(host, cidr)

    for _,item in ipairs(hosts_to_save) do
        result = vs_utils.save_host_to_scan(scan_type, item, nil, nil, nil, 5, scan_ports, scan_frequency)
    end
end

if result == 1 then
    rest_utils.answer(rest_utils.consts.success.ok)
else
    rest_utils.answer(rest_utils.consts.err.internal_error)
end
