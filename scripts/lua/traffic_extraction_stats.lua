--
-- (C) 2013-18 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
-- io.write ("Session:".._SESSION["session"].."\n")
require "lua_utils"
local recording_utils = require "recording_utils"

interface.select(ifname)

sendHTTPContentTypeHeader('text/html')

if not recording_utils.isAvailable() then
  return
end

if not isEmptyString(_POST["delete_job"]) then
  recording_utils.deleteJob(_POST["delete_job"])
end

ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

active_page = "home"
dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print("<HR><H2>"..i18n("traffic_recording.traffic_extraction_jobs").."</H2>")

print [[
  <div id="extractionjobs"></div>

  <script>
  $("#extractionjobs").datatable({
         title: "",
         url: "/lua/traffic_extraction_data.lua",
         columns: [
           {
             title: "]] print(i18n("traffic_recording.job_id")) print [[",
             field: "column_id",
             css: {textAlign:'center'},
           }, {
             title: "]] print(i18n("traffic_recording.job_date_time")) print [[",
             field: "column_job_time",
             sortable: true,
           }, {
             title: "]] print(i18n("status")) print [[",
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
             title: "]] print(i18n("traffic_recording.extracted_packets")) print [[",
             field: "column_extracted_packets",
             css: {textAlign:'right'},
           }, {
             title: "]] print(i18n("traffic_recording.extracted_bytes")) print [[",
             field: "column_extracted_bytes",
             css: {textAlign:'right'},
           }, {
             title: "]] print(i18n("actions")) print [[",
             field: "column_actions",
           }
         ],
  });

  function reloadTable() {
    $("#extractionjobs").data("datatable").render();
    setTimeout(reloadTable, 10000); /* Refresh content every a few seconds */
  }

  $(document).ready(function() {
    setTimeout(reloadTable, 10000); /* Refresh content every a few seconds */
  });

  function deleteJob(job_id) {
   var params = {}
   params.delete_job = job_id;
   params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
   paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
  }
  </script>
]]

dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
