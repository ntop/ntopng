--
-- (C) 2013-17 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"

sendHTTPContentTypeHeader('text/html')


ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")
active_page = "admin"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print [[

     <style type="text/css">
     #map-canvas { width: 640px; height: 480px; }
   </style>
<div class="container-fluid">
<hr>
<h2>]]
print(i18n("export_data.export_data"))
print [[</H2>
<p>&nbsp;<p>

<form class="form-horizontal" action="]]
print (ntop.getHttpPrefix())
print [[/lua/do_export_data.lua">
]]

print [[

  <div class="control-group">
    <label class="control-label">]]
print(i18n("export_data.host"))
print[[</label>
    <div class="controls">
      <input type="hidden" id="hostIP" name="ip">
      <input type="hidden" name="ifid" value="]] print(getInterfaceId(ifname).."") print[[">
      <input type="text" id="hostIPSearch" placeholder="]] print(i18n("export_data.ip_or_mac_address")) print[[" class="form-control">
    </div>
<label><small>]] print(i18n("export_data.note_host")) print[[</small></label>
  </div>


<div class="control-group">
    <label class="control-label" for="hostVlan">]] print(i18n("vlan")) print[[:</label>
    <div class="controls">
      <input type="text" id="hostVlan" name="vlan" placeholder="]] print(i18n("vlan")) print[[" class="form-control">
    </div>
     <label><small>]] print(i18n("export_data.note_vlan")) print[[</small></label>
  </div>
</br>

<div class="control-group">
<div class="controls">
  <button type="submit" class="btn btn-primary">]] print(i18n("export_data.export_json_data")) print[[</button>
  <button class="btn btn-default" type="reset">]] print(i18n("export_data.reset_form")) print[[Reset Form</button>
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
