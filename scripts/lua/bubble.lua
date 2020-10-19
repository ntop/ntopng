--
-- (C) 2013-20 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local ts_utils = require("ts_utils")
local callback_utils = require("callback_utils")
local json = require("dkjson")
local page_utils = require("page_utils")
local format_utils = require("format_utils")

local info = ntop.getInfo()

sendHTTPContentTypeHeader('text/html')


page_utils.set_active_menu_entry(page_utils.menu_entries.host_explorer)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print([[
	<h2>Host Explorer</h2>
	<hr>
]])

-- https://www.d3-graph-gallery.com/graph/bubble_template.html


local modes = {
   { mode = 0, label = i18n("host_explorer_page.all_flows") },
   { mode = 1, label = i18n("host_explorer_page.unreach_flows") },
   { mode = 2, label = i18n("host_explorer_page.alerted_flows") },
   { mode = 3, label = i18n("host_explorer_page.dns_queries") },
   { mode = 4, label = i18n("host_explorer_page.syn_distribution") },
   { mode = 5, label = i18n("host_explorer_page.syn_vs_rst") },
   { mode = 6, label = i18n("host_explorer_page.syn_vs_synack") },
   { mode = 7, label = i18n("host_explorer_page.tcp_pkts_sent_vs_rcvd") },
   { mode = 8, label = i18n("host_explorer_page.tcp_bytes_sent_vs_rcvd") },
   { mode = 9, label = i18n("host_explorer_page.alerted_flows") }
}

local show_remote  = true
local local_hosts  = { }
local remote_hosts = { }
local max_r        = 0
local local_label  = "Local Hosts"
local remote_label = "Remote Hosts"
local x_label
local y_label
local bubble_mode         = tonumber(_GET["bubble_mode"]) or 0

local current_label
for _, mode in ipairs(modes) do
	if mode.mode == bubble_mode then
		current_label = mode.label
	end
end

if(bubble_mode == 0) then
   x_label = 'Flows as Server'
   y_label = 'Flows as Client'
elseif(bubble_mode == 1) then
   x_label = 'Unreachable Flows as Server'
   y_label = 'Unreachable Flows as Client'
elseif(bubble_mode == 2) then
   x_label = 'Alerted Flows as Server'
   y_label = 'Alerted Flows as Client'
elseif(bubble_mode == 3) then
   x_label = 'Positive DNS Replies Received'
   y_label = 'DNS Queries Sent'
elseif(bubble_mode == 4) then
   x_label = '# of SYN Sent'
   y_label = '# of SYN Received'
elseif(bubble_mode == 5) then
   x_label = '# of SYN Sent'
   y_label = '# of RST Received'
elseif(bubble_mode == 6) then
   x_label = '# of SYN Sent'
   y_label = '# of SYNACK Received'
elseif(bubble_mode == 7) then
   x_label = 'TCP Packets Sent'
   y_label = 'TCP Packets Received'
elseif(bubble_mode == 8) then
   x_label = 'TCP Bytes Sent'
   y_label = 'TCP Bytes Received'
elseif(bubble_mode == 9) then
   x_label = 'Flows as Server'
   y_label = 'Flows as Client'
end

function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

