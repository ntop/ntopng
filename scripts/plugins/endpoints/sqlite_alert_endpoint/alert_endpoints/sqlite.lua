--
-- (C) 2018 - ntop.org
--

require "lua_utils"
local json = require "dkjson"
local alerts_api = require "alerts_api"
local alert_consts = require "alert_consts"

local sqlite = {
   name = "SQLite",
   builtin = true, -- Whether this endpoint can be configured from the UI. Disabled for the builtin SQLite

   conf_params = {
      -- No params, SQLite is builtin
   },
   conf_template = {
      plugin_key = "sqlite_alert_endpoint",
      template_name = "sqlite_endpoint.template"
   },
   recipient_params = {
   },
   recipient_template = {
      plugin_key = "sqlite_alert_endpoint",
      template_name = "sqlite_recipient.template"
   },
}

sqlite.EXPORT_FREQUENCY = 1
sqlite.prio = 400

-- ##############################################

local function recipient2sendMessageSettings(recipient)
   local settings = {
      -- builtin
  }

   return settings
end

-- ##############################################

-- Processes queued alerts and returns the information necessary to store them.
-- Alerts are only enqueued by AlertsQueue in C. From lua, the alerts_api
-- can be called directly as slow operations will be postponed
local function processStoreAlertFromQueue(alert)
  local entity_info = nil
  local type_info = nil

  interface.select(tostring(alert.ifid))

  if(alert.alert_type == "misconfigured_dhcp_range") then
    local router_info = {host = alert.router_ip, vlan = alert.vlan_id}
    entity_info = alerts_api.hostAlertEntity(alert.client_ip, alert.vlan_id)
    type_info = alert_consts.alert_types.alert_ip_outsite_dhcp_range.create(
       alert_consts.alert_severities.warning,
       router_info,
       alert.mac_address,
       alert.client_mac,
       alert.sender_mac
    )
  elseif(alert.alert_type == "mac_ip_association_change") then
    if(ntop.getPref("ntopng.prefs.ip_reassignment_alerts") == "1") then
      local name = getDeviceName(alert.new_mac)
      entity_info = alerts_api.macEntity(alert.new_mac)
      type_info = alert_consts.alert_types.alert_mac_ip_association_change.create(
	 alert_consts.alert_severities.warning,
	 name,
	 alert.ip,
	 alert.old_mac,
	 alert.new_mac
      )
    end
  elseif(alert.alert_type == "login_failed") then
    entity_info = alerts_api.userEntity(alert.user)
    type_info = alert_consts.alert_types.alert_login_failed.create(
       alert_consts.alert_severities.warning
    )
  elseif(alert.alert_type == "broadcast_domain_too_large") then
    entity_info = alerts_api.macEntity(alert.src_mac)
    type_info = alert_consts.alert_types.alert_broadcast_domain_too_large.create(alert_consts.alert_severities.warning, alert.src_mac, alert.dst_mac, alert.vlan_id, alert.spa, alert.tpa)
  elseif(alert.alert_type == "remote_to_remote") then
    if(ntop.getPref("ntopng.prefs.remote_to_remote_alerts") == "1") then
      local host_info = {host = alert.host, vlan = alert.vlan}
      entity_info = alerts_api.hostAlertEntity(alert.host, alert.vlan)
      type_info = alerts_api.remoteToRemoteType(host_info, alert.mac_address)
    end
  elseif((alert.alert_type == "user_activity") and (alert.scope == "login")) then
    entity_info = alerts_api.userEntity(alert.user)
    type_info = alert_consts.alert_types.alert_user_activity.create(
       alert_consts.alert_severities.notice,
       "login",
       nil,
       nil,
       nil,
       "authorized"
    )
  elseif(alert.alert_type == "nfq_flushed") then
    entity_info = alerts_api.interfaceAlertEntity(alert.ifid)
    type_info = alert_consts.alert_types.alert_nfq_flushed.create(
       alert_consts.alert_severities.error,
       getInterfaceName(alert.ifid),
       alert.pct,
       alert.tot,
       alert.dropped
    )
  else
    traceError(TRACE_ERROR, TRACE_CONSOLE, "Unknown alert type " .. (alert.alert_type or ""))
  end

  return entity_info, type_info
end

-- ##############################################

function sqlite.dequeueRecipientAlerts(recipient, budget, high_priority)
  local more_available = true
  local budget_used = 0

  -- Check for alerts pushed by the datapath to an internal queue (from C)
  -- and store them (push them to the SQLite and Notification queues).
  -- NOTE: this is executed in a system VM, with no interfaces references
  while budget_used <= budget do
    local alert = ntop.popInternalAlerts()

    if alert == nil then
      break
    end

    if(verbose) then tprint(alert) end

    local entity_info, type_info = processStoreAlertFromQueue(alert)

    if((type_info ~= nil) and (entity_info ~= nil)) then
      alerts_api.store(entity_info, type_info, alert.alert_tstamp)
    end

    budget_used = budget_used + 1
  end

  -- Now also check for alerts pushed by user scripts from Lua
  -- Dequeue alerts up to budget
  -- Note: in this case budget is the number of sqlite alerts to insert into the queue
  while budget_used <= budget and more_available do
     local notifications = {}

     for i=1, budget do
       local notification = ntop.recipient_dequeue(recipient.recipient_id, high_priority)
       if notification then 
	  notifications[#notifications + 1] = notification
       else
	  break
       end
     end

     if not notifications or #notifications == 0 then
      more_available = false
      break
    end

    for _, json_message in ipairs(notifications) do
       local alert = json.decode(json_message)

       if alert.action ~= "engage" then
	  -- Do not store alerts engaged - they're are handled only in-memory

	  if(alert) then
	     interface.select(string.format("%d", alert.ifid))

	     if(alert.is_flow_alert) then
		interface.storeFlowAlert(alert)
	     else
		interface.storeAlert(
		   alert.alert_tstamp, alert.alert_tstamp_end, alert.alert_granularity,
		   alert.alert_type, alert.alert_subtype, alert.alert_severity,
		   alert.alert_entity, alert.alert_entity_val,
		   alert.alert_json)
	     end
	  end
       end
    end

    -- TODO: send

    -- Remove the processed messages from the queue
    budget_used = budget_used + #notifications
  end

  return {success = true, more_available = more_available}
end

-- ##############################################

function sqlite.runTest(recipient)
  return false, "Not implemented"
end

-- ##############################################

return sqlite
