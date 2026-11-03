--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "http_lint"
local rest_utils = require "rest_utils"

-- ?ifid= selects the interface; interface.select silently falls back to an allowed one: check it
local ifid = _GET["ifid"]
if not isEmptyString(ifid) then
   interface.select(tostring(ifid))
   if tostring(interface.getId()) ~= tostring(ifid) then
      rest_utils.answer(rest_utils.consts.err.invalid_interface)
      return
   end
end

-- No nDPI details: not shown by the VLANs page
local vlans_stats = interface.getVLANsInfo(nil, nil, nil, nil, false)
local vlans = vlans_stats and vlans_stats["VLANs"] or {}

-- All the aliases with one Redis call (same hash as label_utils.getVlanAliasKey)
local aliases = ntop.getHashAllCache("ntopng.vlan_aliases") or {}
local now = os.time()
local data = {}

for _, vlan in pairs(vlans) do
   local vlan_id = vlan["vlan_id"]
   local sent = vlan["bytes.sent"] or 0
   local rcvd = vlan["bytes.rcvd"] or 0
   local alias = aliases[tostring(vlan_id)]

   data[#data + 1] = {
      vlan_id = vlan_id,
      -- nil when there is no alias (or it is the id itself)
      vlan_alias = (vlan_id ~= 0 and not isEmptyString(alias) and alias ~= tostring(vlan_id)) and alias or nil,
      is_untagged = (vlan_id == 0),
      score = vlan["score"] or 0,
      num_hosts = vlan["num_hosts"] or 0,
      seen_since = now - vlan["seen.first"] + 1,
      bytes_sent = sent,
      bytes_rcvd = rcvd,
      throughput_bps = vlan["throughput_bps"] or 0,
      throughput_pps = vlan["throughput_pps"] or 0,
      traffic = sent + rcvd,
   }
end

rest_utils.extended_answer(rest_utils.consts.success.ok, data, {
   recordsTotal = #data,
   recordsFiltered = #data,
})
