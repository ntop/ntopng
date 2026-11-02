--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "http_lint"
local rest_utils = require "rest_utils"
local as_utils = require "as_utils"

--
-- Context of the AS overview page (as_overview.lua?asn=, PageAsOverviewRoute) and of the exporter
-- interface overview (PageExporterRoute): the ASN configuration
-- (customer, sub-customer, remote) and the first epoch of the ClickHouse ASN data. Internal (page UI)
-- Example: curl -u admin:admin "http://localhost:3000/lua/rest/v2/get/asn/page_context.lua?ifid=1&asn=3"
--

-- ?ifid= selects the interface; interface.select silently falls back to an allowed one: check it
local ifid = _GET["ifid"]
if not isEmptyString(ifid) then
   interface.select(tostring(ifid))
   if tostring(interface.getId()) ~= tostring(ifid) then
      rest_utils.answer(rest_utils.consts.err.invalid_interface)
      return
   end
end

-- Optional: without it only the ClickHouse fields (e.g. the exporter interface overview)
local asn = tonumber(_GET["asn"])

local has_clickhouse = ntop.isClickHouseEnabled()
local first_seen = 0

if has_clickhouse then
   -- min() instead of ORDER BY ... LIMIT 1: no sort of the whole table
   local res = interface.execSQLQuery("SELECT min(FIRST_SEEN) AS first_seen FROM hourly_asn")
   if type(res) == "table" and res[1] then
      first_seen = tonumber(res[1]["first_seen"]) or 0
   end
end

rest_utils.answer(rest_utils.consts.success.ok, {
   configuration = asn and as_utils.getASNConfiguration(tostring(asn)) or nil,
   has_clickhouse = has_clickhouse,
   first_date_epoch = first_seen,
})
