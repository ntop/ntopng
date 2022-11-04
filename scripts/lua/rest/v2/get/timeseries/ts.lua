--
-- (C) 2013-22 - ntop.org
--

--
-- Example of REST call
-- 
-- curl -u admin:admin -X POST -d '{"ts_schema":"host:traffic", "ts_query": "ifid:3,host:192.168.1.98", "epoch_begin": "1532180495", "epoch_end": "1548839346"}' -H "Content-Type: application/json" "http://127.0.0.1:3000/lua/rest/get/timeseries/ts.lua"
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require("rest_utils")
local ts_rest_utils = require("ts_rest_utils")

local http_context = {
   ts_schema = _GET["ts_schema"],
   epoch_begin    = _GET["epoch_begin"],
   epoch_end      = _GET["epoch_end"],
   ts_compare = _GET["ts_compare"],
   ts_query      = _GET["ts_query"],
   extended  = _GET["extended"],
   ts_aggregation  = _GET["ts_aggregation"],
   no_fill = _GET["no_fill"],
   tskey = _GET["tskey"],
   limit = _GET["limit"],
   initial_point = _GET["initial_point"],
}
-- Epochs in _GET are assumed to be adjusted to UTC. This is always the case when the browser submits epoch using a
-- datetimepicker (e.g., from any chart page).

-- This is what happens for example when drawing a chart from firefox set on three different timezones

-- TZ=UTC firefox.        12 May 2020 11:00:00 -> 1589281200 (sent by browser in _GET)
-- TZ=Europe/Rome.        12 May 2020 11:00:00 -> 1589274000 (sent by browser in _GET)
-- TZ=America/Sao_Paulo   12 May 2020 11:00:00 -> 1589292000 (sent by browser in _GET)

-- Basically, timestamps are adjusted to UTC before being sent in _GET:

-- - 1589274000 (Rome) - 1589281200 (UTC) = -7200: As Rome (CEST) is at +2 from UTC, then UTC is 2 hours ahead Rome
--   - 12 May 2020 11:00:00 in Rome (UTC) is 12 May 2020 09:00:00 UTC (-2)
-- - 1589292000 (Sao Paulo) - 1589281200 (UTC) = +10800: As Sao Paulo is at -3 from UTC, then UTC is 3 hours after UTC
--    - 12 May 2020 11:00:00 in Sao Paolo is 12 May 2020 14:00:00 UTC (+3)

-- As timeseries epochs are always written adjusted to UTC, there is no need to do any extra processing to the received epochs.
-- They are valid from any timezone, provided they are sent in the _GET as UTC adjusted.

local res1 = ts_rest_utils.get_timeseries(http_context)

rest_utils.answer(rest_utils.consts.success.ok, res1)
