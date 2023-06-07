<!-- (C) 2022 - ntop.org     -->
<template>
    <slot name="custom_header2"></slot>
<div ref="table_container" :id="id">
  <Loading v-if="loading"></Loading>
<div class="button-group mb-2"> <!-- TableHeader -->
  <div style="float:left;margin-top:0.5rem;">
    <label>
      Show
      <select v-model="per_page" @change="change_per_page">
	<option v-for="pp in per_page_options" :value="pp">{{pp}}</option>
      </select>
      Entries
    </label>
  </div>
  <div style="text-align:right;" class="form-group ">
  </div>
  
  <div style="text-align:right;" class="form-group ">
    <slot name="custom_header"></slot>

    <div v-if="enable_search" class="d-inline">
      <label>{{ _i18n('search') }}:
	<input type="search" v-model="map_search" @input="on_change_map_search" class="" >
      </label>
    </div>
    <button class="btn btn-link me-1" type="button" @click="reset_column_size">
      <i class="fas fa-columns"></i>
    </button>
    <button class="btn btn-link me-1" type="button" @click="refresh_table">
      <i class="fas fa-refresh"></i>
    </button>
    
    <Dropdown :id="id + '_dropdown'" ref="dropdown"> <!-- Dropdown columns -->
      <template v-slot:title>
	<i class="fas fa-eye"></i>
      </template>
      <template v-slot:menu>
	<div v-for="col in columns_wrap" class="form-check form-switch ms-1">
	  <input class="form-check-input" style="cursor:pointer;" :checked="col.visible == true" @click="change_columns_visibility(col)"  checked="" type="checkbox" id="toggle-Begin">
          <label class="form-check-label" for="toggle-Begin" v-html="print_column_name(col.data)">
          </label>
	</div>
      </template>
    </Dropdown> <!-- Dropdown columns -->
  </div>
</div> <!-- TableHeader -->

<div :key="table_key" class="" style="overflow:auto;width:100%;"> <!-- Table -->
  
  <table ref="table" class="table table-striped table-bordered ml-0 mr-0 mb-0 " style="table-layout: auto; white-space: nowrap;" data-resizable="true" :data-resizable-columns-id="id"> <!-- Table -->
    <thead>
      <tr>
	<template v-for="(col, col_index) in columns_wrap">
	  <th v-if="col.visible" scope="col" :class="{'pointer': col.sortable, 'unset': !col.sortable, }" style="white-space: nowrap;" @click="change_column_sort(col, col_index)" :data-resizable-column-id="get_column_id(col.data)">
	    <div style="display:flex;">
	      <span v-html="print_column_name(col.data)" class="wrap-column"></span>
	      <!-- <i v-show="col.sort == 0" class="fa fa-fw fa-sort"></i> -->
	      
	      <i v-show="col.sort == 1 && col.sortable" class="fa fa-fw fa-sort-up"></i>
	      <i v-show="col.sort == 2 && col.sortable" class="fa fa-fw fa-sort-down"></i>
	    </div>
	  </th>
	</template>
      </tr>
    </thead>
    <tbody>
      <tr v-if="!changing_column_visibility" v-for="row in active_rows">
	<template v-for="(col, col_index) in columns_wrap">
	  <td v-if="col.visible" scope="col" >
	    <div v-if="print_html_row != null && print_html_row(col.data, row, true) != null" :class="col.classes" class="wrap-column" :style="col.style" v-html="print_html_row(col.data, row)">
	    </div>
	    <div :class="col.classes" class="wrap-column">
	      <VueNode v-if="print_vue_node_row != null && print_vue_node_row(col.data, row, vue_obj, true) != null" :content="print_vue_node_row(col.data, row, vue_obj)"></VueNode>
	    </div>
	  </td>
	</template>
      </tr>
    </tbody>
  </table> <!-- Table -->
</div> <!-- Table div-->

<div>
  <SelectTablePage
    ref="select_table_page"
    :key="select_pages_key"
    :total_rows="total_rows"
    :per_page="per_page"
    @change_active_page="change_active_page">
  </SelectTablePage>
