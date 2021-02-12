/**
 * (C) 2020 - ntop.org
 


 * This script implements the logic for the system_alerts_stats.lua script
 */

const toastConfigHostChanges = function() {
    var $error_label = $("#toast-config-change-modal_more_content")
    $.ajax({
	type: 'POST',
	contentType: "application/json",
	dataType: "json",
	url: `${http_prefix}/lua/rest/v1/edit/ntopng/incr_hosts.lua`, /* TODO: Change */
	data: JSON.stringify({
	    csrf: toastCSRF,
	}),
	success: function(rsp) {
	    $('#toast-config-change-modal-hosts').modal('hide');
	},
	error: function(rsp) {
	    console.log("Unable to double max Hosts. Please tune -X from the configuration file and restart ntopng.");
	}
    });
}

$('.toast-config-change-hosts').click(() => {
    $('#toast-config-change-modal-hosts').modal('show');
});

