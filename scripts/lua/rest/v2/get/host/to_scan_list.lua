--
-- (C) 2013-23 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/vulnerability_scan/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local vs_utils = require "vs_utils"
local search_map = _GET["map_search"]
local format_utils = require "format_utils"

-- ##################################################################
-- params
local port = _GET["port"]
local sort = _GET["sort"]

if (not isEmptyString(search_map)) then
    -- trim search_map string
    search_map = trimString(search_map)
end
-- ##################################################################

-- Function to convert ipv6 or ipv4 to hexadecimal int
local function ipv_to_hex(ip)
    -- Check if it's an IPv6 address
    if string.find(ip, ":") then
        local parts = {}
        for part in string.gmatch(ip, "([^:]+)") do
            table.insert(parts, part)
        end
        local hex_parts = {}
        for _, part in ipairs(parts) do
            -- Ensure each part has at least 4 characters by padding with zeros
            part = string.format("%04s", part)
            table.insert(hex_parts, part)
        end
        return table.concat(hex_parts, ":")
    else
        -- IPv4 address
        local parts = {}
        for part in string.gmatch(ip, "([^.]+)") do
            table.insert(parts, part)
        end
        local hex_parts = {}
        for _, part in ipairs(parts) do
            local hex_part = string.format("%02X", tonumber(part))
            table.insert(hex_parts, hex_part)
        end
        return table.concat(hex_parts, ".")
    end
end

-- ##################################################################

-- Function to check if a spceific port is in the ports_list string
local function portCheck(tcp_ports_list, port)
    if (isEmptyString(port)) then
        return true
    else
        local ports = split(tcp_ports_list, ",")
        for _, item in ipairs(ports) do
            if (item == port) then
                return true
            end
        end

        return false
    end
end

-- ##################################################################

-- Function to format epoch
local function format_epoch(value)
    if (value.last_scan ~= nil and value.last_scan.epoch ~= nil) then
        return format_utils.formatPastEpochShort(value.last_scan.epoch)
    else
        return value.last_scan.time
    end
end

-- ##################################################################

-- Function to format port_list string with service names
local function format_port_list(ports_string_list, protocol)

    local formatted_ports_list = ""
    for index, port in ipairs(split(ports_string_list, ',')) do
        local service_name = mapServiceName(port, protocol)
        local port_label = vs_utils.format_port_label(port, service_name, protocol)
        if (index == 1) then
            formatted_ports_list = port_label
        else
            formatted_ports_list = string.format("%s,%s", formatted_ports_list, port_label)
        end
    end

    return formatted_ports_list
end

-- ##################################################################

-- Function compare for sort
local function compare_host(a, b)

    local a_tmp = ipv_to_hex(a.host)
    local b_tmp = ipv_to_hex(b.host)

    return a_tmp < b_tmp
end

-- ##################################################################

-- Function to to compare ports detected by ntopng and ports discovered using nmap
local function get_ports_comparison_result(rsp, ports_string_list, ports_detected)

    local result = {}
    -- cases :
    -- 1: No host traffic but same vs ports and ntopng ports
    -- 2: Host traffic with same vs ports and ntopng ports
    -- 3: Host traffic and different ports (vs ports < ntopng ports)
    -- 4: Host traffic and different ports (vs ports > ntopng ports)
    if (isEmptyString(ports_string_list) and not next(ports_detected)) then
        -- vs_scan ports = 0; detected_ports = 0;
        -- no badge

        result.ports_case = vs_utils.ports_diff_case.no_diff
    elseif ((not isEmptyString(ports_string_list)) and (not next(ports_detected))) then
        -- vs_scan ports != 0; detected_ports = 0;
        -- case 4
        result.ports_case = vs_utils.ports_diff_case.vs_more_t_ntopng
        result.ports_unused = split(ports_string_list, ",")
    elseif (isEmptyString(ports_string_list) and (next(ports_detected))) then
        -- vs_scan ports = 0; detected_ports != 0;
        -- case 3
        result.ports_case = vs_utils.ports_diff_case.ntopng_more_t_vs
        result.ports_filtered = ports_detected
    elseif ((not isEmptyString(ports_string_list)) and (next(ports_detected))) then
        -- vs_scan ports != 0; detected_ports != 0;

        -- could be:
        -- same ports with no traffic (case 1)
        -- same ports without traffic (case 2)
        -- different ports (case 3 or case 4)

        result.ports_unused, result.ports_filtered, result.ports_case =
            vs_utils.compare_ports(ports_string_list, ports_detected)
    end

    return result