</div>

</div>
</template>

<script setup>
import { ref, onMounted, computed, watch, onBeforeUnmount, nextTick } from "vue";
import { getCurrentInstance, h, render } from 'vue';
import { render_component } from "./ntop_utils.js";
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import { default as Dropdown } from "./dropdown.vue";
import { default as SelectTablePage } from "./select_table_page.vue";
import { default as VueNode } from "./vue_node.vue";
import { default as Loading } from "./loading.vue";

const emit = defineEmits(['custom_event', 'loaded'])
const vue_obj = {
    emit,
    h,
    nextTick,
};

const props = defineProps({
    id: String,
    columns: Array,
    get_rows: Function, // async (active_page: number, per_page: number, columns_wrap: any[], search_map: string, first_get_rows: boolean) => { total_rows: number, rows: any[] }
    get_column_id: Function,
    print_column_name: Function,
    print_html_row: Function,
    print_vue_node_row: Function,
    f_is_column_sortable: Function,
    f_sort_rows: Function,
    f_get_column_classes: Function,
    f_get_column_style: Function,
    enable_search: Boolean,
    csrf: String,
    paging: Boolean,
});

const _i18n = (t) => i18n(t);

const show_table = ref(true);
const table_container = ref(null);
const table = ref(null);
const dropdown = ref(null);
const rows_html_element = ref([]);
let active_page = 0;
let rows = [];
const columns_wrap = ref([]);
const active_rows = ref([]);
const total_rows = ref(0);
const per_page_options = [10, 20, 40, 50, 80, 100];
const per_page = ref(10);
const store = window.store;
const map_search = ref("");

const select_table_page = ref(null);
const loading = ref(false);

onMounted(async () => {
    if (props.columns != null) {
	load_table();
    }
});

watch(() => props.columns, (cur_value, old_value) => {
    load_table();
}, { flush: 'pre'});

async function load_table() {
    await set_columns_wrap();
    await set_rows();
    set_columns_resizable();
    await nextTick();
    dropdown.value.load_menu();
    emit("loaded");
}

const changing_column_visibility = ref(false);
async function change_columns_visibility(col) {
    changing_column_visibility.value = true;
    col.visible = !col.visible;
    if (props.paging) {
	await set_rows();
    }
    // redraw_table();
    await redraw_table_resizable();
    await set_columns_visibility();
    // set_columns_resizable();
    changing_column_visibility.value = false;
}

async function redraw_table_resizable() {
    await redraw_table();
    set_columns_resizable();
}

const table_key = ref(0);
async function redraw_table() {
    table_key.value += 1;
    await nextTick();
}

function set_columns_resizable() {
    let options = {
	// selector: table.value,
	// padding: 0,
	store: store,
	minWidth: 32,
	// padding: -50,
	// maxWidth: 150,
    };
    $(table.value).resizableColumns(options);
    // $(table.value).css('width', '100%');
}

async function get_columns_visibility_dict() {
    if (props.csrf == null) { return {}; }
    const params = { table_id: props.id };
    const url_params = ntopng_url_manager.obj_to_url_params(params);
    const url = `${http_prefix}/lua/rest/v2/get/tables/user_columns_config.lua?${url_params}`;
    let columns_visible = await ntopng_utility.http_request(url);
    let columns_visible_dict = {};
    columns_visible.forEach((c) => {
	columns_visible_dict[c.id] = c;
    });
    return columns_visible_dict;
}

async function set_columns_visibility() {
    if (props.csrf == null) { return; }
    let params = { table_id: props.id, visible_columns_ids: [], csrf: props.csrf };
    params.visible_columns_ids = columns_wrap.value.map((c, i) => {
	return {
	    id: c.id,
	    visible: c.visible,
	    order: c.order,
	    sort: c.sort,
	};
    });
    const url = `${http_prefix}/lua/rest/v2/add/tables/user_columns_config.lua`;
    await ntopng_utility.http_post_request(url, params);
}

