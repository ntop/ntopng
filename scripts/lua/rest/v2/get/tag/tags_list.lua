--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "label_utils"
require "ntop_utils"
require "http_lint"

local rest_utils = require "rest_utils"
local tag_badge_utils = require "tag_badge_utils"

-- tag, color, description
local tags = tag_badge_utils.getTags()
local total_rows = #tags

rest_utils.extended_answer(rest_utils.consts.success.ok, tags, {["recordsTotal"] = total_rows})
