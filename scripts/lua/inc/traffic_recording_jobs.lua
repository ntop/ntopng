--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()

require "lua_utils"
local template = require "template_utils"
local recording_utils = require "recording_utils"
local ifid = getInterfaceId(ifname)

if((not isAdministrator()) or (not recording_utils.isAvailable()) or (not ntop.isEnterpriseM())) then
  return
end

if not isEmptyString(_POST["job_action"]) then
  if not isEmptyString(_POST["job_id"]) then
    if _POST["job_action"] == "delete" then
      recording_utils.deleteJob(_POST["job_id"])
    elseif _POST["job_action"] == "stop" then
      recording_utils.stopJob(_POST["job_id"])
    end
  else
    -- no job id
    if _POST["job_action"] == "delete" then
      recording_utils.deleteAndStopAllJobs(ifid)
    end
  end
end

print("<H2>"..i18n("traffic_recording.traffic_extraction_jobs") .. "</H2>")

print(template.gen("modal_confirm_dialog.html", {
  dialog = {
    id      = "PcapDownloadDialog",
    title   = i18n("traffic_recording.download"),
    custom_alert_class = "alert alert-info",
    message = i18n("traffic_recording.multiple_extracted_files", { mb = tostring(math.floor(prefs.max_extracted_pcap_bytes/(1024*1024))) })
 }
}))

print(
  template.gen("modal_confirm_dialog.html", {
    dialog={
      id      = "PcapDeleteJobDialog",
      action  = "deleteJob(selected_job_id)",
      title   = i18n("traffic_recording.delete_job"),
      message = i18n("traffic_recording.delete_job_confirm", {job_id = "<span id='job_to_delete'></span>"}),
      confirm = i18n("delete"),
    }
  })
)

print(
  template.gen("modal_confirm_dialog.html", {
    dialog={
      id      = "PcapStopJobDialog",
      action  = "stopJob(selected_job_id)",
      title   = i18n("traffic_recording.stop_job"),
      message = i18n("traffic_recording.stop_job_confirm", {job_id = "<span id='job_to_stop'></span>"}),
      confirm = i18n("stop"),
    }
  })
)

print(
  template.gen("modal_confirm_dialog.html", {
    dialog={
      id      = "PcapDeleteAllDialog",
      action  = "deleteAllExtractionJobs()",
      title   = i18n("traffic_recording.delete_all_jobs"),
      message = i18n("traffic_recording.delete_all_jobs_confirm"),
      confirm = i18n("delete"),
    }
  })
)

print [[
  <div id="extractionjobs"></div>

  <button class="btn btn-secondary" onclick="$('#PcapDeleteAllDialog').modal('show');" style="float:right; margin-right:1em;"><i class="fas fa-trash" aria-hidden="true" data-original-title="" title=""></i> ]] print(i18n("show_alerts.delete_all")) print[[</button>

  <br><br>
  <span>]]
print(i18n("notes"))
print[[
  <ul>
      <li>]] print(i18n("traffic_recording.note_dump")) print[[</li>]]
   print[[
    </ul>
  </span>

  <script>
  var selected_job_id = null;

  $("#extractionjobs").datatable({
         title: "",
         url: "/lua/traffic_extraction_data.lua",]]

  -- Sort by column_id if a specific job_id is set to show it in the first table page
  if not isEmptyString(_GET["job_id"]) then
    print[[
      sort: [ ["column_id", "desc"] ],
    ]]
  end

  print[[
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
             title: "]] print(i18n("chart")) print [[",
             field: "column_chart",
             sortable: false,
             css: {textAlign:'center'},
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
         ], rowCallback: function(row, data) {
            var actions_td_idx = 10;
            var job_id = data.column_id;
            var num_job_files = data.column_job_files;
            var job_status = data.column_status_raw;

            if(job_id == "]] print(_GET["job_id"] or "") print[[")
              row.addClass("info");

            if(num_job_files > 1) {
              var links = "<ul>";

              for(var file_id=0; file_id<num_job_files; file_id++)
                links = links + "<li><a href=\\']] print(ntop.getHttpPrefix())
                print[[/lua/get_extracted_traffic.lua?job_id=" + job_id + "&file_id=" + file_id + "\\'>" + "]]
                print(i18n("traffic_recording.download_nth_pcap")) print[[".sformat(file_id) + "</a></li>";

              links = links + "</ul>";

              datatableAddActionButtonCallback.bind(row)(actions_td_idx,
                "downloadJobFiles('" + links + "')", "]] print(i18n("download")) print[[");
            } else if (num_job_files == 1) {
              datatableAddLinkButtonCallback.bind(row)(actions_td_idx,
                "]] print(ntop.getHttpPrefix()) print[[/lua/get_extracted_traffic.lua?job_id=" + job_id, "]] print(i18n("download")) print[[");
            }

            if(job_status === "processing") {
              datatableAddDeleteButtonCallback.bind(row)(actions_td_idx,
                "$('#job_to_stop').html('"+ job_id +"'); selected_job_id = "+ job_id +"; $('#PcapStopJobDialog').modal('show')", "]] print(i18n("stop")) print[[");
            } else {
              datatableAddDeleteButtonCallback.bind(row)(actions_td_idx,
                "$('#job_to_delete').html('"+ job_id +"'); selected_job_id = "+ job_id +"; $('#PcapDeleteJobDialog').modal('show')", "]] print(i18n("delete")) print[[");
            }

            return row;
         }
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
    NtopUtils.paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
  }

  function stopJob(job_id) {
    var params = {}
    params.job_action = 'stop';
    params.job_id = job_id;
    params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
    NtopUtils.paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
  }

  function deleteAllExtractionJobs() {
    var params = {}
    params.job_action = 'delete';
    params.csrf = "]] print(ntop.getRandomCSRFValue()) print[[";
    NtopUtils.paramsToForm('<form method="post"></form>', params).appendTo('body').submit();
  }
  </script>
]]
