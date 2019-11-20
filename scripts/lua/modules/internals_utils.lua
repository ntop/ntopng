--
-- (C) 2019 - ntop.org
--

local format_utils = require("format_utils")
local internals_utils = {}
local json = require "dkjson"
local dirs = ntop.getDirs()

-- ###########################################

internals_utils.periodic_scripts_durations = {
   -- Script -> max_duration sec
   ["stats_update.lua"] =        5,
   ["ht_state_update.lua"] =     5,
   ["minute.lua"] =             60,
   ["5min.lua"] =              300,
   ["hourly.lua"] =           3600,
   ["daily.lua"] =           86400,
}

-- ###########################################

local function printHashTablesDropdown(base_url, page_params)
   local hash_table = _GET["hash_table"]
   local hash_table_filter
   if not isEmptyString(hash_table) then
      hash_table_filter = '<span class="glyphicon glyphicon-filter"></span>'
   else
      hash_table_filter = ''
   end
   local hash_table_params = table.clone(page_params)
   hash_table_params["hash_table"] = nil

   print[[\
      <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("internals.hash_table")) print[[]] print(hash_table_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu" role="menu" id="flow_dropdown">\]]

   print[[<li><a href="]] print(getPageUrl(base_url, hash_table_params)) print[[">]] print(i18n("internals.all_hash_tables")) print[[</a></li>\]]

   for ht, stats in pairsByKeys(interface.getHashTablesStats(), asc) do
      print[[ <li]] if hash_table == ht then print(' class="active"') end print[[><a href="]] hash_table_params["hash_table"] = ht; print(getPageUrl(base_url, hash_table_params)); print[[">]] print(i18n("hash_table."..ht)) print[[</a></li>\]]
   end
end

-- ###########################################

local function printHashTablesTable(base_url, ifid, ts_creation)
   local page_params = {hash_table = _GET["hash_table"], tab = _GET["tab"], iffilter = ifid}

   print[[
<div id="table-system-interfaces-stats"></div>
<script type='text/javascript'>

$("#table-system-interfaces-stats").datatable({
   title: "]] print(i18n("internals.hash_tables")) print[[",]]

   local preference = tablePreferences("rows_number",_GET["perPage"])
   if preference ~= "" then print ('perPage: '..preference.. ",\n") end

   print[[
   showPagination: true,
   buttons: [ ]]

   -- Ip version selector
   print[['<div class="btn-group pull-right">]]
   printHashTablesDropdown(base_url, page_params)
   print[[</div>']]

   print[[ ],
   url: "]] print(getPageUrl(ntop.getHttpPrefix().."/lua/get_internals_hash_tables_stats.lua", page_params)) print[[",
   columns: [
     {
       field: "column_key",
       hidden: true,
     }, {
       field: "column_ifid",
       hidden: true,
     }, {
       title: "]] print(i18n("interface")) print[[",
       field: "column_name",
       hidden: ]] if ifid then print('true') else print('false') end print[[,
       sortable: true,
       css: {
	 textAlign: 'left',
	 width: '5%',
       }
     }, {
       title: "]] print(i18n("internals.hash_table")) print[[",
       field: "column_hash_table_name",
       sortable: true,
       css: {
	 textAlign: 'left',
	 width: '10%',
       }
     }, {
       title: "]] print(i18n("chart")) print[[",
       field: "column_chart",
       hidden: ]] if not ifid or not ts_creation then print('true') else print('false') end print[[,
       sortable: false,
       css: {
	 textAlign: 'center',
	 width: '1%',
       }
     }, {
       title: "]] print(i18n("internals.state_active")) print[[",
       field: "column_active_entries",
       sortable: true,
       css: {
	 textAlign: 'right',
	 width: '5%',
       }
     }, {
       title: "]] print(i18n("internals.state_idle")) print[[",
       field: "column_idle_entries",
       sortable: true,
       css: {
	 textAlign: 'right',
	 width: '5%',
       }
     }, {
       title: "]] print(i18n("internals.hash_table_utilization")) print[[",
       field: "column_hash_table_utilization",
       sortable: true,
       css: {
	 textAlign: 'center',
	 width: '5%',
       }
     }
   ], tableCallback: function() {
      datatableInitRefreshRows($("#table-system-interfaces-stats"),
			       "column_key", 5000,
			       {"column_active_entries": addCommas,
				"column_idle_entries": addCommas});
   },
});
</script>
 ]]
end

-- ###########################################

local function printPeriodicactivityDropdown(base_url, page_params)
   local periodic_activity = _GET["periodic_script"]
   local periodic_activity_filter
   if not isEmptyString(periodic_activity) then
      periodic_activity_filter = '<span class="glyphicon glyphicon-filter"></span>'
   else
      periodic_activity_filter = ''
   end
   local periodic_activity_params = table.clone(page_params)
   periodic_activity_params["periodic_script"] = nil

   print[[\
      <button class="btn btn-link dropdown-toggle" data-toggle="dropdown">]] print(i18n("internals.periodic_activity")) print[[]] print(periodic_activity_filter) print[[<span class="caret"></span></button>\
      <ul class="dropdown-menu" role="menu" id="flow_dropdown">\]]

   print[[<li><a href="]] print(getPageUrl(base_url, periodic_activity_params)) print[[">]] print(i18n("internals.all_periodic_activities")) print[[</a></li>\]]

   for script, stats in pairsByKeys(interface.getPeriodicActivitiesStats(), asc) do
      print[[ <li]] if periodic_activity == script then print(' class="active"') end print[[><a href="]] periodic_activity_params["periodic_script"] = script; print(getPageUrl(base_url, periodic_activity_params)); print[[">]] print(script) print[[</a></li>\]]
   end
end

-- ###########################################

local function printPeriodicActivitiesTable(base_url, ifid, ts_creation)
   local page_params = {periodic_script = _GET["periodic_script"], tab = _GET["tab"], iffilter = ifid}

   print[[
<div id="table-internals-periodic-activities"></div>
<script type='text/javascript'>

$("#table-internals-periodic-activities").datatable({
   title: "]] print(i18n("internals.periodic_activities")) print[[",]]

   local preference = tablePreferences("rows_number",_GET["perPage"])
   if preference ~= "" then print ('perPage: '..preference.. ",\n") end

   print[[
   showPagination: true,
   buttons: [ ]]

   -- Ip version selector
   print[['<div class="btn-group pull-right">]]
   printPeriodicactivityDropdown(base_url, page_params)
   print[[</div>']]

   print[[ ],
   url: "]] print(getPageUrl(ntop.getHttpPrefix().."/lua/get_internals_periodic_activities_stats.lua", page_params)) print[[",
   columns: [
     {
       field: "column_key",
       hidden: true,
     }, {
       field: "column_ifid",
       hidden: true,
     }, {
       title: "]] print(i18n("interface")) print[[",
       field: "column_name",
       hidden: ]] if ifid then print('true') else print('false') end print[[,
       sortable: true,
       css: {
	 textAlign: 'left',
	 width: '5%',
       }
     }, {
       title: "]] print(i18n("internals.periodic_activity")) print[[",
       field: "column_periodic_activity_name",
       sortable: true,
       css: {
	 textAlign: 'left',
	 width: '5%',
       }
     }, {
       title: "]] print(i18n("chart")) print[[",
       field: "column_chart",
       hidden: ]] if not ifid or not ts_creation then print('true') else print('false') end print[[,
       sortable: false,
       css: {
	 textAlign: 'center',
	 width: '1%',
       }
     }, {
       title: "]] print(i18n("internals.time_usage")) print[[",
       field: "column_time_perc",
       sortable: true,
       css: {
	 textAlign: 'right',
	 width: '10%',
       }
     }, {
       title: "]] print(i18n("internals.last_duration_ms")) print[[",
       field: "column_last_duration",
       sortable: true,
       css: {
	 textAlign: 'right',
	 width: '5%',
       }
     }
   ], tableCallback: function() {
      datatableInitRefreshRows($("#table-internals-periodic-activities"),
			       "column_key", 5000,
			       {
                  "column_last_duration": fmillis,
                  "column_time_perc": function(v) {return(Math.round(v) + "%")},
               });
   },
});
</script>
 ]]
end

-- ###########################################

local function printTab(tab, content, sel_tab)
   if(tab == sel_tab) then print("\t<li class=active>") else print("\t<li>") end
   print("<a href=\""..ntop.getHttpPrefix().."/lua/"..page_name.."?page=alerts&tab="..tab)
   for param, value in pairs(page_params) do
      print("&"..param.."="..value)
   end
   print("\">"..content.."</a></li>\n")
end

-- ###########################################

function internals_utils.printInternals(ifid)
   local tab = _GET["tab"] or "hash_tables"
   local ts_creation = ntop.getPref("ntopng.prefs.ifid_"..(ifid or getSystemInterfaceId())..".interface_rrd_creation") ~= "false"

   print[[
<ul class="nav nav-tabs" role="tablist">
  <li ]] if tab == "hash_tables" then print[[class="active"]] end print[[>
    <a href="?page=internals&tab=hash_tables]] print[[">]] print(i18n("internals.hash_tables")) print[[</a></li>
  <li ]] if tab == "periodic_activities" then print[[class="active"]] end print[[>
    <a href="?page=internals&tab=periodic_activities"]] print[[">]] print(i18n("internals.periodic_activities")) print[[</a>
  </li>
</ul>

<div class="tab-content clearfix">]]
   local base_url = "?page=internals"

   if tab == "hash_tables" then
      printHashTablesTable(base_url.."&tab=hash_tables", ifid, ts_creation)
   elseif tab == "periodic_activities" then
      printPeriodicActivitiesTable(base_url.."&tab=periodic_activities", ifid, ts_creation)
   end
   print[[</div>]]
end

-- ###########################################

function internals_utils.getFillBar(fill_pct, warn_pct, danger_pct)
   local bg

   if fill_pct >= (danger_pct or 90) then
      bg = "progress-bar-danger"
   elseif fill_pct >= (warn_pct or 75) then
      bg = "progress-bar-warning"
   else
      bg = "progress-bar-success"
   end

   local code = [[
<div class="progress">
  <div class="progress-bar ]]..bg..[[" role="progressbar" style="width: ]]..fill_pct..[[%;" aria-valuenow="]]..fill_pct..[[" aria-valuemin="0" aria-valuemax="100">]]..fill_pct..[[%</div>
</div>
]]

   return code
end

-- ###########################################

function internals_utils.getDoubleFillBar(first_fill_pct, second_fill_pct, third_fill_pct)
   local code = [[<div class="progress">]]

   if first_fill_pct > 0 then
      code = code..[[<div class="progress-bar" role="progressbar" title="]] ..i18n("if_stats_overview.active").. [[" style="width: ]]..first_fill_pct..[[%" aria-valuenow="]]..first_fill_pct..[[" aria-valuemin="0" aria-valuemax="100">]]..i18n("if_stats_overview.active")..[[</div>]]
   end

   if second_fill_pct > 0 then
      code = code..[[<div class="progress-bar progress-bar-info" role="progressbar" title="]] ..i18n("flow_callbacks.idle").. [[" style="width: ]]..second_fill_pct..[[%" aria-valuenow="]]..second_fill_pct..[[" aria-valuemin="0" aria-valuemax="100">]]..i18n("flow_callbacks.idle")..[[</div>]]
   end

   if third_fill_pct > 0 then
      code = code..[[<div class="progress-bar progress-bar-success" role="progressbar" title="]] ..i18n("free").. [[" style="width: ]]..third_fill_pct..[[%" aria-valuenow="]]..second_fill_pct..[[" aria-valuemin="0" aria-valuemax="100">]]..i18n("free")..[[</div>]]
   end

   code = code..[[</div>]]

   return code
end


-- ###########################################

return internals_utils
