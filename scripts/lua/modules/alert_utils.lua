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

package.path = dirs.installdir .. "/scripts/lua/modules/alert_endpoints/?.lua;" .. package.path

local alert_process_queue = "ntopng.alert_process_queue"

local shaper_utils = nil

local CONST_DEFAULT_PACKETS_DROP_PERCENTAGE_ALERT = "5"
local MAX_NUM_PER_MODULE_QUEUED_ALERTS = 1024 -- should match ALERTS_MANAGER_MAX_ENTITY_ALERTS on the AlertsManager

if(ntop.isPro()) then
   package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
   shaper_utils = require("shaper_utils")
end

function alertSeverityLabel(v, nohtml)
   local res = _handleArray(alert_consts.alert_severity_keys, tonumber(v))
   if res ~= nil and nohtml == true then res = noHtml(res) end
   return res
end

function alertSeverity(v)
   local severity_table = {}
   for i, t in ipairs(alert_consts.alert_severity_keys) do
      severity_table[#severity_table + 1] = {t[2], t[3]}
   end
   return(_handleArray(severity_table, v))
end

function alertSeverityRaw(sev_idx)
   sev_idx = sev_idx + 2 -- -1 and 0
   if sev_idx <= #alert_consts.alert_severity_keys then
      return alert_consts.alert_severity_keys[sev_idx][3]
   end
   return nil
end

function alertTypeLabel(v, nohtml)
   local res = _handleArray(alert_consts.alert_type_keys, tonumber(v))
   if res ~= nil and nohtml == true then res = noHtml(res) end
   return res
end

function alertType(v)
   local typetable = {}
   for i, t in ipairs(alert_consts.alert_type_keys) do
      typetable[#typetable + 1] = {t[2], t[3]}
   end
   return(_handleArray(typetable, v))
end

function alertEngine(v)
   local enginetable = {}
   for i, t in ipairs(alert_consts.alert_engine_keys) do
      enginetable[#enginetable + 1] = {t[2], t[3]}
   end
   return(_handleArray(enginetable, v))
end

function alertEngineLabel(v)
   return _handleArray(alert_consts.alert_engine_keys, tonumber(v))
end

function alertEngineRaw(idx)
   idx = idx + 1
   if idx <= #alert_consts.alert_engine_keys then
      return alert_consts.alert_engine_keys[idx][3]
   end
   return nil
end

function alertSeverity(v)
   local severitytable = {}

   for i, t in ipairs(alert_consts.alert_severity_keys) do
      severitytable[#severitytable + 1] = {t[2], t[3]}
   end
   return(_handleArray(severitytable, v))
end

function alertTypeRaw(alert_idx)
   if(alert_idx == nil) then return nil end

   alert_idx = alert_idx + 2 -- -1 and 0
   if alert_idx <= #alert_consts.alert_type_keys then
      return alert_consts.alert_type_keys[alert_idx][3]
   end
   return nil
end

function alertEntityLabel(v, nothml)
   local res = _handleArray(alert_consts.alert_entity_keys, tonumber(v))
   if res ~= nil and nohtml == true then res = noHtml(res) end
   return res
end

function alertEntity(v)
   local typetable = {}
   for i, t in ipairs(alert_consts.alert_entity_keys) do
      typetable[#typetable + 1] = {t[2], t[3]}
   end
   return(_handleArray(typetable, v))
end

function alertEntityRaw(entity_idx)
   entity_idx = entity_idx + 1
   if entity_idx <= #alert_consts.alert_entity_keys then
      return alert_consts.alert_entity_keys[entity_idx][3]
   end
   return nil
end

-- ##############################################################################

local function ndpival_bytes(json, protoname)
   key = "ndpiStats"

   -- Host
   if((json[key] == nil) or (json[key][protoname] == nil)) then
      if(verbose) then print("## ("..protoname..") Empty<br>\n") end
      return(0)
   else
      local v = (json[key][protoname]["bytes"]["sent"] or 0) + (json[key][protoname]["bytes"]["rcvd"] or 0)
      if(verbose) then print("##  ("..protoname..") "..v.."<br>\n") end
      return(v)
   end
end

local function proto_bytes(old, new, protoname)
   return(ndpival_bytes(new, protoname) - ndpival_bytes(old, protoname))
end

--
-- NOTE
--
-- These functions are called by the loadstring function to evaluate
-- threshold crosses.
-- When reading a field from the "old" parameter, an "or" operator should be used
-- to avoid working on nil value. Nil values can be found, for example, when a
-- new entity appear and it has not previous dump or across ntopng reboot.
--

function bytes(old, new, interval)
   -- io.write(debug.traceback().."\n")
   if(verbose) then print("bytes("..interval..")") end

   if(new["sent"] ~= nil) then
      -- Host
      return((new["sent"]["bytes"] + new["rcvd"]["bytes"]) - ((old["sent"] and old["sent"]["bytes"] or 0) + (old["rcvd"] and old["rcvd"]["bytes"] or 0)))
   else
      -- Interface
      return(new.stats.bytes - (old.stats and old.stats.bytes or 0))
   end
end

function packets(old, new, interval)
   if(verbose) then print("packets("..interval..")") end
   if(new["sent"] ~= nil) then
      -- Host
      return((new["sent"]["packets"] + new["rcvd"]["packets"]) - ((old["sent"] and old["sent"]["packets"] or 0) + (old["rcvd"] and old["rcvd"]["packets"] or 0)))
   else
      -- Interface
      return(new.stats.packets - (old.stats and old.stats.packets or 0))
   end
end

function active(old, new, interval)
   if(verbose) then print("active("..interval..")") end
   local diff = (new["total_activity_time"] or 0) - (old["total_activity_time"] or 0)
   return(diff)
end

function idle(old, new, interval)
   if(verbose) then print("idle("..interval..")") end
   local diff = os.time()-new["seen.last"]
   return(diff)
end

function dns(old, new, interval)
   if(verbose) then print("dns("..interval..")") end
   return(proto_bytes(old, new, "DNS"))
end

function p2p(old, new, interval)
   if(verbose) then print("p2p("..interval..")") end
   return(proto_bytes(old, new, "eDonkey") + proto_bytes(old, new, "BitTorrent") + proto_bytes(old, new, "Skype"))
end

function throughput(old, new, interval)
   if(verbose) then print("throughput("..interval..")") end

   return((bytes(old, new, interval) * 8)/ (interval*1000000))
end

function ingress(old, new, interval)
   return new["ingress"] - (old["ingress"] or 0)
end

function egress(old, new, interval)
   return new["egress"] - (old["egress"] or 0)
end

function inner(old, new, interval)
   return new["inner"] - (old["inner"] or 0)
end

function flows(old, new, interval)
   local new_flows = new["flows.as_client"] + new["flows.as_server"]
   local old_flows = (old["flows.as_client"] or 0) + (old["flows.as_server"] or 0)
   return new_flows - old_flows
end

function active_local_hosts(old, new, interval)
   return new["local_hosts"]
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
   for _, granularity in pairs(alert_consts.alerts_granularity) do
      granularity = granularity[1]
      if timespan == granularity then
	 return true
      end
   end
   return false
end

function is_allowed_alarmable_metric(metric)
   for _, allowed_metric in pairs(alert_consts.alarmable_metrics) do
      if metric == allowed_metric then
	 return true
      end
   end
   return false
end

function get_alerts_hash_name(timespan, ifname)
   local ifid = getInterfaceId(ifname)
   if not is_allowed_timespan(timespan) or tonumber(ifid) == nil then
      return nil
   end

   return "ntopng.prefs.alerts_"..timespan..".ifid_"..tostring(ifid)
end

-- Get the hash key used for saving global settings
function get_global_alerts_hash_key(entity_type, alert_source)
   if entity_type == "host" then
      return "local_hosts"
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

-- Note: see getConfiguredAlertsThresholds for threshold object format
local function entity_threshold_crossed(granularity, old_table, new_table, threshold)
   local rc
   local threshold_info = table.clone(threshold)

   if old_table and new_table then -- meaningful checks require both new and old tables
      -- Needed because Lua. loadstring() won't work otherwise.
      old = old_table
      new = new_table
      duration = granularity2sec(granularity)

      local op = op2jsop(threshold.operator)

      -- This is where magic happens: loadstring() evaluates the string
      local what = "val = "..threshold.metric.."(old, new, duration); if(val ".. op .. " " .. threshold.edge .. ") then return(true) else return(false) end"

      local f = loadstring(what)

      rc = f()
      threshold_info.value = val
   else
      rc = false
      threshold_info.value = nil
   end

   return rc, threshold_info
end

-- #################################

function granularity2sec(g)
   for _, granularity in pairs(alert_consts.alerts_granularity) do
      if(granularity[1] == g) then
	 return(granularity[3])
      end
   end

   return(0)
end

function op2jsop(op)
   if op == "gt" then
      return ">"
   elseif op == "lt" then
      return "<"
   else
      return "=="
   end
end

function performAlertsQuery(statement, what, opts, force_query)
   local wargs = {"WHERE", "1=1"}

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

   if tonumber(opts.alert_engine) ~= nil then
      wargs[#wargs+1] = "AND alert_engine = "..(opts.alert_engine)
   end

   if((not isEmptyString(opts.sortColumn)) and (not isEmptyString(opts.sortOrder))) then
      local order_by

      if opts.sortColumn == "column_date" then
         order_by = "alert_tstamp"
      elseif opts.sortColumn == "column_severity" then
         order_by = "alert_severity"
      elseif opts.sortColumn == "column_type" then
         order_by = "alert_type"
      elseif((opts.sortColumn == "column_duration") and (what == "historical")) then
         order_by = "(alert_tstamp_end - alert_tstamp)"
      else
         -- default
         order_by = "alert_tstamp"
      end

      wargs[#wargs+1] = "ORDER BY "..order_by
      wargs[#wargs+1] = string.upper(opts.sortOrder)
   end

   -- pagination
   if((tonumber(opts.perPage) ~= nil) and (tonumber(opts.currentPage) ~= nil)) then
      local to_skip = (tonumber(opts.currentPage)-1) * tonumber(opts.perPage)
      wargs[#wargs+1] = "LIMIT"
      wargs[#wargs+1] = to_skip..","..(opts.perPage)
   end

   local query = table.concat(wargs, " ")
   local res

   -- Uncomment to debug the queries
   --~ tprint(statement.." (from "..what..") "..query)

   if what == "engaged" then
      res = interface.queryAlertsRaw(true, statement, query, force_query)
   elseif what == "historical" then
      res = interface.queryAlertsRaw(false, statement, query, force_query)
   elseif what == "historical-flows" then
      res = interface.queryFlowAlertsRaw(statement, query, force_query)
   else
      error("Invalid alert subject: "..what)
   end

   return res
end

-- #################################

function getNumAlerts(what, options)
   local num = 0
   local opts = getUnpagedAlertOptions(options or {})
   local res = performAlertsQuery("SELECT COUNT(*) AS count", what, opts)
   if((res ~= nil) and (#res == 1) and (res[1].count ~= nil)) then num = tonumber(res[1].count) end

   return num
end

-- #################################

function getAlerts(what, options)
   return performAlertsQuery("SELECT rowid, *", what, options)
end

-- #################################

function deleteAlerts(what, options)
   local opts = getUnpagedAlertOptions(options or {})
   performAlertsQuery("DELETE", what, opts)
   invalidateEngagedAlertsCache(getInterfaceId(ifname))
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

--
-- This function should be updated whenever a new alert entity type is available.
-- If entity_info is nil, then no links will be provided.
--
local function formatAlertEntity(ifid, entity_type, entity_value, entity_info)
   local value

   if entity_type == "host" then
      local host_info = hostkey2hostinfo(entity_value)
      value = resolveAddress(host_info)

      if host_info ~= nil then
	 value = "<a href='"..ntop.getHttpPrefix().."/lua/host_details.lua?ifid="..ifid
	    .."&host="..hostinfo2hostkey(host_info).."'>"..value.."</a>"
      end
   elseif entity_type == "interface" then
      value = getInterfaceName(ifid)

      if entity_info ~= nil then
	 value = "<a href='"..ntop.getHttpPrefix().."/lua/if_stats.lua?ifid="..ifid.."'>"..value.."</a>"
      end
   elseif entity_type == "network" then
      value = hostkey2hostinfo(entity_value)["host"]

      if entity_info ~= nil then
	 value = "<a href='"..ntop.getHttpPrefix().."/lua/network_details.lua?network="..(entity_info.network_id).."&page=historical'>"
	    ..value.."</a>"
      end
   else
      -- fallback
      value = entity_value
   end

   -- try to get a localized message
   local localized = i18n("alert_messages."..entity_type.."_entity", {entity_value=value})

   if localized ~= nil then
      return localized
   else
      -- fallback
      return entity_type.." "..value
   end
end

-- #################################

function formatRawFlow(record, flow_json)
   require "flow_utils"

   -- pretend record is a flow to reuse getFlowLabel
   local flow = {
      ["cli.ip"] = record["cli_addr"], ["cli.port"] = tonumber(record["cli_port"]),
      ["cli.blacklisted"] = tostring(record["cli_blacklisted"]) == "1",
      ["srv.ip"] = record["srv_addr"], ["srv.port"] = tonumber(record["srv_port"]),
      ["srv.blacklisted"] = tostring(record["srv_blacklisted"]) == "1",
      ["vlan"] = record["vlan_id"]}
   flow = "["..i18n("flow")..": "..(getFlowLabel(flow, false, true) or "").."] "

   local l4_proto_label, l4_proto = l4_proto_to_string(record["proto"] or 0) or ""

   if not isEmptyString(l4_proto_label) then
      flow = flow.."[" .. i18n("l4_protocol") .. ": " .. l4_proto_label .. "] "
   end

   if (l4_proto == "tcp") or (l4_proto =="udp") then
      local l7proto_name = interface.getnDPIProtoName(tonumber(record["l7_proto"]) or 0)

      if not isEmptyString(l7proto_name) then
	 flow = flow.."["..i18n("db_explorer.application_protocol")..": <A HREF='"..ntop.getHttpPrefix().."/lua/hosts_stats.lua?protocol="..record["l7_proto"].."'> " ..l7proto_name.."</A>] "
      end
   end

   local decoded = json.decode(flow_json)

   if decoded ~= nil then
      -- render the json
      local msg = ""
      if not isEmptyString(record["flow_status"]) then
         msg = msg..getFlowStatus(tonumber(record["flow_status"])).." "
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

   return flow
end

-- #################################

local function drawDropdown(status, selection_name, active_entry, entries_table, button_label)
   -- alert_consts.alert_severity_keys and alert_consts.alert_type_keys are defined in lua_utils
   local id_to_label
   if selection_name == "severity" then
      id_to_label = alertSeverityLabel
   elseif selection_name == "type" then
      id_to_label = alertTypeLabel
   end

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
	 actual_entries = interface.queryAlertsRaw(engaged, "select alert_severity id, count(*) count", "group by alert_severity")
      elseif selection_name == "type" then
	 actual_entries = interface.queryAlertsRaw(engaged, "select alert_type id, count(*) count", "group by alert_type")
      end

   end

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
   buttons = buttons..'<li'..class_active..'><a href="?status='..status..'">All</a></i>'

   for _, entry in pairs(actual_entries) do
      local id = tonumber(entry["id"])
      local count = entry["count"]
      local label = id_to_label(id, true)

      class_active = ""
      if label == active_entry then class_active = ' class="active"' end
      -- buttons = buttons..'<li'..class_active..'><a href="'..ntop.getHttpPrefix()..'/lua/show_alerts.lua?status='..status
      buttons = buttons..'<li'..class_active..'><a href="?status='..status
      buttons = buttons..'&alert_'..selection_name..'='..id..'">'
      buttons = buttons..firstToUpper(label)..' ('..count..')</a></li>'
   end

   buttons = buttons..'</ul></div>'

   return buttons
end

-- #################################

function getGlobalAlertsConfigurationHash(granularity, entity_type, alert_source)
   return 'ntopng.prefs.alerts_global.'..granularity.."."..get_global_alerts_hash_key(entity_type, alert_source)
end

local global_redis_thresholds_key = "thresholds"

-- #################################

function drawAlertSourceSettings(entity_type, alert_source, delete_button_msg, delete_confirm_msg, page_name, page_params, alt_name, show_entity, options)
   local num_engaged_alerts, num_past_alerts, num_flow_alerts = 0,0,0
   local tab = _GET["tab"]
   local have_nedge = ntop.isnEdge()

   -- This code controls which entries to show under the tabs Every Minute/Hourly/Daily
   local descr
   if entity_type == "network" then
      descr = table.clone(alert_consts.network_alert_functions_description)
   elseif entity_type == "interface" then
      -- interface
      descr = table.merge(alert_consts.alert_functions_description, alert_consts.iface_alert_functions_description)
      descr["active"] = nil
      descr["flows"] = nil
   else
      -- host
      descr = table.clone(alert_consts.alert_functions_description)
   end

   local flow_rate_attacker_key = "flow_attacker_threshold"
   local flow_rate_victim_key = "flow_victim_threshold"
   local syn_attacker_key = "syn_attacker_threshold"
   local syn_victim_key = "syn_victim_threshold"
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
      num_past_alerts = getNumAlerts("historical", getTabParameters(_GET, "historical"))
      num_flow_alerts = getNumAlerts("historical-flows", getTabParameters(_GET, "historical-flows"))

      if num_past_alerts > 0 or num_engaged_alerts > 0 or num_flow_alerts > 0 then
         if(tab == nil) then
            -- if no tab is selected and there are alerts, we show them by default
            tab = "alert_list"
         end

         printTab("alert_list", "Detected Alerts", tab)
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

   for _,e in pairs(alert_consts.alerts_granularity) do
      local k = e[1]
      local l = e[2]
      l = '<i class="fa fa-cog" aria-hidden="true"></i>&nbsp;'..l
      printTab(k, l, tab)
   end

   local anomalies_config = {
      {
         title = i18n("entity_thresholds.flow_attacker_title"),
         descr = i18n("entity_thresholds.flow_attacker_description"),
         key = flow_rate_attacker_key,
         global_default = 25, step = 1
      }, {
         title = i18n("entity_thresholds.flow_victim_title"),
         descr = i18n("entity_thresholds.flow_victim_description"),
         key = flow_rate_victim_key,
         global_default = 25, step = 1
	 }, {
         title = i18n("entity_thresholds.syn_attacker_title"),
         descr = i18n("entity_thresholds.syn_attacker_description"),
         key = syn_attacker_key,
         global_default = 10, step = 5
	    }, {
         title = i18n("entity_thresholds.syn_victim_title"),
         descr = i18n("entity_thresholds.syn_victim_description"),
         key = syn_victim_key,
         global_default = 10, step = 5
	       }
   }

   local global_redis_hash = getGlobalAlertsConfigurationHash(tab, entity_type, alert_source)

   print('</ul>')

   if((show_entity) and (tab == "alert_list")) then
      drawAlertTables(num_past_alerts, num_engaged_alerts, num_flow_alerts, _GET, true)
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
            ntop.delHashCache(get_alerts_hash_name(tab, ifname), alert_source)

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
         for k,_ in pairs(descr) do
	    value    = _POST["value_"..k]
	    operator = _POST["op_"..k]

	    if((value ~= nil) and (operator ~= nil)) then
	       --io.write("\t"..k.."\n")
	       to_save = true
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

         if(to_save) then
            -- This specific entity alerts
            if(alerts == "") then
               ntop.delHashCache(get_alerts_hash_name(tab, ifname), alert_source)
            else
               ntop.setHashCache(get_alerts_hash_name(tab, ifname), alert_source, alerts)
            end

            -- Global alerts
            if(global_alerts ~= "") then
               ntop.setHashCache(global_redis_hash, global_redis_thresholds_key, global_alerts)
            else
               ntop.delHashCache(global_redis_hash, global_redis_thresholds_key)
            end
         else
            alerts = ntop.getHashCache(get_alerts_hash_name(tab, ifname), alert_source)
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

      for key,v in pairsByKeys(descr, asc) do
         print("<tr><td><b>".. alert_consts.alert_functions_info[key].label .."</b><br>")
         print("<small>"..v.."</small>\n")

	 for _, prefix in pairs({"", "global_"}) do
	    local k = prefix..key
	    print("</td><td>")
	    print("<select name=op_".. k ..">\n")
	    if((vals[k] ~= nil) and (vals[k][1] == "gt")) then print("<option selected=\"selected\"") else print("<option ") end
	    print("value=\"gt\">&gt;</option>\n")

	    if((vals[k] ~= nil) and (vals[k][1] == "lt")) then print("<option selected=\"selected\"") else print("<option ") end
	    print("value=\"lt\">&lt;</option>\n")
	    print("</select>\n")
	    print("<input type=number min=1 step=1 class=\"text-right form-control\" style=\"display:inline; width:12em;\" name=\"value_"..k.."\" value=\"")
	    if(vals[k] ~= nil) then print(vals[k][2]) end
	    print("\">\n")
	 end
         print("</td></tr>\n")
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
         print("<li>" .. i18n("alerts_thresholds_config.note_deltas_of_idle_host_become_active") .. "</li>")
	 print("<li>" .. i18n("alerts_thresholds_config.note_checks_on_active_hosts") .. "</li>")
	 print("<li>" .. i18n("alerts_thresholds_config.note_attacker_victime_threshold") .. "</li>")
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
      local res = interface.queryAlertsRaw(false,
					   "SELECT alert_entity, alert_entity_val, count(*) count",
					   "GROUP BY alert_entity, alert_entity_val HAVING COUNT >= "..max_num_alerts_per_entity)

      for _, e in pairs(res) do
	 local to_keep = (max_num_alerts_per_entity * 0.8) -- deletes 20% more alerts than the maximum number
	 to_keep = round(to_keep, 0)
	 -- tprint({e=e, total=e.count, to_keep=to_keep, to_delete=to_delete, to_delete_not_discounted=(e.count - max_num_alerts_per_entity)})
	 local cleanup = interface.queryAlertsRaw(false,
						  "DELETE",
						  "WHERE rowid NOT IN (SELECT rowid FROM closed_alerts WHERE alert_entity="..e.alert_entity.." AND alert_entity_val=\""..e.alert_entity_val.."\""..
						     "ORDER BY alert_tstamp DESC LIMIT "..to_keep..")")
	 -- TODO: possibly raise a too many alerts for entity e
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

function drawAlertTables(num_past_alerts, num_engaged_alerts, num_flow_alerts, get_params, hide_extended_title, alt_nav_tabs)
   local alert_items = {}
   local url_params = {}

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
	 print[[
<br>
<ul class="nav nav-tabs" role="tablist" id="alert-tabs">
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

      local status = _GET["status"]
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

         $("#]] print(nav_tab_id) print[[").append('<li><a href="#tab-]] print(t["div-id"]) print[[" clicked="]] print(clicked) print[[" role="tab" data-toggle="tab">]] print(t["label"]) print[[</a></li>')

         $('a[href="#tab-]] print(t["div-id"]) print[["]').on('shown.bs.tab', function (e) {
         // append the li to the tabs

	 $("#]] print(t["div-id"]) print[[").datatable({
			url: "]] print(ntop.getHttpPrefix()) print [[/lua/get_alerts_data.lua?" + $.param(]] print(tableToJsObject(getTabParameters(url_params, t["status"]))) print [[),
               showFilter: true,
	       showPagination: true,
               buttons: [']]

	 local title = t["label"]

	 -- TODO this condition should be removed and page integration support implemented
	 if((isEmptyString(_GET["entity"])) and isEmptyString(_GET["epoch_begin"]) and isEmptyString(_GET["epoch_end"])) then
	    -- alert_consts.alert_severity_keys and alert_consts.alert_type_keys are defined in lua_utils
	    local alert_severities = {}
	    for _, s in pairs(alert_consts.alert_severity_keys) do alert_severities[#alert_severities +1 ] = s[3] end
	    local alert_types = {}
	    for _, s in pairs(alert_consts.alert_type_keys) do alert_types[#alert_types +1 ] = s[3] end

	    local a_type, a_severity = nil, nil
	    if clicked == "1" then
	       if tonumber(_GET["alert_type"]) ~= nil then a_type = alertTypeLabel(_GET["alert_type"], true) end
	       if tonumber(_GET["alert_severity"]) ~= nil then a_severity = alertSeverityLabel(_GET["alert_severity"], true) end
	    end

	    print(drawDropdown(t["status"], "type", a_type, alert_types, i18n("alerts_dashboard.alert_type")))
	    print(drawDropdown(t["status"], "severity", a_severity, alert_severities, i18n("alerts_dashboard.alert_severity")))
	 elseif((not isEmptyString(_GET["entity_val"])) and (not hide_extended_title)) then
	    if entity == "host" then
	       title = title .. " - " .. firstToUpper(formatAlertEntity(getInterfaceId(ifname), entity, _GET["entity_val"], nil))
	    end
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
       ]]

	 if t["status"] == "historical-flows" then
	    print("hidden: true,")
	 end

	 print[[
	    css: {
	       textAlign: 'center',
          whiteSpace: 'nowrap',
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
               var alert_key = $("td:nth(5)", this).html().split("|");
               var alert_id = alert_key[0];
               var historical_url = alert_key[1];

               if (typeof(historical_url) === "string")
                  datatableAddLinkButtonCallback.bind(this)(7, historical_url, "]] print(i18n("show_alerts.explorer")) print[[");
               datatableAddDeleteButtonCallback.bind(this)(7, "delete_alert_id ='" + alert_id + "'; $('#delete_alert_dialog').modal('show');", "]] print(i18n('delete')) print[[");

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
       data: getTabSpecificParams(),
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

-- Check for checkpoint expiration. This could occurr, for example, if the
-- user disables then re-enables alerts
local function checkpointExpired(checkpoint, working_status)
   local tdiff = working_status.now - checkpoint.timestamp

   return tdiff > 1.9 * working_status.interval
end

-- #################################

local function getEngagedAlertsCacheKey(ifid, granularity)
   return "ntopng.cache.engaged_alerts_cache_ifid_"..ifid.."_".. granularity
end

local function getConfiguredAlertsThresholds(ifname, granularity)
   local thresholds_key = get_alerts_hash_name(granularity, ifname)
   local thresholds_config = {}
   local res = {}

   -- Handle the global configuration
   local global_conf_keys = ntop.getKeysCache(getGlobalAlertsConfigurationHash(granularity, "*", "*")) or {}

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

-- Extracts the configured thresholds for the entity, global and local
local function getEntityThresholds(configured_thresholds, entity_type, entity)
   local res = {}
   local global_conf_key = get_global_alerts_hash_key(entity_type, entity)

   if configured_thresholds[global_conf_key] ~= nil then
      -- Global configuration exists
      for k, v in pairs(configured_thresholds[global_conf_key]) do
         res[k] = v
      end
   end

   -- Possibly override global thresholds with local configured ones
   if configured_thresholds[entity] ~= nil then
      for k, v in pairs(configured_thresholds[entity]) do
         res[k] = v
      end
   end

   return res
end

-- #################################

local function formatThresholdCross(ifid, engine, entity_type, entity_value, entity_info, alert_key, threshold_info)
   if threshold_info.metric then
      local info = alert_consts.alert_functions_info[threshold_info.metric]
      local label = info and string.lower(info.label) or threshold_info.metric
      local value = info and info.fmt(threshold_info.value) or threshold_info.value
      local edge = info and info.fmt(threshold_info.edge) or threshold_info.edge

      return alertEngineLabel(engine).." <b>".. label .."</b> crossed by "..formatAlertEntity(ifid, entity_type, entity_value, entity_info)..
	 " ["..value.." &"..(threshold_info.operator).."; "..edge.."]"
   end

   return ""
end

local function formatSynFlood(ifid, engine, entity_type, entity_value, entity_info, alert_key, alert_info)
   if entity_info.anomalies ~= nil then
      if (alert_key == "syn_flood_attacker") and (entity_info.anomalies.syn_flood_attacker ~= nil) then
	 local anomaly_info = entity_info.anomalies.syn_flood_attacker

	 return firstToUpper(formatAlertEntity(ifid, entity_type, entity_value, entity_info)).." is a SYN Flooder ("..
	    (anomaly_info.last_trespassed_hits).." SYN sent in "..secondsToTime(anomaly_info.over_threshold_duration_sec)..")"
      elseif (alert_key == "syn_flood_victim") and (entity_info.anomalies.syn_flood_victim ~= nil) then
	 local anomaly_info = entity_info.anomalies.syn_flood_victim

	 return firstToUpper(formatAlertEntity(ifid, entity_type, entity_value, entity_info)).." is under SYN flood attack ("..
	    (anomaly_info.last_trespassed_hits).." SYN received in "..secondsToTime(anomaly_info.over_threshold_duration_sec)..")"
      end
   end

   return ""
end

local function formatFlowsFlood(ifid, engine, entity_type, entity_value, entity_info, alert_key, alert_info)
   if entity_info.anomalies ~= nil then
      if (alert_key == "flows_flood_attacker") and (entity_info.anomalies.flows_flood_attacker) then
	 local anomaly_info = entity_info.anomalies.flows_flood_attacker
	 return firstToUpper(formatAlertEntity(ifid, entity_type, entity_value, entity_info)).." is a Flooder ("..
	    (anomaly_info.last_trespassed_hits).." flows sent in "..secondsToTime(anomaly_info.over_threshold_duration_sec)..")"
      elseif (alert_key == "flows_flood_victim") and (entity_info.anomalies.flows_flood_victim) then
	 local anomaly_info = entity_info.anomalies.flows_flood_victim
	 return firstToUpper(formatAlertEntity(ifid, entity_type, entity_value, entity_info)).." is under flood attack ("..
	    (anomaly_info.last_trespassed_hits).." flows received in "..secondsToTime(anomaly_info.over_threshold_duration_sec)..")"
      end
   end

   return ""
end

local function formatMisconfiguredApp(ifid, engine, entity_type, entity_value, entity_info, alert_key, alert_info)
   if entity_info.anomalies ~= nil then
      if alert_key == "too_many_flows" then
	 return firstToUpper(formatAlertEntity(ifid, entity_type, entity_value, entity_info))..
	    " has too many flows. Please extend the --max-num-flows/-X command line option"
      elseif alert_key == "too_many_hosts" then
	 return firstToUpper(formatAlertEntity(ifid, entity_type, entity_value, entity_info))..
	    " has too many hosts. Please extend the --max-num-hosts/-x command line option"
      end
   end

   return ""
end

local function formatTooManyPacketDrops(ifid, engine, entity_type, entity_value, entity_info, alert_key, alert_info)
   local max_drop_perc = ntop.getPref(getInterfacePacketDropPercAlertKey(getInterfaceName(ifid)))
   if isEmptyString(max_drop_perc) then
      max_drop_perc = CONST_DEFAULT_PACKETS_DROP_PERCENTAGE_ALERT
   end

   return firstToUpper(formatAlertEntity(ifid, entity_type, entity_value, entity_info))..
      " has too many dropped packets [&gt " .. max_drop_perc .. "%]"
end

-- returns the pair (message, severity)
local function formatAlertMessage(ifid, engine, entity_type, entity_value, atype, akey, entity_info, alert_info)
   -- Defaults
   local msg = ""
   local severity = "error"

   if atype == "threshold_cross" then
      msg = formatThresholdCross(ifid, engine, entity_type, entity_value, entity_info, akey, alert_info)
   elseif atype == "tcp_syn_flood" then
      msg = formatSynFlood(ifid, engine, entity_type, entity_value, entity_info, akey, alert_info)
   elseif atype == "flows_flood" then
      msg = formatFlowsFlood(ifid, engine, entity_type, entity_value, entity_info, akey, alert_info)
   elseif atype == "misconfigured_app" then
      msg = formatMisconfiguredApp(ifid, engine, entity_type, entity_value, entity_info, akey, alert_info)
   elseif atype == "too_many_drops" then
      msg = formatTooManyPacketDrops(ifid, engine, entity_type, entity_value, entity_info, akey, alert_info)
   end

   return msg, severity
end

local function engageReleaseAlert(engaged, ifid, engine, entity_type, entity_value, atype, alert_key, entity_info, alert_info, force)
   local alert_msg, aseverity = formatAlertMessage(ifid, engine, entity_type, entity_value, atype, alert_key, entity_info, alert_info)
   local alert_type = alertType(atype)
   local alert_severity = alertSeverity(aseverity)

   if engaged then
      return interface.engageAlert(engine, alertEntity(entity_type), entity_value, alert_key, alert_type, alert_severity, alert_msg, force)
   else
      return interface.releaseAlert(engine, alertEntity(entity_type), entity_value, alert_key, alert_type, alert_severity, alert_msg, force)
   end
end

local function engageAlert(ifid, engine, entity_type, entity_value, atype, akey, entity_info, alert_info, force)
   if(verbose) then io.write("Engage Alert: "..entity_value.." "..atype.." "..akey.."\n") end

   engageReleaseAlert(true, ifid, engine, entity_type, entity_value, atype, akey, entity_info, alert_info, force)
end

local function releaseAlert(ifid, engine, entity_type, entity_value, atype, akey, entity_info, alert_info, force)
   if(verbose) then io.write("Release Alert: "..entity_value.." "..atype.." "..akey.."\n") end

   engageReleaseAlert(false, ifid, engine, entity_type, entity_value, atype, akey, entity_info, alert_info, force)
end

local function getEngagedAlertsCache(ifid, granularity)
   local engaged_cache = ntop.getCache(getEngagedAlertsCacheKey(ifid, granularity))

   if isEmptyString(engaged_cache) then
      engaged_cache = {}
      local sql_res = performAlertsQuery("select *", "engaged", {alert_engine = alertEngine(granularity)}) or {}

      if verbose then
	 io.write("Resync alert cache:\n")
	 tprint(sql_res)
      end

      for _, res in pairs(sql_res) do
	 local entity_type = alertEntityRaw(res.alert_entity)
	 local entity_value = res.alert_entity_val
	 local atype = alertTypeRaw(res.alert_type)
	 local akey = res.alert_id

	 engaged_cache[entity_type] = engaged_cache[entity_type] or {}
	 engaged_cache[entity_type][entity_value] = engaged_cache[entity_type][entity_value] or {}
	 engaged_cache[entity_type][entity_value][akey] = engaged_cache[entity_type][entity_value][akey] or {}
	 engaged_cache[entity_type][entity_value][atype] = engaged_cache[entity_type][entity_value][atype] or {}
	 engaged_cache[entity_type][entity_value][atype][akey] = true
      end

      if ntop.getPref("ntopng.prefs.disable_alerts_generation") ~= "1" then
	 ntop.setCache(getEngagedAlertsCacheKey(ifid, granularity), j.encode(engaged_cache))
      end
   else
      engaged_cache = j.decode(engaged_cache, 1, nil)
   end

   return engaged_cache
end

function invalidateEngagedAlertsCache(ifid)
   local keys = ntop.getKeysCache(getEngagedAlertsCacheKey(ifid, "*")) or {}

   for key in pairs(keys) do
      ntop.delCache(key)
   end

   if(verbose) then io.write("Engaged Alerts Cache invalidated\n") end
end

-- #################################

local function check_entity_alerts(ifid, entity_type, entity_value, working_status, old_entity_info, entity_info)
   if are_alerts_suppressed(entity_value, ifid) then return end

   local engine = working_status.engine
   local granularity = working_status.granularity
   local engaged_cache = working_status.engaged_cache
   local current_alerts = {}
   local past_alert_info = {}
   local invalidate = false

   local function addAlertInfo(info_arr, atype, akey, alert_info)
      info_arr[atype] = info_arr[atype] or {}
      info_arr[atype][akey] = alert_info or {}
   end

   local function getAnomalyType(anomal_name)
      if starts(anomal_name, "syn_flood") then
	 return "tcp_syn_flood"
      elseif starts(anomal_name, "flows_flood") then
	 return "flows_flood"
      elseif anomal_name == "too_many_drops" then
	 return "too_many_drops"
      elseif starts(anomal_name, "too_many_") then
	 return "misconfigured_app"
      end

      return nil
   end

   if granularity == "min" then
      -- Populate current_alerts with anomalies
      for anomal_name, anomaly in pairs(entity_info.anomalies or {}) do
	 local anomal_type = getAnomalyType(anomal_name)

	 if not isEmptyString(anomal_type) then
	    addAlertInfo(current_alerts, anomal_type, anomal_name, anomaly)
	 else
	    -- default anomaly - empty alert key
	    addAlertInfo(current_alerts, anomal_name, "", anomaly)
	 end
      end
   end

   -- Populate current_alerts with threshold crosses
   for _, threshold in pairs(getEntityThresholds(working_status.configured_thresholds, entity_type, entity_value)) do
      local atype = "threshold_cross"
      local akey = threshold.key
      local exceeded, alert_info = entity_threshold_crossed(granularity, old_entity_info, entity_info, threshold)

      if exceeded then
	 addAlertInfo(current_alerts, atype, akey, alert_info)
      else
	 -- save past alert information
	 addAlertInfo(past_alert_info, atype, akey, alert_info)
      end
   end

   -- Engage logic
   for atype, akeys in pairs(current_alerts) do
      for akey, alert_info in pairs(akeys) do
	 if ((engaged_cache[entity_type] == nil)
	       or (engaged_cache[entity_type][entity_value] == nil)
	       or (engaged_cache[entity_type][entity_value][atype] == nil)
	    or (engaged_cache[entity_type][entity_value][atype][akey] == nil)) then
	    engageAlert(ifid, engine, entity_type, entity_value, atype, akey, entity_info, alert_info)
	    working_status.dirty_cache = true
	 end
      end
   end

   -- Release logic
   if (engaged_cache[entity_type] ~= nil) and (engaged_cache[entity_type][entity_value] ~= nil) then
      for atype, akeys in pairs(engaged_cache[entity_type][entity_value]) do
	 for akey, _ in pairs(akeys) do
	    -- mark the alert as processed
	    engaged_cache[entity_type][entity_value][atype][akey] = "processed"

	    if (current_alerts[atype] == nil) or (current_alerts[atype][akey] == nil) then
	       local alert_info

	       if (past_alert_info[atype] ~= nil) and (past_alert_info[atype][akey] ~= nil) then
		  alert_info = past_alert_info[atype][akey]
	       else
		  alert_info = {}
	       end

	       releaseAlert(ifid, engine, entity_type, entity_value, atype, akey, entity_info, alert_info)
	       working_status.dirty_cache = true
	    end
	 end
      end
   end
end

-- #################################

function check_interface_alerts(ifid, working_status)
   local ifstats = interface.getStats()
   local entity_value = "iface_"..ifid

   -- note: always checkpoint as the interface could have anomalies

   local checkpoints = interface.checkpointInterface(ifid, working_status.checkpoint_id, "high") or {}
   local old_entity_info = checkpoints["previous"] and j.decode(checkpoints["previous"])
   local new_entity_info = checkpoints["current"] and j.decode(checkpoints["current"])

   -- attach anomalies to the new entity info (no need to attach them to the old)
   if new_entity_info ~= nil then
      new_entity_info["anomalies"] = ifstats["anomalies"] or {}
   end

   if new_entity_info == nil then
      if warning_shown == false then
         print("["..__FILE__().."]:["..__LINE__().."] Unexpected new_entity_info == nil")
         tprint({
	       old_entity_info = old_entity_info,
	       granularity = working_status.granularity,
	       entity_value = entity_value,
	       ifname=getInterfaceName(ifid)})
      end
      return
   end

   if (old_entity_info ~= nil) and (old_entity_info.stats ~= nil)
      and (old_entity_info.stats.bytes ~= nil)
   and not checkpointExpired(old_entity_info, working_status) then
      -- wrap check
      if old_entity_info.stats.bytes > ifstats.stats.bytes then
         -- reset
         if(verbose) then print("entity '"..entity_value.."' stats reset("..working_status.granularity..")") end
         old_entity_info = nil
      end
   else
      -- reset
      old_entity_info = nil
   end

   check_entity_alerts(ifid, "interface", entity_value, working_status, old_entity_info, new_entity_info)
end

function check_networks_alerts(ifid, working_status)
   local subnet_stats = interface.getNetworksStats()
   local warning_shown = false

   for subnet, sstats in pairs(subnet_stats) do
      local entity_value = subnet

      if (working_status.configured_thresholds[subnet] == nil)
      and (working_status.configured_thresholds["local_networks"] == nil) then
         -- no threshold configured, no need to checkpoint
         goto continue
      end

      local checkpoints = interface.checkpointNetwork(ifid, tonumber(sstats.network_id), working_status.checkpoint_id, "high") or {}

      local old_entity_info = checkpoints["previous"] and j.decode(checkpoints["previous"])
      local new_entity_info = checkpoints["current"] and j.decode(checkpoints["current"])

      if new_entity_info == nil then
         if warning_shown == false then
            print("["..__FILE__().."]:["..__LINE__().."] Unexpected new_entity_info == nil")
            tprint({
		  old_entity_info = old_entity_info,
		  granularity = working_status.granularity,
		  entity_value = entity_value, network_id = network_id,
		  ifname=getInterfaceName(ifid)})
            warning_shown = true
         end
         goto continue
      end

      new_entity_info["network_id"] = sstats.network_id

      if (old_entity_info ~= nil) and (old_entity_info.ingress ~= nil)
      and not checkpointExpired(old_entity_info, working_status) then
         old_entity_info["network_id"] = sstats.network_id

         -- wrap check
         if (old_entity_info["egress"] > new_entity_info["egress"])
	    or (old_entity_info["ingress"] > new_entity_info["ingress"])
	 or (old_entity_info["inner"] > new_entity_info["inner"]) then
            -- reset
            if(verbose) then print("entity '"..subnet.."' stats reset("..working_status.granularity..")") end
            old_entity_info = nil
         end
      else
         -- reset
         old_entity_info = nil
      end

      check_entity_alerts(ifid, "network", subnet, working_status, old_entity_info, new_entity_info)
      ::continue::
   end
end

function check_host_alerts(ifid, working_status, host)
   local entity_value = hostinfo2hostkey(hostkey2hostinfo(host), nil, true --[[force vlan]])
   local old_entity_info, new_entity_info

   if (working_status.configured_thresholds[entity_value] ~= nil)
   or (working_status.configured_thresholds["local_hosts"] ~= nil) then

      local checkpoints = interface.checkpointHost(ifid, entity_value, working_status.checkpoint_id, "high") or {}

      old_entity_info = checkpoints["previous"] and j.decode(checkpoints["previous"])
      new_entity_info = checkpoints["current"] and j.decode(checkpoints["current"])
   else
      -- no threshold configured, no need to checkpoint
      new_entity_info = {}
   end

   -- attach anomalies to the new entity info (no need to attach them to the old)
   if new_entity_info ~= nil then
      local host_stats = interface.getHostInfo(host) or {}
      new_entity_info["anomalies"] = host_stats["anomalies"] or {}
   end

   if (new_entity_info == nil) then
      print("["..__FILE__().."]:["..__LINE__().."] Unexpected new_entity_info == nil")
      tprint({new_entity_info = new_entity_info,
	      old_entity_info = old_entity_info,
	      granularity = working_status.granularity,
	      entity_value = entity_value, host = host,
	      ifname=getInterfaceName(ifid)})
      return
   end

   if (old_entity_info ~= nil) and checkpointExpired(old_entity_info, working_status) then
      -- reset
      old_entity_info = nil
   end

   check_entity_alerts(ifid, "host", entity_value, working_status, old_entity_info, new_entity_info)
end

function check_hosts_alerts(ifid, working_status)
   local hosts_iterator = callback_utils.getLocalHostsIterator(false --[[no details]])

   for host, _ in hosts_iterator do
      check_host_alerts(ifid, working_status, host)
   end
end

-- #################################

function newAlertsWorkingStatus(ifstats, granularity)
   local res = {
      granularity = granularity,
      engine = alertEngine(granularity),
      checkpoint_id = checkpointId(granularity),
      ifid = ifstats.id,
      engaged_cache = getEngagedAlertsCache(ifstats.id, granularity),
      configured_thresholds = getConfiguredAlertsThresholds(ifstats.name, granularity),
      dirty_cache = false,
      now = os.time(),
      interval = granularity2sec(granularity),
   }
   return res
end

function finalizeAlertsWorkingStatus(working_status)
   -- Process the remaining alerts to release, e.g. related to expired hosts
   for entity_type, entity_values in pairs(working_status.engaged_cache) do
      for entity_value, alert_types in pairs(entity_values) do
         for atype, alert_keys in pairs(alert_types) do
            for akey, status in pairs(alert_keys) do
               if status ~= "processed" then
                  releaseAlert(working_status.ifid, working_status.engine, entity_type, entity_value, atype, akey, {}, {})
                  working_status.dirty_cache = true
               end
            end
         end
      end
   end

   if working_status.dirty_cache then
      invalidateEngagedAlertsCache(working_status.ifid)
   end
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

local function getMacUrl(mac)
   return ntop.getHttpPrefix() .. "/lua/mac_details.lua?host=" .. mac
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
         interface.storeAlert(alertEntity("mac"), elems.new_mac, alertType("mac_ip_association_change"), alertSeverity("warning"),
                  i18n("alert_messages.mac_ip_association_change",
                  {device=name, ip=elems.ip,
                  old_mac=elems.old_mac, old_mac_url=getMacUrl(elems.old_mac),
                  new_mac=elems.new_mac, new_mac_url=getMacUrl(elems.new_mac)}))
      end
   end   
end


-- Global function
function check_nfq_flushed_queue_alerts()
   while(true) do
      local message = ntop.lpopCache("ntopng.alert_nfq_flushed_queue")
      local elems

      if((message == nil) or (message == "")) then
	 break
      end

      elems = json.decode(message)

      if elems ~= nil then
	 local entity = alertEntity("interface")
	 local entity_value = "iface_"..elems.ifid
	 local alert_type = alertType("nfq_flushed")
	 local alert_severity = alertSeverity("info")

	 -- tprint(elems)
         -- io.write(elems.ip.." ==> "..message.."[".. elems.ifname .."]\n")

         interface.select(elems.ifname)
         interface.storeAlert(entity, entity_value, alert_type, alert_severity,
                  i18n("alert_messages.nfq_flushed",
		       {name = elems.ifname, pct = elems.pct,
			tot = elems.tot, dropped = elems.dropped,
			url = ntop.getHttpPrefix().."/lua/if_stats.lua?ifid="..elems.ifid}))
      end
   end   
end

-- Global function
function check_process_alerts()
   while(true) do
      local message = ntop.lpopCache(alert_process_queue)
      local elems
      -- FIX: In the future we must create a special "ntopng/localhost" interface
      local if_id, if_name = getFirstInterfaceId()
      
      if((message == nil) or (message == "")) then
	 break
      end

      if(verbose) then print(message.."\n") end
      
      local decoded = json.decode(message)

      if(decoded == nil) then
	 if(verbose) then io.write("JSON Decoding error: "..message.."\n") end
      else 
	 interface.select(if_name)
	 interface.storeAlert(decoded.entity_type,
			      decoded.entity_value,
			      decoded.type,
			      decoded.severity,
			      decoded.message,
			      decoded.when)
      end
   end
end

local function check_macs_alerts(ifid, working_status)
   if working_status.granularity ~= "min" then
      return
   end

   local active_devices_set = getActiveDevicesHashKey(ifid)
   local seen_devices_hash = getFirstSeenDevicesHashKey(ifid)
   local seen_devices = ntop.getHashAllCache(seen_devices_hash) or {}
   local prev_active_devices = swapKeysValues(ntop.getMembersCache(active_devices_set) or {})
   local alert_new_devices_enabled = ntop.getPref("ntopng.prefs.alerts.device_first_seen_alert") == "1"
   local alert_device_connection_enabled = ntop.getPref("ntopng.prefs.alerts.device_connection_alert") == "1"
   local new_active_devices = {}

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
					    interface.storeAlert(alertEntity("mac"), mac, alertType("new_device"), alertSeverity("warning"),
								 i18n("alert_messages.a_new_device_has_connected", {device=name, url=getMacUrl(mac)}))
					 end
				      end

				      if not prev_active_devices[mac] then
					 -- Device connection
					 ntop.setMembersCache(active_devices_set, mac)

					 if alert_device_connection_enabled then
					    local name = getDeviceName(mac)
					    setSavedDeviceName(mac, name)
					    interface.storeAlert(alertEntity("mac"), mac, alertType("device_connection"), alertSeverity("info"),
								 i18n("alert_messages.device_has_connected", {device=name, url=getMacUrl(mac)}))
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
            interface.storeAlert(alertEntity("mac"), mac, alertType("device_disconnection"), alertSeverity("info"),
				 i18n("alert_messages.device_has_disconnected", {device=name, url=getMacUrl(mac)}))
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

function check_host_pools_alerts(ifid, working_status)
   if working_status.granularity ~= "min" then
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
	 if pool_stats then
	    local quotas_info = shaper_utils.getQuotasInfo(ifid, pool, pool_stats)

	    for proto, info in pairs(quotas_info) do
	       local prev_exceeded = pool_exceeded_quotas[proto] or {false,false}

	       if alerts_on_quota_exceeded then
		  if info.bytes_exceeded and not prev_exceeded[1] then
		     interface.storeAlert(alertEntity("host_pool"), tostring(pool), alertType("quota_exceeded"), alertSeverity("info"),
					  i18n("alert_messages.subject_quota_exceeded", {
						  pool = host_pools_utils.getPoolName(ifid, pool),
						  url = getHostPoolUrl(pool),
						  subject = i18n("alert_messages.proto_bytes_quotas", {proto=proto}),
						  quota = bytesToSize(info.bytes_quota),
						  value = bytesToSize(info.bytes_value)}))
		  end

		  if info.time_exceeded and not prev_exceeded[2] then
		     interface.storeAlert(alertEntity("host_pool"), alertType("quota_exceeded"), alertSeverity("info"),
					  i18n("alert_messages.subject_quota_exceeded", {
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
		  interface.storeAlert(alertEntity("host_pool"), tostring(pool),
				       alertType("host_pool_connection"), alertSeverity("info"),
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
            interface.storeAlert(alertEntity("host_pool"), tostring(pool),
				 alertType("host_pool_disconnection"), alertSeverity("info"),
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

   local working_status = newAlertsWorkingStatus(ifstats, granularity)

   check_interface_alerts(ifid, working_status)
   check_networks_alerts(ifid, working_status)
   check_hosts_alerts(ifid, working_status)
   check_macs_alerts(ifid, working_status)
   check_host_pools_alerts(ifid, working_status)

   finalizeAlertsWorkingStatus(working_status)
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
   os.execute("sleep 3")

   local selected_interface = ifname
   local ifnames = interface.getIfNames()

   -- Release any engaged alert
   callback_utils.foreachInterface(ifnames, nil, function(ifname, ifstats)
				      if(verbose) then io.write("[Alerts] Processing interface "..ifname.."...\n") end

				      local sql_res = performAlertsQuery("select *", "engaged", {}, true  --[[force]]) or {}

				      for _, res in pairs(sql_res) do
					 local entity_type = alertEntityRaw(res.alert_entity)
					 local entity_value = res.alert_entity_val
					 local atype = alertTypeRaw(res.alert_type)
					 local akey = res.alert_id
					 local engine = tonumber(res.alert_engine)

					 releaseAlert(ifstats.id, engine, entity_type, entity_value, atype, akey, {}, {}, true --[[force]])
				      end
   end)

   deleteCachePattern(getEngagedAlertsCacheKey("*", "*"))

   if(verbose) then io.write("[Alerts] Disable done\n") end
   interface.select(selected_interface)
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
   os.execute("sleep 3")

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
   deleteCachePattern(getEngagedAlertsCacheKey("*", "*"))
   deleteCachePattern(getGlobalAlertsConfigurationHash("*", "*", "*"))
   ntop.delCache(get_alerts_suppressed_hash_name("*"))
   for _, key in pairs(get_make_room_keys("*")) do deleteCachePattern(key) end

   if(verbose) then io.write("[Alerts] Enabling alerts generation...\n") end
   ntop.setAlertsTemporaryDisabled(false);

   callback_utils.foreachInterface(ifnames, nil, function(_ifname, ifstats)
				      -- Reload hosts status
				      interface.refreshHostsAlertsConfiguration(true --[[ with counters ]])
   end)

   ntop.setPref("ntopng.prefs.disable_alerts_generation", generation_toggle_backup)

   if(verbose) then io.write("[Alerts] Flush done\n") end
   interface.select(selected_interface)
end

-- #################################

function alertNotificationActionToLabel(action)
   local label = ""

   if action == "engage" then
      label = "Alert Engaged: "
   elseif action == "release" then
      label = "Alert Released: "
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

-- NOTE: order is important as it defines evaluation order
local ALERT_NOTIFICATION_MODULES = {
   "custom", "nagios", "slack"
}

if ntop.sendMail then -- only if email support is available
   table.insert(ALERT_NOTIFICATION_MODULES, 1, "email")
end

function getAlertNotificationModuleEnableKey(module_name, short)
   local short_k = "alerts." .. module_name .. "_notifications_enabled"

   if short then
      return short_k
   else
      return "ntopng.prefs." .. short_k
   end
end

function getAlertNotificationModuleSeverityKey(module_name, short)
   local short_k = "alerts." .. module_name .. "_severity"

   if short then
      return short_k
   else
      return "ntopng.prefs." .. short_k
   end
end

local function getEnabledAlertNotificationModules()
   local notifications_enabled = ntop.getPref("ntopng.prefs.alerts.external_notifications_enabled")

   if not notifications_enabled or hasAlertsDisabled() then
      return {}
   end

   local enabled_modules = {}

   for _, modname in ipairs(ALERT_NOTIFICATION_MODULES) do
      local module_enabled = ntop.getPref(getAlertNotificationModuleEnableKey(modname))
      local min_severity = ntop.getPref(getAlertNotificationModuleSeverityKey(modname))
      local req_name = modname

      if module_enabled == "1" then
         local ok, _module = pcall(require, req_name)

         if not ok then
            traceError(TRACE_ERROR, TRACE_CONSOLE, "Error while importing alert notification module " .. req_name)

            -- the traceback
            io.write(_module)
         else
	    if isEmptyString(min_severity) then
	       min_severity = _module.DEFAULT_SEVERITY or "warning"
	    end

            enabled_modules[#enabled_modules + 1] = {
               name = modname,
               severity = min_severity,
               export_frequency = tonumber(_module.EXPORT_FREQUENCY) or 60,
               export_queue = "ntopng.alerts.modules_notifications_queue." .. modname,
               ["module"] = _module,
            }
         end
      end
   end

   return enabled_modules
end

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
      notification.message = formatRawFlow(notification.flow, notification.message)
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

   local msg_prefix = alertNotificationActionToLabel(notif.action)
   local msg = "[" .. formatEpoch(notif.tstamp or 0) .. "]" ..
      ternary(defaults.show_severity == true, "", "[" .. alertSeverityLabel(alertSeverity(notif.severity), options.nohtml) .. "]") ..
      "[" .. alertTypeLabel(alertType(notif.type), options.nohtml) .."]: "

   if options.nohtml then
      msg = msg .. noHtml(msg_prefix .. notif.message)
   else
      msg = msg .. msg_prefix .. notif.message
   end

   return msg
end

-- NOTE: this is executed in a system VM, with no interfaces references
function processAlertNotifications(now, periodic_frequency, force_export)
   local modules = getEnabledAlertNotificationModules()

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

      -- dispatch
      for _, m in ipairs(modules) do
         if message.severity >= alertSeverity(m.severity) then
	    ntop.rpushCache(m.export_queue, json_message, MAX_NUM_PER_MODULE_QUEUED_ALERTS)
         end
      end
   end

   -- Process export notifications
   for _, m in ipairs(modules) do
      if force_export or ((now % m.export_frequency) < periodic_frequency) then
         local rv = m.module.dequeueAlerts(m.export_queue)

         if not rv.success then
            local msg = rv.error_message or "Unknown Error"

            -- TODO: generate alert
            traceError(TRACE_ERROR, TRACE_CONSOLE, "Error while sending notifications via " .. m.name .. " module: " .. msg)
         end
      end
   end
end

local function notify_ntopng_status(started)
   local info = ntop.getInfo()
   local severity = alertSeverity("info")
   local msg
   local msg_details = string.format("%s v.%s (%s) [pid: %s][options: %s]", info.product, info.version, info.OS, info.pid, info.command_line)
   
   if(started)
   then
      -- let's check if we are restarting from an anomalous termination
      -- e.g., from a crash
      if not recovery_utils.check_clean_shutdown() then
	 -- anomalous termination
	 msg = string.format("%s %s", i18n("alert_messages.ntopng_anomalous_termination", {url="https://www.ntop.org/support/need-help-2/need-help/"}), msg_details)
	 severity = alertSeverity("error")
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

function notify_ntopng_start()
   notify_ntopng_status(true)
end

function notify_ntopng_stop()
   notify_ntopng_status(false)
end

-- DEBUG: uncomment this to test
--~ scanAlerts("min", "wlan0")
