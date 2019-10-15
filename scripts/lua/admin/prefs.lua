--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/timeseries/drivers/?.lua;" .. package.path -- for influxdb
if((dirs.scriptdir ~= nil) and (dirs.scriptdir ~= "")) then package.path = dirs.scriptdir .. "/lua/modules/?.lua;" .. package.path end
require "lua_utils"
require "prefs_utils"
require "alert_utils"
local template = require "template_utils"
local callback_utils = require "callback_utils"
local lists_utils = require "lists_utils"
local telemetry_utils = require "telemetry_utils"
local alert_consts = require "alert_consts"
local slack_utils = require("slack")
local webhook_utils = require("webhook")
local recording_utils = require "recording_utils"
local remote_assistance = require "remote_assistance"
local data_retention_utils = require "data_retention_utils"
local page_utils = require("page_utils")
local ts_utils = require("ts_utils")
local influxdb = require("influxdb")
local alert_endpoints = require("alert_endpoints_utils")
local nindex_utils = nil

local email_peer_pattern = [[^(([A-Za-z0-9._%+-]|\s)+<)?[A-Za-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,4}>?$]]

if(ntop.isPro()) then
  package.path = dirs.installdir .. "/scripts/lua/pro/?.lua;" .. package.path
  package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path
  if hasNindexSupport() then
     nindex_utils = require("nindex_utils")
  end
end

sendHTTPContentTypeHeader('text/html')

local show_advanced_prefs = false
local alerts_disabled = false
local product = ntop.getInfo().product
local message_info = ""
local message_severity = "alert-warning"

-- NOTE: all the auth methods should be listed below
local auth_toggles = {
  ["local"] = "toggle_local_auth",
  ["ldap"] = "toggle_ldap_auth",
  ["http"] = "toggle_http_auth",
  ["radius"] = "toggle_radius_auth",
}

if(haveAdminPrivileges()) then
  if not table.empty(_POST) then
    if _GET["tab"] == "auth" then
      local one_enabled = false

      for k, v in pairs(auth_toggles) do
        if _POST[v] == "1" then
          one_enabled = true
          break
        end
      end

      if not one_enabled then
        -- at least one auth method should be enabled
        _POST["toggle_local_auth"] = "1"
      end
    end
  end

   if(_POST["email_sender"] ~= nil) then
      _POST["email_sender"] = unescapeHTML(_POST["email_sender"])
   end

   if(_POST["email_recipient"] ~= nil) then
      _POST["email_recipient"] = unescapeHTML(_POST["email_recipient"])
   end

   if(_POST["flush_alerts_data"] ~= nil) then
      require "alert_utils"
      flushAlertsData()

   elseif(_POST["disable_alerts_generation"] == "1") then
      require "alert_utils"
      disableAlertsGeneration()

   elseif(_POST["send_test_email"] ~= nil) then
      local email_utils = require("email")

      local success = email_utils.sendEmail("TEST MAIL", "Email notification is working")

      if success then
         message_info = i18n("prefs.email_sent_successfully")
         message_severity = "alert-success"
      else
         message_info = i18n("prefs.email_send_error", {url="https://www.ntop.org/guides/ntopng/web_gui/alerts.html#email"})
         message_severity = "alert-danger"
      end

   elseif(_POST["send_test_slack"] ~= nil) then
      local success = slack_utils.sendMessage("interface", "info", "Slack notification is working")

      if success then
         message_info = i18n("prefs.slack_sent_successfully", {channel=slack_utils.getChannelName("interface")})
         message_severity = "alert-success"
      else
         message_info = i18n("prefs.slack_send_error", {product=product})
         message_severity = "alert-danger"
      end

   elseif(_POST["send_test_webhook"] ~= nil) then
      local success = webhook_utils.sendMessage({})

      if success then
         message_info = i18n("prefs.webhook_sent_successfully")
         message_severity = "alert-success"
      else
         message_info = i18n("prefs.webhook_send_error", {product=product})
         message_severity = "alert-danger"
      end

   elseif (_POST["timeseries_driver"] == "influxdb") then
      local url = string.gsub(string.gsub( _POST["ts_post_data_url"], "http:__", "http://"), "https:__", "https://")

      if ntop.getPref("ntopng.prefs.timeseries_driver") ~= "influxdb"
        or (url ~= ntop.getPref("ntopng.prefs.ts_post_data_url"))
        or (_POST["influx_dbname"] ~= ntop.getPref("ntopng.prefs.influx_dbname"))
        or (_POST["influx_retention"] ~= ntop.getPref("ntopng.prefs.influx_retention"))
        or (_POST["toggle_influx_auth"] ~= ntop.getPref("ntopng.prefs.influx_auth_enabled"))
        or (_POST["influx_username"] ~= ntop.getPref("ntopng.prefs.influx_username"))
        or (_POST["influx_password"] ~= ntop.getPref("ntopng.prefs.influx_password")) then
         local username = nil
         local password = nil

         if _POST["toggle_influx_auth"] == "1" then
           username = _POST["influx_username"]
           password = _POST["influx_password"]
         end

         local ok, message = influxdb.init(_POST["influx_dbname"], url, tonumber(_POST["influx_retention"]),
            username, password, false --[[verbose]])
         if not ok then
            message_info = message
            message_severity = "alert-danger"

            -- reset driver to the old one
            _POST["timeseries_driver"] = nil
         elseif message then
            message_info = message
            message_severity = "alert-success"
         end
      end

   elseif(_POST["n2disk_license"] ~= nil) then
      recording_utils.setLicense(_POST["n2disk_license"])
   end

   if _POST["timeseries_driver"] ~= nil then
    ts_utils.setupAgain()
   end

   local slack_channels_key = "ntopng.prefs.alerts.slack_channels"

   for k, v in pairs(_POST) do
    if starts(k, "slack_ch_") then
      local alert_entity = tonumber(split(k, "slack_ch_")[2])
      local alert_entity_raw = alertEntityRaw(alert_entity)

      if alert_entity_raw then
        -- map entity -> channel name
        if alert_entity_raw == v then
          ntop.delHashCache(slack_channels_key, alert_entity_raw)
        else
          ntop.setHashCache(slack_channels_key, alert_entity_raw, v)
        end
      end
    end
   end

   page_utils.print_header(i18n("prefs.preferences"))

   active_page = "admin"
   dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

   prefs = ntop.getPrefs()

   if not isEmptyString(message_info) then
      print[[<div class="alert ]] print(message_severity) print[[" role="alert">]]
      print[[<button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>]]
      print(message_info)
      print[[</div>]]
   end

   print [[
	    <h2>]] print(i18n("prefs.runtime_prefs")) print[[</h2>
      ]]

   if(false) then
      io.write("------- SERVER ----------------\n")
      tprint(_SERVER)
      io.write("-------- GET ---------------\n")
      tprint(_GET)
      io.write("-------- POST ---------------\n")
      tprint(_POST)
      io.write("-----------------------\n")
   end

   if toboolean(_POST["show_advanced_prefs"]) ~= nil then
      ntop.setPref(show_advanced_prefs_key, _POST["show_advanced_prefs"])
      show_advanced_prefs = toboolean(_POST["show_advanced_prefs"])
      notifyNtopng(show_advanced_prefs_key, _POST["show_advanced_prefs"])
   else
      show_advanced_prefs = toboolean(ntop.getPref(show_advanced_prefs_key))
      if isEmptyString(show_advanced_prefs) then show_advanced_prefs = false end
   end

   if hasAlertsDisabled() then
    alerts_disabled = true
   end

local subpage_active, tab = prefsGetActiveSubpage(show_advanced_prefs, _GET["tab"])

-- ================================================================================

