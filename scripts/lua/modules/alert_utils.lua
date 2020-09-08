--
-- (C) 2014-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/pools/?.lua;" .. package.path

-- This file contains the description of all functions
-- used to trigger host alerts
local verbose = ntop.getCache("ntopng.prefs.alerts.debug") == "1"
local callback_utils = require "callback_utils"
local template = require "template_utils"
local json = require("dkjson")
local host_pools = require "host_pools"
local recovery_utils = require "recovery_utils"
local alert_consts = require "alert_consts"
local format_utils = require "format_utils"
local telemetry_utils = require "telemetry_utils"
local tracker = require "tracker"
local alerts_api = require "alerts_api"
local flow_consts = require "flow_consts"
local icmp_utils = require "icmp_utils"
local user_scripts = require "user_scripts"

local shaper_utils = nil

if(ntop.isnEdge()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   shaper_utils = require("shaper_utils")
end

-- ##############################################

local alert_utils = {}

-- ##############################################

if ntop.isEnterpriseM() then
   local dirs = ntop.getDirs()
   package.path = dirs.installdir .. "/pro/scripts/lua/enterprise/modules/?.lua;" .. package.path
   -- add enterprise utils to this module
   alert_utils = require "enterprise_alert_utils"
end

-- ##############################################

local function alertTypeDescription(v)
  local alert_key = alert_consts.alertTypeRaw(v)

  if(alert_key) then
    return(alert_consts.alert_types[alert_key].i18n_description)
  end

  return nil
end

-- ##############################################

local function get_make_room_keys(ifId)
   return {flows="ntopng.cache.alerts.ifid_"..ifId..".make_room_flow_alerts",
	   entities="ntopng.cache.alerts.ifid_"..ifId..".make_room_closed_alerts"}
end

-- #################################

-- This function maps the SQLite table names to the conventional table
-- names used in this script
local function luaTableName(sqlite_table_name)
  --~ ALERTS_MANAGER_FLOWS_TABLE_NAME      "flows_alerts"
  if(sqlite_table_name == "flows_alerts") then
    return("historical-flows")
  else
    return("historical")
  end
end

-- #################################

local function performAlertsQuery(statement, what, opts, force_query, group_by)
   local wargs = {"1=1"}
   local oargs = {}

   if(group_by ~= nil) then
     group_by = " GROUP BY " .. group_by
   else
     group_by = ""
   end

   if tonumber(opts.row_id) ~= nil then
      wargs[#wargs+1] = 'AND rowid = '..(opts.row_id)
   end

   if (not isEmptyString(opts.entity)) and (not isEmptyString(opts.entity_val)) then
      if(what == "historical-flows") then
         if(tonumber(opts.entity) ~= alert_consts.alertEntity("host")) then
           return({})
         else
           -- need to handle differently for flows table
           local info = hostkey2hostinfo(opts.entity_val)
           wargs[#wargs+1] = 'AND (cli_addr="'..(info.host)..'" OR srv_addr="'..(info.host)..'")'
           wargs[#wargs+1] = 'AND vlan_id='..(info.vlan)
         end
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
      elseif opts.sortColumn == "column_key" then
         order_by = "rowid"
      elseif opts.sortColumn == "column_severity" then
         order_by = "alert_severity"
      elseif opts.sortColumn == "column_type" then
         order_by = "alert_type"
      elseif opts.sortColumn == "column_count" and what ~= "engaged" then
         order_by = "alert_counter"
      elseif opts.sortColumn == "column_score" and what ~= "engaged" then
         order_by = "score"
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
   group_by = table.concat(oargs, " ") .. group_by
   local res

   -- Uncomment to debug the queries
   --tprint(statement.." (from "..what..") WHERE "..query .. " ".. group_by)

   if((what == "engaged") or (what == "historical")) then
      res = interface.queryAlertsRaw(statement, query, group_by, force_query)
   elseif what == "historical-flows" then
      res = interface.queryFlowAlertsRaw(statement, query, group_by, force_query)
   else
      error("Invalid alert subject: "..what)
   end

   return res
end

-- #################################

local function getNumEngagedAlerts(options)
  local entity_type_filter = tonumber(options.entity)
  local entity_value_filter = options.entity_val

  local res = interface.getEngagedAlertsCount(entity_type_filter, entity_value_filter, options.entity_excludes)

  if(res ~= nil) then
    return(res.num_alerts)
  end

  return(0)
end

-- #################################

-- Remove pagination options from the options
local function getUnpagedAlertOptions(options)
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

function alert_utils.getNumAlerts(what, options)
   local num = 0

   if(what == "engaged") then
     num = getNumEngagedAlerts(options)
   else
     local opts = getUnpagedAlertOptions(options or {})
     local res = performAlertsQuery("SELECT COUNT(*) AS count", what, opts)
     if((res ~= nil) and (#res == 1) and (res[1].count ~= nil)) then num = tonumber(res[1].count) end
   end

   return num
end

-- #################################

-- Faster than of getNumAlerts
function alert_utils.hasAlerts(what, options)
  if(what == "engaged") then
    return(getNumEngagedAlerts(options) > 0)
  end

  local opts = getUnpagedAlertOptions(options or {})
  -- limit 1
  opts.perPage = 1
  opts.currentPage = 1
  local res = performAlertsQuery("SELECT rowid", what, opts)

  if((res ~= nil) and (#res == 1)) then
    return(true)
  else
    return(false)
  end
end

-- #################################

local function engagedAlertsQuery(params)
  local type_filter = tonumber(params.alert_type)
  local severity_filter = tonumber(params.alert_severity)
  local entity_type_filter = tonumber(params.entity)
  local entity_value_filter = params.entity_val

  local perPage = tonumber(params.perPage or 10)
  local sortColumn = params.sortColumn or "column_"
  local sortOrder = params.sortOrder or "desc"
  local sOrder = ternary(sortOrder == "desc", rev_insensitive, asc_insensitive)
  local currentPage = tonumber(params.currentPage or 1)
  local totalRows = 0

  --~ tprint(string.format("type=%s sev=%s entity=%s val=%s", type_filter, severity_filter, entity_type_filter, entity_value_filter))
  local alerts = interface.getEngagedAlerts(entity_type_filter, entity_value_filter, type_filter, severity_filter, params.entity_excludes)
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

  return res, totalRows
end

-- #################################

function alert_utils.getAlerts(what, options, with_counters)
   local alerts, num_alerts

   if what == "engaged" then
      alerts, num_alerts = engagedAlertsQuery(options)

      if not with_counters then
        num_alerts = nil
      end
   else
      alerts = performAlertsQuery("SELECT rowid, *", what, options)

      if with_counters then
        num_alerts = alert_utils.getNumAlerts(what, options)
      end
   end

   return alerts, num_alerts
end

-- #################################

function alert_utils.getNumAlertsPerHour(what, epoch_begin, epoch_end, alert_type, alert_severity)
   local opts = {
      epoch_begin = epoch_begin,
      epoch_end = epoch_end,
      alert_type = alert_type,
      alert_severity = alert_severity,
   }

   return performAlertsQuery("select (alert_tstamp - alert_tstamp % 3600) as hour, count(*) count", what, opts, nil, "hour")
end

-- #################################

function alert_utils.getNumAlertsPerType(what, epoch_begin, epoch_end)
   local opts = {
     epoch_begin = epoch_begin,
     epoch_end = epoch_end,
   }

   return performAlertsQuery("select alert_type id, count(*) count", what, opts, nil, "alert_type" --[[ group by ]])
end

-- #################################

function alert_utils.getNumAlertsPerSeverity(what, epoch_begin, epoch_end)
   local opts = {
     epoch_begin = epoch_begin,
     epoch_end = epoch_end,
   }

   return performAlertsQuery("select alert_severity severity, count(*) count", what, opts, nil, "alert_severity" --[[ group by ]])
end

-- #################################

local function refreshAlerts(ifid)
   ntop.delCache(string.format("ntopng.cache.alerts.ifid_%d.has_alerts", ifid))
   ntop.delCache("ntopng.cache.update_alerts_stats_time")
end

-- #################################

local function deleteAlerts(what, options)
   local opts = getUnpagedAlertOptions(options or {})
   performAlertsQuery("DELETE", what, opts)
end

-- #################################

-- this function returns an object with parameters specific for one tab
function alert_utils.getTabParameters(_get, what)
   local opts = {}
   for k,v in pairs(_get) do opts[k] = v end

   -- these options are contextual to the current tab (status)
   if _get.status ~= what then
      opts.alert_type = nil
      opts.alert_severity = nil
   end
   if not isEmptyString(what) then opts.status = what end
   opts.ifid = interface.getId()
   return opts
end

-- #################################

local function checkDisableAlerts()
  local ifid = interface.getId()

  if(_POST["action"] == "disable_alert") then
    local entity = _POST["entity"]
    local entity_val = _POST["entity_val"]
    local alert_type = _POST["alert_type"]
    local disabled_alerts = alerts_api.getEntityAlertsDisabledBitmap(ifid, entity, entity_val)

    disabled_alerts = ntop.bitmapSet(disabled_alerts, tonumber(alert_type))
    alerts_api.setEntityAlertsDisabledBitmap(ifid, entity, entity_val, disabled_alerts)
  elseif(_POST["action"] == "enable_alert") then
    local entity = _POST["entity"]
    local entity_val = _POST["entity_val"]
    local alert_type = _POST["alert_type"]
    local disabled_alerts = alerts_api.getEntityAlertsDisabledBitmap(ifid, entity, entity_val)

    disabled_alerts = ntop.bitmapClear(disabled_alerts, tonumber(alert_type))
    alerts_api.setEntityAlertsDisabledBitmap(ifid, entity, entity_val, disabled_alerts)
  end
end

-- #################################

function alert_utils.checkDeleteStoredAlerts()
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

      local has_alerts = alert_utils.hasAlerts(_GET["status"], _GET)
      if(not has_alerts) then
         -- reset the filter to avoid hiding the tab
         _GET["alert_severity"] = nil
         _GET["alert_type"] = nil
      end
   end

   checkDisableAlerts()

   if(_POST["action"] == "release_alert") then
      local entity_info = {
         alert_entity = alert_consts.alert_entities[alert_consts.alertEntityRaw(_POST["entity"])],
         alert_entity_val = _POST["entity_val"],
      }

      local type_info = {
         alert_type = alert_consts.alert_types[alert_consts.alertTypeRaw(_POST["alert_type"])],
         alert_severity = alert_consts.alert_severities[alert_consts.alertSeverityRaw(_POST["alert_severity"])],
         alert_subtype = _POST["alert_subtype"],
         alert_granularity = alert_consts.alerts_granularities[alert_consts.sec2granularity(_POST["alert_granularity"])],
      }

      alerts_api.release(entity_info, type_info)
      interface.refreshAlerts();
   end
end

-- #################################

-- Return more information for the flow alert description
local function getFlowStatusInfo(record, status_info)
   local res = ""

   local l7proto_name = interface.getnDPIProtoName(tonumber(record["l7_proto"]) or 0)

   if l7proto_name == "ICMP" then -- is ICMPv4
      -- TODO: old format - remove when the all the flow alers will be generated in lua
      local type_code = {type = status_info["icmp.icmp_type"], code = status_info["icmp.icmp_code"]}

      if table.empty(type_code) and status_info["icmp"] then
	 -- This is the new format created when setting the alert from lua
	 type_code = {type = status_info["icmp"]["type"], code = status_info["icmp"]["code"]}
      end

      if status_info["icmp.unreach.src_ip"] then -- TODO: old format to be removed
	 res = string.format("[%s]", i18n("icmp_page.icmp_port_unreachable_extra", {unreach_host=status_info["icmp.unreach.dst_ip"], unreach_port=status_info["icmp.unreach.dst_port"], unreach_protocol = l4_proto_to_string(status_info["icmp.unreach.protocol"])}))
      elseif status_info["icmp"] and status_info["icmp"]["unreach"] then -- New format
	 res = string.format("[%s]", i18n("icmp_page.icmp_port_unreachable_extra", {unreach_host=status_info["icmp"]["unreach"]["dst_ip"], unreach_port=status_info["icmp"]["unreach"]["dst_port"], unreach_protocol = l4_proto_to_string(status_info["icmp"]["unreach"]["protocol"])}))
      else
	 res = string.format("[%s]", icmp_utils.get_icmp_label(4 --[[ ipv4 --]], type_code["type"], type_code["code"]))
      end
   end

   return string.format(" %s", res)
end

-- #################################

local function formatRawFlow(record, flow_json, skip_add_links)
   require "flow_utils"
   local time_bounds
   local add_links = (not skip_add_links)

   if interfaceHasNindexSupport() and not skip_add_links then
      -- only add links if nindex is present
      add_links = true
      time_bounds = {getAlertTimeBounds(record)}
   end

   local decoded

   if(type(flow_json) == "table") then
     decoded = flow_json
   else
     decoded = json.decode(flow_json) or {}
   end

   if((type(decoded["status_info"]) == "string") and
         (string.sub(decoded["status_info"], 1, 1) == "{")) then
      -- status_info may contain a JSON string or a plain message
      decoded["status_info"] = json.decode(decoded["status_info"])
   end

   local status_info = decoded.status_info

   -- active flow lookup
   if not interface.isView() and status_info and status_info["ntopng.key"] and status_info["hash_entry_id"] and record["alert_tstamp"] then
      -- attempt a lookup on the active flows
      local active_flow = interface.findFlowByKeyAndHashId(status_info["ntopng.key"], status_info["hash_entry_id"])

      if active_flow and active_flow["seen.first"] < tonumber(record["alert_tstamp"]) then
	 return string.format("%s [%s: <A HREF='%s/lua/flow_details.lua?flow_key=%u&flow_hash_id=%u'><span class='badge badge-info'>Info</span></A> %s]",
			      flow_consts.getStatusDescription(tonumber(record["flow_status"]), status_info),
			      i18n("flow"), ntop.getHttpPrefix(), active_flow["ntopng.key"], active_flow["hash_entry_id"],
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

   flow = "["..i18n("flow")..": "..(getFlowLabel(flow, false, add_links, time_bounds, {page = "alerts"}) or "").."] "
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
         msg = msg..flow_consts.getStatusDescription(tonumber(record["flow_status"]), status_info).." "
      end

      if not isEmptyString(flow) then
         msg = msg..flow.." "
      end

      if not isEmptyString(decoded["info"]) then
         local lb = ""
         if (flow_consts.getStatusType(record["flow_status"]) == "status_blacklisted")
                  and (not flow["srv.blacklisted"]) and (not flow["cli.blacklisted"]) then
            lb = " <i class='fas fa-ban' aria-hidden='true' title='Blacklisted'></i>"
         end
	 local info

	 if string.len(decoded["info"]) > 60 then
	    info = "<abbr title=\"".. decoded["info"] .."\">".. shortenString(decoded["info"], 60)
	 else
	    info = decoded["info"]
	 end
         msg = msg.."["..i18n("info")..": " .. info ..lb.."] "
      end

      flow = msg
   end

   if status_info then
      flow = flow..getFlowStatusInfo(record, status_info)
   end

   return flow
end

-- #################################

local function getMenuEntries(status, selection_name, get_params)
   local actual_entries = {}

   -- table.clone needed to modify some parameters while keeping the original unchanged
   local params = table.clone(get_params)

   -- Remove previous filters
   params.alert_severity = nil
   params.alert_type = nil

   if selection_name == "severity" then
      actual_entries = performAlertsQuery("select alert_severity id, count(*) count", status, params, nil, "alert_severity" --[[ group by ]])
    elseif selection_name == "type" then
      actual_entries = performAlertsQuery("select alert_type id, count(*) count", status, params, nil, "alert_type" --[[ group by ]])
   end

   return(actual_entries)
end

-- #################################

local function dropdownUrlParams(get_params)
  local buttons = ""

  for param, val in pairs(get_params) do
    -- NOTE: exclude the ifid parameter to avoid interface selection issues with system interface alerts
    if((param ~= "alert_severity") and (param ~= "alert_type") and (param ~= "status") and (param ~= "ifid")) then
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
      id_to_label = alert_consts.alertSeverityLabel
   elseif selection_name == "type" then
      id_to_label = alert_consts.alertTypeLabel
   end

   actual_entries = actual_entries or getMenuEntries(status, selection_name, get_params)

   local buttons = '<div class="btn-group">'

   button_label = button_label or firstToUpper(selection_name)
   if active_entry ~= nil and active_entry ~= "" then
      button_label = firstToUpper(active_entry)..'<span class="fas fa-filter"></span>'
   end

   buttons = buttons..'<button class="btn btn-link dropdown-toggle" data-toggle="dropdown">'..button_label
   buttons = buttons..'<span class="caret"></span></button>'

   buttons = buttons..'<ul class="dropdown-menu dropdown-menu-right" role="menu">'

   local class_active = ""

   if active_entry == nil then class_active = 'active' end
   buttons = buttons..'<li><a class="dropdown-item '..class_active..'" href="?status='..status..dropdownUrlParams(get_params)..'">All</a></i>'

   for _, entry in pairs(actual_entries) do
      local id = tonumber(entry["id"])
      local count = entry["count"]

      if(id >= 0) then
        local label = id_to_label(id, true)

        class_active = ""
        if label == active_entry then class_active = 'active' end
        -- buttons = buttons..'<li'..class_active..'><a class="dropdown-item" href="'..ntop.getHttpPrefix()..'/lua/show_alerts.lua?status='..status
        buttons = buttons..'<li><a class="dropdown-item '..class_active..'" href="?status='..status
        buttons = buttons..dropdownUrlParams(get_params)
        buttons = buttons..'&alert_'..selection_name..'='..id..'">'
        buttons = buttons..firstToUpper(label)..' ('..count..')</a></li>'
      end
   end

   buttons = buttons..'</ul></div>'

   return buttons
end

-- #################################

local function printConfigTab(entity_type, entity_value, page_name, page_params, alt_name, options)
   local trigger_alerts = true
   local ifid = interface.getId()
   local cur_bitmap

   if(entity_type == "host") then
      cur_bitmap = alerts_api.getHostDisabledStatusBitmap(ifid, entity_value)
   end

   local entity_type_id = alert_consts.alertEntity(entity_type)

   if _SERVER["REQUEST_METHOD"] == "POST" then
      if _POST["trigger_alerts"] ~= "1" then
         trigger_alerts = false
      else
         trigger_alerts = true
      end

      alerts_api.setSuppressedAlerts(ifid, entity_type_id, entity_value, (not trigger_alerts))

      if(entity_type == "host") then
         local bitmap = 0

         if not isEmptyString(_POST["disabled_status"]) then
           local status_selection = split(_POST["disabled_status"], ",") or { _POST["disabled_status"] }

           for _, status in pairs(status_selection) do
             bitmap = ntop.bitmapSet(bitmap, tonumber(status))
           end
         end

         if(bitmap ~= cur_bitmap) then
           alerts_api.setHostDisabledStatusBitmap(ifid, entity_value, bitmap)
           cur_bitmap = bitmap
         end
      end
   else
      trigger_alerts = (not alerts_api.hasSuppressedAlerts(ifid, entity_type_id, entity_value))
   end

   if not (trigger_alerts == false) then
      trigger_alerts = true
   end

  local enable_label = options.enable_label or i18n("show_alerts.trigger_alert_descr")

  print[[
   <br>
   <form id="alerts-config" class="form-inline" method="post">
   <input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />
   <table class="table table-bordered table-striped">]]
  print[[<tr>
         <th width="25%">]] print(i18n("device_protocols.alert")) print[[</th>
         <td>]]

   print(template.gen("on_off_switch.html", {
	 id = "trigger_alerts",
	 checked = trigger_alerts,
	 icon = [[<i class="fas fa-exclamation-triangle fa-lg"></i> ]] .. enable_label
   }))
   
   print[[
         </td>
      </tr>]]

   if(entity_type == "host") then
      print[[<tr>
         <td width="30%">
           <b>]] print(i18n("host_details.status_ignore")) print[[</b> <i class="fas fa-info-circle" title="]] print(i18n("host_details.disabled_flow_status_help")) print[["></i>
         </td>
         <td>
           <input id="status_trigger_alert" name="disabled_status" type="hidden" />
           <select onchange="convertMultiSelect()" id="status_trigger_alert_select" multiple class="form-control" style="width:40em; height:10em; display:inline;">]]

      for _, status in pairsByKeys(flow_consts.status_types, asc) do
        local status_key = status.status_key

        if(status_key == flow_consts.status_types.status_normal.status_key) then
          goto continue
        end

        print[[<option value="]] print(string.format("%d", status_key))
        if ntop.bitmapIsSet(cur_bitmap, tonumber(status_key)) then
          print[[" selected="selected]]
        end
        print[[">]]
        print(i18n(status.i18n_title))
        print[[</option>]]

        ::continue::
      end

      print[[</select><div style="margin-top:1em;"><i>]] print(i18n("host_details.multiple_selection")) print[[</i></div>
         <button type="button" class="btn btn-secondary" style="margin-top:1em;" onclick="resetMultiSelect()">]] print(i18n("reset")) print[[</button>
         </td>
      </tr>]]
   end
   print[[</table>
   <button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_configuration")) print[[</button>
   </form>
   <br><br>
   <script>
    function convertMultiSelect() {
      var values = [];

      $("#status_trigger_alert_select option:selected").each(function(idx, item) {
        values.push($(item).val());
      });

      $("#status_trigger_alert").val(values.join(","));
      $("#status_trigger_alert").trigger("change");
    }

    function resetMultiSelect() {
       $("#status_trigger_alert_select option:selected").each(function(idx, item) {
         item.selected = "";
       });

       convertMultiSelect();
    }

    /* Run after page load */
    $(convertMultiSelect);

    aysHandleForm("#alerts-config");
   </script>]]
end

-- #################################

function alert_utils.printAlertTables(entity_type, alert_source, page_name, page_params, alt_name, show_entity, options)
   local has_engaged_alerts, has_past_alerts, has_flow_alerts = false,false,false
   local has_disabled_alerts = alerts_api.hasEntitiesWithAlertsDisabled(interface.getId())
   local tab = _GET["tab"]
   local have_nedge = ntop.isnEdge()
   options = options or {}

   local anomaly_config_key = nil
   local flow_rate_alert_thresh, syn_alert_thresh

   if entity_type == "host" then
      anomaly_config_key = 'ntopng.prefs.'..(options.host_ip)..':'..tostring(options.host_vlan)..'.alerts_config'
   end

   print('<ul class="nav nav-tabs">')

   local function printTab(tab, content, sel_tab)
      if(tab == sel_tab) then print("\t<li class='nav-item active show'>") else print("\t<li class='nav-item'>") end
      print("<a class='nav-link' href=\""..ntop.getHttpPrefix().."/lua/"..page_name.."?page=alerts&tab="..tab)
      for param, value in pairs(page_params) do
         print("&"..param.."="..value)
      end
      print("\">"..content.."</a></li>\n")
   end

   if(show_entity) then
      -- these fields will be used to perform queries
      _GET["entity"] = alert_consts.alertEntity(show_entity)
      _GET["entity_val"] = alert_source
   end

   if(show_entity) then
      -- possibly process pending delete arguments
      alert_utils.checkDeleteStoredAlerts()

      -- possibly add a tab if there are alerts configured for the host
      has_engaged_alerts = alert_utils.hasAlerts("engaged", alert_utils.getTabParameters(_GET, "engaged"))
      has_past_alerts = alert_utils.hasAlerts("historical", alert_utils.getTabParameters(_GET, "historical"))
      has_flow_alerts = alert_utils.hasAlerts("historical-flows", alert_utils.getTabParameters(_GET, "historical-flows"))

      if(has_engaged_alerts or has_past_alerts or has_flow_alerts) then
         if(has_engaged_alerts) then
           tab = tab or "alert_list"
           printTab("alert_list", i18n("show_alerts.engaged_alerts"), tab)
         end
         if(has_past_alerts) then
           tab = tab or "past_alert_list"
           printTab("past_alert_list", i18n("show_alerts.past_alerts"), tab)
         end
         if(has_flow_alerts) then
           tab = tab or "flow_alert_list"
           printTab("flow_alert_list", i18n("show_alerts.flow_alerts"), tab)
         end
      else
         -- if there are no alerts, we show the alert settings
         if(tab=="alert_list") then tab = nil end
      end
   end

   -- Default tab
   if(tab == nil) then tab = "config" end
   local is_alert_list_tab = ((tab == "alert_list") or (tab == "past_alert_list") or (tab == "flow_alert_list"))

   printTab("config", '<i class="fas fa-cog" aria-hidden="true"></i> ' .. i18n("traffic_recording.settings"), tab)

   print('</ul>')

   if((show_entity) and is_alert_list_tab) then
      alert_utils.drawAlertTables(has_past_alerts, has_engaged_alerts, has_flow_alerts, has_disabled_alerts, _GET, true, nil, { dont_nest_alerts = true })
   elseif(tab == "config") then
      printConfigTab(entity_type, alert_source, page_name, page_params, alt_name, options)
   end
end

-- #################################

function alert_utils.optimizeAlerts()
   if(not areAlertsEnabled()) then
      return
   end

   interface.optimizeAlerts()
end

-- #################################

function alert_utils.housekeepingAlertsMakeRoom(ifId)
   local prefs = ntop.getPrefs()
   local max_num_alerts_per_entity = prefs.max_num_alerts_per_entity
   local max_num_flow_alerts = prefs.max_num_flow_alerts

   local k = get_make_room_keys(ifId)

   if ntop.getCache(k["entities"]) == "1" then
      ntop.delCache(k["entities"])
      local res = interface.queryAlertsRaw(
					   "SELECT alert_entity, alert_entity_val, count(*) count", "",
					   "GROUP BY alert_entity, alert_entity_val HAVING COUNT >= "..max_num_alerts_per_entity) or {}

      for _, e in pairs(res) do
	 local to_keep = (max_num_alerts_per_entity * 0.8) -- deletes 20% more alerts than the maximum number
	 to_keep = round(to_keep, 0)
	 -- tprint({e=e, total=e.count, to_keep=to_keep, to_delete=to_delete, to_delete_not_discounted=(e.count - max_num_alerts_per_entity)})
	 local cleanup = interface.queryAlertsRaw(
						  "DELETE",
						  "alert_entity="..e.alert_entity.." AND alert_entity_val=\""..e.alert_entity_val.."\" "
						     .." AND rowid NOT IN (SELECT rowid FROM alerts WHERE alert_entity="..e.alert_entity.." AND alert_entity_val=\""..e.alert_entity_val.."\" "
						     ,"ORDER BY alert_tstamp DESC LIMIT "..to_keep..")", false)
      end
   end

   if ntop.getCache(k["flows"]) == "1" then
      ntop.delCache(k["flows"])
      local res = interface.queryFlowAlertsRaw("SELECT count(*) count") or {}
      local count = tonumber(res[1].count)
      if count ~= nil and count >= max_num_flow_alerts then
	 local to_keep = (max_num_flow_alerts * 0.8)
	 to_keep = round(to_keep, 0)
	 local cleanup = interface.queryFlowAlertsRaw("DELETE",
						      "rowid NOT IN (SELECT rowid FROM flows_alerts ORDER BY alert_tstamp DESC LIMIT "..to_keep..")")
	 -- tprint({total=count, to_delete=to_delete, cleanup=cleanup})
	 -- tprint(cleanup)
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

local function printDisabledAlerts(ifid)
  print[[
  <script>
  $("#table-disabled-alerts").datatable({
    url: "]] print(ntop.getHttpPrefix()) print [[/lua/get_disabled_alerts.lua?ifid=]] print(string.format("%d", ifid)) print[[",
    showPagination: true,
    title: "]] print(i18n("show_alerts.disabled_alerts")) print[[",
      columns: [
	 {
	    title: "]]print(i18n("show_alerts.alarmable"))print[[",
	    field: "column_entity_formatted",
            sortable: true,
	    css: {
	       textAlign: 'center',
          whiteSpace: 'nowrap',
          width: '35%',
	    }
	 },{
	    title: "]]print(i18n("show_alerts.alert_type"))print[[",
	    field: "column_type",
            sortable: true,
	    css: {
	       textAlign: 'center',
          whiteSpace: 'nowrap',
	    }
	 },{
	    title: "]]print(i18n("show_alerts.alert_actions")) print[[",
	    css: {
	       textAlign: 'center',
	    }
	 }], tableCallback: function() {
        datatableForEachRow("#table-disabled-alerts", function(row_id) {
           datatableAddActionButtonCallback.bind(this)(3, "prepareToggleAlertsDialog('table-disabled-alerts',"+ row_id +"); $('#enable_alert_type').modal('show');", "]] print(i18n("show_alerts.enable_alerts")) print[[");
        })
       }
  });
  </script>]]
end

-- #################################

function alert_utils.drawAlertTables(has_past_alerts, has_engaged_alerts, has_flow_alerts, has_disabled_alerts, get_params, hide_extended_title, alt_nav_tabs, options)
   local alert_items = {}
   local url_params = {}
   local options = options or {}
   local ifid = interface.getId()

   print(
      template.gen("modal_confirm_dialog.html", {
		      dialog={
			 id      = "delete_alert_dialog",
			 action  = "deleteAlertById(delete_alert_id)",
			 title   = i18n("show_alerts.delete_alert"),
			 message = i18n("show_alerts.confirm_delete_alert").."?",
			 confirm = i18n("delete"),
			 confirm_button = "btn-danger",
		      }
      })
   )

   print(
      template.gen("modal_confirm_dialog.html", {
		      dialog={
			 id      = "release_single_alert",
			 action  = "releaseAlert(alert_to_release)",
			 title   = i18n("show_alerts.release_alert"),
			 message = i18n("show_alerts.confirm_release_alert"),
			 confirm = i18n("show_alerts.release_alert_action"),
			 confirm_button = "btn-primary",
		      }
      })
   )

   print(
      template.gen("modal_confirm_dialog.html", {
		      dialog={
			 id      = "enable_alert_type",
			 action  = "toggleAlert(false)",
			 title   = i18n("show_alerts.enable_alerts_title"),
			 message = i18n("show_alerts.enable_alerts_message", {
        type = "<span class='toggle-alert-id'></span>",
        entity_value = "<span class='toggle-alert-entity-value'></span>"
       }),
			 confirm = i18n("show_alerts.enable_alerts"),
		      }
      })
   )

   print(
      template.gen("modal_confirm_dialog.html", {
		      dialog={
			 id      = "disable_alert_type",
			 action  = "toggleAlert(true)",
			 title   = i18n("show_alerts.disable_alerts_title"),
			 message = i18n("show_alerts.disable_alerts_message", {
        type = "<span class='toggle-alert-id'></span>",
        entity_value = "<span class='toggle-alert-entity-value'></span>"
       }),
			 confirm = i18n("show_alerts.disable_alerts"),
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

	 print[[
<ul class="nav nav-tabs" role="tablist" id="alert-tabs" style="]] print(ternary(options.dont_nest_alerts, 'display:none', '')) print[[">
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
   return $("#]] print(nav_tab_id) print[[ > li > a.active").attr('href').substr(1);
}

function updateDeleteLabel(tabid) {
   var label = $("#purgeBtnLabel");
   var prefix = "]]
      if not isEmptyString(_GET["entity"]) then print(alert_consts.alertEntityLabel(_GET["entity"], true).." ") end
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

function deleteAlertById(alert_key) {
  var params = {};
  params.id_to_delete = alert_key;
  params.status = getCurrentStatus();
  params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

  var form = NtopUtils.paramsToForm('<form method="post"></form>', params);
  form.appendTo('body').submit();
}

var alert_to_toggle = null;

function prepareToggleAlertsDialog(table_id, idx) {
  var table_data = $("#" + table_id ).data("datatable").resultset.data;
  var row = table_data[idx];
  alert_to_toggle = row;

  $(".toggle-alert-id").html(NtopUtils.noHtml(row.column_type).trim());
  $(".toggle-alert-entity-value").html(NtopUtils.noHtml(row.column_entity_formatted).trim())
}

var alert_to_release = null;

function releaseAlert(idx) {
  var table_data = $("#table-engaged-alerts").data("datatable").resultset.data;
  var row = table_data[idx];

  var params = {
    "action": "release_alert",
    "entity": row.column_entity_id,
    "entity_val": row.column_entity_val,
    "alert_type": row.column_type_id,
    "alert_severity": row.column_severity_id,
    "alert_subtype": row.column_subtype,
    "alert_granularity": row.column_granularity,
    "csrf": "]] print(ntop.getRandomCSRFValue()) print[[",
  };

  var form = NtopUtils.paramsToForm('<form method="post"></form>', params);
  form.appendTo('body').submit();
}

function toggleAlert(disable) {
  var row = alert_to_toggle;
  var params = {
    "action": disable ? "disable_alert" : "enable_alert",
    "entity": row.column_entity_id,
    "entity_val": row.column_entity_val,
    "alert_type": row.column_type_id,
    "csrf": "]] print(ntop.getRandomCSRFValue()) print[[",
  };

  var form = NtopUtils.paramsToForm('<form method="post"></form>', params);
  form.appendTo('body').submit();
}
</script>
]]

      if not alt_nav_tabs then print [[<div class="tab-content my-3">]] end

      local status = _GET["status"]
      if(status == nil) then
	 local tab = _GET["tab"]

	 if(tab == "past_alert_list") then
	    status = "historical"
	 elseif(tab == "flow_alert_list") then
	    status = "historical-flows"
	 end
      end

      local status_reset = (status == nil)

      if(has_engaged_alerts) then
	 alert_items[#alert_items + 1] = {
	    ["label"] = i18n("show_alerts.engaged_alerts"),
	    ["chart"] = ternary(areInterfaceTimeseriesEnabled(ifid), "iface:alerts_stats", ""),
	    ["div-id"] = "table-engaged-alerts",  ["status"] = "engaged"}
      elseif status == "engaged" then
	 status = nil; status_reset = 1
      end

      if(has_past_alerts) then
	 alert_items[#alert_items +1] = {
	    ["label"] = i18n("show_alerts.past_alerts"),
	    ["chart"] = "",
	    ["div-id"] = "table-alerts-history",  ["status"] = "historical"}
      elseif status == "historical" then
	 status = nil; status_reset = 1
      end

      if(has_flow_alerts) then
	 alert_items[#alert_items +1] = {
	    ["label"] = i18n("show_alerts.flow_alerts"),
	    ["chart"] = "",
	    ["div-id"] = "table-flow-alerts-history",  ["status"] = "historical-flows"}
      elseif status == "historical-flows" then
	 status = nil; status_reset = 1
      end

      if has_disabled_alerts then
	 alert_items[#alert_items +1] = {
	    ["label"] = i18n("show_alerts.disabled_alerts"),
	    ["chart"] = "",
	    ["div-id"] = "table-disabled-alerts",  ["status"] = "disabled-alerts"}
      end

      for k, t in ipairs(alert_items) do
	 local clicked = "0"
	 if((not alt_nav_tabs) and ((k == 1 and status == nil) or (status ~= nil and status == t["status"]))) then
	    clicked = "1"
	 end
	 print [[
      <div class="tab-pane in" id="tab-]] print(t["div-id"]) print[[">
	<div id="]] print(t["div-id"]) print[["></div>
      </div>

      <script type="text/javascript">
      $("#]] print(nav_tab_id) print[[").append('<li class="nav-item ]] print(ternary(options.dont_nest_alerts, 'hidden', '')) print[["><a class="nav-link" href="#tab-]] print(t["div-id"]) print[[" clicked="]] print(clicked) print[[" role="tab" data-toggle="tab">]] print(t["label"]) print[[</a></li>')
      </script>
   ]]

   if t["status"] == "disabled-alerts" then
     printDisabledAlerts(ifid)
     goto next_menu_item
   end

   print[[
      <script type="text/javascript">
         $('a[href="#tab-]] print(t["div-id"]) print[["]').on('shown.bs.tab', function (e) {
         // append the li to the tabs

	 $("#]] print(t["div-id"]) print[[").datatable({
			url: "]] print(ntop.getHttpPrefix()) print [[/lua/get_alerts_table_data.lua?" + $.param(]] print(tableToJsObject(alert_utils.getTabParameters(url_params, t["status"]))) print [[),
               showFilter: true,
	       showPagination: true,
               buttons: [']]

	 local title = t["label"]

	 if(t["chart"] ~= "") then
	    local base_url

	    if interface.getId() == tonumber(getSystemInterfaceId()) then
	       base_url = "/lua/system_stats.lua"
	    else
	       base_url = "/lua/if_stats.lua"
	    end

	    title = title .. " <small><A HREF='"..ntop.getHttpPrefix().. base_url .. "?ifid="..string.format("%d", ifid).."&page=historical&ts_schema="..t["chart"].."'><i class='fas fa-chart-area fa-sm'></i></A></small>"
	 end

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
	       if tonumber(_GET["alert_type"]) ~= nil then a_type = alert_consts.alertTypeLabel(_GET["alert_type"], true) end
	       if tonumber(_GET["alert_severity"]) ~= nil then a_severity = alert_consts.alertSeverityLabel(_GET["alert_severity"], true) end
	    end

	    if t["status"] == "engaged" then
	       local res = interface.getEngagedAlertsCount(tonumber(_GET["entity"]), _GET["entity_val"], _GET["entity_excludes"])

	       if(res ~= nil) then
		  type_menu_entries = menuEntriesToDbFormat(res.type)
		  sev_menu_entries = menuEntriesToDbFormat(res.severities)
	       end
	    end

	    print(drawDropdown(t["status"], "type", a_type, alert_types, i18n("alerts_dashboard.alert_type"), get_params, type_menu_entries))
	    print(drawDropdown(t["status"], "severity", a_severity, alert_severities, i18n("alerts_dashboard.alert_severity"), get_params, sev_menu_entries))
	 elseif((not isEmptyString(_GET["entity_val"])) and (not hide_extended_title)) then
	    if entity == "host" then
	       title = title .. " - " .. firstToUpper(alert_consts.formatAlertEntity(getInterfaceId(ifname), entity, _GET["entity_val"], nil))
	    end
	 end

   if options.dont_nest_alerts then
     title = ""
   end

	 print[['],
/*
               buttons: ['<div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Severity<span class="caret"></span></button><ul class="dropdown-menu scrollable-dropdown" role="menu"><li>test severity</li></ul></div><div class="btn-group"><button class="btn btn-link dropdown-toggle" data-toggle="dropdown">Type<span class="caret"></span></button><ul class="dropdown-menu scrollable-dropdown" role="menu"><li>test type</li></ul></div>'],
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
	        title: "",
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
            hidden: ]] print(ternary(t["status"] ~= "historical-flows" and t["status"] ~= "historical", "true", "false")) print[[,
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
	    title: "]]print(i18n("score"))print[[",
	    field: "column_score",
            hidden: ]] print(ternary(t["status"] ~= "historical-flows", "true", "false")) print[[,
            sortable: true,
	    css: {
	       textAlign: 'center'
	    }
	 },

	 {
	    title: "]]print(i18n("drilldown"))print[[",
	    field: "column_chart",
            sortable: false,
	    hidden: ]] print(ternary(not interfaceHasNindexSupport() or ntop.isPro(), "false", "true")) print[[,
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
	    css: {
	       textAlign: 'center',
	       width: "10%",
	    }
	 },

      ], tableCallback: function() {
            var table_data = $("#]] print(t["div-id"]) print[[").data("datatable").resultset.data;

            datatableForEachRow("#]] print(t["div-id"]) print[[", function(row_id) {
               var alert_key = $("td:nth(8)", this).html().split("|");
               var alert_key = alert_key[0];
               var data = table_data[row_id];
               var explorer_url = data["column_explorer"];

               if(explorer_url) {
                  datatableAddLinkButtonCallback.bind(this)(10, explorer_url, "]] print(i18n("show_alerts.explorer")) print[[");
                  disable_alerts_dialog = "#disable_flows_alerts";
               }

	       if(]] print(ternary(t["status"] == "historical-flows", "false", "true")) print[[) {
		  if(!data.column_alert_disabled)
		     datatableAddActionButtonCallback.bind(this)(10, "prepareToggleAlertsDialog(']] print(t["div-id"]) print[[',"+ row_id +"); $('#disable_alert_type').modal('show');", "]] print(i18n("show_alerts.disable_alerts")) print[[");
		  else
		     datatableAddActionButtonCallback.bind(this)(10, "prepareToggleAlertsDialog(']] print(t["div-id"]) print[[',"+ row_id +"); $('#enable_alert_type').modal('show');", "]] print(i18n("show_alerts.enable_alerts")) print[[");
	       }

               if(]] print(ternary(t["status"] == "engaged", "true", "false")) print[[)
                 datatableAddActionButtonCallback.bind(this)(10, "alert_to_release = "+ row_id +"; $('#release_single_alert').modal('show');", "]] print(i18n("show_alerts.release_alert_action")) print[[");

               if(]] print(ternary(t["status"] ~= "engaged", "true", "false")) print[[) {
                 datatableAddDeleteButtonCallback.bind(this)(10, "delete_alert_id ='" + alert_key + "'; $('#delete_alert_dialog').modal('show');", "]] print(i18n('delete')) print[[");
}

               $("form", this).submit(function() {
                  // add "status" parameter to the form
                  var get_params = NtopUtils.paramsExtend(]] print(tableToJsObject(alert_utils.getTabParameters(url_params, nil))) print[[, {status:getCurrentStatus()});
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

       ::next_menu_item::
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

      if(has_engaged_alerts or has_past_alerts or has_flow_alerts) then
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
	 local delete_params = alert_utils.getTabParameters(url_params, nil)
	 delete_params.epoch_end = -1

	 print[[<button id="buttonOpenDeleteModal" data-toggle="modal" data-target="#myModal" class="btn btn-secondary"> <span id="purgeBtnMessage">]]
	 print(i18n("show_alerts.purge_subj_alerts", {subj='<span id="purgeBtnLabel"></span>'}))
	 print[[</span></button>
   </div> <!-- closes alertsActionsPanel -->

<script>

NtopUtils.paramsToForm('#modalDeleteForm', ]] print(tableToJsObject(delete_params)) print[[);

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
   return NtopUtils.paramsExtend(]] print(tableToJsObject(alert_utils.getTabParameters(url_params, nil))) print[[, tab_specific);
}

function checkModalDelete() {
   var get_params = getTabSpecificParams();
   var post_params = {};
   post_params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
   post_params.id_to_delete = "__all__";

   // this actually performs the request
   var form = NtopUtils.paramsToForm('<form method="post"></form>', post_params);
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
	    print(' with severity "'..alert_consts.alertSeverityLabel(_GET["alert_severity"], true)..'" ')
	 elseif tonumber(_GET["alert_type"]) ~= nil then
	    print(' with type "'..alert_consts.alertTypeLabel(_GET["alert_type"], true)..'" ')
	 end
	 print[[');
   if (lb.length == 1)
      $(".modal-body #modalDeleteContext").html(" " + lb.html());

   $('#modalDeleteAlertsOlderThan').val(zoomsel.data('older'));

   cur_alert_num_req = $.ajax({
      type: 'GET',
      ]] print("url: '"..ntop.getHttpPrefix().."/lua/get_num_alerts.lua'") print[[,
       data: $.extend(getTabSpecificParams(), {ifid: ]] print(string.format("%d", ifid)) print[[}),
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

function alert_utils.drawAlerts(options)
   local has_engaged_alerts = alert_utils.hasAlerts("engaged", alert_utils.getTabParameters(_GET, "engaged"))
   local has_past_alerts = alert_utils.hasAlerts("historical", alert_utils.getTabParameters(_GET, "historical"))
   local has_disabled_alerts = alerts_api.hasEntitiesWithAlertsDisabled(interface.getId())
   local has_flow_alerts = false

   if _GET["entity"] == nil then
     has_flow_alerts = alert_utils.hasAlerts("historical-flows", alert_utils.getTabParameters(_GET, "historical-flows"))
   end

   alert_utils.checkDeleteStoredAlerts()
   checkDisableAlerts()
   return alert_utils.drawAlertTables(has_past_alerts, has_engaged_alerts, num_flow_alerts, has_disabled_alerts, _GET, true, nil, options)
end

-- #################################

-- A redis set with mac addresses as keys
local function getActiveDevicesHashKey(ifid)
   return "ntopng.cache.active_devices.ifid_" .. ifid
end

function alert_utils.deleteActiveDevicesKey(ifid)
   ntop.delCache(getActiveDevicesHashKey(ifid))
end

-- #################################

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

function alert_utils.check_macs_alerts(ifid)
   local alert_new_devices_enabled = ntop.getPref("ntopng.prefs.alerts.device_first_seen_alert") == "1"
   local alert_device_connection_enabled = ntop.getPref("ntopng.prefs.alerts.device_connection_alert") == "1"

   local active_devices_set = getActiveDevicesHashKey(ifid)
   local prev_active_devices = swapKeysValues(ntop.getMembersCache(active_devices_set) or {})
   local num_prev_active_devices = table.len(prev_active_devices)

   local seen_devices_hash = getFirstSeenDevicesHashKey(ifid)
   local seen_devices = ntop.getHashAllCache(seen_devices_hash) or {}
   local num_seen_devices = table.len(seen_devices)

   local max_active_devices_cardinality = 16384
   if(num_seen_devices >= max_active_devices_cardinality) then
      traceError(TRACE_INFO, TRACE_CONSOLE, string.format("Too many active devices, discarding %u devices", num_seen_devices))
      ntop.delCache(active_devices_set)
      prev_active_devices = {}
   end

   local active_devices = {}
   callback_utils.foreachDevice(getInterfaceName(ifid), function(devicename, devicestats, devicebase)
      -- note: location is always lan when capturing from a local interface
      if (not devicestats.special_mac) and (devicestats.location == "lan") then
         local mac = devicestats.mac

	 active_devices[mac] = 1

         if not seen_devices[mac] then
	    -- First time we see a device
	    ntop.setHashCache(seen_devices_hash, mac, tostring(os.time()))

	    if alert_new_devices_enabled then
	       local name = getDeviceName(mac)
	       setSavedDeviceName(mac, name)

	       alerts_api.store(
	          alerts_api.macEntity(mac),
	          alert_consts.alert_types.alert_new_device.create(
		     alert_consts.alert_severities.warning,
		     name
		  )
	       )
	    end
         end

         if not prev_active_devices[mac] then
	    -- Device connection
	    ntop.setMembersCache(active_devices_set, mac)

            -- Do not nofify new connected devices if the prev_active_devices
            -- set was empty (cleared or on startup)
            if num_prev_active_devices > 0 then

	       if alert_device_connection_enabled then
	          local name = getDeviceName(mac)
	          setSavedDeviceName(mac, name)

	          alerts_api.store(
	             alerts_api.macEntity(mac),
		     alert_consts.alert_types.alert_device_connection.create(
			alert_consts.alert_severities.info,
			name
		     )
		  )
               end
	    end
         end
      end
   end)

   -- Safety check to avoid notifying disconnected devices
   -- during shutdown when they are no longer active in ntopng.
   if not ntop.isShutdown() then

      for mac in pairs(prev_active_devices) do
         if not active_devices[mac] then
            -- Device disconnection
            local name = getSavedDeviceName(mac)
            ntop.delMembersCache(active_devices_set, mac)

            if alert_device_connection_enabled then
               alerts_api.store(
		  alerts_api.macEntity(mac),
		  alert_consts.alert_types.alert_device_disconnection.create(
		     alert_consts.alert_severities.info,
		     name
		  )
	       )
            end
         end
      end
   end
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

function alert_utils.check_host_pools_alerts(ifid)
   local active_pools_set = getActivePoolsHashKey(ifid)
   local prev_active_pools = swapKeysValues(ntop.getMembersCache(active_pools_set)) or {}
   local alert_pool_connection_enabled = ntop.getPref("ntopng.prefs.alerts.pool_connection_alert") == "1"
   local alerts_on_quota_exceeded = ntop.isPro() and ntop.getPref("ntopng.prefs.alerts.quota_exceeded_alert") == "1"
   local pools_stats = nil
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
		     alerts_api.store(
			alerts_api.hostPoolEntity(pool),
			alert_consts.alert_types.alert_quota_exceeded.create(
			   alert_consts.alert_severities.warning,
			   "traffic_quota",
			   pool,
			   proto,
			   info.bytes_value,
			   info.bytes_quota
			)
		     )
		  end

		  if info.time_exceeded and not prev_exceeded[2] then
		     alerts_api.store(
			alerts_api.hostPoolEntity(pool),
			alert_consts.alert_types.alert_quota_exceeded.create(
			   alert_consts.alert_severities.warning,
			   "time_quota",
			   pool,
			   proto,
			   info.time_value,
			   info.time_quota
			)
		     )
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
		  alerts_api.store(
		     alerts_api.hostPoolEntity(pool),
		     alert_consts.alert_types.alert_host_pool_connection.create(
			alert_consts.alert_severities.info,
			pool
		     )
		  )
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
            alerts_api.store(
	       alerts_api.hostPoolEntity(pool),
	       alert_consts.alert_types.alert_host_pool_disconnection.create(
		  alert_consts.alert_severities.info,
		  pool
	       )
            )
         end
      end
   end
end

-- #################################

function alert_utils.disableAlertsGeneration()
   if not haveAdminPrivileges() then
      return
   end

   -- Ensure we do not conflict with others
   ntop.setPref("ntopng.prefs.disable_alerts_generation", "1")
   ntop.reloadPreferences()
   if(verbose) then io.write("[Alerts] Disable done\n") end
end

-- #################################

function alert_utils.flushAlertsData()
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

				      if(verbose) then io.write("[Alerts] Flushing SQLite configuration...\n") end
				      performAlertsQuery("DELETE", "engaged", {}, force_query)
				      performAlertsQuery("DELETE", "historical", {}, force_query)
				      performAlertsQuery("DELETE", "historical-flows", {}, force_query)
   end)

   if(verbose) then io.write("[Alerts] Flushing Redis configuration...\n") end
   deleteCachePattern("ntopng.alerts.*")
   deleteCachePattern("ntopng.prefs.alerts.*")

   -- Avoid using 'alert' instead of 'alerts' if we do not want to touch user scripts configurations
   -- as it also deletes ntopng.prefs.plugins_consts_utils.assigned_ids.const_type_alert and others
   deleteCachePattern("ntopng.prefs.*alerts*")

   alerts_api.purgeAlertsPrefs()
   for _, key in pairs(get_make_room_keys("*")) do deleteCachePattern(key) end

   if(verbose) then io.write("[Alerts] Enabling alerts generation...\n") end
   ntop.setAlertsTemporaryDisabled(false);

   ntop.setPref("ntopng.prefs.disable_alerts_generation", generation_toggle_backup)
   refreshAlerts(interface.getId())

   if(verbose) then io.write("[Alerts] Flush done\n") end
   interface.select(selected_interface)
end

-- #################################

local function alertNotificationActionToLabel(action)
   local label = ""

   if action == "engage" then
      label = "[Engaged]"
   elseif action == "release" then
      label = "[Released]"
   end

   return label
end

-- #################################

function alert_utils.getConfigsetAlertLink(alert_json)
   local configsets = user_scripts.getConfigsets()
   local info = alert_json.alert_generation or (alert_json.status_info and alert_json.status_info.alert_generation)

   if(info and isAdministrator()) then
      -- Ensure that the configset still exists
      if configsets[info.confset_id] then
	 return(' <a href="'.. ntop.getHttpPrefix() ..'/lua/admin/edit_configset.lua?confset_id='..
	    info.confset_id ..'&subdir='.. info.subdir ..'&user_script='.. info.script_key ..'#all">'..
	    '<i class="fas fa-cog" title="'.. i18n("edit_configuration") ..'"></i></a>')
    end
  end

  return('')
end

-- #################################

function alert_utils.getAlertInfo(alert)
  local alert_json = alert["alert_json"]

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

  if(alert.alert_entity == alert_consts.alertEntity("flow") or (alert.alert_entity == nil)) then
    msg = formatRawFlow(alert, alert_json)
  else
    msg = alert_json
    local description = alertTypeDescription(alert.alert_type)
    if(type(description) == "string") then
      -- localization string
      msg = i18n(description, msg)
    elseif(type(description) == "function") then
      msg = description(ifid, alert, msg)
    end
  end

  if(type(msg) == "table") then
   return("")
  end

  if(msg) then
     if(alert_consts.getAlertType(alert.alert_type) == "alert_am_threshold_cross") then
      local plugins_utils = require "plugins_utils"
      local active_monitoring_utils = plugins_utils.loadModule("active_monitoring", "am_utils")
      local host = active_monitoring_utils.key2host(alert.alert_entity_val)

      if host and host.measurement then
	 msg = msg .. ' <a href="'.. ntop.getHttpPrefix() ..'/plugins/active_monitoring_stats.lua?am_host='
           .. host.host .. '&measurement='.. host.measurement ..'&page=overview"><i class="fas fa-cog" title="'.. i18n("edit_configuration") ..'"></i></a>'
      end
    else
      msg = msg .. alert_utils.getConfigsetAlertLink(alert_json)
    end
  end

  return(msg or "")
end

-- #################################

function alert_utils.notification_timestamp_rev(a, b)
   return (a.alert_tstamp > b.alert_tstamp)
end

-- Returns a summary of the alert as readable text
function alert_utils.formatAlertNotification(notif, options)
   local defaults = {
      nohtml = false,
      show_severity = true,
   }
   options = table.merge(defaults, options)

   local msg = string.format("[%s][%d][%s]%s[%s]",
			     formatEpoch(notif.alert_tstamp_end or notif.alert_tstamp or 0),
			     notif.ifid or -1, -- Use -1 to avoid issues with interfaceless use cases (for instance notification test)
			     getInterfaceName(notif.ifid),
			     ternary(options.show_severity == false, "", "[" .. alert_consts.alertSeverityLabel(notif.alert_severity, options.nohtml) .. "]"),
			     alert_consts.alertTypeLabel(notif.alert_type, options.nohtml))

   -- entity can be hidden for example when one is OK with just the message
   if options.show_entity then
      msg = msg.."["..alert_consts.alertEntityLabel(notif.alert_entity).."]"

      if notif.alert_entity ~= "flow" then
	 local ev = notif.alert_entity_val
	 if notif.alert_entity == "host" then
	    -- suppresses @0 when the vlan is zero
	    ev = hostinfo2hostkey(hostkey2hostinfo(notif.alert_entity_val))
	 end

	 msg = msg.."["..(ev or '').."]"
      end
   end

   -- add the label, that is, engaged or released
   msg = msg .. alertNotificationActionToLabel(notif.action).. " "
   local alert_message = alert_utils.formatAlertMessage(notif.ifid, notif)

   if options.nohtml then
      msg = msg .. noHtml(alert_message)
   else
      msg = msg .. alert_message
   end

   return msg
end

-- ##############################################

-- Global function
function alert_utils.checkStoreAlertsFromC()
  if(not areAlertsEnabled()) then
    return
  end

  while not ntop.isDeadlineApproaching() do
    local alert = ntop.popInternalAlerts()

    if alert == nil then
      break
    end

    if(verbose) then tprint(alert) end

    local entity_info, type_info = processStoreAlertFromQueue(alert)

    if((type_info ~= nil) and (entity_info ~= nil)) then
      alerts_api.store(entity_info, type_info, alert.alert_tstamp)
    end
  end
end

-- ##############################################

local function notify_ntopng_status(started)
   local info = ntop.getInfo()
   local severity = alert_consts.alertSeverity("info")
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
        severity = alert_consts.alertSeverity("error")
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

   local entity_value = "ntopng"

   obj = {
      entity_type = alert_consts.alertEntity("process"), entity_value=entity_value,
      type = alert_consts.alertType("alert_process_notification"),
      severity = severity,
      message = msg,
      when = os.time() }

   if anomalous then
      telemetry_utils.notify(obj)
   end

  local entity_info = alerts_api.processEntity(entity_value)
  local type_info = alert_consts.alert_types.alert_process_notification.create(
     alert_consts.alert_severities[alert_consts.alertSeverityRaw(severity)],
     event,
     msg_details
  )

  interface.select(getSystemInterfaceId())
  return(alerts_api.store(entity_info, type_info))
end

function alert_utils.notify_ntopng_start()
   return(notify_ntopng_status(true))
end

function alert_utils.notify_ntopng_stop()
   return(notify_ntopng_status(false))
end

return alert_utils
