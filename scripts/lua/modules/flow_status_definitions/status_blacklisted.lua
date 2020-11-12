--
-- (C) 2019-20 - ntop.org
--

local status_keys = require "flow_keys"

local alert_consts = require("alert_consts")

-- #################################################################

local function formatBlacklistedFlow(flowstatus_info)
   local who = {}

   if not flowstatus_info then
      return i18n("flow_details.blacklisted_flow")
   end

   if flowstatus_info["blacklisted.cli"] then
      who[#who + 1] = i18n("client")
   end

   if flowstatus_info["blacklisted.srv"] then
      who[#who + 1] = i18n("server")
   end

   -- if either the client or the server is blacklisted
   -- then also the category is blacklisted so there's no need
   -- to check it.
   -- Domain is basically the union of DNS names, SSL CNs and HTTP hosts.
   if #who == 0 and flowstatus_info["blacklisted.cat"] then
      who[#who + 1] = i18n("domain")
   end

   if #who == 0 then
      return i18n("flow_details.blacklisted_flow")
   end

   local res = i18n("flow_details.blacklisted_flow_detailed", {who = table.concat(who, ", ")})

   return res
end

-- #################################################################

return {
  status_key = status_keys.ntopng.status_blacklisted,
  alert_type = alert_consts.alert_types.alert_flow_blacklisted,
  i18n_title = "flow_details.blacklisted_flow",
  i18n_description = formatBlacklistedFlow
}
