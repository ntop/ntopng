--
-- (C) 2013-23 - ntop.org
--

--
-- Dump vulnerability scan timeseries
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/?.lua;" .. package.path

local ts_utils = require "ts_utils"

-- ########################################################

local when = os.time()

-- TODO
local num_scans      = 1 -- counter
local num_hosts      = 1 -- gauge
local num_open_ports = 1 -- gauge
local num_cve        = 1 -- gauge

ts_utils.append("am_vuln_scan:num_scans",            { ifid = -1, num_scans = num_scans }, when)
ts_utils.append("am_vuln_scan:num_configured_hosts", { ifid = -1, num_hosts = num_hosts }, when)
ts_utils.append("am_vuln_scan:num_open_ports",       { ifid = -1, num_open_ports = num_open_ports }, when)
ts_utils.append("am_vuln_scan:num_cve",              { ifid = -1, num_cve = num_cve }, when)
 
