--
-- (C) 2019-24 - ntop.org
--
local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local alert_categories = require "alert_categories"

local script = {
    -- Script category
    category = alert_categories.internals,
    severity = alert_consts.get_printable_severities().critical,

    -- See below
    hooks = {},

    gui = {
        i18n_title = "internals.system_alert_drops",
        i18n_description = "internals.system_alert_drops_descr"
    }
}

local EXPORTERS_LIMITS_EXCEEDED_KEY = "ntopng.limits.exporters"

-- #################################################################

local function dropped_flows_check(params)
    -- Fetch if an interface dropped some flows due to limits exceeded regarding flow exporters
    local exporters_limit_exceeded = ntop.getCache(EXPORTERS_LIMITS_EXCEEDED_KEY) or ""

    --tprint(exporters_limit_exceeded)
    
    if not isEmptyString(exporters_limit_exceeded) and exporters_limit_exceeded ~= "0" then
        local alert = alert_consts.alert_types.alert_exporters_limit_exceeded.new()
        -- Remove the value to not spam the message
        ntop.setCache(EXPORTERS_LIMITS_EXCEEDED_KEY, "")
        alert:set_score_emergency()
        alert:store(alerts_api.systemEntity())
    end
end

-- #################################################################

script.hooks.min = dropped_flows_check

-- #################################################################

return script
