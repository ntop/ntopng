/**
    (C) 2022 - ntop.org
*/
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import NtopUtils from "./ntop-utils.js";
import { DataTableRenders } from "../utilities/datatable/sprymedia-datatable-utils.js";
import { default as Dropdown } from "../vue//dropdown.vue";

const _i18n = (t) => i18n(t);

async function build_table(http_prefix, table_id, f_map_columns, f_get_extra_params_obj, f_on_get_rows) {
    console.log(table_id);
    console.log("---------------------------------");
    let table_def_url = `${http_prefix}/tables_config/${table_id}.json`;
    let table_def = await ntopng_utility.http_request(table_def_url, null, null, true);
    if (f_map_columns != null) {
	table_def.columns = f_map_columns(table_def.columns);
    }
    const table_config = {
	id: table_id,
	columns: table_def.columns,
	get_rows: get_rows_func(table_def, f_get_extra_params_obj, f_on_get_rows),
	get_column_id: get_column_id_func(table_def),
	print_column_name: get_f_print_column_name(table_def),
	print_html_row: get_f_print_html_row(table_def),
	print_vue_node_row: get_f_print_vue_node_row(table_def),
	f_is_column_sortable: get_f_is_column_sortable(table_def),
	f_get_column_classes: get_f_get_column_classes(table_def),
	enable_search: table_def.enable_search,
	paging: table_def.paging,
    };
    return table_config;
}

function get_f_is_column_sortable(table_def) {
    return (col) => {
	return col.sortable;
    };
}

function get_f_get_column_classes(table_def) {
    return (col) => {
	let classes = col?.class;
	if (classes != null) { return classes; }
	return [];
    };
}

function get_f_print_vue_node_row(table_def) {
    const available_types = {
	"button_list": get_f_print_v_node_buttons(true),
	"button_array": get_f_print_v_node_buttons(false),
    };
    return (col, row, vue_obj, return_true_if_def) => {
	if (col.render_v_node_type == null && col.render_v_func == null) { return null; }
	if (return_true_if_def == true) { return true; }
	if (col.render_v_func != null) {
	    return col.render_v_func(col, row, vue_obj, return_true_if_def);
	}
	let print_v_node_buttons = available_types[col.render_v_node_type];
	return print_v_node_buttons(col, row, vue_obj);
    };
}

function get_f_print_html_row(table_def) {
    return (col, row, return_true_if_def) => {
	if (col.render_type == null && col.render_generic == null && col.render_func == null) { return null; }
	if (return_true_if_def == true) { return true; }

	let data;
	if (col.data_field != null) {
	    data = row[col.data_field];
	}
	if (col.render_generic != null) {
	    let render = DataTableRenders.getFormatGenericField(col.render_generic);
	    return render(data, 'display', row);
	}
	if (col.render_func != null) {
	    return col.render_func(data, row);
	}
	if (col.render_type != null) {
            return DataTableRenders[col.render_type](data, 'display', row);
	}
	return data;
    };
}

function get_f_print_v_node_buttons(list_or_array) {
    return (col, row, vue_obj) => {
	const on_click = (id) => {
	    return (e) => {
		e.stopPropagation();
		let event = {event_id: id, row, col};
		vue_obj.emit('custom_event', event);
	    }
	};
	let v_nodes = col.button_def_array.map((b_def) => {
	    let attributes = {};
	    if (b_def.attributes != null) {
		attributes = b_def.attributes;
	    }
	    let _class = "";
	    if (b_def.class != null && b_def.class.length > 0) {
		_class = b_def.class.join(" ");
	    }
	    if (list_or_array == false) {
		return vue_obj.h("button", { class: `btn btn-sm btn-secondary ${_class}`, style: "margin-right:0.2rem;", onClick: on_click(b_def.event_id), ...attributes }, [ vue_obj.h("span", { class: b_def.icon, style: "", title: _i18n(b_def.title_i18n)}), ]);
	    }
	    return vue_obj.h("a", { class: `${_class}`, onClick: on_click(b_def.event_id), style: "display:inline;", ...attributes }, [ vue_obj.h("span", { class: b_def.icon, style: "margin-right:0.2rem;cursor:pointer;" }), _i18n(b_def.title_i18n)]);
	});
	if (list_or_array == true) {
	    let v_title = vue_obj.h("span", { class: "fas fa-align-justify" });
	    let dropdown =  vue_obj.h(Dropdown, { auto_load: true, button_class: "btn-secondary btn-sm" }, {
		title: () => v_title,
		menu: () => v_nodes,
	    });
	    return dropdown;
	}
	return vue_obj.h("div", {class:"button-group"}, v_nodes);
    };
}

function get_rows_func(table_def, f_get_extra_params_obj, f_on_get_rows) {
    let f_get_column_id = get_column_id_func(table_def);
    return async (active_page, per_page, columns_wrap, map_search, first_get_rows) => {
	let sort_column = columns_wrap.find((c) => c.sort != 0);
	let visible_columns = columns_wrap.filter((c) => c.visible == true)
	    .map((c) => f_get_column_id(c)).join(",");
	let params = {
            start: (active_page * per_page),
            length: per_page,
	    map_search,
	    visible_columns,
	};
	if (sort_column != null) {
	    params.sort = f_get_column_id(sort_column.data);
	    params.order = sort_column.sort == 1 ? "asc" : "desc";
	}
	if (f_get_extra_params_obj != null) {
	    let extra_params = f_get_extra_params_obj();
	    params = { ...params, ...extra_params, };
	}
	const url_params = ntopng_url_manager.obj_to_url_params(params);
	const url = `${http_prefix}/${table_def.data_url}?${url_params}`;
	let res = await ntopng_utility.http_request(url, null, null, true);
	if (f_on_get_rows != null) {
	    f_on_get_rows(params);
	}
	let rows = res.rsp;
	if (table_def.rsp_records_field != null) {
	    rows = res.rsp[table_def.rsp_records_field];
	}
	// fix server rest bug
	if (res.recordsFiltered > res.recordsTotal) {
	    res.recordsTotal = res.recordsFiltered;
	}
	return { total_rows: res.recordsTotal, rows };
    }
}

function get_f_print_column_name(table_def) {
    return (col) => {
	if (col.title_i18n != null) {
            return _i18n(col.title_i18n);
	}
	return "";
    };
}

function get_column_id_func(table_def) {
    return (col) => {
	if (col.id != null) { return col.id; }
	if (col.data_field != null) { return col.data_field; }
	return table_def.columns.findIndex((c) => c == col);
    };
}

function wrap_datatable_columns_config(datatable_columns) {
    return function (col) {
	let name = _i18n(col.name);
	if (name == null || name == "") {
	    return "Test";
	}
	return `${name}`;
    }
}

const table_utils = {
    wrap_datatable_columns_config,
    build_table,
};

export default table_utils;
