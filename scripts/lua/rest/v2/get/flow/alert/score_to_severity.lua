
--
-- (C) 2025 - ntop.org
--
local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "http_lint"
local am_utils = require "am_utils"
local auth = require "auth"
local rest_utils = require "rest_utils"
local alert_consts = require "alert_consts"

-- ################################################
-- This REST converts a score to the severity label associated

local score = _GET["score"]

if isEmptyString(score) then
    rest_utils.answer(rest_utils.consts.err.missing_parameters, {"Please provide a score value to convert to severity"})
end

local severity_label = alert_consts.alertSeverityLabel(tonumber(score), true) -- true to remove html and only get severity label

local res = { 
    ["severityLabel"] = severity_label
}

rest_utils.answer(rest_utils.consts.success.ok, res)