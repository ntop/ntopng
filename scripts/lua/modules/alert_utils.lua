--
-- (C) 2014-18 - ntop.org
--

-- This file contains the description of all functions
-- used to trigger host alerts

local verbose = ntop.getCache("ntopng.prefs.alerts.debug") == "1"
local callback_utils = require "callback_utils"
local template = require "template_utils"
local json = require("dkjson")
local host_pools_utils = require("host_pools_utils")
local recovery_utils = require "recovery_utils"
local alert_consts = require "alert_consts"
local format_utils = require "format_utils"
local telemetry_utils = require "telemetry_utils"
local tracker = require "tracker"
local alerts = require "alerts_api"
local alert_endpoints = require "alert_endpoints_utils"

local alert_process_queue = "ntopng.alert_process_queue"
local host_remote_to_remote_alerts_queue = "ntopng.alert_host_remote_to_remote"
local inactive_hosts_hash_key = "ntopng.prefs.alerts.ifid_%d.inactive_hosts_alerts"
local alert_login_queue = "ntopng.alert_login_trace_queue"

local shaper_utils = nil

local CONST_DEFAULT_PACKETS_DROP_PERCENTAGE_ALERT = "5"

if(ntop.isnEdge()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   shaper_utils = require("shaper_utils")
end

-- ##############################################

function alertSeverityRaw(severity_id)
  severity_id = tonumber(severity_id)

  for key, severity_info in pairs(alert_consts.alert_severities) do
    if(severity_info.severity_id == severity_id) then
      return(key)
    end
  end
end

function alertSeverityLabel(v, nohtml)
   local severity_id = alertSeverityRaw(v)

   if(severity_id) then
      local severity_info = alert_consts.alert_severities[severity_id]
      local title = i18n(severity_info.i18n_title) or severity_info.i18n_title

      if(nohtml) then
        return(title)
      else
        return(string.format('<span class="label %s">%s</span>', severity_info.label, title))
      end
   end
end

function alertSeverity(v)
  return(alert_consts.alert_severities[v].severity_id)
end

-- ##############################################

function alertTypeRaw(type_id)
  type_id = tonumber(type_id)

  for key, type_info in pairs(alert_consts.alert_types) do
    if(type_info.alert_id == type_id) then
      return(key)
    end
  end
end

function alertTypeLabel(v, nohtml)
   local alert_id = alertTypeRaw(v)

   if(alert_id) then
      local type_info = alert_consts.alert_types[alert_id]
      local title = i18n(type_info.i18n_title) or type_info.i18n_title

      if(nohtml) then
        return(title)
      else
        return(string.format('<i class="fa %s"></i> %s', type_info.icon, title))
      end
   end
end

function alertType(v)
  return(alert_consts.alert_types[v].alert_id)
end

function alertTypeDescription(v)
  local alert_id = alertTypeRaw(v)

  if(alert_id) then
    return(alert_consts.alert_types[alert_id].i18n_description)
  end
end

-- ##############################################

-- Rename engine -> granulariy
function alertEngineRaw(granularity_id)
  granularity_id = tonumber(granularity_id)

  for key, granularity_info in pairs(alert_consts.alerts_granularities) do
    if(granularity_info.granularity_id == granularity_id) then
      return(key)
    end
  end
end

function alertEngine(v)
   return(alert_consts.alerts_granularities[v].granularity_id)
end

function alertEngineLabel(v)
  local granularity_id = alertEngineRaw(v)

  if(granularity_id ~= nil) then
    return(i18n(alert_consts.alerts_granularities[granularity_id].i18n_title))
  end
end

function alertEngineDescription(v)
  local granularity_id = alertEngineRaw(v)

  if(granularity_id ~= nil) then
    return(i18n(alert_consts.alerts_granularities[granularity_id].i18n_description))
  end
end

function granularity2sec(v)
  return(alert_consts.alerts_granularities[v].granularity_seconds)
end

-- See NetworkInterface::checkHostsAlerts()
function granularity2id(granularity)
  -- TODO replace alertEngine
  return(alertEngine(granularity))
end

function sec2granularity(seconds)
  seconds = tonumber(seconds)

  for key, granularity_info in pairs(alert_consts.alerts_granularities) do
    if(granularity_info.granularity_seconds == seconds) then
      return(key)
    end
  end
end

-- ##############################################

function alertEntityRaw(entity_id)
  entity_id = tonumber(entity_id)

  for key, entity_info in pairs(alert_consts.alert_entities) do
    if(entity_info.entity_id == entity_id) then
      return(key)
    end
  end
end

function alertEntity(v)
   return(alert_consts.alert_entities[v].entity_id)
end

function alertEntityLabel(v, nothml)
  local entity_id = alertEntityRaw(v)

  if(entity_id) then
    return(alert_consts.alert_entities[entity_id].label)
  end
end

-- ##############################################################################

local function getInterfacePacketDropPercAlertKey(ifname)
   return "ntopng.prefs.iface_" .. getInterfaceId(ifname) .. ".packet_drops_alert"
end

-- ##############################################################################

if ntop.isEnterprise() then
   local dirs = ntop.getDirs()
   package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/modules/?.lua;" .. package.path
   require "enterprise_alert_utils"
end

j = require("dkjson")
require "persistence"

function is_allowed_timespan(timespan)
   return(alert_consts.alerts_granularities[timespan] ~= nil)
end

function get_alerts_hash_name(timespan, ifname, entity_type)
   local ifid = getInterfaceId(ifname)
   if not is_allowed_timespan(timespan) or tonumber(ifid) == nil then
      return nil
   end

   return "ntopng.prefs.alerts_"..timespan..".".. entity_type ..".ifid_"..tostring(ifid)
end

-- Get the hash key used for saving global settings
local function get_global_alerts_hash_key(entity_type, alert_source, local_hosts)
   if entity_type == "host" then
      if local_hosts then
        return "local_hosts"
      else
        return "remote_hosts"
      end
   elseif entity_type == "interface" then
      return "interfaces"
   elseif entity_type == "network" then
      return "local_networks"
   else
      return "*"
   end
end

function get_make_room_keys(ifId)
   return {flows="ntopng.cache.alerts.ifid_"..ifId..".make_room_flow_alerts",
	   entities="ntopng.cache.alerts.ifid_"..ifId..".make_room_closed_alerts"}
end

-- =====================================================

function get_alerts_suppressed_hash_name(ifid)
   local hash_name = "ntopng.prefs.alerts.ifid_"..ifid
   return hash_name
end

function are_alerts_suppressed(observed, ifid)
   local suppressAlerts = ntop.getHashCache(get_alerts_suppressed_hash_name(ifid), observed)
   --[[
      tprint("are_alerts_suppressed ".. suppressAlerts)
      tprint("are_alerts_suppressed observed: ".. observed)
      tprint("are_alerts_suppressed ifname: "..ifname)
   --]]
   if((suppressAlerts == "") or (suppressAlerts == nil) or (suppressAlerts == "true")) then
      return false  -- alerts are not suppressed
   else
      if(verbose) then print("Skipping alert check for("..observed.."): disabled in preferences<br>\n") end
      return true -- alerts are suppressed
   end
end

-- #################################

function performAlertsQuery(statement, what, opts, force_query)
   local wargs = {"WHERE", "1=1"}
   local oargs = {}

   if tonumber(opts.row_id) ~= nil then
      wargs[#wargs+1] = 'AND rowid = '..(opts.row_id)
   end

   if (not isEmptyString(opts.entity)) and (not isEmptyString(opts.entity_val)) then
      if((what == "historical-flows") and (alertEntityRaw(opts.entity) == "host")) then
         -- need to handle differently for flows table
         local info = hostkey2hostinfo(opts.entity_val)
         wargs[#wargs+1] = 'AND (cli_addr="'..(info.host)..'" OR srv_addr="'..(info.host)..'")'
         wargs[#wargs+1] = 'AND vlan_id='..(info.vlan)
      else
         wargs[#wargs+1] = 'AND alert_entity = "'..(opts.entity)..'"'
         wargs[#wargs+1] = 'AND alert_entity_val = "'..(opts.entity_val)..'"'
      end
   elseif (what ~= "historical-flows") then
      if (not isEmptyString(opts.entity)) then
	 wargs[#wargs+1] = 'AND alert_entity = "'..(opts.entity)..'"'
      elseif(not isEmptyString(opts.entity_excludes)) then
	 local excludes = string.split(opts.entity_excludes, ",") or {opts.entity_excludes}

	 for _, entity in pairs(excludes) do
	    wargs[#wargs+1] = 'AND alert_entity != "'.. entity ..'"'
	 end
      end
   end

   if not isEmptyString(opts.origin) then
      local info = hostkey2hostinfo(opts.origin)
      wargs[#wargs+1] = 'AND cli_addr="'..(info.host)..'"'
      wargs[#wargs+1] = 'AND vlan_id='..(info.vlan)
   end

   if not isEmptyString(opts.target) then
      local info = hostkey2hostinfo(opts.target)
      wargs[#wargs+1] = 'AND srv_addr="'..(info.host)..'"'
      wargs[#wargs+1] = 'AND vlan_id='..(info.vlan)
   end

   if tonumber(opts.epoch_begin) ~= nil then
      wargs[#wargs+1] = 'AND alert_tstamp >= '..(opts.epoch_begin)
   end

   if tonumber(opts.epoch_end) ~= nil then
      wargs[#wargs+1] = 'AND alert_tstamp <= '..(opts.epoch_end)
   end

   if not isEmptyString(opts.flowhosts_type) then
      if opts.flowhosts_type ~= "all_hosts" then
         local cli_local, srv_local = 0, 0

         if opts.flowhosts_type == "local_only" then cli_local, srv_local = 1, 1
         elseif opts.flowhosts_type == "remote_only" then cli_local, srv_local = 0, 0
         elseif opts.flowhosts_type == "local_origin_remote_target" then cli_local, srv_local = 1, 0
         elseif opts.flowhosts_type == "remote_origin_local_target" then cli_local, srv_local = 0, 1
         end

         if what == "historical-flows" then
            wargs[#wargs+1] = "AND cli_localhost = "..cli_local
            wargs[#wargs+1] = "AND srv_localhost = "..srv_local
         end
         -- TODO cannot apply it to other tables right now
      end
   end

   if tonumber(opts.alert_type) ~= nil then
      wargs[#wargs+1] = "AND alert_type = "..(opts.alert_type)
   end

   if tonumber(opts.alert_severity) ~= nil then
      wargs[#wargs+1] = "AND alert_severity = "..(opts.alert_severity)
   end

   if((not isEmptyString(opts.sortColumn)) and (not isEmptyString(opts.sortOrder))) then
      local order_by

      if opts.sortColumn == "column_date" then
         order_by = "alert_tstamp"
      elseif opts.sortColumn == "column_severity" then
         order_by = "alert_severity"
      elseif opts.sortColumn == "column_type" then
         order_by = "alert_type"
      elseif opts.sortColumn == "column_count" and what ~= "engaged" then
         order_by = "alert_counter"
      elseif((opts.sortColumn == "column_duration") and (what == "historical")) then
         order_by = "(alert_tstamp_end - alert_tstamp)"
      else
         -- default
         order_by = "alert_tstamp"
      end

      oargs[#oargs+1] = "ORDER BY "..order_by
      oargs[#oargs+1] = string.upper(opts.sortOrder)
   end

   -- pagination
   if((tonumber(opts.perPage) ~= nil) and (tonumber(opts.currentPage) ~= nil)) then
      local to_skip = (tonumber(opts.currentPage)-1) * tonumber(opts.perPage)
      oargs[#oargs+1] = "LIMIT"
      oargs[#oargs+1] = to_skip..","..(opts.perPage)
   end

   local query = table.concat(wargs, " ")
   local res

   query = query .. " " .. table.concat(oargs, " ")

   -- Uncomment to debug the queries
   --~ tprint(statement.." (from "..what..") "..query)

   if what == "engaged" then
      res = interface.queryAlertsRaw(statement, query, force_query)
   elseif what == "historical" then
      res = interface.queryAlertsRaw(statement, query, force_query)
   elseif what == "historical-flows" then
      res = interface.queryFlowAlertsRaw(statement, query, force_query)
   else
      error("Invalid alert subject: "..what)
   end

   return res
end

-- #################################

function getNumAlerts(what, options)
   if isEmptyString(what) then
      return getNumAlerts("engaged", options) +
         getNumAlerts("historical", options) +
         getNumAlerts("historical-flows", options)
   end

   local num = 0

   if(what == "engaged") then
     local entity_type_filter = tonumber(options.entity)
     local entity_value_filter = options.entity_val
     local res = interface.getEngagedAlertsCount(entity_type_filter, entity_value_filter)

     if(res ~= nil) then num = res.num_alerts end
   else
     local opts = getUnpagedAlertOptions(options or {})
     local res = performAlertsQuery("SELECT COUNT(*) AS count", what, opts)
     if((res ~= nil) and (#res == 1) and (res[1].count ~= nil)) then num = tonumber(res[1].count) end
   end

   return num
end

-- #################################

local function engagedAlertsQuery(params)
  local type_filter = tonumber(params.alert_type)
  local severity_filter = tonumber(params.alert_severity)
  local entity_type_filter = tonumber(params.entity)
  local entity_value_filter = params.entity_val

  local perPage = tonumber(params.perPage)
  local sortColumn = params.sortColumn
  local sortOrder = params.sortOrder
  local sOrder = ternary(sortOrder == "desc", rev_insensitive, asc_insensitive)
  local currentPage = tonumber(params.currentPage)
  local totalRows = 0

  --~ tprint(string.format("type=%s sev=%s entity=%s val=%s", type_filter, severity_filter, entity_type_filter, entity_value_filter))
  local alerts = interface.getEngagedAlerts(entity_type_filter, entity_value_filter, type_filter, severity_filter)
  local sort_2_col = {}

  -- Sort
  for idx, alert in pairs(alerts) do
    if sortColumn == "column_type" then
      sort_2_col[idx] = alert.alert_type
    elseif sortColumn == "column_severity" then
      sort_2_col[idx] = alert.alert_severity
    elseif sortColumn == "column_duration" then
      sort_2_col[idx] = os.time() - alert.alert_tstamp
    else -- column_date
      sort_2_col[idx] = alert.alert_tstamp
    end

    totalRows = totalRows + 1
  end

  -- Pagination
  local to_skip = (currentPage-1) * perPage
  local totalRows = #alerts
  local res = {}
  local i = 0

  for idx in pairsByValues(sort_2_col, sOrder) do
    if i >= to_skip + perPage then
      break
    end

    if (i >= to_skip) then
      res[#res + 1] = alerts[idx]
    end

    i = i + 1
  end

  return(res)
end

-- #################################

function getAlerts(what, options)
   if what == "engaged" then
      return engagedAlertsQuery(options)
   else
      return performAlertsQuery("SELECT rowid, *", what, options)
   end
end

-- #################################

local function refreshAlerts(ifid)
   ntop.delCache(string.format("ntopng.cache.alerts.ifid_%d.has_alerts", ifid))
   ntop.delCache("ntopng.cache.update_alerts_stats_time")
end

-- #################################

function deleteAlerts(what, options)
   local opts = getUnpagedAlertOptions(options or {})
   performAlertsQuery("DELETE", what, opts)
   refreshAlerts(interface.getId())
end

-- #################################

-- this function returns an object with parameters specific for one tab
function getTabParameters(_get, what)
   local opts = {}
   for k,v in pairs(_get) do opts[k] = v end

   -- these options are contextual to the current tab (status)
   if _get.status ~= what then
      opts.alert_type = nil
      opts.alert_severity = nil
   end
   if not isEmptyString(what) then opts.status = what end
   return opts
end

-- #################################

-- Remove pagination options from the options
function getUnpagedAlertOptions(options)
   local res = {}

   local paged_option = { currentPage=1, perPage=1, sortColumn=1, sortOrder=1 }

   for k,v in pairs(options) do
      if not paged_option[k] then
         res[k] = v
      end
   end

   return res
end

-- #################################

function checkDeleteStoredAlerts()
   _GET["status"] = _GET["status"] or _POST["status"]

   if((_POST["id_to_delete"] ~= nil) and (_GET["status"] ~= nil)) then
      if(_POST["id_to_delete"] ~= "__all__") then
         _GET["row_id"] = tonumber(_POST["id_to_delete"])
      end

      deleteAlerts(_GET["status"], _GET)

      -- TRACKER HOOK
      tracker.log("checkDeleteStoredAlerts", {_GET["status"], _POST["id_to_delete"]})

      -- to avoid performing the delete again
      _POST["id_to_delete"] = nil
      -- to avoid filtering by id
      _GET["row_id"] = nil
      -- in case of delete "older than" button, resets the time period after the delete took place
      if isEmptyString(_GET["epoch_begin"]) then _GET["epoch_end"] = nil end

      local new_num = getNumAlerts(_GET["status"], _GET)
      if new_num == 0 then
         -- reset the filter to avoid hiding the tab
         _GET["alert_severity"] = nil
         _GET["alert_type"] = nil
      end
   end
end

-- #################################

local function getFlowStatusInfo(record, status_info)
   local res = ""

   local l7proto_name = interface.getnDPIProtoName(tonumber(record["l7_proto"]) or 0)
   if l7proto_name == "ICMP" then -- is ICMPv4
      local type_code = {type = status_info["icmp.icmp_type"], code = status_info["icmp.icmp_code"]}

      if status_info["icmp.unreach.src_ip"] then
	 res = string.format("[%s]", i18n("icmp_page.icmp_port_unreachable_extra", {unreach_host=status_info["icmp.unreach.dst_ip"], unreach_port=status_info["icmp.unreach.dst_port"], unreach_protocol = l4_proto_to_string(status_info["icmp.unreach.protocol"])}))
      else
	 res = string.format("[%s]", getICMPTypeCode(type_code))
      end
   end

   return string.format(" %s", res)
end

-- #################################

function formatRawFlow(record, flow_json, skip_add_links)
   -- Emanuele said: this function can also be called from alertNotificationToObject
   -- with a dummy flow without timestamp. In that case we must skip_add_links
   -- or we will get an exception
   require "flow_utils"
   local time_bounds
   local add_links = false

   if hasNindexSupport() and not skip_add_links then
      -- only add links if nindex is present
      add_links = true
      time_bounds = {getAlertTimeBounds(record)}
   end

   local decoded = json.decode(flow_json)
   local status_info = alert2statusinfo(decoded)

   -- active flow lookup
   if status_info and status_info["ntopng.key"] and record["alert_tstamp"] then
      -- attempt a lookup on the active flows
      local active_flow = interface.findFlowByKey(status_info["ntopng.key"])

      if active_flow and active_flow["seen.first"] < tonumber(record["alert_tstamp"]) then
	 return string.format("%s [%s: <A HREF='%s/lua/flow_details.lua?flow_key=%u'><span class='label label-info'>Info</span></A> %s]",
			      getFlowStatus(tonumber(record["flow_status"]), status_info),
			      i18n("flow"), ntop.getHttpPrefix(), active_flow["ntopng.key"],
			      getFlowLabel(active_flow, true, true))
      end
   end

   -- pretend record is a flow to reuse getFlowLabel
   local flow = {
      ["cli.ip"] = record["cli_addr"], ["cli.port"] = tonumber(record["cli_port"]),
      ["cli.blacklisted"] = tostring(record["cli_blacklisted"]) == "1",
      ["srv.ip"] = record["srv_addr"], ["srv.port"] = tonumber(record["srv_port"]),
      ["srv.blacklisted"] = tostring(record["srv_blacklisted"]) == "1",
      ["vlan"] = record["vlan_id"]}
   flow = "["..i18n("flow")..": "..(getFlowLabel(flow, false, add_links, time_bounds) or "").."] "

   local l4_proto_label = l4_proto_to_string(record["proto"] or 0) or ""

   if not isEmptyString(l4_proto_label) then
      flow = flow.."[" .. l4_proto_label .. "] "
   end

   local l7proto_name = interface.getnDPIProtoName(tonumber(record["l7_proto"]) or 0)

   if record["l7_master_proto"] and record["l7_master_proto"] ~= "0" then
      local l7proto_master_name = interface.getnDPIProtoName(tonumber(record["l7_master_proto"]))

      if l7proto_master_name ~= l7proto_name then
	 l7proto_name = string.format("%s.%s", l7proto_master_name, l7proto_name)
      end
   end

   if not isEmptyString(l7proto_name) and l4_proto_label ~= l7proto_name then
      flow = flow.."["..i18n("application")..": " ..l7proto_name.."] "
   end

   if decoded ~= nil then
      -- render the json
      local msg = ""

      if not isEmptyString(record["flow_status"]) then
         msg = msg..getFlowStatus(tonumber(record["flow_status"]), status_info).." "
      end

      if not isEmptyString(flow) then
         msg = msg..flow.." "
      end

      if not isEmptyString(decoded["info"]) then
         local lb = ""
         if (record["flow_status"] == "13") -- blacklisted flow
                  and (not flow["srv.blacklisted"]) and (not flow["cli.blacklisted"]) then
            lb = " <i class='fa fa-ban' aria-hidden='true' title='Blacklisted'></i>"
         end
         msg = msg.."["..i18n("info")..": "..decoded["info"]..lb.."] "
      end

      flow = msg
   end

   if status_info then
      flow = flow..getFlowStatusInfo(record, status_info)
   end

   return flow
end

-- #################################

function formatRawUserActivity(record, activity_json)
  local decoded = json.decode(activity_json)
  local user = record.alert_entity_val

  -- tprint(activity_json)

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
        local hostname = host2name(hostinfo.host, hostinfo.vlan)
        local host_url = "<a href=\"".. ntop.getHttpPrefix() .. "/lua/host_details.lua?ifid="..decoded.ifid.."&host="..host.."\">"..hostname .."</a>" 
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
        elseif service_name == 'n2n' then
          return i18n('user_activity.remote_assistance_disabled', {user=user})
        end

      elseif decoded.name == 'enableService' and decoded.params[1] ~= nil then
        local service_name = decoded.params[1]
        if service_name == 'n2disk-ntopng' and decoded.params[2] ~= nil then
          local service_instance = decoded.params[2]
          return i18n('user_activity.recording_enabled', {user=user, ifname=service_instance})
        elseif service_name == 'n2n' then
          return i18n('user_activity.remote_assistance_enabled', {user=user})
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
          local hostname = host2name(hostinfo.host, hostinfo.vlan)
          local host_url = "<a href=\"".. ntop.getHttpPrefix() .. "/lua/host_details.lua?ifid="..decoded.ifid.."&host="..host.."\">"..hostname .."</a>" 
          return i18n('user_activity.exported_data_host', {user=user, mode=mode, host=host_url})
        else
          return i18n('user_activity.exported_data', {user=user, mode=mode})
        end

      elseif decoded.name == 'host_get_json' and decoded.params[1] ~= nil then
        local host = decoded.params[1]
        local hostinfo = hostkey2hostinfo(host)
        local hostname = host2name(hostinfo.host, hostinfo.vlan)
        local host_url = "<a href=\"".. ntop.getHttpPrefix() .. "/lua/host_details.lua?ifid="..decoded.ifid.."&host="..host.."\">"..hostname .."</a>" 
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
          local hostname = host2name(hostinfo.host, hostinfo.vlan)
          local host_url = "<a href=\"".. ntop.getHttpPrefix() .. "/lua/host_details.lua?ifid="..decoded.ifid.."&host="..host.."\">"..hostname .."</a>" 
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
        elseif k == "ssl_alerts" then pref_desc = i18n("prefs.toggle_ssl_alerts_title")
        elseif k == "dns_alerts" then pref_desc = i18n("prefs.toggle_dns_alerts_title")
        elseif k == "ip_reassignment_alerts" then pref_desc = i18n("prefs.toggle_ip_reassignment_title")
        elseif k == "remote_to_remote_alerts" then pref_desc = i18n("prefs.toggle_remote_to_remote_alerts_title")
        elseif k == "mining_alerts" then pref_desc = i18n("prefs.toggle_mining_alerts_title")
        elseif k == "host_blacklist" then pref_desc = i18n("prefs.toggle_malware_probing_title")
        elseif k == "ids_alerts" then pref_desc = i18n("prefs.toggle_ids_alert_title")
        elseif k == "device_protocols_alerts" then pref_desc = i18n("prefs.toggle_device_protocols_title")
        elseif k == "alerts.device_first_seen_alert" then pref_desc = i18n("prefs.toggle_device_first_seen_alert_title")
        elseif k == "alerts.device_connection_alert" then pref_desc = i18n("prefs.toggle_device_activation_alert_title")
        elseif k == "alerts.pool_connection_alert" then pref_desc = i18n("prefs.toggle_pool_activation_alert_title")
        elseif k == "alerts.external_notifications_enabled" then pref_desc = i18n("prefs.toggle_alerts_notifications_title")
        elseif k == "alerts.email_notifications_enabled" then pref_desc = i18n("prefs.toggle_email_notification_title")
        elseif k == "alerts.slack_notifications_enabled" then pref_desc = i18n("prefs.toggle_slack_notification_title", {url="http://www.slack.com"})
        elseif k == "alerts.syslog_notifications_enabled" then pref_desc = i18n("prefs.toggle_alert_syslog_title")
        elseif k == "alerts.nagios_notifications_enabled" then pref_desc = i18n("prefs.toggle_alert_nagios_title")
        elseif k == "alerts.webhook_notifications_enabled" then pref_desc = i18n("prefs.toggle_webhook_notification_title")
        elseif starts(k, "alerts.email_") then pref_desc = i18n("prefs.email_notification")
        elseif starts(k, "alerts.smtp_") then pref_desc = i18n("prefs.email_notification")
        elseif starts(k, "alerts.slack_") then pref_desc = i18n("prefs.slack_integration")
        elseif starts(k, "alerts.nagios_") then pref_desc = i18n("prefs.nagios_integration")
        elseif starts(k, "nagios_") then pref_desc = i18n("prefs.nagios_integration")
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

-- #################################

local function getMenuEntries(status, selection_name)
   -- compute counters to avoid printing items that have zero entries in the database
   local actual_entries = {}
   if status == "historical-flows" then

      if selection_name == "severity" then
	 actual_entries = interface.queryFlowAlertsRaw("select alert_severity id, count(*) count", "group by alert_severity")
      elseif selection_name == "type" then
	 actual_entries = interface.queryFlowAlertsRaw("select alert_type id, count(*) count", "group by alert_type")
      end

   else -- dealing with non flow alerts (engaged and closed)
      local engaged
      if status == "engaged" then
	 engaged = true
      elseif status == "historical" then
	 engaged = false
      end

      if selection_name == "severity" then
	 actual_entries = interface.queryAlertsRaw("select alert_severity id, count(*) count", "group by alert_severity")
      elseif selection_name == "type" then
	 actual_entries = interface.queryAlertsRaw("select alert_type id, count(*) count", "group by alert_type")
      end
   end

   return(actual_entries)
end

-- #################################

local function dropdownUrlParams(get_params)
  local buttons = ""

  for param, val in pairs(get_params) do
    if((param ~= "alert_severity") and (param ~= "alert_type")) then
      buttons = buttons.."&"..param.."="..val
    end
  end

  return(buttons)
end

-- #################################

local function drawDropdown(status, selection_name, active_entry, entries_table, button_label, get_params, actual_entries)
   -- alert_consts.alert_severity_keys and alert_consts.alert_type_keys are defined in lua_utils
   local id_to_label
   if selection_name == "severity" then
      id_to_label = alertSeverityLabel
   elseif selection_name == "type" then
      id_to_label = alertTypeLabel
   end

   actual_entries = actual_entries or getMenuEntries(status, selection_name)

   local buttons = '<div class="btn-group">'

   button_label = button_label or firstToUpper(selection_name)
   if active_entry ~= nil and active_entry ~= "" then
      button_label = firstToUpper(active_entry)..'<span class="glyphicon glyphicon-filter"></span>'
   end

   buttons = buttons..'<button class="btn btn-link dropdown-toggle" data-toggle="dropdown">'..button_label
   buttons = buttons..'<span class="caret"></span></button>'

   buttons = buttons..'<ul class="dropdown-menu dropdown-menu-right" role="menu">'

   local class_active = ""
   if active_entry == nil then class_active = ' class="active"' end
   buttons = buttons..'<li'..class_active..'><a href="?status='..status..dropdownUrlParams(get_params)..'">All</a></i>'

   for _, entry in pairs(actual_entries) do
      local id = tonumber(entry["id"])
      local count = entry["count"]
      local label = id_to_label(id, true)

      class_active = ""
      if label == active_entry then class_active = ' class="active"' end
      -- buttons = buttons..'<li'..class_active..'><a href="'..ntop.getHttpPrefix()..'/lua/show_alerts.lua?status='..status
      buttons = buttons..'<li'..class_active..'><a href="?status='..status
      buttons = buttons..dropdownUrlParams(get_params)
      buttons = buttons..'&alert_'..selection_name..'='..id..'">'
      buttons = buttons..firstToUpper(label)..' ('..count..')</a></li>'
   end

   buttons = buttons..'</ul></div>'

   return buttons
end

-- #################################

local function getGlobalAlertsConfigurationHash(granularity, entity_type, alert_source, local_hosts)
   return 'ntopng.prefs.alerts_global.'..granularity.."."..get_global_alerts_hash_key(entity_type, alert_source, local_hosts)
end

local global_redis_thresholds_key = "thresholds"

-- #################################

function drawAlertSourceSettings(entity_type, alert_source, delete_button_msg, delete_confirm_msg, page_name, page_params, alt_name, show_entity, options)
   local num_engaged_alerts, num_past_alerts, num_flow_alerts = 0,0,0
   local tab = _GET["tab"]
   local have_nedge = ntop.isnEdge()
   options = options or {}

   local descr = alerts.load_check_modules(entity_type)

   local anomaly_config_key = nil
   local flow_rate_alert_thresh, syn_alert_thresh

   if entity_type == "host" then
      anomaly_config_key = 'ntopng.prefs.'..(options.host_ip)..':'..tostring(options.host_vlan)..'.alerts_config'
   end

   print('<ul class="nav nav-tabs">')

   local function printTab(tab, content, sel_tab)
      if(tab == sel_tab) then print("\t<li class=active>") else print("\t<li>") end
      print("<a href=\""..ntop.getHttpPrefix().."/lua/"..page_name.."?page=alerts&tab="..tab)
      for param, value in pairs(page_params) do
         print("&"..param.."="..value)
      end
      print("\">"..content.."</a></li>\n")
   end

   if(show_entity) then
      -- these fields will be used to perform queries
      _GET["entity"] = alertEntity(show_entity)
      _GET["entity_val"] = alert_source
   end

   if(show_entity) then
      -- possibly process pending delete arguments
      checkDeleteStoredAlerts()

      -- possibly add a tab if there are alerts configured for the host
      num_engaged_alerts = getNumAlerts("engaged", getTabParameters(_GET, "engaged"))
      --~ num_past_alerts = getNumAlerts("historical", getTabParameters(_GET, "historical"))
      --~ num_flow_alerts = getNumAlerts("historical-flows", getTabParameters(_GET, "historical-flows"))

      if num_past_alerts > 0 or num_engaged_alerts > 0 or num_flow_alerts > 0 then
         if(tab == nil) then
            -- if no tab is selected and there are alerts, we show them by default
            tab = "alert_list"
         end

         printTab("alert_list", i18n("show_alerts.engaged_alerts"), tab)
      else
         -- if there are no alerts, we show the alert settings
         if(tab=="alert_list") then tab = nil end
      end
   end

   -- Default tab
   if(tab == nil) then tab = "min" end

   if(tab ~= "alert_list") then
      local granularity_label = alertEngineLabel(alertEngine(tab))

      print(
	 template.gen("modal_confirm_dialog.html", {
			 dialog={
			    id      = "deleteAlertSourceSettings",
			    action  = "deleteAlertSourceSettings()",
			    title   = i18n("show_alerts.delete_alerts_configuration"),
			    message = i18n(delete_confirm_msg, {granularity=granularity_label}) .. " <span style='white-space: nowrap;'>" .. ternary(alt_name ~= nil, alt_name, alert_source).."</span>?",
			    confirm = i18n("delete")
			 }
	 })
      )

      print(
	 template.gen("modal_confirm_dialog.html", {
			 dialog={
			    id      = "deleteGlobalAlertConfig",
			    action  = "deleteGlobalAlertConfig()",
			    title   = i18n("show_alerts.delete_alerts_configuration"),
			    message = i18n("show_alerts.delete_config_message", {conf = entity_type, granularity=granularity_label}).."?",
			    confirm = i18n("delete")
			 }
	 })
      )
   end

   for k, granularity in pairsByField(alert_consts.alerts_granularities, "granularity_id", asc) do
      local l = i18n(granularity.i18n_title)
      local resolution = granularity.granularity_seconds

      if (not options.remote_host) or resolution <= 60 then
	 l = '<i class="fa fa-cog" aria-hidden="true"></i>&nbsp;'..l
	 printTab(k, l, tab)
      end
   end

   -- keep defaults in sync with ntop_defines.h
   local anomalies_config = {
   }

   local global_redis_hash = getGlobalAlertsConfigurationHash(tab, entity_type, alert_source, not options.remote_host)

   print('</ul>')

   if((show_entity) and (tab == "alert_list")) then
      drawAlertTables(num_past_alerts, num_engaged_alerts, num_flow_alerts, _GET, true, nil, { engaged_only = true })
   else
      -- Before doing anything we need to check if we need to save values

      vals = { }
      alerts = ""
      global_alerts = ""
      anomalies = {}
      global_anomalies = {}
      to_save = false

      if((_POST["to_delete"] ~= nil) and (_POST["SaveAlerts"] == nil)) then
         if _POST["to_delete"] == "local" then
            -- Delete threshold configuration
            ntop.delHashCache(get_alerts_hash_name(tab, ifname, entity_type), alert_source)

            -- Delete specific settings
            if entity_type == "host" then
               ntop.delCache(anomaly_config_key)
               interface.refreshHostsAlertsConfiguration()
            elseif entity_type == "interface" then
               ntop.delCache(getInterfacePacketDropPercAlertKey(ifname))
               interface.loadPacketsDropsAlertPrefs()
            end
            alerts = nil

            -- Load the global settings normally
            global_alerts = ntop.getHashCache(global_redis_hash, global_redis_thresholds_key)
         else
            -- Only delete global configuration
            ntop.delCache(global_redis_hash)
         end
      end

      if _POST["to_delete"] ~= "local" then
	 if not table.empty(_POST) then
	    to_save = true
	 end

         -- TODO refactor this into the threshold cross checker
         for k, check_module in pairs(descr) do
	    value    = _POST["value_"..k]
	    operator = _POST["op_"..k]

	    if((value ~= nil) and (operator ~= nil)) then
	       --io.write("\t"..k.."\n")
	       value = tonumber(value)
	       if(value ~= nil) then
		  if(alerts ~= "") then alerts = alerts .. "," end
		  alerts = alerts .. k .. ";" .. operator .. ";" .. value
	       end

	       -- Handle global settings
	       local global_value = tonumber(_POST["value_global_"..k])
	       local global_operator = _POST["op_global_"..k]

	       if (global_value ~= nil) and (global_operator ~= nil) then
		  if(global_alerts ~= "") then global_alerts = global_alerts .. "," end
		  global_alerts = global_alerts..k..";"..global_operator..";"..global_value
	       end
	    end
         end --END for k,_ in pairs(descr) do

         -- Save source specific anomalies
         if (tab == "min") and (to_save or (_POST["to_delete"] ~= nil)) then
            if entity_type == "host" then
               local config_to_dump = {}

               for _, config in ipairs(anomalies_config) do
                  local value = _POST[config.key]
                  local global_value = _POST["global_"..config.key]

                  if isEmptyString(global_value) then
                     global_value = config.global_default
                  end

                  global_anomalies["global_"..config.key] = global_value
		  ntop.setHashCache(global_redis_hash, config.key, global_value)

                  if not isEmptyString(value) then
                     anomalies[config.key] = value
                  else
                     value = "global"
                  end

                  config_to_dump[#config_to_dump + 1] = value
               end

	       -- Serialize the settings
               local configdump = table.concat(config_to_dump, "|")
               ntop.setCache(anomaly_config_key, configdump)
               interface.refreshHostsAlertsConfiguration()
            elseif entity_type == "interface" then
               local value = _POST["packets_drops_perc"]
               ntop.setCache(getInterfacePacketDropPercAlertKey(ifname), ternary(not isEmptyString(value), value, "0"))
               interface.loadPacketsDropsAlertPrefs()
            end
         end

         --print(alerts)

         if(to_save and (_POST["to_delete"] == nil)) then
            -- This specific entity alerts
            if(alerts == "") then
               ntop.delHashCache(get_alerts_hash_name(tab, ifname, entity_type), alert_source)
            else
               ntop.setHashCache(get_alerts_hash_name(tab, ifname, entity_type), alert_source, alerts)
            end

            -- Global alerts
            if(global_alerts ~= "") then
               ntop.setHashCache(global_redis_hash, global_redis_thresholds_key, global_alerts)
            else
               ntop.delHashCache(global_redis_hash, global_redis_thresholds_key)
            end
         else
            alerts = ntop.getHashCache(get_alerts_hash_name(tab, ifname, entity_type), alert_source)
            global_alerts = ntop.getHashCache(global_redis_hash, global_redis_thresholds_key)
         end
      end -- END if _POST["to_delete"] ~= nil

      --print(alerts)
      --tokens = string.split(alerts, ",")
      for _, al in pairs({
	    {prefix = "", config = alerts},
	    {prefix = "global_", config = global_alerts},
      }) do
	 if al.config ~= nil then
	    tokens = split(al.config, ",")

	    --print(tokens)
	    if(tokens ~= nil) then
	       for _,s in pairs(tokens) do
		  t = string.split(s, ";")
		  --print("-"..t[1].."-")
		  if(t ~= nil) then vals[(al.prefix)..t[1]] = { t[2], t[3] } end
	       end
	    end
	 end
      end


      print [[
       </ul>
       <form method="post">
       <table id="user" class="table table-bordered table-striped" style="clear: both"> <tbody>
       <tr><th>]] print(i18n("alerts_thresholds_config.threshold_type")) print[[</th><th width=30%>]] print(i18n("alerts_thresholds_config.thresholds_single_source", {source=firstToUpper(entity_type),alt_name=ternary(alt_name ~= nil, alt_name, alert_source)})) print[[</th><th width=30%>]] print(i18n("alerts_thresholds_config.common_thresholds_local_sources", {source=firstToUpper(entity_type)}))
      print[[</th></tr>]]
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

      for key, check_module in pairsByKeys(descr, asc) do
        local gui_conf = check_module.gui
	local show_input = true

	if check_module.granularity then
	   -- check if the check is performed and thus has to
	   -- be configured at this granularity
	   show_input = false

	   for _, gran in pairs(check_module.granularity) do
	      if gran == tab then
		 show_input = true
		 break
	      end
	   end
  end

  if(check_module.local_only and options.remote_host) then
    show_input = false
  end

        if not gui_conf or not show_input then
          goto next_module
        end

         print("<tr><td><b>".. i18n(gui_conf.i18n_title) .."</b><br>")
         print("<small>"..i18n(gui_conf.i18n_description).."</small>\n")

         for _, prefix in pairs({"", "global_"}) do
            if check_module.gui.input_builder then
              local k = prefix..key
              local value = vals[k]
              print("</td><td>")

              print(check_module.gui.input_builder(check_module.gui or {}, k, value))
            end
         end

         print("</td></tr>\n")
         ::next_module::
      end

      if (entity_type == "host") and (tab == "min") then
         local vals = table.merge(anomalies, global_anomalies)

	 -- Possibly load old config
	 local serialized_config = ntop.getCache(anomaly_config_key)
	 local deserialized_config
	 if isEmptyString(serialized_config) then
	    deserialized_config = {}
	 else
	    deserialized_config = split(serialized_config, "|")
	 end

	 for idx, config in ipairs(anomalies_config) do
	    if isEmptyString(vals[config.key]) then
	       if idx <= #deserialized_config
		  and deserialized_config[idx] ~= "global"
	       and not isEmptyString(deserialized_config[idx]) then
		  vals[config.key] = deserialized_config[idx]
	       end
	    end

	    if isEmptyString(vals["global_"..config.key]) then
	       vals["global_"..config.key] = ntop.getHashCache(global_redis_hash, config.key)
	       if isEmptyString(vals["global_"..config.key]) then
		  vals["global_"..config.key] = config.global_default
	       end
	    end
	 end

	 -- Print the config
	 if not have_nedge then
	    for _, config in ipairs(anomalies_config) do
	       print("<tr><td><b>"..(config.title).."</b><br>\n")
	       print("<small>"..(config.descr)..".</small>")

	       for _, prefix in pairs({"", "global_"}) do
		  local key = prefix..config.key

		  print("</td><td>\n")
		  print('<input type="number" class=\"text-right form-control\" name="'..key..'" style="display:inline; width:7em;" placeholder="" min="'..(config.step)..'" step="'..(config.step)..'" max="100000" value="')
		  print(tostring(vals[key] or ""))
		  print[["></input>]]
	       end

	       print("</td></tr>")
	    end
	 end
      elseif (entity_type == "interface") and (tab == "min") then
	 local drop_perc = ntop.getCache(getInterfacePacketDropPercAlertKey(ifname), _POST["packets_drops_perc"])
	 if isEmptyString(drop_perc) then
	    drop_perc = CONST_DEFAULT_PACKETS_DROP_PERCENTAGE_ALERT
	 end
	 if drop_perc == "0" then
	    drop_perc = ""
	 end

	 print("<tr><td><b>"..i18n("show_alerts.interface_drops_threshold").."</b><br>\n")
	 print("<small>"..i18n("show_alerts.interface_drops_threshold_descr").."</small>")

	 print("</td><td>\n")
	 print('<input type="number" class=\"text-right form-control\" name="packets_drops_perc" style="display:inline; width:7em;" placeholder="" min="0" max="100" value="')
	 print(tostring(drop_perc))
	 print[[" /> %]]
	 print("</td><td></td></tr>")
      end

      print [[
      </tbody> </table>
      <input type="hidden" name="SaveAlerts" value="">

      <button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_configuration")) print[[</button>
      </form>

      <button class="btn btn-default" onclick="$('#deleteGlobalAlertConfig').modal('show');" style="float:right; margin-right:1em;"><i class="fa fa-trash" aria-hidden="true" data-original-title="" title=""></i> ]] print(i18n("show_alerts.delete_config_btn",{conf=firstToUpper(entity_type)})) print[[</button>
      <button class="btn btn-default" onclick="$('#deleteAlertSourceSettings').modal('show');" style="float:right; margin-right:1em;"><i class="fa fa-trash" aria-hidden="true" data-original-title="" title=""></i> ]] print(delete_button_msg) print[[</button>
      ]]

      print("<div style='margin-top:4em;'><b>" .. i18n("alerts_thresholds_config.notes") .. ":</b><ul>")

      print("<li>" .. i18n("alerts_thresholds_config.note_control_threshold_checks_periods") .. "</li>")
      print("<li>" .. i18n("alerts_thresholds_config.note_thresholds_expressed_as_delta") .. "</li>")
      print("<li>" .. i18n("alerts_thresholds_config.note_consecutive_checks") .. "</li>")

      if (entity_type == "host") then
	 print("<li>" .. i18n("alerts_thresholds_config.note_checks_on_active_hosts") .. "</li>")
      end

      print("</ul></div>")

      print[[
      <script>
         function deleteAlertSourceSettings() {
            var params = {};

            params.to_delete = "local";
            params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

            var form = paramsToForm('<form method="post"></form>', params);
            form.appendTo('body').submit();
         }

         function deleteGlobalAlertConfig() {
            var params = {};

            params.to_delete = "global";
            params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

            var form = paramsToForm('<form method="post"></form>', params);
            form.appendTo('body').submit();
         }

         aysHandleForm("form", {
            handle_tabs: true,
         });
      </script>
      ]]
   end
end

-- #################################

function housekeepingAlertsMakeRoom(ifId)
   local prefs = ntop.getPrefs()
   local max_num_alerts_per_entity = prefs.max_num_alerts_per_entity
   local max_num_flow_alerts = prefs.max_num_flow_alerts

   local k = get_make_room_keys(ifId)

   if ntop.getCache(k["entities"]) == "1" then
      ntop.delCache(k["entities"])
      local res = interface.queryAlertsRaw(
					   "SELECT alert_entity, alert_entity_val, count(*) count",
					   "GROUP BY alert_entity, alert_entity_val HAVING COUNT >= "..max_num_alerts_per_entity)

      for _, e in pairs(res) do
	 local to_keep = (max_num_alerts_per_entity * 0.8) -- deletes 20% more alerts than the maximum number
	 to_keep = round(to_keep, 0)
	 -- tprint({e=e, total=e.count, to_keep=to_keep, to_delete=to_delete, to_delete_not_discounted=(e.count - max_num_alerts_per_entity)})
	 local cleanup = interface.queryAlertsRaw(
						  "DELETE",
						  "WHERE alert_entity="..e.alert_entity.." AND alert_entity_val=\""..e.alert_entity_val.."\" "
						     .." AND rowid NOT IN (SELECT rowid FROM alerts WHERE alert_entity="..e.alert_entity.." AND alert_entity_val=\""..e.alert_entity_val.."\" "
						     .." ORDER BY alert_tstamp DESC LIMIT "..to_keep..")", false)
      end
   end

   if ntop.getCache(k["flows"]) == "1" then
      ntop.delCache(k["flows"])
      local res = interface.queryFlowAlertsRaw("SELECT count(*) count", "WHERE 1=1")
      local count = tonumber(res[1].count)
      if count ~= nil and count >= max_num_flow_alerts then
	 local to_keep = (max_num_flow_alerts * 0.8)
	 to_keep = round(to_keep, 0)
	 local cleanup = interface.queryFlowAlertsRaw("DELETE",
						      "WHERE rowid NOT IN (SELECT rowid FROM flows_alerts ORDER BY alert_tstamp DESC LIMIT "..to_keep..")")
	 --tprint({total=count, to_delete=to_delete, cleanup=cleanup})
	 --tprint(cleanup)
	 -- TODO: possibly raise a too many flow alerts
      end
   end

end

-- #################################

local function menuEntriesToDbFormat(entries)
  local res = {}

  for entry_id, entry_val in pairs(entries) do
    res[#res + 1] = {
      id = tostring(entry_id),
      count = tostring(entry_val),
    }
  end

  return(res)
end

-- #################################

function drawAlertTables(num_past_alerts, num_engaged_alerts, num_flow_alerts, get_params, hide_extended_title, alt_nav_tabs, options)
   local alert_items = {}
   local url_params = {}
   local options = options or {}

   print(
      template.gen("modal_confirm_dialog.html", {
		      dialog={
			 id      = "delete_alert_dialog",
			 action  = "deleteAlertById(delete_alert_id)",
			 title   = i18n("show_alerts.delete_alert"),
			 message = i18n("show_alerts.confirm_delete_alert").."?",
			 confirm = i18n("delete"),
		      }
      })
   )

   print(
      template.gen("modal_confirm_dialog.html", {
		      dialog={
			 id      = "myModal",
			 action  = "checkModalDelete()",
			 title   = "",
			 message = i18n("show_alerts.purge_subj_alerts_confirm", {subj = '<span id="modalDeleteContext"></span><span id="modalDeleteAlertsMsg"></span>'}),
			 confirm = i18n("show_alerts.purge_num_alerts", {
					   num_alerts = '<img id="alerts-summary-wait" src="'..ntop.getHttpPrefix()..'/img/loading.gif"/><span id="alerts-summary-body"></span>'
			 }),
		      }
      })
   )

   for k,v in pairs(get_params) do if k ~= "csrf" then url_params[k] = v end end
      if not alt_nav_tabs then
      if not options.engaged_only then
        print("<br>")
      end
	 print[[
<ul class="nav nav-tabs" role="tablist" id="alert-tabs" class="]] print(ternary(options.engaged_only, 'hidden', '')) print[[">
<!-- will be populated later with javascript -->
</ul>
]]
	 nav_tab_id = "alert-tabs"
      else
	 nav_tab_id = alt_nav_tabs
      end

      print[[
<script>

function checkAlertActionsPanel() {
   /* check if this tab is handled by this script */
   if(getCurrentStatus() == "" || getCurrentStatus() == "engaged")
      $("#alertsActionsPanel").css("display", "none");
   else
      $("#alertsActionsPanel").css("display", "");
}

function setActiveHashTab(hash) {
   $('#]] print(nav_tab_id) --[[ see "clicked" below for the other part of this logic ]] print[[ a[href="' + hash + '"]').tab('show');
}

/* Handle the current tab */
$(function() {
 $("ul.nav-tabs > li > a").on("shown.bs.tab", function(e) {
      var id = $(e.target).attr("href").substr(1);
      history.replaceState(null, null, "#"+id);
      updateDeleteLabel(id);
      checkAlertActionsPanel();
   });

  var hash = window.location.hash;
  if (! hash && ]] if(isEmptyString(status) and not isEmptyString(_GET["tab"])) then print("true") else print("false") end print[[)
    hash = "#]] print(_GET["tab"] or "") print[[";

  if (hash)
    setActiveHashTab(hash)

  $(function() { checkAlertActionsPanel(); });
});

function getActiveTabId() {
   return $("#]] print(nav_tab_id) print[[ > li.active > a").attr('href').substr(1);
}

function updateDeleteLabel(tabid) {
   var label = $("#purgeBtnLabel");
   var prefix = "]]
      if not isEmptyString(_GET["entity"]) then print(alertEntityLabel(_GET["entity"], true).." ") end
      print [[";
   var val = "";

   if (tabid == "tab-table-engaged-alerts")
      val = "]] print(i18n("show_alerts.engaged")) print[[ ";
   else if (tabid == "tab-table-alerts-history")
      val = "]] print(i18n("show_alerts.past")) print[[ ";
   else if (tabid == "tab-table-flow-alerts-history")
      val = "]] print(i18n("show_alerts.past_flow")) print[[ ";

   label.html(prefix + val);
}

function getCurrentStatus() {
   var tabid = getActiveTabId();

   if (tabid == "tab-table-engaged-alerts")
      val = "engaged";
   else if (tabid == "tab-table-alerts-history")
      val = "historical";
   else if (tabid == "tab-table-flow-alerts-history")
      val = "historical-flows";
   else
      val = "";

   return val;
}
</script>
]]

      if not alt_nav_tabs then print [[<div class="tab-content">]] end

      local status = ternary(options.engaged_only, "engaged", _GET["status"])
      local status_reset = (status == nil)

      if num_engaged_alerts > 0 then
	 alert_items[#alert_items + 1] = {["label"] = i18n("show_alerts.engaged_alerts"),
	    ["div-id"] = "table-engaged-alerts",  ["status"] = "engaged"}
      elseif status == "engaged" then
	 status = nil; status_reset = 1
      end

      if num_past_alerts > 0 then
	 alert_items[#alert_items +1] = {["label"] = i18n("show_alerts.past_alerts"),
	    ["div-id"] = "table-alerts-history",  ["status"] = "historical"}
      elseif status == "historical" then
	 status = nil; status_reset = 1
      end

      if num_flow_alerts > 0 then
	 alert_items[#alert_items +1] = {["label"] = i18n("show_alerts.flow_alerts"),
	    ["div-id"] = "table-flow-alerts-history",  ["status"] = "historical-flows"}
      elseif status == "historical-flows" then
	 status = nil; status_reset = 1
      end

      for k, t in ipairs(alert_items) do
	 local clicked = "0"
	 if((not alt_nav_tabs) and ((k == 1 and status == nil) or (status ~= nil and status == t["status"]))) then
	    clicked = "1"
	 end
	 print [[
      <div class="tab-pane fade in" id="tab-]] print(t["div-id"]) print[[">
        <div id="]] print(t["div-id"]) print[["></div>
      </div>

      <script type="text/javascript">
         function deleteAlertById(alert_id) {
            var params = {};
            params.id_to_delete = alert_id;
            params.status = getCurrentStatus();
            params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

            var form = paramsToForm('<form method="post"></form>', params);
            form.appendTo('body').submit();
         }

         $("#]] print(nav_tab_id) print[[").append('<li class="]] print(ternary(options.engaged_only, 'hidden', '')) print[["><a href="#tab-]] print(t["div-id"]) print[[" clicked="]] print(clicked) print[[" role="tab" data-toggle="tab">]] print(t["label"]) print[[</a></li>')

         $('a[href="#tab-]] print(t["div-id"]) print[["]').on('shown.bs.tab', function (e) {
         // append the li to the tabs

	 $("#]] print(t["div-id"]) print[[").datatable({
			url: "]] print(ntop.getHttpPrefix()) print [[/lua/get_alerts_table_data.lua?" + $.param(]] print(tableToJsObject(getTabParameters(url_params, t["status"]))) print [[),
               showFilter: true,
	       showPagination: true,
               buttons: [']]

	 local title = t["label"]

	 -- TODO this condition should be removed and page integration support implemented
	 if(options.hide_filters ~= true)  then
	    -- alert_consts.alert_severity_keys and alert_consts.alert_type_keys are defined in lua_utils
	    local alert_severities = {}
	    for s, _ in pairs(alert_consts.alert_severities) do alert_severities[#alert_severities +1 ] = s end
	    local alert_types = {}
	    for s, _ in pairs(alert_consts.alert_types) do alert_types[#alert_types +1 ] = s end
      local type_menu_entries = nil
      local sev_menu_entries = nil

	    local a_type, a_severity = nil, nil
	    if clicked == "1" then
	       if tonumber(_GET["alert_type"]) ~= nil then a_type = alertTypeLabel(_GET["alert_type"], true) end
	       if tonumber(_GET["alert_severity"]) ~= nil then a_severity = alertSeverityLabel(_GET["alert_severity"], true) end
	    end

      if t["status"] == "engaged" then
        local res = interface.getEngagedAlertsCount(tonumber(_GET["entity"]), _GET["entity_val"])

        if(res ~= nil) then
          type_menu_entries = menuEntriesToDbFormat(res.type)
          sev_menu_entries = menuEntriesToDbFormat(res.severities)
        end
      end

	    print(drawDropdown(t["status"], "type", a_type, alert_types, i18n("alerts_dashboard.alert_type"), get_params, type_menu_entries))
	    print(drawDropdown(t["status"], "severity", a_severity, alert_severities, i18n("alerts_dashboard.alert_severity"), get_params, sev_menu_entries))
	 elseif((not isEmptyString(_GET["entity_val"])) and (not hide_extended_title)) then
	    if entity == "host" then
	       title = title .. " - " .. firstToUpper(formatAlertEntity(getInterfaceId(ifname), entity, _GET["entity_val"], nil))
	    end
	 end

   if options.engaged_only then
     title = ""
   end

	 print[['],
/*
               buttons: ['<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Severity<span class="caret"></span></button><ul class="dropdown-menu" role="menu"><li>test severity</li></ul></div><div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Type<span class="caret"></span></button><ul class="dropdown-menu" role="menu"><li>test type</li></ul></div>'],
*/
]]

	 if(_GET["currentPage"] ~= nil and _GET["status"] == t["status"]) then
	    print("currentPage: ".._GET["currentPage"]..",\n")
	 end
	 if(_GET["perPage"] ~= nil and _GET["status"] == t["status"]) then
	    print("perPage: ".._GET["perPage"]..",\n")
	 end
	 print ('sort: [ ["' .. getDefaultTableSort("alerts") ..'","' .. getDefaultTableSortOrder("alerts").. '"] ],\n')
	 print [[
	        title: "]] print(title) print[[",
      columns: [
	 {
	    title: "]]print(i18n("show_alerts.alert_datetime"))print[[",
	    field: "column_date",
            sortable: true,
	    css: {
	       textAlign: 'center',
          whiteSpace: 'nowrap',
	    }
	 },

	 {
	    title: "]]print(i18n("show_alerts.alert_duration"))print[[",
	    field: "column_duration",
            sortable: true,
	    css: {
	       textAlign: 'center',
          whiteSpace: 'nowrap',
	    }
	 },

	 {
	    title: "]]print(i18n("show_alerts.alert_count"))print[[",
	    field: "column_count",
            hidden: ]] print(ternary(t["status"] ~= "historical-flows", "true", "false")) print[[,
            sortable: true,
	    css: {
	       textAlign: 'center'
	    }
	 },

	 {
	    title: "]]print(i18n("show_alerts.alert_severity"))print[[",
	    field: "column_severity",
            sortable: true,
	    css: {
	       textAlign: 'center'
	    }
	 },

	 {
	    title: "]]print(i18n("show_alerts.alert_type"))print[[",
	    field: "column_type",
            sortable: true,
	    css: {
	       textAlign: 'center',
          whiteSpace: 'nowrap',
	    }
	 },

	 {
	    title: "]]print(i18n("drilldown"))print[[",
	    field: "column_chart",
            sortable: false,
	    hidden: ]] print(ternary(not hasNindexSupport() or ntop.isPro(), "false", "true")) print[[,
	    css: {
	       textAlign: 'center'
	    }
	 },

	 {
	    title: "]]print(i18n("show_alerts.alert_description"))print[[",
	    field: "column_msg",
	    css: {
	       textAlign: 'left',
	    }
	 },

    {
      field: "column_key",
      hidden: true
    },

    {
	    title: "]]print(i18n("show_alerts.alert_actions")) print[[",
       ]]
	 if t["status"] == "engaged" then
	    print("hidden: true,")
	 end
	 print[[
	    css: {
	       textAlign: 'center',
	    }
	 }
      ], tableCallback: function() {
            datatableForEachRow("#]] print(t["div-id"]) print[[", function(row_id) {
               var alert_key = $("td:nth(7)", this).html().split("|");
               var alert_id = alert_key[0];
               var historical_url = alert_key[1];

               if (typeof(historical_url) === "string")
                  datatableAddLinkButtonCallback.bind(this)(9, historical_url, "]] print(i18n("show_alerts.explorer")) print[[");
               datatableAddDeleteButtonCallback.bind(this)(9, "delete_alert_id ='" + alert_id + "'; $('#delete_alert_dialog').modal('show');", "]] print(i18n('delete')) print[[");

               $("form", this).submit(function() {
                  // add "status" parameter to the form
                  var get_params = paramsExtend(]] print(tableToJsObject(getTabParameters(url_params, nil))) print[[, {status:getCurrentStatus()});
                  $(this).attr("action", "?" + $.param(get_params));

                  return true;
               });
         });
      }
   });
   });
   ]]
	 if (clicked == "1") then
	    print[[
         // must wait for modalDeleteAlertsStatus to be created
         $(function() {
            var status_reset = ]] print(tostring(status_reset)) --[[ this is necessary because of status parameter inconsistency after tab switch ]] print[[;
            var tabid;

            if ((status_reset) || (getCurrentStatus() == "")) {
               tabid = "]] print("tab-"..t["div-id"]) print[[";
               history.replaceState(null, null, "#"+tabid);
            } else {
               tabid = getActiveTabId();
            }

            updateDeleteLabel(tabid);
         });
      ]]
	 end
	 print[[
   </script>
	      ]]

      end

      local zoom_vals = {
	 { i18n("show_alerts.5_min"),  5*60*1, i18n("show_alerts.older_5_minutes_ago") },
	 { i18n("show_alerts.30_min"), 30*60*1, i18n("show_alerts.older_30_minutes_ago") },
	 { i18n("show_alerts.1_hour"),  60*60*1, i18n("show_alerts.older_1_hour_ago") },
	 { i18n("show_alerts.1_day"),  60*60*24, i18n("show_alerts.older_1_day_ago") },
	 { i18n("show_alerts.1_week"),  60*60*24*7, i18n("show_alerts.older_1_week_ago") },
	 { i18n("show_alerts.1_month"),  60*60*24*31, i18n("show_alerts.older_1_month_ago") },
	 { i18n("show_alerts.6_months"),  60*60*24*31*6, i18n("show_alerts.older_6_months_ago") },
	 { i18n("show_alerts.1_year"),  60*60*24*366 , i18n("show_alerts.older_1_year_ago") }
      }

      if (num_past_alerts > 0 or num_flow_alerts > 0 or num_engaged_alerts > 0) then
	 -- trigger the click on the right tab to force table load
	 print[[
<script type="text/javascript">
$("[clicked=1]").trigger("click");
</script>
]]

	 if not alt_nav_tabs then print [[</div> <!-- closes tab-content -->]] end
	 local has_fixed_period = ((not isEmptyString(_GET["epoch_begin"])) or (not isEmptyString(_GET["epoch_end"])))

	 print('<div id="alertsActionsPanel">')
	 print('<br>' ..  i18n("show_alerts.alerts_to_purge") .. ': ')
	 print[[<select id="deleteZoomSelector" class="form-control" style="display:]] if has_fixed_period then print("none") else print("inline") end print[[; width:14em; margin:0 1em;">]]
	 local all_msg = ""

	 if not has_fixed_period then
	    print('<optgroup label="' .. i18n("show_alerts.older_than") .. '">')
	    for k,v in ipairs(zoom_vals) do
	       print('<option data-older="'..(os.time() - zoom_vals[k][2])..'" data-msg="'.." "..zoom_vals[k][3].. '">'..zoom_vals[k][1]..'</option>\n')
	    end
	    print('</optgroup>')
	 else
	    all_msg = " " .. i18n("show_alerts.in_the_selected_time_frame")
	 end

	 print('<option selected="selected" data-older="0" data-msg="') print(all_msg) print('">' .. i18n("all") .. '</option>\n')


	 print[[</select>
       <form id="modalDeleteForm" class="form-inline" style="display:none;" method="post" onsubmit="return checkModalDelete();">
         <input type="hidden" id="modalDeleteAlertsOlderThan" value="-1" />
         <input id="csrf" name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />
      </form>
    ]]

	    -- we need to dynamically modify parameters at js-time because we switch tab
	 local delete_params = getTabParameters(url_params, nil)
	 delete_params.epoch_end = -1

	 print[[<button id="buttonOpenDeleteModal" data-toggle="modal" data-target="#myModal" class="btn btn-default"><i type="submit" class="fa fa-trash-o"></i> <span id="purgeBtnMessage">]]
	 print(i18n("show_alerts.purge_subj_alerts", {subj='<span id="purgeBtnLabel"></span>'}))
	 print[[</span></button>
   </div> <!-- closes alertsActionsPanel -->

<script>

paramsToForm('#modalDeleteForm', ]] print(tableToJsObject(delete_params)) print[[);

function getTabSpecificParams() {
   var tab_specific = {status:getCurrentStatus()};
   var period_end = $('#modalDeleteAlertsOlderThan').val();
   if (parseInt(period_end) > 0)
      tab_specific.epoch_end = period_end;

   if (tab_specific.status == "]] print(_GET["status"]) print[[") {
      tab_specific.alert_severity = ]] if tonumber(_GET["alert_severity"]) ~= nil then print(_GET["alert_severity"]) else print('""') end print[[;
      tab_specific.alert_type = ]] if tonumber(_GET["alert_type"]) ~= nil then print(_GET["alert_type"]) else print('""') end print[[;
   }

   // merge the general parameters to the tab specific ones
   return paramsExtend(]] print(tableToJsObject(getTabParameters(url_params, nil))) print[[, tab_specific);
}

function checkModalDelete() {
   var get_params = getTabSpecificParams();
   var post_params = {};
   post_params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
   post_params.id_to_delete = "__all__";

   // this actually performs the request
   var form = paramsToForm('<form method="post"></form>', post_params);
   form.attr("action", "?" + $.param(get_params));
   form.appendTo('body').submit();
   return false;
}

var cur_alert_num_req = null;

/* This acts before shown.bs.modal event, avoiding visual fields substitution glitch */
$('#buttonOpenDeleteModal').on('click', function() {
   var lb = $("#purgeBtnLabel");
   var zoomsel = $("#deleteZoomSelector").find(":selected");
   $("#myModal h3").html($("#purgeBtnMessage").html());

   $(".modal-body #modalDeleteAlertsMsg").html(zoomsel.data('msg') + ']]
	 if tonumber(_GET["alert_severity"]) ~= nil then
	    print(' with severity "'..alertSeverityLabel(_GET["alert_severity"], true)..'" ')
	 elseif tonumber(_GET["alert_type"]) ~= nil then
	    print(' with type "'..alertTypeLabel(_GET["alert_type"], true)..'" ')
	 end
	 print[[');
   if (lb.length == 1)
      $(".modal-body #modalDeleteContext").html(" " + lb.html());

   $('#modalDeleteAlertsOlderThan').val(zoomsel.data('older'));

   cur_alert_num_req = $.ajax({
      type: 'GET',
      ]] print("url: '"..ntop.getHttpPrefix().."/lua/get_num_alerts.lua'") print[[,
       data: $.extend(getTabSpecificParams(), {ifid: ]] print(_GET["ifid"] or "null") print[[}),
       complete: function() {
         $("#alerts-summary-wait").hide();
       }, error: function() {
         $("#alerts-summary-body").html("?");
       }, success: function(count){
         $("#alerts-summary-body").html(count);
         if (count == 0)
            $('#myModal button[type="submit"]').attr("disabled", "disabled");
       }
    });
});

$('#myModal').on('hidden.bs.modal', function () {
   if(cur_alert_num_req) {
      cur_alert_num_req.abort();
      cur_alert_num_req = null;
   }

   $("#alerts-summary-wait").show();
   $("#alerts-summary-body").html("");
   $('#myModal button[type="submit"]').removeAttr("disabled");
})
</script>]]
      end

end

-- #################################

function drawAlerts(options)
   local num_engaged_alerts = getNumAlerts("engaged", getTabParameters(_GET, "engaged"))
   local num_past_alerts = getNumAlerts("historical", getTabParameters(_GET, "historical"))
   local num_flow_alerts = 0

   if _GET["entity"] == nil then
     num_flow_alerts = getNumAlerts("historical-flows", getTabParameters(_GET, "historical-flows"))
   end

   checkDeleteStoredAlerts()

   return drawAlertTables(num_past_alerts, num_engaged_alerts, num_flow_alerts, _GET, true, nil, options)
end

-- #################################

local function getEntityConfiguredAlertThresholds(ifname, granularity, entity_type, local_hosts)
   local thresholds_key = get_alerts_hash_name(granularity, ifname, entity_type)
   local thresholds_config = {}
   local res = {}
   
   -- Handle the global configuration
   local global_conf_keys = ntop.getKeysCache(getGlobalAlertsConfigurationHash(granularity, entity_type, "*", local_hosts)) or {}

   for alert_key in pairs(global_conf_keys) do
      local thresholds_str = ntop.getHashCache(alert_key, global_redis_thresholds_key)

      if not isEmptyString(thresholds_str) then
	 -- extract only the last part of the key
	 local k = string.sub(alert_key, string.find(alert_key, "%.[^%.]*$")+1)
	 thresholds_config[k] = thresholds_str
      end
   end

   for entity_val, thresholds_str in pairs(table.merge(thresholds_config, ntop.getHashAllCache(thresholds_key) or {})) do
      local thresholds = split(thresholds_str, ",")
      res[entity_val] = {}

      for _, threshold in pairs(thresholds) do
	 local parts = string.split(threshold, ";")
	 if #parts == 3 then
	    local alert_key = granularity .. "_" .. parts[1] -- the alert key is the concatenation of the granularity and the metric
	    res[entity_val][parts[1]] = {metric=parts[1], operator=parts[2], edge=parts[3], key=alert_key}
	 end
      end
   end

   return res
end

-- #################################

-- Get all the configured threasholds for the specified interface
-- NOTE: an additional "interfaces" key is added if there are globally
-- configured threasholds (threasholds active for all the interfaces)
function getInterfaceConfiguredAlertThresholds(ifname, granularity)
  return(getEntityConfiguredAlertThresholds(ifname, granularity, "interface"))
end

-- #################################

-- Get all the configured threasholds for local hosts on the specified interface
-- NOTE: an additional "local_hosts" key is added if there are globally
-- configured threasholds (threasholds active for all the hosts of the interface)
function getLocalHostsConfiguredAlertThresholds(ifname, granularity, local_hosts)
  return(getEntityConfiguredAlertThresholds(ifname, granularity, "host", true))
end

-- #################################

-- Get all the configured threasholds for remote hosts on the specified interface
-- NOTE: an additional "local_hosts" key is added if there are globally
-- configured threasholds (threasholds active for all the hosts of the interface)
function getRemoteHostsConfiguredAlertThresholds(ifname, granularity, local_hosts)
  return(getEntityConfiguredAlertThresholds(ifname, granularity, "host", false))
end

-- #################################

-- Get all the configured threasholds for networks on the specified interface
-- NOTE: an additional "local_networks" key is added if there are globally
-- configured threasholds (threasholds active for all the hosts of the interface)
function getNetworksConfiguredAlertThresholds(ifname, granularity)
  return(getEntityConfiguredAlertThresholds(ifname, granularity, "network"))
end

-- #################################

function check_networks_alerts(granularity)
   if(granularity == "min") then
      ntop.checkNetworksAlertsMin()
   elseif(granularity == "5mins") then
      ntop.checkNetworksAlerts5Min()
   elseif(granularity == "hour") then
      ntop.checkNetworksAlertsHour()
   elseif(granularity == "day") then
      ntop.checkNetworksAlertsDay()
   else
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Unknown granularity " .. granularity)
   end
end

-- #################################

function check_interface_alerts(granularity)
   if(granularity == "min") then
      interface.checkAlertsMin()
   elseif(granularity == "5mins") then
      interface.checkAlerts5Min()
   elseif(granularity == "hour") then
      interface.checkAlertsHour()
   elseif(granularity == "day") then
      interface.checkAlertsDay()
   else
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Unknown granularity " .. granularity)
   end
end

-- #################################

function check_hosts_alerts(granularity)
   if(granularity == "min") then
      ntop.checkHostsAlertsMin()
   elseif(granularity == "5mins") then
      ntop.checkHostsAlerts5Min()
   elseif(granularity == "hour") then
      ntop.checkHostsAlertsHour()
   elseif(granularity == "day") then
      ntop.checkHostsAlertsDay()
   else
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Unknown granularity " .. granularity)
   end
end

-- #################################

function newAlertsWorkingStatus(ifstats, granularity)
   local res = {
      granularity = granularity,
      engine = alertEngine(granularity),
      ifid = ifstats.id,
      now = os.time(),
      interval = granularity2sec(granularity),
   }
   return res
end

-- #################################

-- A redis set with mac addresses as keys
local function getActiveDevicesHashKey(ifid)
   return "ntopng.cache.active_devices.ifid_" .. ifid
end

function deleteActiveDevicesKey(ifid)
   ntop.delCache(getActiveDevicesHashKey(ifid))
end

-- #################################

local function triggerAlertFromNotification(notification)
  local alert = alerts:newAlert({
     entity = alertEntityRaw(notification.entity_type),
     type = alertTypeRaw(notification.type),
     severity = alertSeverityRaw(notification.severity),
  })

  alert:trigger(notification.entity_value, notification.message, notification.when)
end

-- #################################

local function getMacUrl(mac)
   return ntop.getHttpPrefix() .. "/lua/mac_details.lua?host=" .. mac
end

local function getHostUrl(host, vlan_id)
   return ntop.getHttpPrefix() .. "/lua/host_details.lua?" .. hostinfo2url({host = host, vlan = vlan_id})
end

local function getSavedDeviceNameKey(mac)
   return "ntopng.cache.devnames." .. mac
end

local function setSavedDeviceName(mac, name)
   local key = getSavedDeviceNameKey(mac)
   ntop.setCache(key, name)
end

local function getSavedDeviceName(mac)
   local key = getSavedDeviceNameKey(mac)
   return ntop.getCache(key)
end

-- Global function
function check_mac_ip_association_alerts()
   local alert = alerts:newAlert({
      entity = "mac",
      type = "mac_ip_association_change",
      severity = "warning",
   })

   while(true) do
      local message = ntop.lpopCache("ntopng.alert_mac_ip_queue")
      local elems

      if((message == nil) or (message == "")) then
	 break
      end

      elems = json.decode(message)

      if elems ~= nil then
         --io.write(elems.ip.." ==> "..message.."[".. elems.ifname .."]\n")
         interface.select(elems.ifname)
         alert:trigger(elems.new_mac, i18n("alert_messages.mac_ip_association_change",
                  {device=name, ip=elems.ip,
                  old_mac=elems.old_mac, old_mac_url=getMacUrl(elems.old_mac),
                  new_mac=elems.new_mac, new_mac_url=getMacUrl(elems.new_mac)}))
      end
   end   
end

-- Global function
function check_broadcast_domain_too_large_alerts()
   local alert = alerts:newAlert({
      entity = "interface",
      type = "broadcast_domain_too_large",
      severity = "warning",
   })

   while(true) do
      local message = ntop.lpopCache("ntopng.alert_bcast_domain_too_large")
      local elems

      if((message == nil) or (message == "")) then
	 break
      end

      elems = json.decode(message)

      if elems ~= nil then
	 local entity_value = "iface_"..elems.ifid

	 --io.write(elems.ip.." ==> "..message.."[".. elems.ifname .."]\n")
	 interface.select(elems.ifname)
	 alert:trigger(entity_value, i18n("alert_messages.broadcast_domain_too_large",
				   {src_mac = elems.src_mac,
				    src_mac_url = getMacUrl(elems.src_mac),
				    dst_mac = elems.dst_mac,
				    dst_mac_url = getMacUrl(elems.dst_mac),
				    spa = elems.spa,
				    spa_url = getHostUrl(elems.spa, elems.vlan_id),
				    tpa = elems.tpa,
				    tpa_url = getHostUrl(elems.tpa, elems.vlan_id)}))
      end
   end
end

-- Global function
function check_nfq_flushed_queue_alerts()
   local alert = alerts:newAlert({
      entity = "interface",
      type = "nfq_flushed",
      severity = "info",
   })

   while(true) do
      local message = ntop.lpopCache("ntopng.alert_nfq_flushed_queue")
      local elems

      if((message == nil) or (message == "")) then
	 break
      end

      elems = json.decode(message)

      if elems ~= nil then
	 local entity_value = "iface_"..elems.ifid

	 -- tprint(elems)
         -- io.write(elems.ip.." ==> "..message.."[".. elems.ifname .."]\n")

         interface.select(elems.ifname)
         alert:trigger(entity_value, i18n("alert_messages.nfq_flushed",{
                name = elems.ifname, pct = elems.pct,
                tot = elems.tot, dropped = elems.dropped,
                url = ntop.getHttpPrefix().."/lua/if_stats.lua?ifid="..elems.ifid
          }))
      end
   end   
end

-- Global function
function check_host_remote_to_remote_alerts()
   local alert = alerts:newAlert({
      entity = "host",
      type = "remote_to_remote",
      severity = "warning",
   })

   while(true) do
      local message = ntop.lpopCache(host_remote_to_remote_alerts_queue)
      local elems

      if((message == nil) or (message == "")) then
	 break
      end

      elems = json.decode(message)

      if elems ~= nil then
	 local host_info = {host = elems.ip.ip, vlan = elems.vlan_id or 0}
	 local entity_value = hostinfo2hostkey(host_info, nil, true --[[ show vlan --]])
	 local msg = i18n("alert_messages.host_remote_to_remote",
			  {url = ntop.getHttpPrefix() .. "/lua/host_details.lua?host=" .. entity_value,
			   flow_alerts_url = ntop.getHttpPrefix() .."/lua/show_alerts.lua?status=historical-flows&alert_type="..alertType("remote_to_remote"),
			   mac_url = ntop.getHttpPrefix() .."/lua/mac_details.lua?host="..elems.mac_address,
			   ip = getResolvedAddress(host_info),
			   mac = get_symbolic_mac(elems.mac_address, true)})

         interface.select(getInterfaceName(elems.ifid))

         alert:trigger(entity_value, msg)
      end
   end   
end

-- Global function
function check_outside_dhcp_range_alerts()
   local alert = alerts:newAlert({
      entity = "host",
      type = "ip_outsite_dhcp_range",
      severity = "warning",
   })

   while(true) do
      local message = ntop.lpopCache("ntopng.alert_outside_dhcp_range_queue")
      local elems

      if((message == nil) or (message == "")) then
	 break
      end

      elems = json.decode(message)

      if elems ~= nil then
	 local host_info = {host = elems.client_ip, vlan = elems.vlan_id or 0}
	 local router_info = {host = elems.router_ip, vlan = elems.vlan_id or 0}
	 local entity_value = hostinfo2hostkey(host_info, nil, true --[[ show vlan --]])

	 local msg = i18n("alert_messages.ip_outsite_dhcp_range", {
	    client_url = ntop.getHttpPrefix() .. "/lua/mac_details.lua?host=" .. elems.client_mac,
	    client_mac = get_symbolic_mac(elems.client_mac, true),
	    client_ip = hostinfo2hostkey(host_info),
	    client_ip_url = ntop.getHttpPrefix() .. "/lua/host_details.lua?host=" .. hostinfo2hostkey(host_info),
	    dhcp_url = ntop.getHttpPrefix() .. "/lua/if_stats.lua?page=dhcp",
	    sender_url = ntop.getHttpPrefix() .. "/lua/mac_details.lua?host=" .. elems.sender_mac,
	    sender_mac = get_symbolic_mac(elems.sender_mac, true),
	    router_url = ntop.getHttpPrefix() .. "/lua/host_details.lua?host=" .. hostinfo2hostkey(router_info),
	    router_ip = getResolvedAddress(router_info),
	 })

         interface.select(getInterfaceName(elems.ifid))
         alert:trigger(entity_value, msg)
      end
   end
end

-- Global function
function check_periodic_activities_alerts()
  local alert = alerts:newAlert({
     entity = "periodic_activity",
     type = "slow_periodic_activity",
     severity = "warning",
  })

  while(true) do
    local message = ntop.lpopCache("ntopng.periodic_activity_queue")
    local elems

    if((message == nil) or (message == "")) then
      break
    end

    elems = json.decode(message)

    if elems ~= nil then
      local duration
      local max_duration

      if(elems.max_duration_ms > 3000) then
        duration = string.format("%u s", math.floor(elems.duration_ms/1000))
        max_duration = string.format("%u s", math.floor(elems.max_duration_ms/1000))
      else
        duration = string.format("%u ms", math.floor(elems.duration_ms))
        max_duration = string.format("%u ms", math.floor(elems.max_duration_ms))
      end

      local msg = i18n("alert_messages.slow_periodic_activity", {
        script = elems.path,
        duration = duration,
        max_duration = max_duration,
      })

      interface.select(elems.ifname)
      alert:trigger(elems.path, msg)
    end
  end
end

-- Global function
function check_login_alerts()
   while(true) do
      local message = ntop.lpopCache(alert_login_queue)
      local elems
      
      if((message == nil) or (message == "")) then
	 break
      end

      if(verbose) then print(message.."\n") end
      
      local decoded = json.decode(message)

      if(decoded == nil) then
	 if(verbose) then io.write("JSON Decoding error: "..message.."\n") end
      else
        interface.select(getSystemInterfaceId())

        local alert = alerts:newAlert({
          entity = "user",
          type = "alert_user_activity",
          severity = ternary(decoded.status == "authorized", "info", "warning"),
          subtype = decoded.authorized,
        })

        local user = decoded.user
        decoded.user = nil -- no need to serialize this
        alert:trigger(user, decoded)
      end
   end
end

-- Global function
function check_process_alerts()
   while(true) do
      local message = ntop.lpopCache(alert_process_queue)
      local elems
      
      if((message == nil) or (message == "")) then
	 break
      end

      if(verbose) then print(message.."\n") end
      
      local decoded = json.decode(message)

      if(decoded == nil) then
	 if(verbose) then io.write("JSON Decoding error: "..message.."\n") end
      else
        interface.select(getSystemInterfaceId())
        triggerAlertFromNotification(decoded)
      end
   end
end

local function check_macs_alerts(ifid, granularity)
   if granularity ~= "min" then
      return
   end

   local active_devices_set = getActiveDevicesHashKey(ifid)
   local seen_devices_hash = getFirstSeenDevicesHashKey(ifid)
   local seen_devices = ntop.getHashAllCache(seen_devices_hash) or {}
   local prev_active_devices = swapKeysValues(ntop.getMembersCache(active_devices_set) or {})
   local alert_new_devices_enabled = ntop.getPref("ntopng.prefs.alerts.device_first_seen_alert") == "1"
   local alert_device_connection_enabled = ntop.getPref("ntopng.prefs.alerts.device_connection_alert") == "1"
   local new_active_devices = {}
   local new_device_alert = alerts:newAlert({
      entity = "mac",
      type = "new_device",
      severity = "warning",
    })
   local device_connection_alert = alerts:newAlert({
      entity = "mac",
      type = "device_connection",
      severity = "info",
    })
   local device_disconnection_alert = alerts:newAlert({
      entity = "mac",
      type = "device_disconnection",
      severity = "info",
    })

   callback_utils.foreachDevice(getInterfaceName(ifid), nil, function(devicename, devicestats, devicebase)
				   -- note: location is always lan when capturing from a local interface
				   if (not devicestats.special_mac) and (devicestats.location == "lan") then
				      local mac = devicestats.mac

				      if not seen_devices[mac] then
					 -- First time we see a device
					 ntop.setHashCache(seen_devices_hash, mac, tostring(os.time()))

					 if alert_new_devices_enabled then
					    local name = getDeviceName(mac)
					    setSavedDeviceName(mac, name)
              
              new_device_alert:trigger(mac, i18n("alert_messages.a_new_device_has_connected", {device=name, url=getMacUrl(mac)}))
					 end
				      end

				      if not prev_active_devices[mac] then
					 -- Device connection
					 ntop.setMembersCache(active_devices_set, mac)

					 if alert_device_connection_enabled then
					    local name = getDeviceName(mac)
					    setSavedDeviceName(mac, name)
              device_connection_alert:trigger(mac, i18n("alert_messages.device_has_connected", {device=name, url=getMacUrl(mac)}))
					 end
				      else
					 new_active_devices[mac] = 1
				      end
				   end
   end)

   for mac in pairs(prev_active_devices) do
      if not new_active_devices[mac] then
         -- Device disconnection
         local name = getSavedDeviceName(mac)
         ntop.delMembersCache(active_devices_set, mac)

         if alert_device_connection_enabled then
            device_disconnection_alert:trigger(mac, i18n("alert_messages.device_has_disconnected", {device=name, url=getMacUrl(mac)}))
         end
      end
   end
end

-- #################################

-- A redis set with host pools as keys
local function getActivePoolsHashKey(ifid)
   return "ntopng.cache.active_pools.ifid_" .. ifid
end

function deleteActivePoolsKey(ifid)
   ntop.delCache(getActivePoolsHashKey(ifid))
end

-- #################################

-- Redis hashe with key=pool and value=list of quota_exceed_items, separated by |
local function getPoolsQuotaExceededItemsKey(ifid)
   return "ntopng.cache.quota_exceeded_pools.ifid_" .. ifid
end

function deletePoolsQuotaExceededItemsKey(ifid)
   ntop.delCache(getPoolsQuotaExceededItemsKey(ifid))
end

-- #################################

local function getHostPoolUrl(pool_id)
   return ntop.getHttpPrefix() .. "/lua/hosts_stats.lua?pool=" .. pool_id
end

function check_host_pools_alerts(ifid, granularity)
   if granularity ~= "min" then
      return
   end

   local active_pools_set = getActivePoolsHashKey(ifid)
   local prev_active_pools = swapKeysValues(ntop.getMembersCache(active_pools_set)) or {}
   local alert_pool_connection_enabled = ntop.getPref("ntopng.prefs.alerts.pool_connection_alert") == "1"
   local alerts_on_quota_exceeded = ntop.isPro() and ntop.getPref("ntopng.prefs.alerts.quota_exceeded_alert") == "1"
   local pools_stats = nil
   local quota_exceeded_pools_key = getPoolsQuotaExceededItemsKey(ifid)
   local quota_exceeded_pools_values = ntop.getHashAllCache(quota_exceeded_pools_key) or {}
   local quota_exceeded_pools = {}
   local now_active_pools = {}

   local quota_exceeded_alert_time = alerts:newAlert({
      entity = "host_pool",
      type = "quota_exceeded",
      severity = "info",
      subtype = "time_quota",
   })
   local quota_exceeded_alert_traffic = alerts:newAlert({
      entity = "host_pool",
      type = "quota_exceeded",
      severity = "info",
      subtype = "traffic_quota",
   })
   local pool_connection_alert = alerts:newAlert({
      entity = "host_pool",
      type = "host_pool_connection",
      severity = "info",
   })
   local pool_disconnection_alert = alerts:newAlert({
      entity = "host_pool",
      type = "host_pool_disconnection",
      severity = "info",
   })

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

   if ntop.isPro() then
      pools_stats = interface.getHostPoolsStats()
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
         quota_exceeded_alert_traffic:trigger(tostring(pool), i18n("alert_messages.subject_quota_exceeded", {
                  pool = host_pools_utils.getPoolName(ifid, pool),
                  url = getHostPoolUrl(pool),
                  subject = i18n("alert_messages.proto_bytes_quotas", {proto=proto}),
                  quota = bytesToSize(info.bytes_quota),
                  value = bytesToSize(info.bytes_value)}))
		  end

		  if info.time_exceeded and not prev_exceeded[2] then
         quota_exceeded_alert_time:trigger(tostring(pool), i18n("alert_messages.subject_quota_exceeded", {
                pool = host_pools_utils.getPoolName(ifid, pool),
                url = getHostPoolUrl(pool),
                subject = i18n("alert_messages.proto_time_quotas", {proto=proto}),
                quota = secondsToTime(info.time_quota),
                value = secondsToTime(info.time_value)}))
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
	 if (pool ~= host_pools_utils.DEFAULT_POOL_ID) and (info.num_hosts > 0) then
	    now_active_pools[pool] = 1

	    if not prev_active_pools[pool] then
	       -- Pool connection
	       ntop.setMembersCache(active_pools_set, pool)

	       if alert_pool_connection_enabled then
            pool_connection_alert:trigger(tostring(pool),
              i18n("alert_messages.host_pool_has_connected",
                {pool=host_pools_utils.getPoolName(ifid, pool), url=getHostPoolUrl(pool)}))
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
            pool_disconnection_alert:trigger(tostring(pool),
              i18n("alert_messages.host_pool_has_disconnected",
                {pool=host_pools_utils.getPoolName(ifid, pool),
                url=getHostPoolUrl(pool)}))
         end
      end
   end
end

-- #################################

function scanAlerts(granularity, ifstats)
   if not mustScanAlerts(ifstats) then return end

   local ifname = ifstats["name"]
   local ifid = getInterfaceId(ifname)

   if(verbose) then print("[minute.lua] Scanning ".. granularity .." alerts for interface " .. ifname.."\n") end

   check_interface_alerts(granularity)
   check_networks_alerts(granularity)
   check_hosts_alerts(granularity)
   check_macs_alerts(ifid, granularity)
   check_host_pools_alerts(ifid, granularity)

   if ntop.getInfo()["test_mode"] then
      package.path = dirs.installdir .. "/scripts/lua/modules/test/?.lua;" .. package.path
      local test_utils = require "test_utils"
      if test_utils then
	 test_utils.check_alerts(ifid, granularity)
      end
   end
end

-- #################################

local function deleteCachePattern(pattern)
   local keys = ntop.getKeysCache(pattern)

   for key in pairs(keys or {}) do
      ntop.delCache(key)
   end
end

function disableAlertsGeneration()
   if not haveAdminPrivileges() then
      return
   end

   -- Ensure we do not conflict with others
   ntop.setPref("ntopng.prefs.disable_alerts_generation", "1")
   ntop.reloadPreferences()
   if(verbose) then io.write("[Alerts] Disable done\n") end
end

-- #################################

function flushAlertsData()
   if not haveAdminPrivileges() then
      return
   end

   local selected_interface = ifname
   local ifnames = interface.getIfNames()
   local force_query = true
   local generation_toggle_backup = ntop.getPref("ntopng.prefs.disable_alerts_generation")

   if(verbose) then io.write("[Alerts] Temporary disabling alerts generation...\n") end
   ntop.setAlertsTemporaryDisabled(true);
   ntop.msleep(3000)

   callback_utils.foreachInterface(ifnames, nil, function(ifname, ifstats)
				      if(verbose) then io.write("[Alerts] Processing interface "..ifname.."...\n") end

				      -- Clear hosts status
				      interface.refreshHostsAlertsConfiguration(true --[[ with counters ]])

				      if(verbose) then io.write("[Alerts] Flushing SQLite configuration...\n") end
				      performAlertsQuery("DELETE", "engaged", {}, force_query)
				      performAlertsQuery("DELETE", "historical", {}, force_query)
				      performAlertsQuery("DELETE", "historical-flows", {}, force_query)
   end)

   if(verbose) then io.write("[Alerts] Flushing Redis configuration...\n") end
   deleteCachePattern("ntopng.prefs.*alert*")
   deleteCachePattern("ntopng.alerts.*")
   deleteCachePattern(getGlobalAlertsConfigurationHash("*", "*", "*", true))
   deleteCachePattern(getGlobalAlertsConfigurationHash("*", "*", "*", false))
   ntop.delCache(get_alerts_suppressed_hash_name("*"))
   for _, key in pairs(get_make_room_keys("*")) do deleteCachePattern(key) end

   if(verbose) then io.write("[Alerts] Enabling alerts generation...\n") end
   ntop.setAlertsTemporaryDisabled(false);

   callback_utils.foreachInterface(ifnames, nil, function(_ifname, ifstats)
				      -- Reload hosts status
				      interface.refreshHostsAlertsConfiguration(true --[[ with counters ]])
   end)

   ntop.setPref("ntopng.prefs.disable_alerts_generation", generation_toggle_backup)
   refreshAlerts(interface.getId())

   if(verbose) then io.write("[Alerts] Flush done\n") end
   interface.select(selected_interface)
end

-- #################################

function alertNotificationActionToLabel(action)
   local label = ""

   if action == "engage" then
      label = "[Engaged]"
   elseif action == "release" then
      label = "[Released]"
   end

   return label
end

-- #################################

--
-- Generic alerts extenral report
--
-- Guidelines:
--
--  - modules are enabled with the getAlertNotificationModuleEnableKey key
--  - module severity is defined with the getAlertNotificationModuleSeverityKey key
--  - A [module] name must have a corresponding modules/[module]_utils.lua script
--

function alertNotificationToObject(alert_json)
   local notification = json.decode(alert_json)

   if not notification then
      return nil
   end

   if(notification.type ~= nil) then
      notification.type = alertTypeRaw(notification.type)
      notification.entity_type = alertEntityRaw(notification.entity_type)
      notification.severity = alertSeverityRaw(notification.severity)
   end

   if(notification.flow ~= nil) then
      notification.message = formatRawFlow(notification.flow, notification.message, true --[[ skip add links ]])
   else
      local alert = alerts.alertNotificationToRecord(notification)
      local description = alertTypeDescription(alert.alert_type)
      local msg = alert.alert_json

      if(string.sub(msg, 1, 1) == "{") then
        msg = json.decode(msg)
      end

      if(type(description) == "string") then
        -- localization string
        notification.message = i18n(description, msg)
      elseif(type(description) == "function") then
        notification.message = description(notification.ifid, alert, msg)
      end
   end

   return notification
end

function notification_timestamp_asc(a, b)
   return (a.tstamp < b.tstamp)
end

function notification_timestamp_rev(a, b)
   return (a.tstamp > b.tstamp)
end

function formatAlertNotification(notif, options)
   local defaults = {
      nohtml = false,
      show_severity = true,
   }
   options = table.merge(defaults, options)

   local msg = "[" .. formatEpoch(notif.tstamp or 0) .. "]"
   msg = msg .. ternary(options.show_severity == false, "", "[" .. alertSeverityLabel(alertSeverity(notif.severity), options.nohtml) .. "]") ..
      "[" .. alertTypeLabel(alertType(notif.type), options.nohtml) .."]"

   -- entity can be hidden for example when one is OK with just the message
   if options.show_entity then
      msg = msg.."["..alertEntityLabel(alertEntity(notif.entity_type)).."]"

      if notif.entity_type ~= "flow" then
	 local ev = notif.entity_value
	 if notif.entity_type == "host" then
	    -- suppresses @0 when the vlan is zero
	    ev = hostinfo2hostkey(hostkey2hostinfo(notif.entity_value))
	 end

	 msg = msg.."["..ev.."]"
      end
   end

   -- add the label, that is, engaged or released
   msg = msg .. alertNotificationActionToLabel(notif.action).. " "

   if options.nohtml then
      msg = msg .. noHtml(notif.message)
   else
      msg = msg .. notif.message
   end

   return msg
end

-- ##############################################

local function alertToNotification(ifid, action, alert)
   return({
      ifid = ifid,
      entity_type = tonumber(alert.alert_entity),
      entity_value = alert.alert_entity_val,
      type = tonumber(alert.alert_type),
      severity = tonumber(alert.alert_severity),
      message = alert.alert_json,
      tstamp = tonumber(alert.alert_tstamp_end),
      action = action,
   })
end

-- ##############################################

-- NOTE: this is executed in a system VM, with no interfaces references
function processAlertNotifications(now, periodic_frequency, force_export)
   alerts.processPendingAlertEvents(now + periodic_frequency)

   -- Get new alerts
   while(true) do
      local json_message = ntop.lpopCache("ntopng.alerts.notifications_queue")

      if((json_message == nil) or (json_message == "")) then
         break
      end

      if(verbose) then
         io.write("Alert Notification: " .. json_message .. "\n")
      end

      local message = json.decode(json_message)

      alert_endpoints.dispatchNotification(message, json_message)
   end

   alert_endpoints.processNotifications(now, periodic_frequency)
end

-- ##############################################

local function notify_ntopng_status(started)
   local info = ntop.getInfo()
   local severity = alertSeverity("info")
   local msg
   local msg_details = string.format("%s v.%s (%s) [pid: %s][options: %s]", info.product, info.version, info.OS, info.pid, info.command_line)
   local anomalous = false
   
   if(started) then
      -- let's check if we are restarting from an anomalous termination
      -- e.g., from a crash
      if not recovery_utils.check_clean_shutdown() then
	 -- anomalous termination
	 msg = string.format("%s %s", i18n("alert_messages.ntopng_anomalous_termination", {url="https://www.ntop.org/support/need-help-2/need-help/"}), msg_details)
	 severity = alertSeverity("error")
	 anomalous = true
      else
	 -- normal termination
	 msg = string.format("%s %s", i18n("alert_messages.ntopng_start"), msg_details)
      end
   else
      msg = string.format("%s %s", i18n("alert_messages.ntopng_stop"), msg_details)
   end

   obj = {
      entity_type = alertEntity("host"), entity_value="ntopng",
      type = alertType("process_notification"),
      severity = severity,
      message = msg,
      when = os.time() }

   if anomalous then
      telemetry_utils.notify(obj)
   end
   
   ntop.rpushCache(alert_process_queue, json.encode(obj))
end

function notify_snmp_device_interface_status_change(snmp_host, snmp_interface)
   local msg = i18n("alerts_dashboard.snmp_port_changed_operational_status",
		    {device = snmp_host,
		     port = snmp_interface["name"] or snmp_interface["index"],
		     url = ntop.getHttpPrefix()..string.format("/lua/pro/enterprise/snmp_device_details.lua?host=%s", snmp_host),
		     port_url = ntop.getHttpPrefix()..string.format("/lua/pro/enterprise/snmp_interface_details.lua?host=%s&snmp_port_idx=%d", snmp_host, snmp_interface["index"]),
		     new_op = snmp_ifstatus(snmp_interface["status"])})

   local entity_value = string.format("%s_ifidx%d", snmp_host, snmp_interface["index"])
   local obj = {entity_type = alertEntity("snmp_device"),
		entity_value = entity_value,
		type = alertType("port_status_change"),
		severity = alertSeverity("info"),
		message = msg, when = os.time()
	       }

   ntop.rpushCache(alert_process_queue, json.encode(obj))
end

function notify_snmp_device_interface_duplexstatus_change(snmp_host, snmp_interface)
   local msg = i18n("alerts_dashboard.snmp_port_changed_duplex_status",
		    {device = snmp_host,
		     port = snmp_interface["name"] or snmp_interface["index"],
		     url = ntop.getHttpPrefix()..string.format("/lua/pro/enterprise/snmp_device_details.lua?host=%s", snmp_host),
		     port_url = ntop.getHttpPrefix()..string.format("/lua/pro/enterprise/snmp_interface_details.lua?host=%s&snmp_port_idx=%d", snmp_host, snmp_interface["index"]),
		     new_op = snmp_duplexstatus(snmp_interface["duplexstatus"])})

   local entity_value = string.format("%s_ifidx%d", snmp_host, snmp_interface["index"])
   local obj = {entity_type = alertEntity("snmp_device"),
		entity_value = entity_value,
		type = alertType("port_duplexstatus_change"),
		severity = alertSeverity("info"),
		message = msg, when = os.time()
	       }

   ntop.rpushCache(alert_process_queue, json.encode(obj))
end

function notify_snmp_device_interface_errors(snmp_host, snmp_interface)
   local msg = i18n("alerts_dashboard.snmp_port_errors_increased",
		    {device = snmp_host,
		     port = snmp_interface["name"] or snmp_interface["index"],
		     url = ntop.getHttpPrefix()..string.format("/lua/pro/enterprise/snmp_device_details.lua?host=%s", snmp_host),
		     port_url = ntop.getHttpPrefix()..string.format("/lua/pro/enterprise/snmp_interface_details.lua?host=%s&snmp_port_idx=%d", snmp_host, snmp_interface["index"])})

   local entity_value = string.format("%s_ifidx%d", snmp_host, snmp_interface["index"])
   local obj = {entity_type = alertEntity("snmp_device"),
		entity_value = entity_value,
		type = alertType("port_errors"),
		severity = alertSeverity("info"),
		message = msg, when = os.time()
	       }

   ntop.rpushCache(alert_process_queue, json.encode(obj))
end

function notify_snmp_device_interface_load_threshold_exceeded(snmp_host, snmp_interface, port_load, in_direction)
   local msg = i18n("alerts_dashboard.snmp_port_load_threshold_exceeded_message",
		    {device = snmp_host,
		     port = snmp_interface["name"] or snmp_interface["index"],
		     url = ntop.getHttpPrefix()..string.format("/lua/pro/enterprise/snmp_device_details.lua?host=%s", snmp_host),
		     port_url = ntop.getHttpPrefix()..string.format("/lua/pro/enterprise/snmp_interface_details.lua?host=%s&snmp_port_idx=%d", snmp_host, snmp_interface["index"]),
                     port_load = port_load,
                     direction = ternary(in_direction, "RX", "TX") })

   local entity_value = string.format("%s_ifidx%d", snmp_host, snmp_interface["index"])
   local obj = {entity_type = alertEntity("snmp_device"),
		entity_value = entity_value,
		type = alertType("port_load_threshold_exceeded"),
		severity = alertSeverity("info"),
		message = msg, when = os.time()
	       }

   ntop.rpushCache(alert_process_queue, json.encode(obj))
end

function notify_ntopng_start()
   notify_ntopng_status(true)
end

function notify_ntopng_stop()
   notify_ntopng_status(false)
end

-- DEBUG: uncomment this to test
--~ scanAlerts("min", "wlan0")
