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

local post_data = _POST or {}
local label_id = post_data["label_id"]

label_badge_utils.deleteLabel(label_id)

rest_utils.answer(rest_utils.consts.success.ok)