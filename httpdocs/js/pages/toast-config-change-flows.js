/**
 * (C) 2020 - ntop.org
 


 * This script implements the logic for the system_alerts_stats.lua script
 */

const toastConfigFlowChanges = function() {
    $.ajax({
	type: 'POST',
	contentType: "application/json",
	dataType: "json",
	url: `${http_prefix}/lua/rest/v1/edit/ntopng/incr_flows.lua`, /* TODO: Change */
	data: JSON.stringify({
	    csrf: toastCSRF,
	}),
	success: function(rsp) {
	    $('#toast-config-change-modal-flows').modal('hide');
	},
	error: function(rsp) {
	    console.log("Unable to double max Flows. Please tune -X from the configuration file and restart ntopng.");
	}
    });
}

$('.toast-config-change-flows').click(() => {
    $('#toast-config-change-modal-flows').modal('show');
});

