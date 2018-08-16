--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local template = require "template_utils"

local page        = _GET["page"] or _POST["page"]

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if _POST and table.len(_POST) > 0 and isAdministrator() then
   local delete_data_utils = require "delete_data_utils"

   local host_info = url2hostinfo(_POST)

   local res = delete_data_utils.delete_host(_POST["ifid"], host_info)

   local err_msgs = {}
   for what, what_res in pairs(res) do
      if what_res["status"] ~= "OK" then
	 err_msgs[#err_msgs + 1] = i18n(delete_data_utils.status_to_i18n(what_res["status"]))
      end
   end

   if #err_msgs == 0 then
      print('<div class="alert alert-success alert-dismissable"><a href="" class="close" data-dismiss="alert" aria-label="close">&times;</a>'..i18n('delete_data.delete_ok', {host = hostinfo2hostkey(host_info)})..'</div>')
   else
      print('<div class="alert alert-danger alert-dismissable"><a href="" class="close" data-dismiss="alert" aria-label="close">&times;</a>'..i18n('delete_data.delete_failed', {host = hostinfo2hostkey(host_info)})..' '..table.concat(err_msgs, ' ')..'</div>')
   end
end

print(
   template.gen("modal_confirm_dialog.html", {
		   dialog = {
		      id      = "delete_data",
		      action  = "delete_data()",
		      title   = i18n("manage_data.delete"),
		      message = i18n("delete_data.delete_confirmation",
				     {host = '<span id="modal_host"></span><span id="modal_vlan"></span>'}),
		      confirm = i18n("delete")
		   }
   })
)

print[[
<hr>
<h2>]] print(i18n("manage_data.manage_data")) print[[</h2>
<br>
<ul class="nav nav-tabs">]]

if((page == "export") or (page == nil)) then
   print[[<li class="active"><a data-toggle="tab" href="#export">]] print(i18n("manage_data.export_tab")) print[[</a></li>]]
else
   print[[<li><a data-toggle="tab" href="#export">]] print(i18n("manage_data.export_tab")) print[[</a></li>]]
end

if isAdministrator() then
   if((page == "delete")) then
      print[[<li class="active"><a data-toggle="tab" href="#delete">]] print(i18n("manage_data.delete_tab")) print[[</a></li>]]
   else
      print[[<li><a data-toggle="tab" href="#delete">]] print(i18n("manage_data.delete_tab")) print[[</a></li>]]
   end
end

print[[</ul>

<div class="tab-content">

]]

print [[

  <div id="export" class="tab-pane fade in active">
  <br>

<section class="panel panel-default">

<div class="panel-heading">
  <h3 class="panel-title"> ]] print(i18n("manage_data.export")) print[[ </h3>
</div>

<div class="panel-body">

  <div id="search_panel">
    <div class='container'>
      <form class="host_data_form" id="host_data_form_export" action="]] print(ntop.getHttpPrefix()) print[[/lua/do_export_data.lua" method="GET">
      <input type=hidden name="ifid" value=]] print(tostring(getInterfaceId(ifname))) print[[>
    
       <div class="row">
         <div class='col-md-1'>
         </div>
    
         <div class='col-md-10'>
           <b>]] print(i18n("manage_data.hosts")) print[[:</b>
           <br>
    
           <div class="form-group form-inline">
             <div class="btn-group" data-toggle="buttons" id="export_hosts_buttons" name="export_hosts_buttons">
               <label class="btn btn-default active">
                 <input type="radio" id="all_hosts" name="mode" value="all" autocomplete="off" data-toggle="toggle"  checked="checked">]] print(i18n("manage_data.all_hosts")) print[[
               </label>
               <label class="btn btn-default">
                 <input type="radio" id="local_hosts" name="mode" value="local" autocomplete="off" data-toggle=" toggle">]] print(i18n("manage_data.local_hosts")) print[[
               </label>
               <label class="btn btn-default">
                 <input type="radio" id="remote_hosts" name="mode" value="remote" autocomplete="off" data-toggle=" toggle">]] print(i18n("manage_data.remote_hosts")) print[[
               </label>
               <label class="btn btn-default">
                 <input type="radio" id="single_host" name="mode" value="filtered" autocomplete="off" data-toggle=" toggle">]] print(i18n("manage_data.single")) print[[
               </label>
             </div>
    
             <div class="form-group has-feedback" style="margin-bottom:0;">
               <input type="text" id="export_host" data-host="host" name="host" placeholder="]] print(i18n("manage_data.ip_or_mac_address")) print[[" class="form-control" disabled required/>
             </div>
    
             <input type="number" min="1" max="65535" placeholder="]] print(i18n("vlan")) print[[" style="display:inline;" id="export_vlan" name="vlan" class="form-control" value="" disabled/>
    
           </div>
         </div>
    
         <div class='col-md-1'>
         </div>
    
       </div>
    
       <div class="row">
         <div class='col-md-10'>
           <input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />
         </div>
    
         <div class='col-md-2'>
           <div class="btn-group pull-right">
             <input type="submit" value="]] print(i18n("export_data.export_json_data")) print[[" class="btn btn-default pull-right">
           </div>
         </div>
       </div>
      </form>
    </div>
  </div>

</section>
  <b>]] print(i18n('notes')) print[[</b>
<ul>
<li>]] print(i18n('export_data.note_maximum_number')) print[[</li>
<li>]] print(i18n('export_data.note_active_hosts')) print[[</li>

</ul>
]]


print("</div>") -- closes <div id="export" class="tab-pane fade in active">

print [[

  <div id="delete" class="tab-pane fade">
  <br>

<section class="panel panel-default">

<div class="panel-heading">
  <h3 class="panel-title"> ]] print(i18n("manage_data.delete")) print[[ </h3>
</div>

<div class="panel-body">

  <div id="search_panel">
    <div class='container'>

      <form class="host_data_form" id="host_data_form_delete" method="POST">
      <input type=hidden name="ifid" value=]] print(tostring(getInterfaceId(ifname))) print[[>
    
       <div class="row">
         <div class='col-md-1'>
         </div>
    
         <div class='col-md-10'>
           <br>
    
           <div class="form-group form-inline">
             <div class="btn-group invisible" data-toggle="buttons" id="delete_hosts_buttons" name="delete_hosts_buttons">
               <label class="btn btn-default active">
                 <input type="radio" id="single_host" name="mode" value="filtered" autocomplete="off" data-toggle=" toggle" checked="checked">]] print(i18n("manage_data.single")) print[[
               </label>
             </div>
    
             <div class="form-group has-feedback" style="margin-bottom:0;">
               <input type="text" id="delete_host" data-host="host" name="host" placeholder="]] print(i18n("manage_data.ip_or_mac_address")) print[[" class="form-control" required/>
             </div>
    
             <input type="number" min="1" max="65535" placeholder="]] print(i18n("vlan")) print[[" style="display:inline;" id="delete_vlan" name="vlan" class="form-control" value=""/>
    
           </div>
         </div>
    
         <div class='col-md-1'>
         </div>
    
       </div>
    
       <div class="row">
         <div class='col-md-10'>
         </div>
    
         <div class='col-md-2'>
           <div class="btn-group pull-right">
           </div>
         </div>
       </div>
          <button class="btn btn-default" type="submit" onclick="return delete_data_show_modal();" style="float:right; margin-right:1em;"><i class="fa fa-trash" aria-hidden="true" data-original-title="" title="]] print(i18n("manage_data.delete")) print[["></i> ]] print(i18n("manage_data.delete")) print[[</button>
        </form>
    
  </div>
</div>

</section>
  <b>]] print(i18n('notes')) print[[</b>
<ul>
<li>]] print(i18n('delete_data.note_persistent_data')) print[[</li>
</ul>
</div>]]


print("</div>") -- closes <div class="tab-content">


print[[<script type='text/javascript'>

var delete_data_show_modal = function() {
  $(".modal-body #modal_host").html(" " + $('#delete_host').val());
  if($('#delete_vlan').val() != "") {
    $(".modal-body #modal_vlan").html("@" + $('#delete_vlan').val());
  } else {
    $(".modal-body #modal_vlan").html("");
  }
  $('#delete_data').modal('show');

  /* abort submit */
  return false;
};

var delete_data = function() {
            var params = {};

            params.ifid = ']] print(tostring(getInterfaceId(ifname))) print[[';
            params.host = $('#delete_host').val();
            params.vlan = $('#delete_vlan').val();
            params.page = 'delete';

            params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

            var form = paramsToForm('<form method="post"></form>', params);

            form.appendTo('body').submit();
         };

var prepare_typeahead = function(host_id, vlan_id, buttons_id) {
  $('#' + host_id).val('');
  $('#' + vlan_id).val('');

  $('#' + host_id).typeahead({
    source: function (query, process) {
      return $.get(']]
print (ntop.getHttpPrefix())
print [[/lua/find_host.lua', { query: query }, function (data) {
                     return process(data.results);
      });
      }, afterSelect: function(item) {
        $('#' + host_id).val(item.ip.split("@")[0]);
        $('#' + vlan_id).val(item.ip.split("@")[1] || '');

        /* retrigger validation */
        $('#' + host_id).closest("form").data("bs.validator").validate();
      }
    });

  $('#' + buttons_id + ' :input').change(function() {
    $('#' + vlan_id + ', #' + host_id).prop('disabled', this.id === "single_host" ? false : true);
    if(this.id !== "single_host") {
      $('#' + vlan_id).val('');
      $('#' + host_id).val('');
    }
  });
}

  $(document).ready(function(){
    prepare_typeahead('export_host', 'export_vlan', 'export_hosts_buttons');
    prepare_typeahead('delete_host', 'delete_vlan', 'delete_hosts_buttons');

    var validator_options = {
      disable: true,
      custom: {
         host: hostOrMacValidator,
      }, errors: {
         host: "]] print(i18n("manage_data.mac_or_ip_required")) print[[.",
      }
    }

    $("#host_data_form_delete")
      .validator(validator_options)
      .find("[type='submit']").addClass("disabled");
  });
</script>


]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
