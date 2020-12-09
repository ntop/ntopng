/**
 * (C) 2020 - ntop.org
 *
 * This script implements the logic for the system_alerts_stats.lua script
 */

const toastConfigHostChanges = function() {
    $.ajax({
	type: 'POST',
	contentType: "application/json",
	dataType: "json",
	url: `${http_prefix}/lua/rest/v1/edit/ntopng/incr_hosts.lua`, /* TODO: Change */
	data: JSON.stringify({
	    csrf: toastCSRF,
	}),
	success: function(rsp) {
	    $('#toast-config-change-modal').modal('hide');
	}
    });
}

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
	    $('#toast-config-change-modal').modal('hide');
	}
    });
}

$('.toast-config-change').click(() => {
    $('#toast-config-change-modal').modal('show');
});
