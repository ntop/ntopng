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
local scan_id = _GET["scan_id"] or nil
local is_edit = toboolean(_GET["is_edit"])



local cidr = _GET["cidr"]

if isEmptyString(host) or isEmptyString(scan_type) then
    rest_utils.answer(rest_utils.consts.err.bad_content)
    return
end
local result = nil
local id = nil

if isEmptyString(cidr) then

    if (not is_edit) then
        result,id = vs_utils.add_host_pref(scan_type, host,scan_ports, scan_frequency)

        vs_utils.schedule_host_scan(scan_type,host,scan_ports,id,false)
    else 
        result,id = vs_utils.edit_host_pref(scan_type, host,scan_ports, scan_frequency)
    end
else 
    local hosts_to_save = vs_utils.get_active_hosts(host, cidr)

    for _,item in ipairs(hosts_to_save) do
        if (not is_edit) then
            result,id = vs_utils.add_host_pref(scan_type, item,scan_ports, scan_frequency)
            vs_utils.schedule_host_scan(scan_type,item,scan_ports,id,false)
        else
            result,id = vs_utils.edit_host_pref(scan_type, item,scan_ports, scan_frequency)

        end
    end
end

if result == 1 then
    -- ok
    rest_utils.answer(rest_utils.consts.success.ok, {rsp= true})
elseif result == 2 then
    --already inserted case
    rest_utils.answer(rest_utils.consts.success.ok, {rsp= false})

else
    rest_utils.answer(rest_utils.consts.err.internal_error)
end
