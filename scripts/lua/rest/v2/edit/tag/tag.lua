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
local tags = post_data["tags"]

if tags then
    for index, t in pairs(tags) do
        tag_badge_utils.editTag(t.tag_id, t.tag_name, t.color, t.description, false)
    end
end

rest_utils.answer(rest_utils.consts.success.ok)