function printInterfaces()
  print('<form method="post">')
  print('<table class="table">')

  print('<tr><th colspan=2 class="info">'..i18n("prefs.zmq_interfaces")..'</th></tr>')

  prefsInputFieldPrefs(subpage_active.entries["ignored_interfaces"].title,
		       subpage_active.entries["ignored_interfaces"].description,
		       "ntopng.prefs.",
		       "ignored_interfaces",
		       "",
		       false, nil, nil, nil,  {attributes={spellcheck="false", pattern="^([0-9]+,)*[0-9]+$", maxlength=32}})

  prefsToggleButton(subpage_active, {
	field = "toggle_dst_with_post_nat_dst",
	default = "0",
	pref = "override_dst_with_post_nat_dst",
  })

  prefsToggleButton(subpage_active, {
	field = "toggle_src_with_post_nat_src",
	default = "0",
	pref = "override_src_with_post_nat_src",
  })

  prefsToggleButton(subpage_active, {
	field = "toggle_src_and_dst_using_ports",
	default = "0",
	pref = "use_ports_to_determine_src_and_dst",
  })

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printAlerts()
  print(
    template.gen("modal_confirm_dialog.html", {
      dialog={
        id      = "flushAlertsData",
        action  = "flushAlertsData()",
        title   = i18n("show_alerts.reset_alert_database"),
        message = i18n("show_alerts.reset_alert_database_message") .. "?",
        confirm = i18n("show_alerts.flush_data"),
        confirm_button = "btn-danger",
      }
    })
  )

  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("show_alerts.alerts")..'</th></tr>')

 if ntop.getPref("ntopng.prefs.disable_alerts_generation") == "1" then
      showElements = true
  else
      showElements = false
  end

 local elementToSwitch = { "max_num_alerts_per_entity", "max_num_flow_alerts", "row_toggle_alert_probing",
			   "row_toggle_malware_probing", "row_toggle_dns_alerts",
			   "row_toggle_flow_alerts_iface", "row_alerts_retention_header", "row_alerts_settings_header", "row_alerts_security_header",
			   "row_toggle_ssl_alerts", "row_toggle_dns_alerts", "row_toggle_remote_to_remote_alerts",
			   "row_toggle_ip_reassignment_alerts", "row_toggle_dropped_flows_alerts", "row_alerts_informative_header",
			   "row_toggle_device_first_seen_alert", "row_toggle_device_activation_alert", "row_toggle_pool_activation_alert", "row_toggle_quota_exceeded_alert", "row_toggle_mining_alerts", "row_toggle_device_protocols_alerts",
			   "row_toggle_longlived_flows_alerts", "longlived_flow_duration", "row_toggle_elephant_flows_alerts", "elephant_flow_local_to_remote_bytes", "elephant_flow_remote_to_local_bytes",
         "row_toggle_data_exfiltration", "row_toggle_external_alerts", "row_toggle_potentially_dangerous_protocols_alerts"
			}
 
 if not subpage_active.entries["toggle_mysql_check_open_files_limit"].hidden then
    elementToSwitch[#elementToSwitch+1] = "row_toggle_mysql_check_open_files_limit"
  end

  prefsToggleButton(subpage_active, {
    field = "disable_alerts_generation",
    default = "0",
    to_switch = elementToSwitch,
    on_value = "0",     -- On  means alerts enabled and thus disable_alerts_generation == 0
    off_value = "1",    -- Off for enabled alerts implies 1 for disable_alerts_generation
  })

  if ntop.getPrefs().are_alerts_enabled == true then
     showElements = true
  else
     showElements = false
  end

  prefsToggleButton(subpage_active, {
    field = "toggle_mysql_check_open_files_limit",
    default = "1",
    pref = "alerts.mysql_check_open_files_limit",
    hidden = not showElements or subpage_active.entries["toggle_mysql_check_open_files_limit"].hidden,
  })

  print('<tr id="row_alerts_security_header" ')
  if (showElements == false) then print(' style="display:none;"') end
  print('><th colspan=2 class="info">'..i18n("prefs.security_alerts")..'</th></tr>')

  prefsToggleButton(subpage_active, {
    field = "toggle_alert_probing",
    pref = "probing_alerts",
    default = "0",
    hidden = not showElements,
  })

  prefsToggleButton(subpage_active, {
    field = "toggle_ssl_alerts",
    pref = "ssl_alerts",
    default = "0",
    hidden = not showElements,
  })

  prefsToggleButton(subpage_active, {
    field = "toggle_dns_alerts",
    pref = "dns_alerts",
    default = "0",
    hidden = not showElements,
  })

  prefsToggleButton(subpage_active, {
  field = "toggle_ip_reassignment_alerts",
  pref = "ip_reassignment_alerts",
  default = "0",
  hidden = not showElements,
  })
  
  prefsToggleButton(subpage_active, {
    field = "toggle_remote_to_remote_alerts",
    pref = "remote_to_remote_alerts",
    default = "0",
    hidden = not showElements,
  })

  if ntop.isnEdge() then
     prefsToggleButton(subpage_active, {
  field = "toggle_dropped_flows_alerts",
  pref = "dropped_flows_alerts",
  default = "0",
  hidden = not showElements,
     })
  end

  prefsToggleButton(subpage_active, {
    field = "toggle_mining_alerts",
    pref = "mining_alerts",
    default = "1",
    hidden = not showElements,
  })

  prefsToggleButton(subpage_active, {
    field = "toggle_malware_probing",
    pref = "host_blacklist",
    default = "1",
    hidden = not showElements,
  })

  prefsToggleButton(subpage_active, {
    field = "toggle_external_alerts",
    pref = "external_alerts",
    default = "1",
    hidden = not showElements,
  })

  prefsToggleButton(subpage_active, {
    field = "toggle_potentially_dangerous_protocols_alerts",
    pref = "potentially_dangerous_protocols_alerts",
    default = "1",
    hidden = not showElements,
  })

  prefsToggleButton(subpage_active, {
    field = "toggle_device_protocols_alerts",
    pref = "device_protocols_alerts",
    default = "0",
    hidden = not showElements,
  })

  prefsToggleButton(subpage_active, {
    field = "toggle_longlived_flows_alerts",
    pref = "longlived_flows_alerts",
    default = ternary(prefs.are_longlived_flows_alerts_enabled, "1", "0"),
    hidden = not showElements,
  })

  prefsInputFieldPrefs(subpage_active.entries["longlived_flow_duration"].title, 
     subpage_active.entries["longlived_flow_duration"].description,
    "ntopng.prefs.", "longlived_flow_duration", prefs.longlived_flow_duration, 
    "number", showElements, nil, nil, {min=1, max=60*60*24*7, tformat="mhd"})

  prefsToggleButton(subpage_active, {
    field = "toggle_elephant_flows_alerts",
    pref = "elephant_flows_alerts",
    default = "0",
    hidden = not showElements,
  })

  prefsInputFieldPrefs(subpage_active.entries["elephant_flow_local_to_remote_bytes"].title, 
     subpage_active.entries["elephant_flow_local_to_remote_bytes"].description,
    "ntopng.prefs.", "elephant_flow_local_to_remote_bytes", prefs.elephant_flow_local_to_remote_bytes, 
    "number", showElements, nil, nil, {min=1024, format_spec = FMT_TO_DATA_BYTES, tformat="kmg"})

  prefsInputFieldPrefs(subpage_active.entries["elephant_flow_remote_to_local_bytes"].title, 
     subpage_active.entries["elephant_flow_remote_to_local_bytes"].description,
    "ntopng.prefs.", "elephant_flow_remote_to_local_bytes", prefs.elephant_flow_remote_to_local_bytes, 
    "number", showElements, nil, nil, {min=1024, format_spec = FMT_TO_DATA_BYTES, tformat="kmg"})

  prefsToggleButton(subpage_active, {
    field = "toggle_data_exfiltration",
    pref = "data_exfiltration_alerts",
    default = "1",
    hidden = not showElements,
  })

  print('<tr id="row_alerts_informative_header" ')
  if (showElements == false) then print(' style="display:none;"') end
  print('><th colspan=2 class="info">'..i18n("prefs.status_alerts")..'</th></tr>')

  prefsToggleButton(subpage_active, {
      field = "toggle_device_first_seen_alert",
      pref = "device_first_seen_alert",
      default = "0",
      hidden = not showElements,
      redis_prefix = "ntopng.prefs.alerts.",
    })

  prefsToggleButton(subpage_active, {
      field = "toggle_device_activation_alert",
      pref = "device_connection_alert",
      default = "0",
      hidden = not showElements,
      redis_prefix = "ntopng.prefs.alerts.",
    })

  prefsToggleButton(subpage_active, {
      field = "toggle_pool_activation_alert",
      pref = "pool_connection_alert",
      default = "0",
      hidden = not showElements,
      redis_prefix = "ntopng.prefs.alerts.",
    })

  if ntop.isnEdge() then
    prefsToggleButton(subpage_active, {
      field = "toggle_quota_exceeded_alert",
      pref = "quota_exceeded_alert",
      default = "0",
      hidden = not showElements,
      redis_prefix = "ntopng.prefs.alerts.",
    })
  end

  print('<tr id="row_alerts_retention_header" ')
  if (showElements == false) then print(' style="display:none;"') end
  print('><th colspan=2 class="info">'..i18n("prefs.alerts_retention")..'</th></tr>')

  prefsInputFieldPrefs(subpage_active.entries["max_num_alerts_per_entity"].title, subpage_active.entries["max_num_alerts_per_entity"].description,
        "ntopng.prefs.", "max_num_alerts_per_entity", prefs.max_num_alerts_per_entity, "number", showElements, false, nil, {min=1, --[[ TODO check min/max ]]})

  prefsInputFieldPrefs(subpage_active.entries["max_num_flow_alerts"].title, subpage_active.entries["max_num_flow_alerts"].description,
        "ntopng.prefs.", "max_num_flow_alerts", prefs.max_num_flow_alerts, "number", showElements, false, nil, {min=1, --[[ TODO check min/max ]]})

  print('<tr><th colspan=2 style="text-align:right;">')
  print('<button class="btn btn-default" type="button" onclick="$(\'#flushAlertsData\').modal(\'show\');" style="width:230px; float:left;">'..i18n("show_alerts.reset_alert_database")..'</button>')
  print('<button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button>')
  print('</th></tr>')
  print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>

  <script>
    function flushAlertsData() {
      var params = {};

      params.flush_alerts_data = "";
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

      var form = paramsToForm('<form method="post"></form>', params);
      form.appendTo('body').submit();
    }
  </script>
  ]]
end

-- ================================================================================

