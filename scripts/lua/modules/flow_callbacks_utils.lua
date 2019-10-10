--
-- (C) 2014-19 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
local alerts_api = require "alerts_api"
local format_utils = require "format_utils"
local user_scripts = require "user_scripts"

local flow_callbacks_utils = {}

-- ##############################################

local function print_callbacks_config_tbody_simple_view(descr)
   print[[<tbody>]]
   print[[<tr>]]
   print[[<th width=30%>]] print(i18n("flow_callbacks.callback")) print[[</th>]]
   print[[<th>]] print(i18n("flow_callbacks.callback_config")) print[[</th>]]
   print[[<th style="text-align: center;" width=20%>]] print(i18n("flow_callbacks.callback_function_duration_simple_view")) print[[</th>]]
   print[[</tr>]]

   print[[<form id="flow-callbacks-config" class="form-inline" method="post">]]
   print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

   local has_modules = false

   for _, user_script in pairsByKeys(descr.modules, asc) do
      if user_script.gui then
         if not has_modules then
            has_modules = true
         end

         print("<tr><td><b>".. i18n(user_script.gui.i18n_title) .."</b><br>")
         print("<small>"..i18n(user_script.gui.i18n_description)..".</small>\n")

         print("</td><td>")
         print(user_script.gui.input_builder(user_script))
         print("</td>")

         if user_script.benchmark and table.len(user_script.benchmark) > 0 then
            local max_duration

            for mod_fn, mod_benchmark in pairsByKeys(user_script.benchmark, asc) do
               -- Just show the maximum duration among all available functions
               if not max_duration or max_duration < mod_benchmark["tot_elapsed"] then
                  max_duration = mod_benchmark["tot_elapsed"]
               end
            end

            print(string.format("<td align='center'>%s</td>", format_utils.secondsToTime(max_duration)))

         else
            print("<td></td>")
         end

         print("</tr>")
      end
   end

   if not has_modules then
      print("<tr><td colspan=3><i>"..i18n("flow_callbacks.no_callbacks_defined")..".</i></td></tr>")
   end

   print[[</tbody>]]

   return has_modules
end

-- #################################

local function print_callbacks_config_tbody_expert_view(descr)
   print[[<tbody>]]
   print[[<tr>]]
   print[[<th colspan=2></th>]]
   print[[<th colspan=4  style="text-align: center;">]] print(i18n("flow_callbacks.callback_latest_run")) print[[</th>]]
   print[[</tr>]]

   print[[<tr>]]
   print[[<th width=30%>]] print(i18n("flow_callbacks.callback")) print[[</th>]]
   print[[<th>]] print(i18n("flow_callbacks.callback_config")) print[[</th>]]
   print[[<th>]] print(i18n("flow_callbacks.callback_function")) print[[</th>]]
   print[[<th style="text-align: center;">]] print(i18n("flow_callbacks.callback_function_duration")) print[[</th>]]
   print[[<th style="text-align: center;">]] print(i18n("flow_callbacks.callback_function_num_flows")) print[[</th>]]
   print[[<th style="text-align: right;">]] print(i18n("flow_callbacks.callback_function_throughput")) print[[</th>]]
   print[[</tr>]]

   print[[<form id="flow-callbacks-config" class="form-inline" method="post">]]
   print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

   local has_modules = false

   for _, user_script in pairsByKeys(descr.modules, asc) do
      if user_script.gui then
         if not has_modules then
            has_modules = true
         end

         local rowspan = 1
         if user_script.benchmark and table.len(user_script.benchmark) > 0 then
            rowspan = table.len(user_script.benchmark)
         end


         print("<tr><td rowspan="..rowspan.."><b>".. i18n(user_script.gui.i18n_title) .."</b><br>")
         print("<small>"..i18n(user_script.gui.i18n_description)..".</small>\n")

         print("</td><td rowspan="..rowspan..">")
         print(user_script.gui.input_builder(user_script))
         print("</td>")

         print("<td>")

         local num = 1
         if user_script.benchmark and table.len(user_script.benchmark) > 0 then
            for mod_fn, mod_benchmark in pairsByKeys(user_script.benchmark, asc) do
               local avg_fps = mod_benchmark["tot_num_calls"] / mod_benchmark["tot_elapsed"]

               if avg_fps ~= avg_fps or not avg_fps or avg_fps < 0.01 then
                  avg_fps = "< 0.01"
               else
                  avg_fps = format_utils.formatValue(format_utils.round(avg_fps, 0))
               end

               local trtd, slash_tdtr = "<tr><td>", "</td></tr>"
               if num == 1 then
                  trtd = ''
               end

               print(string.format("%s %s </td><td align='center'>%s</td><td align='center'>%s</td><td align='right'>%s %s<br>%s",
                                   trtd,
                                   mod_fn,
                                   format_utils.secondsToTime(mod_benchmark["tot_elapsed"]),
                                   format_utils.formatValue(mod_benchmark["tot_num_calls"]),
                                   avg_fps,
                                   i18n("flow_callbacks.callback_elapsed_time_avg"),
                                   slash_tdtr))

               num = num + 1
            end
         else
            print("</td><td></td><td></td><td></td></tr>")
         end
      end
   end

   if not has_modules then
      print("<tr><td colspan=6><i>"..i18n("flow_callbacks.no_callbacks_defined")..".</i></td></tr>")
   end

   print[[</tbody>]]

   return has_modules
