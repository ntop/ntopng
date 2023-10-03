--
-- (C) 2013-23 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/enterprise/modules/?.lua;" .. package.path

-- ############################################
-- Requires

require "lua_utils"
local rest_utils = require("rest_utils")
local format_utils = require("format_utils")
require "lua_utils_get"

if ntop.isEnterpriseM() then
   require "aggregate_live_flows"
end

-- ############################################
-- Set up input variables 

local ifid = _GET["ifid"]
local vlan = tonumber(_GET["vlan_id"] or -1)
local criteria = _GET["aggregation_criteria"] or ""
local rc = rest_utils.consts.success.ok
local filters = {}

filters["page"] = tonumber(_GET["draw"] or 0)
filters["sort_column"] = _GET["sort"]
filters["sort_order"] = _GET["order"] or 'asc'
filters["start"] = tonumber(_GET["start"] or 0)
filters["length"] = tonumber(_GET["length"] or 10)
filters["map_search"] = _GET["map_search"]
filters["host"] = _GET["host"]

if (vlan) and (isEmptyString(vlan) or tonumber(vlan) == -1) then
   vlan = nil
end

interface.select(ifid)

-- ############################################

local debugger = false

local function set_host_info(host_vlan_id, host_ip, host_name, is_host_in_mem, flow_vlan_id)
   local host_info = {}
   local vlan_id_to_use = host_vlan_id
   if (not is_host_in_mem) then
      vlan_id_to_use = flow_vlan_id
   end
   host_info.vlan_name = getFullVlanName(vlan_id_to_use)
   host_info.ip = ternary(tonumber(vlan_id_to_use) ~= 0, string.format("%s@%s", host_ip, vlan_id_to_use), host_ip)
   host_info.ip_label = ternary(tonumber(vlan_id_to_use) ~= 0, string.format("%s@%s", host_ip, host_info.vlan_name),
				host_ip)

   host_info.name = host_name
   if (not isEmptyString(host_info.name)) then
      host_info.name = ternary(host_info.name ~= host_info.ip and host_info.name ~= host_ip, host_info.name, "")
      host_info.name = ternary(vlan_id_to_use ~= 0, string.format("%s@%s", host_info.name, host_info.vlan_name),
			       host_info.name)
   end

   return host_info
end

-- ############################################

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

local res = {}
local num_entries = 0

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
							filters["sort_order"], filters["start"], filters["length"], ternary(not isEmptyString(filters["map_search"]), filters["map_search"], nil) , ternary(filters["host"]~= "", filters["host"], nil), vlan)

