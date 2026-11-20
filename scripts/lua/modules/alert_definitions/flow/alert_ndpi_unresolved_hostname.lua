--
-- (C) 2019-26 - ntop.org
--
-- ##############################################

local flow_alert_keys = require "flow_alert_keys"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
-- Import Mitre Att&ck utils
local mitre = require "mitre_utils"

-- ##############################################

local alert_ndpi_unresolved_hostname = classes.class(alert)

-- ##############################################

alert_ndpi_unresolved_hostname.meta = {
    alert_key = flow_alert_keys.flow_alert_ndpi_unresolved_hostname,
    i18n_title = "flow_alerts_explorer.alert_ndpi_unresolved_hostname_title",
    icon = "fas fa-fw fa-exclamation",

    -- Mitre Att&ck Matrix values
    mitre_values = {
        mitre_tactic = mitre.tactic.defense_evasion,
        mitre_technique = mitre.technique.data_obfuscation,
        mitre_id = "T1207"
    },

    has_attacker = true
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_flow_param The first alert param
-- @param another_flow_param The second alert param
-- @return A table with the alert built
function alert_ndpi_unresolved_hostname:init()
    -- Call the parent constructor
    self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_ndpi_unresolved_hostname.format(ifid, alert, alert_type_params)
    return (i18n("flow_alerts_explorer.status_ndpi_unresolved_hostname_description", {
        server = hostinfo2label({
            ip = alert.srv_ip,
            vlan = alert.vlan_id,
            name = alert.srv_name
        }, true, false, true)
    }))
end

-- #######################################################

return alert_ndpi_unresolved_hostname
