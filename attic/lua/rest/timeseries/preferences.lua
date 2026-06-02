--
-- (C) 2013-26 - ntop.org
--

--
-- Read actually date format selected by the user on the user preferences
-- Example: curl -u admin:admin -H "Content-Type: application/json" -d '{"ifid": "1"}' http://localhost:3000/lua/rest/v2/get/timseries/date_format.lua
--
-- NOTE: in case of invalid login, no error is returned but redirected to login
--

local dirs = ntop.getDirs()

package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils = require("rest_utils")
require "check_redis_prefs"

local rsp = {
   highResolutionFlowExportersTimeseries = highExporterTimeseriesResolution()
}

rest_utils.answer(rest_utils.consts.success.ok, rsp)