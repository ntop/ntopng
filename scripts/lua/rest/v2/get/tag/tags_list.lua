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

local applications_supported = tag_badge_utils.areTagApplicationsSupported()
local risks_supported = tag_badge_utils.areTagRisksSupported()

-- Resolve the nDPI application ids and the flow risk ids
for _, tag in ipairs(tags) do
    local applications = {}

    if applications_supported then
        for _, appl_id in ipairs(tag.protocols or {}) do
            applications[#applications + 1] = interface.getnDPIProtoName(appl_id) or tostring(appl_id)
        end
    end

    tag.applications = applications

    local flow_risks = {}

    if risks_supported then
        for _, risk_id in ipairs(tag.risks or {}) do
            flow_risks[#flow_risks + 1] = ntop.getRiskStr(risk_id) or tostring(risk_id)
        end
    end

    tag.flow_risks = flow_risks
end

local total_rows = #tags

rest_utils.extended_answer(rest_utils.consts.success.ok, tags, {["recordsTotal"] = total_rows})