end

-- #################################

function flow_callbacks_utils.print_callbacks_config()
   local show_advanced_prefs = false
   if _POST and _POST["show_advanced_prefs"] and _POST["show_advanced_prefs"] == "true" then
      show_advanced_prefs = true
   end

   local ifid = interface.getId()
   local descr = user_scripts.load(user_scripts.script_types.flow, ifid, "flow", nil, true --[[ also return disabled ]])

   print [[

<br>
<table id="callbacks_config_table" class="table table-bordered table-striped" style="clear: both">
<thead></thead>]]

   if table.len(_POST) > 0 then
      for mod_key, user_script in pairs(descr.modules) do
         local pref_key = "enabled_" .. mod_key
         local val = _POST[pref_key]

         if(val ~= nil) then
            if(val == "on") then
               user_scripts.enableModule(ifid, "flow", mod_key)
               user_script.enabled = true
            else
               user_scripts.disableModule(ifid, "flow", mod_key)
               user_script.enabled = false
            end
         end
      end
   end

   local has_modules

   if show_advanced_prefs then
      has_modules = print_callbacks_config_tbody_expert_view(descr)
   else
      has_modules = print_callbacks_config_tbody_simple_view(descr)
   end

   print[[</table>]]

   if has_modules then
      print[[<input type=hidden name="show_advanced_prefs" value="]]if show_advanced_prefs then print("true") else print("false") end print[["/>]]
      print[[<button class="btn btn-primary" style="float:right; margin-right:1em;" type="submit">]] print(i18n("save_configuration")) print[[</button>]]
   end

   print[[</form>]]
   print[[

<form method="post">
  <input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print [[" />
  <input type=hidden name="show_advanced_prefs" value="]]if show_advanced_prefs then print("false") else print("true") end print[["/>

  <div class="btn-group btn-toggle">
]]

   local cls_on      = "btn btn-sm"
   local cls_off     = cls_on

   if show_advanced_prefs then
      cls_on  = cls_on..' btn-primary active'
      cls_off = cls_off..' btn-default'
   else
      cls_on = cls_on..' btn-default'
      cls_off = cls_off..' btn-primary active'
   end

   print('<button type="button" class="'..cls_on..'" onclick="this.form.submit();">'..i18n("prefs.expert_view")..'</button>')
   print('<button type="button" class="'..cls_off..'" onclick="this.form.submit();">'..i18n("prefs.simple_view")..'</button>')

   print[[
  </div>
</form>

<script>
</script>
]]

   print("<div style='margin-top:4em;'><b>" .. i18n("flow_callbacks.notes") .. ":</b><ul>")

   print("<li>" .. i18n("flow_callbacks.note_flow_lifecycle") .. "</li>")

   print("<li>" .. i18n("flow_callbacks.note_create_custom_scripts", {url = "https://github.com/ntop/ntopng/blob/dev/doc/README.developers.flow_lua_callbacks.md"}) .. "</li>")
   print("<li>" .. i18n("flow_callbacks.note_add_custom_scripts", {url = ntop.getHttpPrefix().."/lua/directories.lua", product=ntop.getInfo()["product"]}) .. "</li>")

   print("</ul></div>")
end

return flow_callbacks_utils
