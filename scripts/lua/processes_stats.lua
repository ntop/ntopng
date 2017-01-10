--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

mode = _GET["mode"]
if(mode == nil) then mode = "all" end

active_page = "hosts"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print [[
  <br>
  <br>
  
    <ul class="nav nav-tabs">
      <li class="active"><a href="#Overview" data-toggle="tab">Overview</a></li>
      <li ><a href="#Timeline" data-toggle="tab">Timeline</a></li>
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
          title: "Active Processes: Realtime View",
          url: "]]
print (ntop.getHttpPrefix())
print [[/lua/get_processes_data.lua",
          ]]
print ('rowCallback: function ( row ) { return processes_table_setID(row); },')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/processes_stats_top.inc")

if(ifstats.vlan) then
print [[
           {
           title: "Source Id",
         field: "column_vlan",
         sortable: true,
                 css: { 
              textAlign: 'center'
           }
         },
]]
end


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/processes_stats_bottom.inc")
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
  <h2>Processes Timeline</h2><br/> 
  <table class="table table-bordered">
    <tr>
      
      <th class="text-left span3">
        <legend>Legend</legend>
        <div id="legend"></div>
        <br/><br/>
        <legend>Type</legend>
        <form id="offset_form" class="toggler">
          <fieldset>
            <label class="radio inline">
              <input type="radio" name="offset" id="stack" value="zero" checked>
              Stack
            </label>
            <label class="radio inline">
              <input type="radio" name="offset" id="lines" value="lines">
              Lines
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
print [[/lua/get_processes_data.lua",{ mode: "timeline" }, "name" ,2,300,2000);
</script>

</div>
]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
