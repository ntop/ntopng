--
-- (C) 2019-26 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"

local classes = require "classes"
local alert = require "alert"
local alert_entities = require "alert_entities"
local format_utils = require "format_utils"


-- ##############################################

local alert_bgp_prefix_update = classes.class(alert)

alert_bgp_prefix_update.meta = {
  alert_key = other_alert_keys.alert_bgp_prefix_update,
  i18n_title = "internals.bgp_prefix_update",
  icon = "fas fa-fw fa-exclamation-triangle",
  entities = {
    alert_entities.system,
  },
}

-- ##############################################

function alert_bgp_prefix_update:init(bgp_msg)
  -- Call the parent constructor
  self.super:init()
  
  self.alert_type_params = {
    bgp_id = bgp_msg.bgp_id or "",
    asn = bgp_msg.asn or 0,
    reason = bgp_msg.reason or "",
    origin = bgp_msg.origin or "",
    as_path = bgp_msg.as_path or {},
    next_hop = bgp_msg.next_hop or "",
    communities = bgp_msg.communities or {},
    time = bgp_msg.time or 0,
  }
end

-- #######################################################

-- @brief Format an alert into a human-readable string
-- @param ifid The integer interface id of the generated alert
-- @param alert The alert description table, including alert data such as the generating entity, timestamp, granularity, type
-- @param alert_type_params Table `alert_type_params` as built in the `:init` method
-- @return A human-readable string
function alert_bgp_prefix_update.format(ifid, alert, alert_type_params)
  local reason = alert_type_params.reason or ""
  local bgp_id = alert_type_params.bgp_id or ""
  local asn = tostring(alert_type_params.asn or "")
  local next_hop = alert_type_params.next_hop or ""
  local origin = alert_type_params.origin or ""
  local time_str = format_utils.formatEpoch(alert_type_params.time or 0)
 
   -- Build a human-readable AS path string (e.g. "178 -> 13335")
   local as_path_tbl = alert_type_params.as_path or {}
   local as_path_str = ""
   if table.len(as_path_tbl) > 0 then
      local parts = {}
      for _, v in ipairs(as_path_tbl) do
         parts[#parts + 1] = tostring(v)
      end
      as_path_str = table.concat(parts, " -> ")
   end
 
   -- Build a human-readable communities string (e.g. "178:200, 178:202")
   local communities_tbl = alert_type_params.communities or {}
   local communities_str = ""
   if #communities_tbl > 0 then
      communities_str = table.concat(communities_tbl, ", ")
   end
 
   -- Localise the reason tag; fall back to the raw value if missing
   local reason_i18n = i18n("alert_messages.bgp_prefix_update_reason_" .. reason)
   if isEmptyString(reason_i18n) then
      reason_i18n = reason
   end
 
   return i18n("alert_messages.bgp_prefix_update", {
      reason = reason_i18n,
      bgp_id = bgp_id,
      asn = asn,
      next_hop = next_hop,
      origin = origin,
      as_path = as_path_str,
      communities = communities_str,
      time = time_str,
   })
end


-- #######################################################

return alert_bgp_prefix_update 
