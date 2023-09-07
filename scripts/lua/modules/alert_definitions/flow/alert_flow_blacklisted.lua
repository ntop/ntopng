--
-- (C) 2019-22 - ntop.org
--

-- ##############################################

local flow_alert_keys = require "flow_alert_keys"

-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"

-- ##############################################

local alert_flow_blacklisted = classes.class(alert)

-- ##############################################

alert_flow_blacklisted.meta = {
   alert_key = flow_alert_keys.flow_alert_blacklisted,
   i18n_title = "flow_checks_config.blacklisted",
   icon = "fas fa-fw fa-exclamation",

   has_victim = true,
   has_attacker = true,
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param info A flow info table fetched with `flow.getBlacklistedInfo()`
-- @return A table with the alert built
function alert_flow_blacklisted:init()
   -- Call the parent constructor
   self.super:init()
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_flow_blacklisted.format(ifid, alert, alert_type_params)
  local who = {}

  if alert["cli_blacklisted"] and alert["cli_blacklisted"] ~= "0" then
    who[#who + 1] = {type = i18n("client"), blacklist_name = alert_type_params["custom_cat_file"]}
  end

  if alert["srv_blacklisted"] and alert["srv_blacklisted"] ~= "0" then
    who[#who + 1] = {type = i18n("server"), blacklist_name = alert_type_params["custom_cat_file"]}
  end

  -- if either the client or the server is blacklisted
  -- then also the category is blacklisted so there's no need
  -- to check it.
  -- Domain is basically the union of DNS names, SSL CNs and HTTP hosts.
  if alert["cat_blacklisted"] then
    who[#who + 1] = {type = i18n("domain")}
  end

  if alert_type_params["custom_cat_file"] then
    who[#who + 1] = "('"..alert_type_params["custom_cat_file"].."' blacklist)"
  end

  if #who == 0 then
    return i18n("flow_details.blacklisted_flow")
  end
  
  local who_string = ""
  local black_list_names = ""
  for _, v in ipairs(who) do
    if v.type then
      if who_string ~= "" then
        who_string = who_string .. ", "
      end
      who_string = who_string .. v.type
    end

    if v.blacklist_name then
      if black_list_names ~= "" then
        black_list_names = black_list_names .. ", "
      end
      black_list_names = black_list_names .. v.blacklist_name
    end
  end
  local res = i18n("flow_details.blacklisted_flow_detailed", {who = who_string, blacklist = black_list_names})

  return res
end

-- #######################################################

return alert_flow_blacklisted