function processHost(hostname, host)
   local line

   --io.write("================================\n")
   --io.write(hostname.."\n")
   -- tprint(host)
   
   local label = hostinfo2hostkey(host)

   if((label == nil) or (string.len(label) == 0) or string.starts(label, "@")) then label = hostname end
   line = nil

   if(bubble_mode == 0) then
      line = { link = hostname, label = label, x = host["active_flows.as_server"], y = host["active_flows.as_client"], r = host["bytes.sent"]+host["bytes.rcvd"] }
   elseif(bubble_mode == 1) then
      if(host["unreachable_flows.as_server"] + host["unreachable_flows.as_client"] > 0) then
	 line = { link = hostname, label = label, x = host["unreachable_flows.as_server"], y = host["unreachable_flows.as_client"], r = host["bytes.sent"]+host["bytes.rcvd"] }
      end
   elseif(bubble_mode == 2) then
      if((host["alerted_flows.as_server"] ~= nil)
	    and (host["alerted_flows.as_client"] ~= nil)
	 and (host["alerted_flows.as_server"] + host["alerted_flows.as_client"] > 0)) then
	 line = { link = hostname, label = label, x = host["alerted_flows.as_server"], y = host["alerted_flows.as_client"], r = host["alerted_flows.as_server"] + host["alerted_flows.as_client"] }
	 -- if(label == "74.125.20.109") then tprint(line) end
      end
   elseif(bubble_mode == 3) then
      if((host["dns"] ~= nil) and ((host["dns"]["sent"]["num_queries"]+host["dns"]["rcvd"]["num_queries"]) > 0)) then
	 line = { link = hostname, label = label, x = host["dns"]["rcvd"]["num_replies_ok"], y = host["dns"]["sent"]["num_queries"], r = host["dns"]["rcvd"]["num_replies_error"] }
      end
   elseif(bubble_mode == 4) then
      local stats = interface.getHostInfo(host["ip"],host["vlan"])

      line = { link = hostname, label = label, x = stats["pktStats.sent"]["tcp_flags"]["syn"], y = stats["pktStats.recv"]["tcp_flags"]["syn"],
	       r = host["active_flows.as_client"] + host["active_flows.as_server"] }
   elseif(bubble_mode == 5) then
      local stats = interface.getHostInfo(host["ip"],host["vlan"])
      line = { link = hostname, label = label, x = stats["pktStats.sent"]["tcp_flags"]["syn"], y = stats["pktStats.recv"]["tcp_flags"]["rst"],
	       r = host["active_flows.as_client"] + host["active_flows.as_server"] }
   elseif(bubble_mode == 6) then
      local stats = interface.getHostInfo(host["ip"],host["vlan"])
      line = { link = hostname, label = label, x = stats["pktStats.sent"]["tcp_flags"]["syn"], y = stats["pktStats.recv"]["tcp_flags"]["synack"],
	       r = host["active_flows.as_client"] + host["active_flows.as_server"] }
   elseif(bubble_mode == 7) then
      local stats = interface.getHostInfo(host["ip"],host["vlan"])
      line = { link = hostname, label = label, x = stats["tcp.packets.sent"], y = stats["tcp.packets.rcvd"],
	       r = stats["tcp.bytes.sent"]+stats["tcp.bytes.rcvd"] }
   elseif(bubble_mode == 8) then
      local stats = interface.getHostInfo(host["ip"],host["vlan"])

      line = { link = hostname, label = label, x = stats["tcp.bytes.sent"], y = stats["tcp.bytes.rcvd"],
	       r = stats["tcp.bytes.sent"]+stats["tcp.bytes.rcvd"] }
      -- io.write("--------------------------\n")
      -- tprint(host)
   elseif(bubble_mode == 9) then
      if(host["active_alerted_flows"] > 0) then
	 line = { link = hostname, label = label, x = host["active_flows.as_server"], y = host["active_flows.as_client"], r = host["active_alerted_flows"] }
      end
   end

   if(line ~= nil) then
      if(line.r > max_r) then max_r = line.r end

      if(host.localhost) then
	 table.insert(local_hosts, line)
      else
	 table.insert(remote_hosts, line)
      end
   end
end

if(show_remote == true) then
   callback_utils.foreachHost(ifname, processHost)
else
   callback_utils.foreachLocalHost(ifname, processHost)
end

local max_radius_px = 30
local min_radius_px = 3
local ratio         = max_r / max_radius_px

for i,v in pairs(local_hosts)  do local_hosts[i].r  = math.floor(min_radius_px+local_hosts[i].r / ratio) end

if(show_remote == true) then
   for i,v in pairs(remote_hosts) do remote_hosts[i].r = math.floor(min_radius_px+remote_hosts[i].r / ratio) end
end

local local_js  = json.encode(local_hosts)
local remote_js = json.encode(remote_hosts)

