<!-- (C) 2022 - ntop.org     -->
<template>
  <div style="width:100%" ref="chart"></div>
</template>

<script>
import { ntopng_utility, ntopng_url_manager, ntopng_events_manager } from "../services/context/ntopng_globals_services";

export default {
    components: {
    },
    props: {
	id: String,
	chart_type: String,
	register_on_status_change: Boolean,
	not_emit_global_status_update: Boolean,
	base_url_request: String,
	get_params_url_request: Function,
	get_custom_chart_options: Function,
        min_time_interval_id: String,	
	round_time: Boolean, //if min_time_interval_id != null round time by min_time_interval_id	
    },
    emits: ["apply", "hidden", "showed", "chart_reloaded", "zoom"],
    /** This method is the first method of the component called, it's called before html template creation. */
    created() {
    },
    beforeUnmount() {
	this.chart.destroyChart();
    },
    data() {
	return {
	    chart: null,
	    chart_options: null,
	    from_zoom: false,
	    //i18n: (t) => i18n(t),
	};
    },
    /** This method is the first method called after html template creation. */
    async mounted() {
	await this.init();
	ntopng_sync.ready(this.$props["id"]);
    },
    methods: {
	init: async function() {
	    let status = ntopng_status_manager.get_status();
	    let url_request = this.get_url_request(status);
	    if (this.register_on_status_change) {
		this.register_status(status);
	    }
	    await this.draw_chart(url_request);
	},
	get_data_uri: async function(options) {
	    if (this.chart == null) { return null; }
	    let data_uri = await this.chart.to_data_uri();
	    return data_uri;
	},
	download_chart_png: async function(file_name, options) {
	    if (this.chart == null) { return; }
	    let data_uri = await this.chart.to_data_uri();
	    downloadURI(data_uri, file_name);
	},
	register_status: function(status) {
	    let url_request = this.get_url_request(status);
	    ntopng_status_manager.on_status_change(this.id, (new_status) => {
		if (this.from_zoom == true) {
		    this.from_zoom = false;
		    //return;
		}
		let new_url_request = this.get_url_request(new_status);
		if (new_url_request == url_request) {
		    url_request = new_url_request;
		    return;
		}
		url_request = new_url_request;
		this.update_chart(new_url_request);
	    }, false);
	},
	get_url_request: function(status) {
	    let url_params;
	    if (this.get_params_url_request != null) {
		if (status == null) {
		    status = ntopng_status_manager.get_status();
		}
		url_params = this.get_params_url_request(status);
	    } else {
		url_params = ntopng_url_manager.get_url_params();
	    }
	    
	    return `${this.base_url_request}?${url_params}`;
	},
	draw_chart: async function(url_request) {
	    let chartApex = ntopChartApex;
	    let chart_type = this.chart_type;
	    if (chart_type == null) {
		chart_type = chartApex.typeChart.TS_STACKED;
	    }
	    this.chart = chartApex.newChart(chart_type);
	    let me = this;
	    this.chart.registerEvent("beforeZoom", function(chart_context, axis) {
		me.on_before_zoom(chart_context, axis);
	    });
	    this.chart.registerEvent("zoomed", function(chart_context, axis) {
		me.on_zoomed(chart_context, axis);
	    });
	    let chart_options = await this.get_chart_options(url_request);
	    this.chart.drawChart(this.$refs["chart"], chart_options);
	},
	update_chart: async function(url_request) {
	    if (url_request == null) {
		url_request = this.get_url_request();
	    }
	    let chart_options = await this.get_chart_options(url_request);
	    this.chart.updateChart(chart_options);
	},
	update_chart_options: function(chart_options) {
	    this.chart.updateChart(chart_options);
	},
	update_chart_series: function(series) {
	    if (series == null) { return; }
	    this.chart.updateSeries(series);
	},
	get_chart_options: async function(url_request) {
	    let chart_options;
	    if (this.get_custom_chart_options == null) {		
		chart_options = await ntopng_utility.http_request(url_request);
	    } else {
		chart_options = await this.get_custom_chart_options(url_request);
	    }
	    this.$emit('chart_reloaded', chart_options);
	    return chart_options;
	},
	on_before_zoom: function(chart_context, { xaxis, yaxis }) {
	    let new_epoch_status = this.get_epoch_from_xaxis_event(xaxis);
	    if (this.min_time_interval_id != null) {
		const min_time_interval = ntopng_utility.get_timeframe_from_timeframe_id(this.min_time_interval_id);
		if (new_epoch_status.epoch_end - new_epoch_status.epoch_begin < min_time_interval) {
		    
		    new_epoch_status.epoch_end = new_epoch_status.epoch_end + min_time_interval;
		    new_epoch_status.epoch_end = new_epoch_status.epoch_end - (new_epoch_status.epoch_end % min_time_interval);
		    new_epoch_status.epoch_begin = new_epoch_status.epoch_end - min_time_interval;
		}
		if (this.round_time == true) {
		    new_epoch_status.epoch_begin = ntopng_utility.round_time_by_timeframe_id(new_epoch_status.epoch_begin, this.min_time_interval_id);
		    new_epoch_status.epoch_end = ntopng_utility.round_time_by_timeframe_id(new_epoch_status.epoch_end, this.min_time_interval_id);
		}
		
		xaxis.min = new_epoch_status.epoch_begin * 1000;
		xaxis.max = new_epoch_status.epoch_end * 1000;
	    }
	    return xaxis;
	},
	on_zoomed: function(chart_context, { xaxis, yaxis }) {
	    this.from_zoom = true;
	    const new_epoch_status = this.get_epoch_from_xaxis_event(xaxis);
            // the timestamps are in milliseconds, convert them into seconds
	    if (!this.not_emit_global_status_update) {
		ntopng_events_manager.emit_event(ntopng_events.EPOCH_CHANGE, new_epoch_status, this.id);
	    }
	    this.$emit('zoom', new_epoch_status);
	},
	get_epoch_from_xaxis_event: function(xaxis) {
	    const begin = moment(xaxis.min);
            const end = moment(xaxis.max);
	    let new_epoch_status = { epoch_begin: Number.parseInt(begin.unix()), epoch_end: Number.parseInt(end.unix()) };
	    return new_epoch_status;
	}
    },
};
</script>

<style>
</style>
