--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/vulnerability_scan/?.lua;" .. package.path

require "label_utils"
require "ntop_utils"
require "http_lint"

local rest_utils = require "rest_utils"
local label_badge_utils = require "label_badge_utils"

-- label, color, description
local labels = label_badge_utils.getLabels()
local total_rows = #labels

rest_utils.extended_answer(rest_utils.consts.success.ok, labels, {["recordsTotal"] = total_rows})
