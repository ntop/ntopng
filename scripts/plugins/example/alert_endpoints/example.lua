--
-- (C) 2019-20 - ntop.org
--

require "lua_utils"
local json = require "dkjson"
local alert_consts = require("alert_consts")

local script = {}

-- How often this script will be called (in seconds)
script.EXPORT_FREQUENCY = 5

-- The minimum severity for an alert in order to be exported by this
-- endpoint
script.DEFAULT_SEVERITY = "warning"

-- This determines the invocation priority of this endpoint.
-- Higher priority endpoints are invoked first for the alert export.
script.prio = 500

-- ##############################################

-- Each endpoint has a dedicated redis queue for the alerts. This function
-- is called every EXPORT_FREQUENCY seconds and should check the alerts
-- queue for alerts and possibly export them.

-- @brief Process the pending alerts notifications from the queue
-- @params queue the redis queue name
-- @return {success = true} on success,
-- {success = false, error_message = "Some error description here"} on failure
function script.dequeueAlerts(queue)
  while true do
    local json_alert = ntop.lpopCache(queue)

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
  end

  return {success=true}
end

-- ##############################################

-- @brief Called when the "Alert Endpoints" form is submitted.
-- @note This API could be subject to change!
function email.handlePost()
  --tprint(_POST)
end

-- ##############################################

-- @brief Adds some custom preferences to the "Alert Endpoints" page
-- @brief alert_endpoints a reference to the scripts/lua/modules/alert_endpoints_utils.lua module
-- @brief subpage_active the lua table representing the currently active page
-- @brief showElements right now is always true
-- @note This API could be subject to change!
function script.printPrefs(alert_endpoints, subpage_active, showElements)
  local elementToSwitch = {}

  print('<thead class="thead-light"><tr><th colspan="2" class="info">'..i18n("example.example_notification")..'</th></tr></thead>')

  prefsToggleButton(subpage_active, {
    field = "toggle_example_notification",
    pref = alert_endpoints.getAlertNotificationModuleEnableKey("example", true),
    default = "0",
    disabled = showElements==false,
    to_switch = elementToSwitch,
  })
end

-- ##############################################

return script
