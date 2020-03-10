--
-- (C) 2020 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local delete_data_utils = require "delete_data_utils"
local template = require "template_utils"
local page_utils = require("page_utils")

local info = ntop.getInfo()

local delete_data_utils = require "delete_data_utils"


if _POST and table.len(_POST) > 0 and isAdministrator() then

   if _POST["delete_inactive_if_data_system"] then

      local res = delete_data_utils.delete_inactive_interfaces()

      local err_msgs = {}
      for what, what_res in pairs(res) do
         if what_res["status"] ~= "OK" then
            err_msgs[#err_msgs + 1] = i18n(delete_data_utils.status_to_i18n(what_res["status"]))
         end
      end

      if #err_msgs == 0 then
	      print('<div class="alert alert-success alert-dismissable"><a href="#" class="close" data-dismiss="alert" aria-label="close">&times;</a>'..i18n('delete_data.delete_inactive_interfaces_data_ok')..'</div>')
      else
	      print('<div class="alert alert-danger alert-dismissable"><a href="#" class="close" data-dismiss="alert" aria-label="close">&times;</a>'..i18n('delete_data.delete_inactive_interfaces_data_failed')..' '..table.concat(err_msgs, ' ')..'</div>')
      end

   elseif _POST["delete_active_if_data_system"] then

      -- Data for the active interface can't be hot-deleted.
      -- a restart of ntopng is required so we just mark the deletion.
      delete_data_utils.request_delete_active_interface_data(_POST["ifid"])

      print('<div class="alert alert-success alert-dismissable"><a href="#" class="close" data-dismiss="alert" aria-label="close">&times;</a>'..i18n('delete_data.delete_active_interface_data_ok', {ifname = ifname, product = ntop.getInfo().product})..'</div>')
   end

end

local delete_active_interface_requested = delete_data_utils.delete_active_interface_data_requested(ifname)
if not delete_active_interface_requested then
   print(
      template.gen("modal_confirm_dialog.html", {
		   dialog = {
			   id      = "delete_active_interface_data",
			   action  = "delete_system_interfaces_data('delete_active_if_data_system')",
			   title   = i18n("manage_data.delete_active_interface"),
			   message = i18n("delete_data.delete_active_interface_confirmation", {ifname = "<span id='interface-name-to-delete'></span>", product = ntop.getInfo().product}),
			   confirm = i18n("delete"),
            confirm_button = "btn-danger",
		   }
      })
   )
end

local inactive_interfaces = delete_data_utils.list_inactive_interfaces()
local num_inactive_interfaces = ternary(not ntop.isnEdge(), table.len(inactive_interfaces or {}), 0)

if num_inactive_interfaces > 0 then
   local inactive_list = {}
   for if_id, if_name in pairs(inactive_interfaces) do
      inactive_list[#inactive_list + 1] = if_name
   end

   if table.len(inactive_list) > 20 then
      -- too many to use a bullet list, just concat them with a comma
      inactive_list = '<br>'..table.concat(inactive_list, ", ")..'<br>'
   else
      inactive_list = '<br><ul><li>'..table.concat(inactive_list, "</li><li>")..'</li></ul><br>'
   end

   print(
      template.gen("modal_confirm_dialog.html", {
		   dialog = {
            id      = "delete_inactive_interfaces_data",
            action  = "delete_system_interfaces_data('delete_inactive_if_data_system')",
            title   = i18n("manage_data.delete_inactive_interfaces"),
            message = i18n("delete_data.delete_inactive_interfaces_confirmation", {interfaces_list = inactive_list}),
            confirm = i18n("delete"),
            confirm_button = "btn-danger",
		   }
      })
   )
end

-- if num_inactive_interfaces > 0 then
--    print[[
-- 	<form class="interface_data_form" id="form_delete_inactive_interfaces" method="POST">
-- 	  <button class="btn btn-secondary" type="submit" onclick="return delete_interfaces_data_show_modal('delete_inactive_interfaces_data');" style="float:right; margin-right:1em;"><i class="fas fa-trash" aria-hidden="true" data-original-title="" title="]] print(i18n("manage_data.delete_inactive_interfaces")) print[["></i> ]] print() print[[</button>
-- 	</form>
-- ]]
-- end

-- print[[
-- <form class="interface_data_form" method="POST">
--   <button
--     class="btn btn-secondary"
--     type="submit"
--     onclick="$('#interface-name-to-delete').html(']] print(i18n("system")) print[['); delete_system_iface = true; return delete_interfaces_data_show_modal('delete_active_interface_data');"
--     style="float:right; margin-right:1em;"
--       >
-- ]]
-- print[[</button>
-- </form>
-- ]]

print([[
   <script type="text/javascript">

   const delete_system_interfaces_data = function(action) {

      let params = {};
      params[action] = '';
      params.page = 'delete';
      params.ifid = ]].. getSystemInterfaceId() ..[[;
      params.csrf = "]].. ntop.getRandomCSRFValue() ..[[";

      const form = paramsToForm('<form method="post"></form>', params);
      form.appendTo('body').submit();
   };

   $(document).ready(function() {

      $("#delete-system-interface").click(function(e) {
         $('#interface-name-to-delete').html(']].. i18n("system") ..[[');
      });

   });


   </script>
]])