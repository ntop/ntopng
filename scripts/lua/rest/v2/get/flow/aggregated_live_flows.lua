--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- ############################################
-- Requires

require "lua_utils"
local rest_utils = require("rest_utils")
local format_utils = require("format_utils")
-- ############################################

local debugger = false

local function set_host_info(host_vlan_id, host_ip, host_name, is_host_in_mem, flow_vlan_id) 
  local host_info = {}
  local vlan_id_to_use = host_vlan_id
  if(not is_host_in_mem) then
    vlan_id_to_use = flow_vlan_id
  end
  host_info.vlan_name = getFullVlanName(vlan_id_to_use)
  host_info.ip = ternary(tonumber(vlan_id_to_use) ~= 0, string.format("%s@%s",host_ip,vlan_id_to_use), host_ip)
  host_info.ip_label = ternary(tonumber(vlan_id_to_use) ~= 0, string.format("%s@%s",host_ip, host_info.vlan_name), host_ip)

  host_info.name = host_name
  if (not isEmptyString(host_info.name)) then
    host_info.name = ternary(host_info.name ~= host_info.ip and host_info.name ~= host_ip, shortenString(host_info.name), "")
    host_info.name = ternary(vlan_id_to_use ~= 0, string.format("%s@%s",host_info.name, host_info.vlan_name),host_info.name )
  end

  return host_info
end


