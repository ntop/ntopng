--
-- (C) 2013-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.patho

local alert_rest_utils = require "alert_rest_utils"


alert_rest_utils.exclude_alert()
