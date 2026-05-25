--
-- (C) 2019-26 - ntop.org
--
local alerts_api = require("alerts_api")
local alert_consts = require("alert_consts")
local alert_categories = require "alert_categories"
local json = require "dkjson"


local script = {
    -- Script category
    category = alert_categories.internals,
    severity = alert_consts.get_printable_severities().notice,
    default_enabled = false,
    -- See below
    hooks = {},

    gui = {
        i18n_title = "internals.bgp_prefix_update_title",
        i18n_description = "internals.bgp_prefix_update_descr"
    }
}

-- Redis list key where nEdge/FRR pushes BGP update notifications
local BGP_QUEUE_KEY = "ntopng.bgp.queue.updates"
local BGP_QUEUE_MAX_LEN = 100

-- ##############################################
 
--  @brief Pop all pending BGP update messages from the Redis list and generate
--  one system alert per message.
--  lpopCache() atomically removes and returns the leftmost element
--  (LPOP), so each message is consumed exactly once.
local function bgp_prefix_update_check(params)
    for _ = 1, BGP_QUEUE_MAX_LEN do
        -- LPOP: returns an empty string when the list is empty
        local raw = ntop.lpopCache(BGP_QUEUE_KEY)
        if isEmptyString(raw) then
            -- Queue is drained, nothing more to do
            break
        end

        local bgp_msg, _, err = json.decode(raw)

        if not bgp_msg or err or type(bgp_msg) ~= "table" then
            traceError(TRACE_ERROR, TRACE_CONSOLE,
                string.format("bgp_prefix_update: failed to decode message: %s (err: %s)",
                    tostring(raw), tostring(err)))
        -- Skip malformed entry and continue draining
        else
            local a = alert_consts.alert_types.alert_bgp_prefix_update.new(bgp_msg)
            a:set_score_notice()
            a:store(alerts_api.systemEntity())
        end
    end
end


-- #################################################################

script.hooks.min = bgp_prefix_update_check

-- #################################################################

return script
