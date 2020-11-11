--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local alert_utils = require "alert_utils"

local page_utils = require("page_utils")
local alerts_api = require("alerts_api")
local recording_utils = require "recording_utils"
local template = require "template_utils"

sendHTTPContentTypeHeader('text/html')

local ifid = interface.getId()

page_utils.set_active_menu_entry(page_utils.menu_entries.detected_alerts)

alert_utils.checkDeleteStoredAlerts()

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")
page_utils.print_page_title(i18n('alerts_dashboard.alerts'))

local has_engaged_alerts = alert_utils.hasAlerts("engaged", alert_utils.getTabParameters(_GET, "engaged"))
local has_past_alerts = alert_utils.hasAlerts("historical", alert_utils.getTabParameters(_GET, "historical"))
local has_flow_alerts = alert_utils.hasAlerts("historical-flows", alert_utils.getTabParameters(_GET, "historical-flows"))

if ntop.getPrefs().are_alerts_enabled == false then
   print("<div class=\"alert alert alert-warning\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png>" .. " " .. i18n("show_alerts.alerts_are_disabled_message") .. "</div>")
--return
elseif not has_engaged_alerts and not has_past_alerts and not has_flow_alerts then
   print("<div class=\"alert alert alert-info\"><i class=\"fas fa-info-circle fa-lg\" aria-hidden=\"true\"></i>" .. " " .. i18n("show_alerts.no_recorded_alerts_message").."</div>")
else
   alert_utils.drawAlertTables(has_past_alerts, has_engaged_alerts, has_flow_alerts, false, _GET, nil, nil, {
      is_standalone = true
   })

   -- PCAP modal for alert traffic extraction
   local traffic_extraction_available = recording_utils.isActive(ifid) or recording_utils.isExtractionActive(ifid)
   if traffic_extraction_available then 
      local modalID = "pcapDownloadModal"

      print[[
   <script>
   var filters_to_validate = {};
   function bpfValidator(filter_field) {
      var filter = filter_field.val();

      if (filter.trim() === "")
        return true;

      var key = filter_field.attr("name");
      var timeout = 250;

      if (!filters_to_validate[key])
         filters_to_validate[key] = {ajax_obj:null, valid:true, timer:null, submit_remind:false, last_val:null};
      var status = filters_to_validate[key];

      var sendAjax = function () {
         status.timer = null;

         var finally_check = function (valid) {
            status.ajax_obj = null;
            status.valid = valid;
            status.last_val = filter;
         }

         if (status.last_val !== filter) {
            if (status.ajax_obj)
               status.ajax_obj.abort();

            status.ajax_obj = $.ajax({
               type: "GET",
               url: ']] print(ntop.getHttpPrefix().."/lua/pro/check_profile.lua") print [[',
               data: {
                  query: filter,
               }, error: function() {
                  finally_check(status.valid);
               }, success: function(data) {
                  var valid = data.response ? true : false;
                  finally_check(valid);
               }
            });
         } else {
            // possibly process the reminder
            finally_check(status.valid);
         }
      }

      if (status.last_val === filter) {
         // Ignoring
      } else {
         if (status.timer) {
            clearTimeout(status.timer);
            status.submit_remind = false;
         }
         status.timer = setTimeout(sendAjax, timeout);
      }

      return status.valid;
   }

   function appendToFilter(filter, item, value, label) {
     if (filter.length > 0) filter += " and ";
     filter += item + (value ? (" " + value) : value);
     return filter;
   }

   function pcapDownload(item) {
     var modalID = "]] print(modalID) print [[";
     var bpf_filter = item.getAttribute('data-filter');
     var epoch_begin = item.getAttribute('data-epoch-begin');
     var epoch_end = item.getAttribute('data-epoch-end');
     var date_begin = new Date(epoch_begin * 1000);
     var date_end = new Date(epoch_begin * 1000);
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

   function checkPcapDownloadForm(form) {
     var frm = $('#'+form.id);
     var extract_now = (frm.find("[name='extract_now']:checked").val() == "1");

     if (extract_now) {
       window.open(']] print(ntop.getHttpPrefix()) print [[/lua/rest/v1/get/pcap/live_extraction.lua?' + frm.serialize(), '_self', false);
     } else {
       $.ajax({
         type: frm.attr('method'),
         url: frm.attr('action'),
         data: frm.serialize(),
         success: function (data) {
           if (data.error) {
             $('#alerts-div').html('<div class="alert alert-danger alert-dismissable"><a href="" class="close" data-dismiss="alert" aria-label="close">&times;</a>' + data.error + '</div>');
           } else {
              showExtractionAlert(data.id);

              /* update the page URL */
              var url = NtopUtils.getHistoryParameters({job_id: data.id});
              history.replaceState(history.state, "", url);
           }

           window.location.href = "#traffic-extraction-alert";
         }
       });
     }

     $('#]] print(modalID) print [[').modal('hide');
     return false;
   }

   </script>
]]

  print(template.gen("traffic_extraction_dialog.html", { dialog = {
     id = modalID,
     title = i18n("traffic_recording.pcap_download"),
     message = i18n("traffic_recording.about_to_extract_flow", {date_begin = '<span id="'.. modalID ..'_begin">', date_end = '<span id="'.. modalID ..'_end">'}),
     form_method = "post",
     validator_options = "{ custom: { bpf: bpfValidator }, errors: { bpf: '"..i18n("traffic_recording.invalid_bpf").."' } }",
     form_action = ntop.getHttpPrefix().."/lua/traffic_extraction.lua",
     form_onsubmit = "checkPcapDownloadForm",
     advanced_class = "d-none",
     extract_now_class = ternary(traffic_recording_permitted, "", "d-none"), -- hide "Queue as a Job" to users
  }}))

   print(template.gen("modal_confirm_dialog.html", { dialog = {
      id = "no-recording-data",
      title = i18n("traffic_recording.pcap_download"),
      message = "<span id='no-recording-data-message'></span>",
   }}))

   end

end -- closes if ntop.getPrefs().are_alerts_enabled == false then

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
