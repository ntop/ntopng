--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "http_lint"
local rest_utils = require "rest_utils"

-- ?ifid= selects the interface; interface.select silently falls back to an allowed one: check it
local ifid = _GET["ifid"]
if not isEmptyString(ifid) then
   interface.select(tostring(ifid))
   if tostring(interface.getId()) ~= tostring(ifid) then
      rest_utils.answer(rest_utils.consts.err.invalid_interface)
      return
   end
end

-- Sorted and paged by the table (paging disabled in countries_stats.json)
local countries_stats = interface.getCountriesInfo({ detailsLevel = "higher" })
local countries = countries_stats and countries_stats["Countries"] or {}
local data = {}

for _, country in pairs(countries) do
   local sent = country["bytes.sent"] or 0
   local rcvd = country["bytes.rcvd"] or 0

   data[#data + 1] = {
      name = country["country"],
      hosts = country["num_hosts"] or 0,
      -- Epoch of the first packet
      seen_since = country["seen.first"],
      score = country["score"] or 0,
      bytes_sent = sent,
      bytes_rcvd = rcvd,
      throughput = country["throughput_bps"] or 0,
      traffic = sent + rcvd,
   }
end

rest_utils.extended_answer(rest_utils.consts.success.ok, data, {
   recordsTotal = #data,
   recordsFiltered = #data,
})
