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

if not ascan_utils.is_nmap_installed() then
    rest_utils.answer(rest_utils.consts.err.not_enabled, {error = i18n("hosts_stats.page_scan_hosts.nmap_not_installed")})
    return
end

-- A write: _POST (filled only with a valid CSRF)
local host = _POST["host"]
local scan_type = _POST["scan_type"]
local scan_ports = _POST["scan_ports"]
local discovered_host_scan_type = _POST["discovered_host_scan_type"]
local scan_frequency = _POST["scan_frequency"]
local is_edit = toboolean(_POST["is_edit"])
local cidr = _POST["vs_cidr"]

if isEmptyString(host) or isEmptyString(scan_type) then
    rest_utils.answer(rest_utils.consts.err.bad_content)
    return
end

-- Validate that host is a plain IP address or CIDR before passing to nmap,
-- preventing OS command injection via shell metacharacters in the host parameter.
local ip_part = host:match("^([^/]+)") or host
if not isIPv4(ip_part) and not isIPv6(ip_part) then
    rest_utils.answer(rest_utils.consts.err.bad_content)
    return
end

-- Validate the scan types, as they are the names of the Lua modules loaded to perform the scans.
if not ascan_utils.is_valid_scan_type(scan_type) then
    rest_utils.answer(rest_utils.consts.err.bad_content)
    return
end

-- Periodicity: none, every night, every week (modal-add-vs-host.vue)
if not isEmptyString(scan_frequency) and not ascan_utils.is_valid_scan_frequency(scan_frequency) then
    rest_utils.answer(rest_utils.consts.err.bad_content)
    return
end

if not isEmptyString(discovered_host_scan_type) then
    for _, discovered_scan_type in ipairs(split(discovered_host_scan_type, ",")) do
        if not ascan_utils.is_valid_scan_type(discovered_scan_type) then
            rest_utils.answer(rest_utils.consts.err.bad_content)
            return
        end
    end
end

local result = nil
local id = nil


 -- TODO REFACTOR
if scan_type ~= 'ipv4_netscan' then
    if isEmptyString(cidr) then

        if (not is_edit) then
            result,id = ascan_utils.add_host_pref(scan_type, host,scan_ports, scan_frequency, nil, cidr)

            ascan_utils.schedule_ondemand_single_host_scan(scan_type,host,scan_ports,id,false,false,false)
        else 
            result,id = ascan_utils.edit_host_pref(scan_type, host,scan_ports, scan_frequency)
        end
    else 
        local hosts_to_save = ascan_utils.get_active_hosts(host, cidr)
        if (next(hosts_to_save)) then
            for _,item in ipairs(hosts_to_save) do
                if (not is_edit) then
                    result,id = ascan_utils.add_host_pref(scan_type, item,scan_ports, scan_frequency, nil, 32 --[[ on host discovered cidr is 32 ]])
                    ascan_utils.schedule_ondemand_single_host_scan(scan_type,item,scan_ports,id,false,false,false)
                else
                    result,id = ascan_utils.edit_host_pref(scan_type, item,scan_ports, scan_frequency)
                end
            end
        else
            result = 3 -- not found hosts
        end
    end

else
    -- ipv4_netscan -> case

    if (not is_edit) then
        result,id = ascan_utils.add_host_pref(scan_type, host,scan_ports, scan_frequency, discovered_host_scan_type, cidr)
        ascan_utils.schedule_ondemand_single_host_scan(scan_type,host,scan_ports,id,false,false,false, cidr)
    else
        result,id = ascan_utils.edit_host_pref(scan_type, host,scan_ports, scan_frequency, discovered_host_scan_type)
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
