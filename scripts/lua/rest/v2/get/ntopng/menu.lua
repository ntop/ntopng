--
-- (C) 2013-26 - ntop.org
--
-- Returns the filtered menu for the current user and interface
-- Menu definition lives in menu_definition.lua and pro/scripts/lua/modules/menu_definition_pro.lua (community_sections + pro_sections).
-- Visibility flags come from ntopng_menu_visibility.get_flags(); each section
-- and entry carries its own hidden(flags) predicate.
-- Vue receives only visible sections/entries — no client-side filtering.
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "check_redis_prefs"

local rest_utils      = require "rest_utils"
local page_utils      = require "page_utils"
local auth            = require "auth"
local recording_utils = require "recording_utils"
local blog_utils      = require "blog_utils"
local menu_visibility = require "ntopng_menu_visibility"

local ok, err = pcall(function()

local requested_ifid = _GET["ifid"]
if requested_ifid and tostring(requested_ifid) ~= tostring(interface.getId()) then
   interface.select(tostring(requested_ifid))
end

-- Evaluate menu items visibility flags: community + pro
local flags = menu_visibility.get_flags()

local pro_visibilityibility_ok, pro_visibility = pcall(require, "ntopng_menu_visibility_pro")
if pro_visibilityibility_ok and pro_visibility and type(pro_visibility.get_pro_flags) == "function" then
   for k, v in pairs(pro_visibility.get_pro_flags()) do
      flags[k] = v
   end
end

local prefs        = ntop.getPrefs()
local info         = ntop.getInfo(true)
local ifid_stats   = interface.getStats()
local current_ifid = interface.getId()
local iface_names  = interface.getIfNames()
local is_admin     = flags.is_admin
local session_user = _SESSION["user"] or ""
local is_no_login  = isNoLoginUser()
local http_prefix  = ntop.getHttpPrefix()

local is_system_interface  = flags.is_system_interface
local is_allowed_sys_iface = flags.is_allowed_sys_iface
local system_ifid          = getSystemInterfaceId()
local is_nedge             = flags.is_nedge or false
local is_pro               = flags.is_pro
local is_windows           = flags.is_windows
local is_oem               = flags.is_oem

local infrastructure_view      = flags.infrastructure_view
local infrastructure_instances = {}
_, infrastructure_instances = isInfrastructureView()

-- dynamic URL for scripts config
local scripts_config_url = http_prefix .. "/lua/admin/edit_configset.lua?subdir=all"
if tonumber(system_ifid) == tonumber(current_ifid) then
   scripts_config_url = http_prefix .. "/lua/admin/edit_configset.lua?subdir=system"
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

-- ---------------------------------------------------------------
-- Load section definitions and pro menu definition
local community_sections = require("menu_definition")(flags)

local pro_raw_ok, pro_def = pcall(require, "menu_definition_pro")
local pro_sections = (pro_raw_ok and type(pro_def) == "function") and pro_def(flags) or {}

local get_dynamic_entries = (pro_visibilityibility_ok and pro_visibility and type(pro_visibility.get_dynamic_entries) == "function")
   and pro_visibility.get_dynamic_entries
   or function() return {} end

local section_map   = {}   -- key -> section (table with mutable entries array)
local section_order = {}   -- ordered list of keys

for _, section in ipairs(community_sections) do
   section_map[section.key]         = section
   section_map[section.key].entries = section.entries or {}
   section_order[#section_order + 1] = section.key
end

-- Merge pro sections:
--   existing key  -> append entries only (no position change)
--   new key       -> insert right after the section named by ps.after (or append)
for _, ps in ipairs(pro_sections) do
   if section_map[ps.key] then
      for _, e in ipairs(ps.entries or {}) do
         section_map[ps.key].entries[#section_map[ps.key].entries + 1] = e
      end
   else
      section_map[ps.key]         = ps
      section_map[ps.key].entries = ps.entries or {}
      if ps.after then
         local insert_at = #section_order + 1
         for i, k in ipairs(section_order) do
            if k == ps.after then insert_at = i + 1; break end
         end
         table.insert(section_order, insert_at, ps.key)
      else
         section_order[#section_order + 1] = ps.key
      end
   end
end

-- ---------------------------------------------------------------
-- Build filtered + translated menu
-- hidden is a boolean already evaluated by the definition function
local result = {}

local function translate(key_i18n)
   if not key_i18n then return nil end
   local v = i18n(key_i18n)
   return (type(v) == "string") and v or key_i18n
end

for _, sec_key in ipairs(section_order) do
   local section = section_map[sec_key]
   if not section.hidden then
      local entries = nil
      if section.entries ~= nil then
         entries = {}
         for _, entry in ipairs(section.entries) do
            if not entry.hidden then
               entries[#entries + 1] = {
                  key         = entry.key,
                  label       = translate(entry.i18n),
                  icon        = entry.icon or nil,
                  url         = resolve_url(entry),
                  is_external = (entry.is_external == true),
                  is_divider  = (entry.key == "divider") or (entry.is_divider == true),
               }
            end
         end

         -- Append dynamic entries (scripts_menu, nedge, appliance) — pro only
         local dynamic = get_dynamic_entries(sec_key, flags, page_utils, http_prefix)
         for _, de in ipairs(dynamic) do
            entries[#entries + 1] = de
         end
      end

      -- Skip sections with no content
      local has_content = (section.url ~= nil) or (entries ~= nil and #entries > 0)
      if has_content then
         result[#result + 1] = {
            key     = sec_key,
            label   = translate(section.i18n),
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
   elseif ntop.isEnterpriseM and ntop.isEnterpriseM() and is_sub and s.dynamic_interface_probe_ip then
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
   version_full   = info.edition or "",
   copyright      = info.copyright or "",
   uptime         = secondsToTime(ntop.getUptime()),
})

end) -- pcall

if not ok then
   rest_utils.answer(rest_utils.consts.err.internal_error, { error = tostring(err) })
end
