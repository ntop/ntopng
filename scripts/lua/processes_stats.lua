--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print [[
  <br>
  <br>
  
    <ul class="nav nav-tabs">
      <li class="active"><a href="#Overview" data-toggle="tab">]] print(i18n("overview")) print[[</a></li>
      <li ><a href="#Timeline" data-toggle="tab">]] print(i18n("processes_stats.timeline")) print[[</a></li>
    </ul>

    <!-- Tab content-->
    <div class="tab-content">
]]

print [[
      <div class="tab-pane active" id="Overview">

      <div id="table-processes"></div>
   <script> ]]
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/processes_stats_id.inc") 

if(ifstats.vlan) then print ('processes_rows_option["source_id"] = true;\n') end

print [[
   $("#table-processes").datatable({
          title: "]] print(i18n("processes_stats.active_processes_title")) print[[",
          url: "]]
print (ntop.getHttpPrefix())
print [[/lua/get_processes_data.lua",
          ]]
print ('rowCallback: function ( row ) { return processes_table_setID(row); },')
print [[
	       showPagination: true,
	        columns: [
	        {
         title: "Key",
         field: "key",
         hidden: true,
         css: { 
              textAlign: 'center'
           }
         },
			     {
			     title: "]] print(i18n("name")) print[[",
				 field: "column_name",
				 sortable: true,
	 	             css: { 
			        textAlign: 'left'
			     }
				 },
]]

if(ifstats.vlan) then
print [[
           {
           title: "]] print(i18n("flows_page.source_id")) print[[",
         field: "column_vlan",
         sortable: true,
                 css: { 
              textAlign: 'center'
           }
         },
]]
end

print [[
        {
           title: "]] print(i18n("processes_stats.flows_count")) print[[",
         field: "column_count",
         sortable: true,
                 css: { 
              textAlign: 'center'
           }

         },          
           {
           title: "]] print(i18n("processes_stats.active_since")) print[[",
         field: "column_duration",
         sortable: true,
                 css: { 
              textAlign: 'center'
           }

         },          
           {
           title: "]] print(i18n("processes_stats.traffic_sent")) print[[",
         field: "column_bytes_sent",
         sortable: true,
                 css: { 
              textAlign: 'right'
           }
         },
           {
           title: "]] print(i18n("processes_stats.traffic_rcvd")) print[[",
         field: "column_bytes_rcvd",
         sortable: true,
                 css: { 
              textAlign: 'right'
           }
         }
           ]
         });
       </script>

]]

print [[
  <script>
  $( window ).load(function() {
    processes_table_update();
  });
    
  </script>
]]
print 
[[     </div> <!-- Tab Overview-->
]]


print [[  
<link type="text/css" rel="stylesheet" href="/css/timeline.css">
<script src="/js/timeline.js"></script>

<div class="tab-pane" id="Timeline">
  <h2>]] print(i18n("processes_stats.processes_timeline_title")) print[[</h2><br/> 
  <table class="table table-bordered">
    <tr>
      
      <th class="text-left span3">
        <legend>]] print(i18n("processes_stats.legend")) print[[</legend>
        <div id="legend"></div>
        <br/><br/>
        <legend>]] print(i18n("processes_stats.type")) print[[</legend>
        <form id="offset_form" class="toggler">
          <fieldset>
            <label class="radio inline">
              <input type="radio" name="offset" id="stack" value="zero" checked>
              ]] print(i18n("processes_stats.stack")) print[[
            </label>
            <label class="radio inline">
              <input type="radio" name="offset" id="lines" value="lines">
              ]] print(i18n("processes_stats.lines")) print[[
            </label>
          </fieldset>
        </form>
       
      </th>

      <td class="span3">
        <div id="chart_container">
          <div id="chart"></div>
          <div id="line"></div>
          <div id="preview"></div>
        </div>
      </td>
    
    </tr>
  </table>


<script>
  do_timeline("]]
print (ntop.getHttpPrefix())
print [[/lua/get_processes_data.lua",{ procstats_mode: "timeline" }, "name" ,2,300,2000);
</script>

</div>
]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

