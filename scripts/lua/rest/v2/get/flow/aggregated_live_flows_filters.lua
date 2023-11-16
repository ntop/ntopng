--
-- (C) 2013-23 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/enterprise/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require "rest_utils"
local format_utils = require("format_utils")
require "lua_utils_get"

if not isAdministratorOrPrintErr() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end


if ntop.isEnterpriseM() then
    require "aggregate_live_flows"
 end

-- =============================


local ifid = _GET["ifid"]
local criteria = _GET["aggregation_criteria"] or ""
local rc = rest_utils.consts.success.ok
local filters = {}




if isEmptyString(ifid) then
    ifid = interface.getId()
end

interface.select(ifid)


filters["page"] = tonumber(_GET["draw"] or 0)
filters["sort_column"] = _GET["sort"] or 'flows'
filters["sort_order"] = _GET["order"] or 'desc'
filters["start"] = 0
filters["length"] = 0
filters["map_search"] = _GET["map_search"]
filters["host"] = _GET["host"]
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

local isView = interface.isView()
local x = 0

-- Retrieve the flows
local aggregated_info = interface.getProtocolFlowsStats(criteria_type_id, filters["page"], filters["sort_column"],
							filters["sort_order"], filters["start"], filters["length"], ternary(not isEmptyString(filters["map_search"]), filters["map_search"], nil) , ternary(filters["host"]~= "", filters["host"], nil), nil)

local formatted_vlan_filters = {}

local function is_vlan_already_inserted(formatted_vlan_filters, vlan_id)
    for id,x in ipairs(formatted_vlan_filters) do
        if(x.value == vlan_id) then
            return id
        end
    end
    return -1
end

for _, data in pairs(aggregated_info or {}) do

    local index = is_vlan_already_inserted(formatted_vlan_filters, data.vlan_id)
    if index == -1 then
        local vlan_name = i18n('no_vlan')

        if data.vlan_id ~= 0 then
            vlan_name = getFullVlanName(data.vlan_id, true)
        end
        local vlan = {
            count = 1,
            value = data.vlan_id,
            label = vlan_name,
            key = "vlan_id"
        }
        formatted_vlan_filters[#formatted_vlan_filters+1] = vlan
    else
        formatted_vlan_filters[index].count = formatted_vlan_filters[index].count + 1
    end
end




table.sort(formatted_vlan_filters, function(a,b) return a.value < b.value end)
table.insert(formatted_vlan_filters, 1, {
    key = "vlan_id",
    label = i18n('all'),
    value = ""
})

local rsp = {}
if (#formatted_vlan_filters > 2) then
    rsp = {
        {
            action = "vlan_id",
            label = i18n("vlan"),
            tooltip = i18n("vlan_filter"),
            name = "vlan_filter",
            value = formatted_vlan_filters
        }
    }
end

rest_utils.answer(rest_utils.consts.success.ok, rsp)
