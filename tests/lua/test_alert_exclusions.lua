--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local alert_exclusions = require "alert_exclusions"
local alert_consts = require "alert_consts"

-- Cleanup
alert_exclusions.cleanup()

-- ##############################################

-- Invalid params 
local res = alert_exclusions.disable_alert("invalid_ip", 12)
assert(res == false)

local res = alert_exclusions.disable_alert("192.168.2.222", 999999999999)
assert(res == false)

-- ##############################################

-- Valid params

local a_disabled_alert = alert_consts.alert_types.alert_data_exfiltration.meta.alert_key
local another_disabled_alert = alert_consts.alert_types.alert_dns_invalid_query.meta.alert_key
local yet_another_disabled_alert = alert_consts.alert_types.alert_suspicious_tcp_probing.meta.alert_key

local res = alert_exclusions.disable_alert("192.168.2.222", a_disabled_alert)
assert(res)

assert(alert_exclusions.has_disabled_alert("192.168.2.222", a_disabled_alert))
assert(alert_exclusions.has_disabled_alert("192.168.2.222", another_disabled_alert) == false)
assert(alert_exclusions.has_disabled_alert("192.168.2.222", yet_another_disabled_alert) == false)

-- ##############################################

-- Valid params for another host

local res = alert_exclusions.disable_alert("192.168.2.225", a_disabled_alert)
assert(res)

local res = alert_exclusions.disable_alert("192.168.2.225", another_disabled_alert)
assert(res)

assert(alert_exclusions.has_disabled_alert("192.168.2.225", a_disabled_alert))
assert(alert_exclusions.has_disabled_alert("192.168.2.225", another_disabled_alert))
assert(alert_exclusions.has_disabled_alert("192.168.2.225", yet_another_disabled_alert) == false)

-- ##############################################

-- Cleanup
alert_exclusions.cleanup()

assert(alert_exclusions.has_disabled_alert("192.168.2.222", a_disabled_alert) == false)
assert(alert_exclusions.has_disabled_alert("192.168.2.222", another_disabled_alert) == false)
assert(alert_exclusions.has_disabled_alert("192.168.2.222", yet_another_disabled_alert) == false)
assert(alert_exclusions.has_disabled_alert("192.168.2.225", a_disabled_alert) == false)
assert(alert_exclusions.has_disabled_alert("192.168.2.225", another_disabled_alert) == false)
assert(alert_exclusions.has_disabled_alert("192.168.2.225", yet_another_disabled_alert) == false)

print("OK\n")

