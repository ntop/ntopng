--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

--
-- Context of the Active Flows SPA page (page-flows-route.vue): the data the old
-- flows_stats.lua computed for its views. Only raw values: labels are built by the page.
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/flow/page_context.lua?ifid=0"
--

-- http_lint (validates _GET) + the light modules of rest_utils, not the whole lua_utils
require "http_lint"
local rest_utils = require "rest_utils"

-- Same access as flows_stats.lua: any user, on the interfaces they are allowed to see
local ifid = _GET["ifid"]
if not isEmptyString(ifid) then
   interface.select(ifid)
end

local is_pro = ntop.isPro and ntop.isPro()

-- Flow exporters (flow-based interfaces): the flows table shows their columns
local has_exporters = false
if is_pro and not interface.isPacketInterface() then
   has_exporters = table.len(interface.getFlowDevices() or {}) > 0
end

-- VLANs seen on the interface: the Aggregation view adds the VLAN column
local vlan_list = interface.getVLANsList()
local has_vlans = table.len((vlan_list and vlan_list.VLANs) or {}) > 0

rest_utils.answer(rest_utils.consts.success.ok, {
   ifid = interface.getId(),
   has_exporters = has_exporters,
   is_viewed = interface.isViewed(),
   -- A view interface: the flows carry the interface of the view where they were seen
   is_view = interface.isView(),
   is_pcap = interface.isPcapDumpInterface(),
   is_clickhouse_enabled = hasClickHouseSupport(),
   is_enterprise_m = (ntop.isEnterpriseM and ntop.isEnterpriseM()) or false,
   is_enterprise_l = (ntop.isEnterpriseL and ntop.isEnterpriseL()) or false,
   is_nedge = (ntop.isnEdge and ntop.isnEdge()) or false,
   has_geoip = (ntop.hasGeoIP and ntop.hasGeoIP()) or false,
   is_asn_mode = isASNModeEnabled(),
   -- Flow Details side card preference
   flow_details_card = ntop.getPref("ntopng.prefs.flow_details_card") ~= "0",
   flow_details_card_editable = isAdministrator(),
   has_vlans = has_vlans,
})