function printExternalAlertsReport()
  if alerts_disabled then return end

  print('<form method="post" id="external_alerts_form">')
  print('<table class="table">')

  local showElements = true

  local alert_sev_labels = {i18n("prefs.errors"), i18n("prefs.errors_and_warnings"), i18n("prefs.all")}
  local alert_sev_values = {"error", "warning", "info"}

     if ntop.sendMail then -- only if sendmail is defined, and thus, supported
	print('<tr><th colspan="2" class="info">'..i18n("prefs.email_notification")..'</th></tr>')
	
	local elementToSwitch = {"row_email_notification_severity_preference", "email_sender", "email_recipient", "smtp_server", "alerts_test"}

	prefsToggleButton(subpage_active, {
	      field = "toggle_email_notification",
	      pref = alert_endpoints.getAlertNotificationModuleEnableKey("email", true),
	      default = "0",
	      disabled = (showElements==false),
	      to_switch = elementToSwitch,
	})

	local showEmailNotificationPrefs = false
	if ntop.getPref(alert_endpoints.getAlertNotificationModuleEnableKey("email")) == "1" then
	   showEmailNotificationPrefs = true
	else
	   showEmailNotificationPrefs = false
	end

	multipleTableButtonPrefs(subpage_active.entries["slack_notification_severity_preference"].title, subpage_active.entries["slack_notification_severity_preference"].description,
				 alert_sev_labels, alert_sev_values, "error", "primary", "email_notification_severity_preference",
				 alert_endpoints.getAlertNotificationModuleSeverityKey("email"), nil, nil, nil, nil, showElements and showEmailNotificationPrefs)

	prefsInputFieldPrefs(subpage_active.entries["email_notification_server"].title, subpage_active.entries["email_notification_server"].description,
			     "ntopng.prefs.alerts.", "smtp_server",
			     "", nil, showElements and showEmailNotificationPrefs, false, true, {attributes={spellcheck="false"}, required=true, pattern="^(smtp://)?[a-zA-Z0-9-.]*(:[0-9]+)?$"})

	prefsInputFieldPrefs(subpage_active.entries["email_notification_sender"].title, subpage_active.entries["email_notification_sender"].description,
			     "ntopng.prefs.alerts.", "email_sender",
			     "", nil, showElements and showEmailNotificationPrefs, false, nil, {attributes={spellcheck="false"}, pattern=email_peer_pattern, required=true})

	prefsInputFieldPrefs(subpage_active.entries["email_notification_recipient"].title, subpage_active.entries["email_notification_recipient"].description,
			     "ntopng.prefs.alerts.", "email_recipient",
			     "", nil, showElements and showEmailNotificationPrefs, false, nil, {attributes={spellcheck="false"}, pattern=email_peer_pattern, required=true})

  print('<tr id="alerts_test" style="' .. ternary(showEmailNotificationPrefs, "", "display:none;").. '"><td><button class="btn btn-default disable-on-dirty" type="button" onclick="sendTestEmail();" style="width:230px; float:left;">'..i18n("prefs.send_test_mail")..'</button></td></tr>')
     end -- ntop.sendMail

     print('<tr><th colspan=2 class="info"><i class="fa fa-slack" aria-hidden="true"></i> '..i18n('prefs.slack_integration')..'</th></tr>')

     local elementToSwitchSlack = {"row_slack_notification_severity_preference", "slack_sender_username", "slack_webhook", "slack_test", "slack_channels"}

    prefsToggleButton(subpage_active, {
      field = "toggle_slack_notification",
      pref = alert_endpoints.getAlertNotificationModuleEnableKey("slack", true),
      default = "0",
      disabled = showElements==false,
      to_switch = elementToSwitchSlack,
    })

    local showSlackNotificationPrefs = false
    if ntop.getPref(alert_endpoints.getAlertNotificationModuleEnableKey("slack")) == "1" then
       showSlackNotificationPrefs = true
    else
       showSlackNotificationPrefs = false
    end

    multipleTableButtonPrefs(subpage_active.entries["slack_notification_severity_preference"].title, subpage_active.entries["slack_notification_severity_preference"].description,
                 alert_sev_labels, alert_sev_values, "error", "primary", "slack_notification_severity_preference",
           alert_endpoints.getAlertNotificationModuleSeverityKey("slack"), nil, nil, nil, nil, showElements and showSlackNotificationPrefs)

    prefsInputFieldPrefs(subpage_active.entries["sender_username"].title, subpage_active.entries["sender_username"].description,
             "ntopng.prefs.alerts.", "slack_sender_username",
             "ntopng Webhook", nil, showElements and showSlackNotificationPrefs, false, nil, {attributes={spellcheck="false"}, required=true})

    prefsInputFieldPrefs(subpage_active.entries["slack_webhook"].title, subpage_active.entries["slack_webhook"].description,
             "ntopng.prefs.alerts.", "slack_webhook",
             "", nil, showElements and showSlackNotificationPrefs, true, true, {attributes={spellcheck="false"}, style={width="43em"}, required=true, pattern=getURLPattern()})

    -- Channel settings
    print('<tr id="slack_channels" style="' .. ternary(showSlackNotificationPrefs, "", "display:none;").. '"><td><strong>' .. i18n("prefs.slack_channel_names") .. '</strong><p><small>' .. i18n("prefs.slack_channel_names_descr") .. '</small></p></td><td><table class="table table-bordered table-condensed"><tr><th>'.. i18n("prefs.alert_entity") ..'</th><th>' .. i18n("prefs.slack_channel") ..'</th></tr>')

    for entity_type_raw, entity in pairsByKeys(alert_consts.alert_entities) do
      local entity_type = alertEntity(entity_type_raw)
      local label = alertEntityLabel(entity_type)
      local channel = slack_utils.getChannelName(entity_type_raw)

      print('<tr><td>'.. label ..'</td><td><div class="form-group" style="margin:0"><input class="form-control input-sm" name="slack_ch_'.. entity_type ..'" pattern="[^\' \']*" value="'.. channel ..'"></div></td></tr>')
    end

    print('</table></td></tr>')

    print('<tr id="slack_test" style="' .. ternary(showSlackNotificationPrefs, "", "display:none;").. '"><td><button class="btn btn-default disable-on-dirty" type="button" onclick="sendTestSlack();" style="width:230px; float:left;">'..i18n("prefs.send_test_slack")..'</button></td></tr>')

    if ntop.syslog then
      print('<tr><th colspan="2" class="info">'..i18n("prefs.syslog_notification")..'</th></tr>')

      local alertsEnabled = showElements
      local elementToSwitch = {"row_syslog_alert_format"}

      prefsToggleButton(subpage_active, {
        field = "toggle_alert_syslog",
        pref = alert_endpoints.getAlertNotificationModuleEnableKey("syslog", true),
        default = "0",
	disabled = alertsEnabled == false,
        to_switch = elementToSwitch,
      })

      local format_labels = {i18n("prefs.syslog_alert_format_plaintext"), i18n("prefs.syslog_alert_format_json")}
      local format_values = {"plaintext", "json"}

      if ntop.getPref(alert_endpoints.getAlertNotificationModuleEnableKey("syslog")) == "0" then
        alertsEnabled = false
      end


      retVal = multipleTableButtonPrefs(subpage_active.entries["syslog_alert_format"].title,
				        subpage_active.entries["syslog_alert_format"].description,
				        format_labels, format_values,
				        "plaintext",
				        "primary",
				        "syslog_alert_format",
				        "ntopng.prefs.syslog_alert_format", nil,
				        nil, nil, nil, alertsEnabled)

    end

    if(ntop.isPro() and hasNagiosSupport()) then
      print('<tr><th colspan="2" class="info">'..i18n("prefs.nagios_integration")..'</th></tr>')

      local alertsEnabled = showElements

      local elementToSwitch = {"nagios_nsca_host","nagios_nsca_port","nagios_send_nsca_executable",
        "nagios_send_nsca_config","nagios_host_name","nagios_service_name",
        "row_nagios_notification_severity_preference"}

      prefsToggleButton(subpage_active, {
        field = "toggle_alert_nagios",
        pref = alert_endpoints.getAlertNotificationModuleEnableKey("nagios", true),
        default = "0",
        disabled = alertsEnabled == false,
        to_switch = elementToSwitch,
      })

      local showNagiosElements = showElements
      if ntop.getPref(alert_endpoints.getAlertNotificationModuleEnableKey("nagios")) == "0" then
        showNagiosElements = false
      end
      showNagiosElements = alertsEnabled and showNagiosElements

      multipleTableButtonPrefs(subpage_active.entries["slack_notification_severity_preference"].title, subpage_active.entries["slack_notification_severity_preference"].description,
                 alert_sev_labels, alert_sev_values, "error", "primary", "nagios_notification_severity_preference",
           alert_endpoints.getAlertNotificationModuleSeverityKey("nagios"), nil, nil, nil, nil, showNagiosElements, false)

      prefsInputFieldPrefs(subpage_active.entries["nagios_nsca_host"].title, subpage_active.entries["nagios_nsca_host"].description, "ntopng.prefs.", "nagios_nsca_host", prefs.nagios_nsca_host, nil, showNagiosElements, false)
      prefsInputFieldPrefs(subpage_active.entries["nagios_nsca_port"].title, subpage_active.entries["nagios_nsca_port"].description, "ntopng.prefs.", "nagios_nsca_port", prefs.nagios_nsca_port, "number", showNagiosElements, false, nil, {min=1, max=65535})
      prefsInputFieldPrefs(subpage_active.entries["nagios_send_nsca_executable"].title, subpage_active.entries["nagios_send_nsca_executable"].description, "ntopng.prefs.", "nagios_send_nsca_executable", prefs.nagios_send_nsca_executable, nil, showNagiosElements, false)
      prefsInputFieldPrefs(subpage_active.entries["nagios_send_nsca_config"].title, subpage_active.entries["nagios_send_nsca_config"].description, "ntopng.prefs.", "nagios_send_nsca_config", prefs.nagios_send_nsca_conf, nil, showNagiosElements, false)
      prefsInputFieldPrefs(subpage_active.entries["nagios_host_name"].title, subpage_active.entries["nagios_host_name"].description, "ntopng.prefs.", "nagios_host_name", prefs.nagios_host_name, nil, showNagiosElements, false)
      prefsInputFieldPrefs(subpage_active.entries["nagios_service_name"].title, subpage_active.entries["nagios_service_name"].description, "ntopng.prefs.", "nagios_service_name", prefs.nagios_service_name, nil, showNagiosElements)
    end

    -- Webhook
    print('<tr><th colspan=2 class="info">'..i18n('prefs.webhook_notification')..'</th></tr>')

    local elementToSwitchWebhook = {"row_webhook_notification_severity_preference", "webhook_url", "webhook_sharedsecret", "webhook_test", "webhook_username", "webhook_password"}

    prefsToggleButton(subpage_active, {
      field = "toggle_webhook_notification",
      pref = alert_endpoints.getAlertNotificationModuleEnableKey("webhook", true),
      default = "0",
      disabled = showElements==false,
      to_switch = elementToSwitchWebhook,
    })

    local showWebhookNotificationPrefs = false
    if ntop.getPref(alert_endpoints.getAlertNotificationModuleEnableKey("webhook")) == "1" then
       showWebhookNotificationPrefs = true
    else
       showWebhookNotificationPrefs = false
    end

    multipleTableButtonPrefs(subpage_active.entries["webhook_notification_severity_preference"].title, subpage_active.entries["webhook_notification_severity_preference"].description,
                 alert_sev_labels, alert_sev_values, "error", "primary", "webhook_notification_severity_preference",
           alert_endpoints.getAlertNotificationModuleSeverityKey("webhook"), nil, nil, nil, nil, showElements and showWebhookNotificationPrefs)

    prefsInputFieldPrefs(subpage_active.entries["webhook_url"].title, subpage_active.entries["webhook_url"].description,
             "ntopng.prefs.alerts.", "webhook_url",
             "", nil, showElements and showWebhookNotificationPrefs, true, true, {attributes={spellcheck="false"}, style={width="43em"}, required=true, pattern=getURLPattern()})

    prefsInputFieldPrefs(subpage_active.entries["webhook_sharedsecret"].title, subpage_active.entries["webhook_sharedsecret"].description,
             "ntopng.prefs.alerts.", "webhook_sharedsecret",
             "", nil, showElements and showWebhookNotificationPrefs, false, nil, {attributes={spellcheck="false"}, required=false})

  prefsInputFieldPrefs(subpage_active.entries["webhook_username"].title, subpage_active.entries["webhook_username"].description,
	     "ntopng.prefs.alerts.", "webhook_username", 
             "", false, showElements and showWebhookNotificationPrefs, nil, nil,  {attributes={spellcheck="false"}, pattern="[^\\s]+", required=false})

  prefsInputFieldPrefs(subpage_active.entries["webhook_password"].title, subpage_active.entries["webhook_password"].description,
	     "ntopng.prefs.alerts.", "webhook_password", 
             "", "password", showElements and showWebhookNotificationPrefs, nil, nil,  {attributes={spellcheck="false"}, pattern="[^\\s]+", required=false})

    print('<tr id="webhook_test" style="' .. ternary(showWebhookNotificationPrefs, "", "display:none;").. '"><td><button class="btn btn-default disable-on-dirty" type="button" onclick="sendTestWebhook();" style="width:230px; float:left;">'..i18n("prefs.send_test_webhook")..'</button></td></tr>')

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]

  print[[<script>
    function sendTestEmail() {
      var params = {};

      params.send_test_email = "";
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

      var form = paramsToForm('<form method="post"></form>', params);
      form.appendTo('body').submit();
    }

    function sendTestSlack() {
      var params = {};

      params.send_test_slack = "";
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

      var form = paramsToForm('<form method="post"></form>', params);
      form.appendTo('body').submit();
    }

    function sendTestWebhook() {
      var params = {};

      params.send_test_webhook = "";
      params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

      var form = paramsToForm('<form method="post"></form>', params);
      form.appendTo('body').submit();
    }

    function replace_email_special_characters(event) {
      var form = $(this);

      // e.g. when form is invalid
      if(event.isDefaultPrevented())
        return;

      // this is necessary to escape "<" and ">" which are blocked on the backend to prevent injection
      $("[name='email_sender'],[name='email_recipient']", form).each(function() {
        var name = $(this).attr("name");
        $(this).removeAttr("name");

        $('<input type="hidden" name="' + name + '">')
          .val(encodeURI($(this).val()))
          .appendTo(form);
      });
    }

    $(function() {
      $("#external_alerts_form").submit(replace_email_special_characters);
    });
  </script>]]
