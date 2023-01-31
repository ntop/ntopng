import { DataTableUtils } from "../utilities/datatable/sprymedia-datatable-utils";
import formatterUtils from "../utilities/formatter-utils.js";
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import NtopUtils from "../utilities/ntop-utils";

const bytesToSizeFormatter = formatterUtils.getFormatter(formatterUtils.types.bytes.id);
const handlerIdAddLink = "page-stats-action-link";
const handlerIdJumpHistorical = "page-stats-action-jump-historical";

const top_application = {
    table_value: "interface",
    title: i18n('page_stats.top.top_applications'),
    view: "top_protocols",
    default_sorting_columns: 1,
    default: true,
    columnDefs: [
      { type: "file-size", targets: 1 },
    ],
    columns: [{
	    columnName: i18n("application"), name: 'application', data: 'protocol', handlerId: handlerIdAddLink,
	    render: function(data, type, service) {
		let context = this;
		let handler = {
		    handlerId: handlerIdAddLink,
		    onClick: function() {
			console.log(data);
			console.log(service);
			let schema = `top:${service.ts_schema}`;
			context.add_metric_from_metric_schema(schema, service.ts_query)
		    },
		};
		return DataTableUtils.createLinkCallback({ text: data.label, handler });
	    },
	}, {
	    columnName: i18n("traffic"), name: 'traffic', className: 'text-end', data: 'traffic', orderable: true,
	    render: (data) => {
	    	//return bytesToSizeFormatter(data);
	    	return NtopUtils.bytesToSize(data)
	    },
	}, {
	    columnName: i18n("percentage"), name: 'traffic_perc', className: 'text-center', data: 'percentage', orderable: false,
	    render: (data) => {
		const percentage = data.toFixed(1);
		return NtopUtils.createProgressBar(percentage)
	    }
	}, {
	    columnName: i18n("actions"), width: '5%', name: 'actions', className: 'text-center', orderable: false, responsivePriority: 0, handlerId: handlerIdJumpHistorical,
	    render_if: function(context) { return context.is_history_enabled },
	    render: function(data, type, service) {
		let context = this;
		const jump_to_historical = {
		    handlerId: handlerIdJumpHistorical,
		    onClick: function() {
			let status = context.status;
			let l7_proto = ntopng_url_manager.serialize_param("l7proto", `${service.protocol.id};eq`);
			let historical_flows_url = `${http_prefix}/lua/pro/db_search.lua?epoch_begin=${context.status.epoch_begin}&epoch_end=${context.status.epoch_end}&${l7_proto}`;
			let source_type = context.source_type;
			let source_array = context.source_array;
			
			let params = "";
			let params_array = source_type.source_def_array.map((source_def, i) => {
			    let source = source_array[i];
			    if (source_def.value == "ifid") {
				return ntopng_url_manager.serialize_param("ifid", source.value);
			    } else if (source_def.value == "host") {
				return ntopng_url_manager.serialize_param("ip", `${source.value};eq`);
			    }
			});
			params = params_array.join("&");
			historical_flows_url = `${historical_flows_url}&${params}`;
			console.log(historical_flows_url);
			window.open(historical_flows_url);
		    }
		};
		return DataTableUtils.createActionButtons([
		    { class: 'dropdown-item', href: '#', title: i18n('db_explorer.historical_data'), handler: jump_to_historical },
		]);
	    }
	},],
};

const top_categories = {
    table_value: "interface",
    title: i18n('page_stats.top.top_categories'),
    view: "top_categories",
    default_sorting_columns: 2,
    columnDefs: [
      { type: "file-size", targets: 1 },
    ],
    columns: [{
	    columnName: i18n("category"), name: 'category', data: 'category', handlerId: handlerIdAddLink,
	    render: function(data, type, service) {
		let context = this;
		let handler = {
		    handlerId: handlerIdAddLink,
		    onClick: function() {
			console.log(data);
			console.log(service);
			let schema = `top:${service.ts_schema}`;
			context.add_metric_from_metric_schema(schema, service.ts_query)
		    },
		};
		return DataTableUtils.createLinkCallback({ text: data.label, handler });
	    },
	}, {
	    columnName: i18n("traffic"), name: 'traffic', className: 'text-end', data: 'traffic', orderable: true,
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
	    columnName: i18n("actions"), width: '5%', name: 'actions', className: 'text-center', orderable: false, responsivePriority: 0, handlerId: handlerIdJumpHistorical,
	    render_if: function(context) { return context.is_history_enabled },
	    render: function(data, type, service) {
		let context = this;
		const jump_to_historical = {
		    handlerId: handlerIdJumpHistorical,
		    onClick: function() {
			let status = context.status;
			let category = ntopng_url_manager.serialize_param("l7cat", `${service.category.id};eq`);
			let historical_flows_url = `${http_prefix}/lua/pro/db_search.lua?epoch_begin=${context.status.epoch_begin}&epoch_end=${context.status.epoch_end}&${category}`;
			let source_type = context.source_type;
			let source_array = context.source_array;
			
			let params = "";
			let params_array = source_type.source_def_array.map((source_def, i) => {
			    let source = source_array[i];
			    if (source_def.value == "ifid") {
				return ntopng_url_manager.serialize_param("ifid", source.value);
			    } else if (source_def.value == "host") {
				return ntopng_url_manager.serialize_param("ip", `${source.value};eq`);
			    }
			});
			params = params_array.join("&");
			historical_flows_url = `${historical_flows_url}&${params}`;
			console.log(historical_flows_url);
			window.open(historical_flows_url);
		    }
		};
		return DataTableUtils.createActionButtons([
		    { class: 'dropdown-item', href: '#', title: i18n('db_explorer.historical_data'), handler: jump_to_historical },
		]);
	    }
	},],
};

