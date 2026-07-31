--
-- (C) 2013-26 - ntop.org
--
-- Single-call health summary for external fleet-monitoring tools (e.g. the
-- ntopng Companion Chrome extension). Wraps interface/data.lua's per-interface
-- stats plus a deterministic status color/label, so a caller gets everything
-- needed for a status dot in one round trip.
--
-- Params:
--   ifid          - single interface id (default: default interface / "all" below)
--   iffilter=all  - return one entry per monitored interface, keyed by ifid
--
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/ntopng/health.lua?iffilter=all
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")
local auth = require "auth"

local rc = rest_utils.consts.success.ok

local ifid = _GET["ifid"]
local iffilter = _GET["iffilter"]

if isEmptyString(ifid) and iffilter ~= "all" then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

local function getStatus(ifstats)
   if ifstats == nil then
      return "grey", "Unreachable or invalid interface"
   end

   local errors = ifstats.engaged_alerts_error or 0
   local warnings = ifstats.engaged_alerts_warning or 0

   if errors > 0 then
      return "red", errors .. " engaged error-level alert(s)"
   end

   if warnings > 0 then
      return "yellow", warnings .. " engaged warning-level alert(s)"
   end

   return "green", "Healthy"
end

local function getInterfaceHealth(cur_ifid, cur_ifname)
   interface.select(cur_ifname)
   local ifstats = interface.getStats()

   if ifstats == nil then
      return nil
   end

   local ingress_thpt = ifstats["eth"]["ingress"]["throughput"]
   local egress_thpt = ifstats["eth"]["egress"]["throughput"]

   local function bps_or_fallback(thpt, fallback_bytes)
      if thpt ~= nil and thpt["bps"] ~= nil then
         return thpt["bps"] * 8
      end
      return fallback_bytes or 0
   end

   local res = {
      ifid = tonumber(cur_ifid),
      ifname = getInterfaceName(cur_ifid),
      uptime_sec = ntop.getUptime(),
      uptime = secondsToTime(ntop.getUptime()),
      num_flows = ifstats.stats.flows,
      num_local_hosts = ifstats.stats.local_hosts,
      num_hosts = ifstats.stats.hosts,
      throughput = {
         download = { bps = bps_or_fallback(ingress_thpt, ifstats["eth"]["ingress"]["bytes"]) },
         upload = { bps = bps_or_fallback(egress_thpt, ifstats["eth"]["egress"]["bytes"]) }
      },
      -- A view interface (e.g. "view:enp1s0,tcp://*:1234") already
      -- aggregates its underlying member interfaces' flows/hosts/traffic;
      -- callers summing across "all" must count the view once and skip
      -- its members, not sum both, or totals inflate. is_viewed marks a
      -- member interface backing at least one view.
      is_view = ifstats.isView or false,
      is_viewed = ifstats.isViewed or false
   }

   if auth.has_capability(auth.capabilities.alerts) then
      res.alerted_flows = ifstats["num_alerted_flows"] or 0
      res.has_alerts = (res.alerted_flows > 0)
      -- Same fields ntopng's own dashboard-table.vue reads for its
      -- red/yellow/green badges (engaged_alerts_error/_warning).
      res.engaged_alerts = ifstats["num_alerts_engaged"] or 0
      local by_sev = ifstats["num_alerts_engaged_by_severity"] or {}
      res.engaged_alerts_error = (by_sev["error"] or 0) + (by_sev["critical"] or 0) +
         (by_sev["emergency"] or 0)
      res.engaged_alerts_warning = by_sev["warning"] or 0
   else
      res.alerted_flows = 0
      res.has_alerts = false
      res.engaged_alerts = 0
      res.engaged_alerts_error = 0
      res.engaged_alerts_warning = 0
   end

   local status, label = getStatus(res)
   res.status = status
   res.status_label = label

   return res
end

local res = {}

if iffilter == "all" then
   for cur_ifid, cur_ifname in pairs(interface.getIfNames()) do
      res[cur_ifid .. ""] = getInterfaceHealth(cur_ifid, cur_ifname)
   end
else
   local ifstats = getInterfaceHealth(ifid, getInterfaceName(ifid))
   if ifstats == nil then
      rest_utils.answer(rest_utils.consts.err.invalid_interface)
      return
   end
   res = ifstats
end

rest_utils.answer(rc, res)