end

-- ================================================================================

function printProtocolPrefs()
  print('<form method="post">')

  print('<table class="table">')

  print('<tr><th colspan=2 class="info">HTTP</th></tr>')

  prefsToggleButton(subpage_active, {
    field = "toggle_top_sites",
    pref = "host_top_sites_creation",
    default = "0",
  })

  --[[
  print('<tr><th colspan=2 class="info">TCP</th></tr>')

  prefsInputFieldPrefs(subpage_active.entries["ewma_alpha_percent"].title, subpage_active.entries["ewma_alpha_percent"].description,
		       "ntopng.prefs.", "ewma_alpha_percent", prefs.ewma_alpha_percent, "number",
		       true,
		       nil, nil, {min=1, max=99,})
  --]]

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')

  print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printNetworkDiscovery()
   print('<form method="post">')
   print('<table class="table">')

   print('<tr><th colspan=2 class="info">'..i18n("prefs.network_discovery")..'</th></tr>')

   local elementToSwitch = {"network_discovery_interval"}

   prefsToggleButton(subpage_active, {
    field = "toggle_network_discovery",
    default = "0",
    pref = "is_periodic_network_discovery_enabled",
    to_switch = elementToSwitch,
  })

   local showNetworkDiscoveryInterval = false
   if ntop.getPref("ntopng.prefs.is_periodic_network_discovery_enabled") == "1" then
      showNetworkDiscoveryInterval = true
   end

   local interval = ntop.getPref("ntopng.prefs.network_discovery_interval")

   if isEmptyString(interval) then -- set a default value
      interval = 15 * 60 -- 15 minutes
      ntop.setPref("ntopng.prefs.network_discovery_interval", tostring(interval))
   end

   prefsInputFieldPrefs(subpage_active.entries["network_discovery_interval"].title, subpage_active.entries["network_discovery_interval"].description,
    "ntopng.prefs.", "network_discovery_interval", interval, "number", showNetworkDiscoveryInterval, nil, nil, {min=60 * 15, tformat="mhd"})

   print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')

   print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
    </form>]]
end


-- ================================================================================

function printTelemetry()
   print('<form method="post">')
   print('<table class="table">')

   print('<tr><th colspan=2 class="info">'..i18n("prefs.telemetry")..'</th></tr>')

   local t_labels = {i18n("prefs.telemetry_do_not_contribute")..' <i class="fa fa-frown-o"></i>',
		     i18n("prefs.telemetry_contribute")..' <i class="fa fa-heart"></i>'}
   local t_values = {"0", "1"}
   local elementToSwitch = {"telemetry_email"}
   local showElementArray = {false, true}

   multipleTableButtonPrefs(subpage_active.entries["toggle_send_telemetry_data"].title,
			    subpage_active.entries["toggle_send_telemetry_data"].description,
			    t_labels, t_values,
			    "", -- leave the default empty so one is forced to either chose opt-in or opt-out
			    "primary", "toggle_send_telemetry_data", "ntopng.prefs.send_telemetry_data", nil,
			    elementToSwitch, showElementArray, javascriptAfterSwitch, true--[[show]])

   prefsInputFieldPrefs(subpage_active.entries["telemetry_email"].title,
			subpage_active.entries["telemetry_email"].description,
		       "ntopng.prefs.",
		       "telemetry_email",
		       "",
		       false,
		       telemetry_utils.telemetry_enabled(),
		       nil, nil,  {attributes={spellcheck="false"}, pattern=email_peer_pattern, required=false})

   print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')

   print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
    </form>]]
end

-- ================================================================================

function printRecording()
  local n2disk_info = recording_utils.getN2diskInfo()

  print('<form method="post">')
  print('<table class="table">')

  print('<tr><th colspan=2 class="info">'..i18n("prefs.license")..'</th></tr>')

  prefsInputFieldPrefs(subpage_active.entries["n2disk_license"].title, subpage_active.entries["n2disk_license"].description.."<br>"
      ..ternary(n2disk_info.version ~= nil, i18n("prefs.n2disk_license_version", {version=n2disk_info.version}).."<br>", "")
      ..ternary(n2disk_info.systemid ~= nil, i18n("prefs.n2disk_license_systemid", {systemid=n2disk_info.systemid}), ""),
    "ntopng.prefs.", "n2disk_license",
    ternary(n2disk_info.license ~= nil, n2disk_info.license, ""),
    false, nil, nil, nil, {style={width="25em;"}, min = 50, max = 64,
    pattern = getLicensePattern()})

  print('<tr><th colspan=2 class="info">'..i18n("traffic_recording.settings")..'</th></tr>')

  prefsInputFieldPrefs(subpage_active.entries["max_extracted_pcap_bytes"].title, 
     subpage_active.entries["max_extracted_pcap_bytes"].description,
    "ntopng.prefs.", "max_extracted_pcap_bytes", prefs.max_extracted_pcap_bytes, 
    "number", true, nil, nil, {min=10*1024*1024, format_spec = FMT_TO_DATA_BYTES, tformat="mg"})

  -- ######################

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
    </form>]]
end

-- ================================================================================

function printRemoteAssitance()
  if not remote_assistance.isAvailable() then
    return
  end

  print('<form method="post">')
  print('<table class="table">')

  print('<tr><th colspan=2 class="info">'..i18n("remote_assistance.remote_assistance")..'</th></tr>')
  prefsInputFieldPrefs(subpage_active.entries["n2n_supernode"].title, 
                       subpage_active.entries["n2n_supernode"].description,
		       "ntopng.prefs.remote_assistance.", "supernode", remote_assistance.getSupernode(), nil,
		       true, nil, nil, {attributes = {pattern = "[0-9.\\-A-Za-z]+(:[0-9]+)?", required = "required"}})

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
    </form>]]
end

-- ================================================================================

function printDataRetention()
  print('<form method="post">')
  print('<table class="table">')

  print('<tr><th colspan=2 class="info">'..i18n("prefs.data_retention")..'</th></tr>')

  prefsInputFieldPrefs(subpage_active.entries["data_retention"].title,
		       subpage_active.entries["data_retention"].description,
		       "ntopng.prefs.", "data_retention_days", data_retention_utils.getDefaultRetention(), "number", nil, nil, nil, {min=1, max=365 * 10})

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
    </form>]]
end

-- ================================================================================

