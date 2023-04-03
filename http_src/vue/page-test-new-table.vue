<!-- (C) 2022 - ntop.org     -->
<template>
<!-- <div id="aggregated_live_flows">           -->
  <!-- <Datatable ref="table_test" -->
  <!-- 	     :table_buttons="table_config.table_buttons" -->
  <!-- 	     :columns_config="table_config.columns_config" -->
  <!-- 	     :data_url="table_config.data_url" -->
  <!-- 	     :filter_buttons="table_config.table_filters" -->
  <!-- 	     :enable_search="table_config.enable_search" -->
  <!-- 	     :table_config="table_config.table_config"> -->
    <!-- </Datatable> -->
  <!-- </div> -->
<div class="mt-4 card card-shadow">
  <!-- <div class="card-body" style="width: 100%;overflow: scroll;"> -->
  <div class="card-body" style="">
    <Table
      id="page-test"
      :columns="table_config_2.columns"
      :get_rows="table_config_2.get_rows"
      :print_column_name="(col) => table_config_2.print_column_name(col)"
      :print_html_row="(col, row) => table_config_2.print_html_row(col, row)"
      :paging= "false">
    </Table>
  </div>
</div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import NtopUtils from "../utilities/ntop-utils";
import { default as Datatable } from "./datatable.vue";
import { default as Table } from "./table.vue";
import HistoricalFlowsTableConfig from "../constants/historical_flows_table.js";
import TableUtils from "../utilities/table-utils.js";

const _i18n = (t) => i18n(t);

const props = defineProps({
    url: String,
    ifid: Number,
    columns_config: Array
});

const columns = HistoricalFlowsTableConfig.columns;
const table_config_2 = {
    columns: columns,
    get_rows: (active_page, per_page, columns_wrap) => get_rows(active_page, per_page, columns_wrap),
    print_column_name: TableUtils.wrap_datatable_columns_config(columns),
    print_html_row: (col, row) => print_html_row(col, row),
};

const table_config = ref({})
const table_test = ref(null);

async function get_rows(active_page, per_page, columns_wrap) {
    let rows = [];
    for (let i = 0; i < 10000; i += 1) {
	let row = {};
	columns.forEach((c, j) => {
	    row[c.name] = "djaskldasj klasdjkldasj askdljkasdl";
	    if (j == 0) {
		row[c.name] = `${i + 1}`;
	    }
	});
	rows.push(row);
    }
    return {
	rows,
	total_rows: rows.length,
    }
}

function print_html_row(col, row) {
    return row[col.name];
}

onBeforeMount(() => {
    // set_datatable_config();
});

function set_datatable_config() {
    const datatableButton = [];
    
    let params = { 
	ifid: ntopng_url_manager.get_url_entry("ifid") || props.ifid,	
    };
    let url_params = ntopng_url_manager.obj_to_url_params(params);
    
    datatableButton.push({
	text: '<i class="fas fa-sync"></i>',
	className: 'btn-link',
	action: function (e, dt, node, config) {
            table_test.value.reload();
	}
    });
    
    let defaultDatatableConfig = {
	table_buttons: datatableButton,
	data_url: `${props.url}?${url_params}`,
	enable_search: true,
    };
    
    let columns = [];
    
    defaultDatatableConfig.columns_config = props.columns_config;
    table_config.value = defaultDatatableConfig;
}
    
</script>
