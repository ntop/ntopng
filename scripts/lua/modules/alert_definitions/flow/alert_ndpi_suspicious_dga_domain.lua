--
-- (C) 2019-24 - ntop.org
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

local alert_ndpi_suspicious_dga_domain = classes.class(alert)

-- ##############################################

alert_ndpi_suspicious_dga_domain.meta = {
    alert_key = flow_alert_keys.flow_alert_ndpi_suspicious_dga_domain,
    i18n_title = "alerts_dashboard.ndpi_suspicious_dga_domain_title",
    icon = "fas fa-fw fa-exclamation",

    -- Mitre Att&ck Matrix values
    mitre_values = {
        mitre_tactic = mitre.tactic.c_and_c,
        mitre_technique = mitre.technique.dynamic_resolution,
        mitre_sub_technique = mitre.sub_technique.domain_generation_algorithms,
        mitre_id = "T1568.002"
    },

    -- A compromised host can do DGA domain requests. A compromised host can be:
    --  1. 'victim' as it is compromised
    --  2. 'attacker' as it can do malicious activities due to the fact that it has been compromised
    -- Since 'attacker' implies 'victim' in this case, the alert is assumed to have the 'attacker'.
    -- The DNS server is not assumed to be the victim as it justs serves the request.
    has_attacker = true
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @return A table with the alert built
function alert_ndpi_suspicious_dga_domain:init()
    -- Call the parent constructor
    self.super:init()
end

-- #######################################################

function alert_ndpi_suspicious_dga_domain.format(ifid, alert, alert_type_params)
    return
end

-- #######################################################

return alert_ndpi_suspicious_dga_domain
