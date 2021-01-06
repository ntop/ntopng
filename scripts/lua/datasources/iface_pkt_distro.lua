--
-- (C) 2020 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require("lua_utils")
local datasources_utils = require("datasources_utils")
local datamodel = require("datamodel")

local function reportError(msg)
    print(json.encode({ error = msg, success = false, csrf = ntop.getRandomCSRFValue() }))
end

local pkt_distribution = {
   ['upTo64']    = '<= 64',
   ['upTo128']   = '64 <= 128',
   ['upTo256']   = '128 <= 256',
   ['upTo512']   = '256 <= 512',
   ['upTo1024']  = '512 <= 1024',
   ['upTo1518']  = '1024 <= 1518',
   ['upTo2500']  = '1518 <= 2500',
   ['upTo6500']  = '2500 <= 6500',
   ['upTo9000']  = '6500 <= 9000',
   ['above9000'] = '> 9000'
}

local ifid       = _GET["ifid"] or 0
local ifname     = getInterfaceName(ifid)
local chart_type = _GET["chart_type"] or "size"

interface.select(ifname)
local ifstats = interface.getStats()

what = ifstats["pktSizeDistribution"]["size"]

local tot = 0
for key, value in pairs(what) do
   tot = tot + value
end

local threshold = (tot * 5) / 100
local sum = 0

local labels = {}
local slices = {}

for key, value in pairs(what) do
   if(value > threshold) then
      if(pkt_distribution[key] ~= nil) then
	 table.insert(labels, pkt_distribution[key])
	 table.insert(slices, value)
	 sum = sum + value
      end
   end
end

if(sum < tot) then
   table.insert(labels, "Other")
   table.insert(slices, tot-sum)
end

-- Prepare the results

local m = datamodel:new(labels)
local dataset = ifname.." Packet Distribution"

m:appendRow(when, dataset, slices)

return(m)
