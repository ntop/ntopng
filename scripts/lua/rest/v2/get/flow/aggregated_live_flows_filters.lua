--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/enterprise/modules/?.lua;" .. package.path

-- ##################################################################
-- Requires

require "lua_utils"
local rest_utils = require "rest_utils"
local format_utils = require("format_utils")
require "lua_utils_get"

if ntop.isEnterpriseM() then
    require "aggregate_live_flows"
end
-- ##################################################################
-- REST params

local ifid = _GET["ifid"]
local criteria = _GET["aggregation_criteria"] or ""
local rest_filters = {}

rest_filters["page"] = tonumber(_GET["draw"] or 0)
rest_filters["sort_column"] = _GET["sort"] or 'flows'
rest_filters["sort_order"] = _GET["order"] or 'desc'
rest_filters["start"] = 0
rest_filters["length"] = 0
rest_filters["map_search"] = _GET["map_search"]
rest_filters["host"] = _GET["host"]

-- ##################################################################
-- Enums

local filter_types = {
    vlan = 1,
    flow_device = 2
}

-- ##################################################################
-- Utils functions 

local function retrieve_aggregation_criteria(criteria)
    
    -- Aggregation criteria 
    local criteria_type_id = 1 -- by default application_protocol
    if criteria == "client" then
        criteria_type_id = 2
    elseif criteria == "server" then
        criteria_type_id = 3
    elseif criteria == "client_server_srv_port" then
        criteria_type_id = 7
    elseif ntop.isEnterpriseM() then
        criteria_type_id = get_criteria_type_id(criteria)
    end
    return criteria_type_id
end

-- ******************************************************************

local function is_filter_already_inserted(filters, filter_id)
    for id,x in ipairs(filters) do
        if(x.value == filter_id) then
            return id
        end
    end
    return -1
end

-- ******************************************************************

local function get_filter_item_label(element, filter_type)
    local label
    if (filter_type == filter_types.vlan) then
        label = ternary(element~=0, getFullVlanName(element, false), i18n('no_vlan'))
    elseif (filter_type == filter_types.flow_device) then
        label = getProbeName(element, false, false)
    end

    return label
end

-- ******************************************************************

local function get_filter_key(filter_type)
    local key
    if (filter_type == filter_types.vlan) then
        key = "vlan_id"
    elseif (filter_type == filter_types.flow_device) then
        key = "deviceIP"
    end

    return key
end 

-- ******************************************************************

local function add_new_filter_item_to_filters_array(filter_id,formatted_filters, filter_type)
    local index = is_filter_already_inserted(formatted_filters, filter_id)
    if index == -1 then
        local filter_label = get_filter_item_label(filter_id, filter_type)
        local filert_key = get_filter_key(filter_type)
        local filter_item = {
            count = 1,
            value = filter_id,
            label = filter_label,
            key = filert_key
        }
        formatted_filters[#formatted_filters+1] = filter_item
    else
        formatted_filters[index].count = formatted_filters[index].count + 1
    end

end

-- ******************************************************************

local function build_response(criteria)
    local formatted_vlan_filters = {}

    local criteria_type_id = retrieve_aggregation_criteria(criteria)

    local aggregated_info = interface.getProtocolFlowsStats(criteria_type_id, rest_filters["page"], rest_filters["sort_column"],
        rest_filters["sort_order"], rest_filters["start"], rest_filters["length"], ternary(not isEmptyString(rest_filters["map_search"]), rest_filters["map_search"], nil) , ternary(rest_filters["host"]~= "", rest_filters["host"], nil), nil)

    for _, data in pairs(aggregated_info or {}) do
        add_new_filter_item_to_filters_array(data.vlan_id, formatted_vlan_filters,filter_types.vlan)
    end

    table.sort(formatted_vlan_filters, function(a,b) return a.value < b.value end)
    table.insert(formatted_vlan_filters, 1, {
        key = "vlan_id",
        label = i18n('all'),
        value = ""
    })

    local formatted_device_filters = {}
    if ntop.isPro() and interface.isPacketInterface() == false then
        local flowdevs = interface.getFlowDevices() or {}
        local devips = getProbesName(flowdevs)
        if table.len(devips) > 0 then
            local in_out_rsp = {}
            formatted_device_filters = {{
                key = "deviceIP",
                value = "",
                label = i18n("all")
            }}
            for _, device_list in pairs(devips or {}) do
                for dev_ip, dev_resolved_name in pairsByValues(device_list, asc) do
                    local dev_name = dev_ip
                    if not isEmptyString(dev_resolved_name) and dev_resolved_name ~= dev_name then
                        dev_name = dev_resolved_name
                    end
                    formatted_device_filters[#formatted_device_filters + 1] = {
                        key = "deviceIP",
                        value = dev_ip,
                        label = dev_name
                    }
                end
            end
        end
    end
    
    local rsp = {}
    if (#formatted_vlan_filters > 2) then
        rsp[#rsp+1] = {
                action = "vlan_id",
                label = i18n("vlan"),
                tooltip = i18n("vlan_filter"),
                name = "vlan_id",
                value = formatted_vlan_filters
            }
    end

    if (#formatted_device_filters > 1) then
        rsp[#rsp+1] = {
            action = "deviceIP",
            label = i18n("flows_page.device_ip"),
            tooltip = i18n("flows_page.device_ip"),
            name = "deviceIP",
            value = formatted_device_filters
        }
    end

    if ntop.isPro() and not isEmptyString(_GET["deviceIP"]) then      
        local dev_ip = _GET["deviceIP"]          
        -- Flow exporter requested
        local in_ports = {{
            key = "inIfIdx",
            value = "",
            label = i18n("all")
        }}
        local ports_table = interface.getFlowDeviceInfoByIP(dev_ip, true --[[ Show minimal info ]])
        
        for _, ports in pairs(ports_table) do
            for portidx, _ in pairsByKeys(ports, asc) do
                in_ports[#in_ports + 1] = {
                    key = "inIfIdx",
                    value = portidx,
                    label = format_portidx_name(dev_ip, portidx)
                }
            end
        end
    
        rsp[#rsp + 1] = {
            action = "inIfIdx",
            label = i18n("db_search.input_snmp"),
            name = "inIfIdx",
            value = in_ports,
            show_with_value = dev_ip,
            show_with_key = "deviceIP"
        }
    
        local out_ports = {{
            key = "outIfIdx",
            value = "",
            label = i18n("all")
        }}
        local ports_table = interface.getFlowDeviceInfoByIP(dev_ip, false)
        
        for _, ports in pairs(ports_table) do
            for portidx, _ in pairsByKeys(ports, asc) do
                out_ports[#out_ports + 1] = {
                    key = "outIfIdx",
                    value = portidx,
                    label = format_portidx_name(dev_ip, portidx)
                }
            end
        end
    
        rsp[#rsp + 1] = {
            action = "outIfIdx",
            label = i18n("db_search.output_snmp"),
            name = "outIfIdx",
            value = out_ports,  
            show_with_value = dev_ip,
            show_with_key = "deviceIP"
        }    
    end
    
    return rsp
end

-- ##################################################################
-- Handle REST Response

if isEmptyString(ifid) then
    ifid = interface.getId()
end

interface.select(ifid)
if not isAdministratorOrPrintErr() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
end

local respose = build_response(criteria)

rest_utils.answer(rest_utils.consts.success.ok, respose)

-- ##################################################################
