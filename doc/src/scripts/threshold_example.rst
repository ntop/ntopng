Other Alerts Threshold Example
##############################

Here described an alert example with a threshold configurable by the user.

Check
~~~~~

As an example reporte the ghost_networks.lua check; it checks if ghost networks are present in the network.

.. code:: lua

    --
    -- (C) 2019-24 - ntop.org
    --

    local alerts_api = require("alerts_api")
    local alert_consts = require("alert_consts")
    local checks = require("checks")
    local script = {
        -- Script category
        category = checks.check_categories.security,

        default_enabled = true,

        severity = alert_consts.get_printable_severities().warning,

        hooks = {},

        gui = {
            i18n_title = "alerts_dashboard.ghost_networks",
            i18n_description = "alerts_dashboard.ghost_networks_description",
        },
    }

    -- #################################################################

    local function check_ghost_networks(params)
        for domain, domain_info in pairs(params.entity_info.bcast_domains or {}) do
            if(domain_info.ghost_network) then
                local key = params.check.key .. "__" .. domain
                local delta_hits = alerts_api.interface_delta_val(key, params.granularity, domain_info.hits)

                local alert = alert_consts.alert_types.alert_ghost_network.new(domain)

                alert:set_info(params)
                alert:set_subtype(domain)

                if(delta_hits > 0) then
                    alert:trigger(params.alert_entity, nil, params.cur_alerts)
                else
                    alert:release(params.alert_entity, nil, params.cur_alerts)
                end
            end
        end
    end

    -- #################################################################

    script.hooks.min = check_ghost_networks

    -- #################################################################

    return script



Alert ID
~~~~~~~~

.. code:: lua

    alert_flow_flood                     =  OTHER_BASE_KEY + 5 , -- No longer used, check alert_flow_flood_attacker and alert_flow_flood_victim
    alert_ghost_network                  =  OTHER_BASE_KEY + 6 ,
    alert_no_exporter_activity           =  OTHER_BASE_KEY + 7 ,



Alert Script
~~~~~~~~~~~~

.. code:: lua
    
    --
    -- (C) 2019-24 - ntop.org
    --

    -- ##############################################

    local other_alert_keys = require "other_alert_keys"
    local classes = require "classes"
    local alert = require "alert"
    local alert_entities = require "alert_entities"
    local mitre = require "mitre_utils"

    -- ##############################################

    local alert_ghost_network = classes.class(alert)

    -- ##############################################

    alert_ghost_network.meta = {
        alert_key = other_alert_keys.alert_ghost_network,
        i18n_title = "alerts_dashboard.ghost_networks",
        icon = "fas fa-fw fa-ghost",
        entities = {
            alert_entities.interface,
            alert_entities.network
        },

        -- Mitre Att&ck Matrix values
        mitre_values = {
            mitre_tactic = mitre.tactic.c_and_c,
            mitre_technique = mitre.technique.hide_infrastructure,
            mitre_id = "T1665"
        },
    }

    -- ##############################################

    function alert_ghost_network:init(network)
        -- Call the parent constructor
        self.super:init()

        self.alert_type_params = {
            network = network
        }
    end

    -- #######################################################

    function alert_ghost_network.format(ifid, alert, alert_type_params)
        return(i18n("alerts_dashboard.ghost_network_detected_description", {
            network = alert_type_params.network,
            entity = getInterfaceName(ifid),
            url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?ifid=".. ifid .."&page=networks",
        }))
    end

    -- #######################################################

    return alert_ghost_network
