--
-- (C) 2013-21 - ntop.org
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

local ifstats = interface.getStats()
if ifstats and ifstats.ndpi then
    local total_bytes = 0
    for _, value in pairs(ifstats.ndpi or {}) do
        -- calculate the total
        local bytes_in = value["bytes.rcvd"]
        local bytes_out = value["bytes.sent"]
        total_bytes = total_bytes + bytes_in + bytes_out
    end
    for protocol, value in pairs(ifstats.ndpi or {}) do
        local bytes_in = value["bytes.rcvd"]
        local bytes_out = value["bytes.sent"]
        local packets_in = value["packets.rcvd"]
        local packets_out = value["packets.sent"]
        local breed = value["breed"]
        res[#res + 1] = {
            application = {
                name = protocol,
                id = interface.getnDPIProtoId(protocol)
            },
            bytes = {
                rcvd = bytes_in,
                sent = bytes_out,
                total = bytes_in + bytes_out,
                percentage = math.floor(1 + (bytes_in + bytes_out) * 100 / total_bytes)
            },
            packets = {
                rcvd = packets_in,
                sent = packets_out,
                total = packets_in + packets_out
            },
            breed = breed,
            tot_num_flows = value.num_flows
        }
    end
end

rest_utils.answer(rc, res)