/**
 * (C) 2020 - ntop.org
 


 * This script implements the logic for the system_alerts_stats.lua script
 */

const toastConfigFlowChanges = function() {
    $.ajax({
	type: 'POST',
	contentType: "application/json",
	dataType: "json",
	url: `${http_prefix}/lua/rest/v2/edit/ntopng/incr_flows.lua`, /* TODO: Change */
	data: JSON.stringify({
	    csrf: toastCSRF,
	}),
	success: function(rsp) {
	    $('#toast-config-change-modal-flows').modal('hide');
	},
	error: function(rsp) {
	    $('#toast-config-change-modal-flows_more_content').show();
	}
     });
}

$('.toast-config-change-flows').click(() => {
    $('#toast-config-change-modal-flows').modal('show');
});