local function build_response() 
  
  -- ############################################
  -- Set up input variables 
  local ifid = _GET["ifid"]
  local vlan = _GET["vlan_id"]
  local criteria = _GET["aggregation_criteria"] or ""

  local filters = {}
  filters["page"] = tonumber(_GET["draw"] or 0)
  filters["sort_column"] = _GET["sort"]
  filters["sort_order"] = _GET["order"] or 'asc'
  filters["start"] = tonumber(_GET["start"] or 0)
  filters["length"] = tonumber(_GET["length"] or 10)
  -- ############################################

  local rc = rest_utils.consts.success.ok
  
  if isEmptyString(ifid) then
    rc = rest_utils.consts.err.invalid_interface
    rest_utils.answer(rc)
    return
  end

  local res = {}

  local num_entries = 0

  -- Discovery analysis type 
  local criteria_type_id = 1 
  -- by default -> application_protocol
  if criteria == "client" then
    criteria_type_id = 2
  elseif criteria == "server" then
    criteria_type_id = 3
  elseif criteria == "client_server" then
    criteria_type_id = 4
  end
  

  interface.select(ifid)

  local isView = interface.isView()

  local x = 0

  -- retrieve stats
  local aggregated_info = interface.getProtocolFlowsStats(criteria_type_id, 
                                                          filters["page"], 
                                                          filters["sort_column"], 
                                                          filters["sort_order"], 
                                                          filters["start"], 
                                                          filters["length"])

  
  if( criteria_type_id == 1) then

    if(debugger and x < 2 and filters["sort_column"] == "application") then 
      tprint("FROM C++")
      tprint(aggregated_info)
      tprint("---------------------------------")
      x = x + 1
    end
    -- application_protocol case

      for _, data in pairs(aggregated_info) do
      if vlan and not isEmptyString(vlan) and tonumber(vlan) ~= tonumber(data.vlan_id) and tonumber(vlan) ~= -1 then
        goto continue
      end
      num_entries = data.num_entries

      local bytes_sent = data.bytes_sent
      local bytes_rcvd = data.bytes_rcvd
      local total_bytes = bytes_rcvd + bytes_sent

      local vlan_name = getFullVlanName(data.vlan_id)
      
      
      res[#res + 1] = {
        flows = format_high_num_value_for_tables(data, 'num_flows'),
        application = {
          label = data.proto_name,
          id = data.proto_id,
        },
        breakdown = {
          percentage_bytes_sent = (bytes_sent * 100) / total_bytes,
          percentage_bytes_rcvd = (bytes_rcvd * 100) / total_bytes,
        },
        bytes_rcvd = bytes_rcvd,
        bytes_sent = bytes_sent,
        tot_traffic = total_bytes,
        tot_score   = format_high_num_value_for_tables(data, 'total_score'),
        num_servers = format_high_num_value_for_tables(data, 'num_servers'),
        num_clients = format_high_num_value_for_tables(data, 'num_clients'),
        vlan_id = {
          id = data.vlan_id,
          label = vlan_name
        }
      }
      
      if(debugger and x < 2 and filters["sort_column"] == "application") then 
        tprint("LUA RESP")
        tprint(res)
        tprint("---------------------------------")
        x = x + 1
      end

    ::continue::
    end
  else 
    -- other criteria cases
    for _, data in pairs(aggregated_info) do
    

      local bytes_sent = data.bytes_sent
      local bytes_rcvd = data.bytes_rcvd
      local total_bytes = bytes_rcvd + bytes_sent

      if (criteria_type_id == 2) then
        if(vlan and not isEmptyString(vlan) and (tonumber(vlan) ~= tonumber(data.cli_vlan_id)  and tonumber(vlan) ~= -1)) then
          goto continue
        end
      elseif (criteria_type_id == 3) then
        if(vlan and not isEmptyString(vlan) and (tonumber(vlan) ~= tonumber(data.srv_vlan_id) and tonumber(vlan) ~= -1)) then
          goto continue
        end
      else
        if(vlan and not isEmptyString(vlan) and 
          tonumber(vlan) ~= tonumber(data.srv_vlan_id) and tonumber(vlan) ~= tonumber(data.cli_vlan_id) and tonumber(vlan) ~= -1) then
          goto continue
        end
      end
      


      local flow_vlan_name = getFullVlanName(data.vlan_id)

      local server_name = ""
      local server_ip_label = ""
      local server_ip = ""
      local srv_in_mem = false
      local server_host = nil

      local is_server_alerted = false
      
      if(criteria_type_id == 3 or criteria_type_id == 4) then
        local srv_info = set_host_info(data.srv_vlan_id, data.server_ip, data.server_name, data.is_srv_in_mem, data.vlan_id)
        server_ip = srv_info.ip
        server_ip_label = srv_info.ip_label
        server_name = srv_info.name
        server_host = interface.getHostInfo(data.server_ip, data.vlan_id or 0)
        srv_in_mem = server_host ~= nil

        srv_in_mem = server_host ~= nil
        if (srv_in_mem) then
          is_server_alerted = (server_host["num_alerts"] ~= nil) and (server_host["num_alerts"] > 0)
        end
      end

      local client_ip = ""
      local client_ip_label = ""
      local client_name = ""
      local cli_in_mem = false

      local client_host = nil
      local is_client_alerted = false

      if(criteria_type_id == 2 or criteria_type_id == 4) then
        local cli_info = set_host_info(data.cli_vlan_id, data.client_ip, data.client_name, data.is_cli_in_mem, data.vlan_id)
        client_ip = cli_info.ip
        client_ip_label = cli_info.ip_label
        client_name = cli_info.name
        client_host = interface.getHostInfo(data.client_ip, data.vlan_id or 0)
	
        cli_in_mem = client_host ~= nil
        if (cli_in_mem) then
          is_client_alerted = (client_host["num_alerts"] ~= nil) and (client_host["num_alerts"] > 0)
        end
      end
      
      num_entries = data.num_entries
      
      res[#res + 1] = {
        flows = format_high_num_value_for_tables(data, 'num_flows'),
        client = {
          label = client_ip_label,
          id = client_ip,
        },
        is_client_in_mem = isView or cli_in_mem,
        client_name = {
          label = client_name,
          id = client_ip, 
          complete_label = format_utils.formatFullAddressCategory(client_host),
	        alerted = is_client_alerted
        },
        server = {
          label = server_ip_label,
          id = server_ip,
        },
        is_server_in_mem = isView or srv_in_mem,
        server_name = {
          label = server_name,
          id = server_ip,
          complete_label = format_utils.formatFullAddressCategory(server_host),
	        alerted = is_server_alerted
        },
        breakdown = {
          percentage_bytes_sent = (bytes_sent * 100) / total_bytes,
          percentage_bytes_rcvd = (bytes_rcvd * 100) / total_bytes,
        },
        bytes_rcvd = bytes_rcvd,
        bytes_sent = bytes_sent,
        tot_traffic = total_bytes,
        tot_score   = format_high_num_value_for_tables(data, 'total_score'),
        num_servers = format_high_num_value_for_tables(data, 'num_servers'),
        num_clients = format_high_num_value_for_tables(data, 'num_clients'),
        vlan_id = {
          id = data.vlan_id,
          label = flow_vlan_name
        }
      }

      ::continue::

    end
  end

  local extra_rsp_data = {
    ["draw"] = tonumber(_GET["draw"]),
    ["recordsFiltered"] = tonumber(num_entries),
    ["recordsTotal"] = tonumber(num_entries),
  }

  rest_utils.extended_answer(rc, res, extra_rsp_data)

end

build_response()