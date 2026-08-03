--
-- (C) 2013-26 - ntop.org
--
-- Community visibility flags and dynamic entry injection
--
-- get_flags()
--   Returns interface-state, user/admin, capability, and basic feature flags.
--   Pro/nEdge/enterprise flags are added by ntopng_menu_visibility_pro.get_pro_flags()
--   and merged into this table in menu.lua before being passed to definitions.
--
-- get_dynamic_entries(section_key, flags, page_utils, http_prefix)
--   Injects runtime entries from scripts_menu, nEdge, and appliance.
--   Receives the already-merged flags table, so is_nedge etc. are available
--   when the pro module has been loaded.
--

local M = {}

--   Returns a dense copy of an array that may contain nil holes.
function M.compact(t)
   if type(t) ~= "table" then
      return {}
   end

   local max_idx = 0
   for k in pairs(t) do
      if type(k) == "number" and k > max_idx then
         max_idx = k
      end
   end

   local out = {}
   for i = 1, max_idx do
      if t[i] ~= nil then
         out[#out + 1] = t[i]
      end
   end

   return out
end

-- ---------------------------------------------------------------
-- reason(badge, reason_key, suggestion_key)
--   One entry of a menu item's `reason` array. badge decides what
--   resolve() does when `hidden` is true — see below.
--   badge: "pro" | "perm" | "feature"  -> fixable, shown dimmed+tooltip
--          "iface" | "platform"        -> structural, dropped entirely
function M.reason(badge, reason_key, suggestion_key)
   return {
      badge      = badge,
      reason     = i18n(reason_key),
      suggestion = suggestion_key and i18n(suggestion_key) or nil,
   }
end

-- Badge types whose presence means "still show it, just dimmed" instead of
-- dropping the item outright — the user can plausibly act on these
-- (upgrade license, log in as admin, flip a preference).
local FIXABLE_BADGES = { pro = true, perm = true, feature = true }

-- ---------------------------------------------------------------
-- resolve(item)
--   Single source of truth for what a menu section/entry's conditions mean.
--   Every entry/section is authored with:
--     hard_hidden = <lua boolean expr>  -- optional, structural: always drops
--     hidden      = <lua boolean expr>
--     reason      = { M.reason(...), ... }   -- optional, only when hidden can be true
--   resolve() returns:
--     drop(bool)     -- true: omit entirely from the REST response
--     disabled(bool) -- true: keep it, but render dimmed with a tooltip
--
--   `hard_hidden` is checked FIRST and wins over everything else. It is for
--   conditions the user cannot act on and that make the item meaningless
--   rather than merely unavailable.
--
--   Then, for `hidden`:
--   If hidden is false: drop=false, disabled=false.
--   If hidden is true and `reason` has at least one fixable-badge entry:
--     drop=false, disabled=true (dimmed + tooltip from `reason`).
--   If hidden is true and `reason` is empty/nil, or only has structural
--     badges (iface/platform): drop=true (nothing to explain, nothing to fix).
--
--   Side effect: item.reason is normalised in place to a dense array (see
--   compact()), so callers can hand it straight to the JSON encoder.
function M.resolve(item)
   if item.hard_hidden then
      return true, false
   end

   -- Normalise before reading
   local reasons = M.compact(item.reason)
   item.reason = reasons

   if not item.hidden then
      return false, false
   end

   for _, r in ipairs(reasons) do
      if FIXABLE_BADGES[r.badge] then
         return false, true
      end
   end

   return true, false
end

function M.get_flags()
   local page_utils = require "page_utils"
   local auth       = require "auth"

   local prefs        = ntop.getPrefs()
   local info         = ntop.getInfo(true)
   local ifid_stats   = interface.getStats()
   local is_admin     = isAdministrator()

   local is_system_interface  = toboolean(page_utils.is_system_view())
   local system_ifid          = getSystemInterfaceId()
   local current_ifid         = interface.getId()

   local is_pcap_dump        = interface.isPcapDumpInterface()
   local is_packet_interface = interface.isPacketInterface()
   local is_sub_interface    = interface.isSubInterface()
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

   local sFlowDevices   = interface.getSFlowDevices() or {}
   local obsInfo        = interface.getObsPointsInfo() or {}
   local num_obs_points = obsInfo.numObsPoints or 0

   local infrastructure_view = false
   infrastructure_view, _ = isInfrastructureView()

   local cap_alerts    = auth.has_capability(auth.capabilities.alerts)
   local cap_checks    = auth.has_capability(auth.capabilities.checks)
   local cap_developer = auth.has_capability(auth.capabilities.developer)

   local is_asn_mode       = isASNModeEnabled()
   local is_oem            = (info.oem == true)
   local is_windows        = ntop.isWindows()
   local is_pro            = ntop.isPro and ntop.isPro()
   local has_geoip         = ntop.hasGeoIP()
   local has_dump_cache    = ntop.hasDumpCache()
   local has_local_auth    = (ntop.getPref("ntopng.prefs.local.auth_enabled") ~= "0")
   local is_influxdb       = (ntop.getPref("ntopng.prefs.timeseries_driver") == "influxdb")
   local limit_resources   = ntop.limitResourcesUsage()
   local is_allowed_sys    = isAllowedSystemInterface()
   local is_system_ifid    = (tonumber(system_ifid) == tonumber(current_ifid))

   return {
      -- interface state
      is_pcap_dump              = is_pcap_dump,
      is_packet_interface       = is_packet_interface,
      is_sub_interface          = is_sub_interface,
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
      no_hr_flows               = not has_hr_flows,

      -- user / admin
      is_admin                    = is_admin,
      no_admin                    = not is_admin,
      no_local_auth_or_local_user = (not _SESSION["localuser"] and not has_local_auth),

      -- capabilities
      alerts_disabled  = not prefs.are_alerts_enabled,
      no_alerts_cap    = not cap_alerts,
      no_checks_cap    = not cap_checks,
      no_developer_cap = not cap_developer,

      -- basic edition / platform
      is_pro               = is_pro,
      no_pro               = not is_pro,
      is_oem               = is_oem,
      is_windows           = is_windows,
      is_allowed_sys_iface = is_allowed_sys,
      limit_resource_usage = limit_resources,
      is_system_ifid       = is_system_ifid,
      pro_forced_community = (info["pro.forced_community"] == true),

      -- basic features
      no_geoip      = not has_geoip,
      no_dump_cache = not has_dump_cache,
      no_influxdb   = not is_influxdb,
   }
end


return M
