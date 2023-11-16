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

-- begin od container
print("<div class='manage-data-modals'>")

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
	      print('<div class="alert alert-success alert-dismissable">'..i18n('delete_data.delete_inactive_interfaces_data_ok')..'<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button></div>')
      else
	      print('<div class="alert alert-danger alert-dismissable">'..i18n('delete_data.delete_inactive_interfaces_data_failed')..' '..table.concat(err_msgs, ' ')..'<button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button></div>')
      end

   else

      -- Data for the active interface can't be hot-deleted.
      -- a restart of ntopng is required so we just mark the deletion.
      delete_data_utils.request_delete_active_interface_data(getSystemInterfaceId())

      print([[
         <div class="alert alert-success alert-dismissable">
            ]]..i18n('delete_data.delete_active_interface_data_ok', {ifname = i18n("system"), product = ntop.getInfo().product})..[[
               <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
         </div>
      ]])
   end

end

local delete_active_interface_requested = delete_data_utils.delete_active_interface_data_requested(getSystemInterfaceId())
if not delete_active_interface_requested then
   print(
      template.gen("modal_confirm_dialog.html", {
		   dialog = {
			   id      = "delete_active_interface_data_system",
			   action  = "delete_system_interfaces_data('delete_active_if_data_system')",
			   title   = i18n("manage_data.delete_active_interface"),
			   message = i18n("delete_data.delete_active_interface_confirmation", {ifname = "<span id='interface-name-to-delete'></span>", product = ntop.getInfo().product}),
			   confirm = i18n("delete"),
            confirm_button = "btn-danger",
            custom_alert_class = 'alert alert-danger'
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
            id      = "delete_inactive_interfaces_data_system",
            action  = "delete_system_interfaces_data('delete_inactive_if_data_system')",
            title   = i18n("manage_data.delete_inactive_interfaces"),
            message = i18n("delete_data.delete_inactive_interfaces_confirmation", {interfaces_list = inactive_list}),
            confirm = i18n("delete"),
            confirm_button = "btn-danger",
            custom_alert_class = 'alert alert-danger'
		   }
      })
   )
end

print([[
   <script type="text/javascript">

   const delete_system_interfaces_data = function(action) {

      let params = {};
      params[action] = '';
      params.page = 'delete';
      params.ifid = ]].. getSystemInterfaceId() ..[[;
      params.csrf = "]].. ntop.getRandomCSRFValue() ..[[";

      const form = NtopUtils.paramsToForm('<form method="post"></form>', params);
      form.appendTo('body').submit();
   };

   $(document).ready(function() {

      $("#delete-system-interface").click(function(e) {
         $('#interface-name-to-delete').html(']].. i18n("system") ..[[');
      });

   });


   </script>
]])

-- end of the container
print("</div>")