async function set_columns_wrap() {
    let cols_visibility_dict = await get_columns_visibility_dict();
    columns_wrap.value = props.columns.map((c, i) => {
	let classes = [];
	let style = "";
	if (props.f_get_column_classes != null) {
	    classes = props.f_get_column_classes(c);
	}
	if (props.f_get_column_style != null) {
	    style = props.f_get_column_style(c);
	}
	let id = props.get_column_id(c);
	let col_opt = cols_visibility_dict[id];
	return {
	    id,
	    visible: col_opt?.visible == null || col_opt?.visible == true,
	    sort: col_opt?.sort || 0,
	    sortable: is_column_sortable(c),
	    order: col_opt?.order || i,
	    classes,
	    style,
	    data: c,
	};
    });
    await set_columns_visibility();
}

async function reset_column_size() {
    props.columns.forEach((c) => {
	let id = `${props.id}-${props.get_column_id(c)}`;
	store.remove(id);
    });
    await redraw_table_resizable();
}

function change_per_page() {
    redraw_select_pages();
    change_active_page(0);
}

const select_pages_key = ref(0);
function redraw_select_pages() {
    select_pages_key.value += 1;
}

async function change_active_page(new_active_page) {
    active_page = new_active_page;
    if (props.paging == true) {
	await set_rows();
    } else {
	set_active_rows();
    }
}

async function change_column_sort(col, col_index) {
    if (col.sortable == false) {
	return;
    }
    col.sort = (col.sort + 1) % 3;
    columns_wrap.value.filter((c, i) => i != col_index).forEach((c) => c.sort = 0);
    if (col.sort == 0) { return; }
    if (props.paging) {
	await set_rows();
    } else {
	let f_sort = get_sort_function();
	rows = rows.sort((r0, r1) => {
	    return f_sort(col, r0, r1);
	});
	set_active_rows();
    }
    await set_columns_visibility();
}

function get_sort_function() {
    if (props.f_sort_rows != null) {
	return props.f_sort_rows;
    }
    return (col, r0, r1) => {
	let r0_col = props.print_html_row(col.data, r0);
	let r1_col = props.print_html_row(col.data, r1);
	if (col.sort == 1) {
	    return r0_col.localeCompare(r1_col);
	}
	return r1_col.localeCompare(r0_col);	
    };
}

function refresh_table() {
    select_table_page.value.change_active_page(0, 0);
}

let first_get_rows = true;
async function set_rows() {
    loading.value = true;
    let res = await props.get_rows(active_page, per_page.value, columns_wrap.value, map_search.value, first_get_rows);
    first_get_rows = false;
    total_rows.value = res.rows.length;
    if (props.paging == true) {
	total_rows.value = res.total_rows;
    }
    rows = res.rows;
    set_active_rows();    
    loading.value = false;
}

function is_column_sortable(col) {
    if (props.f_is_column_sortable != null) {
	return props.f_is_column_sortable(col);
    }
    return true;
}

function set_active_rows() {
    let start_row_index = 0;
    if (props.paging == false) {
	start_row_index = active_page * per_page.value;
    }
    active_rows.value = rows.slice(start_row_index, start_row_index + per_page.value);
}

let map_search_change_timeout;
async function on_change_map_search() {
    let timeout = 1000;
    if (map_search_change_timeout != null) {
	clearTimeout(map_search_change_timeout);
    } else {
	timeout = 0;
    }
    map_search_change_timeout = setTimeout(async () => {
	await set_rows();
	map_search_change_timeout = null;
    }, timeout);
    
}

defineExpose({ load_table, refresh_table });

</script>

<style scoped>
  .sticky {
  position: sticky;
  left: 0;
  background-color: white;
  }
.wrap-column {
  text-overflow: ellipsis;
  white-space: nowrap;
  overflow: hidden;
  width:100%;  
}
.pointer {
  cursor: pointer;
}
.unset {
  cursor: unset;
}
.link-button {
    color: var(--bs-dropdown-link-color);
    cursor: pointer;
}
.link-disabled {
    pointer-events: none;
    color: #ccc;
}
/*table {
    table-layout:fixed;
    display: block;
    overflow-x: auto;
    white-space: nowrap;
}*/
</style>
