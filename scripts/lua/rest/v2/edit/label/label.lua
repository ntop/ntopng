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
local labels = post_data["labels"]

if labels then
    for index, l in pairs(labels) do
        label_badge_utils.editLabel(l.old_name, l.name, l.color, l.description)
    end
end

rest_utils.answer(rest_utils.consts.success.ok)