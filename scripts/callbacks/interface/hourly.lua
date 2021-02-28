--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if (ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/interface/?.lua;" .. package.path
  require('hourly')
end

-- ########################################################

local k = string.format("ntopng.cache.ifid_%i.user_scripts.request.granularity_hourly", interface.getId())
ntop.setCache(k, "1")
