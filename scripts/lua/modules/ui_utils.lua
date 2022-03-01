--
-- (C) 2020-22 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local json = require("dkjson")
local template_utils = require("template_utils")

local ui_utils = {}

function ui_utils.render_configuration_footer(item,page)
   local ret = template_utils.gen('pages/components/manage-configuration-link.template', {item = item})

   if(((page == "host") or (page == nil))
      and (item == "pool") and (ntop.isPro() or ntop.isEnterpriseM() or ntop.isEnterpriseL())) then
      ret = ret .. template_utils.gen('pages/components/export-policy-configuration-link.template')
   end
   
   return ret
end

--- Single note element: { content = 'note description', hidden = true|false }
function ui_utils.render_notes(notes_items, title, is_ordered)

    if notes_items == nil then
        traceError(TRACE_DEBUG, TRACE_CONSOLE, "The notes table is nil!")
        return ""
    end

    return template_utils.gen("pages/components/notes.template", {
        notes = notes_items,
        is_ordered = is_ordered,
        title = title
    })
end

function ui_utils.render_breadcrumb(title, items, icon)
    return template_utils.gen("pages/components/breadcrumb.template", {
        items = items,
        i18n_title = title,
        breadcrumb_icon = icon
    })
end

function ui_utils.render_pools_dropdown(pools_instance, member, key)

    if (pools_instance == nil) then
        traceError(TRACE_DEBUG, TRACE_CONSOLE, "The pools instance is nil!")
        return ""
    end

    if (member == nil) then
        traceError(TRACE_DEBUG, TRACE_CONSOLE, "The member is nil!")
        return ""
    end

    local selected_pool = pools_instance:get_pool_by_member(member)
    local selected_pool_id = selected_pool and selected_pool.pool_id or pools_instance.DEFAULT_POOL_ID

    local all_pools = pools_instance:get_all_pools()

    return template_utils.gen("pages/components/pool-select.template", {
        pools = all_pools,
        selected_pool_id = selected_pool_id,
        key = key,
    })
end

function ui_utils.create_navbar_title(title, subpage, title_link)
    if isEmptyString(subpage) then return title end
    return "<a href='".. title_link .."'>".. title .. "</a>&nbsp;/&nbsp;<span>"..subpage.."</span>"
end

--- Shortcut function to print a togglw switch inside the requested page
function ui_utils.print_toggle_switch(context)
    print(template_utils.gen("on_off_switch.html", context))
end

function ui_utils.render_table_picker(name, context, modals)
    template_utils.render("pages/table_picker.template", {
        ui_utils = ui_utils,
        json = json,
        template_utils = template_utils,
        modals = modals or {},
        datasource = context.datasource, -- the data provider
        datatable = {
            name = name, -- the table name
            columns = context.table.columns, -- the columns to print inside the table
            js_columns = context.table.js_columns, -- a custom javascript code to format the columns
        }
    })
end

---Render a Tags Input box.
--@param name The component unique name
---@param tags A table containing the values
---@return string
function ui_utils.render_tag_input(name, tags)
    local options = {
       instance_name = name,
       json = json,
       tags = tags or {}, -- initial tags
    }

    return template_utils.gen("pages/components/tag-input.template", options)
end

-- Render a dialog and js code to download a pcap from recorded traffic
function ui_utils.draw_pcap_download_dialog(ifid)
   local modalID = "pcapDownloadModal"

   print[[
   <script>
   function bpfValidator(filter_field) {
      // no pre validation required as the user is not
      // supposed to edit the filter here
      return true;
   }

   function pcapShowModal(epoch_begin, epoch_end, bpf_filter) {
     var modalID = "]] print(modalID) print [[";
     var date_begin = new Date(epoch_begin * 1000);
     var date_end = new Date(epoch_end * 1000);
     var epoch_begin_formatted = $.datepicker.formatDate('M dd, yy ', date_begin)+date_begin.getHours()
       +":"+date_begin.getMinutes()+":"+date_begin.getSeconds(); 
     var epoch_end_formatted = $.datepicker.formatDate('M dd, yy ', date_end)
       +date_end.getHours()+":"+date_end.getMinutes()+":"+date_end.getSeconds();

     $('#'+modalID+'_ifid').val(]] print(ifid) print [[);
     $('#'+modalID+'_epoch_begin').val(epoch_begin);
     $('#'+modalID+'_epoch_end').val(epoch_end);
     $('#'+modalID+'_begin').text(epoch_begin_formatted);
     $('#'+modalID+'_end').text(epoch_end_formatted);
     $('#'+modalID+'_query_items').html("");
     $('#'+modalID+'_chart_link').val("");

     $('#'+modalID+'_bpf_filter').val(bpf_filter);
     $('#'+modalID).modal('show');

     $("#]] print(modalID) print [[ form:data(bs.validator)").each(function(){
       $(this).data("bs.validator").validate();
     });
   }

   function pcapDownload(epoch_begin, epoch_end, bpf_filter) {
     $.ajax({
       type: "GET",
       url: ']] print(ntop.getHttpPrefix().."/lua/check_recording_data.lua") print [[',
       data: {
         epoch_begin: epoch_begin,
         epoch_end: epoch_end
       }, error: function(err) {
         console.error(err);
       }, success: function(data) {
         if(!data.available) {
            if(data.extraction_checks_msg) {
              $("#no-recording-data-message").html(data.extraction_checks_msg);
            } else {
              $("#no-recording-data-message").html(']] print(i18n("traffic_recording.no_recorded_data")) print[[');
            }
            $("#no-recording-data").modal("show");
            return;
         }
      
         pcapShowModal(epoch_begin, epoch_end, bpf_filter);
       }
     });
   }

   function submitPcapDownload(form) {
     var frm = $('#'+form.id);
     window.open(']] print(ntop.getHttpPrefix()) print [[/lua/rest/v2/get/pcap/live_extraction.lua?' + frm.serialize(), '_self', false);
     $('#]] print(modalID) print [[').modal('hide');
     return false;
   }

   </script>
]]

  print(template_utils.gen("traffic_extraction_dialog.html", { dialog = {
     id = modalID,
     title = i18n("traffic_recording.pcap_download"),
     message = i18n("traffic_recording.about_to_download_flow", {date_begin = '<span id="'.. modalID ..'_begin">', date_end = '<span id="'.. modalID ..'_end">'}),
     submit = i18n("traffic_recording.download"),
     form_method = "post",
     validator_options = "{ custom: { bpf: bpfValidator }, errors: { bpf: '"..i18n("traffic_recording.invalid_bpf").."' } }",
     form_action = ntop.getHttpPrefix().."/lua/traffic_extraction.lua",
     form_onsubmit = "submitPcapDownload",
     advanced_class = "d-none",
     extract_now_class = "d-none", -- direct download only
  }}))

   print(template_utils.gen("modal_confirm_dialog.html", { dialog = {
      id = "no-recording-data",
      title = i18n("traffic_recording.pcap_download"),
      message = "<span id='no-recording-data-message'></span>",
      confirm = i18n("confirm"),
      dismiss_on_confirm = true,
   }}))

end

return ui_utils
