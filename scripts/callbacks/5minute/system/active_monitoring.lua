--
-- (C) 2013-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local ts_dump = require "ts_5min_dump_utils"
local am_utils = require  "am_utils"

local hosts = am_utils.getHosts(nil, "5mins")
am_utils.run_am_check(os.time(), hosts, "5mins")

