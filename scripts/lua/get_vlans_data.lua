--
-- (C) 2013-26 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "label_utils"

local rest_utils = require "rest_utils"

interface.select(ifname)

-- Paging is disabled in httpdocs/tables_config/vlans_stats.json
local vlans_stats = interface.getVLANsInfo(nil --[[ sortColumn --]],
					   nil --[[ maxHits --]],
					   nil --[[ toSkip --]],
					   nil --[[ a2zSortOrder --]],
					   false --[[high, but not higher details as there's no need for nDPI here --]])

local total_rows = 0
local vlans = {}

if(vlans_stats) then
   total_rows = vlans_stats["numVLANs"]
   vlans = vlans_stats["VLANs"]
end

local now = os.time()
local ifid = interface.getId()
local data = {}

for _, vlan in pairs(vlans or {}) do
   local record = {}

   record["vlan_id"]        = vlan["vlan_id"]
   record["vlan_name"]      = getFullVlanName(vlan["vlan_id"], false, false)
   record["is_untagged"]    = (vlan["vlan_id"] == 0)
   record["score"]          = vlan["score"] or 0
   record["num_hosts"]      = vlan["num_hosts"] or 0
   record["seen_since"]     = now - vlan["seen.first"] + 1
   record["bytes_sent"]     = vlan["bytes.sent"] or 0
   record["bytes_rcvd"]     = vlan["bytes.rcvd"] or 0
   record["throughput_bps"] = vlan["throughput_bps"] or 0
   record["throughput_pps"] = vlan["throughput_pps"] or 0
   record["traffic"]        = (vlan["bytes.sent"] or 0) + (vlan["bytes.rcvd"] or 0)

   data[#data + 1] = record
end

rest_utils.extended_answer(rest_utils.consts.success.ok, data, {
   recordsTotal    = total_rows,
   recordsFiltered = total_rows,
})
