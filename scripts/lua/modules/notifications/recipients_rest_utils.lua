--
-- (C) 2017-26 - ntop.org
--
local dirs = ntop.getDirs()

require "lua_utils"
local alert_severities = require "alert_severities"
local checks = require "checks"
local host_pools = require "host_pools":create()
local am_utils = require "am_utils"

-- ##############################################

local recipients_rest_utils = {}

-- ##############################################

-- @brief Parses and validates a comma-separated list of check category ids into a lua array
-- @return A lua array of valid check category ids
function recipients_rest_utils.parse_check_categories(categories_string)
   local categories = {}

    if isEmptyString(categories_string) then return categories end

    -- Unfold the categories csv
    categories = categories_string:split(",") or {categories_string}

    local res = {}
    for _, category_id in pairs(categories) do
       local category_id = tonumber(category_id)

       for _, category in pairs(checks.check_categories) do
	  if category_id == category.id then
	     res[#res + 1] = category_id
	     break
	  end
       end
    end

    return res
end

-- ##############################################

-- @brief Parses and validates a comma-separated list of host pool ids into a lua array
-- @return A lua array of valid ids
function recipients_rest_utils.parse_host_pools(pools_string)
   local pools = host_pools:get_all_pools()
   local pools_list = {}

    if isEmptyString(pools_string) then return pools_list end

    -- Unfold the pools csv
    pools_list = pools_string:split(",") or {pools_string}

    local res = {}
    for _, pool_id in pairs(pools_list) do
       local pool_id = tonumber(pool_id)

       for _, pool in pairs(pools) do
	  if pool_id == pool.pool_id then
	     res[#res + 1] = pool_id
	     break
	  end
       end
    end

    return res
end

-- ##############################################

-- @brief Parses and validates a comma-separated list of active monitoring hosts into a lua array
-- @return A lua array of valid ids
function recipients_rest_utils.parse_am_hosts(hosts_string)
   local hosts_list = {}

    if isEmptyString(hosts_string) then return hosts_list end

    -- Unfold the hosts csv
    hosts_list = hosts_string:split(",") or {hosts_string}

    local am_hosts = am_utils.getHosts()

    local res = {}
    for _, host_id in pairs(hosts_list) do
       if am_hosts[host_id] then
	  res[#res + 1] = host_id
       else
          -- Debug
          tprint(host_id .. " AM host not found")
       end
    end

    return res
end

-- ##############################################

-- @brief Parses and validates a comma-separated list of tag ids
-- @return A lua array of tag ids
function recipients_rest_utils.parse_tags(tags_string)
   if isEmptyString(tags_string) then return {} end

   local tag_badge_utils = require "tag_badge_utils"
   local all_tags = tag_badge_utils.getTags()
   local valid_ids = {}
   for _, t in pairs(all_tags) do
      valid_ids[t.id] = true
   end

   local tags_list = tags_string:split(",") or {tags_string}
   local res = {}
   for _, id_str in pairs(tags_list) do
      local id = tonumber(id_str)
      if id and valid_ids[id] then
	 res[#res + 1] = id
      end
   end
   return res
end

-- ##############################################

-- @brief Parses and validates a severity id string and returns it as a number
-- @param minimum_severity_id_string An string with an integer severity id as found in `alert_severities`
-- @return A valid integer severity id or nil when validation fails
function recipients_rest_utils.parse_minimum_severity(minimum_severity_id_string)
   local minimum_severity_id = tonumber(minimum_severity_id_string)

   for _, alert_severity in pairs(alert_severities) do
      if minimum_severity_id == alert_severity.severity_id then
	 return minimum_severity_id
      end
   end

   return alert_severities.notice.severity_id -- No minimum severity
 end

-- ##############################################

-- @brief Parses a notification policy of a v2 notification REST request
-- @param post The request params (_POST)
-- @return A table with the policy (see notification_policies.add_policy), with validated
--         filters. An empty category, host pool, active monitoring host or tag list is no filter
function recipients_rest_utils.parse_policy(post)
   return {
      name = post["policy_name"],
      enabled = (post["policy_enabled"] ~= "false"),
      notifications_type = post["policy_notifications_type"],
      minimum_severity = recipients_rest_utils.parse_minimum_severity(post["policy_minimum_severity"]),
      check_categories = recipients_rest_utils.parse_check_categories(post["policy_check_categories"]),
      host_pools = recipients_rest_utils.parse_host_pools(post["policy_host_pools"]),
      am_hosts = recipients_rest_utils.parse_am_hosts(post["policy_am_hosts"]),
      tags = recipients_rest_utils.parse_tags(post["policy_labels"]),
      recipient_ids = recipients_rest_utils.parse_ids(post["policy_recipients"]),
   }
end

-- ##############################################

-- @brief Parses a comma-separated list of recipient or policy ids (checked by notification_policies)
-- @return A lua array of numbers
function recipients_rest_utils.parse_ids(ids_string)
   local res = {}

   if isEmptyString(ids_string) then return res end

   for _, id in ipairs(ids_string:split(",") or { ids_string }) do
      res[#res + 1] = tonumber(id)
   end

   return res
end

-- ##############################################

-- @brief Extra checks on the channel params of a v2 notification REST request
-- @return nil when valid, otherwise an error table { type = ..., param = ... }
function recipients_rest_utils.check_channel_params(endpoint_key, post)
   if endpoint_key ~= "shell" then return nil end

   -- shell.runScript prepends its folders to the name and runs "<script> <options>":
   -- no path components in the name, no shell metacharacters in the options
   local script = post["shell_script"]
   if script and (script:find("/", 1, true) or script:find("..", 1, true)) then
      return { type = "invalid_param", param = "shell_script" }
   end

   local options = post["shell_script_options"]
   if options and not options:match("^[%w%s%-%._=,:@]*$") then
      return { type = "invalid_param", param = "shell_script_options" }
   end

   return nil
end

-- ##############################################

return recipients_rest_utils
