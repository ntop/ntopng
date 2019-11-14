--
-- (C) 2013-19 - ntop.org
--

require "os"
local ts_utils = require("ts_utils")

print [[
      <div id="footer"> <hr>
      <p id="ntopng_update_available"></p>
   ]]

local template = require "template_utils"

local have_nedge = ntop.isnEdge()
info = ntop.getInfo(true)

print [[
        <div class="container-fluid">
        <div class="row">
        <div class="col-xs-6 col-sm-4">]]
print(info["product"])

local iface_id = interface.name2id(ifname)

interface.select(ifname)
local _ifstats = interface.getStats()

printntopngRelease(info)

print(" v."..info["version"])

print("</br> ") print(i18n("please_wait_page.user")) print(" ")
print('<a href="'..ntop.getHttpPrefix()..'/lua/admin/users.lua"><span class="label label-primary">'.._SESSION["user"].. '</span></a> ' .. i18n("interface") .. ' <a href="'..ntop.getHttpPrefix()..'/lua/if_stats.lua"><span class="label label-primary" title="'..ifname..'">')

local alias = getHumanReadableInterfaceName(ifname)
print(alias)

print('</span></a>')

if have_nedge then
  print[[<form id="powerOffForm" method="post">
    <input name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" type="hidden" />
    <input name="poweroff" value="" type="hidden" />
  </form>
  <form id="rebootForm" method="post">
    <input name="csrf" value="]] print(ntop.getRandomCSRFValue()) print[[" type="hidden" />
    <input name="reboot" value="" type="hidden" />
  </form>]]

  print(
    template.gen("modal_confirm_dialog.html", {
      dialog={
        id      = "poweroff_dialog",
        action  = "$('#powerOffForm').submit()",
        title   = i18n("nedge.power_off"),
        message = i18n("nedge.power_off_confirm"),
        confirm = i18n("nedge.power_off"),
      }
    })
  )

  print(
    template.gen("modal_confirm_dialog.html", {
      dialog={
        id      = "reboot_dialog",
        action  = "$('#rebootForm').submit()",
        title   = i18n("nedge.reboot"),
        message = i18n("nedge.reboot_corfirm"),
        confirm = i18n("nedge.reboot"),
      }
    })
  )
end

if(info["pro.systemid"] and (info["pro.systemid"] ~= "")) then
   local do_show = false

   print('<br><A HREF="https://shop.ntop.org"> <span class="badge badge-warning">')
   if(info["pro.release"]) then
      if(info["pro.demo_ends_at"] ~= nil) then
         local rest = info["pro.demo_ends_at"] - os.time()
         if(rest > 0) then
            print(" " .. i18n("about.licence_expires_in", {time=secondsToTime(rest)}))
         end
      end
   else
      print(i18n("about.upgrade_to_professional"))
      do_show = true
   end
   print('</span></A>')

   if(info["pro.out_of_maintenance"] == true) then
      print('<span class="badge badge-error">') print(i18n("about.maintenance_expired", {product=info["product"]})) print('</span>')
   end

   if(do_show) then
      print('<br><iframe src="https://ghbtns.com/github-btn.html?user=ntop&repo=ntopng&type=watch&count=true" allowtransparency="true" frameborder="0" scrolling="0" width="110" height="20"></iframe>')
   end
end

print [[</font>

</div> <!-- End column 1 -->
        <div class="col-xs-4 v col-sm-4">
        <div class="row">
]]

if not have_nedge then
  print[[        <div class="col-xs-6 col-sm-6"> ]]
else
  print[[        <div class="col-md-12"> ]]
end

if not interface.isPcapDumpInterface() and not have_nedge then
   if(ifname ~= nil) then
     maxSpeed = getInterfaceSpeed(_ifstats.id)
   end
   -- io.write(maxSpeed)
   if((maxSpeed == "") or (maxSpeed == nil)) then
      -- if the speed in not custom we try to read the speed from the interface
      -- and, as a final resort, we use 1Gbps
      if tonumber(_ifstats.speed) ~= nil then
         maxSpeed = tonumber(_ifstats.speed) * 1e6
      else
         maxSpeed = 1000000000 -- 1 Gbit
      end
   else
      -- use the user-specified custom value for the speed
      maxSpeed = tonumber(maxSpeed)*1000000
   end

   addGauge('networkload', ntop.getHttpPrefix()..'/lua/if_stats.lua?ifid='..getInterfaceId(ifname).."&page=config", 100, 100, 50)
   print [[ <div class="text-center" title="All traffic detected by NTOP: Local2Local, download, upload" id="gauge_text_allTraffic"></div> ]]

   print [[
        </div>
        <div>]]
