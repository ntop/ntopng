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

if not isAdministrator() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

local post_data = _POST or {}
local tags = post_data["tags"]

-- The fields not sent are left untouched (e.g. a rename from the tags field of a form sends only tag_name)
if tags then
    -- A new name must not be the one of another tag (the existing duplicates can still be edited)
    local current_names = {}
    for _, tag in ipairs(tag_badge_utils.getTags()) do
        current_names[tonumber(tag.id)] = tag.name
    end

    for _, t in pairs(tags) do
        if t.tag_name and t.tag_name ~= current_names[tonumber(t.tag_id)]
            and tag_badge_utils.isTagNameUsed(t.tag_name, t.tag_id) then
            rest_utils.answer(rest_utils.consts.err.tag_already_existing)
            return
        end
    end

    for index, t in pairs(tags) do
        local reserved = tag_badge_utils.isReservedTag(t.tag_id)
        tag_badge_utils.editTag(t.tag_id, t.tag_name, t.color, t.description, tostring(reserved), t.tag_protocols, t.tag_risks, t.tag_ttl)
    end
end

rest_utils.answer(rest_utils.consts.success.ok)
