--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local template = require "template_utils"

local page = _GET["page"] or _POST["page"]

sendHTTPContentTypeHeader('text/html')

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

if _POST and table.len(_POST) > 0 then
   local err_msg = "not_implemented"
   page = "restore"

   -- Note: restore happens at boot, we can manually place the tarball
   -- in the expected location, or write the upload code here if we 
   -- decide to add multipart upload support in mongoose.

   if isEmptyString(err_msg) then
      print('<div class="alert alert-success alert-dismissable"><a href="" class="close" data-dismiss="alert" aria-label="close">&times;</a>'..i18n('conf_backup.restore_ok')..'</div>')
   else
      print('<div class="alert alert-danger alert-dismissable"><a href="" class="close" data-dismiss="alert" aria-label="close">&times;</a>'..i18n('conf_backup.restore_failed')..'</div>')
   end
end

print(
   template.gen("modal_confirm_dialog.html", {
		   dialog = {
		      id      = "restore_data",
		      action  = "restore_data()",
		      title   = i18n("conf_backup.restore"),
		      message = i18n("conf_backup.restore_confirmation"),
		      confirm = i18n("restore")
		   }
   })
)

print[[
<hr>
<h2>]] print(i18n("conf_backup.conf_backup")) print[[</h2>
<br>
<ul class="nav nav-tabs">]]

if((page == "backup") or (page == nil)) then
   print[[<li class="active"><a data-toggle="tab" href="#backup">]] print(i18n("conf_backup.backup_tab")) print[[</a></li>]]
else
   print[[<li><a data-toggle="tab" href="#backup">]] print(i18n("conf_backup.backup_tab")) print[[</a></li>]]
end

-- -- Restore tab temporarily disabled
-- if((page == "restore")) then
--   print[[<li class="active"><a data-toggle="tab" href="#restore">]] print(i18n("conf_backup.restore_tab")) print[[</a></li>]]
-- else
--    print[[<li><a data-toggle="tab" href="#restore">]] print(i18n("conf_backup.restore_tab")) print[[</a></li>]]
-- end

print[[</ul>

<div class="tab-content">

]]

-- BACKUP TAB

print [[

  <div id="backup" class="tab-pane fade in active">
  <br>

<section class="panel panel-default">

<div class="panel-heading">
  <h3 class="panel-title"> ]] print(i18n("conf_backup.backup")) print[[ </h3>
</div>

<div class="panel-body">

  <div id="search_panel">
    <div class='container'>
      <form class="" id="backup_form" action="]] print(ntop.getHttpPrefix()) print[[/lua/get_config.lua" method="POST">
    
       <div class="row">
         <div class='col-md-1'>
         </div>
    
         <div class='col-md-10'>
           ]] print(i18n("conf_backup.backup_descr")) print[[
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
             <button class="btn btn-default" type="submit"><i class="fa fa-download" aria-hidden="true" data-original-title="" title="]] print(i18n("conf_backup.backup")) print[["></i> ]] print(i18n("download")) print[[</button>
           </div>
         </div>
       </div>
      </form>
    </div>
  </div>

</section>

<b>]] print(i18n('notes')) print[[</b>
<ul>
<li>]] print(i18n('conf_backup.manual_restore')) print[[</li>
</ul>
]]

print("</div>")

-- RESTORE TAB

print [[

  <div id="restore" class="tab-pane fade">
  <br>

<section class="panel panel-default">

<div class="panel-heading">
  <h3 class="panel-title"> ]] print(i18n("conf_backup.restore")) print[[ </h3>
</div>

<div class="panel-body">

  <div id="search_panel">
    <div class='container'>

      <form class="" id="restore_form" method="POST" enctype="multipart/form-data">
    
       <div class="row">
         <div class='col-md-1'>
         </div>
   
         <div class='col-md-10'>
           ]] print(i18n("conf_backup.restore_descr")) print[[

           <br>
           <br>
    
           <div class="form-group form-inline">
    
             <div class="form-group has-feedback" style="margin-bottom:0;">
               <input type="hidden" name="page" value="restore"/>
               <input type="file" id="restore_file" name="payload" enctype="multipart/form-data" required/>
             </div>
    
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
          <button class="btn btn-default" type="submit" onclick="return restore_show_modal();" style="float:right; margin-right:1em;"><i class="fa fa-upload" aria-hidden="true" data-original-title="" title="]] print(i18n("conf_backup.restore")) print[["></i> ]] print(i18n("restore")) print[[</button>
        </form>
    
  </div>
</div>

</section>

</div>]]


print("</div>") -- closes <div class="tab-content">


print[[<script type='text/javascript'>

var restore_show_modal = function() {
  $('#restore_data').modal('show');
  return false; /* abort submit */
};

var restore_data = function() {
  $("#restore_form").submit();
};

$(document).ready(function(){
  var validator_options = { disable: true, custom: {}, errors: {} }
  $("#restore_form")
    .validator(validator_options)
    .find("[type='submit']").addClass("disabled");
  });
</script>


]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
