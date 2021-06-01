--
-- (C) 2021 - ntop.org
--

local format_utils = require("format_utils")
local custom_column_utils = {}

local dirs = ntop.getDirs()

local custom_column_pref_key = "ntopng.prefs.custom_column"

-- IMPORTANT: keep it in sync with sortField (ntop_typedefs.h)
--            AND host_search_walker:NetworkInterface.cpp
--            AND NetworkInterface::getFlows()
custom_column_utils.available_custom_columns = {
   -- KEY  LABEL   Host::lua()_label  formatting  additonal_url  hidden
   { "mac", i18n("mac_address"), "mac", get_symbolic_mac --[[ Don't touch it, already formatted --]], "left" },
   { "traffic_sent", i18n("flows_page.total_bytes_sent"), "bytes.sent", bytesToSize, "right" },
   { "traffic_rcvd", i18n("flows_page.total_bytes_rcvd"), "bytes.rcvd", bytesToSize, "right" },
   { "traffic_unknown", i18n("flows_page.total_bytes_unknown"), "bytes.ndpi.unknown", bytesToSize, "right" },
   { "num_flows_as_client", i18n("flows_page.flows_as_client"), "active_flows.as_client", format_utils.formatValue, "center", {page = "flows"} },
   { "num_flows_as_server", i18n("flows_page.flows_as_server"), "active_flows.as_server", format_utils.formatValue, "center", {page = "flows"} },
   { "total_num_alerted_flows_as_client", i18n("total_outgoing_alerted_flows"), "alerted_flows.as_client", format_utils.formatValue, "center" },
   { "total_num_alerted_flows_as_server", i18n("total_incoming_alerted_flows"), "alerted_flows.as_server", format_utils.formatValue, "center" },
   { "total_num_unreachable_flows_as_client", i18n("total_outgoing_unreachable_flows"), "unreachable_flows.as_client", format_utils.formatValue, "center" },
   { "total_num_unreachable_flows_as_server", i18n("total_incoming_unreachable_flows"), "unreachable_flows.as_server", format_utils.formatValue, "center" },
   { "total_num_retx_sent", i18n("total_retransmissions_sent"), function(host_stats) return host_stats["tcpPacketStats.sent"]["retransmissions"] end, format_utils.formatValue, "center" },
   { "total_num_retx_rcvd", i18n("total_retransmissions_rcvd"), function(host_stats) return host_stats["tcpPacketStats.rcvd"]["retransmissions"] end, format_utils.formatValue, "center" },
   { "alerts", i18n("show_alerts.engaged_alerts"), "num_alerts", format_utils.formatValue, "center", {page = "alerts"} },
   { "total_alerts", i18n("alerts_dashboard.total_alerts"), "total_alerts", format_utils.formatValue, "center" },
   { "score", i18n("score"), "score", format_utils.formatValue, "center", nil, (not isScoreEnabled()) },
   { "score_as_client", i18n("score_as_client"), "score.as_client", format_utils.formatValue, "center", nil, (not isScoreEnabled()) },
   { "score_as_server", i18n("score_as_server"), "score.as_server", format_utils.formatValue, "center", nil, (not isScoreEnabled()) },
}
local available_custom_columns = custom_column_utils.available_custom_columns

-- ###########################################

-- @brief Getter for host_stats values
--        Need this getter as there are certain host keys which contain dots, so
--        lua is unhappy and doesn't allow us to use the dot-notation to access table keys.
--        For example host_stats["tcpPacketStats.sent"]["retransmissions"] has "tcpPacketStats.sent" which
--        contains a dot so we are unable to use the notation host_stats.tcpPacketStats.sent.retransmissions as
--        done for other keys. To access these keys, we need to use the [] notation inside a `key` function.
local function host_stats_getter(host_stats, key)
   if type(key) == "string" then
      return host_stats[key]
   elseif type(key) == "function" then
      return  key(host_stats)
   end
end

-- ###########################################

function custom_column_utils.hostStatsToColumnValue(host_stats, column, formatted)
   for _, c in ipairs(available_custom_columns) do
      if c[1] == column then
	 local val = nil

	 if formatted then
	    val = host_stats_getter(host_stats, c[3])

	    if not tonumber(val) or val > 0 then
	       val = c[4](val)
	    else
	       val = ""
	    end

	    if((c[6] ~= nil) and (tonumber(val) ~= 0)) then
	       val = hostinfo2detailshref(host_stats, c[6], val)
	   end
	 else
	    val = host_stats_getter(host_stats, c[3])
	 end

         return(val)
      end
   end
end

-- ###########################################

function custom_column_utils.label2criteriakey(what)
   what = what:gsub("^column_", "")
   local id

   for id, _ in ipairs(available_custom_columns) do
      local c        = available_custom_columns[id][1]
      local fnctn    = available_custom_columns[id][4]

      if(what == c) then
	 return what, fnctn
      end
   end

   return what, format_utils.formatValue
end

-- ###########################################

function custom_column_utils.getCustomColumnName()
   local cc = ntop.getPref(custom_column_pref_key)

   local res = ""

   for _, lg in ipairs(custom_column_utils.available_custom_columns) do
      local key   = lg[1]
      local label = lg[2]
      local align = lg[5]

      if cc == key then
	 return label, key, align
      end
   end

   return custom_column_utils.available_custom_columns[1][2], custom_column_utils.available_custom_columns[1][1], custom_column_utils.available_custom_columns[1][5]
end

-- ###########################################

local function setCustomColumnName(custom_column_name)
   local res

   for _, lg in ipairs(custom_column_utils.available_custom_columns) do
      local key   = lg[1]
      local label = lg[2]

      if custom_column_name == key then
	 ntop.setPref(custom_column_pref_key, custom_column_name)
	 return true
      end
   end

   return false
end

-- ###########################################

function custom_column_utils.updateCustomColumn()
   local _, current_column = custom_column_utils.getCustomColumnName()

   if not isEmptyString(_GET["custom_column"]) and (_GET["custom_column"] ~= current_column) then
      if setCustomColumnName(_GET["custom_column"]) then
	 local custom_column_key, custom_column_format = custom_column_utils.label2criteriakey(_GET["custom_column"])

	 tablePreferences("sort_hosts", "column_"..custom_column_key)
	 tablePreferences("sort_order_hosts", "desc")
      end
   end
end

-- ###########################################

function custom_column_utils.isCustomColumn(column)
   local c = column:gsub("^column_", "")

   for _, lg in ipairs(custom_column_utils.available_custom_columns) do
      if c == lg[1] then
	 return true
      end
   end

   return false
end

-- ###########################################

function custom_column_utils.printCustomColumnDropdown(base_url, page_params)
   local custom_column = custom_column_utils.getCustomColumnName()

   -- table.clone needed to modify some parameters while keeping the original unchanged
   local custom_column_params = table.clone(page_params)
   custom_column_params["custom_column"] = nil

   print[[\
      <button class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown"><i class="fas fa-columns" aria-hidden="true"></i><span class="caret"></span></button>\
      <ul class="dropdown-menu scrollable-dropdown" role="menu" id="custom_column_dropdown">]]

   for _, lg in ipairs(custom_column_utils.available_custom_columns) do
      local key = lg[1]
      local label = lg[2]
      local hidden = lg[7]

      if hidden then
	 goto continue
      end

      print[[<li><a class="dropdown-item ]] print(custom_column == label and 'active' or '') print[[" href="]] custom_column_params["custom_column"] = key; print(getPageUrl(base_url, custom_column_params)); print[[">]] print(label) print[[</a></li>]]

      ::continue::
   end

   print[[</ul>]]
end

-- ###########################################

return custom_column_utils