end

-- ##################################################################

-- Function to format result
local function format_result(result)
    local rsp = {}
    if result then

        for _, value in ipairs(result) do
            local tcp_ports_string_list = value.tcp_ports_list
            local udp_ports_string_list = value.udp_ports_list

            -- FIX for early development versions
            if (value.scan_type == "tcp_openports") then
                value.scan_type = "tcp_portscan"
            end
            if (value.scan_type == "udp_openports") then
                value.scan_type = "udp_portscan"
            end

            -- FIX ME with udp port check
            if (portCheck(tcp_ports_string_list, port) or portCheck(udp_ports_string_list, port)) then
                if (isEmptyString(search_map)) then
                    rsp[#rsp + 1] = value
                    rsp[#rsp].num_vulnerabilities_found = format_high_num_value_for_tables(value,
                        "num_vulnerabilities_found")
                    rsp[#rsp].num_open_ports = format_high_num_value_for_tables(value, "num_open_ports")
                    rsp[#rsp].tcp_ports = format_high_num_value_for_tables(value, "tcp_ports")
                    rsp[#rsp].udp_ports = format_high_num_value_for_tables(value, "udp_ports")
                    if (rsp[#rsp].tcp_ports == 0 and rsp[#rsp].udp_ports == 0) then
                        rsp[#rsp].tcp_ports = rsp[#rsp].num_open_ports
                    end
                    if (rsp[#rsp].last_scan) then
                        rsp[#rsp].last_scan.time = format_epoch(value)
                    end
                else
                    if (value.host == search_map or string.find(value.host, search_map) or
                        string.find((value.host_name or ""), search_map)) then
                        rsp[#rsp + 1] = value
                        rsp[#rsp].num_vulnerabilities_found =
                            format_high_num_value_for_tables(value, "num_vulnerabilities_found")
                        rsp[#rsp].num_open_ports = format_high_num_value_for_tables(value, "num_open_ports")
                        if (rsp[#rsp].last_scan) then
                            rsp[#rsp].last_scan.time = format_epoch(value)
                        end
                    end
                end

                if (next(rsp) and not isEmptyString(tcp_ports_string_list)) then
                    rsp[#rsp].tcp_ports_list = format_port_list(tcp_ports_string_list, "tcp")
                end

                if (next(rsp) and not isEmptyString(udp_ports_string_list)) then
                    rsp[#rsp].udp_ports_list = format_port_list(udp_ports_string_list, "udp")
                end
            end

            if (next(rsp)) then
                local tcp_ports_detected, host_in_mem, udp_ports_detected =
                    vs_utils.retrieve_detected_ports(rsp[#rsp].host)

                local tcp_ports_compare_result = {}
                local udp_ports_compare_result = {}

                if (rsp[#rsp].scan_type == "tcp_portscan") then
                    tcp_ports_compare_result = get_ports_comparison_result(rsp, tcp_ports_string_list,
                        tcp_ports_detected)

                    rsp[#rsp].tcp_ports_unused = tcp_ports_compare_result.ports_unused
                    rsp[#rsp].tcp_ports_filtered = tcp_ports_compare_result.ports_filtered
                    rsp[#rsp].tcp_ports_case = tcp_ports_compare_result.ports_case
                else
                    udp_ports_compare_result = get_ports_comparison_result(rsp, udp_ports_string_list,
                        udp_ports_detected)
                    rsp[#rsp].udp_ports_unused = udp_ports_compare_result.ports_unused
                    rsp[#rsp].udp_ports_filtered = udp_ports_compare_result.ports_filtered
                    rsp[#rsp].udp_ports_case = udp_ports_compare_result.ports_case
                end
                rsp[#rsp].host_in_mem = host_in_mem
            end

        end

        if not isEmptyString(sort) and sort == 'ip' then
            table.sort(rsp, compare_host)
        end
    end
    return rsp
end

-- ##################################################################

-- Function to retrieve data
local function retrieve_host(host)
    local result = vs_utils.retrieve_hosts_to_scan()

    return format_result(result)
end

-- ##################################################################

-- REST response
rest_utils.answer(rest_utils.consts.success.ok, retrieve_host())
