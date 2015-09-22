--
-- (C) 2013-15 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"

-- ifname variable is already available via lua_utils
ifid = _GET['ifid']
rrdFile = _GET['rrdFile']
host = _GET['host']
start_time = _GET['start_time']
end_time = _GET['end_time']

sendHTTPHeader('application/json')
print(rrd2json(ifid, host, rrdFile, start_time, end_time))
