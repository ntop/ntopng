--
-- (C) 2019-20 - ntop.org
--

local alert_keys = require "alert_keys"

-- #######################################################

-- @brief Prepare an alert table used to generate the alert
-- @param alert_severity A severity as defined in `alert_consts.alert_severities`
-- @return A table with the alert built
local function createWebMining()
   local built = {
      alert_type_params = {
      }
   }

   return built
end

-- #######################################################

return {
  alert_key = alert_keys.ntopng.alert_web_mining,
  i18n_title = "alerts_dashboard.web_mining",
  icon = "fab fa-bitcoin",
  creator = createWebMining,
}
