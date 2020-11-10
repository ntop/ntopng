--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param one_param The first alert param
-- @param another_param The second alert param
-- @return A table with the alert built
local function createDemo(one_param, another_param)
   local built = {
      alert_type_params = {
	 one_param = one_param,
	 another_param = another_param
      },
   }

   return built
end

-- #######################################################

return {
  alert_key = alert_keys.user.alert_user_03,
  i18n_title = "New API Demo",
  icon = "fas fa-exclamation",
  creator = createDemo,
}
