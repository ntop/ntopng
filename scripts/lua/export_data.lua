--
-- (C) 2013-18 - ntop.org
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

<section class="panel panel-default">

<div class="panel-heading">
  <h3 class="panel-title"> ]] print(i18n("export_data.export_data")) print[[ </h3>
</div>

<div class="panel-body">
  <form action="]] print(ntop.getHttpPrefix()) print[[/lua/do_export_data.lua">
  <input type=hidden name="ifid" value=]] print(tostring(getInterfaceId(ifname))) print[[>

   <div class="row">
     <div class='col-md-3'>
     </div>

     <div class='col-md-6'>
       <b>]] print(i18n("export_data.hosts")) print[[:</b>
       <br>

       <div class="form-group form-inline">
         <div class="btn-group" data-toggle="buttons" id="export_hosts_buttons" name="export_hosts_buttons">
           <label class="btn btn-default active">
             <input type="radio" id="all_hosts" name="mode" value="all" autocomplete="off" data-toggle="toggle"  checked="checked">]] print(i18n("export_data.all_hosts")) print[[
           </label>
           <label class="btn btn-default">
             <input type="radio" id="local_hosts" name="mode" value="local" autocomplete="off" data-toggle=" toggle">]] print(i18n("export_data.local_hosts")) print[[
           </label>
           <label class="btn btn-default">
             <input type="radio" id="remote_hosts" name="mode" value="remote" autocomplete="off" data-toggle=" toggle">]] print(i18n("export_data.remote_hosts")) print[[
           </label>
           <label class="btn btn-default">
             <input type="radio" id="single_host" name="mode" value="filtered" autocomplete="off" data-toggle=" toggle">]] print(i18n("export_data.single")) print[[
           </label>
         </div>

         <input type="text" id="hostIPSearch" name="host" placeholder="]] print(i18n("export_data.ip_or_mac_address")) print[[" class="form-control" disabled/>

         <input type="number" min="1" max="65535" placeholder="]] print(i18n("vlan")) print[[" style="display:inline;" id="hostVlan" name="vlan" class="form-control" value="" disabled/>

       </div>
     </div>

     <div class='col-md-3'>
     </div>

   </div>

   <div class="row">
     <div class='col-md-10'>
       <input type="hidden" name="search" value=""/>
     </div>

     <div class='col-md-2'>
       <div class="btn-group pull-right">
         <input type="submit" value="]] print(i18n("export_data.export_json_data")) print[[" class="btn btn-default pull-right">
       </div>
     </div>
   </div>
  </form>
</section>
  <b>]] print(i18n('notes')) print[[</b>
<ul>
<li>]] print(i18n('export_data.note_maximum_number')) print[[</li>
<li>]] print(i18n('export_data.note_active_hosts')) print[[</li>

</ul>
</div>
<script type='text/javascript'>
  $('#hostVlan').val('');
  $('#hostIPSearch').val('');

  function auto_ip_mac () {
   $('#hostIPSearch').typeahead({
       source: function (query, process) {
               return $.get(']]
print (ntop.getHttpPrefix())
print [[/lua/find_host.lua', { query: query }, function (data) {
                     return process(data.results);
      });
      }, afterSelect: function(item) {
        $('#hostIPSearch').val(item.ip.split("@")[0]);
        $('#hostVlan').val(item.ip.split("@")[1] || '');
      }
    });
  }

  $('#export_hosts_buttons :input').change(function() {
    $('#hostVlan, #hostIPSearch').prop('disabled', this.id === "single_host" ? false : true);
    if(this.id !== "single_host") {
      $('#hostVlan').val('');
      $('#hostIPSearch').val('');
    }
  });

  $(document).ready(function(){
    auto_ip_mac();
  });
</script>


]]


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
