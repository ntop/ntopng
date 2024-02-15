--
-- (C) 2013-24 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

-- ##################################

local ts_dump = require "ts_5min_dump_utils"

-- ##################################

local when = os.time()

ts_dump.blacklist_update(when)
