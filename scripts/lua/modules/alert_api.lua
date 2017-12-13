--
-- (C) 2014-17 - ntop.org
--
--[[
This file contains an API the programmer can use to generate custom alerts

ntopng alerts are a very generic concept that are represented using lua tables.
The only two mandatory keys that must exist in every alert lua table are 'alert_level'
and 'alert_type', respectively. The remaining keys are custom and a user can choose
to save as many fields as he/she wish.

'alert_type' must be an integer number that uniquely identifies the alert type.
This integer number can be obtained using the helper function alertType as follows:

alertType("tcp_syn_flood"))
alertType("flows_flood"))

'alert_severity' must be an integer number that uniquely identifies the alert severity.
This integer number can be obtained using the helper function alertSeverity as follows:

Alerts are fired using function fire_alert that takes the interface id as the first argument
and the alert lua table as the second argument.

alertSeverity("info")
alertSeverity("warning")
alertSeverity("error")


Examples of alerts generation are:
--]]

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

if (ntop.isPro()) then
  package.path = dirs.installdir .. "/pro/scripts/callbacks/?.lua;" .. package.path
end

require "lua_utils"

function fire_alert(ifid, alert)
   ntop.storeAlert(ifid, alert)
end

--fire_alert(0, {['ifid']=0, ['alert_type']=2, ['alert_severity']=1, ['seen']=os.time(), ['msg']="simone"})
--tprint(alertSeverity("warning"))

