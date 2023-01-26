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

if isEmptyString(ifid) then
  rc = rest_utils.consts.err.invalid_interface
  rest_utils.answer(rc)
  return
end

interface.select(ifid)

local aggregated_info = interface.getProtocolFlowsStats()

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
    tot_score   = data.total_score,
    num_servers = format_high_num_value_for_tables(data, 'num_servers'),
    num_clients = format_high_num_value_for_tables(data, 'num_clients'),
    vlan_id = {
      id = data.vlan_id,
      label = data.vlan_id
    }
  }

::continue::
end

rest_utils.answer(rc, res)
