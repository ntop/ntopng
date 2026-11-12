--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

--
-- Overview of an active host (host details page): identity, flags, traffic, flows, score and
-- TCP counters as raw values (host), plus what the page derives from other sources (ext).
-- counters=true: only the host values (polled by the page every few seconds).
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/host/overview.lua?ifid=0&host=192.168.1.1@0"
--

require "http_lint"
require "label_utils"
local rest_utils = require "rest_utils"

local ifid = _GET["ifid"]
local host_key = _GET["host"]

if isEmptyString(ifid) or isEmptyString(host_key) then
   rest_utils.answer(rest_utils.consts.err.invalid_args)
   return
end

interface.select(ifid)
if tostring(interface.getId()) ~= tostring(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

local host_info = hostkey2hostinfo(host_key)
local h = interface.getHostInfo(host_info["host"], host_info["vlan"])

if h == nil then
   rest_utils.answer(rest_utils.consts.err.not_found)
   return
end

-- The values of the page: the C host table also holds the per protocol stats, not needed here
local KEYS = {
   "ip", "mac", "router", "vlan", "localhost", "is_broadcast", "is_multicast", "privatehost", "systemhost",
   "broadcast_domain_host", "dhcpHost", "dhcp_server", "crawlerBotScannerHost", "is_blackhole", "is_blacklisted",
   "blacklist_name", "childSafe", "device_type", "iface_index", "os", "os_detail", "asn", "asname",
   "observation_point_id", "local_network_name", "local_network_id", "city", "country", "tcp_fingerprint", "num_alerts",
   "active_alerted_flows", "num_reset_flows", "has_blocking_quota", "has_blocking_shaper", "seen.first", "seen.last",
   "bytes.sent", "bytes.rcvd", "local.bytes", "non_local.bytes", "packets.sent", "packets.rcvd", "score.as_client",
   "score.as_server", "active_flows.as_client", "active_flows.as_server", "flows.as_client", "flows.as_server",
   "alerted_flows.as_client", "alerted_flows.as_server", "unreachable_flows.as_client", "unreachable_flows.as_server",
   "num_blacklisted_flows", "num_unidirectional_tcp_flows", "contacts.as_client", "contacts.as_server", "flows.dropped",
   "num_contacted_peers_with_tcp_udp_flows_no_response", "num_incoming_peers_that_sent_tcp_udp_flows_no_response",
   "server_contacts", "tcp.packets.seq_problems", "tcpPacketStats.sent", "tcpPacketStats.rcvd", "os_learning",
   "device_ip", "more_then_one_device", "ssdp", "inconsistent_host_os", "usernames",
}

local host = {}
for _, k in ipairs(KEYS) do
   host[k] = h[k]
end

-- Score breakdown per category (C table indexed 0: network, 1: security)
local function breakdown(what)
   if not what then return nil end
   return { network = what[0] or 0, security = what[1] or 0 }
end
if h.score_pct then
   host.score_breakdown_client = breakdown(h.score_pct["score_breakdown_client"])
   host.score_breakdown_server = breakdown(h.score_pct["score_breakdown_server"])
end
host.tot_num_anomalies = h.score_behaviour and h.score_behaviour.tot_num_anomalies or 0
host.label = hostinfo2label(h, false, false)
host.now = os.time()

if _GET["counters"] == "true" then
   rest_utils.answer(rest_utils.consts.success.ok, { host = host })
   return
end

require "lua_utils_get"
local host_pools = require "host_pools"
local site_utils = require "site_utils"
local tag_badge_utils = require "tag_badge_utils"

local ifstats = interface.getStats()
local host_ip = h["ip"]
local host_vlan = h["vlan"] or 0
local is_localhost = h["localhost"]
local is_pro = ntop.isPro and ntop.isPro()
local is_admin = isAdministrator()

local pools = host_pools:create()
local pool_id = h["host_pool_id"] or pools.DEFAULT_POOL_ID

local ext = {
   is_admin = is_admin,
   is_pro = is_pro,
   is_nedge = (ntop.isnEdge and ntop.isnEdge()) or false,
   is_inline = ifstats.inline or false,
   is_view = ifstats.isView or false,
   is_packet_interface = interface.isPacketInterface(),
   score_enabled = ((ntop.isEnterpriseM and ntop.isEnterpriseM()) or (ntop.isnEdgeEnterprise and ntop.isnEdgeEnterprise())) or false,
   charts_available = areHostTimeseriesEnabled() and is_localhost and not h["is_multicast"] or false,
   pool_id = pool_id,
   pool_name = pools:get_pool_name(pool_id),
   name_for_link = hostinfo2label(h, true),
   resolving = ntop.shouldResolveHost(host_ip) or false,
   notes = getHostNotes({ host = host_ip, vlan = host_vlan }),
   -- Syslog events of the host (page_utils.showSyslog)
   show_syslog = is_admin and hasClickHouseSupport() and (ntop.getPref("ntopng.prefs.menu_entries.experimental_features") == "1"),
}

-- Traffic blocking of inline interfaces (as the old page: a preference per IP)
if ext.is_inline then
   ext.blocked = (ntop.getHashCache("ntopng.prefs.drop_host_traffic", host_ip) == "true")
end

-- The MAC (symbolic name) and its device, when meaningful
if h["mac"] and h["mac"] ~= "00:00:00:00:00:00" then
   ext.mac_label = get_symbolic_mac(h["mac"], true)
   local mac_info = interface.getMacInfo(h["mac"])
   if mac_info then ext.mac_devtype = mac_info.devtype end
end
if h.router then ext.router_label = get_symbolic_mac(h.router, true) end

-- The interface (of this machine) of the iface_index, as printInterfaceIndex
local idx = tostring(h.iface_index or "")
if idx ~= "" and idx ~= "0" then
   local basedir = "/sys/class/net"
   for k in pairs(ntop.readdir(basedir) or {}) do
      local f = io.open(basedir .. "/" .. k .. "/ifindex", "r")
      if f then
         local v = f:read("*l")
         f:close()
         if v == idx then
            ext.iface_name = k
            break
         end
      end
   end
end

if h["local_network_name"] then
   local alias = getLocalNetworkAlias(h["local_network_name"])
   if not isEmptyString(alias) and alias ~= h["local_network_name"] then ext.network_alias = alias end
   local site = site_utils.getNetworkSite(h["local_network_id"])
   ext.site_name = site and site.name
end

if (h["vlan"] or 0) > 0 then
   ext.vlan_name = getFullVlanName(h["vlan"])
end

-- Host tags set on the host (built-in tags: bits 0-31, user tags: bits 32-63)
local tags_bitmap = interface.getHostTags(host_ip)
if tags_bitmap and tags_bitmap ~= 0 then
   local tags = {}
   for _, t in ipairs(tag_badge_utils.getTags(true --[[ no i18n ]])) do
      if math.floor(tags_bitmap / (2 ^ t.id)) % 2 ~= 0 then
         tags[#tags + 1] = { id = t.id, name = t.name, name_i18n = t.name_i18n, color = t.color }
      end
   end
   ext.tags = tags
end

-- The asset of the host (inventory), by IP and VLAN
if is_localhost and assetsInventoryEnabled() then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   ext.asset_serial_key = require("asset_utils").getHostAssetKey(interface.getId(), host_ip, host_vlan)
end

-- Active monitoring (ICMP): whether the host is monitored and its last RTT. ntop.isPingAvailable() is
-- the setup of the icmp measurement (am_utils.isMeasurementAvailable loads all the measurement scripts)
if ntop.isPingAvailable() then
   local am_utils = require "am_utils"
   local measurement = isIPv6(host_ip) and "icmp6" or "icmp"
   local auth = require "auth"
   local am = { measurement = measurement, monitored = am_utils.hasHost(host_ip, measurement),
      can_edit = auth.has_capability(auth.capabilities.active_monitoring) }
   if am.monitored then
      local last = am_utils.getLastAmUpdate(host_ip, measurement)
      am.last_rtt = last and last.value
   end
   ext.active_monitoring = am
end

-- The SNMP devices where the MAC of the host was seen (the SNMP location row)
if h["mac"] and ntop.isEnterpriseM and ntop.isEnterpriseM() then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   ext.has_snmp_location = require("snmp_location").host_has_snmp_location(h["mac"]) or false
end

ext.wazuh = (ntop.isEnterpriseL and ntop.isEnterpriseL()) and hasClickHouseSupport() and isWazuhEnabled() and is_localhost or false

-- Further names of the host, the same name from more sources collapsed in one row
local names = {}
local by_name = {}
for source, name in pairs(h["names"] or {}) do
   if by_name[name] then
      by_name[name].sources[#by_name[name].sources + 1] = source
   else
      by_name[name] = { name = name, sources = { source } }
      names[#names + 1] = by_name[name]
   end
end
for _, n in ipairs(names) do table.sort(n.sources) end
table.sort(names, function(a, b) return a.name < b.name end)
ext.names = names

-- Downloads: the host JSON, a live pcap (packet interfaces only, not on views and sub-interfaces)
ext.live_capture = ntop.isPcapDownloadAllowed() and not ifstats.isView and not interface.isSubInterface()
   and interface.isPacketInterface() or false

-- Drop the host traffic / its active flows (inline interfaces, administrators)
ext.can_drop_traffic = is_admin and ext.is_inline and is_localhost and not h["is_multicast"] and not h["is_broadcast"] or false

rest_utils.answer(rest_utils.consts.success.ok, { host = host, ext = ext })
