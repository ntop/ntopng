--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

require "lua_utils"
local host_alert_store = require("host_alert_store").new()

sendHTTPContentTypeHeader('text/plain')

assert(host_alert_store:add_host_filter("192.168.2.1"))
assert(host_alert_store:add_vlan_filter(0))
assert(host_alert_store:add_time_filter(os.time() - 60, os.time()))
assert(host_alert_store:add_limit(20, 60))

assert(not host_alert_store:add_host_filter("foobar"))
assert(not host_alert_store:add_vlan_filter("foobar"))

local res = host_alert_store:select("count(*)")

print("OK")

