--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local alert_rest_utils = require "alert_rest_utils"

if isAdministratorOrPrintErr(true) then
   alert_rest_utils.exclude_alert()
end
