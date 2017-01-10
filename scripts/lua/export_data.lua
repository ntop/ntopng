--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
active_page = "admin"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print [[

     <style type="text/css">
     #map-canvas { width: 640px; height: 480px; }
   </style>
<div class="container-fluid">
<hr>
<h2>Export Data</H2>
<p>&nbsp;<p>

<form class="form-horizontal" action="]]
print (ntop.getHttpPrefix())
print [[/lua/do_export_data.lua" method="GET">
]]

print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')


print [[

  <div class="control-group">
    <label class="control-label">Host</label>
    <div class="controls">
      <input type="hidden" id="hostIP" name="hostIP">
      <input type="text" id="hostIPSearch" placeholder="IP or MAC Address" class="form-control">
    </div>
<label><small>NOTE: If the field is empty all hosts will be exported</small></label>
  </div>


<div class="control-group">
    <label class="control-label" for="hostVlan">Vlan:</label>
    <div class="controls">
      <input type="text" id="hostVlan" name="hostVlan" placeholder="Vlan" class="form-control">
    </div>
     <label><small>NOTE: If the field is empty vlan is set to 0.</small></label>
  </div>
</br>

<div class="control-group">
<div class="controls">
  <button type="submit" class="btn btn-primary">Export JSON Data</button> 
  <button class="btn btn-default" type="reset">Reset Form</button>
</div>
</div>

<script type='text/javascript'>
  function auto_ip_mac () {
   $('#hostIPSearch').typeahead({
       source: function (query, process) {
               return $.get(']]
print (ntop.getHttpPrefix())
print [[/lua/find_host.lua', { query: query }, function (data) {
                     return process(data.results);
      });
      }, afterSelect: function(item) {
        $("#hostIP").val(item.ip);
      }
    });
  }

  $(document).ready(function(){
    auto_ip_mac();
  });
</script>


</form>
</div>

]]


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
