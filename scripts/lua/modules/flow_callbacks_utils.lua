--
-- (C) 2014-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local alerts_api = require "alerts_api"

local CALLBACK_EVENTS = {
   application_detected = {
      cb = "protocolDetected",
      i18n = "flow_callbacks.application_detected",
      i18n_note = "flow_callbacks.note_flow_application_detected",
   },
   status_changed = {
      cb = "statusChanged",
      i18n = "flow_callbacks.status_changed",
      i18n_note = "flow_callbacks.note_flow_staus_changed",
   },
   periodic_update = {
      cb = "periodicUpdate",
      i18n = "flow_callbacks.periodic_update",
      i18n_note = "flow_callbacks.note_flow_periodic_update",
   },
   idle = {
      cb = "idle",
      i18n = "flow_callbacks.idle",
      i18n_note = "flow_callbacks.note_flow_idle",
   }
}

local flow_callbacks_utils = {}

-- #################################

local function print_callbacks_config_tab(tab, tab_contents, selected_tab)
   if tab == selected_tab then
      print("\t<li class=active>") else print("\t<li>")
   end

   print("<a href=\""..ntop.getHttpPrefix().."/lua/if_stats.lua?page=flow_callbacks&tab="..tab)
   for param, value in pairs(page_params or {}) do
      print("&"..param.."="..value)
   end

   print("\">"..i18n(tab_contents.i18n).."</a></li>\n")
end

-- #################################

function flow_callbacks_utils.print_callbacks_config()
   local tab = _GET["tab"] or "application_detected"
   local descr = alerts_api.load_flow_check_modules(entity_type)

   print('<ul class="nav nav-tabs">')

   for cur_k, cur_tab in pairsByKeys(CALLBACK_EVENTS or {}) do
      print_callbacks_config_tab(cur_k, cur_tab, tab)
   end

   print('</ul>')

   print [[

<br>
<table id="callbacks_config_table" class="table table-bordered table-striped" style="clear: both">
<thead></thead>
<tbody>]]
   print[[<tr>]]
   print[[<th width=30%>]] print(i18n("flow_callbacks.callback")) print[[</th>]]
   print[[<th width=5%  style="text-align:center">]] print(i18n("flow_callbacks.callback_enabled")) print[[</th>]]
   print[[<th>]] print(i18n("flow_callbacks.callback_config")) print[[</th>]]
   print[[</tr>]]

   print[[<form id="flow-callbacks-config" class="form-inline" method="post">]]
   print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

   local has_modules = false
   local callback_name = CALLBACK_EVENTS[tab]["cb"]
   for _, check_module in pairsByKeys(descr[callback_name], asc) do
      if check_module[callback_name] and check_module.gui then
	 if not has_modules then
	    has_modules = true
	 end

         print("<tr><td><b>".. i18n(check_module.gui.i18n_title) .."</b><br>")
         print("<small>"..i18n(check_module.gui.i18n_description)..".</small>\n")

	 print('</td><td align="center">')

	 print(alerts_api.checkbox_input_builder(check_module.gui, string.format("enabled_%s", check_module.key), check_module.conf.enabled))

	 print("</td><td>")

	 print(check_module.gui.input_builder(check_module.gui, nil --[[ current key --]], nil --[[ current val for key --]]))

	 print("</td></tr>")
      end
   end

   if not has_modules then
      print("<tr><td colspan=3><i>"..i18n("flow_callbacks.no_callbacks_defined", {cb = callback_name})..".</i></td></tr>")
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
   print("<li>" .. i18n(CALLBACK_EVENTS[tab]["i18n_note"]) .. "</li>")

   print("</ul></div>")
end

return flow_callbacks_utils
