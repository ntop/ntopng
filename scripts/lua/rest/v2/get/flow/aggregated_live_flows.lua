--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]
local vlan = _GET["vlan_id"]
local criteria = _GET["aggregation_criteria"] or ""

if isEmptyString(ifid) then
  rc = rest_utils.consts.err.invalid_interface
  rest_utils.answer(rc)
  return
end

if isEmptyString(criteria) or criteria == "application_protocol" then

  interface.select(ifid)

  local aggregated_info = interface.getProtocolFlowsStats(1)

  for _, data in pairs(aggregated_info) do
    if vlan and not isEmptyString(vlan) and tonumber(vlan) ~= tonumber(data.vlan_id) then
      goto continue
    end

    local bytes_sent = data.bytes_sent
    local bytes_rcvd = data.bytes_rcvd
    local total_bytes = bytes_rcvd + bytes_sent
      
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
        label = data.vlan_id
      }
    }

  ::continue::
  end
else

  interface.select(ifid)

  local criteria_type_id = 1

  if criteria == "client" then
    criteria_type_id = 2
  elseif criteria == "server" then
    criteria_type_id = 3
  elseif criteria == "client_server" then
    criteria_type_id = 4
  end

  local aggregated_info = interface.getProtocolFlowsStats(criteria_type_id)

  for _, data in pairs(aggregated_info) do
    

    local bytes_sent = data.bytes_sent
    local bytes_rcvd = data.bytes_rcvd
    local total_bytes = bytes_rcvd + bytes_sent

    if vlan and not isEmptyString(vlan) and tonumber(vlan) ~= tonumber(data.vlan_id) then
      goto continue
    end

    local client_ip = ternary(tonumber(data.vlan_id) ~= 0, string.format("%s@%s",data.client_ip,data.vlan_id), data.client_ip)
    local server_ip = ternary(tonumber(data.vlan_id) ~= 0, string.format("%s@%s",data.server_ip,data.vlan_id), data.server_ip)

    res[#res + 1] = {
      flows = format_high_num_value_for_tables(data, 'num_flows'),
      client = {
        label = client_ip,
        id = client_ip,
      },
      server = {
        label = server_ip,
        id = server_ip,
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
        label = data.vlan_id
      }
    }

    ::continue::

  end
end
rest_utils.answer(rc, res)
