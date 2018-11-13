--
-- (C) 2013-18 - ntop.org
--

local dirs = ntop.getDirs()

require "lua_utils"
local template = require "template_utils"
local recording_utils = require "recording_utils"

if((not isAdministrator()) or (not recording_utils.isAvailable())) then
  return
end

if not isEmptyString(_POST["job_action"]) and not isEmptyString(_POST["job_id"]) then
  if _POST["job_action"] == "delete" then
    recording_utils.deleteJob(_POST["job_id"])
  elseif _POST["job_action"] == "stop" then
    recording_utils.stopJob(_POST["job_id"])
  end
end

print("<H2>"..i18n("traffic_recording.traffic_extraction_jobs") .. "</H2>")

print(template.gen("modal_confirm_dialog.html", {
  dialog = {
    id      = "PcapDownloadDialog",
    title   = i18n("traffic_recording.download"),
    custom_alert_class = "alert alert-info",
    message = i18n("traffic_recording.multiple_extracted_files", { mb = prefs.max_extracted_pcap_mbytes })
 }
}))

print [[
  <div id="extractionjobs"></div>

  <span>
    <ul>]]
print(i18n("notes"))
print [[
      <li>]] print(i18n("traffic_recording.note_dump")) print[[</li>]]
   print[[
    </ul>
  </span>

  <script>
  $("#extractionjobs").datatable({
         title: "",
         url: "/lua/traffic_extraction_data.lua",
         columns: [
           {
             title: "]] print(i18n("traffic_recording.job_id")) print [[",
             field: "column_id",
             sortable: true,
             css: {textAlign:'center'},
           }, {
             title: "]] print(i18n("traffic_recording.job_date_time")) print [[",
             field: "column_job_time",
             sortable: true,
           }, {
             title: "]] print(i18n("status")) print [[",
             sortable: true,
             field: "column_status",
           }, {
             title: "]] print(i18n("report.begin_date_time")) print [[",
             field: "column_begin_time",
           }, {
             title: "]] print(i18n("report.end_date_time")) print [[",
             field: "column_end_time",
           }, {
             title: "]] print(i18n("traffic_recording.filter_bpf")) print [[",
             field: "column_bpf_filter",
           }, {
             title: "]] print(i18n("packets")) print [[",
             field: "column_extracted_packets",
             sortable: true,
             css: {textAlign:'right'},
           }, {
             title: "]] print(i18n("bytes")) print [[",
             field: "column_extracted_bytes",
             sortable: true,
             css: {textAlign:'right'},
           }, {
             title: "]] print(i18n("actions")) print [[",
             field: "column_actions",
             css: {textAlign:'center'},
           }
         ],
  });

  function downloadJobFiles(links) {
    $('#PcapDownloadDialog_more_content').html(links);
    $('#PcapDownloadDialog').modal('show');
  }

  function deleteJob(job_id) {
    var params = {}
    params.job_action = 'delete';
    params.job_id = job_id;
    params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
    paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
  }

  function stopJob(job_id) {
    var params = {}
    params.job_action = 'stop';
    params.job_id = job_id;
    params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
    paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
  }
  </script>
]]
