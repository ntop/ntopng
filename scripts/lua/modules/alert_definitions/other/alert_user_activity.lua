--
-- (C) 2019-21 - ntop.org
--

-- ##############################################

local other_alert_keys = require "other_alert_keys"
local format_utils = "format_utils"
local pools_lua_utils = require "pools_lua_utils"
-- Import the classes library.
local classes = require "classes"
-- Make sure to import the Superclass!
local alert = require "alert"
local alert_entities = require "alert_entities"

-- ##############################################

local alert_user_activity = classes.class(alert)

-- ##############################################

alert_user_activity.meta = {
   alert_key = other_alert_keys.alert_user_activity,
   i18n_title = "alerts_dashboard.user_activity",
   icon = "fas fa-fw fa-user",
   entities = {
      alert_entities.user
   },
}

-- ##############################################

-- @brief Prepare an alert table used to generate the alert
-- @param scope A string indicating the scope, one of 'function' or 'login'
-- @param name The name of the function when the scope is 'function' or nil
-- @param params Function parameters when the scope is 'function' or nil
-- @param remote_addr The ip address of the remote user when available
-- @param status A string indicating the action status or nil
-- @return A table with the alert built
function alert_user_activity:init(scope, name, params, remote_addr, status)
   -- Call the parent constructor
   self.super:init()

   self.alert_type_params = {
	scope = scope,
	name = name,
	params = params,
	remote_addr = remote_addr,
	status = status,
   }
end

-- #######################################################

