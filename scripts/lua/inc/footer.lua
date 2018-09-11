--
-- (C) 2013-18 - ntop.org
--

require "os"

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
  print[[	 <div class="col-xs-6 col-sm-6"> ]]
else
  print[[	 <div class="col-md-12"> ]]
end

if (interface.isPcapDumpInterface() == false) and (not have_nedge) then
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
   print [[ <div class="text-center" title="All traffic detected by NTOP: Local2Local, Remote2Local, Local2Remote" id="gauge_text_allTraffic"></div> ]]

   print [[
	</div>
	<div>]]
   print [[  <a href="]]
   print (ntop.getHttpPrefix())
   print [[/lua/if_stats.lua">
	    <table style="border-collapse:collapse; !important">
	    <tr><td title="Local to Remote Traffic"><i class="fa fa-cloud-upload"></i>&nbsp;</td><td class="network-load-chart-local2remote">0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</td><td class="text-right" id="chart-local2remote-text"></td></tr>
	    <tr><td title="Remote to Local Traffic"><i class="fa fa-cloud-download"></i>&nbsp;</td><td class="network-load-chart-remote2local">0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</td><td class="text-right" id="chart-remote2local-text"></td></tr>
	    </table>
	    </div>
	    <div class="col-xs-6 col-sm-4">
	    </a>
]]

end -- closes interface.isPcapDumpInterface() == false 

if have_nedge then
   print [[  <a href="]]
   print (ntop.getHttpPrefix())
   print [[/lua/if_stats.lua">
	    <table style="border-collapse:collapse; !important">
	    <tr><td title="Upload"><i class="fa fa-cloud-upload"></i>&nbsp;</td><td class="network-load-chart-local2remote">0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</td><td class="text-right" id="chart-local2remote-text"></td></tr>
	    <tr><td title="Download"><i class="fa fa-cloud-download"></i>&nbsp;</td><td class="network-load-chart-remote2local">0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</td><td class="text-right" id="chart-remote2local-text"></td></tr>
	    </table>
	    </div>
	    <div class="col-xs-6 col-sm-4">
	    </a>]]
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
</div>]]

-- Bridge wizard check
local show_bridge_dialog = false

if isAdministrator()
 and isBridgeInterface(_ifstats)
 and ntop.isEnterprise()
 and ((ntop.getCache(getBridgeInitializedKey(_ifstats.id)) ~= "1") or (_POST["show_wizard"] ~= nil)) then
  show_bridge_dialog = true
  dofile(dirs.installdir .. "/scripts/lua/inc/bridge_wizard.lua")
end

print[[<script>
// Updating charts.
]]

if show_bridge_dialog then
  print("$('#bridgeWizardModal').modal();")
  ntop.setCache(getBridgeInitializedKey(_ifstats.id), "1")
end

local traffic_peity_width = ternary(have_nedge, "140", "64")

print('var is_historical = false;')
print [[

var updatingChart_local2remote = $(".network-load-chart-local2remote").peity("line", { width: ]] print(traffic_peity_width) print[[, max: null });
var updatingChart_remote2local = $(".network-load-chart-remote2local").peity("line", { width: ]] print(traffic_peity_width) print[[, max: null, fill: "lightgreen"});

var prev_bytes   = 0;
var prev_packets = 0;
var prev_local   = 0;
var prev_remote  = 0;
var prev_epoch   = 0;

var prev_cpu_load = 0;
var prev_cpu_idle = 0;

var footerRefresh = function() {
    $.ajax({
      type: 'GET',
	  url: ']]
print (ntop.getHttpPrefix())
print [[/lua/network_load.lua',
	  data: { },
	  /* error: function(content) { alert("JSON Error (session expired?): logging out"); window.location.replace("]]
print (ntop.getHttpPrefix())
print [[/lua/logout.lua");  }, */
	  success: function(rsp) {
    
	  try {
]]

if have_nedge then
  -- Use bytes up / down on edge
  print[[
            rsp.local2remote = rsp.bytes_upload;
            rsp.remote2local = rsp.bytes_download;
  ]]
end

print[[

	    if (prev_bytes > 0) {
	      if (rsp.packets < prev_packets) {
	        prev_bytes   = rsp.bytes;
	        prev_packets = rsp.packets;
	        prev_local   = rsp.local2remote;
	        prev_remote  = rsp.remote2local;
	      }

              var values = updatingChart_local2remote.text().split(",")
	      var values1 = updatingChart_remote2local.text().split(",")
	      var bytes_diff   = Math.max(rsp.bytes-prev_bytes, 0);
	      var packets_diff = Math.max(rsp.packets-prev_packets, 0);
	      var local_diff   = Math.max(rsp.local2remote-prev_local, 0);
	      var remote_diff  = Math.max(rsp.remote2local-prev_remote, 0);
	      var epoch_diff   = Math.max(rsp.epoch - prev_epoch, 0);

	      if(epoch_diff > 0) {
		if(bytes_diff > 0) {
		   var v = local_diff-remote_diff;
		   var v_label;

		  values.shift();
		  values.push(local_diff);
		  updatingChart_local2remote.text(values.join(",")).change();
		  values1.shift();
		  values1.push(-remote_diff);
		  updatingChart_remote2local.text(values1.join(",")).change();
		}

		var pps = Math.floor(packets_diff / epoch_diff);
		var bps = Math.round((bytes_diff*8) / epoch_diff );
		var bps_local2remote = Math.round((local_diff*8) / epoch_diff);
		var bps_remote2local = Math.round((remote_diff*8) / epoch_diff);

                if(rsp.remote_pps != 0) {
                  pps = Math.max(rsp.remote_pps, 0);
                }
                if(rsp.remote_bps != 0) {
                  bps = Math.max(rsp.remote_bps, 0);
                  bps = Math.min(bps, rsp.speed * 1e6);
                }
]]

   if (interface.isPcapDumpInterface() == false) and (not have_nedge) then
      print[[

		$('#gauge_text_allTraffic').html("<small>"+bitsToSize(Math.min(bps, ]] print(maxSpeed) print[[), 1000) + " [" + addCommas(pps) + " pps]</small>");
		$('#chart-local2remote-text').html("&nbsp;"+bitsToSize(bps_local2remote, 1000));
		$('#chart-remote2local-text').html("&nbsp;"+bitsToSize(bps_remote2local, 1000));
		var v = Math.round(Math.min((bps*100)/]] print(maxSpeed) print[[, 100));
		$('#networkload').css("width", v+"%")
		$('#networkload').html(v+"%");

]]
   elseif have_nedge then
     print[[
		$('#chart-local2remote-text').html("&nbsp;"+bitsToSize(bps_local2remote, 1000));
		$('#chart-remote2local-text').html("&nbsp;"+bitsToSize(bps_remote2local, 1000));
     ]]
   end

print[[
}
	      } /* closes if (prev_bytes > 0) */

		var msg = "&nbsp;<i class=\"fa fa-clock-o\"></i> <small>"+rsp.localtime+" | ]] print(i18n("about.uptime")) print[[: "+rsp.uptime+"</small>";

                if(rsp.system_host_stats.mem_total !== undefined) {
                   var mem_total = rsp.system_host_stats.mem_total;
                   var mem_used = rsp.system_host_stats.mem_used;

                   var mem_used_ratio = mem_used / mem_total;
                   mem_used_ratio = mem_used_ratio * 100;
                   mem_used_ratio = Math.round(mem_used_ratio * 100) / 100;
                   mem_used_ratio = mem_used_ratio + "%";
                   $('#ram-used').html('Used: ' + mem_used_ratio + ' / Available: ' + bytesToSize((mem_total - mem_used) * 1024) + ' / Total: ' + bytesToSize(mem_total * 1024));
                }

                if(rsp.system_host_stats.cpu_load !== undefined) {
                  var load = "...";
                  if(prev_cpu_load > 0) {
                     var active = (rsp.system_host_stats.cpu_load - prev_cpu_load);
                     var idle = (rsp.system_host_stats.cpu_idle - prev_cpu_idle);
                     load = active / (active + idle);
                     load = load * 100;
                     load = Math.round(load * 100) / 100;
                     load = load + "%";
                  }
                  $('#cpu-load-pct').html(load);
                }

                msg += "<br>";

		if(rsp.engaged_alerts > 0) {
                   // var warning_color = "#F0AD4E"; // bootstrap warning orange
                   // var warning_label = "label-warning";
                   var error_color = "#B94A48";  // bootstrap danger red
                   var error_label = "label-danger";
                   var error_color = error_color;
                   var color = error_color;
                   var label = error_label;

		   msg += "&nbsp;<a href=\"]]
print (ntop.getHttpPrefix())
print [[/lua/show_alerts.lua\">"

                   msg += "&nbsp;<span class=\"label " + label + "\">"+addCommas(rsp.engaged_alerts)+" <i class=\"fa fa-warning\"></i></span></A>"
                }

		if((rsp.engaged_alerts > 0 || rsp.alerts_stored == true) && $("#alerts-id").is(":visible") == false) {
                  $("#alerts-id").show();
                }

		var alarm_threshold_low = 60;  /* 60% */
		var alarm_threshold_high = 90; /* 90% */
		var alert = 0;     

		if(rsp.num_local_hosts > 0) {
		  msg += "<a style=\"margin-left:0.5em;\" href=\"]]
print (ntop.getHttpPrefix())
print [[/lua/hosts_stats.lua?mode=local\">";

		  msg += "<span class=\"label label-success\">";
		  msg += addCommas(rsp.num_local_hosts)+" <i class=\"fa fa-laptop\" aria-hidden=\"true\"></i></span></a> ";
		}

	    msg += "<a href=\"]]
print (ntop.getHttpPrefix())
print [[/lua/hosts_stats.lua?mode=remote\">";

		if(rsp.hosts_pctg < alarm_threshold_low) {
		  msg += "<span class=\"label label-default\">";
		} else if(rsp.hosts_pctg < alarm_threshold_high) {
		  alert = 1;
		  msg += "<span class=\"label label-warning\">";
		} else {
		  alert = 1;
		  msg += "<span class=\"label label-danger\">";
		}

		msg += addCommas(rsp.num_hosts-rsp.num_local_hosts)+" <i class=\"fa fa-laptop\" aria-hidden=\"true\"></i></span></a> ";

	    if(typeof rsp.num_devices !== "undefined") {
	      msg += "<a href=\"]]
print (ntop.getHttpPrefix())
print [[/lua/macs_stats.lua?devices_mode=source_macs_only\">";
		  msg += "<span class=\"label label-default\">";
		msg += addCommas(rsp.num_devices)+" Devices</span></a> ";
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

		msg += addCommas(rsp.num_flows)+" Flows </span> </a>";

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


		$('#network-load').html(msg);


		if(alert) {
		   $('#toomany').html("<div class='alert alert-warning'><h4>]] print(i18n("warning")) print[[</h4>]] print(i18n("about.you_have_too_many_flows", {product=info["product"]})) print[[.</div>");
		}

	    prev_bytes   = rsp.bytes;
	    prev_packets = rsp.packets;
            prev_local   = rsp.local2remote;
            prev_remote  = rsp.remote2local;
	    prev_epoch   = rsp.epoch;
            if(rsp.system_host_stats.cpu_load !== undefined) {
              prev_cpu_load = rsp.system_host_stats.cpu_load;
              prev_cpu_idle = rsp.system_host_stats.cpu_idle;
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

local footer_refresh_rate

if have_nedge then
  footer_refresh_rate = 5
else
  footer_refresh_rate = getInterfaceRefreshRate(_ifstats.id)
end

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
