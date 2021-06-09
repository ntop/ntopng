--
-- (C) 2019-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local alert_rest_utils = require "alert_rest_utils"

alert_rest_utils.delete_all_alert_exclusions(_POST["script_subdir"])
