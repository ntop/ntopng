<!-- (C) 2022 - ntop.org     -->
<template>
  
<div class="button-group mb-2"> <!-- TableHeader -->
  <div style="float:left;">
    <label>
      Show
      <select v-model="per_page" @click="refresh_table()">
	<option v-for="pp in per_page_options" :value="pp">{{pp}}</option>
      </select>
      Entries
    </label>
  </div>
  <div style="text-align:right;">
    <button class="btn btn-secondary me-1" type="button" @click="refresh_table">
      <i class="fas fa-refresh"></i>
    </button>
    
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

<div class="" style="width: 100%;overflow: scroll;"> <!-- Table SelectTablePage -->
  
  <table v-if="show_table" ref="table" class="table table-striped table-bordered mb-0"> <!-- Table -->
    <thead>
      <tr>
	<template v-for="(col, col_index) in columns_wrap">
	  <th v-if="col.visible" scope="col" style="cursor:pointer;" @click="change_column_sort(col, col_index)">
	    <div style="display:flex;">
	      <span v-html="print_column_name(col.data)" class="wrap-column"></span>
	      <!-- <i v-show="col.sort == 0" class="fa fa-fw fa-sort"></i> -->
	      <i v-show="col.sort == 1" class="fa fa-fw fa-sort-up"></i>
	      <i v-show="col.sort == 2" class="fa fa-fw fa-sort-down"></i>
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
</div> <!-- Table and SelectTablePage -->

<div>
  <SelectTablePage :total_rows="total_rows"
		   :per_page="per_page"
		   @change_active_page="change_active_page">
  </SelectTablePage>
</div>
</template>

<script setup>
import { ref, onMounted, computed, watch, onBeforeUnmount, nextTick } from "vue";
import { default as Dropdown } from "./dropdown.vue";
import { default as SelectTablePage } from "./select_table_page.vue";

const props = defineProps({
    id: String,
    columns: Array,
    get_rows: Function, // async (active_page: number, per_page: number, columns_wrap: any[]) => { total_rows: number, rows: any[] }
    print_column_name: Function,
    print_html_row: Function,
    f_sort_rows: Function,
    paging: Boolean,
});

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

onMounted(async () => {
    set_columns_wrap();
    await set_rows();
    $(table.value).resizableColumns();
    dropdown.value.load_menu();
});

async function change_columns_visibility(col) {
    if (props.paging) {
	await set_rows();
    }
    
    show_table.value = false;
    await nextTick();
    show_table.value = true;
    await nextTick();
    setTimeout(async () => {
	await nextTick();
	$(table.value).resizableColumns()
    }, 0);
}

function set_columns_wrap() {
    columns_wrap.value = props.columns.map((c, i) => {
	return {
	    visible: true,
	    sort: 0,
	    order: i,
	    data: c,
	};
    });
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
    set_rows();
}

async function set_rows() {
    let res = await props.get_rows(active_page, per_page.value, columns_wrap.value);
    total_rows.value = res.rows.length;
    if (props.paging == true) {
	total_rows.value = res.total_rows;
    }
    rows = res.rows;
    set_active_rows();
}

function set_active_rows() {
    let start_row_index = active_page * per_page.value;
    active_rows.value = rows.slice(start_row_index, start_row_index + per_page.value);
}

</script>

<style scoped>
.wrap-column {
  text-overflow: ellipsis;
  white-space: nowrap;
  overflow: hidden;
  width:100%;  
}
/*table {
    table-layout:fixed;
    display: block;
    overflow-x: auto;
    white-space: nowrap;
}*/
</style>