print ([[

	 <script type="text/javascript" src="/js/Chart.bundle.min.js"></script>

	 <div class="dropdown mb-3">
	 <button class="btn btn-light dropdown-toggle" type="button" data-toggle="dropdown">]] .. (bubble_mode == 0 and 'Visualization' or current_label) ..[[
	 <span class="caret"></span></button>
	 <ul class="dropdown-menu scrollable-dropdown" role="menu" aria-labelledby="menu1">
	 ]])

for i,v in pairs(modes) do
   print('<li class="dropdown-item"><a class="dropdown-link" tabindex="-1" href="?bubble_mode='..tostring(i-1)..'">'..v.label..'</a></li>\n')
end

print [[
      </ul>
	   </div>

<div class="container">
    <div class="row">
	<div class="col-12">
	    <div class="card">
		<div class="card-body">
		    <canvas id="canvas"></canvas>
		</div>
	    </div>
	</div>
     </div>
</div>

<script type="text/javascript">

let chartColors = {
red: 'rgba(255, 99, 132, 0.45)',
orange: 'rgba(255, 159, 64, 0.45)',
yellow: 'rgba(255, 205, 86, 0.45)',
green: 'rgba(75, 192, 192, 0.45)',
blue: 'rgba(54, 162, 235, 0.45)',
purple: 'rgba(153, 102, 255, 0.45)',
grey: 'rgba(201, 203, 207, 0.45)'
};

 var ctx = document.getElementById("canvas");
 var data = {
 datasets: [{
	       label: ']] print(local_label) print [[',
	       data: ]] print(local_js) print [[,
	       backgroundColor: chartColors.purple,
	       borderWidth: function(context) {
		  return Math.min(Math.max(1, context.datasetIndex + 1), 8);
	       },
	       hoverBackgroundColor: 'transparent',
	       hoverBackgroundColor: 'transparent',
	       hoverBorderColor: function(context) {
		  return chartColors[context.datasetIndex];
	       },
	       hoverBorderWidth: function(context) {
		  var value = context.dataset.data[context.dataIndex];
		  return Math.round(8 * value.v / 1000);
	       },
	      },
]]

if(show_remote == true) then
print [[
   {
	       label: ']] print(remote_label) print [[',
	       data: ]] print(remote_js) print [[,
	       backgroundColor: chartColors.orange,
	       borderWidth: function(context) {
		  return Math.min(Math.max(1, context.datasetIndex + 1), 8);
	       },
	       hoverBackgroundColor: 'transparent',
	       hoverBorderColor: function(context) {
		  return chartColors[context.datasetIndex];
	       },
	       hoverBorderWidth: function(context) {
		  var value = context.dataset.data[context.dataIndex];
		  return Math.round(8 * value.v / 1000);
	       },
	      }
]]
end

print [[
	    ]
 };

 var chart = new Chart(ctx, {
   data: data,
   type: "bubble",
       options: {
	 scales: { xAxes: [{ display: true, scaleLabel: { display: true, labelString: ']] print(x_label) print [[' } }],
		    yAxes: [{ display: true, scaleLabel: { display: true, labelString: ']] print(y_label) print [[' } }]
		 },

		 elements: {
			      points: {
				       borderWidth: 1,
				       borderColor: 'rgb(0, 0, 0)'
				       }
			      },
		     onClick: function(e) {
			       var element = this.getElementAtEvent(e);
			       // If you click on at least 1 element ...
			      if (element.length > 0) {
				 // Logs it
				 // console.log(element[0]);
				 var datasetLabel = this.config.data.datasets[element[0]._datasetIndex].label;
				 var data = this.config.data.datasets[element[0]._datasetIndex].data[element[0]._index];
				 // console.log(data);
				 window.location.href = "/lua/host_details.lua?host="+data.link; // Jump to this host
			       }
		     },

tooltips: {
      callbacks: {
	title: function(tooltipItem, data) {
	  return data['labels'][tooltipItem[0]['index'] ];
},

   label: function(tooltipItem, data) {
	 var dataset = data['datasets'][tooltipItem.datasetIndex];
	 var idx = tooltipItem['index'];
	 var host = dataset['data'][idx];
	 if(host)
	    return(host.label);
	 else
	     return('');
	 },
      }
     }
    }
   });

</script>
]]


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
