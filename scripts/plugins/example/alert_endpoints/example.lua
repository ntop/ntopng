--
-- (C) 2019-20 - ntop.org
--

require "lua_utils"
local json = require "dkjson"
local alert_consts = require("alert_consts")

local example = {
  conf_params = {
  },
  conf_template = {
    plugin_key = "example_alert_endpoint",
    template_name = "example_endpoint.template"
  },
  recipient_params = {
  },
  recipient_template = {
    plugin_key = "example_alert_endpoint",
    template_name = "example_recipient.template"
  },
}

-- How often this script will be called (in seconds)
example.EXPORT_FREQUENCY = 5

-- The minimum severity for an alert in order to be exported by this endpoint
-- example.DEFAULT_SEVERITY = "warning"

-- This determines the invocation priority of this endpoint.
-- Higher priority endpoints are invoked first for the alert export.
example.prio = 500

-- ##############################################

-- Each endpoint has a dedicated redis queue for the alerts. This function
-- is called every EXPORT_FREQUENCY seconds and should check the alerts
-- queue for alerts and possibly export them.

-- @brief Process the pending alerts notifications from the queue
-- @params recipient the recipient information and configuration, including the queue name
-- @param budget the number of items to export (or number of external calls in batch mode)
-- @return {success = true} on success,
-- {success = false, error_message = "Some error description here"} on failure
function example.dequeueRecipientAlerts(recipient, budget)
  local exported = 0

  while exported < budget do
    local json_alert = ntop.lpopCache(recipient.export_queue)

    if not json_alert then
      break
    end

    local alert = json.decode(json_alert)

    -- Print the alert on the console.
    tprint(alert)

    -- Can filter the alerts based on some criteria
    if (alert.action == "engage") then
      if (alert_consts.alertTypeRaw(alert.type) == "alert_threshold_cross") and
            (alert.alert_key == "min_active_local_hosts") then

        -- Export the alert, e.g. by running a custom bash script
        --os.execute("/tmp/my_script.sh")
      end
    end

    exported = exported + 1
  end

  return {success=true}
end

-- ##############################################

return example
