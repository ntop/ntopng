--
-- (C) 2013-26 - ntop.org
--

--
-- Exports two functions:
--   get_flags()          -> flat table of named boolean flags used by entry_hidden checks
--   get_dynamic_entries(section_key, flags, page_utils, http_prefix)
--                        -> array of extra {key,label,url,is_divider} rows injected by
--                          page_utils.scripts_menu, nedge, appliance, etc.
--

local ntopng_menu_visibility = {}

function ntopng_menu_visibility.get_flags()
   local page_utils     = require "page_utils"
   local auth           = require "auth"
   local behavior_utils = require "behavior_utils"
   local vs_utils       = require "vs_utils"

   local prefs        = ntop.getPrefs()
   local info         = ntop.getInfo(true)
   local ifid_stats   = interface.getStats()
   local current_ifid = interface.getId()
   local is_admin     = isAdministrator()
   local http_prefix  = ntop.getHttpPrefix()

   local is_system_interface  = toboolean(page_utils.is_system_view())
   local system_ifid          = getSystemInterfaceId()
   local is_nedge             = ntop.isnEdge()
   local is_nedge_enterprise  = ntop.isnEdgeEnterprise()
   local is_routing_mode      = is_nedge and ntop.isRoutingMode() or false
   local is_enterprise        = ntop.isEnterprise()
   local is_enterprise_m      = ntop.isEnterpriseM()
   local is_enterprise_l      = ntop.isEnterpriseL()
   local is_enterprise_xl     = ntop.isEnterpriseXL()
   local is_pro               = ntop.isPro()
   local is_appliance         = ntop.isAppliance()
   local is_windows           = ntop.isWindows()
   local is_oem               = (info.oem == true)

   local has_ch_support      = hasClickHouseSupport()
   local is_influxdb         = (ntop.getPref("ntopng.prefs.timeseries_driver") == "influxdb")
   local asset_inventory     = assetsInventoryEnabled()
   local is_geoip            = ntop.hasGeoIP()
   local limit_resources     = ntop.limitResourcesUsage()
   local has_dump_cache      = ntop.hasDumpCache()
   local has_local_auth      = (ntop.getPref("ntopng.prefs.local.auth_enabled") ~= "0")
   local has_nanalyst        = page_utils.has_nanalyst and page_utils.has_nanalyst()
   local has_developer_menu  = (ntop.getPref("ntopng.prefs.menu_entries.developer") ~= "0")
   local has_help_menu       = (ntop.getPref("ntopng.prefs.menu_entries.help") ~= "0")
   local is_asn_mode         = isASNModeEnabled()

   local is_pcap_dump        = interface.isPcapDumpInterface()
   local is_db_view          = interface.isDatabaseViewInterface()
   local is_viewed_interface = interface.isViewed()
   local is_zmq_interface    = interface.isZMQInterface()
   local is_loopback         = interface.isLoopback()
   local is_discoverable     = interface.isDiscoverableInterface()
   local has_vlans           = interface.hasVLANs()
   local is_viewed           = (ifid_stats.isViewed == true)
   local is_db_type          = (ifid_stats["type"] == "db")
   local has_hr_flows        = (ifid_stats["has_hr_flows"] == true)
   local has_macs            = (ifid_stats.has_macs == true)
   local has_seen_pods       = (ifid_stats.has_seen_pods == true)
   local has_seen_containers = (ifid_stats.has_seen_containers == true)

   local flowDevices    = (interface.getFlowDevices and interface.getFlowDevices()) or {}
   local sFlowDevices   = interface.getSFlowDevices() or {}
   local obsInfo        = interface.getObsPointsInfo() or {}
   local num_obs_points = obsInfo.numObsPoints or 0

   local infrastructure_view = false
   infrastructure_view, _ = isInfrastructureView()

   -- capability shortcuts
   local cap_alerts     = auth.has_capability(auth.capabilities.alerts)
   local cap_checks     = auth.has_capability(auth.capabilities.checks)
   local cap_hist_flows = auth.has_capability(auth.capabilities.historical_flows)
   local cap_developer  = auth.has_capability(auth.capabilities.developer)

   -- computed compound flags
   local has_exporters            = (ifid_stats.type == "zmq") or (ifid_stats.type == "custom") or
                                    (is_pro and (table.len(flowDevices) > 0))
   local service_map_available, _ = behavior_utils.mapsAvailable()
   local vs_available             = vs_utils.is_available()
   local has_bgp_server           = not (isEmptyString(ntop.getPref("ntopng.prefs.bgp_server.ip_address")) or
                                         isEmptyString(ntop.getPref("ntopng.prefs.bgp_server.port")))

   local devices_exclusion_enabled = false
   local checks_config = require("checks").getConfigset()["config"]
   if checks_config and checks_config["interface"] and
      checks_config["interface"]["device_connection_disconnection"] and
      checks_config["interface"]["device_connection_disconnection"]["min"]["enabled"] then
      devices_exclusion_enabled = true
   end

   local is_system_ifid     = (tonumber(system_ifid) == tonumber(current_ifid))
   local is_allowed_sys_iface = isAllowedSystemInterface()

   return {
      -- interface state
      is_pcap_dump              = is_pcap_dump,
      is_system_interface       = is_system_interface,
      no_system_interface       = not is_system_interface,
      is_db_view_interface      = is_db_view,
      is_viewed                 = is_viewed,
      is_viewed_interface       = is_viewed_interface,
      is_zmq_interface          = is_zmq_interface,
      is_loopback_interface     = is_loopback,
      no_discoverable_interface = not is_discoverable,
      is_asn_mode_enabled       = is_asn_mode,
      no_asn_mode               = not is_asn_mode,
      infrastructure_view       = infrastructure_view,
      is_db_type                = is_db_type,
      no_vlans                  = not has_vlans,
      no_macs                   = not has_macs,
      no_pods                   = not has_seen_pods,
      no_containers             = not has_seen_containers,
      no_obs_points             = (num_obs_points == 0),
      no_sflow_devices          = (table.len(sFlowDevices) == 0),
      no_exporters              = not has_exporters,
      no_hr_flows               = not has_hr_flows,
      no_bgp_server             = not has_bgp_server,
      no_service_map            = not service_map_available,
      no_vs_utils               = not vs_available,

      -- user/admin
      is_admin                    = is_admin,
      no_admin                    = not is_admin,
      no_local_auth_or_local_user = (not _SESSION["localuser"] and not has_local_auth),

      -- features / capabilities
      alerts_disabled  = not prefs.are_alerts_enabled,
      no_alerts_cap    = not cap_alerts,
      no_checks_cap    = not cap_checks,
      no_developer_cap = not cap_developer,

      -- license / edition
      is_pro            = is_pro,
      no_pro            = not is_pro,
      is_nedge          = is_nedge,
      is_nedge_enterprise = is_nedge_enterprise,
      is_routing_mode   = is_routing_mode,
      is_oem            = is_oem,
      is_windows        = is_windows,
      is_appliance      = is_appliance,
      is_allowed_sys_iface = is_allowed_sys_iface,
      limit_resource_usage = limit_resources,

      -- enterprise tiers
      no_enterprise             = not is_enterprise,
      no_enterprise_m           = not is_enterprise_m,
      no_enterprise_l           = not is_enterprise_l,
      no_enterprise_xl          = not is_enterprise_xl,
      no_enterprise_l_or_nedge  = (not is_enterprise_l and not is_nedge_enterprise),
      no_enterprise_m_or_nedge  = (not is_enterprise_m and not is_nedge_enterprise),
      no_enterprise_m_no_windows = (not is_enterprise_m or is_windows),

      -- compound conditions
      no_ch_support             = not has_ch_support,
      no_influxdb               = not is_influxdb,
      no_asset_inventory        = not asset_inventory,
      no_geoip                  = not is_geoip,
      no_dump_cache             = not has_dump_cache,
      no_nanalyst               = not has_nanalyst,
      no_developer_menu         = (not has_developer_menu) and is_enterprise_m,
      no_help_menu              = (not has_help_menu) and is_enterprise_m,
      no_devices_exclusion      = not devices_exclusion_enabled,
      is_system_ifid            = is_system_ifid,
      pro_forced_community      = (info["pro.forced_community"] == true),

      -- complex compound
      no_enterprise_with_ch               = not (is_enterprise and has_ch_support),
      no_enterprise_or_nedge_with_ch_hist = (not is_enterprise and not is_nedge_enterprise) or
                                            not cap_hist_flows or not has_ch_support,
   }
