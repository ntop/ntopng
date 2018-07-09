--
-- (C) 2018 - ntop.org
--

require "lua_utils"
local json = require "dkjson"

local script = {}

-- How often this script will be called (in seconds)
script.EXPORT_FREQUENCY = 5

-- The minimum severity for an alert
script.DEFAULT_SEVERITY = "warning"

function script.dequeueAlerts(queue)
  while true do
    local json_alert = ntop.lpopCache(queue)

    if not json_alert then
      break
    end

    local alert = json.decode(json_alert)

    -- Print the alert on the console
    tprint(alert)

    if (alert.action == "engage") then
      if (alertTypeRaw(alert.type) == "threshold_cross") and
            (alert.alert_key == "min_active_local_hosts") then

        -- Run a custom bash script
        --os.execute("/tmp/my_script.sh")
      end
    end
  end

  return {success=true}
end

return script
