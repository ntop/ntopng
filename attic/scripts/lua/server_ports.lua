--
-- (C) 2013-26 - ntop.org
--
-- trace_script_duration = true
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local if_stats = interface.getStats()
if not (ntop.isEnterpriseL and ntop.isEnterpriseL()) then
   return
end

require "check_redis_prefs"
require "lua_utils"
require "flow_utils"
local json = require("dkjson")
local template_utils = require("template_utils")

local page_utils = require("page_utils")
local template = require "template_utils"
local is_asn_mode_enabled = isASNModeEnabled()

sendHTTPContentTypeHeader('text/html')

local menu = page_utils.menu_entries.server_ports

if is_asn_mode_enabled then
   menu = page_utils.menu_entries.server_ports_asn_mode
end

page_utils.print_header_and_set_active_menu_entry(menu)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local draw = _GET["draw"] or 0
local sort = _GET["sort"] or "bytes_rcvd"
local order = _GET["order"] or "asc"
local start = _GET["start"] or 0
local length = _GET["length"] or 10

local page = _GET["page"]

if isEmptyString(page) and ntop.isEnterpriseL and ntop.isEnterpriseL() then
   page = "flows_sankey"
elseif isEmptyString(page) then
   page = "live"
end

local ifId = interface.getId()

local base_url = ntop.getHttpPrefix() .. "/lua/server_ports.lua"

page_utils.print_navbar(i18n('server_ports.server_ports'), base_url .. "?", {{
   hidden = not (ntop.isEnterpriseL and ntop.isEnterpriseL()),
   active = page == "flows_sankey",
   page_name = "flows_sankey",
   label = i18n("chart")
}, {
   hidden = isASNModeEnabled(),
   active = page == "live",
   page_name = "live",
   label = i18n("jump_to_table")
}})

if (page == "live" or page == nil) then
   template_utils.render("pages/vue_page.template", {
      vue_page_name = "PageServerPorts",
      page_context = json.encode({
         ifid = ifId,
			is_ntop_enterprise_m = ntop.isEnterpriseM and ntop.isEnterpriseM(),
         csrf = ntop.getRandomCSRFValue()
      })
   })
else
   local alerts_analysis_utils = require("alerts_analysis_utils")

   local ifid = interface.getId()
   local timeframe = tonumber(_GET["timeframe"])
   local vlan = tonumber(_GET["vlan"])
   local l4_proto = _GET["l4proto"]

   -- print the modes inside the dropdown
   local timeframe_options = {}
   local vlan_options = {}
   local l4_options = {}

   -- ####################

   local vlans = interface.getVLANsList()
   if (vlans ~= nil) then
      vlan_options[#vlan_options + 1] = {
         currently_active = (vlan == 'none' or vlan == nil),
         label = i18n('all'),
         key = 'none',
         id = ''
      }

      for _, v in pairs(vlans.VLANs) do
         local name = getFullVlanName(v.vlan_id)

         if isEmptyString(name) then
            name = i18n('no_vlan')
         end
         vlan_options[#vlan_options + 1] = {
            currently_active = (tonumber(vlan) == v.vlan_id),
            label = name,
            key = v.vlan_id,
            id = v.vlan_id
         }
      end
   end

   -- ####################

   if ntop.isClickHouseEnabled() then
      timeframe_options[#timeframe_options + 1] = {
         currently_active = (timeframe == 'none' or timeframe == nil),
         label = i18n("active_flows"),
         key = 'none',
         id = 'none'
      }

      for _, v in pairs(alerts_analysis_utils.timeframes_specs) do
         timeframe_options[#timeframe_options + 1] = {
            currently_active = (timeframe == v.duration),
            label = i18n("alerts_dashboard." .. v.label),
            key = v.duration,
            id = v.duration
         }
      end
   end

   -- ####################

   l4_options = {{
      currently_active = (l4_proto == "" or l4_proto == 'none' or l4_proto == nil),
      label = i18n("all_tcp_udp"),
      key = -1,
      id = -1
   }, {
      currently_active = (l4_proto == "TCP" or l4_proto == 'tcp' or l4_proto == 6),
      label = i18n("tcp"),
      key = l4_proto_to_id('TCP'),
      id = l4_proto_to_id('TCP')
   }, {
      currently_active = (l4_proto == "UDP" or l4_proto == 'udp' or l4_proto == 17),
      label = i18n("udp"),
      key = l4_proto_to_id('UDP'),
      id = l4_proto_to_id('UDP')
   }}

   -- ####################

   template_utils.render("pages/vue_page.template", {
      vue_page_name = "PageVLANPortsSankey",
      page_context = json.encode({
         ifid = ifid,
         available_filters = {
            timeframe = timeframe_options,
            vlan = vlan_options,
            l4proto = l4_options
         }
      })
   })
end

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
