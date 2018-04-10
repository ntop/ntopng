--
-- (C) 2018 - ntop.org
--

require("lua_utils")

local nagios = {}

nagios.EXPORT_FREQUENCY = 1

function nagios.sendNotifications(notifications)
  if ntop.isPro() and hasNagiosSupport() then
    for _, notif in ipairs(notifications) do
      local entity_value = notif.entity_value
      local akey = notif.alert_key

      if notif.action == "engage" then
        if not ntop.sendNagiosAlert(entity_value:gsub("@0", ""), akey, notif.message) then
          return false
        end
      elseif notif.action == "release" then
        if not ntop.withdrawNagiosAlert(entity_value:gsub("@0", ""), akey, "Service OK.") then
          return false
        end
      end
    end
  end

  return true
end

return nagios
