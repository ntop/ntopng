--
-- (C) 2013-24 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "ntop_utils"
require "http_lint"
local rest_utils = require "rest_utils"
local lists_utils = require "lists_utils"

local enabled = _POST["list_enabled"]
local list_name = _POST["list_name"]
local category = tonumber(_POST["category"])
local url = _POST["url"]
local list_update = tonumber(_POST["list_update"])

if enabled == "on" then
    enabled = true
else
    enabled = false
end
if isEmptyString(enabled) or isEmptyString(list_name) or isEmptyString(category) or isEmptyString(url) or
    isEmptyString(list_update) then
    rest_utils.answer(rest_utils.consts.err.bad_content)
    return
end

url = string.gsub(url, "http:__", "http://")
url = string.gsub(url, "https:__", "https://")

lists_utils.editList(list_name, {
    enabled = enabled,
    category = nil,
    url = url,
    update_interval = list_update
})

rest_utils.answer(rest_utils.consts.success.ok)