function printMisc()
  print('<form method="post">')
  print('<table class="table">')

  print('<tr><th colspan=2 class="info">'..i18n("prefs.web_user_interface")..'</th></tr>')
  if prefs.is_autologout_enabled == true then
    prefsToggleButton(subpage_active, {
      field = "toggle_autologout",
      default = "1",
      pref = "is_autologon_enabled",
    })
  end

  prefsInputFieldPrefs(subpage_active.entries["max_ui_strlen"].title, subpage_active.entries["max_ui_strlen"].description,
		       "ntopng.prefs.", "max_ui_strlen", prefs.max_ui_strlen, "number", nil, nil, nil, {min=3, max=128})

  prefsInputFieldPrefs(subpage_active.entries["mgmt_acl"].title, subpage_active.entries["mgmt_acl"].description,
		       "ntopng.prefs.",
		       "http_acl_management_port",
		       "", false, nil, nil, nil, {style = {width = "25em;"},
						  attributes = {spellcheck = "false", maxlength = 64, pattern = getACLPattern()}})

  prefsInputFieldPrefs(subpage_active.entries["google_apis_browser_key"].title, subpage_active.entries["google_apis_browser_key"].description,
		       "ntopng.prefs.",
		       "google_apis_browser_key",
		       "", false, nil, nil, nil, {style={width="25em;"}, attributes={spellcheck="false"} --[[ Note: Google API keys can vary in format ]] })

  -- ######################

  print('<tr><th colspan=2 class="info">'..i18n("prefs.report")..'</th></tr>')

  local t_labels = {i18n("bytes"), i18n("packets")}
  local t_values = {"bps", "pps"}

  multipleTableButtonPrefs(subpage_active.entries["toggle_thpt_content"].title, subpage_active.entries["toggle_thpt_content"].description,
			   t_labels, t_values, "bps", "primary", "toggle_thpt_content", "ntopng.prefs.thpt_content")

  -- ######################

  if ntop.isPro() then
     t_labels = {i18n("topk_heuristic.precision.disabled"),
		 i18n("topk_heuristic.precision.more_accurate"),
		 i18n("topk_heuristic.precision.less_accurate"),
		 i18n("topk_heuristic.precision.aggressive")}
     t_values = {"disabled", "more_accurate", "accurate", "aggressive"}

     multipleTableButtonPrefs(subpage_active.entries["topk_heuristic_precision"].title,
			      subpage_active.entries["topk_heuristic_precision"].description,
			      t_labels, t_values, "more_accurate", "primary", "topk_heuristic_precision",
			      "ntopng.prefs.topk_heuristic_precision")
  end

  -- ######################

  if(haveAdminPrivileges()) then
     print('<tr><th colspan=2 class="info">'..i18n("hosts")..'</th></tr>')

     local h_labels = {i18n("prefs.no_host_mask"), i18n("prefs.local_host_mask"), i18n("prefs.remote_host_mask")}
     local h_values = {"0", "1", "2"}

     multipleTableButtonPrefs(subpage_active.entries["toggle_host_mask"].title,
			      subpage_active.entries["toggle_host_mask"].description,
			      h_labels, h_values, "0", "primary", "toggle_host_mask", "ntopng.prefs.host_mask")

    prefsToggleButton(subpage_active, {
			 field = "toggle_arp_matrix_generation",
			 default = "0",
			 pref = "arp_matrix_generation",
			 to_switch = nil,
    })
  end

  -- #####################

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
    </form>]]

end

-- ================================================================================

local function printAuthDuration()
  print('<tr><th colspan=2 class="info">'..i18n("prefs.authentication_duration")..'</th></tr>')

  prefsInputFieldPrefs(subpage_active.entries["authentication_duration"].title, subpage_active.entries["authentication_duration"].description,
		       "ntopng.prefs.","auth_session_duration",
		       prefs.auth_session_duration, "number", true, nil, nil,
		       {min = 60 --[[ 1 minute --]], max = 86400 * 7 --[[ 7 days --]],
			tformat="mhd"})

  prefsToggleButton(subpage_active, {
  		       field = "toggle_auth_session_midnight_expiration",
  		       default = "0",
  		       pref = "auth_session_midnight_expiration",
  })

end

-- ================================================================================

