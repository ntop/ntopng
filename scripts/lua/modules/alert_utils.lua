--
-- (C) 2014-21 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

-- This file contains the description of all functions
-- used to trigger host alerts
local verbose = ntop.getCache("ntopng.prefs.alerts.debug") == "1"
local callback_utils = require "callback_utils"
local template = require "template_utils"
local json = require("dkjson")
local host_pools = require "host_pools"
local recovery_utils = require "recovery_utils"
local alert_severities = require "alert_severities"
local alert_entities = require "alert_entities"
local alert_consts = require "alert_consts"
local format_utils = require "format_utils"
local telemetry_utils = require "telemetry_utils"
local tracker = require "tracker"
local alerts_api = require "alerts_api"
local icmp_utils = require "icmp_utils"
local checks = require "checks"

local shaper_utils = nil

if(ntop.isnEdge()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   shaper_utils = require("shaper_utils")
end

-- ##############################################

local alert_utils = {}

-- ##############################################

local function alertTypeDescription(alert_key, entity_id)

   local alert_id = alert_consts.getAlertType(alert_key, entity_id)

   if(alert_id) then
      if alert_consts.alert_types[alert_id].format then
	 -- New API
	 return alert_consts.alert_types[alert_id].format
      else
	 -- TODO: Possible removed once migration is done
	 return(alert_consts.alert_types[alert_id].i18n_description)
      end
   end

  return nil
end

-- ##############################################

local function get_make_room_keys(ifId)
   return {flows="ntopng.cache.alerts.ifid_"..ifId..".make_room_flow_alerts",
	   entities="ntopng.cache.alerts.ifid_"..ifId..".make_room_closed_alerts"}
end

-- #################################

--@brief Deletes all stored alerts matching an host and an IP
-- @return nil
function alert_utils.deleteFlowAlertsMatching(host_ip, alert_id)
   local flow_alert_store = require("flow_alert_store").new()

   if not isEmptyString(host_ip) then
      flow_alert_store:add_ip_filter(hostkey2hostinfo(host_ip)["host"])
   end
   flow_alert_store:add_alert_id_filter(alert_id)

   -- Perform the actual deletion
   flow_alert_store:delete()
end

-- #################################

--@brief Deletes all stored alerts matching an host and an IP
-- @return nil
function alert_utils.deleteHostAlertsMatching(host_ip, alert_id)
   local host_alert_store = require("host_alert_store").new()

   if not isEmptyString(host_ip) then
      host_alert_store:add_ip_filter(hostkey2hostinfo(host_ip)["host"])
   end
   host_alert_store:add_alert_id_filter(alert_id)

   -- Perform the actual deletion
   host_alert_store:delete()
end

-- #################################

-- this function returns an object with parameters specific for one tab
function alert_utils.getTabParameters(_get, what)
   local opts = {}
   for k,v in pairs(_get) do opts[k] = v end

   -- these options are contextual to the current tab (status)
   if _get.status ~= what then
      opts.alert_id = nil
   end
   if not isEmptyString(what) then opts.status = what end
   opts.ifid = interface.getId()
   return opts
end

-- #################################

-- Return more information for the flow alert description
local function getAlertTypeInfo(record, alert_info)
   local res = ""

   local l7proto_name = interface.getnDPIProtoName(tonumber(record["l7_proto"]) or 0)

   if l7proto_name == "ICMP" then -- is ICMPv4
      -- TODO: old format - remove when the all the flow alers will be generated in lua
      local type_code = {type = alert_info["icmp.icmp_type"], code = alert_info["icmp.icmp_code"]}

      if table.empty(type_code) and alert_info["icmp"] then
	 -- This is the new format created when setting the alert from lua
	 type_code = {type = alert_info["icmp"]["type"], code = alert_info["icmp"]["code"]}
      end

      if alert_info["icmp.unreach.src_ip"] then -- TODO: old format to be removed
	 res = string.format("[%s]", i18n("icmp_page.icmp_port_unreachable_extra", {unreach_host=alert_info["icmp.unreach.dst_ip"], unreach_port=alert_info["icmp.unreach.dst_port"], unreach_protocol = l4_proto_to_string(alert_info["icmp.unreach.protocol"])}))
      elseif alert_info["icmp"] and alert_info["icmp"]["unreach"] then -- New format
	 res = string.format("[%s]", i18n("icmp_page.icmp_port_unreachable_extra", {unreach_host=alert_info["icmp"]["unreach"]["dst_ip"], unreach_port=alert_info["icmp"]["unreach"]["dst_port"], unreach_protocol = l4_proto_to_string(alert_info["icmp"]["unreach"]["protocol"])}))
      else
	 res = string.format("[%s]", icmp_utils.get_icmp_label(4 --[[ ipv4 --]], type_code["type"], type_code["code"]))
      end
   end

   return string.format(" %s", res)
end

-- #################################

-- This function formats flows in alerts
function alert_utils.formatRawFlow(alert)
   require "flow_utils"
   local time_bounds
   local add_links = false

   -- pretend alert is a flow to reuse getFlowLabel
   local flow = {
      ["cli.ip"] = alert["cli_ip"], ["cli.port"] = tonumber(alert["cli_port"]),
      ["cli.blacklisted"] = tostring(alert["cli_blacklisted"]) == "1",
      ["cli.localhost"] = tostring(alert["cli_localhost"]) == "1",
      ["srv.ip"] = alert["srv_ip"], ["srv.port"] = tonumber(alert["srv_port"]),
      ["srv.blacklisted"] = tostring(alert["srv_blacklisted"]) == "1",
      ["srv.localhost"] = tostring(alert["srv_localhost"]) == "1",
      ["vlan"] = alert["vlan_id"]}

   flow = "<i class=\"fas fa-stream\"></i> "..(getFlowLabel(flow, false, add_links, time_bounds, {page = "alerts"}) or "")

   return flow
end

-- #################################

function alert_utils.drawAlertPCAPDownloadDialog(ifid)
   local modalID = "pcapDownloadModal"

   print[[
   <script>
   function bpfValidator(filter_field) {
      // no pre validation required as the user is not
      // supposed to edit the filter here
      return true;
   }

   function pcapDownload(item) {
     var modalID = "]] print(modalID) print [[";
     var bpf_filter = item.getAttribute('data-filter');
     var epoch_begin = item.getAttribute('data-epoch-begin');
     var epoch_end = item.getAttribute('data-epoch-end');
     var date_begin = new Date(epoch_begin * 1000);
     var date_end = new Date(epoch_begin * 1000);
     var epoch_begin_formatted = $.datepicker.formatDate('M dd, yy ', date_begin)+date_begin.getHours()
       +":"+date_begin.getMinutes()+":"+date_begin.getSeconds(); 
     var epoch_end_formatted = $.datepicker.formatDate('M dd, yy ', date_end)
       +date_end.getHours()+":"+date_end.getMinutes()+":"+date_end.getSeconds();

     $('#'+modalID+'_ifid').val(]] print(ifid) print [[);
     $('#'+modalID+'_epoch_begin').val(epoch_begin);
     $('#'+modalID+'_epoch_end').val(epoch_end);
     $('#'+modalID+'_begin').text(epoch_begin_formatted);
     $('#'+modalID+'_end').text(epoch_end_formatted);
     $('#'+modalID+'_query_items').html("");
     $('#'+modalID+'_chart_link').val("");

     $('#'+modalID+'_bpf_filter').val(bpf_filter);
     $('#'+modalID).modal('show');

     $("#]] print(modalID) print [[ form:data(bs.validator)").each(function(){
       $(this).data("bs.validator").validate();
     });
   }

   function submitPcapDownload(form) {
     var frm = $('#'+form.id);
     window.open(']] print(ntop.getHttpPrefix()) print [[/lua/rest/v2/get/pcap/live_extraction.lua?' + frm.serialize(), '_self', false);
     $('#]] print(modalID) print [[').modal('hide');
     return false;
   }

   </script>
]]

  print(template.gen("traffic_extraction_dialog.html", { dialog = {
     id = modalID,
     title = i18n("traffic_recording.pcap_download"),
     message = i18n("traffic_recording.about_to_download_flow", {date_begin = '<span id="'.. modalID ..'_begin">', date_end = '<span id="'.. modalID ..'_end">'}),
     submit = i18n("traffic_recording.download"),
     form_method = "post",
     validator_options = "{ custom: { bpf: bpfValidator }, errors: { bpf: '"..i18n("traffic_recording.invalid_bpf").."' } }",
     form_action = ntop.getHttpPrefix().."/lua/traffic_extraction.lua",
     form_onsubmit = "submitPcapDownload",
     advanced_class = "d-none",
     extract_now_class = "d-none", -- direct download only
  }}))

   print(template.gen("modal_confirm_dialog.html", { dialog = {
      id = "no-recording-data",
      title = i18n("traffic_recording.pcap_download"),
      message = "<span id='no-recording-data-message'></span>",
   }}))

end

-- #################################

-- A redis set with mac addresses as keys
function alert_utils.getActiveDevicesHashKey(ifid)
   return "ntopng.cache.active_devices.ifid_" .. ifid
end

function alert_utils.deleteActiveDevicesKey(ifid)
   ntop.delCache(alert_utils.getActiveDevicesHashKey(ifid))
end

-- #################################

-- A redis set with host pools as keys
local function getActivePoolsHashKey(ifid)
   return "ntopng.cache.active_pools.ifid_" .. ifid
end

function alert_utils.deleteActivePoolsKey(ifid)
   ntop.delCache(getActivePoolsHashKey(ifid))
end

-- #################################

-- Redis hashe with key=pool and value=list of quota_exceed_items, separated by |
local function getPoolsQuotaExceededItemsKey(ifid)
   return "ntopng.cache.quota_exceeded_pools.ifid_" .. ifid
end

-- #################################

function alert_utils.check_host_pools_alerts(params, ifid, alert_pool_connection_enabled, alerts_on_quota_exceeded)
   local active_pools_set = getActivePoolsHashKey(ifid)
   local prev_active_pools = swapKeysValues(ntop.getMembersCache(active_pools_set)) or {}
   local pools_stats = interface.getHostPoolsStats()
   local quota_exceeded_pools_key = getPoolsQuotaExceededItemsKey(ifid)
   local quota_exceeded_pools_values = ntop.getHashAllCache(quota_exceeded_pools_key) or {}
   local quota_exceeded_pools = {}
   local now_active_pools = {}

   -- Deserialize quota_exceeded_pools
   for pool, v in pairs(quota_exceeded_pools_values) do
      quota_exceeded_pools[pool] = {}

      for _, group in pairs(split(quota_exceeded_pools_values[pool], "|")) do
         local parts = split(group, "=")

         if #parts == 2 then
            local proto = parts[1]
            local quota = parts[2]

            local parts = split(quota, ",")
            quota_exceeded_pools[pool][proto] = {toboolean(parts[1]), toboolean(parts[2])}
         end
      end
      -- quota_exceeded_pools[pool] is like {Youtube={true, false}}, where true is bytes_exceeded, false is time_exceeded
   end

   local pools = interface.getHostPoolsInfo()
   if(pools ~= nil) and (pools_stats ~= nil) then
      for pool, info in pairs(pools.num_members_per_pool) do
	 local pool_stats = pools_stats[tonumber(pool)]
	 local pool_exceeded_quotas = quota_exceeded_pools[pool] or {}

	 -- Pool quota
	 if((pool_stats ~= nil) and (shaper_utils ~= nil)) then
	    local quotas_info = shaper_utils.getQuotasInfo(ifid, pool, pool_stats)

	    for proto, info in pairs(quotas_info) do
	       local prev_exceeded = pool_exceeded_quotas[proto] or {false,false}

	       if alerts_on_quota_exceeded then
		  if info.bytes_exceeded and not prev_exceeded[1] then
		     local alert = alert_consts.alert_types.alert_quota_exceeded.new(
			"traffic_quota",
			pool,
			proto,
			info.bytes_value,
			info.bytes_quota
		     )

		     alert:set_score_warning()
		     alert:store(alerts_api.hostPoolEntity(pool))
		  end

		  if info.time_exceeded and not prev_exceeded[2] then           
		     local alert = alert_consts.alert_types.alert_quota_exceeded.new(
			"time_quota",
			pool,
			proto,
			info.time_value,
			info.time_quota
		     )

		     alert:set_score_warning()
		     alert:store(alerts_api.hostPoolEntity(pool))
		  end
	       end

	       if not info.bytes_exceeded and not info.time_exceeded then
		  -- delete as no quota is left
		  pool_exceeded_quotas[proto] = nil
	       else
		  -- update/add serialized
		  pool_exceeded_quotas[proto] = {info.bytes_exceeded, info.time_exceeded}
	       end
	    end

	    if table.empty(pool_exceeded_quotas) then
	       ntop.delHashCache(quota_exceeded_pools_key, pool)
	    else
	       -- Serialize the new quota information for the pool
	       for proto, value in pairs(pool_exceeded_quotas) do
		  pool_exceeded_quotas[proto] = table.concat({tostring(value[1]), tostring(value[2])}, ",")
	       end

	       ntop.setHashCache(quota_exceeded_pools_key, pool, table.tconcat(pool_exceeded_quotas, "=", "|"))
	    end
	 end

	 -- Pool presence
	 if (pool ~= host_pools.DEFAULT_POOL_ID) and (info.num_hosts > 0) then
	    now_active_pools[pool] = 1

	    if not prev_active_pools[pool] then
	       -- Pool connection
	       ntop.setMembersCache(active_pools_set, pool)

	       if alert_pool_connection_enabled then
		  local alert = alert_consts.alert_types.alert_host_pool_connection.new(
		     pool
		  )

		  alert:set_score_notice()
		  alert:store(alerts_api.hostPoolEntity(pool))
	       end
	    end
	 end
      end
   end

   -- Pool presence
   for pool in pairs(prev_active_pools) do
      if not now_active_pools[pool] then
         -- Pool disconnection
         ntop.delMembersCache(active_pools_set, pool)

         if alert_pool_connection_enabled then
            local alert = alert_consts.alert_types.alert_host_pool_disconnection.new(
               pool
            )

            alert:set_score_notice()
            alert:store(alerts_api.hostPoolEntity(pool))
         end
      end
   end
end

-- #################################

function alert_utils.disableAlertsGeneration()
   if not isAdministratorOrPrintErr() then
      return
   end

   -- Ensure we do not conflict with others
   ntop.setPref("ntopng.prefs.disable_alerts_generation", "1")
   if(verbose) then io.write("[Alerts] Disable done\n") end
end

-- #################################

local function alertNotificationActionToLabel(action, use_emoji)
   local label = "["

   if action == "engage" then
      if(use_emoji) then label = label .."\xE2\x9D\x97 " end
      label = label .. "Engaged]"
   elseif action == "release" then
      if(use_emoji) then label = label .."\xE2\x9C\x94 " end
      label = label .. "Released]"
   end

   return label
end

-- #################################

function alert_utils.getConfigsetURL(script_key, subdir)
   return string.format('%s/lua/admin/edit_configset.lua?subdir=%s&check=%s#all', ntop.getHttpPrefix(), subdir, script_key)
end

-- #################################

function alert_utils.getConfigsetAlertLink(alert_json, alert --[[ optional --]])
   local info = alert_json.alert_generation or (alert_json.alert_info and alert_json.alert_info.alert_generation)

   if(info and isAdministrator()) then

      if alert then
	 -- This piece of code (exception) has been moved here from formatAlertMessage
	 if(alert_consts.getAlertType(alert.alert_id, alert.entity_id) == "alert_am_threshold_cross") then
	    local plugins_utils = require "plugins_utils"
	    local active_monitoring_utils = plugins_utils.loadModule("active_monitoring", "am_utils")
	    local host = json.decode(alert.json)["host"]

	    if host and host.measurement and not host.is_infrastructure then
	       return ' <a href="'.. ntop.getHttpPrefix() ..'/plugins/active_monitoring_stats.lua?am_host='
		  .. host.host .. '&measurement='.. host.measurement ..'&page=overview"><i class="fas fa-cog" title="'.. i18n("edit_configuration") ..'"></i></a>'
	    end
	 end
      end

      return(' <a href="'..alert_utils.getConfigsetURL(info.script_key, info.subdir)..'">'..
		'<i class="fas fa-cog" title="'.. i18n("edit_configuration") ..'"></i></a>')
   end

   return('')
end

-- #################################

function alert_utils.getAlertInfo(alert)
  local alert_json = alert["json"] or alert["alert_json"]

  if isEmptyString(alert_json) then
    alert_json = {}
  elseif(string.sub(alert_json, 1, 1) == "{") then
    alert_json = json.decode(alert_json) or {}
  end

  return alert_json
end

-- #################################

function alert_utils.formatAlertMessage(ifid, alert, alert_json, skip_live_data)
  local msg

  if(alert_json == nil) then
   alert_json = alert_utils.getAlertInfo(alert)
  end

  msg = alert_json
  local description = alertTypeDescription(alert.alert_id, alert.entity_id)

  if(type(description) == "string") then
     -- localization string
     msg = i18n(description, msg)
  elseif(type(description) == "function") then
     msg = description(ifid, alert, msg)
  end

  if(type(msg) == "table") then
     return("")
  end

  if isEmptyString(msg) then
    msg = alert_consts.alertTypeLabel(tonumber(alert.alert_id), true --[[ no_html --]], alert.entity_id)
  end

  if not isEmptyString(alert["user_label"]) then
     msg = string.format('%s <small><span class="text-muted">%s</span></small>', msg, alert["user_label"])
  end

  return(msg or "")
end

-- #################################

function alert_utils.formatFlowAlertMessage(ifid, alert, alert_json, skip_live_data)
  local msg

  if(alert_json == nil) then
   alert_json = alert_utils.getAlertInfo(alert)
  end

  msg = alert_json
  local description = alertTypeDescription(alert.alert_id, alert_entities.flow.entity_id)

  if(type(description) == "string") then
     -- localization string
     msg = i18n(description, msg)
  elseif(type(description) == "function") then
     msg = description(ifid, alert, msg)
  end

  if isEmptyString(msg) then
    msg = alert_consts.alertTypeLabel(tonumber(alert.alert_id), true --[[ no_html --]], alert_entities.flow.entity_id)
  end

  if not isEmptyString(alert["user_label"]) then
     msg = string.format('%s <small><span class="text-muted">%s</span></small>', msg, alert["user_label"])
  end

  return msg or ""
end

-- #################################

function alert_utils.notification_timestamp_rev(a, b)
   return (a.tstamp > b.tstamp)
end

function alert_utils.severity_rev(a, b)
   return (a.severity_id > b.severity_id)
end

-- #################################
--
-- Returns a summary of the alert as readable text
function alert_utils.formatAlertNotification(notif, options)
   local defaults = {
      nohtml = false,
      show_severity = true,
   }
   options = table.merge(defaults, options)

   local ifname
   local severity
   local when

   if(notif.ifid ~= -1) then
      ifname = string.format(" [%s]", getInterfaceName(notif.ifid))
   else
      ifname = ""
   end

   if(options.show_severity == false) then
      severity = ""
   else
      severity =  " [" .. alert_consts.alertSeverityLabel(notif.score, options.nohtml, options.emoji) .. "]"
   end

   if(options.nodate == true) then
      when = ""
   else
      when = formatEpoch(notif.tstamp_end or notif.tstamp or 0)

      if(not options.no_bracket_around_date) then
	 when = "[" .. when .. "]"
      end

      when = when .. " "
   end

   local msg = string.format("%s%s%s [%s]",
			     when, ifname, severity,
			     alert_consts.alertTypeLabel(notif.alert_id, options.nohtml))

   -- entity can be hidden for example when one is OK with just the message
   if options.show_entity then
      msg = msg.."["..alert_consts.alertEntityLabel(notif.entity_id).."]"
      local ev
      if notif.entity_id == alert_entities.flow.entity_id then
         ev = noHtml(alert_utils.formatRawFlow(notif))
      else
	 ev = notif.entity_val
	 if notif.entity_id == alert_entities.host.entity_id then
	    -- suppresses @0 when the vlan is zero
	    ev = hostinfo2hostkey(hostkey2hostinfo(notif.entity_val))
	 end
      end
      msg = msg.."["..(ev or '').."]"
   end

   -- add the label, that is, engaged or released
   msg = msg .. " " .. alertNotificationActionToLabel(notif.action, options.emoji).. " "
   local alert_message = alert_utils.formatAlertMessage(notif.ifid, notif)

   if(options.add_cr) then
      msg = msg .. "\n"
   end

   if options.nohtml then
      msg = msg .. noHtml(alert_message)
   else
      msg = msg .. alert_message
   end

   return msg
end

-- ##############################################

-- Processes queued alerts and returns the information necessary to store them.
-- Alerts are only enqueued by AlertsQueue in C. From lua, the alerts_api
-- can be called directly as slow operations will be postponed
local function processStoreAlertFromQueue(alert)
   local entity_info = nil
   local type_info = nil

   interface.select(tostring(alert.ifid))

   if(alert.alert_id == "misconfigured_dhcp_range") then
      local router_info = {host = alert.router_ip, vlan = alert.vlan_id}
      entity_info = alerts_api.hostAlertEntity(alert.client_ip, alert.vlan_id)
      type_info = alert_consts.alert_types.alert_ip_outsite_dhcp_range.new(
	 router_info,
	 alert.mac_address,
	 alert.client_mac,
	 alert.sender_mac
      )
      type_info:set_score_warning()
      type_info:set_subtype(string.format("%s_%s_%s", hostinfo2hostkey(router_info), alert.client_mac, alert.sender_mac))
   elseif(alert.alert_id == "mac_ip_association_change") then
      local name = getDeviceName(alert.new_mac)
      entity_info = alerts_api.macEntity(alert.new_mac)
      type_info = alert_consts.alert_types.alert_mac_ip_association_change.new(
	 name,
	 alert.ip,
	 alert.old_mac,
	 alert.new_mac
      )
      type_info:set_score_warning()
      type_info:set_subtype(string.format("%s_%s_%s", alert.ip, alert.old_mac, alert.new_mac))
   elseif(alert.alert_id == "login_failed") then
      entity_info = alerts_api.userEntity(alert.user)
      type_info = alert_consts.alert_types.alert_login_failed.new()
      type_info:set_score_warning()
   elseif(alert.alert_id == "broadcast_domain_too_large") then
      entity_info = alerts_api.macEntity(alert.src_mac)
      type_info = alert_consts.alert_types.alert_broadcast_domain_too_large.new(alert.src_mac, alert.dst_mac, alert.vlan_id, alert.spa, alert.tpa)
      type_info:set_score_warning()
      type_info:set_subtype(string.format("%u_%s_%s_%s_%s", alert.vlan_id, alert.src_mac, alert.spa, alert.dst_mac, alert.tpa))
   elseif((alert.alert_id == "user_activity") and (alert.scope == "login")) then
      entity_info = alerts_api.userEntity(alert.user)
      type_info = alert_consts.alert_types.alert_user_activity.new(
         "login",
         nil,
         nil,
         nil,
         "authorized"
      )
      type_info:set_score_notice()
      type_info:set_subtype("login//")
   elseif(alert.alert_id == "nfq_flushed") then
      entity_info = alerts_api.interfaceAlertEntity(alert.ifid)
      type_info = alert_consts.alert_types.alert_nfq_flushed.new(
         getInterfaceName(alert.ifid),
         alert.pct,
         alert.tot,
         alert.dropped
      )

      type_info:set_score_error()
   else
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Unknown alert type " .. (alert.alert_id or ""))
   end

   return entity_info, type_info
end

-- ##############################################

-- @brief Process notifications arriving from the internal C queue
--        Such notifications are transformed into stored alerts
function alert_utils.process_notifications_from_c_queue()
   local budget = 1024 -- maximum 1024 alerts per call
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

      if type_info and entity_info then
	 type_info:store(entity_info)
      end


      budget_used = budget_used + 1
   end
end

-- ##############################################

local function notify_ntopng_status(started)
   local info = ntop.getInfo()
   local score = 10
   local msg
   local msg_details = string.format("%s v.%s (%s) [OS: %s][pid: %s][options: %s]", info.product, info.version, info.revision, info.OS, info.pid, info.command_line)
   local anomalous = false
   local event

   if(started) then

      -- reading current version and last version to check if it has been updated
      local last_version_key = "ntopng.updates.last_version"
      local last_version = ntop.getCache(last_version_key)
      local curr_version = info["version"].."-"..info["revision"]
      ntop.setCache(last_version_key, curr_version)

      -- let's check if we are restarting from an anomalous termination
      -- e.g., from a crash
      if not recovery_utils.check_clean_shutdown() then
        -- anomalous termination
        msg = string.format("%s %s", i18n("alert_messages.ntopng_anomalous_termination", {url="https://www.ntop.org/support/need-help-2/need-help/"}), msg_details)
        score = 100
        anomalous = true
        event = "anomalous_termination"
      elseif not isEmptyString(last_version) and last_version ~= curr_version then
	-- software update
        msg = string.format("%s %s", i18n("alert_messages.ntopng_update"), msg_details)
        event = "update"
      else
	-- normal termination
        msg = string.format("%s %s", i18n("alert_messages.ntopng_start"), msg_details)
        event = "start"
      end
   else
      msg = string.format("%s %s", i18n("alert_messages.ntopng_stop"), msg_details)
      event = "stop"
   end

   local entity_value = ntop.getInfo().product

   obj = {
      entity_id = alerts_api.systemEntity(entity_value), entity_val = entity_value,
      type = alert_consts.alertType("alert_process_notification"),
      score = score,
      message = msg,
      when = os.time() }

   if anomalous then
      telemetry_utils.notify(obj)
   end

   local entity_info = alerts_api.systemEntity(entity_value)
   local type_info = alert_consts.alert_types.alert_process_notification.new(
      event,
      msg_details
   )

   type_info:set_score(score)

   return(type_info:store(entity_info))
end

function alert_utils.notify_ntopng_start()
   return(notify_ntopng_status(true))
end

function alert_utils.notify_ntopng_stop()
   return(notify_ntopng_status(false))
end

-- #####################################

function alert_utils.formatBehaviorAlert(params, anomalies, stats, id, subtype, name)
   -- Cycle throught the behavior stats
   for anomaly_type, anomaly_table in pairs(anomalies) do
      local lower_bound = stats[anomaly_type]["lower_bound"]
      local upper_bound = stats[anomaly_type]["upper_bound"]
      local value = stats[anomaly_type]["value"]
      
      if anomaly_table["cut_values"] then
         value = tonumber(string.format("%.2f", tonumber(value * (anomaly_table["multiplier"] or 1))))
         lower_bound = tonumber(string.format("%.2f", tonumber(lower_bound * (anomaly_table["multiplier"] or 1))))
         upper_bound = tonumber(string.format("%.2f", tonumber(upper_bound * (anomaly_table["multiplier"] or 1))))
      end

      if anomaly_table["formatter"] then
         value = anomaly_table["formatter"](value)
         lower_bound = anomaly_table["formatter"](lower_bound)
         upper_bound = anomaly_table["formatter"](upper_bound)
      end
 
      local alert = alert_consts.alert_types.alert_behavior_anomaly.new(
         i18n(subtype .. "_id", {id = name or id}),
         anomaly_type,
         value,
         lower_bound,
         upper_bound,
         anomaly_table["entity_id"],
         id,
         anomaly_table["extra_params"]
      )
 
      alert:set_score_warning()
      alert:set_granularity(params.granularity)
      alert:set_subtype(name)

      -- Trigger an alert if an anomaly is found
      if anomaly_table["anomaly"] == true then
         alert:trigger(params.alert_entity, nil, params.cur_alerts)
      else
         alert:release(params.alert_entity, nil, params.cur_alerts)
      end
   end
end

return alert_utils