const top_senders = {
    table_value: "interface",
    title: i18n('page_stats.top.top_senders'),
    view: "top_senders",
    default_sorting_columns: 1,
    columnDefs: [
      { type: "file-size", targets: 1 },
    ],
    columns: [{
	columnName: i18n("page_stats.top.host_name"), name: 'host_name', data: 'host', handlerId: handlerIdAddLink,
	render: function(data, type, service) {
	    let context = this;
      let label = data.label;
      let host_ref = '';
	    let handler = {
		handlerId: handlerIdAddLink,
		onClick: async function() {
		    console.log(data);
		    console.log(service);
		    let schema = `host:traffic`;
		    context.add_ts_group_from_source_value_dict("host", service.tags, schema);
		},
	    };
	    if (context.sources_types_enabled["host"] && data.is_local) {
        label = DataTableUtils.createLinkCallback({ text: data.label, handler });
	    }
      if (data.is_available) {
        host_ref = ` <a href="/lua/host_details.lua?host=${data.id}" data-bs-toggle="tooltip" title=""><i class="fas fa-laptop"></i></a>`
      }
      
	    return `${label}${host_ref}`;
	},
    }, {
	columnName: i18n("page_stats.top.sent"), name: 'sent', className: 'text-end', data: 'traffic', orderable: true,
	render: (data) => {
	    return bytesToSizeFormatter(data);
	    //return NtopUtils.bytesToSize(data)
	},
    }, // {
	      // 	columnName: i18n("percentage"), name: 'traffic_perc', data: 'percentage',
	      // 	render: (data) => {
	      // 	    const percentage = data.toFixed(1);
	      // 	    return NtopUtils.createProgressBar(percentage)
	      // 	}
	      // },
	      {
		  columnName: i18n("actions"), width: '5%', name: 'actions', className: 'text-center', orderable: false, responsivePriority: 0, handlerId: handlerIdJumpHistorical,
		  render_if: function(context) { return context.is_history_enabled },
		  render: function(data, type, service) {
		      let context = this;
          const host = service.host.id;
          const host_ts_available= service.host.is_local;
		      const jump_to_historical = {
            handlerId: handlerIdJumpHistorical,
            onClick: function() {
                let status = context.status;
                let historical_flows_url = `${http_prefix}/lua/pro/db_search.lua?epoch_begin=${context.status.epoch_begin}&epoch_end=${context.status.epoch_end}`;
                let source_type = context.source_type;
                let source_array = context.source_array;
                
                let params = "";			    
                let params_array = [];
                for (let key in service.tags) {
              let value = service.tags[key];
              let p_url = "";
              if (key == "ifid") {
                  p_url = ntopng_url_manager.serialize_param(key, value);
              } else if (key == "host") {
                  p_url = ntopng_url_manager.serialize_param("ip", `${value};eq`);
              }
              params_array.push(p_url);
                }
                params = params_array.join("&");
                historical_flows_url = `${historical_flows_url}&${params}`;
                console.log(historical_flows_url);
                window.open(historical_flows_url);
            }
          };
              
          const jump_to_host = {
            handlerId: handlerIdJumpHistorical,
            onClick: function() {
                const ifid = ntopng_url_manager.get_url_entry('ifid');
                const host_url = `${http_prefix}/lua/host_details.lua?host=${host}&page=historical&ts_query=ifid:${ifid},host:${host}&ts_schema=host:details&epoch_begin=${context.status.epoch_begin}&epoch_end=${context.status.epoch_end}`;
                
                window.open(host_url);
            }
          };

          const dropdown = [{ class: 'dropdown-item', href: '#', title: i18n('db_explorer.historical_data'), handler: jump_to_historical }]
	        if (context.sources_types_enabled["host"] && host_ts_available) {
            dropdown.push({ class: 'dropdown-item', href: '#', title: i18n('db_explorer.host_data'), handler: jump_to_host })
          }

		      return DataTableUtils.createActionButtons(dropdown);
		  }
	      },],
};

