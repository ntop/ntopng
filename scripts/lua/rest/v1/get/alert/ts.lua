--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local alert_utils = require "alert_utils"
require "flow_utils"
local alert_consts = require "alert_consts"
local format_utils = require "format_utils"
local json = require "dkjson"
local rest_utils = require("rest_utils")

--
-- Read alerts data as timeseries (number of alerts per hour)
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "6", "status": "historical-flows", "epoch_begin": 1590226522, "epoch_end": 1590485722}' http://localhost:3000/lua/rest/v1/get/alert/ts.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

sendHTTPHeader('application/json')

local rc = rest_utils.consts.success.ok
local res = {}

local ifid = _GET["ifid"]
local what = _GET["status"] -- historical, historical-flows
local epoch_begin = _GET["epoch_begin"]
local epoch_end = _GET["epoch_end"]
local alert_type = _GET["alert_type"]
local alert_severity = _GET["alert_severity"]

if isEmptyString(ifid) then
   rc = rest_utils.consts.err.invalid_interface
   print(rest_utils.rc(rc))
   return
end

interface.select(ifid)

if isEmptyString(what) then
   rc = rest_utils.consts.err.invalid_args
   print(rest_utils.rc(rc))
   return
end

if isEmptyString(epoch_begin) or isEmptyString(epoch_end) then
   rc = rest_utils.consts.err.invalid_args
   print(rest_utils.rc(rc))
   return
end

epoch_begin = tonumber(epoch_begin);
epoch_end = tonumber(epoch_end);

if epoch_end <= epoch_begin then
   rc = rest_utils.consts.err.invalid_args
   print(rest_utils.rc(rc))
   return
end

local hour_secs = 60*60
local day_secs = 60*60*24

-- Round begin to start of day
epoch_begin = epoch_begin - (epoch_begin % day_secs)

-- Round end to end of day
epoch_end = epoch_end - (epoch_end % day_secs) + day_secs

local days = (epoch_end - epoch_begin) / day_secs

local engaged = false
if what == "engaged" then
   engaged = true
end

local counters = alert_utils.getNumAlertsPerHour(what, epoch_begin, epoch_end, alert_type, alert_severity)

if counters == nil then
   rc = rest_utils.consts.err.internal_error
   print(rest_utils.rc(rc)) 
   return
end

for day = 1, days do
   local day_epoch = epoch_begin + ((day - 1) * day_secs)

   res[day_epoch] = {
      0, --[[ Counter for alerts between 00:00 and 00:59 UTC --]]
      0, --[[ Counter for alerts between 01:00 and 01:59 UTC --]]
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 --[[ Counter for alerts in other hours, until 23:00 to 23:59 --]]
   }
end

local curr_epoch = epoch_begin

for k,v in ipairs(counters) do
   -- Midnight UTC of the day containing v.hour
   local day_epoch = v.hour - (v.hour % day_secs)

   -- Hour of the day containing v.hour, from 0 to 23, inclusive
   -- NOTE: Use the `floor` to make sure hour is an integer as it will be used to index a Lua array
   local hour = math.floor((v.hour - day_epoch) / hour_secs) 

   -- Here we add 1 to the hour as Lua array are indexed starting from 1, whereas `hour` is an integer starting from zero
   res[day_epoch][hour + 1] = tonumber(v.count)
end -- for

print(rest_utils.rc(rc, res))

