--
-- (C) 2014-15 - ntop.org
--

-- This file contains the description of all functions
-- used to trigger host alerts

local verbose = false
local prefs = ntop.getPrefs()
local info = ntop.getInfo()
show_advanced_prefs_key = "ntopng.prefs.show_advanced_prefs"

local function hasBridgeInterfaces()
  local curif = ifname
  local ifnames = interface.getIfNames()
  local found = false

  for _,ifname in pairs(ifnames) do
    interface.select(ifname)

    local ifstats = interface.getStats()
    if isBridgeInterface(ifstats) then
      found = true
      break
    end
  end

  interface.select(curif)
  return found
end

function hasNagiosSupport()
   return prefs.nagios_nsca_host ~= nil
end

function hasAlertsDisabled()
  return (prefs.has_cmdl_disable_alerts == true) or
      ((_POST["disable_alerts_generation"] ~= nil) and (_POST["disable_alerts_generation"] == "1")) or
      ((_POST["disable_alerts_generation"] == nil) and (ntop.getPref("ntopng.prefs.disable_alerts_generation") == "1"))
end

-- This table is used both to control access to the preferences and to filter preferences results
menu_subpages = {
  {id="auth",          label=i18n("prefs.user_authentication"),  advanced=false, pro_only=true,   disabled=false, entries={
    multiple_ldap_authentication = {
      title       = i18n("prefs.multiple_ldap_authentication_title"),
      description = i18n("prefs.multiple_ldap_authentication_description"),
    }, multiple_ldap_account_type = {
      title       = i18n("prefs.multiple_ldap_account_type_title"),
      description = i18n("prefs.multiple_ldap_account_type_description"),
    }, ldap_server_address = {
      title       = i18n("prefs.ldap_server_address_title"),
      description = i18n("prefs.ldap_server_address_description"),
    }, bind_dn = {
      title       = i18n("prefs.bind_dn_title"),
      description = i18n("prefs.bind_dn_description"),
    }, bind_pwd = {
      title       = i18n("prefs.bind_pwd_title"),
      description = i18n("prefs.bind_pwd_description"),
    }, search_path = {
      title       = i18n("prefs.search_path_title"),
      description = i18n("prefs.search_path_description"),
    }, user_group = {
      title       = i18n("prefs.user_group_title"),
      description = i18n("prefs.user_group_description"),
    }, admin_group = {
      title       = i18n("prefs.admin_group_title"),
      description = i18n("prefs.admin_group_description"),
    }, toggle_ldap_anonymous_bind = {
      title       = i18n("prefs.toggle_ldap_anonymous_bind_title"),
      description = i18n("prefs.toggle_ldap_anonymous_bind_description"),
    },
  }}, {id="ifaces",    label=i18n("prefs.network_interfaces"),   advanced=true,  pro_only=false,  disabled=false, entries={
    dynamic_iface_vlan_creation = {
      title       = i18n("prefs.dynamic_iface_vlan_creation_title"),
      description = i18n("prefs.dynamic_iface_vlan_creation_description"),
    }, dynamic_flow_collection = {
      title       = i18n("prefs.dynamic_flow_collection_title"),
      description = i18n("prefs.dynamic_flow_collection_description"),
    },
  }}, {id="in_memory",     label=i18n("prefs.cache_settings"),             advanced=true,  pro_only=false,  disabled=false, entries={
    local_host_max_idle = {
      title       = i18n("prefs.local_host_max_idle_title"),
      description = i18n("prefs.local_host_max_idle_description"),
    }, non_local_host_max_idle = {
      title       = i18n("prefs.non_local_host_max_idle_title"),
      description = i18n("prefs.non_local_host_max_idle_description"),
    }, flow_max_idle = {
      title       = i18n("prefs.flow_max_idle_title"),
      description = i18n("prefs.flow_max_idle_description"),
    }, housekeeping_frequency = {
      title       = i18n("prefs.housekeeping_frequency_title"),
      description = i18n("prefs.housekeeping_frequency_description"),
    }, toggle_local_host_cache_enabled = {
      title       = i18n("prefs.toggle_local_host_cache_enabled_title"),
      description = i18n("prefs.toggle_local_host_cache_enabled_description"),
    }, toggle_active_local_host_cache_enabled = {
      title       = i18n("prefs.toggle_active_local_host_cache_enabled_title"),
      description = i18n("prefs.toggle_active_local_host_cache_enabled_description"),
    }, active_local_host_cache_interval = {
      title       = i18n("prefs.active_local_host_cache_interval_title"),
      description = i18n("prefs.active_local_host_cache_interval_description"),
    }, local_host_cache_duration = {
      title       = i18n("prefs.local_host_cache_duration_title"),
      description = i18n("prefs.local_host_cache_duration_description"),
    },
  }}, {id="on_disk_ts",    label=i18n("prefs.data_retention"),       advanced=false, pro_only=false,  disabled=false, entries={
    toggle_local = {
      title       = i18n("prefs.toggle_local_title"),
      description = i18n("prefs.toggle_local_description"),
    }, toggle_local_ndpi = {
      title       = i18n("prefs.toggle_local_ndpi_title"),
      description = i18n("prefs.toggle_local_ndpi_description"),
    }, toggle_flow_rrds = {
      title       = i18n("prefs.toggle_flow_rrds_title"),
      description = i18n("prefs.toggle_flow_rrds_description"),
    }, toggle_pools_rrds = {
      title       = i18n("prefs.toggle_pools_rrds_title"),
      description = i18n("prefs.toggle_pools_rrds_description"),
    }, toggle_vlan_rrds = {
      title       = i18n("prefs.toggle_vlan_rrds_title"),
      description = i18n("prefs.toggle_vlan_rrds_description"),
    }, toggle_asn_rrds = {
      title       = i18n("prefs.toggle_asn_rrds_title"),
      description = i18n("prefs.toggle_asn_rrds_description"),
    }, toggle_tcp_flags_rrds = {
      title       = i18n("prefs.toggle_tcp_flags_rrds_title"),
      description = i18n("prefs.toggle_tcp_flags_rrds_description"),
    }, toggle_tcp_retr_ooo_lost_rrds = {
      title       = i18n("prefs.toggle_tcp_retr_ooo_lost_rrds_title"),
      description = i18n("prefs.toggle_tcp_retr_ooo_lost_rrds_description"),
    }, toggle_local_categorization = {
      title       = i18n("prefs.toggle_local_categorization_title"),
      description = i18n("prefs.toggle_local_categorization_description"),
    }, minute_top_talkers_retention = {
      title       = i18n("prefs.minute_top_talkers_retention_title"),
      description = i18n("prefs.minute_top_talkers_retention_description"),
    }, mysql_retention = {
      title       = i18n("prefs.mysql_retention_title"),
      description = i18n("prefs.mysql_retention_description"),
      hidden      = (prefs.is_dump_flows_to_mysql_enabled == false),
    }
  }}, {id="alerts",        label=i18n("show_alerts.alerts"),               advanced=false, pro_only=false,  disabled=(prefs.has_cmdl_disable_alerts == true), entries={
    disable_alerts_generation = {
      title       = i18n("prefs.disable_alerts_generation_title"),
      description = i18n("prefs.disable_alerts_generation_description"),
    }, toggle_flow_alerts_iface = {
      title       = i18n("prefs.toggle_flow_alerts_iface_title"),
      description = i18n("prefs.toggle_flow_alerts_iface_description"),
    }, toggle_alert_probing = {
      title       = i18n("prefs.toggle_alert_probing_title"),
      description = i18n("prefs.toggle_alert_probing_description"),
    }, toggle_ssl_alerts = {
      title       = i18n("prefs.toggle_ssl_alerts_title"),
      description = i18n("prefs.toggle_ssl_alerts_description"),
    }, toggle_malware_probing = {
      title       = i18n("prefs.toggle_malware_probing_title"),
      description = i18n("prefs.toggle_malware_probing_description", {url="https://rules.emergingthreats.net/fwrules/emerging-Block-IPs.txt"}),
    }, max_num_alerts_per_entity = {
      title       = i18n("prefs.max_num_alerts_per_entity_title"),
      description = i18n("prefs.max_num_alerts_per_entity_description"),
    }, max_num_flow_alerts = {
      title       = i18n("prefs.max_num_flow_alerts_title"),
      description = i18n("prefs.max_num_flow_alerts_description"),
    }, toggle_mysql_check_open_files_limit = {
      title       = i18n("prefs.toggle_mysql_check_open_files_limit_title"),
      description = i18n("prefs.toggle_mysql_check_open_files_limit_description"),
      hidden      = (prefs.is_dump_flows_to_mysql_enabled == false),
    }
    
  }}, {id="ext_alerts",    label=i18n("prefs.external_alerts"), advanced=false, pro_only=false,  disabled=hasAlertsDisabled(), entries={
    toggle_alert_syslog = {
      title       = i18n("prefs.toggle_alert_syslog_title"),
      description = i18n("prefs.toggle_alert_syslog_description"),
    }, toggle_slack_notification = {
      title       = i18n("prefs.toggle_slack_notification_title", {url="http://www.slack.com"}),
      description = i18n("prefs.toggle_slack_notification_description"),
    }, slack_notification_severity_preference = {
      title       = i18n("prefs.slack_notification_severity_preference_title", {url="http://www.slack.com"}),
      description = i18n("prefs.slack_notification_severity_preference_description"),
    }, sender_username = {
      title       = i18n("prefs.sender_username_title"),
      description = i18n("prefs.sender_username_description"),
    }, slack_webhook = {
      title       = i18n("prefs.slack_webhook_title"),
      description = i18n("prefs.slack_webhook_description"),
    },
  }}, {id="protocols",     label=i18n("prefs.protocols"),            advanced=false, pro_only=false,  disabled=false, entries={
    toggle_top_sites = {
      title       = i18n("prefs.toggle_top_sites_title"),
      description = i18n("prefs.toggle_top_sites_description", {url="https://resources.sei.cmu.edu/asset_files/Presentation/2010_017_001_49763.pdf"}),
    },
  }}, {id="logging",       label=i18n("prefs.logging"),              advanced=false, pro_only=false,  disabled=(prefs.has_cmdl_trace_lvl == true), entries={
    toggle_logging_level = {
      title       = i18n("prefs.toggle_logging_level_title"),
      description = i18n("prefs.toggle_logging_level_description"),
    }, toggle_access_log = {
      title       = i18n("prefs.toggle_access_log_title"),
      description = i18n("prefs.toggle_access_log_description"),
    },
  }}, {id="flow_db_dump",  label=i18n("prefs.flow_database_dump"),   advanced=true,  pro_only=false,  disabled=(prefs.is_dump_flows_enabled == false), entries={
    toggle_flow_db_dump_export = {
      title       = i18n("prefs.toggle_flow_db_dump_export_title"),
      description = i18n("prefs.toggle_flow_db_dump_export_description"),
    }, max_num_packets_per_tiny_flow = {
      title       = i18n("prefs.max_num_packets_per_tiny_flow_title"),
      description = i18n("prefs.max_num_packets_per_tiny_flow_description"),
    }, max_num_bytes_per_tiny_flow = {
      title       = i18n("prefs.max_num_bytes_per_tiny_flow_title"),
      description = i18n("prefs.max_num_bytes_per_tiny_flow_description"),
    },
  }}, {id="snmp",          label=i18n("prefs.snmp"),                 advanced=true,  pro_only=true,   disabled=false, entries={
    toggle_snmp_rrds = {
      title       = i18n("prefs.toggle_snmp_rrds_title"),
      description = i18n("prefs.toggle_snmp_rrds_description"),
    }, default_snmp_community = {
      title       = i18n("prefs.default_snmp_community_title"),
      description = i18n("prefs.default_snmp_community_description"),
    },
  }}, {id="nbox",          label=i18n("prefs.nbox_integration"),     advanced=true,  pro_only=true,   disabled=false, entries={
    toggle_nbox_integration = {
      title       = i18n("prefs.toggle_nbox_integration_title"),
      description = i18n("prefs.toggle_nbox_integration_description"),
    }, nbox_user = {
      title       = i18n("prefs.nbox_user_title"),
      description = i18n("prefs.nbox_user_description"),
    }, nbox_password = {
      title       = i18n("prefs.nbox_password_title"),
      description = i18n("prefs.nbox_password_description"),
    },
  }}, {id="misc",          label=i18n("prefs.misc"),                 advanced=false, pro_only=false,  disabled=false, entries={
    toggle_autologout = {
      title       = i18n("prefs.toggle_autologout_title"),
      description = i18n("prefs.toggle_autologout_description"),
    }, google_apis_browser_key = {
      title       = i18n("prefs.google_apis_browser_key_title"),
      description = i18n("prefs.google_apis_browser_key_description", {url="https://maps-apis.googleblog.com/2016/06/building-for-scale-updates-to-google.html"}),
    }, toggle_thpt_content = {
      title       = i18n("prefs.toggle_thpt_content_title"),
      description = i18n("prefs.toggle_thpt_content_description"),
    }, toggle_host_mask = {
      title       = i18n("prefs.toggle_host_mask_title"),
      description = i18n("prefs.toggle_host_mask_description"),
    }
  }}, {id="bridging",      label=i18n("prefs.traffic_bridging"),     advanced=false,  pro_only=true,   enterprise_only=true, disabled=(not hasBridgeInterfaces()), entries={
    safe_search_dns = {
      title       = i18n("prefs.safe_search_dns_title"),
      description = i18n("prefs.safe_search_dns_description", {url="https://en.wikipedia.org/wiki/SafeSearch"}),
    }, global_dns = {
      title       = i18n("prefs.global_dns_title"),
      description = i18n("prefs.global_dns_description"),
    }, secondary_dns = {
      title       = i18n("prefs.secondary_dns_title"),
      description = i18n("prefs.secondary_dns_description"),
    }, featured_dns = {
      title       = i18n("prefs.featured_dns_title"),
      description = i18n("prefs.featured_dns_description"),
    }, toggle_shaping_directions = {
      title       = i18n("prefs.toggle_shaping_directions_title"),
      description = i18n("prefs.toggle_shaping_directions_description"),
    }, toggle_captive_portal = {
      title       = i18n("prefs.toggle_captive_portal_title"),
      description = i18n("prefs.toggle_captive_portal_description"),
    }, captive_portal_url = {
      title       = i18n("prefs.captive_portal_url_title"),
      description = i18n("prefs.captive_portal_url_description"),
    }
  }},
}