const top_receivers = {
    table_value: "interface",
    title: i18n('page_stats.top.top_receivers'),
    view: "top_receivers",
    default_sorting_columns: 1,
    columnDefs: [
      { type: "file-size", targets: 1 },
    ],
    columns: [{
	columnName: i18n("page_stats.top.host_name"), name: 'host_name', data: 'host', handlerId: handlerIdAddLink,
	render: function(data, type, service) {
	    let context = this;
      let label = data.label;
      let host_ref = '';
	    let handler = {
		handlerId: handlerIdAddLink,
		onClick: async function() {
		    console.log(data);
		    console.log(service);
		    let schema = `host:traffic`;
		    context.add_ts_group_from_source_value_dict("host", service.tags, schema);
		},
	    };
	    if (context.sources_types_enabled["host"] && data.is_local) {
        label = DataTableUtils.createLinkCallback({ text: data.label, handler });
	    }
      if (data.is_available) {
        host_ref = ` <a href="/lua/host_details.lua?host=${data.id}" data-bs-toggle="tooltip" title=""><i class="fas fa-laptop"></i></a>`
      }
      
	    return `${label}${host_ref}`;
	},
    }, {
	columnName: i18n("page_stats.top.received"), name: 'received', className: 'text-end', data: 'traffic', orderable: true,
	render: (data) => {
	    return bytesToSizeFormatter(data);
	    //return NtopUtils.bytesToSize(data)
	},
    }, // {
	      // 	columnName: i18n("percentage"), name: 'traffic_perc', data: 'percentage',
	      // 	render: (data) => {
	      // 	    const percentage = data.toFixed(1);
	      // 	    return NtopUtils.createProgressBar(percentage)
	      // 	}
	      // },
	      {
		  columnName: i18n("actions"), width: '5%', name: 'actions', className: 'text-center', orderable: false, responsivePriority: 0, handlerId: handlerIdJumpHistorical,
		  render_if: function(context) { return context.is_history_enabled },
		  render: function(data, type, service) {
		      let context = this;
          const host = service.host.id;
          const host_ts_available= service.host.is_local;
		      const jump_to_historical = {
			  handlerId: handlerIdJumpHistorical,
			  onClick: function() {
			      let status = context.status;
			      let historical_flows_url = `${http_prefix}/lua/pro/db_search.lua?epoch_begin=${context.status.epoch_begin}&epoch_end=${context.status.epoch_end}`;
			      let source_type = context.source_type;
			      let source_array = context.source_array;
			      
			      let params = "";
			      let params_array = [];
			      for (let key in service.tags) {
				  let value = service.tags[key];
				  let p_url = "";
				  if (key == "ifid") {
				      p_url = ntopng_url_manager.serialize_param(key, value);
				  } else if (key == "host") {
				      p_url = ntopng_url_manager.serialize_param("ip", `${value};eq`);
				  }
				  params_array.push(p_url);
			      }
			      params = params_array.join("&");
			      historical_flows_url = `${historical_flows_url}&${params}`;
			      console.log(historical_flows_url);
			      window.open(historical_flows_url);
			  }
		      };
              
          const jump_to_host = {
            handlerId: handlerIdJumpHistorical,
            onClick: function() {
                const ifid = ntopng_url_manager.get_url_entry('ifid');
                const host_url = `${http_prefix}/lua/host_details.lua?host=${host}&page=historical&ts_query=ifid:${ifid},host:${host}&ts_schema=host:details&epoch_begin=${context.status.epoch_begin}&epoch_end=${context.status.epoch_end}`;
                
                window.open(host_url);
            }
          };

          const dropdown = [{ class: 'dropdown-item', href: '#', title: i18n('db_explorer.historical_data'), handler: jump_to_historical }]
	        if (context.sources_types_enabled["host"] && host_ts_available) {
            dropdown.push({ class: 'dropdown-item', href: '#', title: i18n('db_explorer.host_data'), handler: jump_to_host })
          }

		      return DataTableUtils.createActionButtons(dropdown);
		  },
	      },],
};

const interface_top_tables = [top_application, top_categories, top_senders, top_receivers];

export default interface_top_tables;

