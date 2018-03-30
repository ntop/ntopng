--
-- (C) 2018 - ntop.org
--

require("lua_utils")

local nagios = {}

function nagios.sendNotification(notif)
  if ntop.isPro() and hasNagiosSupport() then
    local entity_value = notif.entity_value
    local akey = notif.alert_key

    if notif.action == "engage" then
      return ntop.sendNagiosAlert(entity_value:gsub("@0", ""), akey, notif.message)
    elseif notif.action == "release" then
      return ntop.withdrawNagiosAlert(entity_value:gsub("@0", ""), akey, "Service OK.")
    end
  end
end

return nagios
