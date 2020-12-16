--
-- (C) 2020 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/toasts/?.lua;" .. package.path

require "lua_utils"
require "flow_utils"

local page_utils = require("page_utils")
local ui_utils = require("ui_utils")
local template = require "template_utils"
local json = require "dkjson"

sendHTTPContentTypeHeader('text/html')

local is_admin = isAdministrator()
local service_map = interface.serviceMap() or {}

if is_admin and (_GET["action"] == "reset") then
    interface.flushServiceMap()
end

local function generate_graph(service_map, host_ip)

    local nodes = {}
    local proto_number = {}
    local num_services = 0

    for k,v in pairs(service_map) do

        local key = ""
        if ((host_ip == nil) or (v.client == host_ip) or (v.server == host_ip)) then

            nodes[v["client"]] = true
            nodes[v["server"]] = true
      
            if v["client"] > v["server"] then
               key = v["client"] .. "," .. v["server"]
               if proto_number[key] == nil then
                  proto_number[key] = { 1, false , v["client"], v["server"], v.l7_proto} -- { num_recurrencies, bidirection true | monodirectional false, client_ip, server_ip, l7_proto}
               else
                  proto_number[key][1] = proto_number[key][1] + 1
      
                  -- Don't show more then 3 l7 protocols
                  if proto_number[key][1] <= 3 then
                     proto_number[key][5] = proto_number[key][5] .. ", " .. v.l7_proto
                  end
      
                  -- Checking direction of the service, false monodirectional and true bidirectional
                  if v["server"] ~= proto_number[key][4] then
                     proto_number[key][2] = true
                  end
               end
            else
               key = v["server"] .. "," .. v["client"]
               if proto_number[key] == nil then
                  proto_number[key] = { 1, false , v["client"], v["server"], v.l7_proto} -- { num_recurrencies, bidirection true | monodirectional false, client_ip, server_ip, l7_proto}
               else
                  proto_number[key][1] = proto_number[key][1] + 1
      
                  -- Don't show more then 3 l7 protocols
                  if proto_number[key][1] <= 3 then
                     proto_number[key][5] = proto_number[key][5] .. ", " .. v.l7_proto
                  end
      
                  -- Checking direction of the service, false monodirectional and true bidirectional
                  if v["server"] ~= proto_number[key][4] then
                     proto_number[key][2] = true
                  end
               end
            end
         end

    end

    return nodes, proto_number, num_services
end

--- Generate nodes to be used by the js plugin
local function generate_ui_graph(map_nodes, proto_number)
    
    local nodes_id = {}
    local nodes = {}
    local edges = {}

    local i = 1

    for k,_ in pairs(map_nodes) do

        local hinfo = hostkey2hostinfo(k)
        local label = shortenString(hostinfo2label(hinfo), 16)
        local ainfo = interface.getAddressInfo(k)
        local node = {id = i, value = k, label = label}

        if (ainfo.is_multicast or ainfo.is_broadcast) then
            node.color = "#7BE141"
        end
        
        nodes_id[k] = i
        nodes[#nodes+1] = node
        i = i + 1
    end

    for k,v in pairs(proto_number) do

        local title = v[5]
        local arrow = ""
  
        if v[1] > 3 then
           title = title .. ", other " .. v[1] - 3 .. "..."
        end
  
        if v[2] == true then
           arrow = "to;from"
        else
           arrow = "to"
        end
           
        edges[#edges+1] = {
            from = nodes_id[v[3]],
            to = nodes_id[v[4]],
            value = 1,
            title = title,
            arrows = arrow
        }
     end

    return nodes, edges
end

local function generate_filters(service_map)

    local filters = {}
    local keys = {}
    local keys_regex = {}

    for k,v in pairs(service_map) do
        if ((host_ip == nil)
            or (v.client == host_ip)
            or (v.server == host_ip) ) then
            local k = "^".. getL4ProtoName(v.l4_proto) .. ":" .. v.l7_proto .."$"

            keys_regex[v.l7_proto] = k

            k = v.l7_proto
            if(keys[k] == nil) then
                keys[k] = 0
            end
            keys[k] = keys[k] + 1
        end
    end

    local id = 0
    for k, v in pairsByKeys(keys, asc) do
        filters[#filters+1] = {
            key = "filter_"..id,
            regex = keys_regex[k],
            label = string.format("%s (%s)", k, v),
            countable = false,
        }
        id = id + 1
    end

    return filters
end

local host_ip = _GET["host"]
local page = _GET["page"]

local nodes, proto_number, num_services = generate_graph(service_map, host_ip)
local ui_nodes, ui_edges = generate_ui_graph(nodes, proto_number)

page_utils.set_active_menu_entry(page_utils.menu_entries.service_map)

-- append the menu above the page
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local url = ntop.getHttpPrefix() .. "/lua/service_map.lua"
page_utils.print_navbar(i18n("service_map"), url, {
    {
        active = page == nil or page == "home",
        page_name = "home",
        label = "<i class=\"fas fa-lg fa-home\"></i>",
        url = url
    },
    {
        active = page == "graph",
        hideen = (num_services == 0), 
        page_name = "graph",
        label = i18n("snmp.snmp_topology"),
        url = url .. "?page=graph"
    }
})

local context = {
    json = json,
    is_admin = is_admin,
    page = page,
    service_map = {
        num_services = num_services,
        graph_ui = {
            nodes = ui_nodes,
            edges = ui_edges
        },
        table = {
            filters = generate_filters(service_map)
        }
    }
}

-- print service_map.template template
print(template.gen("pages/service_map.template", context))

-- append the menu below the page
dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
