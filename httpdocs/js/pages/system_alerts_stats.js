/**
 * (C) 2020 - ntop.org
 *
 * This script implements the logic for the system_alerts_stats.lua script
 */

$(document).ready(function () {
    let last_queues;
    const systemAlertsStatsrefresh = function() {
	$.ajax({
	    type: 'GET',
	    url: `${http_prefix}/lua/rest/v1/get/system/stats.lua`,
	    success: function(content) {
		if(content["rc_str"] != "OK") {
		    return;
		}
		const rsp = content["rsp"];

		try {
		    if(rsp.alerts_stats && rsp.alerts_stats.alert_queues) {
			if(!last_queues)
			    last_queues = rsp.alerts_stats.alert_queues;

			for (const [key, value] of Object.entries(rsp.alerts_stats.alert_queues)) {
			    $('#' + key).html(
				NtopUtils.fint(value.num_enqueued) + " "  + NtopUtils.drawTrend(value.num_enqueued, last_queues[key].num_enqueued, "") + " / "
				    + NtopUtils.fint(value.num_not_enqueued) + " " + NtopUtils.drawTrend(value.num_not_enqueued, last_queues[key].num_not_enqueued, "") + " / "
				    + NtopUtils.fint(value.num_dequeued)  + " " + NtopUtils.drawTrend(value.num_dequeued, last_queues[key].num_dequeued, ""));
			}

			last_queues = rsp.alerts_stats.alert_queues;
		    }
		} catch(e) {
		    console.warn(e);
		}
	    }
	});
    }

    systemAlertsStatsrefresh();
    setInterval(systemAlertsStatsrefresh, 3000);
});
