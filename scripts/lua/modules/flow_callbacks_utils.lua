--
-- (C) 2014-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local alerts_api = require "alerts_api"

local flow_callbacks_utils = {}

-- #################################

function flow_callbacks_utils.print_callbacks_config()
   local tab = _GET["tab"] or "application_detected"
   local descr = alerts_api.load_flow_check_modules(entity_type)

   print [[

<br>
<table id="callbacks_config_table" class="table table-bordered table-striped" style="clear: both">
<thead></thead>
<tbody>]]
   print[[<tr>]]
   print[[<th width=30%>]] print(i18n("flow_callbacks.callback")) print[[</th>]]
   print[[<th>]] print(i18n("flow_callbacks.callback_config")) print[[</th>]]
   print[[</tr>]]

   print[[<form id="flow-callbacks-config" class="form-inline" method="post">]]
   print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

   local has_modules = false
   for _, check_module in pairsByKeys(descr["all"], asc) do
      if check_module.gui then
	 if not has_modules then
	    has_modules = true
	 end

         print("<tr><td><b>".. i18n(check_module.gui.i18n_title) .."</b><br>")
         print("<small>"..i18n(check_module.gui.i18n_description)..".</small>\n")

	 print("</td><td>")
	 print(check_module.gui.input_builder(check_module))

	 print("</td></tr>")
      end
   end

   if not has_modules then
      print("<tr><td colspan=2><i>"..i18n("flow_callbacks.no_callbacks_defined")..".</i></td></tr>")
   end
   
   print[[</tbody></table>]]

   if has_modules then
      print[[<button class="btn btn-primary" style="float:right; margin-right:1em;" type="submit">]] print(i18n("save_configuration")) print[[</button>]]
   end

   print[[</form>]]

   print[[
<script>
</script>
]]
   
   print("<div style='margin-top:4em;'><b>" .. i18n("flow_callbacks.notes") .. ":</b><ul>")

   print("<li>" .. i18n("flow_callbacks.note_flow_lifecycle") .. "</li>")

   print("</ul></div>")
end

return flow_callbacks_utils
