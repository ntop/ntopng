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

-- Keep in sync with Utils::mapScoreToSeverity (C) */
function alert_utils.mapScoreToSeverity(score)
  if (not score or score < prefs.score_level_notice) then
    return alert_severities.info
  elseif score < prefs.score_level_warning then
    return alert_severities.notice
  elseif score < prefs.score_level_error then
    return alert_severities.warning
  else 
    return alert_severities.error
  end
end

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

   if tonumber(opts.alert_id) ~= nil then
      wargs[#wargs+1] = "AND alert_id = "..(opts.alert_id)
   end

   if tonumber(opts.severity) ~= nil then
      wargs[#wargs+1] = "AND severity = "..(opts.severity)
   end

   if what == "historical-flows" then
      if tonumber(opts.alert_l7_proto) ~= nil then
         wargs[#wargs+1] = "AND l7_proto = "..(opts.alert_l7_proto)
      end
   end

   if((not isEmptyString(opts.sortColumn)) and (not isEmptyString(opts.sortOrder))) then
      local order_by

      if opts.sortColumn == "column_date" then
         order_by = "tstamp"
      elseif opts.sortColumn == "column_key" then
         order_by = "rowid"
      elseif opts.sortColumn == "column_severity" then
         order_by = "severity"
      elseif opts.sortColumn == "column_type" then
         order_by = "alert_id"
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
  local type_filter = tonumber(params.alert_id)
  local severity_filter = tonumber(params.severity)
  local entity_type_filter = tonumber(params.entity)
  local entity_value_filter = params.entity_val

  local perPage = tonumber(params.perPage or 10)
  local sortColumn = params.sortColumn or "column_"
  local sortOrder = params.sortOrder or "desc"
  local sOrder = ternary(sortOrder == "desc", rev_insensitive, asc_insensitive)
  local currentPage = tonumber(params.currentPage or 1)
  local totalRows = 0

  -- tprint(string.format("type=%s sev=%s entity=%s val=%s", type_filter, severity_filter, entity_type_filter, entity_value_filter))
  local alerts = interface.getEngagedAlerts(entity_type_filter, entity_value_filter, type_filter, severity_filter)
  local sort_2_col = {}

  -- Sort
  for idx, alert in pairs(alerts) do
    if sortColumn == "column_type" then
      sort_2_col[idx] = alert.alert_id
    elseif sortColumn == "column_severity" then
      sort_2_col[idx] = alert.severity
    elseif sortColumn == "column_duration" then
      sort_2_col[idx] = os.time() - alert.tstamp
    else -- column_date
      sort_2_col[idx] = alert.tstamp
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

--@brief Deletes all stored alerts matching an host and an IP
-- @return nil
function alert_utils.deleteFlowAlertsMatching(host_ip, alert_id)
   local flow_alert_store = require("flow_alert_store").new()
   flow_alert_store:add_ip_filter(hostkey2hostinfo(host_ip)["host"])
   flow_alert_store:add_alert_id_filter(alert_id)

   -- Perform the actual deletion
   flow_alert_store:delete()
end

-- #################################

--@brief Deletes all stored alerts matching an host and an IP
-- @return nil
function alert_utils.deleteHostAlertsMatching(host_ip, alert_id)
   local host_alert_store = require("host_alert_store").new()
   host_alert_store:add_ip_filter(hostkey2hostinfo(host_ip)["host"])
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
      opts.severity = nil
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
   if alert_json["alert_info"] then
      alert_json = json.decode(alert_json["alert_info"])
   end

   -- active flow lookup
   if not interface.isView() and alert_json and alert_json["ntopng.key"] and alert_json["hash_entry_id"] and alert["alert_tstamp"] then
      -- attempt a lookup on the active flows
      local active_flow = interface.findFlowByKeyAndHashId(alert_json["ntopng.key"], alert_json["hash_entry_id"])

      if active_flow and active_flow["seen.first"] < tonumber(alert["alert_tstamp"]) then
	 return string.format("<i class=\"fas fa-stream\"></i> %s <A class='btn-sx' HREF='%s/lua/flow_details.lua?flow_key=%u&flow_hash_id=%u'><i class='fas fa-search-plus'></i></A> %s",
			      '',
			      ntop.getHttpPrefix(), active_flow["ntopng.key"], active_flow["hash_entry_id"],
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

   flow = "[ <i class=\"fas fa-stream\"></i> "..(getFlowLabel(flow, false, add_links, time_bounds, {page = "alerts"}) or "").."] "
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
         msg = msg.."[" .. info ..lb.."] "
      end

      flow = msg
   end

   if alert_json then
      flow = flow..getAlertTypeInfo(alert, alert_json)
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

   local select_clause = {}    -- Contains the selection which is <alert_entity>, <selection_name>
   local group_by_clause = {}  -- The clause used to group alerts. It is <alert_entity>, <selection_name> for all non-flow alerts

   if status == "historical-flows" then
      -- Flows don't have the alert_entity as a table column so we just put the entity id as a placeholder
      select_clause[#select_clause + 1] = string.format("%u entity", alert_entities.flow.entity_id)
   else
      -- TODO: entities will be removed when every entity will have its own database table
      select_clause[#select_clause + 1] = "alert_entity entity"
      group_by_clause[#group_by_clause + 1] = "alert_entity"
   end

   if selection_name == "severity" then
      select_clause[#select_clause + 1] = "severity id"
      group_by_clause[#group_by_clause + 1] = "severity"
   elseif selection_name == "type" then
      select_clause[#select_clause + 1] = "alert_id id"
      group_by_clause[#group_by_clause + 1] = "alert_id"
   elseif selection_name == "l7_proto" then
      select_clause[#select_clause + 1] = "l7_proto id"
      group_by_clause[#group_by_clause + 1] = "l7_proto"
   end

   select_clause[#select_clause + 1] = "count(*) count"

   local select_str = "SELECT "..table.concat(select_clause, ", ")
   local group_by_str =  table.concat(group_by_clause, ", ")

   actual_entries = performAlertsQuery(select_str, status, params, nil, group_by_str --[[ group by ]])

   -- tprint({select_str, group_by_str, status, params})

   return actual_entries
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

local function drawDropdown(status, selection_name, active_entry, button_label, get_params, actual_entries)
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
      local alert_entity = tonumber(entry["entity"])

      entry.label = firstToUpper(id_to_label(id, true, alert_entity))
   end

   for _, entry in pairsByField(actual_entries, 'label', asc) do
      local id = tonumber(entry["id"])
      local alert_entity = tonumber(entry["entity"])
      local count = entry["count"]
      if(id >= 0) then
        local label = entry.label

        class_active = ""
        if label == active_entry then class_active = 'active' end
        -- buttons = buttons..'<li'..class_active..'><a class="dropdown-item" href="'..ntop.getHttpPrefix()..'/lua/show_alerts.lua?status='..status
        buttons = buttons..'<li><a class="dropdown-item '..class_active..'" href="?status='..status
        buttons = buttons..dropdownUrlParams(get_params)
	buttons = buttons..'&entity='..(alert_entity or '')
        buttons = buttons..'&alert_'..selection_name..'='..id..'">'
	buttons = buttons..firstToUpper(label)

	-- Add the formatted alert entity between square brackets
	if alert_entity then
	   buttons = buttons..' ['..alert_consts.alertEntityLabel(alert_entity)..']'
	end

        buttons = buttons..' ('..count..')</a></li>'
      end
   end

   buttons = buttons..'</ul></div>'

   return buttons
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

		     alert:set_score(50)
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

		     alert:set_score(50)
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

		  alert:set_score(10)
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

            alert:set_score(10)
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
   local info = alert_json.alert_generation or (alert_json.alert_info and alert_json.alert_info.alert_generation)

   if(info and isAdministrator()) then
	 return(' <a href="'.. ntop.getHttpPrefix() ..'/lua/admin/edit_configset.lua?'..
	    'subdir='.. info.subdir ..'&user_script='.. info.script_key ..'#all">'..
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

  if(msg) then
     if(alert_consts.getAlertType(alert.alert_id, alert.entity_id) == "alert_am_threshold_cross") then
      local plugins_utils = require "plugins_utils"
      local active_monitoring_utils = plugins_utils.loadModule("active_monitoring", "am_utils")
      local host = json.decode(alert.json)["host"]

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

  return msg or ""
end

-- #################################

function alert_utils.notification_timestamp_rev(a, b)
   return (a.tstamp > b.tstamp)
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

      if notif.entity_id ~= "flow" then
	 local ev = notif.entity_val
	 if notif.entity_id == "host" then
	    -- suppresses @0 when the vlan is zero
	    ev = hostinfo2hostkey(hostkey2hostinfo(notif.entity_val))
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
      type_info:set_score(50)
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
      type_info:set_score(50)
      type_info:set_subtype(string.format("%s_%s_%s", alert.ip, alert.old_mac, alert.new_mac))
   elseif(alert.alert_id == "login_failed") then
      entity_info = alerts_api.userEntity(alert.user)
      type_info = alert_consts.alert_types.alert_login_failed.new()
      type_info:set_score(50)
   elseif(alert.alert_id == "broadcast_domain_too_large") then
      entity_info = alerts_api.macEntity(alert.src_mac)
      type_info = alert_consts.alert_types.alert_broadcast_domain_too_large.new(alert.src_mac, alert.dst_mac, alert.vlan_id, alert.spa, alert.tpa)
      type_info:set_score(50)
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
      type_info:set_score(10)
      type_info:set_subtype("login//")
   elseif(alert.alert_id == "nfq_flushed") then
      entity_info = alerts_api.interfaceAlertEntity(alert.ifid)
      type_info = alert_consts.alert_types.alert_nfq_flushed.new(
         getInterfaceName(alert.ifid),
         alert.pct,
         alert.tot,
         alert.dropped
      )

      type_info:set_score(100)
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

return alert_utils