-- Formatting the data
for _, data in pairs(aggregated_info or {}) do
   local bytes_sent = data.bytes_sent or 0
   local bytes_rcvd = data.bytes_rcvd or 0
   local total_bytes = bytes_rcvd + bytes_sent
   local add_app_proto = false
   local add_server = false
   local add_client = false
   local add_server_port = false
   local client = nil
   local server = nil
   local info = nil
   local application = nil
   local srv_port = nil

   if (vlan) and
      (tonumber(vlan) ~= tonumber(data.vlan_id) ) then
      goto continue
   end

   -- In case the vlans are 0, put them to nil for semplicity later
   --[[if data.srv_vlan_id == 0 then
      data.srv_vlan_id = nil
   end

   if data.cli_vlan_id == 0 then
      data.cli_vlan_id = nil
   end
   --]]
   local response = {}
   if (criteria_type_id == 1) then
      add_app_proto = true
   elseif (criteria_type_id == 2) then
      if(data.client_ip ~= nil) then
	 add_client = true
      end
   elseif (criteria_type_id == 3) then
      if(data.server_ip ~= nil) then
	 add_server = true
      end
   elseif (criteria_type_id == 7) then
      if(data.server_ip ~= nil) then
	 add_server = true
      end
      if(data.client_ip ~= nil) then
   add_client = true
      end
      if(data.srv_port ~= nil) then
   add_server_port = true
      end
   elseif ntop.isEnterpriseM() then
      response = get_output_flags(criteria_type_id)
   end

   if (add_app_proto or (response ~= {} and response.add_app_proto)) then
      application = {
	 label = data.proto_name,
	 id = data.proto_id,
	 label_with_icons = getApplicationLabel(data.proto_name, 256)
      }
   end

   if (add_server_port) then
      srv_port = {
         label = data.srv_port,
         id = data.srv_port
      }
   end

   -- Format the client and server info
   if (add_client or (response ~= {} and response.add_client)) then
      local host = interface.getHostInfo(data.client_ip, data.cli_vlan_id or data.vlan_id)
      local in_memory = (host ~= nil)
      local is_alerted = (in_memory) and (host["num_alerts"] ~= nil) and (host["num_alerts"] > 0)

      client = {
	 vlan_id = data.cli_vlan_id or data.vlan_id,
	 label = hostinfo2label({
	       ip = data.client_ip,
	       vlan = data.cli_vlan_id or data.vlan_id
	 }),
	 ip = data.client_ip,
	 is_alerted = is_alerted,
	 in_memory = in_memory,
	 extra_labels = format_utils.formatFullAddressCategory(host or {})
      }
   end

   if (add_server or (response ~= {} and response.add_server)) then
      local host = interface.getHostInfo(data.server_ip, data.srv_vlan_id or data.vlan_id)
      local in_memory = (host ~= nil)
      local is_alerted = (in_memory) and (host["num_alerts"] ~= nil) and (host["num_alerts"] > 0)

      server = {
	 vlan_id = data.srv_vlan_id or data.vlan_id,
	 label = hostinfo2label({
	       ip = data.server_ip,
	       vlan = data.srv_vlan_id or data.vlan_id
	 }),
	 ip = data.server_ip,
	 is_alerted = is_alerted,
	 in_memory = in_memory,
	 extra_labels = format_utils.formatFullAddressCategory(host or {})
      }
   end

   if add_server and (vlan ~= nil and tonumber(vlan) ~=
   tonumber(data.srv_vlan_id)) then
      goto continue
   end
   if add_client and ( vlan ~= nil and tonumber(vlan) ~= tonumber(data.cli_vlan_id)) then
         goto continue
   end

   if (table.len(response) > 0 and response.add_info) then
      info = {
	 label = data.info,
	 id = data.info
      }
   end

   -- TODO: remove this data from inside the for
   num_entries = data.num_entries

   local item =  {
	 flows = format_high_num_value_for_tables(data, 'num_flows'),

	 breakdown = {
	    percentage_bytes_sent = (bytes_sent * 100) / total_bytes,
	    percentage_bytes_rcvd = (bytes_rcvd * 100) / total_bytes
	 },
	 bytes_rcvd = bytes_rcvd,
	 bytes_sent = bytes_sent,
	 tot_traffic = total_bytes,
	 tot_score = format_high_num_value_for_tables(data, 'total_score'),
	 num_servers = format_high_num_value_for_tables(data, 'num_servers'),
	 num_clients = format_high_num_value_for_tables(data, 'num_clients'),
	 client = client,
	 server = server,
	 info = info,
    srv_port = srv_port,
	 application = application,
    vlan_id = {
      id = nil,
      label = nil
    }
      }

   if data.vlan_id and data.vlan_id ~= 0 then
      item.vlan_id = {
         id = data.vlan_id,
         label = getFullVlanName(data.vlan_id)
      }
   end
   if criteria_type_id == 1 or criteria_type_id == 5 then 
      item.app_proto_is_not_guessed = data.is_not_guessed
      item.confidence_name = get_confidence(ternary(application.id == "0", "-1", ternary(data.is_not_guessed, "1", "0")))
      item.confidence = ternary(data.is_not_guessed, 1, 0)
   end   
   
   if num_entries > 0 then
      res[#res + 1] = item

   end

   ::continue::
end

local extra_rsp_data = {
   ["draw"] = tonumber(_GET["draw"]),
   ["recordsFiltered"] = tonumber(num_entries),
   ["recordsTotal"] = tonumber(num_entries)
}

rest_utils.extended_answer(rc, res, extra_rsp_data)
