<!-- (C) 2022 - ntop.org     -->
<template>
<div v-if="true">
  <!-- <slot name="menu"></slot> -->
</div>
<div>
  <table ref="table_id" class="table w-100 table-striped table-hover table-bordered">
  <thead>
    <tr>
      <th class="text-center" v-for="item in columns_config">{{ item.columnName }}</th>
    </tr>
  </thead>
  <tbody></tbody>
</table>
</div>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount, watch } from "vue";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services";
import { useSlots, render, getCurrentInstance } from 'vue';
import { render_component } from "./ntop_utils.js";

const instance = getCurrentInstance();

const slots = useSlots();
const props = defineProps({
	id: String,
	table_buttons: Array,
	columns_config: Array,
	data_url: String,
	enable_search: Boolean,
	filter_buttons: {
type: Array,
required: false,
	},
	table_config: {
type: Object,
required: false,
	},
	base_url: String,
	base_params: Object, 
});

const emit = defineEmits(['drawed'])

/* Add last sorting preferences to the browser cache in order to reload it the next time */
const save_last_sort = (last_sorting, id) => {
	if(id || props.id) {
		/* Do not save the sorting if the direction is undefined */
		if(last_sorting.dir != undefined) {
			const sorting_pref = [last_sorting.col, last_sorting.dir];
			const sorting_key = `${id || props.id}_sorting_preferences`
			
			/* Use the local storage for the sorting preferences */
			localStorage.setItem(sorting_key, sorting_pref);
		}
	}
}

const load_last_sort = (id) => {
	let sorting_pref = null;
	if(id || props.id) {
		const sorting_key = `${id || props.id}_sorting_preferences`

		/* Use the local storage for the sorting preferences */
		const unformatted_pref = localStorage.getItem(sorting_key);
		if(unformatted_pref) {
			const splitted_pref = unformatted_pref.split(',');
			if(splitted_pref.length == 2) {
				sorting_pref = [ Number(splitted_pref[0]), splitted_pref[1] ];
			}
		}
	}

	return sorting_pref;
}

let new_params = props.base_params
const table_id = ref(null);
/* In case no sorting is provided use the default_sorting */
const last_sorting = load_last_sort() || [0, "asc"];

function loadDatatable() {
    let updated = false;
    /* Create a datatable with the buttons */
    let extend_config = {
	serverSide: false,
	scrollX: false,
	destroy: true,
	searching: props.enable_search,
	order: [last_sorting],
	pagingType: 'full_numbers',
	//columnDefs: props.columns_config,
	columns: props.columns_config,
	autoWidth: false,
	responsive: true,
	ajax: {
	    method: 'get',
	    url: props.data_url,
	    dataSrc: 'rsp',
	    data: (data, settings) => {
		if(Object.keys(data).length == 0) {
		    return;
		}
		
		const tableApi = settings.oInstance.api();
		const orderColumnIndex = data.order[0].column;
		const orderColumnName = tableApi.column(orderColumnIndex).name() || undefined;
		
		if (data.order) {
		    data.order = data.order[0].dir;
		    data.sort = orderColumnName;
		}
		
		if (data.columns !== undefined) {
		    delete data.columns;
		}
		
		if (data.search !== undefined) {
		    data.map_search = data.search.value;
		    delete data.search;
		}
		
		return data;
	    },
	    beforeSend: function() {
		NtopUtils.showOverlays();
	    },
	},
	drawCallback: function (settings) {
	    NtopUtils.hideOverlays();
	    emit('drawed');
	    ntopng_events_manager.emit_custom_event(ntopng_custom_events.DATATABLE_LOADED);		 
		 save_last_sort(settings.aLastSort[0]);
	}
    };
    for (const item in (props.table_config || {})) {
	extend_config[item] = props.table_config[item]
    }
    
    let config = DataTableUtils.getStdDatatableConfig(props.table_buttons);
    config = DataTableUtils.extendConfig(config, extend_config);
    table = $(table_id.value).DataTable(config);
	 load_table_menu();
    for (const filter of (props.filter_buttons || [])) {
	/* Set filters to active if available in the url */
	const curr_value = ntopng_url_manager.get_url_entry(filter.filterMenuKey)
	if(curr_value && curr_value != '') {
	    let num_non_active_entries = 0
	    filter.filters.forEach((i) => {
		i.currently_active = false
		num_non_active_entries += 1
		if(i.id == curr_value) {
		    i.currently_active = true
		    num_non_active_entries -= 1
		}
	    })
	    
	    if(num_non_active_entries == filter.filters.length) {
		ntopng_url_manager.set_key_to_url(filter.filterMenuKey, '');
		updated = true
	    }
	}
	
	new DataTableFiltersMenu({
	    filterTitle: filter.filterTitle,
	    tableAPI: table,
	    filters: filter.filters,
	    filterMenuKey: filter.filterMenuKey,
	    columnIndex: filter.columnIndex,
	    url: props.data_url,
	    id: filter.id,
	    removeAllEntry: filter.removeAllEntry,
	    callbackFunction: filter.callbackFunction
	}).init();
    }
    
    if(updated && props.base_params) {
	const entries = ntopng_url_manager.get_url_entries()
	for(const [key, value] of (entries)) {
	    new_params[key] = value
	}
	table.ajax.url(NtopUtils.buildURL(`${http_prefix}/lua/pro/enterprise/get_map.lua`, new_params))
	reload()
    }
}

let table = null;
onMounted(() => {
    loadDatatable()
});

function get_table_default_menu() {
    if (table == null) { return; }
    let table_wrapper = $(table.context[0].nTableWrapper);
    return $($(".row .text-end", table_wrapper).children()[0]);;
}

function search_value(value_to_search) {
	if (table == null) { return; }
	table.search(value_to_search).draw();
}

let table_default_menu = null;
function load_table_menu() {
    if (table_default_menu == null) {
	table_default_menu = get_table_default_menu();
    }
    if (slots == null || slots.menu == null) { return; }
    let menu_array = slots.menu();
    if (menu_array == null || menu_array.length == 0) { return; }
    let node = slots.menu()[0];
    let element = $("<div class='d-inline-block'></div>")[0];
    const { vNode, el } = render_component(node, { app:  instance?.appContext?.app, element });
    // const { vNode, el } = render_component(Test, { app:  instance.appContext.app });
    let table_wrapper = $(table.context[0].nTableWrapper);
    $($(".row .text-end", table_wrapper).children()[0]).append(el);
}

const reload = () => {
    if (table == null) { return; }
    table.ajax.reload();
}

const update_url = (new_url) => {
    if (table == null) { return; }
    table.ajax.url(new_url);
}

const delete_button_handlers = (handlerId) => {
    DataTableUtils.deleteButtonHandlers(handlerId);
};

let is_destroyed = false;

const destroy_table = () => {
    table.clear();
    table.destroy(true);
    is_destroyed = true;
    props.columns_config.filter((config) => config.handlerId != null).forEach((config) => {
	delete_button_handlers(config.handlerId);
    });
};

const refresh_menu = () => {
    let table_wrapper = $(table.context[0].nTableWrapper);
    $($(".row .text-end", table_wrapper).children()[0]).html("");
    load_table_menu();
};

const is_last_sorting_available = (id) => {
	return load_last_sort(id) != null;
}

defineExpose({ reload, delete_button_handlers, destroy_table, update_url, refresh_menu, is_last_sorting_available, load_last_sort, save_last_sort, search_value });

onBeforeUnmount(() => {
    if (is_destroyed == true) { return; }
    destroy_table();
    // table.destroy(true);
});

</script>

<style scoped>
</style>
