--
-- (C) 2026 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/active_scan/?.lua;" .. package.path

--
-- Context of the Active Scan SPA views (page-active-scan-route.vue, page-host-vs-result.vue):
-- the data the old active_scan.lua / active_scan_report.lua computed server side.
-- Only raw values: the titles are built by the page. Internal (page UI flow), not documented.
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/active_scan/page_context.lua?ifid=0&host=192.168.1.1"
--

-- http_lint (validates _GET) + the light modules of rest_utils, not the whole lua_utils
require "http_lint"
local rest_utils = require "rest_utils"
local json = require "dkjson"
local ascan_status_utils = require "ascan_status_utils"

-- Same access as the active scan REST: administrators only
if not isAdministrator() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local ifid = _GET["ifid"]
local host = _GET["host"]
local epoch_end = tonumber(_GET["epoch_end"])

if not isEmptyString(ifid) then
   interface.select(ifid)
   if tostring(interface.getId()) ~= tostring(ifid) then
      rest_utils.answer(rest_utils.consts.err.invalid_interface)
      return
   end
end

local res = {
   nmap_installed = (ascan_status_utils.get_nmap_binary() ~= nil),
   is_clickhouse_enabled = ntop.isClickHouseEnabled(),
}

-- Scan result of a host: link to the host page only when the host is in memory
if not isEmptyString(host) then
   res.is_in_mem = (interface.getHostInfo(host) ~= nil)
end

if epoch_end then
   -- A stored report (ClickHouse): its name. ascan_db_utils loads lua_utils, only here
   if res.is_clickhouse_enabled then
      local ascan_db_utils = require "ascan_db_utils"
      res.report_name = ascan_db_utils.retrieve_report_name(epoch_end)
   end
else
   -- The last report (no ClickHouse): the time range of the last periodic scan
   -- (ascan_utils.get_scan_all_dates, read here not to load ascan_utils)
   local dates = ntop.getCache("ntopng.vs.report_dates")
   if not isEmptyString(dates) then
      dates = json.decode(dates)
      if dates then
         res.start_date = dates.start_date
         res.end_date = dates.end_date
      end
   end
end

rest_utils.answer(rest_utils.consts.success.ok, res)
