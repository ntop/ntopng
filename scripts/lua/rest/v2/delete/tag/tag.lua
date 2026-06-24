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

local post_data = _POST or {}
local tag_id = post_data["tag_id"]

tag_badge_utils.deleteTag(tag_id)

rest_utils.answer(rest_utils.consts.success.ok)
