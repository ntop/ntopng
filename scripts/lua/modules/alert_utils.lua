--
-- (C) 2014-21 - ntop.org
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
local alert_severities = require "alert_severities"
local alert_consts = require "alert_consts"
local format_utils = require "format_utils"
local telemetry_utils = require "telemetry_utils"
local tracker = require "tracker"
local alerts_api = require "alerts_api"
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
      if alert_consts.alert_types[alert_key].format then
	 -- New API
	 return alert_consts.alert_types[alert_key].format
      else
	 -- TODO: Possible removed once migration is done
	 return(alert_consts.alert_types[alert_key].i18n_description)
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

   if what == "historical-flows" then
      if tonumber(opts.alert_l7_proto) ~= nil then
         wargs[#wargs+1] = "AND l7_proto = "..(opts.alert_l7_proto)
      end
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
   -- tprint(statement.." (from "..what..") WHERE "..query .. " ".. group_by)
   

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

  local res = interface.getEngagedAlertsCount(entity_type_filter, entity_value_filter)

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

   if(_POST["action"] == "release_alert") then
      local entity_info = {
         alert_entity = alert_consts.alert_entities[alert_consts.alertEntityRaw(_POST["entity"])],
         alert_entity_val = _POST["entity_val"],
      }

      local type_info = {
         alert_type = (alert_consts.alert_types[alert_consts.alertTypeRaw(_POST["alert_type"])]).meta,
         alert_severity = alert_severities[alert_consts.alertSeverityRaw(_POST["alert_severity"])],
         alert_subtype = _POST["alert_subtype"],
         alert_granularity = alert_consts.alerts_granularities[alert_consts.sec2granularity(_POST["alert_granularity"])],
      }

      alerts_api.release(entity_info, type_info)
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

local function formatRawFlow(ifid, alert, alert_json)
   require "flow_utils"
   local time_bounds
   local add_links = (not skip_add_links)

   if interfaceHasNindexSupport() and not skip_add_links then
      -- only add links if nindex is present
      add_links = true
      time_bounds = {getAlertTimeBounds(alert)}
   end

   -- TODO: adapter just to be compatible with old alerts, can be removed at some point
   if alert_json["status_info"] then
      alert_json = json.decode(alert_json["status_info"])
   end

   -- active flow lookup
   if not interface.isView() and alert_json and alert_json["ntopng.key"] and alert_json["hash_entry_id"] and alert["alert_tstamp"] then
      -- attempt a lookup on the active flows
      local active_flow = interface.findFlowByKeyAndHashId(alert_json["ntopng.key"], alert_json["hash_entry_id"])

      if active_flow and active_flow["seen.first"] < tonumber(alert["alert_tstamp"]) then
	 return string.format("%s [%s: <A class='btn btn-sm btn-info' HREF='%s/lua/flow_details.lua?flow_key=%u&flow_hash_id=%u'><i class='fas fa-search-plus'></i></A> %s]",
			      '',
			      i18n("flow"), ntop.getHttpPrefix(), active_flow["ntopng.key"], active_flow["hash_entry_id"],
			      getFlowLabel(active_flow, true, true))
      end
   end

   -- pretend alert is a flow to reuse getFlowLabel
   local flow = {
      ["cli.ip"] = alert["cli_addr"], ["cli.port"] = tonumber(alert["cli_port"]),
      ["cli.blacklisted"] = tostring(alert["cli_blacklisted"]) == "1",
      ["cli.localhost"] = tostring(alert["cli_localhost"]) == "1",
      ["srv.ip"] = alert["srv_addr"], ["srv.port"] = tonumber(alert["srv_port"]),
      ["srv.blacklisted"] = tostring(alert["srv_blacklisted"]) == "1",
      ["srv.localhost"] = tostring(alert["srv_localhost"]) == "1",
      ["vlan"] = alert["vlan_id"]}

   flow = "["..i18n("flow")..": "..(getFlowLabel(flow, false, add_links, time_bounds, {page = "alerts"}) or "").."] "
   local l4_proto_label = l4_proto_to_string(alert["proto"] or 0) or ""

   if not isEmptyString(l4_proto_label) then
      flow = flow.."[" .. l4_proto_label .. "] "
   end

   if alert_json ~= nil then
      -- render the json
      local msg = ""

      if not isEmptyString(flow) then
         msg = msg..flow.." "
      end

      if not isEmptyString(alert_json["info"]) then
         local lb = ""
	 local info

	 if string.len(alert_json["info"]) > 24 then
	    info = "<abbr title=\"".. alert_json["info"] .."\">".. shortenString(alert_json["info"], 24)
	 else
	    info = alert_json["info"]
	 end
         msg = msg.."["..i18n("info")..": " .. info ..lb.."] "
      end

      flow = msg
   end

   if alert_json then
      flow = flow..getFlowStatusInfo(alert, alert_json)
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
   params.l7_proto = nil

   if selection_name == "severity" then
      actual_entries = performAlertsQuery("select alert_severity id, count(*) count", status, params, nil, "alert_severity" --[[ group by ]])
   elseif selection_name == "type" then
      actual_entries = performAlertsQuery("select alert_type id, count(*) count", status, params, nil, "alert_type" --[[ group by ]])
   elseif selection_name == "l7_proto" then
      actual_entries = performAlertsQuery("select l7_proto id, count(*) count", status, params, nil, "l7_proto" --[[ group by ]])
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
   elseif selection_name == "l7_proto" then
      id_to_label = interface.getnDPIProtoName
   end
   
   actual_entries = actual_entries or getMenuEntries(status, selection_name, get_params)

   local buttons = '<div class="btn-group">'

   button_label = button_label or firstToUpper(selection_name)
   if active_entry ~= nil and active_entry ~= "" then
      if selection_name == "l7_proto" then 
         button_label = firstToUpper(interface.getnDPIProtoName(active_entry))..'<span class="fas fa-filter"></span>'
      else
         button_label = firstToUpper(active_entry)..'<span class="fas fa-filter"></span>'
      end
   end

   buttons = buttons..'<button class="btn btn-link dropdown-toggle" data-toggle="dropdown">'..button_label
   buttons = buttons..'<span class="caret"></span></button>'

   buttons = buttons..'<ul class="dropdown-menu dropdown-menu-right" role="menu">'

   local class_active = ""

   if active_entry == nil then class_active = 'active' end
   buttons = buttons..'<li><a class="dropdown-item '..class_active..'" href="?status='..status..'">All</a></i>'

   -- add a label to each entry
   for _, entry in pairs(actual_entries) do
      local id = tonumber(entry["id"])
      entry.label = firstToUpper(id_to_label(id, true))
   end

   for _, entry in pairsByField(actual_entries, 'label', asc) do
      local id = tonumber(entry["id"])
      local count = entry["count"]

      if(id >= 0) then
        local label = entry.label

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

function alert_utils.printAlertTables(entity_type, alert_source, page_name, page_params, alt_name, options)
   local has_engaged_alerts, has_past_alerts, has_flow_alerts = false,false,false
   local tab = _GET["tab"]
   local have_nedge = ntop.isnEdge()
   options = options or {}

   local function printTab(tab, content, sel_tab)
      if(tab == sel_tab) then print("\t<li class='nav-item active show'>") else print("\t<li class='nav-item'>") end
      print("<a class='nav-link' href=\""..ntop.getHttpPrefix().."/lua/"..page_name.."?page=alerts&tab="..tab)
      for param, value in pairs(page_params) do
	 print("&"..param.."="..value)
      end
      print("\">"..content.."</a></li>\n")
   end

   -- these fields will be used to perform queries
   _GET["entity"] = alert_consts.alertEntity(entity_type)
   _GET["entity_val"] = alert_source

   -- possibly process pending delete arguments
   alert_utils.checkDeleteStoredAlerts()

   -- possibly add a tab if there are alerts configured for the host
   has_engaged_alerts = alert_utils.hasAlerts("engaged", alert_utils.getTabParameters(_GET, "engaged"))
   has_past_alerts = alert_utils.hasAlerts("historical", alert_utils.getTabParameters(_GET, "historical"))
   has_flow_alerts = alert_utils.hasAlerts("historical-flows", alert_utils.getTabParameters(_GET, "historical-flows"))

   if(has_engaged_alerts or has_past_alerts or has_flow_alerts) then
      print("<div class='card'>")
      print("<div class='card-header'>")
      print('<ul class="nav nav-tabs card-header-tabs">')

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
      -- if there are no alerts, we show a message
      print("<div class=\"alert alert alert-info\"><i class=\"fas fa-info-circle fa-lg\" aria-hidden=\"true\"></i>" .. " " .. i18n("show_alerts.no_recorded_alerts_message").."</div>")
      return
   end

   print('</ul>')
   print("</div>")

   alert_utils.drawAlertTables(has_past_alerts, has_engaged_alerts, has_flow_alerts, false, _GET, true, nil, { dont_nest_alerts = true })
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
     window.open(']] print(ntop.getHttpPrefix()) print [[/lua/rest/v1/get/pcap/live_extraction.lua?' + frm.serialize(), '_self', false);
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

function alert_utils.drawAlertTables(has_past_alerts, has_engaged_alerts, has_flow_alerts, has_disabled_alerts, get_params, hide_extended_title, alt_nav_tabs, options)
   local alert_items = {}
   local url_params = {}
   local options = options or {}
   local ifid = interface.getId()
   local default_filter = ''
   local additional_params = {}
   local err     = ""
   local update_err = ""

   -- Checking if a new filter for the alert is added
   if _POST["filters"] then
      additional_filters = _POST["filters"]

      local success = ""
      local new_filter  = {}

      -- Getting the parameters
      -- NB: THIS NEEDS TO BE DONE IN AJAX
      success, new_filter = user_scripts.parseFilterParams(additional_filters, _POST["subdir"], false)
      
      if success then
	 local confset_id = _POST["confset_id"]
	 success, update_err = user_scripts.updateScriptConfig(tonumber(confset_id), _POST["script_key"], _POST["subdir"], nil, nil, new_filter)
      else
	 -- Error while parsing the params, error is printed
	 update_err = new_filter
      end
   end
   -- this paramater is used to print out a card container for the table
   local is_standalone = options.is_standalone or false

   print(
      template.gen("modal_confirm_dialog.html", {
		      dialog={
			 id      = "delete_alert_dialog",
			 action  = "deleteAlertById(delete_alert_id)",
			 title   = i18n("show_alerts.delete_alert"),
			 message = i18n("show_alerts.confirm_delete_alert"),
			 confirm = i18n("delete"),
			 confirm_button = "btn-danger",
		      }
      })
   )

   print(
      template.gen("modal_alert_filter_dialog.html", {
      		      dialog={
			 id		   = "filter_alert_dialog",
			 action		   = "filterAlertByFilters(confset_id, subdir, script_key)",
          		 title		   = i18n("show_alerts.filter_alert"),
          		 message	   = i18n("show_alerts.confirm_filter_alert"),
          		 field_input_title = i18n("current_filter"),
          		 alert_filter      = "default_filter",
	  		 confirm 	   = i18n("filter"),
			 confirm_button    = "btn-warning",
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
            id      = "myModal",
            action  = "checkModalDelete()",
            title   = i18n("show_alerts.purge_all_alerts"),
            confirm_button = "btn-danger",
            custom_alert_class = "alert alert-danger",
            message = i18n("show_alerts.purge_subj_alerts_confirm", {subj = '<span id="modalDeleteContext"></span><span id="modalDeleteAlertsMsg"></span>'}),
            confirm = i18n("show_alerts.purge_num_alerts", {
                     num_alerts = '<img id="alerts-summary-wait" src="'..ntop.getHttpPrefix()..'/img/loading.gif"/><span id="alerts-summary-body"></span>'
            }),
		      }
      })
   )

   if is_standalone then
      print("<div class='card'>")
      print("<div class='card-header'>")
   end

   for k,v in pairs(get_params) do if k ~= "csrf" then url_params[k] = v end end
   if not alt_nav_tabs then
      print[[
         <ul class="nav nav-tabs card-header-tabs card-header-pills" role="tablist" id="alert-tabs" style="]] print(ternary(options.dont_nest_alerts, 'display:none', '')) print[[">
         <!-- will be populated later with javascript -->
         </ul>
      ]]
      nav_tab_id = "alert-tabs"
   else
      nav_tab_id = alt_nav_tabs
   end

   if is_standalone then
      print("</div>")
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

function filterAlertByFilters(confset_id, subdir, script_key) {
   var params = {};
   params.filters = document.getElementById("name_input").value;
   params.confset_id = confset_id;
   params.subdir     = subdir;
   params.script_key = script_key;
   params.status = getCurrentStatus();
   params.csrf = "]] print(ntop.getRandomCSRFValue()) print[["

   var form = NtopUtils.paramsToForm('<form method="post"></form>', params);
   form.appendTo('body').submit();
}

var alert_to_toggle = null;
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
</script>
]]

      if not alt_nav_tabs then
         print [[<div class='card-body'>]]
         print [[<div class="tab-content">]]
      end

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

      -- In case of error while trying to add a new alert to exclude to the exclusion list
      -- Done in this way cause it's a post onto the page 
      if not isEmptyString(err) or not isEmptyString(update_err) then
          print[[<div class="alert alert-danger"><button type="button" class="close" data-dismiss="alert">x</button>"Error while excluding the alert, check the parameters and try again"</div>]]
      end

      for k, t in ipairs(alert_items) do
	 local clicked = "0"
	 if((not alt_nav_tabs) and ((k == 1 and status == nil) or (status ~= nil and status == t["status"]))) then
	    clicked = "1"
	 end

	 print [[
      <div class="tab-pane in" id="tab-]] print(t["div-id"]) print[[">
         <!-- Table to render --->
	      <div id="]] print(t["div-id"]) print[["></div>
      </div>

      <script type="text/javascript">
      $("#]] print(nav_tab_id) print[[").append('<li class="nav-item ]] print(ternary(options.dont_nest_alerts, 'hidden', '')) print[["><a class="nav-link" href="#tab-]] print(t["div-id"]) print[[" clicked="]] print(clicked) print[[" role="tab" data-toggle="tab">]] print(t["label"]) print[[</a></li>')
      </script>
   ]]

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

	 if(not options.hide_filters)  then
	    -- alert_consts.alert_severity_keys and alert_consts.alert_type_keys are defined in lua_utils
	    local alert_severities = {}
	    for s, _ in pairs(alert_severities) do alert_severities[#alert_severities +1 ] = s end
	    local alert_types = {}
       for s, _ in pairs(alert_consts.alert_types) do alert_types[#alert_types +1 ] = s end
       local l7_proto = {}
	    local type_menu_entries = nil
       local sev_menu_entries = nil
       local l7_proto_entries = nil

       local a_type, a_severity, a_l7_proto = nil, nil, nil
	    if clicked == "1" then
          if tonumber(_GET["alert_type"]) ~= nil then a_type = alert_consts.alertTypeLabel(_GET["alert_type"], true) end
          if tonumber(_GET["alert_l7_proto"]) ~= nil then a_l7_proto = tonumber(_GET["alert_l7_proto"]) end
	       if tonumber(_GET["alert_severity"]) ~= nil then a_severity = alert_consts.alertSeverityLabel(_GET["alert_severity"], true) end
	    end

	    if t["status"] == "engaged" then
	       local res = interface.getEngagedAlertsCount(tonumber(_GET["entity"]), _GET["entity_val"])

	       if(res ~= nil) then
		  type_menu_entries = menuEntriesToDbFormat(res.type)
        sev_menu_entries = menuEntriesToDbFormat(res.severities)
        --l7_proto_entries = menuEntriesToDbFormat(res.l7_proto)
	       end
       end
       
       print(drawDropdown(t["status"], "type", a_type, alert_types, i18n("alerts_dashboard.alert_type"), get_params, type_menu_entries))
       if t["status"] == "historical-flows" then
         print(drawDropdown(t["status"], "l7_proto", a_l7_proto, l7_proto, i18n("application"), get_params, l7_proto_entries))                    
       end
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
	    title: "]]print(i18n("application"))print[[",
	    field: "column_ndpi",
            sortable: false,
	    hidden: ]] print(ternary(t["status"] ~= "historical-flows", "true", "false")) print[[,
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

               if(data["column_filter"]) {
                  datatableAddFilterButtonCallback.bind(this)(10, "confset_id = '" + data["column_confset_id"] + "'; subdir = '" + data["column_subdir"] + "'; script_key = '" + data["column_script_key"] + "'; $('#name_input').attr('value', '" + data["column_filter"] + "'); $('#filter_alert_dialog').modal('show');", "<i class='fas fa-ban'></i>");
               }                

               if(data["column_drilldown"]) {
                  datatableAddLinkButtonCallback.bind(this)(10, data["column_drilldown"], "<i class='fas fa-search-plus drilldown-icon'></i>", "]] print(i18n("show_alerts.expand_action")) print[[");
               }

               if(explorer_url) {
                  datatableAddLinkButtonCallback.bind(this)(10, explorer_url, "<i class='fab fa-wpexplorer'></i>", "]] print(i18n("show_alerts.explorer")) print[[");
                  disable_alerts_dialog = "#disable_flows_alerts";
               }

               if(]] print(ternary(t["status"] == "engaged", "true", "false")) print[[)
                 datatableAddActionButtonCallback.bind(this)(10, "alert_to_release = "+ row_id +"; $('#release_single_alert').modal('show');", "<i class='fas fa-unlock'></i>", true, "]] print(i18n("show_alerts.release_alert_action")) print[[");

               if(]] print(ternary(t["status"] ~= "engaged", "true", "false")) print[[) {
                 datatableAddDeleteButtonCallback.bind(this)(10, "delete_alert_id ='" + alert_key + "'; $('#delete_alert_dialog').modal('show');", "<i class='fas fa-trash'></i>");
}

               $("form", this).submit(function() {
                  // add "status" parameter to the form
                  var get_params = NtopUtils.paramsExtend(]] print(tableToJsObject(alert_utils.getTabParameters(url_params, nil))) print[[, {status:getCurrentStatus()});
                  $(this).attr("action", "?" + $.param(get_params));

                  return true;
               });

               $(`a[title]`).tooltip();
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

    if not alt_nav_tabs then
      print [[</div> <!-- closes tab-content -->]]
      print [[</div> <!-- Close Card body -->]]
   end
    local has_fixed_period = ((not isEmptyString(_GET["epoch_begin"])) or (not isEmptyString(_GET["epoch_end"])))

    -- the dont_print_footer option is used to skip the card footer printing
    if not options.dont_print_footer then print([[<div class='card-footer'>]]) end

   local purge_label
   if (_GET['alert_type']) then
      purge_label = i18n("show_alerts.alerts_to_purge_x", { filter = "<b>" .. alert_consts.alertTypeLabel(_GET["alert_type"], true) .. "</b>"})
   elseif (_GET['alert_severity']) then
      purge_label = i18n("show_alerts.alerts_to_purge_x", { filter = "<b>" .. alert_consts.alertSeverityLabel(_GET["alert_severity"], true) .. "</b>"})
   elseif (not isEmptyString(_GET['alert_l7_proto'])) then
      purge_label = i18n("show_alerts.alerts_to_purge_x", { filter = "<b>" .. interface.getnDPIProtoName(tonumber(_GET["alert_l7_proto"])) .. "</b>"})
   else
      purge_label = i18n("show_alerts.alerts_to_purge")
   end

    print('<div id="alertsActionsPanel">')
    print(purge_label .. ': ')
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

	 print[[<button id="buttonOpenDeleteModal" data-toggle="modal" data-target="#myModal" class="btn btn-danger"> <span id="purgeBtnMessage">]]
	 print(i18n("show_alerts.purge_subj_alerts", {subj='<span id="purgeBtnLabel"></span>'}))
	 print[[</span></button>

         <a href="#" class="btn btn-primary" role="button" aria-disabled="true" onclick="downloadAlerts();"><i class="fas fa-download"></i></a>
   </div> <!-- closes alertsActionsPanel -->]]

   if not options.dont_print_footer then print([[</div> <!-- card-footer -->]]) end

   print[[
   </div>  <!-- closes card -->

<script>

NtopUtils.paramsToForm('#modalDeleteForm', ]] print(tableToJsObject(delete_params)) print[[);

function getTabSpecificParams() {
   var tab_specific = {status:getCurrentStatus()};
   var period_end = $('#modalDeleteAlertsOlderThan').val();
   if (parseInt(period_end) > 0)
      tab_specific.epoch_end = period_end;

   if (tab_specific.status == "]] print(_GET["status"]) print[[") {
      tab_specific.alert_severity = ]] if tonumber(_GET["alert_severity"]) ~= nil then print(_GET["alert_severity"]) else print('""') end print[[;
      tab_specific.alert_l7_proto = ]] if tonumber(_GET["alert_l7_proto"]) ~= nil then print(_GET["alert_l7_proto"]) else print('""') end print[[;
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

function downloadAlerts() {
    $.ajax({
	type: 'POST',
	contentType: "application/json",
	dataType: "json",
	url: `${http_prefix}/lua/rest/v1/get/alert/data.lua`,
	data: JSON.stringify(getTabSpecificParams()),
	success: function(rsp) {
	 // Convert the Byte Data to BLOB object.
	 // Source: https://www.aspsnippets.com/Articles/Download-File-in-AJAX-Response-Success-using-jQuery.aspx

	  var blob = new Blob([JSON.stringify(rsp.rsp)], { type: "application/octetstream" });

	  //Check the Browser type and download the File.
	  var isIE = false || !!document.documentMode;
	  if (isIE) {
	    window.navigator.msSaveBlob(blob, fileName);
	  } else {
	    var url = window.URL || window.webkitURL;
	    var link = url.createObjectURL(blob);
	    var a = $("<a />");
	    a.attr("download", "alerts.json");
	    a.attr("href", link);
	    $("body").append(a);
	    a[0].click();
	    $("body").remove(a);
	    }
	  }
    });
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
    elseif tonumber(_GET["alert_l7_proto"]) ~= nil then
       print(' with type "'..interface.getnDPIProtoName(tonumber(_GET["alert_l7_proto"]))..'" ')
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
   local has_flow_alerts = false

   if _GET["entity"] == nil then
     has_flow_alerts = alert_utils.hasAlerts("historical-flows", alert_utils.getTabParameters(_GET, "historical-flows"))
   end

   alert_utils.checkDeleteStoredAlerts()
   return alert_utils.drawAlertTables(has_past_alerts, has_engaged_alerts, num_flow_alerts, false, _GET, true, nil, options)
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

         alert:set_severity(params.user_script_config.severity)
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

         alert:set_severity(alert_severities.warning)
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

            alert:set_severity(alert_severities.notice)
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

            alert:set_severity(alert_severities.notice)
            alert:store(alerts_api.hostPoolEntity(pool))
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

   for _, key in pairs(get_make_room_keys("*")) do deleteCachePattern(key) end

   if(verbose) then io.write("[Alerts] Enabling alerts generation...\n") end
   ntop.setAlertsTemporaryDisabled(false);

   ntop.setPref("ntopng.prefs.disable_alerts_generation", generation_toggle_backup)
   refreshAlerts(interface.getId())

   if(verbose) then io.write("[Alerts] Flush done\n") end
   interface.select(selected_interface)
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

function alert_utils.formatAlertMessage(ifid, alert, alert_json, skip_live_data)
  local msg

  if(alert_json == nil) then
   alert_json = alert_utils.getAlertInfo(alert)
  end

  msg = alert_json
  local description = alertTypeDescription(alert.alert_type)

  if(type(description) == "string") then
     -- localization string
     msg = i18n(description, msg)
  elseif(type(description) == "function") then
     msg = description(ifid, alert, msg)
  end

  if(type(msg) == "table") then
   return("")
  end

  -- Append flow information to the alert message
  if(alert.alert_entity == alert_consts.alertEntity("flow") or not alert.alert_entity) and not skip_live_data then
      if msg == nil then 
         msg = formatRawFlow(ifid, alert, alert_json, true --[[ skip alert description, description already set --]])
      else
         msg = msg.. " "..formatRawFlow(ifid, alert, alert_json, true --[[ skip alert description, description already set --]])
      end
  end

  if(msg) then
     if(alert_consts.getAlertType(alert.alert_type) == "alert_am_threshold_cross") then
      local plugins_utils = require "plugins_utils"
      local active_monitoring_utils = plugins_utils.loadModule("active_monitoring", "am_utils")
      local host = active_monitoring_utils.key2host(alert.alert_entity_val)

      if host and host.measurement and not host.is_infrastructure then
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
      severity =  " [" .. alert_consts.alertSeverityLabel(notif.alert_severity, options.nohtml, options.emoji) .. "]"
   end

   if(options.nodate == true) then
      when = ""
   else
      when = formatEpoch(notif.alert_tstamp_end or notif.alert_tstamp or 0)

      if(not options.no_bracket_around_date) then
	 when = "[" .. when .. "]"
      end

      when = when .. " "
   end

   local msg = string.format("%s%s%s [%s]",
			     when, ifname, severity,
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
   msg = msg .. " " .. alertNotificationActionToLabel(notif.action, options.emoji).. " "
   local alert_message = alert_utils.formatAlertMessage(notif.ifid, notif)

   if(options.add_cr) then
      msg = msg .. "\n"
   end

   if options.nohtml then
      msg = msg .. noHtml(alert_message)
      msg = msg:gsub('&nbsp;', "")
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

   if(alert.alert_type == "misconfigured_dhcp_range") then
      local router_info = {host = alert.router_ip, vlan = alert.vlan_id}
      entity_info = alerts_api.hostAlertEntity(alert.client_ip, alert.vlan_id)
      type_info = alert_consts.alert_types.alert_ip_outsite_dhcp_range.new(
	 router_info,
	 alert.mac_address,
	 alert.client_mac,
	 alert.sender_mac
      )
      type_info:set_severity(alert_severities.warning)
      type_info:set_subtype(string.format("%s_%s_%s", hostinfo2hostkey(router_info), alert.client_mac, alert.sender_mac))
   elseif(alert.alert_type == "mac_ip_association_change") then
      if(ntop.getPref("ntopng.prefs.ip_reassignment_alerts") == "1") then
         local name = getDeviceName(alert.new_mac)
         entity_info = alerts_api.macEntity(alert.new_mac)
         type_info = alert_consts.alert_types.alert_mac_ip_association_change.new(
            name,
            alert.ip,
            alert.old_mac,
            alert.new_mac
         )
         type_info:set_severity(alert_severities.warning)
         type_info:set_subtype(string.format("%s_%s_%s", alert.ip, alert.old_mac, alert.new_mac))
      end
   elseif(alert.alert_type == "login_failed") then
      entity_info = alerts_api.userEntity(alert.user)
      type_info = alert_consts.alert_types.alert_login_failed.new()
      type_info:set_severity(alert_severities.warning)
   elseif(alert.alert_type == "broadcast_domain_too_large") then
      entity_info = alerts_api.macEntity(alert.src_mac)
      type_info = alert_consts.alert_types.alert_broadcast_domain_too_large.new(alert.src_mac, alert.dst_mac, alert.vlan_id, alert.spa, alert.tpa)
      type_info:set_severity(alert_severities.warning)
      type_info:set_subtype(string.format("%u_%s_%s_%s_%s", alert.vlan_id, alert.src_mac, alert.spa, alert.dst_mac, alert.tpa))
   elseif((alert.alert_type == "user_activity") and (alert.scope == "login")) then
      entity_info = alerts_api.userEntity(alert.user)
      type_info = alert_consts.alert_types.alert_user_activity.new(
         "login",
         nil,
         nil,
         nil,
         "authorized"
      )
      type_info:set_severity(alert_severities.notice)
      type_info:set_subtype("login//")
   elseif(alert.alert_type == "nfq_flushed") then
      entity_info = alerts_api.interfaceAlertEntity(alert.ifid)
      type_info = alert_consts.alert_types.alert_nfq_flushed.new(
         getInterfaceName(alert.ifid),
         alert.pct,
         alert.tot,
         alert.dropped
      )

      type_info:set_severity(alert_severities.error)
   else
      traceError(TRACE_ERROR, TRACE_CONSOLE, "Unknown alert type " .. (alert.alert_type or ""))
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
   local type_info = alert_consts.alert_types.alert_process_notification.new(
      event,
      msg_details
   )

   type_info:set_severity(alert_severities[alert_consts.alertSeverityRaw(severity)])

   interface.select(getSystemInterfaceId())
   return(type_info:store(entity_info))
end

function alert_utils.notify_ntopng_start()
   return(notify_ntopng_status(true))
end

function alert_utils.notify_ntopng_stop()
   return(notify_ntopng_status(false))
end

-- A redis set with mac addresses as keys
function alert_utils.deleteOldData(interface_id, epoch_end)
   local opts = {}

   opts["ifid"] = interface_id
   opts["epoch_end"] = tostring(epoch_end)
   opts["status"] = "historical"

   deleteAlerts("historical", opts)

   opts["status"] = "historical-flows"
   deleteAlerts("historical-flows", opts)
end


return alert_utils
