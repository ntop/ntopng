--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

if (ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/interface/?.lua;" .. package.path
  require('hourly')
end

local alert_store_utils = require "alert_store_utils"

-- ########################################################

local k = string.format("ntopng.cache.ifid_%i.checks.request.granularity_hourly", interface.getId())
ntop.setCache(k, "1")

-- ########################################################

-- Alerts DB housekeeping (cleanup)
alert_store_utils.housekeeping()

