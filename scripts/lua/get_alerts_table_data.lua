--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local alert_utils = require "alert_utils"
require "flow_utils"

local format_utils = require "format_utils"
local json = require "dkjson"
local alerts_api = require "alerts_api"
local alert_consts = require "alert_consts"
local recording_utils = require "recording_utils"
local user_scripts = require "user_scripts"
local alert_exclusions = require "alert_exclusions"

sendHTTPHeader('application/json')

local status          = _GET["status"]

local engaged = false
if status == "engaged" then
   engaged = true
end

-- ifid is mandatory here
interface.select(_GET["ifid"])

local ifid = interface.getId()

local function getExplorerLink(origin, target, timestamp)
   local url = ntop.getHttpPrefix() .. "/lua/pro/enterprise/flow_alerts_explorer.lua?"
   if origin ~= nil and origin ~= "" then
      url = url..'&origin='..origin
   end
   if target ~= nil and target ~= "" then
      url = url..'&target='..target
   end
   if timestamp ~= nil then
      url = url..'&epoch_begin='..(tonumber(timestamp) - 1800)
      url = url..'&epoch_end='..(tonumber(timestamp) + 1800)
   end
   return url
end

--~ function alerts_api.getEntityAlertsDisabled(ifid, entity, entity_val)

if(tonumber(_GET["currentPage"]) == nil) then _GET["currentPage"] = 1 end
if(tonumber(_GET["perPage"]) == nil) then _GET["perPage"] = getDefaultTableSize() end

if(isEmptyString(_GET["sortColumn"]) or (_GET["sortColumn"] == "column_") or
      (status ~= "historical" and _GET["sortColumn"] == "column_sort")) or
      (status ~= "historical-flows" and status ~= "historical" and  _GET["sortColumn"] == "column_count") or
      (status ~= "historical-flows" and  _GET["sortColumn"] == "column_score") then
   if(status ~= "historical-flows" and status ~= "historical" and  _GET["sortColumn"] == "column_count") or
         (status ~= "historical-flows" and  _GET["sortColumn"] == "column_score") then
      tablePreferences("sort_alerts", "column_")
   end
   _GET["sortColumn"] = getDefaultTableSort("alerts")
elseif((_GET["sortColumn"] ~= "column_") and (_GET["sortColumn"] ~= "")) then
   tablePreferences("sort_alerts", _GET["sortColumn"])
end

if _GET["sortOrder"] == nil then
   _GET["sortOrder"] = getDefaultTableSortOrder("alerts")
elseif((_GET["sortColumn"] == "column_") or (_GET["sortOrder"] == "")) then
   _GET["sortOrder"] = "asc"
end
tablePreferences("sort_order_alerts", _GET["sortOrder"])

local alert_options = _GET

if alert_options.entity_val ~= nil then
   alert_options.entity_val = string.gsub(alert_options.entity_val, "http:__", "http://")
   alert_options.entity_val = string.gsub(alert_options.entity_val, "https:__", "https://")
end

local alerts, num_alerts = alert_utils.getAlerts(status, alert_options, true --[[ with_counters ]])

if alerts == nil then alerts = {} end

local res_formatted = {}

