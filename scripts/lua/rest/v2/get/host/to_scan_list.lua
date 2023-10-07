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

local port = _GET["port"]

local sort = _GET["sort"]

local function portCheck(tcp_ports_list, port) 
    if (isEmptyString(port)) then
        return true
    else 
        local ports = split(tcp_ports_list,",")
        for _, item in ipairs(ports) do
            if (item == port) then
                return true
            end
        end

        return false
    end
end


local function format_epoch(value)
    if (value.last_scan~= nil and value.last_scan.epoch~= nil) then
        return format_utils.formatPastEpochShort(value.last_scan.epoch)
    else 
        return value.last_scan.time
    end
end

local function format_result(result) 
    local rsp = {}
    if result then
        if not isEmptyString(sort) and sort == 'ip' then
            table.sort(result, function (k1, k2)  return (k1.host or k1.host_name) < (k2.host or k2.host_name) end )
        end
        for _,value in ipairs(result) do

            local tcp_ports_string_list = value.tcp_ports_list
            -- FIX ME with udp port check
            if portCheck(tcp_ports_string_list, port) then
                if (isEmptyString(search_map)) then
                    rsp[#rsp+1] = value
                    rsp[#rsp].num_vulnerabilities_found = format_high_num_value_for_tables(value, "num_vulnerabilities_found")
                    rsp[#rsp].num_open_ports = format_high_num_value_for_tables(value, "num_open_ports")
                    rsp[#rsp].tcp_ports = format_high_num_value_for_tables(value, "tcp_ports")
                    rsp[#rsp].udp_ports = format_high_num_value_for_tables(value, "udp_ports")
                    if (rsp[#rsp].tcp_ports == 0 and rsp[#rsp].udp_ports == 0) then
                        rsp[#rsp].tcp_ports = rsp[#rsp].num_open_ports
                    end
                    if(rsp[#rsp].last_scan) then
                        rsp[#rsp].last_scan.time = format_epoch(value)
                    end
                else 
                    if (value.host == search_map or string.find(value.host,search_map) or string.find(value.host_name,search_map)) then
                        rsp[#rsp+1] = value
                        rsp[#rsp].num_vulnerabilities_found = format_high_num_value_for_tables(value, "num_vulnerabilities_found")
                        rsp[#rsp].num_open_ports = format_high_num_value_for_tables(value, "num_open_ports")
                        if(rsp[#rsp].last_scan) then
                            rsp[#rsp].last_scan.time = format_epoch(value)
                        end
                    end
                end


                if (next(rsp) and not isEmptyString(tcp_ports_string_list)) then
                    local formatted_ports_list = ""
                    for index,port in ipairs(split(tcp_ports_string_list,',')) do
                        local service_name = mapServiceName(port, "tcp")
                        local port_label = vs_utils.format_port_label(port, service_name, "tcp")
                        
    
                        
                        if (index == 1) then
                            formatted_ports_list = port_label
                        else
                            formatted_ports_list = string.format("%s,%s",formatted_ports_list,port_label)
                        end
                    end
    
                    rsp[#rsp].tcp_ports_list = formatted_ports_list
                end

                if not isEmptyString(sort) and sort == 'ip' then
                    rsp[#rsp].host = ternary(isEmptyString(rsp[#rsp].host_name), rsp[#rsp].host, rsp[#rsp].host_name)
                end
            end

            if(next(rsp)) then
                local tcp_ports_detected,host_in_mem = vs_utils.retrieve_detected_ports(rsp[#rsp].host)

                -- cases :
                    -- 1: No host traffic but same vs ports and ntopng ports
                    -- 2: Host traffic with same vs ports and ntopng ports
                    -- 3: Host traffic and different ports (vs ports < ntopng ports)
                    -- 4: Host traffic and different ports (vs ports > ntopng ports)
                if (isEmptyString(tcp_ports_string_list) and not next(tcp_ports_detected)) then
                    -- vs_scan ports = 0; detected_ports = 0;
                    -- no badge

                    rsp[#rsp].tcp_ports_case = vs_utils.tcp_ports_diff_case.no_diff
                elseif ((not isEmptyString(tcp_ports_string_list)) and (not next(tcp_ports_detected))) then
                    -- vs_scan ports != 0; detected_ports = 0;
                    -- case 4
                    rsp[#rsp].tcp_ports_case = vs_utils.tcp_ports_diff_case.vs_more_t_ntopng
                    rsp[#rsp].tcp_ports_unused = split(tcp_ports_string_list,",")
                elseif (isEmptyString(tcp_ports_string_list) and (next(tcp_ports_detected))) then
                    -- vs_scan ports = 0; detected_ports != 0;
                    -- case 3
                    rsp[#rsp].tcp_ports_case = vs_utils.tcp_ports_diff_case.ntopng_more_t_vs
                    rsp[#rsp].tcp_ports_filtered = tcp_ports_detected

                elseif ((not isEmptyString(tcp_ports_string_list)) and (next(tcp_ports_detected))) then
                    -- vs_scan ports != 0; detected_ports != 0;

                    -- could be: 
                        -- same ports with no traffic (case 1)
                        -- same ports without traffic (case 2)
                        -- different ports (case 3 or case 4)
                    
                    rsp[#rsp].tcp_ports_unused,rsp[#rsp].tcp_filtered_ports,rsp[#rsp].tcp_ports_case = vs_utils.compare_ports(tcp_ports_string_list,tcp_ports_detected)
                end
                rsp[#rsp].host_in_mem = host_in_mem
            end
        end

        if not isEmptyString(sort) and sort == 'ip' then
            table.sort(rsp, function (k1, k2)  return k1.host < k2.host end )
        end



    end 
    return rsp 
end

local function retrieve_host(host) 
    local result = vs_utils.retrieve_hosts_to_scan()

    return format_result(result)
end

rest_utils.answer(rest_utils.consts.success.ok, retrieve_host())

