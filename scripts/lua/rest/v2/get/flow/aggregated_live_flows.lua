--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

-- ############################################
-- Requires

require "lua_utils"
local rest_utils = require("rest_utils")
-- ############################################

local debugger = false

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
      if vlan and not isEmptyString(vlan) and tonumber(vlan) ~= tonumber(data.vlan_id) then
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

      if vlan and not isEmptyString(vlan) and tonumber(vlan) ~= tonumber(data.vlan_id) then
        goto continue
      end


      local vlan_name = getFullVlanName(data.vlan_id)

      local client_ip = ternary(tonumber(data.vlan_id) ~= 0, string.format("%s@%s",data.client_ip,data.vlan_id), data.client_ip)
      local client_ip_label = ternary(tonumber(data.vlan_id) ~= 0, string.format("%s@%s",data.client_ip,vlan_name), data.client_ip)

      local server_ip = ternary(tonumber(data.vlan_id) ~= 0, string.format("%s@%s",data.server_ip,data.vlan_id), data.server_ip)
      local server_ip_label = ternary(tonumber(data.vlan_id) ~= 0, string.format("%s@%s",data.server_ip,vlan_name), data.server_ip)
      
      local server_name = data.server_name
      if (not isEmptyString(server_name)) then
        server_name = ternary(server_name ~= server_ip, server_name, "")
      end
      
      local client_name = data.client_name
      if (not isEmptyString(client_name)) then
        client_name = ternary(client_name ~= client_ip, client_name, "")
      end

      num_entries = data.num_entries
      
      
      res[#res + 1] = {
        flows = format_high_num_value_for_tables(data, 'num_flows'),
        client = {
          label = client_ip_label,
          id = client_ip,
        },
        client_name = {
          label = client_name,
          id = client_ip
        },
        server = {
          label = server_ip_label,
          id = server_ip,
        },
        server_name = {
          label = server_name,
          id = server_ip
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