end -- closes interface.isPcapDumpInterface() == false

if not interface.isPcapDumpInterface() then
   if _ifstats.has_traffic_directions then
      print [[  <a href="]]
      print (ntop.getHttpPrefix())
      print [[/lua/if_stats.lua">
            <table style="border-collapse:collapse; !important">
            <tr><td><i class="fa fa-arrow-up" title="]] print(i18n("iface_upload", {iface=_ifstats.name})) print[["></i>&nbsp;</td><td class="network-load-chart-upload">0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</td><td class="text-right" id="chart-upload-text"></td></tr>
            <tr><td><i class="fa fa-arrow-down" title="]] print(i18n("iface_download", {iface=_ifstats.name})) print[["></i>&nbsp;</td><td class="network-load-chart-download">0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</td><td class="text-right" id="chart-download-text"></td></tr>
            </table>
            </div>
            <div class="col-xs-6 col-sm-4">
            </a>]]
   else
      print [[  <a href="]]
      print (ntop.getHttpPrefix())
      print [[/lua/if_stats.lua">
            <table style="border-collapse:collapse; !important">
            <tr><td class="network-load-chart-total">0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</td><td class="text-right" id="chart-total-text"></td></tr>
            </table>
            </div>
            <div class="col-xs-6 col-sm-4">
            </a>]]
   end
end

print [[
      </div>
    </div>
  </div><!-- End column 2 -->
  <!-- Optional: clear the XS cols if their content doesn't match in height -->
  <div class="clearfix visible-xs"></div>
  <div class="col-xs-6 col-sm-4">
    <div id="network-load">
  </div> <!-- End column 3 -->
</div>
</div>
<script>
]]

local traffic_peity_width = ternary(have_nedge, "140", "64")

local host_ts_mode = ntop.getPref("ntopng.prefs.host_ndpi_timeseries_creation")
if ntop.getPref("ntopng.prefs.host_rrd_creation") ~= "1" then
  host_ts_mode = "none"
end

-- Only show the message if the host protocol/category timeseries are enabled
local message_enabled = ((host_ts_mode ~= "none") and (host_ts_mode ~= "")) and
  (ts_utils.getDriverName() ~= "influxdb") and
  (ntop.getPref("ntopng.prefs.disable_ts_migration_message") ~= "1")

print('var is_historical = false;')
print [[
function checkMigrationMessage(data) {
  var max_local_hosts = 500;
  var enabled = ]] print(ternary(message_enabled, "true", "false")) print[[;

  if(enabled && (data.num_local_hosts > max_local_hosts))
    $("#move-rrd-to-influxdb").show();
}

$("#move-rrd-to-influxdb, #host-id-message-warning").on("close.bs.alert", function() {
  $.ajax({
      type: 'POST',
        url: ']]
print (ntop.getHttpPrefix())
print [[/lua/update_prefs.lua',
        data: {
          csrf: ']] print(ntop.getRandomCSRFValue()) print[[',
          action: this.id,
          ifid: ]] print(string.format("%u", _ifstats.id)) print[[,
        }
    });
});

var updatingChart_upload = $(".network-load-chart-upload").peity("line", { width: ]] print(traffic_peity_width) print[[, max: null });
var updatingChart_download = $(".network-load-chart-download").peity("line", { width: ]] print(traffic_peity_width) print[[, max: null, fill: "lightgreen"});
var updatingChart_total = $(".network-load-chart-total").peity("line", { width: ]] print(traffic_peity_width) print[[, max: null});

var footerRefresh = function() {
    $.ajax({
      type: 'GET',
          url: ']]
print (ntop.getHttpPrefix())
print [[/lua/rest/get/interface/data.lua',
          data: { ifid: ]] print(tostring(getInterfaceId(ifname))) print[[ },
          /* error: function(content) { alert("JSON Error (session expired?): logging out"); window.location.replace("]]
print (ntop.getHttpPrefix())
print [[/lua/logout.lua");  }, */
          success: function(rsp) {

          try {
              var values = updatingChart_upload.text().split(",")
              var values1 = updatingChart_download.text().split(",")
              var values2 = updatingChart_total.text().split(",")

              var pps = rsp.throughput_pps;
              var bps = rsp.throughput_bps * 8;
              var bps_upload = rsp.throughput.upload.bps * 8;
              var bps_download = rsp.throughput.download.bps * 8;

              if(rsp.remote_pps != 0) {
                pps = Math.max(rsp.remote_pps, 0);
              }
              if(rsp.remote_bps != 0) {
                bps = Math.max(rsp.remote_bps, 0);
                bps = Math.min(bps, rsp.speed * 1e6);
              }

              values.shift();
              values.push(bps_upload);
              updatingChart_upload.text(values.join(",")).change();
              values1.shift();
              values1.push(-bps_download);
              updatingChart_download.text(values1.join(",")).change();
              values2.shift();
              values2.push(bps);
              updatingChart_total.text(values2.join(",")).change();
              var v = bps_upload - bps_download;

]]

   if (interface.isPcapDumpInterface() == false) and (not have_nedge) then
      print[[

                $('#gauge_text_allTraffic').html("<small>"+bitsToSize(Math.min(bps, ]] print(maxSpeed) print[[), 1000) + " [" + fpackets(pps) + "]</small>");
                var v = Math.round(Math.min((bps*100)/]] print(maxSpeed) print[[, 100));
                $('#networkload').css("width", v+"%")
                $('#networkload').html(v+"%");

]]
   end

     print[[
                $('#chart-upload-text').html("&nbsp;"+bitsToSize(bps_upload, 1000));
                $('#chart-download-text').html("&nbsp;"+bitsToSize(bps_download, 1000));
                //$('#chart-total-text').html("&nbsp;"+bitsToSize(Math.min(bps, ]] print(maxSpeed) print[[), 1000));
     ]]

print[[

                var msg = "&nbsp;<i class=\"fa fa-clock-o\"></i> <small>"+rsp.localtime+" | ]] print(i18n("about.uptime")) print[[: "+rsp.uptime+"</small>";

                if(rsp.system_host_stats.mem_total !== undefined) {
                   var mem_total = rsp.system_host_stats.mem_total;
                   var mem_used = rsp.system_host_stats.mem_used;

                   var mem_used_ratio = mem_used / mem_total;
                   mem_used_ratio = mem_used_ratio * 100;
                   mem_used_ratio = Math.round(mem_used_ratio * 100) / 100;
                   mem_used_ratio = mem_used_ratio + "%";
                   $('#ram-used').html('Used: ' + mem_used_ratio + ' / Available: ' + bytesToSize((mem_total - mem_used) * 1024) + ' / Total: ' + bytesToSize(mem_total * 1024));
                   $('#ram-process-used').html('Used: ' + bytesToSize(rsp.system_host_stats.mem_ntopng_resident * 1024));
                }

                if(rsp.system_host_stats.cpu_load !== undefined)
                  $('#cpu-load-pct').html(ffloat(rsp.system_host_stats.cpu_load));

                msg += "<br>";

                if(rsp.engaged_alerts > 0 || rsp.alerted_flows > 0) {
                   var error_color = "#B94A48";  // bootstrap danger red
                   var error_label = "label-danger";
                   var error_color = error_color;
                   var color = error_color;
                   var label = error_label;

                   if(rsp.engaged_alerts > 0) {
                   msg += "&nbsp;<a href=\"]]
 print (ntop.getHttpPrefix())
print [[/lua/show_alerts.lua\">"

                    msg += "<span class=\"label " + label + "\">"+addCommas(rsp.engaged_alerts)+" <i class=\"fa fa-warning\"></i></span></A>";
                   }

                   if(rsp.alerted_flows > 0) {
                   msg += "&nbsp;<a href=\"]]
 print (ntop.getHttpPrefix())
print [[/lua/flows_stats.lua?flow_status=alerted\">"

                    msg += "<span class=\"label " + label + "\">"+addCommas(rsp.alerted_flows)+ " ]] print(i18n("flows")) print[[ <i class=\"fa fa-warning\"></i></span></A>";
                   }

                   //Push.create('Hello World!');
                }

                if((rsp.engaged_alerts > 0 || rsp.has_alerts > 0 || rsp.alerted_flows > 0) && $("#alerts-id").is(":visible") == false) {
                  $("#alerts-id").show();
                }

                if(rsp.ts_alerts && rsp.ts_alerts.influxdb) {
                  msg += "&nbsp;<a href=\"]]
print (ntop.getHttpPrefix())
print [[/lua/system/influxdb_stats.lua?ifid=]] print(tostring(getInterfaceId(ifname))) print[[&page=alerts#tab-table-engaged-alerts\">"
                  msg += "<span class=\"label label-danger\"><i class=\"fa fa-database\"></i></span></A>";
                }

                var alarm_threshold_low = 60;  /* 60% */
                var alarm_threshold_high = 90; /* 90% */
                var alert = 0;

                if(rsp.num_local_hosts > 0) {
                  msg += "&nbsp;<a href=\"]]
print (ntop.getHttpPrefix())
print [[/lua/hosts_stats.lua?mode=local\">";

                  msg += "<span title=\"]] print(i18n("local_hosts")) print[[\" class=\"label label-success\">";
                  msg += addCommas(rsp.num_local_hosts)+" <i class=\"fa fa-laptop\" aria-hidden=\"true\"></i></span></a>";

                  checkMigrationMessage(rsp);
                }

            msg += "&nbsp;<a href=\"]]
print (ntop.getHttpPrefix())
print [[/lua/hosts_stats.lua?mode=remote\">";
                var remove_hosts_label = "]] print(i18n("remote_hosts")) print[[";

                if(rsp.hosts_pctg < alarm_threshold_low) {
                  msg += "<span title=\"" + remove_hosts_label +"\" class=\"label label-default\">";
                } else if(rsp.hosts_pctg < alarm_threshold_high) {
                  alert = 1;
                  msg += "<span title=\"" + remove_hosts_label +"\" class=\"label label-warning\">";
                } else {
                  alert = 1;
                  msg += "<span title=\"" + remove_hosts_label +"\" class=\"label label-danger\">";
                }

                msg += addCommas(rsp.num_hosts-rsp.num_local_hosts)+" <i class=\"fa fa-laptop\" aria-hidden=\"true\"></i></span></a> ";

            if(typeof rsp.num_devices !== "undefined") {
              var macs_label = "]] print(i18n("mac_stats.layer_2_source_devices", {device_type=""})) print[[";
              msg += "<a href=\"]]
print (ntop.getHttpPrefix())
print [[/lua/macs_stats.lua?devices_mode=source_macs_only\">";
                if(rsp.macs_pctg < alarm_threshold_low) {
                  msg += "<span title=\"" + macs_label +"\" class=\"label label-default\">";
                } else if(rsp.macs_pctg < alarm_threshold_high) {
                  alert = 1;
                  msg += "<span title=\"" + macs_label +"\" class=\"label label-warning\">";
                } else {
                  alert = 1;
                  msg += "<span title=\"" + macs_label +"\" class=\"label label-danger\">";
                }

                msg += addCommas(rsp.num_devices)+" ]] print(i18n("devices")) print[[</span></a> ";
            }

            if(typeof rsp.num_flows !== "undefined") {
    msg += "<a href=\"]]
print (ntop.getHttpPrefix())
print [[/lua/flows_stats.lua\">";
                if(rsp.flows_pctg < alarm_threshold_low) {
                  msg += "<span class=\"label label-default\">";
                } else if(rsp.flows_pctg < alarm_threshold_high) {
                   alert = 1;
                  msg += "<span class=\"label label-warning\">";
                } else {
                   alert = 1;
                  msg += "<span class=\"label label-danger\">";
                }

                msg += addCommas(rsp.num_flows)+" ]] print(i18n("flows")) print[[ </span> </a>";

                if(rsp.flow_export_drops > 0) {
                   msg += "&nbsp;<a href=\"]]
print (ntop.getHttpPrefix())
print [[/lua/if_stats.lua\"><i class=\"fa fa-warning\" style=\"color: #B94A48;\"></i> <span class=\"label label-danger\">"+addCommas(rsp.flow_export_drops)+" Dropped flow";
                   if(rsp.flow_export_drops > 1) msg += "s";

                   msg += "</span></A> ";
                }
            }

            if((typeof rsp.num_live_captures !== "undefined") && (rsp.num_live_captures > 0)) {
                msg += "&nbsp;<a href=\"]]
                print (ntop.getHttpPrefix())
                print [[/lua/live_capture_stats.lua\">";
                msg += "<span class=\"label label-primary\">";
                msg += addCommas(rsp.num_live_captures)+" <i class=\"fa fa-download fa-lg\"></i></A> </span> ";
            }

            if(typeof rsp.remote_assistance !== "undefined") {
              var status = rsp.remote_assistance.status;
              var status_label = (status == "active") ? "success" : "danger";

              msg += "&nbsp;<a href=\"]] print(ntop.getHttpPrefix()) print[[/lua/admin/remote_assistance.lua?tab=status\"><span class=\"label label-" + status_label + "\" title=\"]]
              print(i18n("remote_assistance.remote_assistance")) print[[\">";
              msg += "<i class=\"fa fa-commenting fa-lg\"></i></span></a>";
            }

            if(typeof rsp.traffic_recording !== "undefined") {
                var status_label="primary";
                var status_title="]] print(i18n("traffic_recording.recording")) print [[";
                if (rsp.traffic_recording != "recording") {
                  status_label = "danger";
                  status_title = "]] print(i18n("traffic_recording.failure")) print [[";
                }
                msg += "&nbsp;<a href=\"]] print (ntop.getHttpPrefix()) print [[/lua/if_stats.lua?ifid=]] print(tostring(getInterfaceId(ifname))) print[[&page=traffic_recording&tab=status\">";
                msg += "<span class=\"label label-"+status_label+"\" title=\""+addCommas(status_title)+"\">";
                msg += "<i class=\"fa fa-hdd-o fa-lg\"></i></a></span>";
            }

            if(typeof rsp.traffic_extraction !== "undefined") {
                var status_title="]] print(i18n("traffic_recording.traffic_extraction_jobs")) print [[";
                var status_label = "default";
                if (rsp.traffic_extraction == "ready") status_label="primary";
                msg += "&nbsp;<a href=\"]] print (ntop.getHttpPrefix()) print [[/lua/if_stats.lua?ifid=]] print(tostring(getInterfaceId(ifname))) print[[&page=traffic_recording&tab=jobs\">";
                msg += "<span class=\"label label-"+status_label+"\" title=\""+addCommas(status_title)+"\">";
                msg += rsp.traffic_extraction_num_tasks+" <i class=\"fa fa-tasks fa-lg\"></i></a></span>";
            }

            $('#network-load').html(msg);


            if(alert) {
                $('#toomany').html("<div class='alert alert-warning'><h4>]] print(i18n("warning")) print[[</h4>]] print(i18n("about.you_have_too_many_flows", {product=info["product"]})) print[[.</div>");
            }

          } catch(e) {
             console.log(e);
             /* alert("JSON Error (session expired?): logging out"); window.location.replace("]]
print (ntop.getHttpPrefix())
print [[/lua/logout.lua");  */
          }
        }
      });
}

$(document).ajaxError(function(err, response, ajaxSettings, thrownError) {
  if((response.status == 403) && (response.responseText == "Login Required"))
    window.location.href = "]] print(ntop.getHttpPrefix().."/lua/login.lua") print[[";
});

footerRefresh();  /* call immediately to give the UI a more responsive look */
setInterval(footerRefresh, ]]

local footer_refresh_rate = ntop.getPrefs()["housekeeping_frequency"]

print(footer_refresh_rate.."")
print[[ * 1000);  /* re-schedule every [interface-rate] seconds */

//Enable tooltip without a fixer placement
$(document).ready(function () { $("[rel='tooltip']").tooltip(); });
$(document).ready(function () { $("a").tooltip({ 'selector': ''});});
$(document).ready(function () { $("i").tooltip({ 'selector': ''});});

//Automatically open dropdown-menu
$(document).ready(function(){
    $('ul.nav li.dropdown').hover(function() {
      $(this).find('.dropdown-menu').stop(true, true).delay(150).fadeIn(100);
    }, function() {
      $(this).find('.dropdown-menu').stop(true, true).delay(150).fadeOut(100);
    });
    $('.collapse')
      .on('shown.bs.collapse', function(){
        $(this).parent().find(".fa-caret-down").removeClass("fa-caret-down").addClass("fa-caret-up");
      })
      .on('hidden.bs.collapse', function(){
        $(this).parent().find(".fa-caret-up").removeClass("fa-caret-up").addClass("fa-caret-down");
    });
});

]]

-- This code rewrites the current page state after a POST request to avoid Document Expired errors
if not table.empty(_POST) then
  print[[
    if ((typeof(history) === "object")
      && (typeof(history).replaceState === "function")
      && (typeof(window.location.href) === "string"))
    history.replaceState(history.state, "", window.location.href);
  ]]
end

-- Update check
local latest_version = ntop.getCache("ntopng.cache.version")

latest_version = trimSpace(string.gsub(latest_version, "\n", ""))

if isEmptyString(latest_version) then
  print[[
  $.ajax({
      type: 'GET',
        url: ']]
print (ntop.getHttpPrefix())
print [[/lua/check_update.lua',
        data: {},
        success: function(rsp) {
          if(rsp && rsp.msg)
            $("#ntopng_update_available").html(rsp.msg);
        }
    });
  ]]
else
  local msg = get_version_update_msg(info, latest_version)

  if not isEmptyString(msg) then
    print[[
      $("#ntopng_update_available").html("]] print(msg) print[[");
    ]]
  end
end

print[[

// hide the possibly shown alerts icon in the header
]]
if not _ifstats.isView or ntop.getPrefs().are_alerts_enabled == false then
   print("$('#alerts-li').hide();")
else
   print("$('#alerts-li').show();")
end
print[[
</script>

    </div> <!-- / header main container -->

  </body>
</html> ]]
