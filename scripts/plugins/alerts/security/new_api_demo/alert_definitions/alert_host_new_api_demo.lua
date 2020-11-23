--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- ##############################################

local NewHostAlert = { }

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_param The first alert param
-- @param another_param The second alert param
-- @return A table with the alert built
function NewHostAlert:set_params(one_param, another_param)
   -- tprint("new create: "..self.def_script.alert_key)
   self.alert_type_params = {
      one_param = one_param,
      another_param = another_param
   }
end

-- #######################################################

function NewHostAlert:format()
   -- tprint("new format: "..self.def_script.alert_key)
end

-- #######################################################

return {
  alert_key = alert_keys.user.alert_user_04,
  i18n_title = "New Host API Demo",
  icon = "fas fa-exclamation",
  Alert = NewHostAlert
}
