function drawAlertSourceSettings(entity_type, alert_source, delete_button_msg, delete_confirm_msg, page_name, page_params, alt_name, show_entity, options)
   options = options or {}
   local tab = _GET["tab"] or "min"
   local ts_utils = require("ts_utils")
   local ifid = interface.getId()
   local entity_value = alert_source
   local subdir = entity_type

   if interface.isPcapDumpInterface() then
      if entity_type == "interface" then
         tab = "flows"
      else
         return
      end
   else
      local function printTab(tab, content, sel_tab)
         if(tab == sel_tab) then print("\t<li class='nav-item active show'>") else print("\t<li class='nav-item'>") end
         print("<a class='nav-link' href=\""..ntop.getHttpPrefix().."/lua/"..page_name.."?page=callbacks&tab="..tab)
         for param, value in pairs(page_params) do
            print("&"..param.."="..value)
         end
         print("\">"..content.."</a></li>\n")
      end

      print('<ul class="nav nav-tabs">')

      for k, granularity in pairsByField(alert_consts.alerts_granularities, "granularity_id", asc) do
         local l = i18n(granularity.i18n_title)
         local resolution = granularity.granularity_seconds

         if (not options.remote_host) or resolution <= 60 then
	    --~ l = '<i class="fas fa-cog" aria-hidden="true"></i>&nbsp;'..l
	    printTab(k, l, tab)
         end
      end

      if(entity_type == "interface") then
         local l = i18n("flows")
         printTab("flows", l, tab)
      end

      if tab ~= "flows" then
         local granularity_label = alertEngineLabel(alert_consts.alertEngine(tab))

         print(
	    template.gen("modal_confirm_dialog.html", {
			 dialog={
			    id      = "deleteAlertSourceSettings",
			    action  = "deleteAlertSourceSettings()",
			    title   = i18n("show_alerts.delete_alerts_configuration"),
			    message = i18n(delete_confirm_msg, {granularity=granularity_label}) .. " <span style='white-space: nowrap;'>" .. ternary(alt_name ~= nil, alt_name, alert_source).."</span>?",
			    confirm = i18n("delete")
			 }
            })
         )

         print(
	    template.gen("modal_confirm_dialog.html", {
			 dialog={
			    id      = "deleteGlobalAlertConfig",
			    action  = "deleteGlobalAlertConfig()",
			    title   = i18n("show_alerts.delete_alerts_configuration"),
			    message = i18n("show_alerts.delete_config_message", {conf = entity_type, granularity=granularity_label}).."?",
			    confirm = i18n("delete")
			 }
	    })
         )
      end
      print('</ul>')
   end -- !isPcapDumpInterface

   if((tab == "flows") and (entity_type == "interface")) then
      local flow_callbacks_utils = require "flow_callbacks_utils"
      flow_callbacks_utils.print_callbacks_config()
   else
      local available_modules = user_scripts.load(interface.getId(), user_scripts.script_types.traffic_element, entity_type)
      local no_modules_available = table.len(available_modules.modules) == 0

      if((_POST["to_delete"] ~= nil) and (_POST["SaveAlerts"] == nil)) then
         if _POST["to_delete"] == "local" then
	    user_scripts.deleteSpecificConfiguration(subdir, available_modules, tab, entity_value)
         else
	    user_scripts.deleteGlobalConfiguration(subdir, available_modules, tab, options.remote_host)
         end
      elseif(not table.empty(_POST)) then
	 user_scripts.handlePOST(subdir, available_modules, tab, entity_value, options.remote_host)
      end

      local label

      if entity_type == "host" then
        if options.remote_host then
          label = i18n("remote_hosts")
        else
          label = i18n("alerts_thresholds_config.active_local_hosts")
        end
      else
        label = firstToUpper(entity_type) .. "s"
      end

      print [[
       </ul>
       <form method="post">
       <br>
       <table id="user" class="table table-bordered table-striped" style="clear: both"> <tbody>
       <tr><th width"40%">]] print(i18n("alerts_thresholds_config.threshold_type")) print[[</th>]]
      if(tab == "min") then
         print[[<th class="text-center" width=5%>]] print(i18n("chart")) print[[</th>]]
      end
      print[[<th width=20%>]] print(i18n("alerts_thresholds_config.thresholds_single_source", {source=firstToUpper(entity_type),alt_name=ternary(alt_name ~= nil, alt_name, alert_source)})) print[[</th><th width=20%>]] print(i18n("alerts_thresholds_config.common_thresholds_local_sources", {source=label}))
      print[[</th><th style="text-align: center;">]] print(i18n("flow_callbacks.callback_latest_run")) print[[</th></tr>]]
      print('<input id="csrf" name="csrf" type="hidden" value="'..ntop.getRandomCSRFValue()..'" />\n')

      if no_modules_available then
	 if areAlertsEnabled() then
	    print[[<tr><td colspan=5>]] print(i18n("flow_callbacks.no_callbacks_available")) print[[.</td></tr>]]
	 else
	    print[[<tr><td colspan=5>]] print(i18n("flow_callbacks.no_callbacks_available_disabled_alerts", {url = ntop.getHttpPrefix().."/lua/admin/prefs.lua?tab=alerts"})) print[[.</td></tr>]]
	 end
      else
	 local benchmarks = user_scripts.getLastBenchmark(ifid, entity_type)

	 for mod_k, user_script in pairsByKeys(available_modules.modules, asc) do
	    local key = user_script.key
	    local gui_conf = user_script.gui
	    local show_input = true

	    if user_script.granularity then
	       -- check if the check is performed and thus has to
	       -- be configured at this granularity
	       show_input = false

	       for _, gran in pairs(user_script.granularity) do
		  if gran == tab then
		     show_input = true
		     break
		  end
	       end
	    end

	    if(user_script.local_only and options.remote_host) then
	       show_input = false
	    end

	    if not gui_conf or not show_input then
	       goto next_module
	    end

	    local url = ''

	    if(user_script.plugin.edition == "community") then
	       local path = string.sub(user_script.source_path, string.len(ntop.getDirs().scriptdir)+1)
	       url = '<A HREF="/lua/code_viewer.lua?lua_script_path='..path..'"><i class="fas fa-lg fa-binoculars"></i></A>'
	    end
            
	    print("<tr><td><b>".. (i18n(gui_conf.i18n_title) or gui_conf.i18n_title) .. " " .. url .."</b><br>")
	    print("<small>".. (i18n(gui_conf.i18n_description) or gui_conf.i18n_description) .."</small>\n")

	    if(tab == "min") then
	       print("<td class='text-center'>")
	       if ts_utils.exists("elem_user_script:duration", {ifid=ifid, user_script=mod_k, subdir=entity_type}) then
		  print('<a href="'.. ntop.getHttpPrefix() ..'/lua/user_script_details.lua?ifid='..ifid..'&user_script='..
			   mod_k..'&subdir='..entity_type..'"><i class="fas fa-chart-area fa-lg"></i></a>')
	       end
	    end

	    for _, prefix in pairs({"", "global_"}) do
	       if user_script.gui.input_builder then
		  local k = prefix..key
		  local is_global = (prefix == "global_")
		  local conf

		  print("</td><td>")

		  if is_global then
		     conf = user_scripts.getGlobalConfiguration(user_script, tab, options.remote_host)
		  else
		     conf = user_scripts.getConfiguration(user_script, tab, entity_value, options.remote_host)
		  end

		  if(conf ~= nil) then
		     -- TODO remove after implementing the new gui
		     local value = ternary(user_script.gui.post_handler == user_scripts.checkbox_post_handler, conf.enabled, conf.script_conf)

		     print(user_script.gui.input_builder(user_script.gui or {}, k, value))
		  end
	       end
	    end
	    print("</td><td align='center'>\n")

	    local script_benchmark = benchmarks[mod_k]

	    if script_benchmark and (script_benchmark[tab] or script_benchmark["all"]) then
	       local hook = ternary(script_benchmark[tab], tab, "all")

	       if script_benchmark[hook]["tot_elapsed"] then
		  if script_benchmark[hook]["tot_num_calls"] > 1 then
		     print(i18n("flow_callbacks.callback_function_duration_fmt_long",
				{num_calls = format_utils.formatValue(script_benchmark[hook]["tot_num_calls"]),
				 time = format_utils.secondsToTime(script_benchmark[hook]["tot_elapsed"]),
				 speed = format_utils.formatValue(round(script_benchmark[hook]["avg_speed"], 0))}))
		  else
		     print(i18n("flow_callbacks.callback_function_duration_fmt_short",
				{time = format_utils.secondsToTime(script_benchmark[hook]["tot_elapsed"])}))
		  end
	       end
	    end

	    print("</td></tr>\n")
	    ::next_module::
	 end
      end

      print [[</tbody> </table>]]

      if not no_modules_available then
	 print[[
      <input type="hidden" name="SaveAlerts" value="">

      <button class="btn btn-primary" style="float:right; margin-right:1em;" disabled="disabled" type="submit">]] print(i18n("save_configuration")) print[[</button>
      </form>

      <button type="button" class="btn btn-secondary" data-toggle="modal" data-target="#deleteGlobalAlertConfig" style="float:right; margin-right:1em;"> ]] print(i18n("show_alerts.delete_config_btn",{conf=firstToUpper(entity_type)})) print[[</button>
      <button type="button" class="btn btn-secondary" data-toggle="modal" data-target="#deleteAlertSourceSettings" style="float:right; margin-right:1em;"> ]] print(delete_button_msg) print[[</button>
      ]]
      end

      print("<div style='margin-top:4em;'><b>" .. i18n("alerts_thresholds_config.notes") .. ":</b><ul>")

      print("<li>" .. i18n("alerts_thresholds_config.note_control_threshold_checks_periods") .. "</li>")
      print("<li>" .. i18n("alerts_thresholds_config.note_thresholds_expressed_as_delta") .. "</li>")
      print("<li>" .. i18n("alerts_thresholds_config.note_consecutive_checks") .. "</li>")

      if (entity_type == "host") then
    print("<li>" .. i18n("alerts_thresholds_config.note_checks_on_active_hosts") .. "</li>")
      end

      print("<li>" .. i18n("alerts_thresholds_config.note_create_custom_scripts", {url = "https://github.com/ntop/ntopng/blob/dev/doc/README.alerts.md"}) .. "</li>")
      print("<li>" .. i18n("flow_callbacks.note_add_custom_scripts", {url = ntop.getHttpPrefix().."/lua/directories.lua", product=ntop.getInfo()["product"]}) .. "</li>")
      print("<li>" .. i18n("flow_callbacks.note_scripts_list", {url = ntop.getHttpPrefix().."/lua/user_scripts_overview.lua", product=ntop.getInfo()["product"]}) .. "</li>")

      print("</ul></div>")

      print[[
      <script>
         function deleteAlertSourceSettings() {
            var params = {};

            params.to_delete = "local";
            params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

            var form = paramsToForm('<form method="post"></form>', params);
            form.appendTo('body').submit();
         }

         function deleteGlobalAlertConfig() {
            var params = {};

            params.to_delete = "global";
            params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";

            var form = paramsToForm('<form method="post"></form>', params);
            form.appendTo('body').submit();
         }

         aysHandleForm("form", {
            handle_tabs: true,
         });
      </script>
      ]]
   end
end