for k,v in ipairs(alerts) do
   local record = {}
   local alert_entity
   local alert_entity_val
   local column_duration = ""
   local tdiff = os.time() - v["alert_tstamp"]
   local column_date = os.date("%c", v["alert_tstamp"])
   local alert = v
   local alert_id = v["rowid"]
   
   if v["alert_entity"] ~= nil then
      alert_entity    = tonumber(v["alert_entity"])
   else
      alert_entity = "flow" -- flow alerts page doesn't have an entity
   end

   if v["alert_entity_val"] ~= nil then
      alert_entity_val = v["alert_entity_val"]
   else
      alert_entity_val = ""
   end

   if(tdiff <= 600) then
      column_date  = secondsToTime(tdiff).. " " ..i18n("details.ago")
   else
      column_date = format_utils.formatPastEpochShort(v["alert_tstamp"])
      column_date = column_date:gsub("%s", "<br>")
   end

   if engaged == true then
      column_duration = secondsToTime(os.time() - tonumber(v["alert_tstamp"]))
   elseif tonumber(v["alert_tstamp_end"]) ~= nil
        and (tonumber(v["alert_tstamp_end"]) - tonumber(v["alert_tstamp"])) ~= 0 then
      column_duration = secondsToTime(tonumber(v["alert_tstamp_end"]) - tonumber(v["alert_tstamp"]))
   end

   local column_severity = alert_consts.alertSeverityLabel(tonumber(v["alert_severity"]))
   local column_type     = alert_consts.alertTypeLabel(tonumber(v["alert_type"]))
   local column_type_str = alert_consts.alertTypeLabel(tonumber(v["alert_type"]), true)
   local column_count    = format_utils.formatValue(tonumber(v["alert_counter"]))
   local column_score    = format_utils.formatValue(tonumber(v["score"]))
   local alert_info      = alert_utils.getAlertInfo(v)
   local column_msg      = string.gsub(alert_utils.formatAlertMessage(ifid, v, alert_info), '"', "'")
   local column_chart     = ""
   local column_drilldown = ""
   local column_filter  = ""
   local column_subdir     = ""
   local column_script_key = ""
   local column_ndpi      = ""
   local column_filter_disabled = false

   if v["l7_proto"] and v["l7_master_proto"] then
      local app = create_ndpi_proto_name(v)
      local breed = interface.getnDPIProtoBreed(tonumber(v["l7_proto"]))

      column_ndpi = "<A HREF='".. ntop.getHttpPrefix().."/lua/hosts_stats.lua?protocol=" .. v["l7_proto"] .."'>"..app.." " .. formatBreed(breed) .."</A>"
   end

   if ntop.isPro() then
      local graph_utils = require "graph_utils"

      if graph_utils.getAlertGraphLink then
	 local chart_link = graph_utils.getAlertGraphLink(getInterfaceId(ifname), v, alert_info, engaged)
	 if not isEmptyString(chart_link) then
      column_drilldown = chart_link
	 end
      end
   end

   if alert_entity == "flow" then
      -- Checking PCAP data availability
      local traffic_extraction_available = recording_utils.isActive(ifid) and recording_utils.isExtractionActive(ifid)
      if traffic_extraction_available then 
         -- Checking PCAP availability in the time window
         local epoch_begin = tonumber(v["first_seen"])
         local epoch_end = tonumber(v["alert_tstamp"])
         local window_info = recording_utils.isDataAvailable(ifid, epoch_begin, epoch_end)
         if window_info.epoch_begin and window_info.epoch_end then
            -- Building BPF filter
            local filter = "host "..v["cli_addr"].." and host "..v["srv_addr"]..
                           " and port "..v["cli_port"].." and port "..v["srv_port"]
            filer = filter.." and ip proto "..v["proto"]
            if not isEmptyString(v["vlan_id"]) then
               filer = filter.." and vlan "..v["vlan_id"]
            end
            
            column_chart = column_chart.." <button class='btn btn-link btn-sm' title='"..i18n("traffic_recording.pcap_download").."' "
              .."onclick='pcapDownload(this); return false;'"
              .." data-filter='"..filter.."' data-epoch-begin='"..window_info.epoch_begin.."' data-epoch-end='"..window_info.epoch_end.."'><i class='fas fa-lg fa-download'></i></button>"
         end
      end
   end

   local column_id = tostring(alert_id)
   if(ntop.isEnterpriseM()) then
      if (status == "historical-flows") then
	 record["column_explorer"] = getExplorerLink(v["cli_addr"], v["srv_addr"], v["alert_tstamp"])
      end
   end

   if status ~= "historical-flows" then
     record["column_entity_formatted"] = alert_consts.formatAlertEntity(ifid, alert_consts.alertEntityRaw(v["alert_entity"]), v["alert_entity_val"])
   end

   record["column_key"] = column_id
   record["column_date"] = column_date
   record["column_duration"] = column_duration
   record["column_severity"] = column_severity
   record["column_severity_id"] = tonumber(v["alert_severity"])
   record["column_subtype"] = v["alert_subtype"]
   record["column_granularity"] = v["alert_granularity"]
   record["column_count"] = column_count
   record["column_score"] = column_score
   record["column_type"] = column_type
   record["column_type_str"] = column_type_str
   record["column_type_id"] = tonumber(v["alert_type"])
   record["column_msg"] = column_msg
   record["column_entity_id"] = alert_entity
   record["column_entity_val"] = alert_entity_val
   record["column_ndpi"] = column_ndpi
   record["column_chart"] = column_chart
   record["column_drilldown"] = column_drilldown   
   
   if alert_info.alert_generation then
      record["column_script_key"] = alert_info.alert_generation.script_key or nil
      record["column_subdir"]     = alert_info.alert_generation.subdir or nil

      -- Checking if the filter column needs to be skipped
      if record["column_subdir"] == "flow" then
	 -- Enabled, show the bell to disable
	 record["column_filter"] = v["cli_addr"].."|"..v["srv_addr"]
      else
	 record["column_filter"] = user_scripts.getFilterPreset(alert, alert_info)
      end
   end

   res_formatted[#res_formatted + 1] = record

end -- for

local result = {}
result["perPage"] = alert_options.perPage
result["currentPage"] = alert_options.currentPage
result["totalRows"] = num_alerts
result["data"] = res_formatted
result["sort"] = {{alert_options.sortColumn, alert_options.sortOrder}}

print(json.encode(result))

