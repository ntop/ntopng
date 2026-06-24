--
-- (C) 2013-26 - ntop.org
--
-- Returns the filtered menu for the current user and interface.
-- Visibility logic lives in ntopng_menu_visibility.lua; menu_definition.json
-- carries pure structure (no hide_if fields).
-- Vue receives only visible sections/entries — no client-side filtering 
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/vulnerability_scan/?.lua;" .. package.path

require "lua_utils"
require "check_redis_prefs"

local rest_utils      = require "rest_utils"
local page_utils      = require "page_utils"
local auth            = require "auth"
local json            = require "dkjson"
local recording_utils = require "recording_utils"
local blog_utils      = require "blog_utils"
local menu_visibility = require "ntopng_menu_visibility"

local ok, err = pcall(function()

-- ---------------------------------------------------------------
local requested_ifid = _GET["ifid"]
if requested_ifid and tostring(requested_ifid) ~= tostring(interface.getId()) then
   interface.select(tostring(requested_ifid))
end

-- ---------------------------------------------------------------
-- Evaluate viisbility flags
local flags = menu_visibility.get_flags()

local prefs        = ntop.getPrefs()
local info         = ntop.getInfo(true)
local ifid_stats   = interface.getStats()
local current_ifid = interface.getId()
local iface_names  = interface.getIfNames()
local is_admin     = isAdministrator()
local session_user = _SESSION["user"] or ""
local is_no_login  = isNoLoginUser()
local http_prefix  = ntop.getHttpPrefix()

local is_system_interface  = toboolean(page_utils.is_system_view())
local is_allowed_sys_iface = isAllowedSystemInterface()
local system_ifid          = getSystemInterfaceId()
local is_nedge             = ntop.isnEdge()
local is_pro               = ntop.isPro()
local is_windows           = ntop.isWindows()
local is_oem               = (info.oem == true)

local infrastructure_view      = false
local infrastructure_instances = {}
infrastructure_view, infrastructure_instances = isInfrastructureView()

-- dynamic URL for scripts config
local scripts_config_url = http_prefix .. "/lua/admin/edit_configset.lua?subdir=all"
if tonumber(system_ifid) == tonumber(current_ifid) then
   scripts_config_url = http_prefix .. "/lua/admin/edit_configset.lua?subdir=system"
end

-- Section visibility: return true to HIDE the section
local section_hidden = {
   dashboard     = function() return flags.is_pcap_dump or flags.is_system_interface or flags.is_db_view_interface end,
   monitoring    = function() return flags.is_system_interface or flags.no_admin end,
   alerts        = function() return flags.alerts_disabled or flags.no_alerts_cap or flags.is_db_view_interface or flags.infrastructure_view end,
   flows         = function() return flags.is_asn_mode_enabled or flags.is_system_interface or flags.infrastructure_view or flags.is_nedge end,
   nanalyst      = function() return flags.no_nanalyst end,
   views         = function() return (flags.no_asn_mode and not flags.is_nedge) or flags.is_system_interface or flags.is_viewed or flags.infrastructure_view end,
   hosts         = function() return flags.is_system_interface or flags.is_viewed or flags.infrastructure_view or flags.is_asn_mode_enabled or flags.is_nedge end,
   collection    = function() return flags.no_exporters or flags.no_enterprise_m or flags.is_system_interface or flags.infrastructure_view end,
   maps          = function() return flags.is_system_interface or flags.is_viewed or flags.infrastructure_view end,
   if_stats      = function() return flags.is_system_interface or flags.infrastructure_view end,
   health        = function() return flags.no_system_interface end,
   pollers       = function() return flags.no_system_interface end,
   notifications = function() return flags.no_system_interface or flags.no_admin end,
   policies      = function() return flags.infrastructure_view or flags.no_admin end,
   admin         = function() return flags.no_admin end,
   dev           = function() return flags.is_oem or flags.no_developer_cap or flags.no_developer_menu end,
   about         = function() return flags.is_oem or flags.no_help_menu end,
   -- system_stats: only on system interface and only when allowed
   system_stats  = function() return not flags.is_allowed_sys_iface or flags.no_system_interface end,
}

-- Entry visibility: return true to HIDE the entry
local entry_hidden = {
   -- dashboard
   assets_dashboard = function() return flags.no_ch_support or flags.no_asset_inventory or flags.no_enterprise_l end,
   gateways_users   = function() return not flags.is_nedge or not flags.is_routing_mode end,
   traffic_report   = function() return (not flags.is_nedge and flags.no_enterprise_with_ch) or (flags.is_nedge and (not flags.is_nedge_enterprise or flags.no_ch_support)) or flags.infrastructure_view or flags.is_viewed end,
   hr_chart         = function() return flags.no_enterprise_m or flags.no_ch_support or flags.no_hr_flows end,

   -- monitoring
   active_monitoring        = function() return flags.is_windows end,
   network_discovery        = function() return flags.no_discoverable_interface or flags.is_windows or flags.is_loopback_interface or flags.limit_resource_usage or flags.infrastructure_view end,
   infrastructure_dashboard = function() return flags.no_enterprise_l_or_nedge or flags.no_admin end,
   snmp_monitoring          = function() return flags.no_enterprise_m_or_nedge end,
   vulnerability_scan       = function() return flags.no_vs_utils or flags.is_zmq_interface end,

   -- alerts
   alerts_geomap    = function() return true end,  -- always hidden per old code: hidden = true or (not is_enterprise_XL)
   alerts_graph     = function() return flags.no_enterprise_l_or_nedge or flags.no_ch_support or flags.is_pcap_dump end,
   alerts_analysis  = function() return flags.no_enterprise or flags.is_pcap_dump end,
   notifications    = function() return flags.no_admin or flags.is_pcap_dump end,

   -- flows
   db_explorer         = function() return flags.no_enterprise_or_nedge_with_ch_hist or flags.is_viewed or flags.is_db_type end,
   server_ports        = function() return flags.no_enterprise_l end,
   bgp_looking_glass   = function() return flags.no_bgp_server end,

   -- views (nedge mode — all hidden unless nedge)
   nedge_flows      = function() return not flags.is_nedge end,
   nedge_hosts      = function() return not flags.is_nedge end,
   nedge_devices    = function() return not flags.is_nedge end,
   nedge_db_explorer = function() return not flags.is_nedge or not flags.is_nedge_enterprise or flags.no_ch_support end,
   nedge_users      = function() return not flags.is_nedge end,
   nedge_vlans      = function() return not flags.is_nedge or flags.no_vlans end,
   nedge_networks   = function() return not flags.is_nedge end,
   nedge_os         = function() return not flags.is_nedge end,
   nedge_geo_map    = function() return not flags.is_nedge or flags.is_loopback_interface end,

   -- views (ASN mode — all hidden when nedge)
   hosts_asn_mode         = function() return flags.is_nedge end,
   active_flows_asn_mode  = function() return flags.is_nedge end,
   db_explorer_asn_mode         = function() return flags.is_nedge or flags.no_enterprise_or_nedge_with_ch_hist or flags.is_viewed or flags.is_db_type end,
   historical_flows_asn_mode    = function() return not flags.is_nedge or flags.no_enterprise_or_nedge_with_ch_hist or flags.is_viewed or flags.is_db_type end,
   server_ports_asn_mode  = function() return flags.is_nedge or flags.no_enterprise_l end,
   bgp_looking_glass_asn  = function() return flags.is_nedge or flags.no_bgp_server end,

   -- hosts
   devices = function() return flags.no_macs end,
   assets  = function() return flags.no_enterprise_m_no_windows or flags.no_asset_inventory end,

   -- collection
   sflow_exporters    = function() return flags.no_sflow_devices end,
   observation_points = function() return flags.no_obs_points end,

   -- maps
   analysis_map = function() return flags.no_service_map end,
   geo_map      = function() return flags.is_loopback_interface or flags.no_geoip end,
   hosts_map    = function() return flags.no_enterprise or flags.is_asn_mode_enabled end,

   -- if_stats
   networks           = function() return flags.is_viewed_interface end,
   host_pools         = function() return flags.is_nedge end,
   autonomous_systems = function() return flags.no_geoip or flags.is_viewed_interface end,
   countries          = function() return flags.no_geoip or flags.is_viewed_interface end,
   vlans              = function() return flags.no_vlans or flags.is_viewed_interface end,
   pods               = function() return flags.no_pods end,
   containers         = function() return flags.no_containers end,

   -- health
   influxdb_status   = function() return flags.no_influxdb end,
   clickhouse_status = function() return flags.no_ch_support end,

   -- pollers
   -- assets_snmp: hidden if no asset inventory
   assets_snmp                     = function() return flags.no_asset_inventory end,
   -- snmp: in system interface, hidden if not enterprise_m/nedge
   snmp                            = function() return flags.no_enterprise_m_or_nedge end,
   -- active_monitoring_system: only for system interface (always visible when section is shown)
   active_monitoring_system        = function() return false end,
   -- infrastructure_dashboard_system: same condition as monitoring section version
   infrastructure_dashboard_system = function() return flags.no_enterprise_l_or_nedge or flags.no_admin end,

   -- policies
   access_control_list = function() return flags.no_enterprise_l or flags.is_asn_mode_enabled end,
   device_protocols    = function() return flags.is_asn_mode_enabled end,
   device_exclusions   = function() return flags.no_checks_cap or flags.no_enterprise_m or flags.no_devices_exclusion end,
   network_config      = function() return flags.no_checks_cap end,
   traffic_rules       = function() return flags.no_enterprise or flags.no_admin end,
   scripts_config      = function() return flags.no_checks_cap end,
   alert_exclusions    = function() return flags.no_checks_cap or flags.no_enterprise_m or flags.is_system_ifid end,
   profiles            = function() return flags.no_pro or flags.is_nedge or flags.is_asn_mode_enabled end,

   -- admin
   nedge_users            = function() return not flags.is_nedge end,
   manage_users           = function() return flags.no_local_auth_or_local_user end,
   manage_configurations  = function() return flags.no_dump_cache end,
   divider_nedge_admin    = function() return not flags.is_nedge end,
   remote_assistance      = function() return true end,  -- page removed (attic), hidden until restored
   conf_backup            = function() return not flags.is_nedge or flags.no_admin or flags.is_oem end,
   conf_restore           = function() return not flags.is_nedge or flags.no_admin or flags.is_oem end,

   -- dev
   manage_data = function() return flags.no_admin end,

   -- about
   license = function() return flags.pro_forced_community or flags.no_admin end,
   limits  = function() return flags.no_admin end,
}

-- Load menu definition JSON
local def_path = dirs.installdir .. "/httpdocs/misc/menu_definition.json"
local f = io.open(def_path, "r")
if not f then
   rest_utils.answer(rest_utils.consts.err.internal_error, { error = "menu_definition.json not found" })
   return
end
local def_raw = f:read("*a")
f:close()

local def, _, jerr = json.decode(def_raw)
if jerr then
   rest_utils.answer(rest_utils.consts.err.internal_error, { error = "menu_definition.json parse error: " .. jerr })
   return
end

local dynamic_urls = {
   scripts_config_url = scripts_config_url,
}

local function resolve_url(entry)
   if entry.url_dynamic then
      return dynamic_urls[entry.url_dynamic] or ""
   end
   if entry.url then
      if entry.is_external then return entry.url end
      return http_prefix .. entry.url
   end
   return nil
end


-- Build filtered + translated menu
local result = {}

for _, section in ipairs(def.sections) do
   local sec_check = section_hidden[section.key]
   if sec_check and sec_check() then
      -- section hidden: skip entirely
   else
      -- Collect static entries from JSON
      local entries = nil
      if section.entries ~= nil then
         entries = {}
         for _, entry in ipairs(section.entries) do
            local entry_check = entry_hidden[entry.key]
            if not (entry_check and entry_check()) then
               entries[#entries + 1] = {
                  key         = entry.key,
                  label       = entry.i18n and (function() local v = i18n(entry.i18n); return type(v) == "string" and v or entry.i18n end)() or nil,
                  icon        = entry.icon or nil,
                  url         = resolve_url(entry),
                  is_external = (entry.is_external == true),
                  is_divider  = (entry.key == "divider") or (entry.is_divider == true),
               }
            end
         end

         -- Append dynamic entries (scripts_menu, nedge, appliance)
         local dynamic = menu_visibility.get_dynamic_entries(section.key, flags, page_utils, http_prefix)
         for _, de in ipairs(dynamic) do
            entries[#entries + 1] = de
         end
      end

      -- Skip sections that end up with no entries (and no direct url)
      local has_content = (section.url ~= nil) or
                          (entries ~= nil and #entries > 0)
      if has_content then
         local sec_label_raw = i18n(section.i18n)
         local sec_label = (type(sec_label_raw) == "string") and sec_label_raw or section.i18n

         result[#result + 1] = {
            key     = section.key,
            label   = sec_label,
            icon    = section.icon or "",
            url     = section.url and (http_prefix .. section.url) or nil,
            entries = entries,
         }
      end
   end
end

-- ---------------------------------------------------------------
-- Build interface list for topbar dropdown
local ifnames     = {}
local ifHdescr    = {}
local ifCustom    = {}
local views       = {}
local dynamic     = {}
local recording   = {}
local pcapdump    = {}
local packetifs   = {}
local zmqifs      = {}
local drops       = {}
local action_urls = {}

for v, k in pairs(iface_names) do
   interface.select(k)
   local s       = interface.getStats()
   local is_pcap = interface.isPcapDumpInterface()
   local is_sub  = interface.isSubInterface()
   local is_pkt  = interface.isPacketInterface()
   local is_zmq2 = interface.isZMQInterface()

   ifnames[tostring(s.id)]     = k
   action_urls[tostring(s.id)] = page_utils.switch_interface_form_action_url(current_ifid, s.id, s.type)

   if is_pcap  then pcapdump[tostring(s.id)]  = true end
   if s.isView then views[tostring(s.id)]     = true end
   if is_sub   then dynamic[tostring(s.id)]   = true end
   if recording_utils.isEnabled(s.id) then recording[tostring(s.id)] = true end
   if is_pkt   then packetifs[tostring(s.id)] = true end
   if is_zmq2  then zmqifs[tostring(s.id)]    = true end
   if s.stats_since_reset.drops * 100 > s.stats_since_reset.packets then
      drops[tostring(s.id)] = true
   end
   ifCustom[tostring(s.id)] = s.customIftype

   local descr = getHumanReadableInterfaceName(v)
   if is_windows and string.contains(descr, "{") then
      descr = s.description
   elseif ntop.isEnterpriseM() and is_sub and s.dynamic_interface_probe_ip then
      local snmp_utils      = require "snmp_utils"
      local snmp_cached_dev = require "snmp_cached_dev"
      local cached_device   = snmp_cached_dev:create(s.dynamic_interface_probe_ip)
      local snmp_name, snmp_if_name
      if cached_device then
         if cached_device.system and cached_device.system.name then
            snmp_name = cached_device.system.name
            if s.dynamic_interface_inifidx then
               if cached_device.interfaces and cached_device.interfaces[tostring(s.dynamic_interface_inifidx)] then
                  snmp_if_name = snmp_utils.get_snmp_interface_label(
                     cached_device.interfaces[tostring(s.dynamic_interface_inifidx)], true)
               else
                  snmp_if_name = s.dynamic_interface_inifidx
               end
            end
         end
      end
      if snmp_name then
         local fmt = snmp_if_name and string.format("%s [%s]", snmp_name, snmp_if_name) or string.format("%s", snmp_name)
         if descr ~= s.description then
            descr = string.format("%s (%s)", descr, fmt)
         else
            descr = fmt
         end
      end
   else
      if descr ~= s.description and not views[tostring(s.id)] and not pcapdump[tostring(s.id)] then
         if descr == shortenCollapse(s.description) then
            descr = s.description
         end
      end
   end
   ifHdescr[tostring(s.id)] = descr
end

-- Collect observation points for the current interface
local observation_points = nil
do
   local obs_info = interface.getObsPointsInfo()
   if obs_info and obs_info["ObsPoints"] and table.len(obs_info["ObsPoints"]) > 0 then
      observation_points = obs_info["ObsPoints"]
   end
end

-- Add the system interface explicitly (not returned by getIfNames())
if is_allowed_sys_iface then
   local sys_id = tostring(system_ifid)
   if not ifnames[sys_id] then
      interface.select(system_ifid)
      local ss = interface.getStats()
      ifnames[sys_id]     = ss.name or "@SystemInterface"
      ifHdescr[sys_id]    = i18n("system") or "System"
      action_urls[sys_id] = ntop.getHttpPrefix() .. "/lua/system_stats.lua?ifid=" .. sys_id
      interface.select(current_ifid)
   end
end

interface.select(current_ifid)

-- Blog notifications
local blog_posts = {}
local new_posts_counter = 0
if not is_oem then
   local blog_username = session_user
   if is_no_login then blog_username = "no_login" end
   local posts_raw, npc = blog_utils.readPostsFromRedis(blog_username)
   new_posts_counter = npc or 0
   for _, p in pairs(posts_raw or {}) do
      local user_has_read = p.users_read and p.users_read[blog_username] == true
      local title = p.title or ""
      if #title > 42 then title = title:sub(1, 42) .. "..." end
      blog_posts[#blog_posts + 1] = {
         id         = p.id,
         title      = title,
         url        = p.link,
         short_desc = p.shortDesc,
         epoch      = p.epoch,
         is_read    = user_has_read,
      }
   end
end

-- License badge
local license_badge = nil
if info["pro.systemid"] and info["pro.systemid"] ~= "" then
   if info["pro.release"] then
      if info["pro.demo_ends_at"] then
         local rest_secs = info["pro.demo_ends_at"] - os.time()
         if rest_secs > 0 then
            license_badge = {
               type  = "demo_expires",
               label = i18n("about.licence_expires_in", { time = secondsToTime(rest_secs) }),
               url   = "https://shop.ntop.org",
            }
         end
      end
   elseif not info["pro.forced_community"] then
      license_badge = {
         type  = "upgrade",
         label = i18n("about.upgrade_to_professional"),
         url   = "https://shop.ntop.org",
      }
   end
end

-- User menu data
local theme_selector = ntop.getPref("ntopng.user." .. session_user .. ".theme")
local theme_label    = i18n("toggle_dark_theme")
if theme_selector == "dark" then theme_label = i18n("toggle_white_theme") end

local logo_path = nil
if (is_pro or is_nedge) and ntop.exists(dirs.installdir .. "/httpdocs/img/custom_logo.png") then
   logo_path = http_prefix .. "/img/custom_logo.png"
end

-- Infrastructure instances as array
local infra_arr = {}
for k, v in pairs(infrastructure_instances or {}) do
   infra_arr[#infra_arr + 1] = { id = k, info = v }
end

rest_utils.answer(rest_utils.consts.success.ok, {
   -- sidebar
   sections    = result,
   logo_path   = logo_path,
   http_prefix = http_prefix,

   -- topbar: interface dropdown
   ifnames      = ifnames,
   ifHdescr     = ifHdescr,
   ifCustom     = ifCustom,
   views        = views,
   dynamic      = dynamic,
   recording    = recording,
   pcapdump     = pcapdump,
   packetifs    = packetifs,
   zmqifs       = zmqifs,
   drops        = drops,
   action_urls  = action_urls,
   current_ifid        = tostring(current_ifid),
   system_ifid         = tostring(system_ifid),
   observation_points  = observation_points,
   is_system_interface = is_system_interface,
   infrastructure_instances = infra_arr,
   infrastructure_view = infrastructure_view,

   -- topbar: user menu
   username         = session_user,
   is_admin         = is_admin,
   is_no_login_user = is_no_login,
   is_local_user    = (_SESSION["localuser"] ~= nil),
   is_nedge         = is_nedge,
   is_windows       = is_windows,
   is_package       = (ntop.isPackage() == true),
   has_updates_support = (hasSoftwareUpdatesSupport() == true),
   theme_label      = theme_label,
   theme            = theme_selector or "light",

   -- topbar: blog
   blog_posts        = blog_posts,
   new_posts_counter = new_posts_counter,
   is_oem            = is_oem,

   -- topbar: license badge
   license_badge = license_badge,

   -- product info
   product        = info.product or "",
   version        = info.version or "",
   version_full   = getNtopngRelease(info),
   copyright      = info.copyright or "",
   uptime         = secondsToTime(ntop.getUptime()),
})

end) -- pcall

if not ok then
   rest_utils.answer(rest_utils.consts.err.internal_error, { error = tostring(err) })
end
