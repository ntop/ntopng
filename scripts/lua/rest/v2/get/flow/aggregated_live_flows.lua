--
-- (C) 2013-23 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require("rest_utils")

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]

if isEmptyString(ifid) then
  rc = rest_utils.consts.err.invalid_interface
  rest_utils.answer(rc)
  return
end

interface.select(ifid)

local aggregated_info = interface.getProtocolFlowsStats()

for _, data in pairs(aggregated_info) do
  res[#res + 1] = {
    flows = data.num_flows,
    application = {
      label = data.proto_name,
      id = data.proto_id,
    },
    bytes_rcvd = data.bytes_rcvd,
    bytes_sent = data.bytes_sent,
    tot_traffic = data.bytes_sent + data.bytes_rcvd,
    num_servers = data.num_servers,
    num_clients = data.num_clients,
    vlan_id = {
      id = data.vlan_id,
      label = data.vlan_id
    }
  }
end

rest_utils.answer(rc, res)
