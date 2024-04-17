import { DataTableUtils } from "../utilities/datatable/sprymedia-datatable-utils";
import formatterUtils from "../utilities/formatter-utils.js";
import NtopUtils from "../utilities/ntop-utils";

const bytesToSizeFormatter = formatterUtils.getFormatter(formatterUtils.types.bytes.id);
const bpsFormatter = formatterUtils.getFormatter(formatterUtils.types.bps.id);
const handlerIdAddLink = "page-stats-action-link";
const handlerIdJumpHistorical = "page-stats-action-jump-historical";
const handlerIdJumpLive = "page-stats-action-jump-live";
const handlerIdJumpDetails = "page-stats-action-jump-details";

const top_flow_interface = {
	table_value: "flowdevice",
	table_source_def_value_dict: { ifid: true, device: true, if_index: false },
	title: i18n('page_stats.top.top_interfaces'),
	view: "top_flowdev_ifaces",
	default_sorting_columns: 4,
	columnDefs: [
		{ type: "file-size", targets: 1 },
		{ type: "file-size", targets: 2 },
		{ type: "file-size", targets: 3 },
	],
	f_get_label: (ts_group) => {
		let source_def_array = ts_group.source_type.source_def_array;
		let source_label;
		for (let i = 0; i < source_def_array.length; i += 1) {
			if (source_def_array[i].value != "device") { continue; }
			source_label = ts_group.source_array[i].label;
			break;
		}
		return `${i18n('page_stats.top.top_interfaces')} - Flow Exporter ${source_label}`;
	},
	default: true,

	columns: [{
		columnName: i18n("actions"), width: '5%', name: 'actions', className: 'text-center', orderable: false, responsivePriority: 0, handlerId: handlerIdJumpHistorical,
		render_if: function (context) { return context.is_history_enabled },
		render: function (data, type, service) {
			let context = this;
			const jump_to_historical = {
				handlerId: handlerIdJumpHistorical,
				onClick: function () {
					let historical_flows_url = `${http_prefix}/lua/pro/db_search.lua?epoch_begin=${context.status.epoch_begin}&epoch_end=${context.status.epoch_end}`;

					let params = "";
					let params_array = [];
					for (let key in service.tags) {
						let value = service.tags[key];
						let p_url = "";
						if (key == "ifid") {
							p_url = ntopng_url_manager.serialize_param(key, value);
						} else if (key == "device") {
							p_url = ntopng_url_manager.serialize_param("probe_ip", `${value};eq`);
						}
						params_array.push(p_url);
					}
					params = params_array.join("&");
					historical_flows_url = `${historical_flows_url}&${params}`;
					window.open(historical_flows_url);
				}
			};
			const jump_to_live = {
				handlerId: handlerIdJumpLive,
				onClick: function () {
					let live_flows_url = `${http_prefix}/lua/flows_stats.lua?page=flows`
					let params = "";
					let params_array = [];
					for (let key in service.tags) {
						let value = service.tags[key];
						let p_url = "";
						if (key == "ifid") {
							p_url = ntopng_url_manager.serialize_param(key, value);
						} else if (key == "device") {
							p_url = ntopng_url_manager.serialize_param("deviceIP", `${value}`);
						}
						params_array.push(p_url);
					}
					params = params_array.join("&");
					live_flows_url = `${live_flows_url}&${params}`;
					window.open(live_flows_url);
				}
			};

			const jump_to_host = {
				handlerId: handlerIdJumpDetails,
				onClick: function () {
					const ifid = ntopng_url_manager.get_url_entry('ifid');
					const port = service.tags.port;
					const host = service.tags.device;
					const interface_url = `${http_prefix}/lua/pro/enterprise/flowdevice_interface_details.lua?snmp_port_idx=${port}&ip=${host}&page=historical&ts_query=ifid:${ifid},device:${host},port:${port}&ts_schema=host:details&epoch_begin=${context.status.epoch_begin}&epoch_end=${context.status.epoch_end}`;

					window.open(interface_url);
				}
			};

			const dropdown = [
				{ class: 'dropdown-item', icon: 'fas fa-search-plus', href: '#', title: i18n('db_explorer.historical_data'), handler: jump_to_historical },				
				{ class: 'dropdown-item', icon: 'fas fa-stream', href: '#', title: i18n('flows_page.live_flows'), handler: jump_to_live },
				{ class: 'dropdown-item', icon: 'fas fa-laptop', href: '#', title: i18n('db_explorer.host_data'), handler: jump_to_host }
			]
			
			return DataTableUtils.createActionButtons(dropdown);
		},
	}, {
		columnName: i18n("interface_name"), name: 'interface', data: 'interface', handlerId: handlerIdAddLink,
		render: function (data, type, service) {
			let context = this;
			let handler = {
				handlerId: handlerIdAddLink,
				onClick: function () {
					let schema = `flowdev_port:traffic`;
					context.add_ts_group_from_source_value_dict("flow_interface", service.tags, schema);
				},
			};
			let label_text = `${data.label}`;
			return DataTableUtils.createLinkCallback({ text: label_text, handler });
		},
	},  {
		columnName: i18n("page_stats.top.sent"), name: 'sent', className: 'text-end', data: 'sent', orderable: true,
		render: (data) => {
			return bytesToSizeFormatter(data);
		},
	}, {
		columnName: i18n("page_stats.top.received"), name: 'received', className: 'text-end', data: 'rcvd', orderable: true,
		render: (data) => {
			return bytesToSizeFormatter(data);
		},
	}, {
		columnName: i18n("traffic"), name: 'traffic', className: 'text-end', data: 'total', orderable: true,
		render: (data) => {
			return bytesToSizeFormatter(data);
		},
	}, {
		columnName: i18n("percentage"), name: 'traffic_perc', className: 'text-center', data: 'percentage',
		render: (data) => {
			const percentage = data.toFixed(1);
			return NtopUtils.createProgressBar(percentage)
		}
	}, {
		columnName: i18n("page_stats.top.throughput"), name: 'throughput', className: 'text-end', data: 'throughput', orderable: true,
		render: (data) => {
			return bpsFormatter(data);
		},
	},],
};

const flow_dev_top_tables = [top_flow_interface];

export default flow_dev_top_tables;
