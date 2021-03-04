--
-- (C) 2013-21 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
local page_utils = require("page_utils")
local MODES = require("hosts_map_utils").MODES

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.hosts_map)

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print("<h2 class='mb-4'>"..i18n("hosts_map").."</h2>")

local show_remote  = true
local bubble_mode  = tonumber(_GET["bubble_mode"]) or 0
local current_label = MODES[bubble_mode + 1].label

print ([[

	<script type="text/javascript" src="/js/Chart.bundle.min.js"></script>
    <div class="row">
	<div class="col-12">
	    <div class="card">
			<div class="card-body">
			<div class='d-flex align-items-center justify-content-end mb-3'>
				<div class="dropdown">
				<button class="btn btn-link dropdown-toggle" type="button" data-toggle="dropdown">]] .. (bubble_mode == 0 and i18n("flows_page.all_flows") or (current_label .. '<i class="fas fa-filter"></i>')) ..[[
				<span class="caret"></span></button>
				<ul class="dropdown-menu dropdown-menu-right scrollable-dropdown" role="menu" aria-labelledby="menu1">
				
]])

-- print the modes inside the dropdown
for i,v in pairs(MODES) do
	print('<a class="dropdown-item '.. (bubble_mode == v.mode and 'active' or '') ..'" tabindex="-1" href="?bubble_mode='..tostring(v.mode)..'">'..v.label..'</a>')
end

print([[
				</ul>
				</div>
				</div>
				<div style='height: 60vh'>
					<canvas id="canvas"></canvas>
				</div>
			</div>
	    </div>
	</div>
    </div>

<script type="text/javascript">

	// default properties that a dataset must have
	const COMMON_DATASET_PROPERTIES = {
		borderWidth: function(context) {
			return Math.min(Math.max(1, context.datasetIndex + 1), 8);
		},
		hoverBackgroundColor: 'transparent',
		hoverBackgroundColor: 'transparent',
		hoverBorderWidth: function(context) {
			var value = context.dataset.data[context.dataIndex];
			return Math.round(8 * value.v / 1000);
		},
	};

	// default options used by the bubble chart
	const DEFAULT_OPTIONS = {
		responsive: true,
		maintainAspectRatio: false,
		tooltips: {
			callbacks: {
				title: function(tooltipItem, data) {
					return data['labels'][ tooltipItem[0]['index'] ];
				},
				label: function(tooltipItem, data) {
					var dataset = data['datasets'][tooltipItem.datasetIndex];
					var idx = tooltipItem['index'];
					var host = dataset['data'][idx];
					if (host)
						return(host.label);
					else
						return('');
				}
			}
		},
		elements: {
			points: {
				borderWidth: 1,
				borderColor: 'rgb(0, 0, 0)'
			}
		},
		onClick: function(e) {
			const element = this.getElementAtEvent(e);
			// if you click on at least 1 element ...
			if (element.length > 0) {
				var datasetLabel = this.config.data.datasets[element[0]._datasetIndex].label;
				var data = this.config.data.datasets[element[0]._datasetIndex].data[element[0]._index];
				window.location.href = "/lua/host_details.lua?host="+data.link; // Jump to this host
			}
		},
	};

	/**
	* Draw inside a canvas's context a bubble chart
	* using the data fetched from the REST endpoint.
	*/
	const generateBubbleChart = async (ctx) => {

		const req = await fetch(`]].. ntop.getHttpPrefix() ..[[/lua/rest/v1/get/host/map.lua?bubble_mode=]].. bubble_mode ..[[`);
		const fetchedData = await req.json();
		const {data, options} = fetchedData.rsp;

		// merge common dataset properties with fetched datasets
		for (const dataset of data.datasets) {
			Object.assign(dataset, COMMON_DATASET_PROPERTIES);
		}
		// merge default options with the fecthed one
		Object.assign(options, DEFAULT_OPTIONS);

		return new Chart(ctx, {
			data: data,
			type: "bubble",
			options: options
	 	});
	}

	// when the document is ready fetch the data from the endpoint
	// and create a new bubble chart
	$(document).ready(async function() {
		const ctx = document.getElementById("canvas");
		const chart = await generateBubbleChart(ctx);
	});
</script>
]])


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")
