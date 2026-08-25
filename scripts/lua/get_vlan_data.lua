--
-- (C) 2013-26 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
require "label_utils"

local rest_utils = require "rest_utils"

interface.select(ifname)

local vlan_id = tonumber(_GET["vlan"])

local vlan = interface.getVLANInfo(vlan_id)

local record = {}

if vlan ~= nil then
   local now = os.time()

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
end

rest_utils.answer(rest_utils.consts.success.ok, record)