local function printLdapAuth()
  if not ntop.isPro() then return end

  print('<tr><th colspan=2 class="info">'..i18n("prefs.ldap_authentication")..'</th></tr>')

  local elementToSwitch = {"row_multiple_ldap_account_type", "row_toggle_ldap_anonymous_bind","server","bind_dn", "bind_pwd", "ldap_server_address", "search_path", "user_group", "admin_group", "row_toggle_ldap_referrals"}

  local javascriptAfterSwitch = "";
  javascriptAfterSwitch = javascriptAfterSwitch.."  if($(\"#toggle_ldap_auth_input\").val() == \"1\") {\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."    if($(\"#toggle_ldap_anonymous_bind_input\").val() == \"0\") {\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."      $(\"#bind_dn\").css(\"display\",\"table-row\");\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."      $(\"#bind_pwd\").css(\"display\",\"table-row\");\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."    } else {\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."      $(\"#bind_dn\").css(\"display\",\"none\");\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."      $(\"#bind_pwd\").css(\"display\",\"none\");\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."    }\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."  }\n"

  prefsToggleButton(subpage_active, {
	      field = auth_toggles.ldap,
	      pref = "ldap.auth_enabled",
	      default = "0",
	      to_switch = elementToSwitch,
        js_after_switch = javascriptAfterSwitch,
	})

  local showElements = (ntop.getPref("ntopng.prefs.ldap.auth_enabled") == "1")

  local labels_account = {i18n("prefs.posix"), i18n("prefs.samaccount")}
  local values_account = {"posix","samaccount"}
  multipleTableButtonPrefs(subpage_active.entries["multiple_ldap_account_type"].title, subpage_active.entries["multiple_ldap_account_type"].description,
        labels_account, values_account, "posix", "primary", "multiple_ldap_account_type", "ntopng.prefs.ldap.account_type", nil, nil, nil, nil, showElements)

  prefsInputFieldPrefs(subpage_active.entries["ldap_server_address"].title, subpage_active.entries["ldap_server_address"].description,
        "ntopng.prefs.ldap", "ldap_server_address", "ldap://localhost:389", nil, showElements, true, true, {attributes={pattern="ldap(s)?://[0-9.\\-A-Za-z]+(:[0-9]+)?", spellcheck="false", required="required", maxlength=255}})

  local elementToSwitchBind = {"bind_dn","bind_pwd"}
  prefsToggleButton(subpage_active, {
      field = "toggle_ldap_anonymous_bind",
      default = "1",
      pref = "ldap.anonymous_bind",
      to_switch = elementToSwitchBind,
      reverse_switch = true,
      hidden = not showElements,
    })

  local showEnabledAnonymousBind = false
    if ntop.getPref("ntopng.prefs.ldap.anonymous_bind") == "0" then
  showEnabledAnonymousBind = true
  end
  local showElementsBind = showElements
  if showElements == true then
    showElementsBind = showEnabledAnonymousBind
  end

  prefsInputFieldPrefs(subpage_active.entries["bind_dn"].title, subpage_active.entries["bind_dn"].description .. "\"CN=ntop_users,DC=ntop,DC=org,DC=local\".", "ntopng.prefs.ldap", "bind_dn", "", nil, showElementsBind, true, false, {attributes={spellcheck="false", maxlength=255}})
  prefsInputFieldPrefs(subpage_active.entries["bind_pwd"].title, subpage_active.entries["bind_pwd"].description, "ntopng.prefs.ldap", "bind_pwd", "", "password", showElementsBind, true, false, {attributes={maxlength=255}})
  prefsInputFieldPrefs(subpage_active.entries["search_path"].title, subpage_active.entries["search_path"].description, "ntopng.prefs.ldap", "search_path", "", "text", showElements, nil, nil, {attributes={spellcheck="false", maxlength=255}})
  prefsInputFieldPrefs(subpage_active.entries["user_group"].title, subpage_active.entries["user_group"].description, "ntopng.prefs.ldap", "user_group", "", "text", showElements, nil, nil, {attributes={spellcheck="false", maxlength=255}})
  prefsInputFieldPrefs(subpage_active.entries["admin_group"].title, subpage_active.entries["admin_group"].description, "ntopng.prefs.ldap", "admin_group", "", "text", showElements, nil, nil, {attributes={spellcheck="false", maxlength=255}})

  prefsToggleButton(subpage_active, {
    field = "toggle_ldap_referrals",
    default = "1",
    pref = "ldap.follow_referrals",
    reverse_switch = true,
    hidden = not showElements,
  })
end

-- #####################

local function printRadiusAuth()
  if subpage_active.entries["toggle_radius_auth"].hidden then
    return
  end

  print('<tr><th colspan=2 class="info">'..i18n("prefs.radius_auth")..'</th></tr>')

  local elementToSwitch = {"radius_server_address", "radius_secret", "radius_admin_group"}

  prefsToggleButton(subpage_active, {
	      field = auth_toggles.radius,
	      pref = "radius.auth_enabled",
	      default = "0",
	      to_switch = elementToSwitch,
	})

  local showElements = (ntop.getPref("ntopng.prefs.radius.auth_enabled") == "1")

  prefsInputFieldPrefs(subpage_active.entries["radius_server"].title, subpage_active.entries["radius_server"].description,
    "ntopng.prefs.radius", "radius_server_address", "127.0.0.1:1812", nil, showElements, true, false,
    {attributes={spellcheck="false", maxlength=255, required="required", pattern="[0-9.\\-A-Za-z]+:[0-9]+"}})

  -- https://github.com/FreeRADIUS/freeradius-client/blob/7b7473ab78ca5f99e083e5e6c16345b7c2569db1/include/freeradius-client.h#L395
  prefsInputFieldPrefs(subpage_active.entries["radius_secret"].title, subpage_active.entries["radius_secret"].description,
    "ntopng.prefs.radius", "radius_secret", "", "password", showElements, true, false,
    {attributes={spellcheck="false", maxlength=48, required="required"}})

  prefsInputFieldPrefs(subpage_active.entries["radius_admin_group"].title, subpage_active.entries["radius_admin_group"].description,
    "ntopng.prefs.radius", "radius_admin_group", "", nil, showElements, true, false,
    {attributes={spellcheck="false", maxlength=255, pattern="[^\\s]+"}})
end

-- #####################

local function printHttpAuth()
  print('<tr><th colspan=2 class="info">'..i18n("prefs.http_auth")..'</th></tr>')

  local elementToSwitch = {"http_auth_url"}

  prefsToggleButton(subpage_active, {
	      field = auth_toggles.http,
	      pref = "http_authenticator.auth_enabled",
	      default = "0",
	      to_switch = elementToSwitch,
	})

  local showElements = (ntop.getPref("ntopng.prefs.http_authenticator.auth_enabled") == "1")

  prefsInputFieldPrefs(subpage_active.entries["http_auth_server"].title, subpage_active.entries["http_auth_server"].description,
    "ntopng.prefs.http_authenticator", "http_auth_url", "", nil, showElements, true, true --[[ allowUrls ]],
    {attributes={spellcheck="false", maxlength=255, required="required", pattern=getURLPattern()}})
end

-- #####################

local function printLocalAuth()
  print('<tr><th colspan=2 class="info">'..i18n("prefs.local_auth")..'</th></tr>')

  prefsToggleButton(subpage_active, {
	      field = auth_toggles["local"],
	      pref = "local.auth_enabled",
	      default = "1",
	})
end

-- #####################

function printAuthentication()
  print('<form method="post">')
  print('<table class="table">')

  local entries = subpage_active.entries

  printAuthDuration()

  -- Note: order must correspond to evaluation order in Ntop.cpp
  print('<tr><th class="info" colspan="2">'..i18n("prefs.client_x509_auth")..'</th></tr>')
  prefsToggleButton(subpage_active,{
	field = "toggle_client_x509_auth",
	default = "0",
	pref = "is_client_x509_auth_enabled",
  })
  if not entries.toggle_ldap_auth.hidden then
    printLdapAuth()
  end
  if not entries.toggle_radius_auth.hidden then
    printRadiusAuth()
  end
  if not entries.toggle_http_auth.hidden then
    printHttpAuth()
  end
  if not entries.toggle_local_auth.hidden then
    printLocalAuth()
  end

  if not ntop.isnEdge() then
    prefsInformativeField(i18n("notes"), i18n("prefs.auth_methods_order"))
  else
    prefsInformativeField(i18n("notes"), i18n("nedge.authentication_gui_and_captive_portal",
      {product = product, url = ntop.getHttpPrefix() .. "/lua/pro/nedge/system_setup/captive_portal.lua"}))
  end

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />]]
  print('</form>')
end

-- ================================================================================

function printInMemory()
  print('<form id="localRemoteTimeoutForm" method="post">')

  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("prefs.stats_reset")..'</th></tr>')
  prefsToggleButton(subpage_active, {
    field = "toggle_midnight_stats_reset",
    default = "0",
    pref = "midnight_stats_reset_enabled",
  })

  print('<tr><th colspan=2 class="info">'..i18n("prefs.local_hosts_cache_settings")..'</th></tr>')

  prefsToggleButton(subpage_active, {
    field = "toggle_local_host_cache_enabled",
    default = "1",
    pref = "is_local_host_cache_enabled",
    to_switch = {"local_host_cache_duration"},
  })

  local showLocalHostCacheInterval = false
  if ntop.getPref("ntopng.prefs.is_local_host_cache_enabled") == "1" then
    showLocalHostCacheInterval = true
  end

  prefsInputFieldPrefs(subpage_active.entries["local_host_cache_duration"].title, subpage_active.entries["local_host_cache_duration"].description,
    "ntopng.prefs.","local_host_cache_duration", prefs.local_host_cache_duration, "number", showLocalHostCacheInterval, nil, nil, {min=60, tformat="mhd"})

  prefsToggleButton(subpage_active, {
    field = "toggle_active_local_host_cache_enabled",
    default = "0",
    pref = "is_active_local_host_cache_enabled",
    to_switch = {"active_local_host_cache_interval"},
  })

  local showActiveLocalHostCacheInterval = false
  if ntop.getPref("ntopng.prefs.is_active_local_host_cache_enabled") == "1" then
    showActiveLocalHostCacheInterval = true
  end

  prefsInputFieldPrefs(subpage_active.entries["active_local_host_cache_interval"].title, subpage_active.entries["active_local_host_cache_interval"].description,
    "ntopng.prefs.", "active_local_host_cache_interval", prefs.active_local_host_cache_interval or 3600, "number", showActiveLocalHostCacheInterval, nil, nil, {min=60, tformat="mhd"})

  print('</table>')
  
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("prefs.idle_timeout_settings")..'</th></tr>')

  prefsInputFieldPrefs(subpage_active.entries["local_host_max_idle"].title, subpage_active.entries["local_host_max_idle"].description,
		       "ntopng.prefs.","local_host_max_idle", prefs.local_host_max_idle, "number", nil, nil, nil,
		       {min=1, max=86400, tformat="smh", attributes={["data-localremotetimeout"]="localremotetimeout"}})

  prefsInputFieldPrefs(subpage_active.entries["non_local_host_max_idle"].title, subpage_active.entries["non_local_host_max_idle"].description,
		       "ntopng.prefs.", "non_local_host_max_idle", prefs.non_local_host_max_idle, "number", nil, nil, nil,
		       {min=1, max=86400, tformat="smh"})
  
  prefsInputFieldPrefs(subpage_active.entries["flow_max_idle"].title, subpage_active.entries["flow_max_idle"].description,
		       "ntopng.prefs.", "flow_max_idle", prefs.flow_max_idle, "number", nil, nil, nil,
		       {min=1, max=3600, tformat="smh"})

  prefsInputFieldPrefs(subpage_active.entries["housekeeping_frequency"].title,
		       subpage_active.entries["housekeeping_frequency"].description,
		       "ntopng.prefs.", "housekeeping_frequency", prefs.housekeeping_frequency, "number", nil, nil, nil, {min = 1, max = 60})

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')
  print('</table>')
  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>

  <script>
    function localRemoteTimeoutValidator() {
      var form = $("#localRemoteTimeoutForm");
      var local_timeout = resol_selector_get_raw($("input[name='local_host_max_idle']", form));
      var remote_timeout = resol_selector_get_raw($("input[name='non_local_host_max_idle']", form));

      if ((local_timeout != null) && (remote_timeout != null)) {
        if (local_timeout < remote_timeout)
          return false;
      }

      return true;
    }
  
    var idleFormValidatorOptions = {
      disable: true,
      custom: {
         localremotetimeout: localRemoteTimeoutValidator,
      }, errors: {
         localremotetimeout: "Cannot be less then Remote Host Idle Timeout",
      }
   }

   $("#localRemoteTimeoutForm")
      .validator(idleFormValidatorOptions);

   /* Retrigger the validation every second to clear outdated errors */
   setInterval(function() {
      $("#localRemoteTimeoutForm").data("bs.validator").validate();
    }, 1000);
  </script>
  ]]
end

-- ================================================================================