-- Add nagios configuration (if available)
-- Presently, nagios is not available under windows
if hasNagiosSupport() then
   for _, i in pairs(menu_subpages) do
      if i["id"] == "ext_alerts" then
	 local nagios = {
	    toggle_alert_nagios = {
	       title       = i18n("prefs.toggle_alert_nagios_title"),
	       description = i18n("prefs.toggle_alert_nagios_description"),
	    }, nagios_nsca_host = {
	       title       = i18n("prefs.nagios_nsca_host_title"),
	       description = i18n("prefs.nagios_nsca_host_description"),
	    }, nagios_nsca_port = {
	       title       = i18n("prefs.nagios_nsca_port_title"),
	       description = i18n("prefs.nagios_nsca_port_description"),
	    }, nagios_send_nsca_executable = {
	       title       = i18n("prefs.nagios_send_nsca_executable_title"),
	       description = i18n("prefs.nagios_send_nsca_executable_description"),
	    }, nagios_send_nsca_config = {
	       title       = i18n("prefs.nagios_send_nsca_config_title"),
	       description = i18n("prefs.nagios_send_nsca_config_description"),
	    }, nagios_host_name = {
	       title       = i18n("prefs.nagios_host_name_title"),
	       description = i18n("prefs.nagios_host_name_description"),
	    }, nagios_service_name = {
	       title       = i18n("prefs.nagios_service_name_title"),
	       description = i18n("prefs.nagios_service_name_description"),
	    },
	 }
	 i["entries"] = table.merge(i["entries"], nagios)
      end
   end
