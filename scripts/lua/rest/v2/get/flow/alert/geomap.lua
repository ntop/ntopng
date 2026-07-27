--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local auth = require "auth"
local rest_utils = require "rest_utils"
local flow_alert_store = require "flow_alert_store".new()

--
-- Per-host geolocated alert aggregation for flow alerts, powering the SOC
-- alerts heatmap. Reuses the same URL filters (time range, severity, status,
-- etc.) as the flow alert explorer table. Aggregates both the client and the
-- server side of each alerted flow.
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/flow/alert/geomap.lua?ifid=0&epoch_begin=..&epoch_end=..
--

local ifid = _GET["ifid"]

if not auth.has_capability(auth.capabilities.alerts) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

if not ntop.hasGeoIP or not ntop.hasGeoIP() then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

if isEmptyString(ifid) then
   rest_utils.answer(rest_utils.consts.err.invalid_interface)
   return
end

if not ntop.isClickHouseEnabled() then
   rest_utils.answer(rest_utils.consts.err.internal_error)
   return
end

interface.select(ifid)

flow_alert_store:add_request_filters()
local where_clause = flow_alert_store:build_where_clause()
local table_name = flow_alert_store:get_table_name()

local q = string.format(
   "SELECT ip, vlan_id, any(country) AS country, sum(score) AS total_score, count(*) AS alerts_count FROM (" ..
      "SELECT cli_ip AS ip, vlan_id, cli_country AS country, score FROM %s WHERE %s AND cli_country != '' " ..
      "UNION ALL " ..
      "SELECT srv_ip AS ip, vlan_id, srv_country AS country, score FROM %s WHERE %s AND srv_country != '' " ..
   ") GROUP BY ip, vlan_id ORDER BY total_score DESC LIMIT 512",
   table_name, where_clause, table_name, where_clause)

local q_res = interface.alert_store_query(q) or {}

local hosts = {}
local country_totals = {}

for _, row in ipairs(q_res) do
   local country = row.country -- ISO alpha-2, e.g. "IT"
   if not isEmptyString(country) then
      local alerts_count = tonumber(row.alerts_count) or 0
      local total_score = tonumber(row.total_score) or 0

      hosts[#hosts + 1] = {
         ip = row.ip,
         vlan_id = tonumber(row.vlan_id) or 0,
         country = country,
         alerts_count = alerts_count,
         total_score = total_score
      }

      -- Aggregate by country too, for the geomap.vue countryHeatmap mode
      country_totals[country] = country_totals[country] or { alerts_count = 0, total_score = 0 }
      country_totals[country].alerts_count = country_totals[country].alerts_count + alerts_count
      country_totals[country].total_score = country_totals[country].total_score + total_score
   end
end

local countries = {}
for country, totals in pairsByKeys(country_totals, asc) do
   countries[#countries + 1] = {
      country = country,
      value = totals.total_score,
      alerts_count = totals.alerts_count,
      total_score = totals.total_score
   }
end

rest_utils.answer(rest_utils.consts.success.ok, {
   hosts = hosts,
   countries = countries
})
