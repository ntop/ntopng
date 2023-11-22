--
-- (C) 2019-22 - ntop.org
--
local checks = require("checks")
local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local ERROR_QUEUE = "ntopng.trace_error.alert_queue"

local script = {
    -- Script category
    category = checks.check_categories.internals,
    severity = alert_consts.get_printable_severities().emergency,
    default_enabled = true,

    -- See below
    hooks = {},

    gui = {
        i18n_title = "internals.system_error",
        i18n_description = "internals.system_error_description"
    }
}

-- #################################################################

local function system_error_check(params)
    -- Fetch the issue from the error queue
    local error = ntop.rpopCache(ERROR_QUEUE)

    while (error ~= nil) do
        if not isEmptyString(error) then
            -- error is a string with the error message
            local alert = alert_consts.alert_types.alert_system_error.new(error)

            alert:set_score_emergency()
            alert:store(alerts_api.systemEntity())
        end

        error = ntop.rpopCache("ntopng.trace_error.alert_queue")
    end
end

-- #################################################################

script.hooks.min = system_error_check

-- #################################################################

return script