function alert_user_activity.format(ifid, alert, alert_type_params)
   local decoded = alert_type_params
   local user = alert.user or alert.entity_val
 
   if decoded.scope ~= nil then
 
      if decoded.scope == 'login' and decoded.status ~= nil then
	  if decoded.status == 'authorized' then
		 return i18n('user_activity.login_successful', {user=user})
	  else
		 return i18n('user_activity.login_not_authorized', {user=user})
	  end
 
	   elseif decoded.scope == 'function' and decoded.name ~= nil then
	  local ifname = getInterfaceName(decoded.ifid)
 
	  -- User add/del/password
 
	  if decoded.name == 'addUser' and decoded.params[1] ~= nil then
		 local add_user = decoded.params[1]
		 return i18n('user_activity.user_added', {user=user, add_user=add_user})
 
	  elseif decoded.name == 'deleteUser' and decoded.params[1] ~= nil then
		 local del_user = decoded.params[1]
		 return i18n('user_activity.user_deleted', {user=user, del_user=del_user})
 
	  elseif decoded.name == 'resetUserPassword' and decoded.params[2] ~= nil then
		 local pwd_user = decoded.params[2]
		 local user_ip = ternary(decoded.remote_addr, decoded.remote_addr, '')
		 return  i18n('user_activity.password_changed', {user=user, pwd_user=pwd_user, ip=user_ip})
 
		 -- SNMP device add/del
 
	  elseif decoded.name == 'add_snmp_device' and decoded.params[1] ~= nil then
		 local device_ip = decoded.params[1]
		 return i18n('user_activity.snmp_device_added', {user=user, ip=device_ip})
 
	  elseif decoded.name == 'del_snmp_device' and decoded.params[1] ~= nil then
		 local device_ip = decoded.params[1]
		 return i18n('user_activity.snmp_device_deleted', {user=user, ip=device_ip})
 
		 -- Stored data
 
	  elseif decoded.name == 'request_delete_active_interface_data' and decoded.params[1] ~= nil then
		 return i18n('user_activity.deleted_interface_data', {user=user, ifname=ifname})
 
	  elseif decoded.name == 'delete_all_interfaces_data' then
		 return i18n('user_activity.deleted_all_interfaces_data', {user=user})
 
	  elseif decoded.name == 'delete_host' and decoded.params[1] ~= nil then
		 local host = decoded.params[1]
		 local hostinfo = hostkey2hostinfo(host)
		 local hostname = hostinfo2label(hostinfo)
		 local host_url = hostinfo2detailshref(hostinfo, {ifid = decoded.ifid}, hostname)
		 return i18n('user_activity.deleted_host_data', {user=user, ifname=ifname, host=host_url})
 
	  elseif decoded.name == 'delete_network' and decoded.params[1] ~= nil then
		 local network = decoded.params[1]
		 return i18n('user_activity.deleted_network_data', {user=user, ifname=ifname, network=network})
 
	  elseif decoded.name == 'delete_inactive_interfaces' then
		 return i18n('user_activity.deleted_inactive_interfaces_data', {user=user})
 
		 -- Service enable/disable
 
	  elseif decoded.name == 'disableService' and decoded.params[1] ~= nil then
		 local service_name = decoded.params[1]
		 if service_name == 'n2disk-ntopng' and decoded.params[2] ~= nil then
			local service_instance = decoded.params[2]
			return i18n('user_activity.recording_disabled', {user=user, ifname=service_instance})
		 end
 
	  elseif decoded.name == 'enableService' and decoded.params[1] ~= nil then
		 local service_name = decoded.params[1]
		 if service_name == 'n2disk-ntopng' and decoded.params[2] ~= nil then
			local service_instance = decoded.params[2]
			return i18n('user_activity.recording_enabled', {user=user, ifname=service_instance})
		 end
 
		 -- File download
 
	  elseif decoded.name == 'dumpBinaryFile' and decoded.params[1] ~= nil then
		 local file_name = decoded.params[1]
		 return i18n('user_activity.file_downloaded', {user=user, file=file_name})
 
	  elseif decoded.name ==  'export_data' and decoded.params[1] ~= nil then
		 local mode = decoded.params[1]
		 if decoded.params[2] ~= nil then
			local host = decoded.params[1]
			local hostinfo = hostkey2hostinfo(host)
			local hostname = hostinfo2label(hostinfo)
			local host_url = hostinfo2detailshref(hostinfo, {ifid = decoded.ifid}, hostname)
			return i18n('user_activity.exported_data_host', {user=user, mode=mode, host=host_url})
		 else
			return i18n('user_activity.exported_data', {user=user, mode=mode})
		 end
 
	  elseif decoded.name == 'host_get_json' and decoded.params[1] ~= nil then
		 local host = decoded.params[1]
		 local hostinfo = hostkey2hostinfo(host)
		 local hostname = hostinfo2label(hostinfo)
		 local host_url = hostinfo2detailshref(hostinfo, {ifid = decoded.ifid}, hostname)
		 return i18n('user_activity.host_json_downloaded', {user=user, host=host_url})
 
	  elseif decoded.name == 'live_flows_extraction' and decoded.params[1] ~= nil and decoded.params[2] ~= nil then
		 local time_from = format_utils.formatEpoch(decoded.params[1])
		 local time_to = format_utils.formatEpoch(decoded.params[2])
		 return i18n('user_activity.flows_downloaded', {user=user, from=time_from, to=time_to })
 
		 -- Live capture
 
	  elseif decoded.name == 'liveCapture' then
		 if not isEmptyString(decoded.params[1]) then
			local host = decoded.params[1]
			local hostinfo = hostkey2hostinfo(host)
			local hostname = hostinfo2label(hostinfo)
			local host_url = hostinfo2detailshref(hostinfo, {ifid = decoded.ifid}, hostname)
 
			if not isEmptyString(decoded.params[3]) then
		   local filter = decoded.params[3]
		   return i18n('user_activity.live_capture_host_with_filter', {user=user, host=host_url, filter=filter, ifname=ifname})
			else
		   return i18n('user_activity.live_capture_host', {user=user, host=host_url, ifname=ifname})
			end
		 else
			if not isEmptyString(decoded.params[3]) then
		   local filter = decoded.params[3]
		   return i18n('user_activity.live_capture_with_filter', {user=user,filter=filter, ifname=ifname})
			else
		   return i18n('user_activity.live_capture', {user=user, ifname=ifname})
			end
		 end
 
		 -- Live extraction
 
	  elseif decoded.name == 'runLiveExtraction' and decoded.params[1] ~= nil then
		 local time_from = format_utils.formatEpoch(decoded.params[2])
		 local time_to = format_utils.formatEpoch(decoded.params[3])
		 local filter = decoded.params[4]
		 return i18n('user_activity.live_extraction', {user=user, ifname=ifname,
							   from=time_from, to=time_to, filter=filter})
 
		 -- Rest API
 
	  elseif decoded.name == 'set_host_alias' and decoded.params['host'] ~= nil and decoded.params['custom_name'] ~= nil then
		 local host = decoded.params['host']
		 local hostinfo = hostkey2hostinfo(host)
		 local hostname = hostinfo2label(hostinfo)
		 local host_url = hostinfo2detailshref(hostinfo, {ifid = decoded.ifid}, hostname)
		 local new_alias = decoded.params['custom_name']
		 return i18n('user_activity.set_host_alias', {user=user, host=host_url, alias=new_alias})
 
	  elseif decoded.name == 'set_pool_config' then
		 return i18n('user_activity.set_pool_config', {user=user})
 
	  elseif decoded.name == 'set_scripts_config' then
		 return i18n('user_activity.set_scripts_config', {user=user})
 
	  elseif decoded.name == 'bind_pool_member' then
		 return i18n('user_activity.bind_pool_member',
			 {user = user,
			  pool_id = decoded.params['pool_id'],
			  member = decoded.params['member'],
			  pool_name = decoded.params['pool_name'] or '?',
		 })
 
	  elseif decoded.name == 'add_pool' then
		 return i18n('user_activity.add_pool',
			 {user = user,
			  pool_name = decoded.params['pool_name'] or '?',
			  pool_url = pools_lua_utils.get_pool_url(decoded.params['pool_key']),
		 })
 
	  elseif decoded.name == 'delete_pool' then
		 return i18n('user_activity.delete_pool',
			 {user = user,
			  pool_id = decoded.params['pool_id'],
			  pool_name = decoded.params['pool_name'] or '?',
			  pool_url = pools_lua_utils.get_pool_url(decoded.params['pool_key']),
		 })
 
	  elseif decoded.name == 'edit_pool' then
		 return i18n('user_activity.edit_pool', {
				user = user,
				pool_id = decoded.params['pool_id'],
				pool_name = decoded.params['pool_name'] or '?',
				pool_url = pools_lua_utils.get_pool_url(decoded.params['pool_key']),
		 })
 
	  elseif decoded.name == 'add_ntopng_user' then
		 return i18n('user_activity.add_ntopng_user', {user=user, new_user = decoded.params['username']})
 
	  elseif decoded.name == 'delete_ntopng_user' then
		 return i18n('user_activity.delete_ntopng_user', {user=user, old_user = decoded.params['username']})
 
		 -- Alerts
 
	  elseif decoded.name == 'checkDeleteStoredAlerts' and decoded.params[1] ~= nil then
		 local status = decoded.params[1]
		 return i18n('user_activity.alerts_deleted', {user=user, status=status})
 
	  elseif decoded.name == 'setPref' and decoded.params[1] ~= nil and decoded.params[2] ~= nil then
		 local key = decoded.params[1]
		 local value = decoded.params[2]
		 local k = key:gsub("^ntopng%.prefs%.", "")
		 local pref_desc
 
		 if k == "disable_alerts_generation" then pref_desc = i18n("prefs.disable_alerts_generation_title")
		 elseif k == "mining_alerts" then pref_desc = i18n("prefs.toggle_mining_alerts_title")
		 elseif k == "probing_alerts" then pref_desc = i18n("prefs.toggle_alert_probing_title")
		 elseif k == "tls_alerts" then pref_desc = i18n("prefs.toggle_tls_alerts_title")
		 elseif k == "dns_alerts" then pref_desc = i18n("prefs.toggle_dns_alerts_title")
		 elseif k == "mining_alerts" then pref_desc = i18n("prefs.toggle_mining_alerts_title")
		 elseif k == "host_blacklist" then pref_desc = i18n("prefs.toggle_malware_probing_title")
		 elseif k == "external_alerts" then pref_desc = i18n("prefs.toggle_external_alert_title")
		 elseif k == "device_protocols_alerts" then pref_desc = i18n("prefs.toggle_device_protocols_title")
		 elseif k == "alerts.device_first_seen_alert" then pref_desc = i18n("prefs.toggle_device_first_seen_alert_title")
		 elseif k == "alerts.device_connection_alert" then pref_desc = i18n("prefs.toggle_device_activation_alert_title")
		 elseif k == "alerts.pool_connection_alert" then pref_desc = i18n("prefs.toggle_pool_activation_alert_title")
		 elseif k == "alerts.email_notifications_enabled" then pref_desc = i18n("prefs.toggle_email_notification_title")
		 elseif k == "alerts.slack_notifications_enabled" then pref_desc = i18n("prefs.toggle_slack_notification_title", {url="http://www.slack.com"})
		 elseif k == "alerts.syslog_notifications_enabled" then pref_desc = i18n("prefs.toggle_alert_syslog_title")
		 elseif k == "alerts.webhook_notifications_enabled" then pref_desc = i18n("prefs.toggle_webhook_notification_title")
		 elseif starts(k, "alerts.email_") then pref_desc = i18n("prefs.email_notification")
		 elseif starts(k, "alerts.smtp_") then pref_desc = i18n("prefs.email_notification")
		 elseif starts(k, "alerts.slack_") then pref_desc = i18n("prefs.slack_integration")
		 elseif starts(k, "alerts.webhook_") then pref_desc = i18n("prefs.webhook_notification")
		 else pref_desc = k -- last resort if not handled
		 end
 
		 if k == "disable_alerts_generation" then
			if value == "1" then value = "0" else value = "1" end
		 end
 
		 if value == "1" then
			return i18n('user_activity.enabled_preference', {user=user, pref=pref_desc})
		 elseif value == "0" then
			return i18n('user_activity.disabled_preference', {user=user, pref=pref_desc})
		 else
			return i18n('user_activity.changed_preference', {user=user, pref=pref_desc})
		 end
 
	  else
		 return i18n('user_activity.unknown_activity_function', {user=user, name=decoded.name})
 
	  end
	   end
	end
 
	return i18n('user_activity.unknown_activity', {user=user, scope=decoded.scope})
end

-- #######################################################

return alert_user_activity

