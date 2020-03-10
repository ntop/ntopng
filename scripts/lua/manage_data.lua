--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local delete_data_utils = require "delete_data_utils"
local template = require "template_utils"
local page_utils = require("page_utils")

local page        = _GET["page"] or _POST["page"]
local info = ntop.getInfo()

local delete_data_utils = require "delete_data_utils"

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.manage_data)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if _POST and table.len(_POST) > 0 and isAdministrator() then

  if _POST["delete_active_if_data"] then

    -- Data for the active interface can't be hot-deleted.
    -- a restart of ntopng is required so we just mark the deletion.
    delete_data_utils.request_delete_active_interface_data(_POST["ifid"])

    print('<div class="alert alert-success alert-dismissable"><a href="" class="close" data-dismiss="alert" aria-label="close">&times;</a>'..i18n('delete_data.delete_active_interface_data_ok', {ifname = ifname, product = ntop.getInfo().product})..'</div>')

  else -- we're deleting an host

    local host_info = url2hostinfo(_POST)
    local parts = split(host_info["host"], "/")
    local res

    if (#parts == 2) and (tonumber(parts[2]) ~= nil) then
      res = delete_data_utils.delete_network(_POST["ifid"], parts[1], parts[2], host_info["vlan"] or 0)
    else
      res = delete_data_utils.delete_host(_POST["ifid"], host_info)
    end

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
end

local delete_active_interface_requested = delete_data_utils.delete_active_interface_data_requested(ifname)
if not delete_active_interface_requested then
   print(
      template.gen("modal_confirm_dialog.html", {
		      dialog = {
			 id      = "delete_active_interface_data",
			 action  = "delete_interfaces_data('delete_active_if_data')",
			 title   = i18n("manage_data.delete_active_interface"),
			 message = i18n("delete_data.delete_active_interface_confirmation",
					{ifname = "<span id='interface-name-to-delete'></span>", product = ntop.getInfo().product}),
			 confirm = i18n("delete"),
                         confirm_button = "btn-danger",
		      }
      })
   )
end

print(
   template.gen("modal_confirm_dialog.html", {
		   dialog = {
		      id      = "delete_data",
		      action  = "delete_data()",
		      title   = i18n("manage_data.delete"),
		      message = i18n("delete_data.delete_confirmation",
				     {host = '<span id="modal_host"></span><span id="modal_vlan"></span>'}),
		      confirm = i18n("delete"),
                      confirm_button = "btn-danger",
		   }
   })
)

print[[
<h2>]] print(i18n("manage_data.manage_data")) print[[</h2>
<br>
<ul id="manage-data-nav" class="nav nav-tabs">]]

local tab_export_active = ""
local tab_delete_active = ""

if((page == "export") or (page == nil)) then
   tab_export_active = " in active"
   print[[<li class="nav-item active"><a class="nav-link active" data-toggle="tab" href="#export">]] print(i18n("manage_data.export_tab")) print[[</a></li>]]
else
   print[[<li class="nav-item"><a class="nav-link" data-toggle="tab" href="#export">]] print(i18n("manage_data.export_tab")) print[[</a></li>]]
end

-- TODO show delete tab also in oem after https://github.com/ntop/ntopng/issues/2258 is fixed
if isAdministrator() and (not info.oem) then
   if((page == "delete")) then
      tab_delete_active = " in active"
      print[[<li class="nav-item active"><a class="nav-link active" data-toggle="tab" href="#delete">]] print(i18n("manage_data.delete_tab")) print[[</a></li>]]
   else
      print[[<li class="nav-item"><a class="nav-link" data-toggle="tab" href="#delete">]] print(i18n("manage_data.delete_tab")) print[[</a></li>]]
   end
end

print[[</ul>

<div class="tab-content">

]]

print [[

  <div id="export" class="tab-pane ]]print(tab_export_active) print[[">
  <br>

<section class="panel panel-default">

<div class="panel-heading">
  <h3 class="panel-title"> ]] print(i18n("manage_data.export")) print[[ </h3>
  <br>
</div>

<div class="panel-body">
  <div id="search_panel">
    <div class='container'>
      <form class="host_data_form" id="host_data_form_export" action="]] print(ntop.getHttpPrefix()) print[[/lua/do_export_data.lua" method="GET">
      <input type=hidden name="ifid" value=]] print(tostring(getInterfaceId(ifname))) print[[>

       <div class="row">
	 <div class='col-md-3'>
	   <div class="form-group">
	     <div class="btn-group btn-group-toggle" data-toggle="buttons" id="export_hosts_buttons" name="export_hosts_buttons">
	       <label class="btn btn-secondary active">
		 <input type="radio" id="all_hosts" name="mode" value="all" autocomplete="off" data-toggle="toggle"  checked="checked">]] print(i18n("manage_data.all_hosts")) print[[
	       </label>
	       <label class="btn btn-secondary">
		 <input type="radio" id="local_hosts" name="mode" value="local" autocomplete="off" data-toggle=" toggle">]] print(i18n("manage_data.local_hosts")) print[[
	       </label>
	       <label class="btn btn-secondary">
		 <input type="radio" id="remote_hosts" name="mode" value="remote" autocomplete="off" data-toggle=" toggle">]] print(i18n("manage_data.remote_hosts")) print[[
	       </label>
	       <label class="btn btn-secondary">
		 <input type="radio" id="single_host" name="mode" value="filtered" autocomplete="off" data-toggle=" toggle">]] print(i18n("manage_data.single")) print[[
	       </label>
	     </div>
	   </div>
	 </div>
	 <div class='col-md-3'>
	   <div class="form-group" style="margin-bottom:0;">
	     <input type="text" id="export_host" data-host="host" name="host" placeholder="]] print(i18n("manage_data.ip_or_mac_address")) print[[" class="form-control" size="24" disabled required/>
	   </div>
	 </div>
	 <div class='col-md-2'>
	   <input type="number" min="1" max="65535" placeholder="]] print(i18n("vlan")) print[[" style="display:inline;" id="export_vlan" name="vlan" class="form-control" value="" disabled/>
	 </div>
	 <div class='col-md-2'>
	 </div>
       </div>
     </div>

       <div class="row">
	 <div class='col-md-10'>
	   <input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />
	 </div>

	 <div class='col-md-2'>
	   <div class="btn-group btn-group-toggle float-right">
	     <input type="submit" value="]] print(i18n("export_data.export_json_data")) print[[" class="btn btn-secondary float-right">
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


print("</div>") -- closes <div id="export" class="tab-pane in active">

print [[

  <div id="delete" class="tab-pane ]] print(tab_delete_active) print[[">
  <br>

<section class="panel panel-default">

<div class="panel-heading">
  <h3 class="panel-title"> ]] print(i18n("manage_data.delete")) print[[ </h3>
  <br>
</div>

<div class="panel-body">
  <div id="search_panel">
  <form class="host_data_form" id="host_data_form_delete" method="POST">
    <div class='container'>

        <input type=hidden name="ifid" value=]] print(tostring(getInterfaceId(ifname))) print[[>

      <div class="row">
	      <div class='col-md-1'>
	        <div class="form-group">
	          <div class="btn-group btn-group-toggle invisible" data-toggle="buttons" id="delete_hosts_buttons" name="delete_hosts_buttons">
              <label class="btn btn-secondary active">
                <input type="radio" id="single_host" name="mode" value="filtered" autocomplete="off" data-toggle=" toggle" checked="checked">]] print(i18n("manage_data.single")) print[[
              </label>
	          </div>
	        </div>
	      </div>
	      <div class='col-md-3'>
	        <div class="form-group" style="margin-bottom:0;">
	          <input type="text" required id="delete_host" data-host="host" name="host" placeholder="]] print(i18n("manage_data.ip_or_mac_address")) print[[" class="form-control" size="24"/>
	        </div>
	      </div>
	      <div class='col-md-3'>
	        <input type="number" required min="1" max="65535" placeholder="]] print(i18n("vlan")) print[[" style="display:inline;" id="delete_vlan" name="vlan" class="form-control" value=""/>
	      </div>
  	  </div>
      <div class="row">
        <div class='col-md-10'></div>
        <div class='col-md-2'>
	        <div class="btn-group btn-group-toggle float-right">
	        </div>
	      </div>
       </div>
    </div>
	  <button class="btn btn-secondary" type="submit" onclick="return delete_data_show_modal();" style="float:right; margin-right:1em;"><i class="fas fa-trash" aria-hidden="true" data-original-title="" title="]] print(i18n("manage_data.delete")) print[["></i> ]] print(i18n("manage_data.delete")) print[[</button>
	</form>

</div>

</section>
]]

print[[<div>]]

if (not ntop.isnEdge()) and (not delete_active_interface_requested) then
   print[[
<form class="interface_data_form" method="POST">
  <button class="btn btn-secondary" type="submit" onclick="$('#interface-name-to-delete').html(']] print(ifname) print[['); return delete_interfaces_data_show_modal('delete_active_interface_data');" style="float:right; margin-right:1em;"><i class="fas fa-trash" aria-hidden="true" data-original-title="" title="]] print(i18n("manage_data.delete_active_interface")) print[["></i> ]] print(i18n("manage_data.delete_active_interface")) print[[</button>
</form>
]]
end

print[[</div><br>]]

print[[  <b>]] print(i18n('notes')) print[[</b>
<ul>
<li>]] print(i18n('delete_data.note_persistent_data')) print[[</li>
]]

if interfaceHasNindexSupport() then
  print[[<li>]] print(i18n('delete_data.node_nindex_flows')) print[[</li>]]
end

print[[
<li>]] print(i18n('manage_data.system_interface_note')) print[[</li>
</ul>
</div>]]


print("</div>") -- closes <div class="tab-content">


print[[<script type='text/javascript'>

$(document).ready(function() {
  $('#host_data_form_delete').areYouSure();
})

var delete_data_show_modal = function() {

  $(".modal-body #modal_host").html(" " + $('#delete_host').val());
  if ($('#delete_vlan').val() != "") {

    $(".modal-body #modal_vlan").html("@" + $('#delete_vlan').val());
    $('#delete_data').modal('show');

    /* abort submit */
    return false;
  }

  return true;

};

var delete_data = function() {
var params = {};

params.ifid = ']] print(tostring(getInterfaceId(ifname))) print[[';
            params.host = $('#delete_host').val();
            params.vlan = $('#delete_vlan').val();
            params.page = 'delete';

            params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

            var form = paramsToForm('<form method="post"></form>', params);

            aysResetForm($("#host_data_form_delete")); // clean the form to void alert message
            form.appendTo('body').submit();
         };

var delete_interfaces_data_show_modal = function(modal_id) {
  $('#' + modal_id).modal('show');

  /* abort submit */
  return false;
};

var delete_interfaces_data = function(action) {
  var params = {[action] : ''};

  params.page = 'delete';
  params.ifid = ]] print(getInterfaceId(ifname)) print[[;

  params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

  var form = paramsToForm('<form method="post"></form>', params);

  form.appendTo('body').submit();
};

function setActiveHashTab(hash) {
   $('#manage-data-nav a[href="' + hash + '"]').tab('show');
}

var prepare_typeahead = function(host_id, vlan_id, buttons_id) {
  $('#' + host_id).val('');
  $('#' + vlan_id).val('');

  $('#' + host_id).typeahead({
    source: function (query, process) {
      return $.get(']]
print (ntop.getHttpPrefix())
print [[/lua/find_host.lua', { query: query, hosts_only: true }, function (data) {
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

  function deleteHostValidator(input) {
    if(hostOrMacValidator(input))
      return true;

    /* check for a /24-/32 IPv4 network */
    if(is_network_mask(input.val(), false /* mandatory mask */)) {
      var elems = input.val().split("/");

      if((elems.length == 2) && is_good_ipv4(elems[0]) && (parseInt(elems[1]) >= 24))
        return true;
    }

    return false;
  }

  $(document).ready(function(){
    prepare_typeahead('export_host', 'export_vlan', 'export_hosts_buttons');
    prepare_typeahead('delete_host', 'delete_vlan', 'delete_hosts_buttons');

    var validator_options = {
      disable: true,
      custom: {
         host: deleteHostValidator,
      }, errors: {
         host: "]] print(i18n("manage_data.mac_or_ip_required")) print[[.",
      }
    }

    $("#host_data_form_delete")
      .validator(validator_options);

    aysHandleForm("#host_data_form_delete");
  });

  /* Handle tab state across requests */
  $("ul.nav-tabs > li > a").on("shown.bs.tab", function(e) {
      var id = $(e.target).attr("href").substr(1);
      history.replaceState(null, null, "#"+id);
  });

  if(window.location.hash)
    setActiveHashTab(window.location.hash)
</script>


]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
