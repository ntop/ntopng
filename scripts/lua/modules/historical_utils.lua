require "lua_utils"

function historicalTopTalkersTable(ifid, epoch_begin, epoch_end, host)
   local top_talkers_url_params=""
   top_talkers_url_params = top_talkers_url_params.."&epoch_start="..epoch_begin
   top_talkers_url_params = top_talkers_url_params.."&epoch_end="..epoch_end
   if host and host ~= "" then
      top_talkers_url_params = top_talkers_url_params.."&peer1="..host
   end
   local preference = tablePreferences("rows_number",_GET["perPage"])
   local sort_order = getDefaultTableSortOrder("historical_stats_top_talkers")
   local sort_column= getDefaultTableSort("historical_stats_top_talkers")
   if not sort_column or sort_column == "column_" then sort_column = "column_bytes" end
   print[[
<div id="historical-top-talkers-table">

</div>


<script type="text/javascript">

$('a[href="#historical-top-talkers"]').on('shown.bs.tab', function (e) {
  var target = $(e.target).attr("href"); // activated tab
  $('#historical-top-talkers-table').datatable({
      title: "",]]
      print("url: '"..ntop.getHttpPrefix().."/lua/get_historical_data.lua?stats_type=top_talkers"..top_talkers_url_params.."',")
if preference ~= "" then print ('perPage: '..preference.. ",\n") end
-- Automatic default sorted. NB: the column must be exists.
print ('sort: [ ["'..sort_column..'","'..sort_order..'"] ],\n')
      print [[
      showFilter: true,
      showPagination: true,
      columns:
	[
	  {title: "Address", field: "column_addr", hidden: true},
	  {title: "Host Name", field: "column_label", sortable: true},
	  {title: "Traffic Volume", field: "column_bytes", sortable: true},
	  {title: "Packets", field: "column_packets", sortable: true},
	  {title: "Flows", field: "column_flows", sortable: true}
	]
  });

});
</script>

]]
end

function historicalTopApplicationsTable(ifid, epoch_begin, epoch_end, host)
   local top_apps_url_params=""
   top_apps_url_params = top_apps_url_params.."&epoch_start="..epoch_begin
   top_apps_url_params = top_apps_url_params.."&epoch_end="..epoch_end
   if host and host ~= "" then
      top_apps_url_params = top_apps_url_params.."&peer1="..host
   end
   local preference = tablePreferences("rows_number",_GET["perPage"])
   local sort_order = getDefaultTableSortOrder("historical_stats_top_applications")
   local sort_column= getDefaultTableSort("historical_stats_top_applications")
   if not sort_column or sort_column == "column_" then sort_column = "column_tot_bytes" end

   print[[
<div id="historical-top-applications-table" total_rows=-1>

</div>


<script type="text/javascript">
var totalRows = -1;

$('a[href="#historical-top-apps"]').on('shown.bs.tab', function (e) {
  var target = $(e.target).attr("href"); // activated tab
  $('#historical-top-applications-table').datatable({
      title: "",]]
      print("url: '"..ntop.getHttpPrefix().."/lua/get_historical_data.lua?stats_type=top_applications"..top_apps_url_params.."',")
if preference ~= "" then print ('perPage: '..preference.. ",") end
-- Automatic default sorted. NB: the column must be exists.
print ('sort: [ ["'..sort_column..'","'..sort_order..'"] ],')
print [[
      post: {totalRows: function(){ return $('#historical-top-applications-table').attr("total_rows");} },
      showFilter: true,
      showPagination: true,
      tableCallback: function(){$('#historical-top-applications-table').attr("total_rows", this.options.totalRows);},
      columns:
	[
	  {title: "Protocol id", field: "column_application", hidden: true},
	  {title: "Application", field: "column_label", sortable: false},
	  {title: "Traffic Volume", field: "column_bytes", sortable: true, css: {textAlign:'right'}},
	  {title: "Packets", field: "column_packets", sortable: true, css: {textAlign:'right'}},
	  {title: "Flows", field: "column_flows", sortable: true, css: {textAlign:'right'}}
	]
  });

});
</script>

]]
end
