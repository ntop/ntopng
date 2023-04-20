<!-- (C) 2022 - ntop.org     -->
<template>
<div>
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
    <button class="btn btn-link me-1" type="button" @click="reset_column_size">
      <i class="fas fa-columns"></i>
    </button>
    <button class="btn btn-link me-1" type="button" @click="refresh_table">
      <i class="fas fa-refresh"></i>
    </button>
    <div v-if="enable_search" class="d-inline">
      <label>{{ _i18n('search') }}:
	<input type="search" v-model="map_search" @input="on_change_map_search" class="" >
      </label>
    </div>
    
    <Dropdown :id="id" ref="dropdown"> <!-- Dropdown columns -->
      <template v-slot:title>
	<i class="fas fa-eye"></i>
      </template>
      <template v-slot:menu>
	<div v-for="col in columns_wrap" class="form-check form-switch ms-1">
	  <input class="form-check-input" v-model="col.visible" @click="change_columns_visibility(col)"  checked="" type="checkbox" id="toggle-Begin">
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
	  <th v-if="col.visible" scope="col" :class="{'pointer': col.sortable, 'unset': !col.sortable }" style="white-space: nowrap;" @click="change_column_sort(col, col_index)" :data-resizable-column-id="get_column_id(col.data)">
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
      <tr v-for="row in active_rows">
	<template v-for="col in columns_wrap">
	  <td v-if="col.visible" scope="col"><div class="wrap-column" v-html="print_html_row(col.data, row)"></div></td>
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
import { default as Dropdown } from "./dropdown.vue";
import { default as SelectTablePage } from "./select_table_page.vue";

const props = defineProps({
    id: String,
    columns: Array,
    get_rows: Function, // async (active_page: number, per_page: number, columns_wrap: any[], search_map: string, first_get_rows: boolean) => { total_rows: number, rows: any[] }
    get_column_id: Function,
    print_column_name: Function,
    print_html_row: Function,
    f_is_column_sortable: Function,
    f_sort_rows: Function,
    enable_search: Boolean,
    paging: Boolean,
});

const _i18n = (t) => i18n(t);

const show_table = ref(true);
const table = ref(null);
const dropdown = ref(null);
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

onMounted(async () => {
    if (props.columns != null) {
	load_table();
    }
});

watch(() => props.columns, (cur_value, old_value) => {
    load_table();
}, { flush: 'pre'});

async function load_table() {
    set_columns_wrap();
    await set_rows();
    set_columns_resizable();
    await nextTick();
    dropdown.value.load_menu();
}

async function change_columns_visibility(col) {    
    if (props.paging) {
	await set_rows();
    }
    redraw_table();
    await redraw_table_resizable();
    set_columns_resizable();
}

async function redraw_table_resizable() {
    redraw_table();
    await nextTick();
    set_columns_resizable();
}

const table_key = ref(0);
function redraw_table() {
    table_key.value += 1;
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

function set_columns_wrap() {
    columns_wrap.value = props.columns.map((c, i) => {
	return {
	    visible: true,
	    sort: 0,
	    sortable: is_column_sortable(c),
	    order: i,
	    data: c,
	};
    });
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

function change_column_sort(col, col_index) {
    if (col.sortable == false) {
	return;
    }
    col.sort = (col.sort + 1) % 3;
    columns_wrap.value.filter((c, i) => i != col_index).forEach((c) => c.sort = 0);
    if (col.sort == 0) { return; }
    if (props.paging) {
	set_rows();
	return;
    }
    let f_sort = get_sort_function();
    rows = rows.sort((r0, r1) => {
	return f_sort(col, r0, r1);
    });
    set_active_rows();
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
    let res = await props.get_rows(active_page, per_page.value, columns_wrap.value, map_search.value, first_get_rows);
    first_get_rows = false;
    total_rows.value = res.rows.length;
    if (props.paging == true) {
	total_rows.value = res.total_rows;
    }
    rows = res.rows;
    set_active_rows();
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
/*table {
    table-layout:fixed;
    display: block;
    overflow-x: auto;
    white-space: nowrap;
}*/
</style>
