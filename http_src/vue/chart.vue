<!-- (C) 2022 - ntop.org     -->
<template>
  <div style="width:100%" ref="chart"></div>
</template>

<script>
export default {
    components: {
    },
    props: {
	id: String,
	chart_type: String,
	register_on_status_change: Boolean,
	base_url_request: String,
	get_params_url_request: Function,
	get_custom_chart_options: Function,
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
	    this.chart.registerEvent("zoomed", (chart_context, axis) => this.on_zoomed(chart_context, axis));
	    let chart_options = await this.get_chart_options(url_request);
	    this.chart.drawChart(this.$refs["chart"], chart_options);
	},
	update_chart: async function(url_request) {
	    let chart_options = await this.get_chart_options(url_request);
	    this.chart.updateChart(chart_options);
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
	on_zoomed: function(chart_context, { xaxis, yaxis }) {
	    this.from_zoom = true;
            const begin = moment(xaxis.min);
            const end = moment(xaxis.max);
            // the timestamps are in milliseconds, convert them into seconds
	    let new_epoch_status = { epoch_begin: Number.parseInt(begin.unix()), epoch_end: Number.parseInt(end.unix()) };
	    ntopng_events_manager.emit_event(ntopng_events.EPOCH_CHANGE, new_epoch_status, this.id);
	    this.$emit('zoom', new_epoch_status);
	},
    },
};
</script>

<style>
</style>
