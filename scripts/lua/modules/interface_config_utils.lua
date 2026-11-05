--
-- (C) 2026 - ntop.org
--
-- Settings of an interface (Interface details > Settings, page-interface-settings.vue), read by
-- rest/v2/get/interface/config.lua and saved by rest/v2/set/interface/config.lua with the same
-- rules of the old if_stats.lua?page=config form: which settings apply to the interface, their
-- stored values, how a change is applied. The interface must be selected (interface.select).
--

require "ntop_utils"
require "lua_utils_generic" -- toboolean()
require "lua_utils_get" -- getInterfaceSpeed(), getGwMacsSet()
require "label_utils"   -- getHumanReadableInterfaceName(), getInterfaceAlias()
local recording_utils = require "recording_utils"
local companion_interface_utils = require "companion_interface_utils"
local top_talkers_utils = require "top_talkers_utils"
local dhcp_utils = require "dhcp_utils"

local interface_config_utils = {}

-- Longest custom name; the characters refused in it (it is printed in many pages)
local MAX_NAME_LEN = 64
local NAME_REFUSED = "[<>\"'`]"

-- Disaggregation criteria: packet interfaces only by VLAN (old ids kept by older versions)
local DISAGGREGATION_PACKET = { "none", "vlan" }
local DISAGGREGATION_FLOW = { "none", "vlan", "exporter_ip", "iface_idx", "ingress_iface_idx", "ingress_vrf_id",
                              "exporter_ip_and_ingress_iface_idx" }
local DISAGGREGATION_OLD = { probe_ip = "exporter_ip", probe_ip_and_ingress_iface_idx = "exporter_ip_and_ingress_iface_idx" }

local function key(fmt, ifid) return string.format(fmt, ifid) end

local KEYS = {
   speed = "ntopng.prefs.ifid_%d.speed",
   scaling_factor = "ntopng.prefs.iface_%d.scaling_factor",
   lbd_by_mac = "ntopng.prefs.ifid_%d.serialize_local_broadcast_hosts_as_macs",
   flow_dump_disabled = "ntopng.prefs.ifid_%d.is_flow_dump_disabled",
   mirrored = "ntopng.prefs.ifid_%d.is_traffic_mirrored",
   network_discovery = "ntopng.prefs.ifid_%d.interface_network_discovery",
   disaggregation = "ntopng.prefs.dynamic_sub_interfaces.ifid_%d.mode",
   show_dyn_traffic = "ntopng.prefs.ifid_%d.show_dynamic_interface_traffic",
   push_host_filters = "ntopng.prefs.ifid_%d.push_host_filters_to_pfring",
}

local function reports_utils()
   local dirs = ntop.getDirs()
   package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/modules/?.lua;" .. package.path
   return require "reports_utils"
end

local function contains(list, v)
   for _, x in ipairs(list) do if x == v then return true end end
   return false
end

-- What applies to the selected interface (the same conditions of the old form)
local function scope(ifid)
   local ifstats = interface.getStats()
   local prefs = ntop.getPrefs()
   local is_nedge = (ntop.isnEdge and ntop.isnEdge()) or false
   local is_packet = interface.isPacketInterface()
   local is_view = interface.isView()
   local is_sub = interface.isSubInterface()

   local has_recording = false
   if recording_utils.isAvailable() then
      if is_view then
         has_recording = next(recording_utils.getViewedInterfacesWithRecording(ifid)) ~= nil
      else
         has_recording = is_packet
            or (recording_utils.isSupportedZMQInterface(ifid) and next(recording_utils.getExtInterfaces(ifid)) ~= nil)
            or (recording_utils.getCurrentTrafficRecordingProvider(ifid) ~= "ntopng")
      end
   end

   return {
      ifstats = ifstats,
      is_nedge = is_nedge,
      is_packet = is_packet,
      is_zmq = interface.isZMQInterface(),
      is_view = is_view,
      is_sub = is_sub,
      has_name = not interface.isPcapDumpInterface() and ifstats.name ~= nil and ifstats.name ~= "dummy",
      has_speed = not is_nedge,
      has_scaling = is_packet and not is_nedge,
      has_reports = ntop.isEnterpriseL and ntop.isEnterpriseL() and toboolean(ntop.getPref("ntopng.prefs.automatic_reports_enabled")),
      has_flow_dump = prefs.is_dump_flows_enabled or false,
      has_mirrored = is_packet and not is_nedge,
      has_discovery = interface.isDiscoverableInterface(),
      has_companion = not is_sub,
      has_recording_provider = has_recording and not is_view,
      has_disaggregation = not is_sub and not is_nedge,
      -- DHCP ranges: the interfaces that see the DHCP traffic (old DHCP tab)
      has_dhcp = not interface.isPcapDumpInterface() and not interface.isZMQInterface(),
      -- Custom disaggregation (sub-interfaces by filter) and syslog producers (old tabs)
      has_sub_interfaces = not is_nedge and not is_sub and not is_view,
      has_syslog_producers = not is_nedge and (ifstats.isSyslog or false),
   }
