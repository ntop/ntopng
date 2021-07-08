/**
 * (C) 2020 - ntop.org
 *
 * This script implements the logic for the system_alerts_stats.lua script
 */

$(function () {
    let last_queues;
    const systemAlertsStatsrefresh = function() {
	$.ajax({
	    type: 'GET',
	    url: `${http_prefix}/lua/rest/v2/get/system/stats.lua`,
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
				NtopUtils.fpercent(value.pct_in_queue) + " "  + NtopUtils.drawTrend(value.pct_in_queue, last_queues[key].pct_in_queue, "") + " / "
				    + NtopUtils.fpercent(value.pct_not_enqueued) + " " + NtopUtils.drawTrend(value.pct_not_enqueued, last_queues[key].pct_not_enqueued, ""));
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
