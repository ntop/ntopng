--
-- (C) 2019-25 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"

local json = require("dkjson")
local alert_creators = require "alert_creators"
local classes = require "classes"
local alert = require "alert"
local mitre = require "mitre_utils"
local alert_entities = require "alert_entities"


-- ##############################################

local alert_as_ranking_changed = classes.class(alert)

-- ##############################################

alert_as_ranking_changed.meta = {
    alert_key = other_alert_keys.alert_as_ranking_changed,
    i18n_title = "alerts_dashboard.as_ranking_changed",
    icon = "fas fa-exclamation-triangle",
    entities = {
        alert_entities.as,
    }

    -- Mitre Att&ck Matrix values
    -- mitre_values = {
    --   mitre_tactic =
    --   mitre_technique = 
    --   mitre_id =
    -- }
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_as_ranking_changed:init(as, current_ranking, previous_ranking)
    self.super:init()
    self.alert_type_params = {
        as = as,
        current_ranking = current_ranking,
        previous_ranking = previous_ranking
  }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_as_ranking_changed.format(ifid, alert, alert_type_params)
    local alert_consts = require("alert_consts")
    current = alert_consts.formatRanking(alert_type_params.current_ranking)
    prev = alert_consts.formatRanking(alert_type_params.previous_ranking)
    return i18n("alert_messages.alert_as_ranking_changed", { 
        as = alert_type_params.as,
        current_ranking = current,
        previous_ranking = prev
    })
end

-- #######################################################

return alert_as_ranking_changed