end

function interface_config_utils.read(ifid)
   local s = scope(ifid)
   local res = { ifid = ifid, is_packet = s.is_packet, is_zmq = s.is_zmq }
   local mirrored = s.has_mirrored and ntop.getPref(key(KEYS.mirrored, ifid)) == "1"

   if s.has_name then
      res.custom_name = getInterfaceAlias(ifid)
      res.name_placeholder = getHumanReadableInterfaceName(s.ifstats.name, true)
      res.name_max_len = MAX_NAME_LEN
   end
   if s.has_speed then res.speed = tostring(getInterfaceSpeed(ifid) or "") end
   if s.has_scaling then
      local sf = ntop.getCache(key(KEYS.scaling_factor, ifid))
      res.scaling_factor = isEmptyString(sf) and "1" or sf
   end

   -- Hosts identified by MAC: never for mirrored traffic and flow collectors (forced to IP)
   res.lbd_by_mac = ntop.getPref(key(KEYS.lbd_by_mac, ifid)) == "1"
   res.lbd_locked = mirrored or s.is_zmq

   if s.has_reports then res.automatic_reports = reports_utils().automatic_reports_enabled(ifid) end
   res.top_talkers = top_talkers_utils.areTopEnabled(ifid)
   if s.has_flow_dump then res.flow_dump = ntop.getPref(key(KEYS.flow_dump_disabled, ifid)) ~= "1" end

   if s.has_mirrored then
      res.mirrored = mirrored
      local macs = {}
      for _, mac in pairs(ntop.getMembersCache(getGwMacsSet(ifid)) or {}) do macs[#macs + 1] = mac end
      table.sort(macs)
      res.gw_macs = table.concat(macs, ",")
   end

   if s.has_discovery then res.network_discovery = ntop.getPref(key(KEYS.network_discovery, ifid)) ~= "false" end

   if s.has_companion then
      local companions = companion_interface_utils.getAvailableCompanions()
      -- Only "None" means no other flow interface to pair with
      if #companions > 1 then
         res.companion = companion_interface_utils.getCurrentCompanion(ifid)
         res.companions = {}
         for _, c in ipairs(companions) do
            res.companions[#res.companions + 1] = {
               ifid = c.ifid, name = (c.ifname ~= "None") and getHumanReadableInterfaceName(c.ifname) or nil,
            }
         end
      end
   end

   if s.has_recording_provider then
      local providers = recording_utils.getAvailableTrafficRecordingProviders()
      -- Only ntopng itself: nothing to choose
      if #providers > 1 then
         res.recording_provider = recording_utils.getCurrentTrafficRecordingProvider(ifid)
         res.recording_providers = {}
         for _, p in ipairs(providers) do
            res.recording_providers[#res.recording_providers + 1] = { name = p.name, conf = p.conf }
         end
      end
   end

   if s.has_disaggregation then
      local mode = ntop.getCache(key(KEYS.disaggregation, ifid))
      mode = DISAGGREGATION_OLD[mode] or (isEmptyString(mode) and "none" or mode)
      res.disaggregation = mode
      res.disaggregation_modes = s.is_packet and DISAGGREGATION_PACKET or DISAGGREGATION_FLOW
      res.show_dyn_traffic = ntop.getPref(key(KEYS.show_dyn_traffic, ifid)) == "1"
      res.push_host_filters = ntop.getPref(key(KEYS.push_host_filters, ifid)) == "1"
      res.pfring_queue = "pfring." .. ifid .. ".filter.host.queue"
   end

   if s.has_dhcp then
      res.dhcp_ranges = {}
      for _, r in ipairs(dhcp_utils.listRanges(ifid)) do res.dhcp_ranges[#res.dhcp_ranges + 1] = { first = r[1], last = r[2] } end
   end
   res.has_sub_interfaces = s.has_sub_interfaces
   res.sub_interfaces_license = (ntop.isEnterpriseM and ntop.isEnterpriseM()) or false
   res.has_syslog_producers = s.has_syslog_producers
   if s.has_syslog_producers then
      -- The producer types are the syslog checks
      local checks = require "checks"
      res.syslog_producer_types = {}
      for _, v in pairs(checks.listScripts(checks.script_types.syslog, "syslog") or {}) do
         res.syslog_producer_types[#res.syslog_producer_types + 1] = v
      end
      table.sort(res.syslog_producer_types)
   end

   return res
end

-- Saves the settings present in `post` (the others are kept) that apply to the interface.
-- Returns res ({ restart_required }) or nil, field (the first invalid one)
function interface_config_utils.apply(ifid, post)
   local s = scope(ifid)
   local res = { restart_required = false }
   local is_true = function(v) return v == "1" or v == "true" end
   local given = function(k) return post[k] ~= nil end

   -- Validate first: nothing is written when a value is refused
   if s.has_name and given("custom_name") then
      local name = post["custom_name"]
      if #name > MAX_NAME_LEN or name:find(NAME_REFUSED) then return nil, "custom_name" end
   end
   if s.has_speed and given("ifSpeed") and post["ifSpeed"] ~= "" and (tonumber(post["ifSpeed"]) or 0) < 1 then
      return nil, "ifSpeed"
   end
   if s.has_scaling and given("scaling_factor") and post["scaling_factor"] ~= "" and (tonumber(post["scaling_factor"]) or 0) < 1 then
      return nil, "scaling_factor"
   end
   if s.has_disaggregation and given("disaggregation_criterion")
      and not contains(s.is_packet and DISAGGREGATION_PACKET or DISAGGREGATION_FLOW, post["disaggregation_criterion"]) then
      return nil, "disaggregation_criterion"
   end
   if s.has_recording_provider and given("traffic_recording_provider") and post["traffic_recording_provider"] ~= "ntopng" then
      local ok = false
      for _, p in ipairs(recording_utils.getAvailableTrafficRecordingProviders()) do
         if p.name == post["traffic_recording_provider"] then ok = true end
      end
      if not ok then return nil, "traffic_recording_provider" end
   end
   if s.has_companion and given("companion_interface") and post["companion_interface"] ~= "" then
      local ok = false
      for _, c in ipairs(companion_interface_utils.getAvailableCompanions()) do
         if tostring(c.ifid) == post["companion_interface"] then ok = true end
      end
      if not ok then return nil, "companion_interface" end
   end

   if s.has_name and given("custom_name") then
      local name = post["custom_name"]
      if name == "" then ntop.delCache(key("ntopng.prefs.ifid_%d.name", ifid))
      else ntop.setCache(key("ntopng.prefs.ifid_%d.name", ifid), name) end
   end

   if s.has_speed and given("ifSpeed") then
      if post["ifSpeed"] == "" then ntop.delCache(key(KEYS.speed, ifid))
      else ntop.setCache(key(KEYS.speed, ifid), tostring(math.floor(tonumber(post["ifSpeed"])))) end
   end

   if s.has_scaling and given("scaling_factor") then
      local sf = tonumber(post["scaling_factor"]) or 1
      ntop.setCache(key(KEYS.scaling_factor, ifid), tostring(math.floor(sf)))
      interface.loadScalingFactorPrefs()
   end

   local mirrored = s.has_mirrored and ntop.getPref(key(KEYS.mirrored, ifid)) == "1"
   if s.has_mirrored and given("is_mirrored_traffic") then
      mirrored = is_true(post["is_mirrored_traffic"])
      ntop.setPref(key(KEYS.mirrored, ifid), mirrored and "1" or "0")
      interface.updateTrafficMirrored()
   end
   if s.has_mirrored and given("gw_macs") then
      -- Gateway MAC addresses: they give the traffic direction of mirrored traffic
      local set = getGwMacsSet(ifid)
      ntop.delCache(set)
      for mac in post["gw_macs"]:gmatch("[^,%s]+") do ntop.setMembersCache(set, mac) end
      interface.reloadGwMacs()
   end

   -- Mirrored traffic and flow collectors identify the hosts by IP
   if mirrored or s.is_zmq then
      if ntop.getPref(key(KEYS.lbd_by_mac, ifid)) == "1" then
         ntop.setPref(key(KEYS.lbd_by_mac, ifid), "0")
         interface.updateLbdIdentifier()
      end
   elseif given("lbd_hosts_as_macs") then
      local v = is_true(post["lbd_hosts_as_macs"]) and "1" or "0"
      if ntop.getPref(key(KEYS.lbd_by_mac, ifid)) ~= v then
         ntop.setPref(key(KEYS.lbd_by_mac, ifid), v)
         interface.updateLbdIdentifier()
      end
   end

   if s.has_reports and given("automatic_reports_creation") then
      reports_utils().toggle_automatic_reports(ifid, is_true(post["automatic_reports_creation"]))
   end

   if given("interface_top_talkers_creation") then
      if is_true(post["interface_top_talkers_creation"]) then top_talkers_utils.enableTop(ifid)
      else top_talkers_utils.disableTop(ifid) end
   end

   if s.has_flow_dump and given("interface_flow_dump") then
      local enabled = is_true(post["interface_flow_dump"])
      if enabled ~= (ntop.getPref(key(KEYS.flow_dump_disabled, ifid)) ~= "1") then
         ntop.setPref(key(KEYS.flow_dump_disabled, ifid), enabled and "0" or "1")
         require("configuration_utils").set_restart_required()
         res.restart_required = true
      end
   end

   if s.has_discovery and given("interface_network_discovery") then
      ntop.setPref(key(KEYS.network_discovery, ifid), tostring(is_true(post["interface_network_discovery"])))
   end

   if s.has_companion and given("companion_interface") then
      companion_interface_utils.setCompanion(ifid, post["companion_interface"])
   end

   if s.has_recording_provider and given("traffic_recording_provider") then
      local new = post["traffic_recording_provider"]
      local prev = recording_utils.getCurrentTrafficRecordingProvider(ifid)
      -- From the ntopng recorder to an external one: stop the ntopng one first
      if prev == "ntopng" and new ~= "ntopng" then
         recording_utils.stop(ifid)
         ntop.setCache("ntopng.prefs.ifid_" .. ifid .. ".traffic_recording.enabled", "false")
      end
      recording_utils.setCurrentTrafficRecordingProvider(ifid, new)
   end

   -- DHCP ranges ("first-last,..."; each one validated by http_lint, an empty list removes them all)
   if s.has_dhcp and given("dhcp_ranges") then
      dhcp_utils.setRanges(ifid, post["dhcp_ranges"])
   end

   if s.has_disaggregation then
      if given("disaggregation_criterion") then
         if post["disaggregation_criterion"] == "none" then ntop.delCache(key(KEYS.disaggregation, ifid))
         else ntop.setCache(key(KEYS.disaggregation, ifid), post["disaggregation_criterion"]) end
      end
      if given("show_dyn_iface_traffic") then
         ntop.setPref(key(KEYS.show_dyn_traffic, ifid), is_true(post["show_dyn_iface_traffic"]) and "1" or "0")
         interface.updateDynIfaceTrafficPolicy()
      end
      if given("push_host_filters") then
         ntop.setPref(key(KEYS.push_host_filters, ifid), is_true(post["push_host_filters"]) and "1" or "0")
         interface.updatePushFiltersSettings()
      end
   end

   return res
end

return interface_config_utils
