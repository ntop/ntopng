--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local ts_dump = require "ts_min_dump_utils"
local am_utils = require  "am_utils"

local hosts = am_utils.getHosts(nil, "hour")
am_utils.run_am_check(os.time(), hosts, "hour")
