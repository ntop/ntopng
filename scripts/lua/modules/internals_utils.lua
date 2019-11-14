--
-- (C) 2019 - ntop.org
--

local format_utils = require("format_utils")
local internals_utils = {}
local json = require "dkjson"
local dirs = ntop.getDirs()

-- ###########################################

function internals_utils.printHashTablesDropdown(base_url, page_params)
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

function internals_utils.printHashTablesTable(base_url)
   local page_params = {hash_table = _GET["hash_table"]}

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
   internals_utils.printHashTablesDropdown(base_url, page_params)
   print[[</div>']]

   print[[ ],
   url: "]] print(getPageUrl(ntop.getHttpPrefix().."/lua/get_internals_hash_tables_stats.lua?iffilter=all", page_params)) print[[",
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

return internals_utils