end


function isSubpageAvailable(subpage, show_advanced_prefs)
  if show_advanced_prefs == nil then
    show_advanced_prefs = toboolean(ntop.getPref(show_advanced_prefs_key))
  end

  if (subpage.disabled) or
     ((subpage.advanced) and (not show_advanced_prefs)) or
     ((subpage.pro_only) and (not ntop.isPro())) or
     ((subpage.enterprise_only) and (not info["version.enterprise_edition"])) then
    return false
  end

  return true
end

-- notify ntopng upon preference changes
function notifyNtopng(key)
    if key == nil then return end
    -- notify runtime ntopng configuration changes
    if string.starts(key, 'nagios') then
        if verbose then io.write('notifying ntopng upon nagios pref change\n') end
        ntop.reloadNagiosConfig()
    elseif string.starts(key, 'toggle_logging_level') then
        if verbose then io.write('notifying ntopng upon logging level pref change\n') end 
        ntop.setLoggingLevel(value)
    end
end

-- ############################################

local options_script_loaded = false
local options_ctr = 0

function prefsResolutionButtons(fmt, value, fixed_id)
  local ctrl_id
  if fixed_id ~= nil then
    ctrl_id = fixed_id
  else
    ctrl_id = "options_group_" .. options_ctr
    options_ctr = options_ctr + 1
  end

  local res = makeResolutionButtons(FMT_TO_DATA_TIME, ctrl_id, fmt, value, {classes={"pull-right"}})

  print(res.html)
  print("<script>")
  if not options_script_loaded then
    print(res.init)
    options_script_loaded = true
  end
  print(res.js)
  print("</script>")

  return res.value
