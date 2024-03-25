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
local scan_ports = _GET["scan_ports"]
local discovered_host_scan_type = _GET["discovered_host_scan_type"]
local scan_frequency = _GET["scan_frequency"]
local scan_id = _GET["scan_id"] or nil
local is_edit = toboolean(_GET["is_edit"])
local cidr = _GET["vs_cidr"]

if isEmptyString(host) or isEmptyString(scan_type) then
    rest_utils.answer(rest_utils.consts.err.bad_content)
    return
end
local result = nil
local id = nil


 -- TODO REFACTOR
if scan_type ~= 'ipv4_netscan' then
    if isEmptyString(cidr) then

        if (not is_edit) then
            result,id = vs_utils.add_host_pref(scan_type, host,scan_ports, scan_frequency, nil)

            vs_utils.schedule_ondemand_single_host_scan(scan_type,host,scan_ports,id,false,false,false)
        else 
            result,id = vs_utils.edit_host_pref(scan_type, host,scan_ports, scan_frequency)
        end
    else 
        local hosts_to_save = vs_utils.get_active_hosts(host, cidr)
        if (next(hosts_to_save)) then
            for _,item in ipairs(hosts_to_save) do
                if (not is_edit) then
                    result,id = vs_utils.add_host_pref(scan_type, item,scan_ports, scan_frequency, nil)
                    vs_utils.schedule_ondemand_single_host_scan(scan_type,item,scan_ports,id,false,false,false)
                else
                    result,id = vs_utils.edit_host_pref(scan_type, item,scan_ports, scan_frequency)
                end
            end
        else
            result = 3 -- not found hosts
        end
    end

else
    -- ipv4_netscan -> case

    if (not is_edit) then
        result,id = vs_utils.add_host_pref(scan_type, host,scan_ports, scan_frequency, discovered_host_scan_type)
        vs_utils.schedule_ondemand_single_host_scan(scan_type,host,scan_ports,id,false,false,false)
    else
        result,id = vs_utils.edit_host_pref(scan_type, host,scan_ports, scan_frequency, discovered_host_scan_type)
    end

end

if result == 1 then
    -- ok
    rest_utils.answer(rest_utils.consts.success.ok, {rsp= 1})
elseif result == 2 then
    --already inserted case
    rest_utils.answer(rest_utils.consts.success.ok, {rsp= 2})
elseif result == 3 then
    -- not found hosts with netscan case
    rest_utils.answer(rest_utils.consts.success.ok, {rsp= 3})
else
    rest_utils.answer(rest_utils.consts.err.internal_error)
end
