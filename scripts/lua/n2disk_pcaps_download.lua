--
-- (C) 2013-16 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

require "lua_utils"
require "graph_utils"

sendHTTPHeader('text/html; charset=iso-8859-1')
ntop.dumpFile(dirs.installdir .. "/httpdocs/inc/header.inc")

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

local json = require ("dkjson")

local pcap_status_url = ntop.getHttpPrefix().."/lua/get_nbox_data.lua?action=status"
local pcap_retrieval_url = ntop.getHttpPrefix().."/lua/get_nbox_data.lua?action=download"

res = {}

if((res == nil) or (type(res) == "string")) then
	print("<div class=\"alert alert alert-danger\"><img src=".. ntop.getHttpPrefix() .. "/img/warning.png> Unable to find the specified flow</div>")
else
	print('<section class="panel panel-default">')
	print('<div class="panel-heading"> <h3 class="panel-title"> n2disk downloadable pcaps </h3> </div>')

	headerShown = true

	print [[
	<table id="records_table" border=0 class="table table-bordered table-striped">
	    <tr>
	        <th>Task id</th>
	        <th>Status</th>
	        <th>Actions</th>
	    </tr>
	</table>

	<script type="text/javascript">
	$.ajax({type: 'GET', url: "]] print(pcap_status_url) print [[",
	success: function(response) {
		response = jQuery.parseJSON(response);
		if (response.tasks.length > 0){
			$.each(response.tasks, function(i, item) {
			$('<tr>').append(
			    $('<td>').text(item.task_id),
			    $('<td>').text(item.status),
			    $('<td>').html('<i class="fa fa-download fa-lg"></i><a href="]] print(pcap_retrieval_url) print [[&task_id=' + item.task_id + '"> Download</a>')
			).appendTo('#records_table');
			// $('#records_table').append($tr);
			//console.log($tr.wrap('<p>').html());
			});
		} else {
			$('<tr>').append(
			    $('<td colspan="3">').text("No downloadable pcap found.")
			).appendTo('#records_table');
		}
	},
	error: function() {
	 perror('An HTTP error occurred.');
	}
	});
	</script>

	]]

	if(headerShown) then
	   print("</table>")
	else
	   print('<div class="panel-body"> <H5><i class="fa fa-exclamation-triangle fa-2x"></i> No downloadable pcap found./H5> </div>')
	end

	print("</section>")

end
