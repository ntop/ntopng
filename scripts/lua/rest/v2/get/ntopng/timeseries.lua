--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local rest_utils    = require "rest_utils"
local auth          = require "auth"
local ts_info       = require "timeseries_info"

--
-- Returns the community timeseries schema definitions.
-- Example: curl -u admin:admin http://localhost:3000/lua/rest/v2/get/ntopng/timeseries.lua
--

-- Developer pages (Developer > Catalog): users with the developer capability
if not auth.has_capability(auth.capabilities.developer) then
   rest_utils.answer(rest_utils.consts.err.not_granted)
   return
end

local res = ts_info.getAllTimeseries()

rest_utils.answer(rest_utils.consts.success.ok, res)