end


-- get_dynamic_entries: returns plugin/nedge/appliance-injected menu rows
-- for sections that can be extended at runtime.
--
-- Each returned entry is already resolved: {key, label, url, is_divider}
-- Hidden entries are simply omitted.
function ntopng_menu_visibility.get_dynamic_entries(section_key, flags, page_utils, http_prefix)
   local entries = {}

   -- health
   if section_key == "health" then
      if page_utils.scripts_menu then
         for k, entry in pairsByField(page_utils.scripts_menu, "sort_order", rev) do
            if entry.menu_entry.section == page_utils.menu_sections.health.key then
               local label_raw = i18n(entry.menu_entry.i18n or entry.menu_entry.key)
               entries[#entries + 1] = {
                  key        = entry.menu_entry.key,
                  label      = (type(label_raw) == "string") and label_raw or entry.menu_entry.key,
                  url        = http_prefix .. entry.url,
                  is_divider = false,
               }
            end
         end
      end

   -- pollers
   elseif section_key == "pollers" then
      if page_utils.scripts_menu then
         for k, entry in pairsByField(page_utils.scripts_menu, "sort_order", rev) do
            if entry.menu_entry.section == page_utils.menu_sections.pollers.key then
               local label_raw = i18n(entry.menu_entry.i18n or entry.menu_entry.key)
               entries[#entries + 1] = {
                  key        = entry.menu_entry.key,
                  label      = (type(label_raw) == "string") and label_raw or entry.menu_entry.key,
                  url        = http_prefix .. entry.url,
                  is_divider = false,
               }
            end
         end
      end

   -- system_stats: nedge / appliance entries
   elseif section_key == "system_stats" then
      -- script-injected (skip pollers, those live under pollers section)
      if page_utils.scripts_menu then
         for k, entry in pairsByField(page_utils.scripts_menu, "sort_order", rev) do
            if entry.menu_entry.section ~= "pollers" then
               local label_raw = i18n(entry.menu_entry.i18n or entry.menu_entry.key)
               entries[#entries + 1] = {
                  key        = entry.menu_entry.key,
                  label      = (type(label_raw) == "string") and label_raw or entry.menu_entry.key,
                  url        = http_prefix .. entry.url,
                  is_divider = false,
               }
            end
         end
      end

      -- nedge entries
      if flags.is_nedge then
         if #entries > 0 and not flags.no_admin then
            entries[#entries + 1] = { key = "divider", is_divider = true }
         end
         local nedge_rows = {
            { key = "system_setup",       i18n_key = "nedge.system_setup",       url = "/lua/system_setup_ui/interfaces.lua", hidden = flags.no_admin },
            { key = "dhcp_static_leases", i18n_key = "nedge.dhcp_static_leases", url = "/lua/pro/nedge/admin/dhcp_leases.lua", hidden = flags.no_admin or not flags.is_routing_mode },
            { key = "dhcp_active_leases", i18n_key = "nedge.dhcp_active_leases", url = "/lua/pro/nedge/admin/dhcp_active_leases.lua", hidden = flags.no_admin or not flags.is_routing_mode },
            { key = "port_forwarding",    i18n_key = "nedge.port_forwarding",    url = "/lua/pro/nedge/admin/port_forwarding.lua", hidden = flags.no_admin or not flags.is_routing_mode },
            { key = "rules_config",       i18n_key = "nedge.rules_config",       url = "/lua/pro/nedge/admin/rules_config.lua", hidden = flags.no_admin or not flags.is_routing_mode },
            { key = "forwarders_config",  i18n_key = "nedge.forwarders_config",  url = "/lua/pro/nedge/admin/forwarders_config.lua", hidden = flags.no_admin or not flags.is_routing_mode },
         }
         for _, r in ipairs(nedge_rows) do
            if not r.hidden then
               local label_raw = i18n(r.i18n_key)
               entries[#entries + 1] = {
                  key        = r.key,
                  label      = (type(label_raw) == "string") and label_raw or r.key,
                  url        = http_prefix .. r.url,
                  is_divider = false,
               }
            end
         end
      end

      -- appliance entries
      if flags.is_appliance then
         if #entries > 0 and not flags.no_admin then
            entries[#entries + 1] = { key = "divider", is_divider = true }
         end
         if not flags.no_admin then
            local label_raw = i18n("nedge.system_setup")
            entries[#entries + 1] = {
               key        = "system_setup",
               label      = (type(label_raw) == "string") and label_raw or "system_setup",
               url        = http_prefix .. "/lua/system_setup_ui/mode.lua",
               is_divider = false,
            }
         end
      end
   end

   return entries
end

return ntopng_menu_visibility
