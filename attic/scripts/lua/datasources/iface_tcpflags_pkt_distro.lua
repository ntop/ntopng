--
-- (C) 2020 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require("lua_utils")
local datasources_utils = require("datasources_utils")
local datamodel = require("datamodel")

local pkt_distribution = {
   ['syn'] = 'SYN',
   ['synack'] = 'SYN/ACK',
   ['finack'] = 'FIN/ACK',
   ['rst'] = 'RST',
}

local function reportError(msg)
    print(json.encode({ error = msg, success = false, csrf = ntop.getRandomCSRFValue() }))
end

local ifid    = _GET["ifid"] or 0
local if_name = getInterfaceName(ifid)

interface.select(ifname)
local ifstats = interface.getStats()
local labels  = {}
local slices  = {}

local res = {}
for key, value in pairs(ifstats["pktSizeDistribution"]["tcp_flags"]) do
   if value > 0 then
      table.insert(labels, pkt_distribution[key])
      table.insert(slices, value)
   end
end

if(table.len(res) == 0) then
   table.insert(labels, "Other")
   table.insert(slices, 100)
end

-- Prepare the results
local m = datamodel:new(labels)
local dataset = ifname.." TCP Flags"

m:appendRow(when, dataset, slices)

return(m)
