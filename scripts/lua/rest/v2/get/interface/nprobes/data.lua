--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local rest_utils = require("rest_utils")

--
-- Read information about the nprobes connected to an interface
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/get/interfacenprobes/data.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)
local ifstats = interface.getStats()

for k, v in pairs(ifstats.probes or {}) do
   local nprobe_interface = i18n("if_stats_overview.remote_probe_collector_mode")

   if v["remote.name"] ~= "none" then
      nprobe_interface = string.format("%s [%s]", v["remote.name"], bitsToSize(v["remote.ifspeed"]*1000000))
   end

   local nprobe_version = v["probe.probe_version"]

   if not isEmptyString(v["probe.probe_os"]) then
      nprobe_version = string.format("%s (%s)", nprobe_version, v["probe.probe_os"])
   end

   local nprobe_probe_ip = ip2detailshref(v["probe.ip"], 0, nil, v["probe.ip"], nil, true)
   local nprobe_probe_public_ip

   if not isEmptyString(v["probe.public_ip"]) then
      nprobe_probe_public_ip = ip2detailshref(v["probe.public_ip"], 0, nil, v["probe.public_ip"], nil, true)
   end

   local nprobe_edition = v["probe.probe_edition"]
   local nprobe_license = v["probe.probe_license"] or i18n("if_stats_overview.no_license")
   local nprobe_maintenance = v["probe.probe_maintenance"] or i18n("if_stats_overview.expired_maintenance")

   local record = {
      column_nprobe_interface = nprobe_interface,
      column_nprobe_version = nprobe_version,
      column_nprobe_edition = nprobe_edition,
      column_nprobe_license = nprobe_license,
      column_nprobe_maintenance = nprobe_maintenance,
      column_nprobe_probe_ip = nprobe_probe_ip,
      column_nprobe_probe_public_ip = nprobe_probe_public_ip,
   }



   res[#res + 1] = record
end

rest_utils.answer(rc, res)
