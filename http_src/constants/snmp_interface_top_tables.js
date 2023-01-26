import { DataTableUtils } from "../utilities/datatable/sprymedia-datatable-utils";
import formatterUtils from "../utilities/formatter-utils.js";
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import NtopUtils from "../utilities/ntop-utils";


const bytesToSizeFormatter = formatterUtils.getFormatter(formatterUtils.types.bytes.id);
const bpsFormatter = formatterUtils.getFormatter(formatterUtils.types.bps.id);
const handlerIdAddLink = "page-stats-action-link";
const handlerIdJumpHistorical = "page-stats-action-jump-historical";

const top_snmp_interface = {
    table_value: "snmp",
    table_source_def_value_dict: { ifid: true, device: true, if_index: false },
    title: i18n('page_stats.top.top_interfaces'),
    view: "top_snmp_ifaces",
    default_sorting_columns: 4,
    f_get_label: (ts_group) => {
	let source_def_array = ts_group.source_type.source_def_array;
	let source_label;
	for (let i = 0; i < source_def_array.length; i += 1) {
	    if (source_def_array[i].value != "device") { continue; }
	    source_label = ts_group.source_array[i].label;
	    break;
	}
	return `${i18n('page_stats.top.top_interfaces')} - SNMP ${i18n('page_stats.source_def.device')} ${source_label}`;
    },
    default: true,
    
    columns: [{
	columnName: i18n("interface"), name: 'interface', data: 'interface', handlerId: handlerIdAddLink,
	render: function(data, type, service) {
	    let context = this;
	    let handler = {
		handlerId: handlerIdAddLink,
		onClick: function() {
		    let schema = `snmp_if:traffic`;
		    context.add_ts_group_from_source_value_dict("snmp_interface", service.tags, schema);
		},
	    };
	    let label_text = `${data.label} (${data.id})`;
	    return DataTableUtils.createLinkCallback({ text: label_text, handler });
	},
    }, {
	columnName: i18n("page_stats.top.sent"), name: 'sent', className: 'text-end', data: 'sent', orderable: true,
	render: (data) => {
	    return bytesToSizeFormatter(data);
	    //return NtopUtils.bytesToSize(data)
	},
    }, {
	columnName: i18n("page_stats.top.received"), name: 'received', className: 'text-end', data: 'rcvd', orderable: true,
	render: (data) => {
	    return bytesToSizeFormatter(data);
	    //return NtopUtils.bytesToSize(data)
	},
    }, {
	columnName: i18n("traffic"), name: 'traffic', className: 'text-end', data: 'total', orderable: true,
	render: (data) => {
	    return bytesToSizeFormatter(data);
	    //return NtopUtils.bytesToSize(data)
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
	    //return NtopUtils.bytesToSize(data)
	},
    },],
};

const snmp_interface_top_tables = [top_snmp_interface];

export default snmp_interface_top_tables;
