--
-- (C) 2019-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "label_utils" -- getHumanReadableInterfaceName()
local rest_utils = require("rest_utils")

-- ################################################

-- Redis lists used as queues: a producer pushes the entries, a consumer pops
-- them. key: the Redis key (%d: interface id); max_len: the length the
-- producer trims the list to at every push (nil: not limited), dropping
-- entries when the queue is full: the newest or the oldest ones, depending on
-- how the producer pushes (see Redis::msg_push); is_available: the edition
-- with the producer (nil: all).
-- NOTE: keep the keys and the lengths in sync with the producers

-- A queue per interface
local INTERFACE_QUEUES = {
   -- OFFLINE_LOCAL_HOSTS_MACS_QUEUE_NAME, CONST_MAX_INACTIVE_HOSTS_MAC_QUEUE_LEN (ntop_defines.h)
   { label_i18n = "system_stats.redis.queues.assets", key = "ntopng.assets_hosts_macs.queue.ifid_%d", max_len = 32768,
     is_available = ntop.isEnterpriseM },
   -- DHCP_STORM_QUEUE_NAME (ntop_defines.h), NetworkInterface::checkDHCPStorm
   { label_i18n = "system_stats.redis.queues.dhcp_storm", key = "ntopng.dhcp.storm.%d", max_len = 32, is_available = ntop.isPro },
   -- Host::enqueueAlertToRecipients (interface pushing the host filters to PF_RING)
   { label_i18n = "system_stats.redis.queues.pfring_filter", key = "pfring.%d.filter.host.queue", max_len = 1024 },
}

-- Queues of the system
local SYSTEM_QUEUES = {
   -- snmp_dev_bridge.lua
   { label_i18n = "system_stats.redis.queues.snmp_assets", key = "ntopng.assets_hosts_macs.queue.ifid_255",
     is_available = ntop.isEnterpriseM },
   -- BGP_PREFIX_UPDATE_QUEUE_NAME (ntop_defines.h), BGPPrefixListener
   { label_i18n = "system_stats.redis.queues.bgp_updates", key = "ntopng.bgp.queue.updates", max_len = 100 },
   -- DROP_TMP_ADD_HOST_LIST (ntop_defines.h), DangerousHost
   { label_i18n = "system_stats.redis.queues.hosts_to_jail", key = "ntopng.cache.tmp_add_host_list" },
   -- drop_host_pool_utils.lua (ids_ips_jail_add_key, ids_ips_jail_remove_key, max_ids_ips_log_queue_len)
   { label_i18n = "system_stats.redis.queues.jail_add_log", key = "ntopng.cache.ids_ips_jail_add", max_len = 256 },
   { label_i18n = "system_stats.redis.queues.jail_remove_log", key = "ntopng.cache.ids_ips_jail_remove", max_len = 256 },
   -- recording_utils.lua
   { label_i18n = "system_stats.redis.queues.extractions", key = "ntopng.traffic_recording.extraction_queue" },
   { label_i18n = "system_stats.redis.queues.extractions_stop", key = "ntopng.traffic_recording.extraction_stop_queue" },
   -- ascan_utils.lua
   { label_i18n = "system_stats.redis.queues.active_scans", key = "ntopng.vs.scan_queue" },
   { label_i18n = "system_stats.redis.queues.scanned_hosts_changes", key = "ntopng.alerts.scanned_hosts_changes" },
}

-- ################################################

-- -1: the system interface (Health > Redis)
if not ntop.isAllowedInterface(-1) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local res = {}

-- The length and the fill level of the queues of an interface (iface_name:
-- nil for the system, the page shows its label)
local function addQueues(queues, ifid, iface_name)
   for _, queue in ipairs(queues) do
      if (queue.is_available == nil) or queue.is_available() then
         local key = string.format(queue.key, ifid)
         local length = ntop.llenCache(key) or 0

         res[#res + 1] = {
            ifid       = ifid,
            iface_name = iface_name,
            queue_i18n = queue.label_i18n,
            redis_key  = key,
            length     = length,
            max_length = queue.max_len,
            fill_pct   = queue.max_len and (length * 100 / queue.max_len),
         }
      end
   end
end

for ifid, ifname in pairs(interface.getIfNames()) do
   addQueues(INTERFACE_QUEUES, tonumber(ifid), getHumanReadableInterfaceName(ifname))
end

addQueues(SYSTEM_QUEUES, tonumber(getSystemInterfaceId()))

-- ################################################

rest_utils.extended_answer(rest_utils.consts.success.ok, res, {
   recordsTotal    = #res,
   recordsFiltered = #res,
})
