--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local alert_rest_utils = require "alert_rest_utils"

alert_rest_utils.delete_alert_exclusions("flow", _POST["alert_addr"], _POST["alert_key"])
