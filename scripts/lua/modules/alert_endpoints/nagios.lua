--
-- (C) 2018 - ntop.org
--

require("lua_utils")

local nagios = {}

nagios.EXPORT_FREQUENCY = 1

function nagios.dequeueAlerts(queue)
  if not ntop.isPro() or not hasNagiosSupport() then
    return {success=false, error_message="Nagios support is not available"}
  end

  while true do
    local notifications = ntop.lrangeCache(queue, 0, 0)

    if (not notifications) or (#notifications ~= 1) then
      break
    end

    local notif = alertNotificationToObject(notifications[1])
    local entity_value = notif.entity_value
    local akey = notif.alert_key

    if notif.action == "engage" then
      if not ntop.sendNagiosAlert(entity_value:gsub("@0", ""), akey, notif.message) then
        return {success=false, error_message="Unable to send alert to nagios"}
      end
    elseif notif.action == "release" then
      if not ntop.withdrawNagiosAlert(entity_value:gsub("@0", ""), akey, "Service OK.") then
        return {success=false, error_message="Unable to withdraw nagios alert"}
      end
    end

    -- Remove the notification from the queue
    ntop.lpopCache(queue)
  end

  return {success=true}
end

return nagios