function printStatsTimeseries()
  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n('prefs.timeseries_database')..'</th></tr>')

  local elementToSwitch = {"ts_post_data_url", "influx_dbname", "influx_retention", "row_toggle_influx_auth", "influx_username", "influx_password", "row_ts_high_resolution"}
  local showElementArray = {false, true, false}

  local javascriptAfterSwitch = "";
  javascriptAfterSwitch = javascriptAfterSwitch.."  if($(\"#id-toggle-timeseries_driver\").val() == \"influxdb\") {\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."    if($(\"#toggle_influx_auth_input\").val() == \"1\") {\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."      $(\"#influx_username\").css(\"display\",\"table-row\");\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."      $(\"#influx_password\").css(\"display\",\"table-row\");\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."    } else {\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."      $(\"#influx_username\").css(\"display\",\"none\");\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."      $(\"#influx_password\").css(\"display\",\"none\");\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."    }\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."    $(\"#old_rrd_files_retention\").css(\"display\",\"none\");\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."  } else if($(\"#id-toggle-timeseries_driver\").val() == \"rrd\") {\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."    $(\"#old_rrd_files_retention\").css(\"display\",\"table-row\");\n"
  javascriptAfterSwitch = javascriptAfterSwitch.."  }\n"

  local active_driver = "rrd"
  local influx_active = false

  if not ntop.isWindows() then
    multipleTableButtonPrefs(subpage_active.entries["multiple_timeseries_database"].title,
				    subpage_active.entries["multiple_timeseries_database"].description,
				    {"RRD", "InfluxDB", "Prometheus [Export Only]"}, {"rrd", "influxdb", "prometheus"},
				    "rrd",
				    "primary",
				    "timeseries_driver",
				    "ntopng.prefs.timeseries_driver", nil,
				    elementToSwitch, showElementArray, javascriptAfterSwitch, true--[[show]])

    active_driver = ntop.getPref("ntopng.prefs.timeseries_driver")
    influx_active = (active_driver == "influxdb")
  end

  prefsInputFieldPrefs(subpage_active.entries["influxdb_url"].title,
		       subpage_active.entries["influxdb_url"].description,
		       "ntopng.prefs.",
		       "ts_post_data_url",
		       "http://localhost:8086",
		       false, influx_active, nil, nil,  {attributes={spellcheck="false"}, pattern=getURLPattern(), required=true})

  if ntop.isnEdge() and ntop.getPref("ntopng.prefs.influx_dbname") == "ntopng edge" then
     -- Fixes issue #1939 with wrong deployed nedge db name
     ntop.delCache("ntopng.prefs.influx_dbname")
  end
  prefsInputFieldPrefs(subpage_active.entries["influxdb_dbname"].title, subpage_active.entries["influxdb_dbname"].description,
		       "ntopng.prefs.", "influx_dbname", product:gsub(' ' , '_'), nil, influx_active, nil, nil, {pattern="[A-z,0-9,_]+"})

  prefsToggleButton(subpage_active, {
	field = "toggle_influx_auth",
	default = "0",
	pref = "influx_auth_enabled",
	to_switch = {"influx_username", "influx_password"},
  hidden = not influx_active,
  })

  local auth_enabled = influx_active and (ntop.getPref("ntopng.prefs.influx_auth_enabled") == "1")

  prefsInputFieldPrefs(subpage_active.entries["influxdb_username"].title, subpage_active.entries["influxdb_username"].description,
		       "ntopng.prefs.",
		       "influx_username", "",
           false, auth_enabled, nil, nil,  {attributes={spellcheck="false"}, pattern="[^\\s]+"})

  prefsInputFieldPrefs(subpage_active.entries["influxdb_password"].title, subpage_active.entries["influxdb_password"].description,
		       "ntopng.prefs.",
		       "influx_password", "",
           "password", auth_enabled, nil, nil,  {attributes={spellcheck="false"}, pattern="[^\\s]+"})

  local ts_slots_labels = {"10s", "30s", "1m", "5m"}
  local ts_slots_values = {"10", "30", "60", "300"}
  -- Currently, high-resolution-timeseries seem to only work when the default housekeeping frequency is in place.
  -- As a TODO, it would be nice to relax this assumption.
  local has_custom_housekeeping = (tonumber(ntop.getPref("ntopng.prefs.housekeeping_frequency")) or 5) ~= 5

  multipleTableButtonPrefs(subpage_active.entries["timeseries_resolution_resolution"].title,
				    subpage_active.entries["timeseries_resolution_resolution"].description .. ternary(has_custom_housekeeping, "<br>" .. i18n("prefs.note_timeseries_resolution_disabled", {pref=i18n("prefs.housekeeping_frequency_title")}), ""),
				    ts_slots_labels, ts_slots_values,
				    "60",
				    "primary",
				    "ts_high_resolution",
				    "ntopng.prefs.ts_high_resolution", has_custom_housekeeping,
				    nil, nil, nil, influx_active)

  print('<tr><th colspan=2 class="info">'..i18n('prefs.interfaces_timeseries')..'</th></tr>')

  -- TODO: make also per-category interface RRDs
  local l7_rrd_labels = {i18n("prefs.none"),
		  i18n("prefs.per_protocol"),
		  i18n("prefs.per_category"),
		  i18n("prefs.both")
                  }
  local l7_rrd_values = {"none",
		  "per_protocol",
		  "per_category",
		  "both"}

  local elementToSwitch = { }
  local showElementArray = nil -- { true, false, false }
  local javascriptAfterSwitch = "";

  prefsToggleButton(subpage_active, {
	field = "toggle_interface_traffic_rrd_creation",
	default = "1",
	pref = "interface_rrd_creation",
	to_switch = {"row_interfaces_ndpi_timeseries_creation"},
  })

  local showElement = ntop.getPref("ntopng.prefs.interface_rrd_creation") == "1"

  retVal = multipleTableButtonPrefs(subpage_active.entries["toggle_ndpi_timeseries_creation"].title,
				    subpage_active.entries["toggle_ndpi_timeseries_creation"].description,
				    l7_rrd_labels, l7_rrd_values,
				    "per_protocol",
				    "primary",
				    "interfaces_ndpi_timeseries_creation",
				    "ntopng.prefs.interface_ndpi_timeseries_creation", nil,
				    elementToSwitch, showElementArray, javascriptAfterSwitch, showElement)


  print('<tr><th colspan=2 class="info">'..i18n('prefs.local_hosts_timeseries')..'</th></tr>')

  prefsToggleButton(subpage_active, {
    field = "toggle_local_hosts_traffic_rrd_creation",
    default = "1",
    pref = "host_rrd_creation",
    to_switch = {"row_hosts_ndpi_timeseries_creation"},
  })

  local showElement = ntop.getPref("ntopng.prefs.host_rrd_creation") == "1"

  retVal = multipleTableButtonPrefs(subpage_active.entries["toggle_ndpi_timeseries_creation"].title,
				    subpage_active.entries["toggle_ndpi_timeseries_creation"].description,
				    l7_rrd_labels, l7_rrd_values,
				    "none",
				    "primary",
				    "hosts_ndpi_timeseries_creation",
				    "ntopng.prefs.host_ndpi_timeseries_creation", nil,
				    elementToSwitch, showElementArray, javascriptAfterSwitch, showElement)

  print('<tr><th colspan=2 class="info">'..i18n('prefs.l2_devices_timeseries')..'</th></tr>')

  prefsToggleButton(subpage_active, {
    field = "toggle_l2_devices_traffic_rrd_creation",
    default = "0",
    pref = "l2_device_rrd_creation",
    to_switch = {"row_l2_devices_ndpi_timeseries_creation"},
  })

  local l7_rrd_labels = {i18n("prefs.none"),
			 i18n("prefs.per_category")}
  local l7_rrd_values = {"none",
			 "per_category"}

  local showElement = ntop.getPref("ntopng.prefs.l2_device_rrd_creation") == "1"

  retVal = multipleTableButtonPrefs(subpage_active.entries["toggle_ndpi_timeseries_creation"].title,
				    subpage_active.entries["toggle_ndpi_timeseries_creation"].description,
				    l7_rrd_labels, l7_rrd_values,
				    "none",
				    "primary",
				    "l2_devices_ndpi_timeseries_creation",
				    "ntopng.prefs.l2_device_ndpi_timeseries_creation", nil,
				    elementToSwitch, showElementArray, javascriptAfterSwitch, showElement)


  print('<tr><th colspan=2 class="info">'..i18n('prefs.other_timeseries')..'</th></tr>')

  local info = ntop.getInfo()

  if ntop.isPro() then
    prefsToggleButton(subpage_active, {
      field = "toggle_flow_rrds",
      default = "0",
      pref = "flow_device_port_rrd_creation",
      disabled = not info["version.enterprise_edition"],
    })

    prefsToggleButton(subpage_active, {
      field = "toggle_pools_rrds",
      default = "0",
      pref = "host_pools_rrd_creation",
    })
  end

  prefsToggleButton(subpage_active, {
    field = "toggle_tcp_flags_rrds",
    default = "0",
    pref = "tcp_flags_rrd_creation",
  })

  prefsToggleButton(subpage_active, {
    field = "toggle_tcp_retr_ooo_lost_rrds",
    default = "0",
    pref = "tcp_retr_ooo_lost_rrd_creation",
  })

  prefsToggleButton(subpage_active, {
    field = "toggle_vlan_rrds",
    default = "0",
    pref = "vlan_rrd_creation",
  })

  prefsToggleButton(subpage_active, {
    field = "toggle_asn_rrds",
    default = "0",
    pref = "asn_rrd_creation",
  })

  prefsToggleButton(subpage_active, {
    field = "toggle_country_rrds",
    default = "0",
    pref = "country_rrd_creation",
  })

  if ntop.isPro() then
    prefsToggleButton(subpage_active, {
      field = "toggle_ndpi_flows_rrds",
      default = "0",
      pref = "ndpi_flows_rrd_creation",
    })
  end

  print('</table>')

  print('<table class="table">')
if show_advanced_prefs and false --[[ hide these settings for now ]] then
  print('<tr><th colspan=2 class="info">Network Interface Timeseries</th></tr>')
  prefsInputFieldPrefs("Days for raw stats", "Number of days for which raw stats are kept. Default: 1.", "ntopng.prefs.", "intf_rrd_raw_days", prefs.intf_rrd_raw_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  prefsInputFieldPrefs("Days for 1 min resolution stats", "Number of days for which stats are kept in 1 min resolution. Default: 30.", "ntopng.prefs.", "intf_rrd_1min_days", prefs.intf_rrd_1min_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  prefsInputFieldPrefs("Days for 1 hour resolution stats", "Number of days for which stats are kept in 1 hour resolution. Default: 100.", "ntopng.prefs.", "intf_rrd_1h_days", prefs.intf_rrd_1h_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  prefsInputFieldPrefs("Days for 1 day resolution stats", "Number of days for which stats are kept in 1 day resolution. Default: 365.", "ntopng.prefs.", "intf_rrd_1d_days", prefs.intf_rrd_1d_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})

  print('<tr><th colspan=2 class="info">Protocol/Networks Timeseries</th></tr>')
  prefsInputFieldPrefs("Days for raw stats", "Number of days for which raw stats are kept. Default: 1.", "ntopng.prefs.", "other_rrd_raw_days", prefs.other_rrd_raw_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  --prefsInputFieldPrefs("Days for 1 min resolution stats", "Number of days for which stats are kept in 1 min resolution. Default: 30.", "ntopng.prefs.", "other_rrd_1min_days", prefs.other_rrd_1min_days)
  prefsInputFieldPrefs("Days for 1 hour resolution stats", "Number of days for which stats are kept in 1 hour resolution. Default: 100.", "ntopng.prefs.", "other_rrd_1h_days", prefs.other_rrd_1h_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
  prefsInputFieldPrefs("Days for 1 day resolution stats", "Number of days for which stats are kept in 1 day resolution. Default: 365.", "ntopng.prefs.", "other_rrd_1d_days", prefs.other_rrd_1d_days, "number", nil, nil, nil, {min=1, max=365*5, --[[ TODO check min/max ]]})
end
  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')
  print('</table>')

  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form> ]]
end

-- ================================================================================

function printLogging()
  if prefs.has_cmdl_trace_lvl then return end
  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("prefs.logging")..'</th></tr>')

  loggingSelector(subpage_active.entries["toggle_logging_level"].title, 
     subpage_active.entries["toggle_logging_level"].description, 
     "toggle_logging_level", "ntopng.prefs.logging_level")
     
  prefsToggleButton(subpage_active, {
    field = "toggle_log_to_file",
    default = "0",
    pref = "log_to_file",
  })

  prefsToggleButton(subpage_active, {
    field = "toggle_access_log",
    default = "0",
    pref = "enable_access_log",
  })

  prefsToggleButton(subpage_active, {
    field = "toggle_host_pools_log",
    default = "0",
    pref = "enable_host_pools_log",
  })

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')

  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>
  </table>]]
end

function printSnmp()
  if not ntop.isPro() then return end

  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">SNMP</th></tr>')

  prefsToggleButton(subpage_active, {
    field = "toggle_snmp_rrds",
    default = "0",
    pref = "snmp_devices_rrd_creation",
    disabled = not info["version.enterprise_edition"],
  })

  local t_labels = {"v1", "v2c"}
  local t_values = {"0", "1"}

  multipleTableButtonPrefs(subpage_active.entries["default_snmp_proto_version"].title, subpage_active.entries["default_snmp_proto_version"].description,
			   t_labels, t_values, "0", "primary", "default_snmp_version", "ntopng.prefs.default_snmp_version")
  
  prefsInputFieldPrefs(subpage_active.entries["default_snmp_community"].title, subpage_active.entries["default_snmp_community"].description,
		       "ntopng.prefs.",
		       "default_snmp_community",
		       "public", false, nil, nil, nil,  {attributes={spellcheck="false", maxlength=64}})

  prefsToggleButton(subpage_active, {
    field = "toggle_snmp_alerts_port_status_change",
    default = "1",
    pref = "alerts.snmp_port_status_change",
    disabled = not info["version.enterprise_edition"],
  })

  prefsToggleButton(subpage_active, {
    field = "toggle_snmp_alerts_port_duplexstatus_change",
    default = "1",
    pref = "alerts.snmp_port_duplexstatus_change",
    disabled = not info["version.enterprise_edition"],
  })

  prefsToggleButton(subpage_active, {
    field = "toggle_snmp_alerts_port_errors",
    default = "1",
    pref = "alerts.snmp_port_errors",
    disabled = not info["version.enterprise_edition"],
  })

  prefsInputFieldPrefs(subpage_active.entries["snmp_port_load_threshold"].title, 
                       subpage_active.entries["snmp_port_load_threshold"].description,
                       "ntopng.prefs.alerts.", 
                       "snmp_port_load_threshold", 
                       "100", "number", nil, false, nil, {min=0})

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')

  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>
  </table>]]
end

function printFlowDBDump()
  print('<form method="post">')
  print('<table class="table">')
  print('<tr><th colspan=2 class="info">'..i18n("prefs.tiny_flows")..'</th></tr>')

  local tiny_to_switch = {"max_num_packets_per_tiny_flow", "max_num_bytes_per_tiny_flow"}

  prefsToggleButton(subpage_active, {
    field = "toggle_flow_db_dump_export",
    default = "1",
    pref = "tiny_flows_export_enabled",
  })

  prefsInputFieldPrefs(subpage_active.entries["max_num_packets_per_tiny_flow"].title, subpage_active.entries["max_num_packets_per_tiny_flow"].description,
        "ntopng.prefs.", "max_num_packets_per_tiny_flow", prefs.max_num_packets_per_tiny_flow, "number",
	true, false, nil, {min=1, max=2^32-1})

  prefsInputFieldPrefs(subpage_active.entries["max_num_bytes_per_tiny_flow"].title, subpage_active.entries["max_num_bytes_per_tiny_flow"].description,
        "ntopng.prefs.", "max_num_bytes_per_tiny_flow", prefs.max_num_bytes_per_tiny_flow, "number",
	true, false, nil, {min=1, max=2^32-1})

  print('<tr><th colspan=2 class="info">'..i18n("prefs.aggregated_flows")..'</th></tr>')

  local dump_to_switch = {"max_num_aggregated_flows_per_export"}
  prefsToggleButton(subpage_active, {
    field = "toggle_aggregated_flows_export_limit",
    default = "0",
    pref = "aggregated_flows_export_limit_enabled",
    to_switch = dump_to_switch,
  })

  local showElement = ntop.getPref("ntopng.prefs.aggregated_flows_export_limit_enabled") == "1"

  prefsInputFieldPrefs(subpage_active.entries["max_num_aggregated_flows_per_export"].title,
		       subpage_active.entries["max_num_aggregated_flows_per_export"].description,
		       "ntopng.prefs.", "max_num_aggregated_flows_per_export",
		       prefs.max_num_aggregated_flows_per_export, "number", showElement, false, nil,
		       {min = 1000, max = 2^32-1})

  print('<tr><th colspan=2 style="text-align:right;"><button type="submit" class="btn btn-primary" style="width:115px" disabled="disabled">'..i18n("save")..'</button></th></tr>')

  print [[<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  </form>
  </table>]]
end

   print[[
       <table class="table table-bordered">
         <col width="20%">
         <col width="80%">
         <tr><td style="padding-right: 20px;">]]

   print(
      template.gen("typeahead_input.html", {
        typeahead={
          base_id     = "prefs_search",
          action      = ntop.getHttpPrefix() .. "/lua/admin/prefs.lua",
          json_key    = "tab",
          query_field = "tab",
          query_url   = ntop.getHttpPrefix() .. "/lua/find_prefs.lua",
          query_title = i18n("prefs.search_preferences"),
          style       = "width:20em; margin:auto; margin-top: 0.4em; margin-bottom: 1.5em;",
        }
      })
    )

   print[[
           <div class="list-group">]]

printMenuSubpages(tab)

print[[
           </div>
           <br>
           <div align="center">

            <div id="prefs_toggle" class="btn-group">
              <form method="post">
<input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
<input type=hidden name="show_advanced_prefs" value="]]if show_advanced_prefs then print("false") else print("true") end print[["/>


<br>
<div class="btn-group btn-toggle">
]]

local cls_on      = "btn btn-sm"
local onclick_on  = ""
local cls_off     = cls_on
local onclick_off = onclick_on
if show_advanced_prefs then
   cls_on  = cls_on..' btn-primary active'
   cls_off = cls_off..' btn-default'
   onclick_off = "this.form.submit();"
else
   cls_on = cls_on..' btn-default'
   cls_off = cls_off..' btn-primary active'
   onclick_on = "this.form.submit();"
end
print('<button type="button" class="'..cls_on..'" onclick="'..onclick_on..'">'..i18n("prefs.expert_view")..'</button>')
print('<button type="button" class="'..cls_off..'" onclick="'..onclick_off..'">'..i18n("prefs.simple_view")..'</button>')

print[[
</div>
              </form>

            </div>

           </div>

        </td><td colspan=2 style="padding-left: 14px;border-left-style: groove; border-width:1px; border-color: #e0e0e0;">]]

if(tab == "report") then
   printReportVisualization()
end

if(tab == "in_memory") then
   printInMemory()
end

if(tab == "on_disk_ts") then
   printStatsTimeseries()
end

if(tab == "alerts") then
   printAlerts()
end

if(tab == "ext_alerts") then
   printExternalAlertsReport()
end

if(tab == "protocols") then
   printProtocolPrefs()
end

if(tab == "discovery") then
   printNetworkDiscovery()
end

if(tab == "telemetry") then
   printTelemetry()
end

if(tab == "recording") then
   printRecording()
end

if(tab == "remote_assistance") then
   printRemoteAssitance()
end

if(tab == "retention") then
   printDataRetention()
end

if(tab == "misc") then
   printMisc()
end

if(tab == "auth") then
   printAuthentication()
end
if(tab == "ifaces") then
   printInterfaces()
end
if(tab == "logging") then
   printLogging()
end
if(tab == "snmp") then
   printSnmp()
end
if(tab == "flow_db_dump") then
   printFlowDBDump()
end

print[[
        </td></tr>
      </table>
]]

   dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

   print([[<script>
aysHandleForm("form", {
  disable_on_dirty: '.disable-on-dirty',
});

/* Use the validator plugin to override default chrome bubble, which is displayed out of window */
$("form[id!='search-host-form']").validator({disable:true});
</script>]])

local high_res_secs = tonumber(_POST["ts_high_resolution"])      
if high_res_secs then
  -- update ts_write_slots
  local driver = ntop.getPref("ntopng.prefs.timeseries_driver")
  local new_slots = 0
  local new_steps = 0

  -- high_res_secs must be <= 60 to be considered high-resolution
  -- the only other option is 300 seconds (5 minutes) and there's
  -- no need to use timeseries rings

  if driver == "influxdb" and high_res_secs <= 60 then
    new_slots = 60 / high_res_secs
    new_steps = 60 / new_slots / 5 -- TODO: remove this hardcoded 5

    -- important: add one extra slots to give "buffer" time to the writer
    new_slots = new_slots + 1
  end

  -- When high resolution timeseries are enabled, the ntopng C core creates
  -- timeseries rings with diffent slots. Each slot holds a snapshot of the
  -- host/interface timeseries in a given time interval. For example, if 10s
  -- resolution is choose, each slot holds a snapshot representing an interval
  -- of 10s. Periodically (in NetworkInterface::periodicStatsUpdate) the slots
  -- are polulated and then in minute.lua they are read and exported.
  --
  -- This Redis preferences tell the C core how to configure the ring:
  --  - ntopng.prefs.ts_write_slots: the number of slots to allocate in the ring
  --  - ntopng.prefs.ts_write_steps: how many ticks of NetworkInterface::periodicStatsUpdate
  --    are necessary to fill a slot.
  --
  -- For the example above of 10s resolution:
  --  - ntopng.prefs.ts_write_slots = 60 / 10 = 6 slots, + 1 extra slot as buffer (see above) = 7
  --  - ntopng.prefs.ts_write_steps = 60 / 6 slots = 10s / 5 (5s is the periodicStatsUpdate interval) = 2
  --
  -- See TimseriesRing.cpp for more details.
  --
  ntop.setPref("ntopng.prefs.ts_write_slots", tostring(math.ceil(new_slots)))
  ntop.setPref("ntopng.prefs.ts_write_steps", tostring(math.ceil(new_steps)))

--  tprint(ntop.getPref("ntopng.prefs.ts_write_slots"))
--  tprint(ntop.getPref("ntopng.prefs.ts_write_steps"))
end

if(_SERVER["REQUEST_METHOD"] == "POST") then
   -- Something has changed
  ntop.reloadPreferences()
end

end --[[ haveAdminPrivileges ]]
