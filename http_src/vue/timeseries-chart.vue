<!-- (C) 2022 - ntop.org     -->
<template>
	<div style="width:100% height:380px;" class="text-end m-3">
		<label class="form-check-label form-control-sm" v-for="(item, i) in  timeseries_list ">
			<input type="checkbox" class="form-check-input align-middle mt-0" @click="change_visibility(!item.checked, i)"
				:checked="item.checked" style="border-color: #0d6efd;" :style="{ backgroundColor: item.color }">
			{{ item.name }}
		</label>
	</div>
	<div class="mb-3" style="width:100%" ref="chart"></div>
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
	created() { },
	beforeUnmount() { },
	data() {
		return {
			chart: null,
			chart_options: null,
			from_zoom: false,
			timeseries_visibility: null,
			timeseries_list: [],
			//i18n: (t) => i18n(t),
		};
	},
	/** This method is the first method called after html template creation. */
	async mounted() {
		await this.init();
		ntopng_sync.ready(this.$props["id"]);
	},
	methods: {
		init: async function () {
			let status = ntopng_status_manager.get_status();
			let url_request = this.get_url_request(status);
			if (this.register_on_status_change) {
				this.register_status(status);
			}
			await this.draw_chart(url_request);
		},
		get_image: function (image) {
			return Dygraph.Export.asPNG(this.chart, image, this.$refs["chart"]);
		},
		change_visibility: function (visible, id) {
			if (this.timeseries_list[id] != null) {
				this.timeseries_list[id]["checked"] = visible
				this.chart.setVisibility(id, visible);
			}
		},
		register_status: function (status) {
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
		get_url_request: function (status) {
			let url_params;
			if (this.get_params_url_request != null) {
				if (status == null) {
					status = ntopng_status_manager.get_status();
				}
				url_params = this.get_params_url_request(status);
			} else {
				url_params = ntopng_url_manager.get_url_params();
			}

			return `${this.$props.base_url_request || ''}?${url_params}`;
		},
		draw_chart: async function (url_request) {
			let chart_options = await this.get_chart_options(url_request);
			const data = chart_options.data || [];
			chart_options.data = null;
			chart_options.zoomCallback = this.on_zoomed;
			this.timeseries_list = [];
			let visibility = [];
			let last_point = null;
			let id = 0;
			for (const key in chart_options.series) {
				this.timeseries_list.push({ name: key, checked: true, id: id, color: chart_options.colors[id] + "!important" });
				id = id + 1;
				visibility.push(true);
			}
			chart_options.visibility = visibility;
			this.chart = new Dygraph(this.$refs["chart"], data, chart_options);
		},
		update_chart: async function (url_request) {
			let chart_options = await this.get_chart_options(url_request);
			this.chart.updateChart(chart_options);
		},
		update_chart_options: function (chart_options) {
			this.chart.updateChart(chart_options);
		},
		update_chart_series: function (series) {
			if (series == null) { return; }
			this.chart.updateOptions({ 'file': series });
		},
		get_chart_options: async function (url_request) {
			let chart_options;
			if (this.get_custom_chart_options == null) {
				chart_options = await ntopng_utility.http_request(url_request);
			} else {
				chart_options = await this.get_custom_chart_options(url_request);
			}
			this.$emit('chart_reloaded', chart_options);
			return chart_options;
		},
		on_zoomed: function (minDate, maxDate) {
			this.from_zoom = true;
			const begin = moment(minDate);
			const end = moment(maxDate);
			// the timestamps are in milliseconds, convert them into seconds
			let new_epoch_status = { epoch_begin: Number.parseInt(begin.unix()), epoch_end: Number.parseInt(end.unix()) };
			ntopng_events_manager.emit_event(ntopng_events.EPOCH_CHANGE, new_epoch_status, this.id);
			this.$emit('zoom', new_epoch_status);
		},
	},
};
</script>

<style></style>
