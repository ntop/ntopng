--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

local auth = require "auth"
local rest_utils = require "rest_utils"
local alert_consts = require "alert_consts"
local all_alert_store = require "all_alert_store".new()

--
-- Read alerts count by time
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/get/alert/list/alerts.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local rc = rest_utils.consts.success.ok
local ifid = _GET["ifid"]

if not auth.has_capability(auth.capabilities.alerts) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   rest_utils.answer(rc)
   return
end

interface.select(ifid)

local alert_family  = _GET["alert_family"] -- "active_monitoring", "flow", "host", "interface", "mac" , "network" , "snmp" , "system" , "user"
local epoch_begin   = _GET["epoch_begin"]
local epoch_end     = _GET["epoch_end"]
local select_clause = _GET["select_clause"] or "*"
local where_clause  = _GET["where_clause"]
local maxhits       = _GET["maxhits_clause"] or 10
local group_by      = _GET["group_by"]
local order_by      = _GET["order_by"]

local table_name

if(alert_family == "flow") then
   if(ntop.isClickHouseEnabled()) then
      table_name = "flow_alerts_view"
   else
      table_name = "flow_alerts"
   end
elseif(alert_family == "host") then
   table_name = "host_alerts"
elseif(alert_family == "interface") then
   table_name = "interface_alerts"
elseif(alert_family == "mac") then
   table_name = "mac_alerts"
elseif(alert_family == "network") then
   table_name = "network_alerts"
elseif(alert_family == "snmp") then
   table_name = "snmp_alerts"
elseif(alert_family == "system") then
   table_name = "system_alerts"
elseif(alert_family == "user") then
   table_name = "user_alerts"
elseif(alert_family == "active_monitoring") then
   table_name = "active_monitoring_alerts"
else
   rc = rest_utils.consts.err.invalid_args
   rest_utils.answer(rc)
   return
end

if isEmptyString(epoch_begin) or isEmptyString(epoch_end) then
   rc = rest_utils.consts.err.invalid_args
   rest_utils.answer(rc)
   return
end

local sql = "SELECT " .. select_clause .. " FROM " .. table_name

sql = sql .. " WHERE (tstamp >= "..epoch_begin..") AND (tstamp_end <= "..epoch_end..") AND (interface_id == " .. ifid .. ")"

if not isEmptyString(where_clause) then
   sql = sql .. " AND (" .. where_clause .. ")"
end

if not isEmptyString(group_by) then
   sql = sql .. " GROUP BY " .. group_by
end

if not isEmptyString(order_by) then
   sql = sql .. " ORDER BY " .. order_by
end

sql = sql .. " LIMIT "..maxhits

res = interface.alert_store_query(sql)

rest_utils.answer(rc, res)