end

-- ############################################

-- Runtime preference

function prefsInputFieldPrefs(label, comment, prekey, key, default_value, _input_type, showEnabled, disableAutocomplete, allowURLs, extra)
  extra = extra or {}

  if(string.ends(prekey, ".")) then
    k = prekey..key
  else
    k = prekey.."."..key
  end

  if(_POST[key] ~= nil) then
    v_s = _POST[key]
    v = tonumber(v_s)

    v_cache = ntop.getPref(k)
    value = v_cache
    if ((v_cache==nil) or (v ~= v_cache)) then

      if(v ~= nil and (v > 0) and (v <= 86400)) then
        ntop.setPref(k, tostring(v))
        value = v
      elseif (v_s ~= nil) then
      	if(allowURLs or (extra.pattern == getURLPattern())) then
	        v_s = string.gsub(v_s, "ldaps:__", "ldaps://")
        	v_s = string.gsub(v_s, "ldap:__", "ldap://")
		v_s = string.gsub(v_s, "http:__", "http://")
		v_s = string.gsub(v_s, "https:__", "https://")
	end
        ntop.setPref(k, v_s)
        value = v_s
      end
      -- least but not last we asynchronously notify the runtime ntopng instance for changes
      notifyNtopng(key)
    end
  else
    local v_s = nil
    if not isEmptyString(prekey) then
      v_s = ntop.getPref(k)
    end
    value = v_s
    if((v_s==nil) or (v_s=="")) then
      value = default_value
      if not isEmptyString(prekey) then
        ntop.setPref(k, tostring(default_value))
        notifyNtopng(key)
      end
    end
  end

  if ((showEnabled == nil) or (showEnabled == true)) then
    showEnabled = "table-row"
  else
    showEnabled = "none"
  end

  local attributes = {}

  if extra.min ~= nil then
    if extra.tformat ~= nil then
      attributes["data-min"] = extra.min
    else
      attributes["min"] = extra.min
    end
  end

  if extra.max ~= nil then
    if extra.tformat ~= nil then
      attributes["data-max"] = extra.max
    else
      attributes["max"] = extra.max
    end
  end

  if extra.disabled == true then attributes["disabled"] = "disabled" end
  if extra.required == true then attributes["required"] = "" end
  if extra.pattern ~= nil then attributes["pattern"] = extra.pattern end

  if (_input_type == "number") then
    attributes["required"] = "required"
  end

  local input_type = "text"
  if _input_type ~= nil then input_type = _input_type end
  print('<tr id="'..key..'" style="display: '..showEnabled..';"><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td>')

  local style = {}
  style["text-align"] = "right"
  style["margin-bottom"] = "0.5em"

  print [[
    <td align=right>
      <table class="form-group" style="margin-bottom: 0; min-width:22em;">
        <tr>
          <td width="100%;"></td>
          <td style="vertical-align:top;">]]
      if extra.tformat ~= nil then
        value = prefsResolutionButtons(extra.tformat, value)
      end

      if extra.width == nil then
        if _input_type == "number" then
          style["width"] = "8em"
        else
          style["width"] = "20em"
        end
        style["margin-left"] = "auto"
      else
        style["width"] = "15em"
      end
      style["margin-left"] = "auto"

      style = table.merge(style, extra.style)
      attributes = table.merge(attributes, extra.attributes)

      print[[
          </td>
          <td style="vertical-align:top; padding-left: 2em;">
            <input id="id_input_]] print(key) print[[" type="]] print(input_type) print [[" class="form-control" ]] print(table.tconcat(attributes, "=", " ", nil, '"')) print[[ name="]] print(key) print [[" style="]] print(table.tconcat(style, ":", "; ", ";")) print[[" value="]] print(value..'"')
          if disableAutocomplete then print(" autocomplete=\"off\"") end
        print [[/>
          </td>
        </tr>
        <tr>
          <td colspan="3" style="padding:0;">
            <div class="help-block with-errors text-right" style="height:1em;"></div>
          </td>
        </tr>
      </table>
  </td></tr>
]]

end

function prefsInformativeField(label, comment, showEnabled, extra)
  local extra = extra or {}
  extra["style"] = extra["style"] or {}
  extra["style"]["display"] = "none"
  prefsInputFieldPrefs(label, comment, "", "", "", nil, showEnabled, nil, nil, extra)
end

function toggleTableButton(label, comment, on_label, on_value, on_color , off_label, off_value, off_color, submit_field, redis_key, disabled)
  if(_POST[submit_field] ~= nil) then
    ntop.setPref(redis_key, _POST[submit_field])
    value = _POST[submit_field]
    notifyNtopng(submit_field)
  else
    value = ntop.getPref(redis_key)
  end
  if (disabled == true) then
    disabled = 'disabled = ""'
  else
    disabled = ""
  end

  -- Read it anyway to
  if(value == off_value) then
    rev_value  = on_value
    on_active  = "btn-default"
    off_active = "btn-"..off_color.." active"
  else
    rev_value  = off_value
    on_active  = "btn-"..on_color.." active"
    off_active = "btn-default"
  end

  if(label ~= "") then print('<tr><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td><td align=right>\n') end
  print('<form method="post">\n<div class="btn-group btn-toggle">')
  print('<button type="submit" '..disabled..' class="btn btn-sm  '..on_active..'">'..on_label..'</button>')
  print('<button '..disabled..' class="btn btn-sm '..off_active..'">'..off_label..'</button></div>\n')
  print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')
  print('<input type=hidden name='..submit_field..' value='..rev_value..' />\n')
  print('</form>\n')
  if(label ~= "") then print('</td></tr>') end

  return(value)
end

function toggleTableButtonPrefs(label, comment, on_label, on_value, on_color , off_label, off_value, off_color, submit_field,
                                redis_key, default_value, disabled, elementToSwitch, hideOn, showElement)

  value = ntop.getPref(redis_key)
  if(_POST[submit_field] ~= nil) then
    if ( (value == nil) or (value ~= _POST[submit_field])) then
      ntop.setPref(redis_key, _POST[submit_field])
      value = _POST[submit_field]
      notifyNtopng(submit_field)
    end
  else
    if ((value == nil) or (value == "")) then
      if (default_value ~= nil) then
        value = default_value
      else
        value = off_value
      end
      ntop.setPref(redis_key, value)
      notifyNtopng(submit_field)
    end
  end

  if (disabled == true) then
    disabled = 'disabled = ""'
  else
    disabled = ""
  end

  -- Read it anyway to
  if(value == off_value) then
    on_active  = "btn-default"
    off_active = "btn-"..off_color.." active"
  else
    value = on_value
    on_active  = "btn-"..on_color.." active"
    off_active = "btn-default"
  end

  local objRow = ""
  if ((showElement ~= nil) and (showElement == false)) then
    objRow = " style=\"display:none\""
  else
    objRow = " style=\"display:table-row\""
  end
  if(label ~= "") then print('<tr id="row_'..submit_field..'"'..objRow..'><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td><td align=right>\n') end
  print('<div class="btn-group btn-toggle">')
  print('<button type="button" onclick="'..submit_field..'_functionOn()" id="'..submit_field..'_on_id" '..disabled..' class="btn btn-sm  '..on_active..'">'..on_label..'</button>')
  print('<button type="button" onclick="'..submit_field..'_functionOff()" id="'..submit_field..'_off_id" '..disabled..' class="btn btn-sm '..off_active..'">'..off_label..'</button></div>\n')
  print('<input type=hidden id="'..submit_field..'_input" name='..submit_field..' value="'..value..'"/>\n')
  if(label ~= "") then print('</td></tr>') end
  print('\n')
  print('<script>\n')
  print[[function ]] print(submit_field) print [[_functionOn(){
    var classOn = document.getElementById("]] print(submit_field) print [[_on_id");
    var classOff = document.getElementById("]] print(submit_field) print [[_off_id");
    classOn.removeAttribute("class");
    classOff.removeAttribute("class");
    classOn.setAttribute("class", "btn btn-sm btn-]]print(on_color) print[[ active");
    classOff.setAttribute("class", "btn btn-sm btn-default");

    $("#]] print(submit_field) print [[_input").val("]] print(on_value) print[[").trigger('change');]]
    if elementToSwitch ~= nil then
      for element = 1, #elementToSwitch do
        if ((hideOn == nil) or (hideOn == false)) then
          print('$("#'..elementToSwitch[element]..'").css("display","table-row");')
        else
          print('$("#'..elementToSwitch[element]..'").css("display","none");')
        end
      end
    end
    print[[
  }
  ]]
  print[[
  function ]] print(submit_field) print [[_functionOff(){
    var classOn = document.getElementById("]] print(submit_field) print [[_on_id");
    var classOff = document.getElementById("]] print(submit_field) print [[_off_id");
    classOn.removeAttribute("class");
    classOff.removeAttribute("class");
    classOn.setAttribute("class", "btn btn-sm btn-default");
    classOff.setAttribute("class", "btn btn-sm btn-]]print(off_color) print[[ active");
    $("#]] print(submit_field) print [[_input").val("]]print(off_value) print[[").trigger('change');]]
    if elementToSwitch ~= nil then
      for element = 1, #elementToSwitch do
        if ((hideOn == nil) or (hideOn == false)) then
          print('$("#'..elementToSwitch[element]..'").css("display","none");')
        else
          print('$("#'..elementToSwitch[element]..'").css("display","table-row");')
        end
      end
    end
    print [[
  }]]
  print('</script>\n')
  return(value)
end

function multipleTableButtonPrefs(label, comment, array_labels, array_values, default_value, selected_color,
                                  submit_field, redis_key, disabled, elementToSwitch, showElementArray,
                                  javascriptAfterSwitch, showElement)
  if(_POST[submit_field] ~= nil) then
    ntop.setPref(redis_key, _POST[submit_field])
    value = _POST[submit_field]
    notifyNtopng(submit_field)
  else
    value = ntop.getPref(redis_key)
    if(value == "") then
      if(default_value ~= nil) then
        ntop.setPref(redis_key, default_value)
        value = default_value
      end
    end
  end

  if (disabled == true) then
    disabled = 'disabled = ""'
  else
    disabled = ""
  end

  local objRow = ""
  if ((showElement ~= nil) and (showElement == false)) then
    objRow = " style=\"display:none\""
  else
    objRow = " style=\"display:table-row\""
  end
  if(value ~= nil) then
    if(label ~= "") then print('<tr id="row_'..submit_field..'"'..objRow..'><td width=50%><strong>'..label..'</strong><p><small>'..comment..'</small></td><td align=right>\n') end
    print('<div class="btn-group" data-toggle="buttons-radio" data-toggle-name="'..submit_field..'">')

    for nameCount = 1, #array_labels do
      local type_button = "btn-default"
      if(value == array_values[nameCount]) then
        local color
        if type(selected_color) == "table" then
          color = selected_color[nameCount]
        else
          color = selected_color
        end
        type_button = "btn-"..color.."  active"
      end
      print('<button id="id_'..array_values[nameCount]..'" value="'..array_values[nameCount]..'" type="button" class="btn btn-sm '..type_button..'" data-toggle="button">'..array_labels[nameCount]..'</button>\n')
    end
    print('</div>\n')
    print('<input type="hidden" id="id-toggle-'..submit_field..'" name="'..submit_field..'" value="'..value..'" />\n')
    print('<script>\n')
    for nameCount = 1, #array_labels do
      print('$("#id_'..array_values[nameCount]..'").click(function() {\n')
      print(' var field = $(\'#id-toggle-'..submit_field..'\');\n')
      print(' var oldval = field.val(); ')
      print(' field.val("'..array_values[nameCount]..'").trigger("change");\n')

      for indexLabel = 1, #array_labels do
        local color
        if type(selected_color) == "table" then
          color = selected_color[indexLabel]
        else
          color = selected_color
        end

        print[[ var class_]] print(array_values[indexLabel]) print[[ = document.getElementById("id_]] print(array_values[indexLabel]) print [[");
        class_]] print(array_values[indexLabel]) print[[.removeAttribute("class");]]
        if(array_values[indexLabel] == array_values[nameCount]) then
          print[[class_]] print(array_values[indexLabel]) print[[.setAttribute("class", "btn btn-sm btn-]]print(color) print[[ active");]]
        else
          print[[class_]] print(array_values[indexLabel]) print[[.setAttribute("class", "btn btn-sm btn-default");]]
        end
      end

      if (showElementArray ~= nil) then
      for indexSwitch = 1, #showElementArray do
        if (indexSwitch == nameCount) then
          if elementToSwitch ~= nil then
            for element = 1, #elementToSwitch do
              if (showElementArray[indexSwitch] == true) then
                print('$("#'..elementToSwitch[element]..'").css("display","table-row");\n')
              else
                print('$("#'..elementToSwitch[element]..'").css("display","none");\n')
              end
            end
          end
        end
      end
      end

      if javascriptAfterSwitch ~= nil then
        print(javascriptAfterSwitch)
      end

      print('});\n')
    end
    print('</script>\n')
    if(label ~= "") then print('</td></tr>') end
  end

  return(value)
end

function loggingSelector(label, comment, submit_field, redis_key)
  prefs = ntop.getPrefs()
  if prefs.has_cmdl_trace_lvl then return end

  if(_POST[submit_field] ~= nil) then
    ntop.setCache(redis_key, _POST[submit_field])
    value = _POST[submit_field]
    notifyNtopng(submit_field, _POST[submit_field])
  else
    value = ntop.getCache(redis_key)
  end

  if value == "" or value == nil then
     value = "normal"
  end

  local logging_values = {"trace", "debug", "info", "normal", "warning", "error"}
  local color_map = {"default", "success", "info", "primary", "warning", "danger"}
  local logging_keys = {}
  local color = "default"

  for i,v in ipairs(logging_values) do logging_keys[i] = firstToUpper(v) end

  multipleTableButtonPrefs("Log level", "Choose the runtime logging level.",
          logging_keys, logging_values, value, color_map, submit_field, redis_key)

  return(value)
end
