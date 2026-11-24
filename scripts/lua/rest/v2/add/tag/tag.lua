--
-- (C) 2013-26 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "string_utils"
require "http_lint"

local rest_utils = require "rest_utils"
local tag_badge_utils = require "tag_badge_utils"

-- Creates a user-defined tag (e.g. from the tags field of a form) and returns it
-- POST tag_name, color, tag_ids (the tags selected in the form and not saved yet: not reused)

if not isAdministrator() then
    rest_utils.answer(rest_utils.consts.err.not_granted)
    return
end

local name = trimString(_POST["tag_name"] or "")
local color = _POST["color"]

if name == "" or isEmptyString(color) then
    rest_utils.answer(rest_utils.consts.err.invalid_args)
    return
end

if tag_badge_utils.isTagNameUsed(name) then
    rest_utils.answer(rest_utils.consts.err.tag_already_existing)
    return
end

local id = tag_badge_utils.addTag(name, color, split(_POST["tag_ids"] or "", ","))

if id == nil then
    rest_utils.answer(rest_utils.consts.err.no_free_tags)
    return
end

rest_utils.answer(rest_utils.consts.success.ok, { id = id, name = name, color = color })
