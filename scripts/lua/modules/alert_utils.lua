--
-- (C) 2014-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/modules/alert_store/?.lua;" .. package.path

-- This file contains the description of all functions
-- used to trigger host alerts
local verbose = ntop.getCache("ntopng.prefs.alerts.debug") == "1"
local json = require("dkjson")
local host_pools = require "host_pools"
local recovery_utils = require "recovery_utils"
local alert_entities = require "alert_entities"
local alert_consts = require "alert_consts"
local format_utils = require "format_utils"
local telemetry_utils = require "telemetry_utils"
local alerts_api = require "alerts_api"
local icmp_utils = require "icmp_utils"
local flow_risk_utils = require "flow_risk_utils"

local shaper_utils = nil

if(ntop.isnEdge()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   shaper_utils = require("shaper_utils")
end

-- ##############################################

local alert_utils = {}

alert_utils.SEPARATOR = ';'

-- ##############################################

local function alertTypeDescription(alert_key, entity_id)
   local alert_id = alert_consts.getAlertType(alert_key, entity_id)

   if(alert_id) then
      if alert_consts.alert_types[alert_id].format then
	 return alert_consts.alert_types[alert_id].format
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
   local label = ""

   if action == "engage" then
      label = "["
      if(use_emoji) then label = label .."\xE2\x9D\x97 " end
      label = label .. "Engaged"
      label = label .. "]"
   elseif action == "release" then
      label = "["
      if(use_emoji) then label = label .."\xE2\x9C\x94 " end
      label = label .. "Released"
      label = label .. "]"
   end

   return label
end

-- #################################

function alert_utils.getConfigsetURL(script_key, subdir)
   return string.format('%s/lua/admin/edit_configset.lua?subdir=%s&check=%s#all', ntop.getHttpPrefix(), subdir, script_key)
end

-- #################################

function alert_utils.getConfigsetAlertLink(alert_json, alert --[[ optional --]], alert_entity)
   if isAdministrator() then 
      local info = alert_json.alert_generation or (alert_json.alert_info and alert_json.alert_info.alert_generation)
      if alert_entity and alert_entity == alert_entities.am_host.entity_id then
         local host = json.decode(alert.json)["host"]
         if host then
            return ' <a href="'.. ntop.getHttpPrefix() ..'/lua/monitor/active_monitoring_monitor.lua?am_host='
   		.. host.host .. '&measurement='.. host.measurement ..'&page=overview"><i class="fas fa-cog" title="'.. i18n("edit_configuration") ..'"></i></a>'
         else
   	    return ' <a href="'.. ntop.getHttpPrefix() ..'/lua/monitor/active_monitoring_monitor.lua?page=overview"><i class="fas fa-cog" title="'.. i18n("edit_configuration") ..'"></i></a>'
         end
      elseif info then
         return(' <a href="'..alert_utils.getConfigsetURL(info.script_key, info.subdir)..'">'..
		'<i class="fas fa-cog" title="'.. i18n("edit_configuration") ..'"></i></a>')
      else
         return (' <a href="' .. ntop.getHttpPrefix() .. '/lua/admin/edit_configset.lua?subdir=interface#all">'..
         '<i class="fas fa-cog" title="'.. i18n("edit_configuration") ..'"></i></a>')
      end
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

function alert_utils.formatAlertMessage(ifid, alert, alert_json)
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

function alert_utils.formatFlowAlertMessage(ifid, alert, alert_json)
   local msg
   local alert_risk = ntop.getFlowAlertRisk(tonumber(alert.alert_id))

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

  -- Add the link to the documentation
  if alert_risk > 0 then
     msg = string.format("%s %s", msg, flow_risk_utils.get_documentation_link(alert_risk))
  end

  return msg or ""
end

-- #################################

function alert_utils.getLinkToPastFlows(ifid, alert, alert_json)
   if not ntop.isEnterpriseM() or not hasClickHouseSupport() then
      -- nIndex not enabled or enabled but not available for this particular interface
      return
   end

   -- Fetch the alert id
   local alert_id = alert_consts.getAlertType(alert.alert_id, alert.entity_id)
   if alert_id then
      -- If there's a function that generates the filter available for this particular alert,
      -- then the function is called to fetch the filter for the historical flows
      if alert_consts.alert_types[alert_id].filter_to_past_flows then
	 if not alert_json then
	    alert_json = alert_utils.getAlertInfo(alert)
	 end

	 -- Fetch the filter
	 local past_flows_filter = alert_consts.alert_types[alert_id].filter_to_past_flows(ifid, alert, alert_json)
	 local epoch_begin, epoch_end

	 -- Add a default start time, if no start time has been added by the filter-generation function
	 if not past_flows_filter["epoch_begin"] then
	    past_flows_filter["epoch_begin"] = tonumber(alert["tstamp"])
	 end
	 epoch_begin = tonumber(past_flows_filter["epoch_begin"])
	 past_flows_filter["epoch_begin"] = nil

	 -- Add a default end time, if not end time has been added by the filter-generation function
	 if not past_flows_filter["epoch_end"] then
	    local duration = tonumber(alert["duration"]) or (tonumber(alert["tstamp_end"]) - tonumber(alert["tstamp"]))

	    past_flows_filter["epoch_end"] = epoch_begin + duration
	 end
	 epoch_end = tonumber(past_flows_filter["epoch_end"])
	 past_flows_filter["epoch_end"] = nil

	 local tags = {}
	 for name, val in pairs(past_flows_filter) do
	    local filter_op, filter_val

	    if name == "epoch_end" or name == "epoch_begin" then
	       -- They are not tags, they will be inserted as-is
	       goto continue
	    elseif val == true then
	       -- Assumes > 0
	       tags[#tags + 1] = {name = name, op = "gt", val = "0"}
	    elseif string.contains(name, "ip") then
	       -- Unpack the hostkey into two separate fields, one for the VLAN (if present and positive) and one for the IP
	       local host_info = hostkey2hostinfo(val)

	       tags[#tags + 1] = {name = name, op = "eq", val = host_info["host"]}
	       if host_info["vlan"] > 0 then
		  tags[#tags + 1] = {name = "vlan_id", op = "eq", val = tostring(host_info["vlan"])}
	       end
	    elseif string.contains(name, "tcp_flags") then
	       -- Assumes IN query
	       if val >= 0 then
		  -- Assumes IN
		  tags[#tags + 1] = {name = name, op = "in", val = tostring(val)}
	       else
		  -- A negative value assumes NOT IN
		  tags[#tags + 1] = {name = name, op = "nin", val = tostring(-val)}
	       end
	    else
	       -- Fallback, assume equality
	       tags[#tags + 1] = {name = name, op = "eq", val = tostring(val)}
	    end

	    ::continue::
	 end

	 -- Look a bit around the epochs...
	 epoch_begin = epoch_begin - (5*60)
	 epoch_end = epoch_end + (5*60)

	 -- ... but not too much
	 if epoch_end - epoch_begin > 600 then
	    epoch_end = epoch_begin + 600
	 end

	 -- Join the TAG filters using the predefined operator
	 local final_filter = {}
	 for _, tag in pairs(tags) do
	    final_filter[tag.name] = string.format("%s%s%s", tag.val, alert_utils.SEPARATOR, tag.op)
	 end

	 -- tprint({formatEpoch(epoch_begin), formatEpoch(epoch_end), formatEpoch(tonumber(alert.tstamp)), formatEpoch(tonumber(alert.tstamp_end))})

	 -- Return the link augmented with the filter
	 local res = string.format("%s/lua/pro/db_search.lua?epoch_begin=%u&epoch_end=%u&%s",
				   ntop.getHttpPrefix(),
				   epoch_begin,
				   epoch_end,
				   table.tconcat(final_filter, "=", "&"))

	 return res
      end
   end
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
      if options.timezone then
	 when = format_utils.formatEpochISO8601(notif.tstamp_end or notif.tstamp or 0)
      else
	 when = format_utils.formatEpoch(notif.tstamp_end or notif.tstamp or 0)
      end

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

function alert_utils.formatAlertCulript(notif)
   local msg

   -- Formatting cli-srv
   if not isEmptyString(notif.cli_ip) and not isEmptyString(notif.srv_ip) then
      local client = notif.cli_ip
      local server = notif.srv_ip
      local client_port = ''
      local server_port = ''

      if not isEmptyString(notif.cli_name) then
         client = notif.cli_name
      end
      
      if not isEmptyString(notif.srv_name) then
         server = notif.srv_name
      end

      if notif.cli_port ~= 0 then
         client_port = ':' .. notif.cli_port
      end
      
      if notif.srv_port ~= 0 then
         server_port = ':' .. notif.srv_port
      end

      msg = string.format('%s%s \xE2\x9E\xA1 %s%s', client, client_port, server, server_port)
   elseif not isEmptyString(notif.entity_val) then
      msg = notif.entity_val

      if notif.name and not isEmptyString(notif.name) then
         msg = notif.name
      end
   else
      msg = ''
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

-- ##############################################

local function addDayEpoch(res, day_epoch)
   res[day_epoch] = {
      0, --[[ Counter for alerts between 00:00 and 00:59 UTC --]]
      0, --[[ Counter for alerts between 01:00 and 01:59 UTC --]]
      0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 --[[ Counter for alerts in other hours, until 23:00 to 23:59 --]]
   }

   return res
end

-- ##############################################

--@brief Function used to format the old timeseries format (CheckMK integration)
function alert_utils.formatOldTimeseries(q_res, _epoch_begin, _epoch_end)
   local hour_secs = 60*60
   local day_secs = 60*60*24
   local epoch_begin = _epoch_begin - (_epoch_begin % day_secs) -- Round begin to start of day
   local epoch_end = _epoch_end - (_epoch_end % day_secs) + day_secs -- Round end to end of day
   local res = {}

   for _, v in ipairs(q_res) do
      local tstamp = v.hour or v.tstamp
      -- Midnight UTC of the day containing v.hour
      local day_epoch = tstamp - (tstamp % day_secs)

      -- Hour of the day containing v.hour, from 0 to 23, inclusive
      -- NOTE: Use the `floor` to make sure hour is an integer as it will be used to index a Lua array
      local hour = math.floor((tstamp - day_epoch) / hour_secs) 

      -- Here we add 1 to the hour as Lua array are indexed starting from 1, whereas `hour` is an integer starting from zero
      if not res[day_epoch] then
         res = addDayEpoch(res, day_epoch)
      end

      -- This is done for both, enganged and historical alert, historical have v.hour and v.count, instead engaged
      -- There is one entry per engaged, reporting the starting time (tstamp), so just add +1 to the hour having that alert 
      res[day_epoch][hour + 1] = tonumber(--[[ Historical ]]v.count or --[[ Engaged ]]((res[day_epoch][hour + 1] or 0) + 1))
   end -- for

   return res
end

-- ##############################################

return alert_utils
