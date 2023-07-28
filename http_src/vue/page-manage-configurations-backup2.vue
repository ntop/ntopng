<!--
  (C) 2013-22 - ntop.org
-->

<template>
  <div class="row">
    <div class="col-md-12 col-lg-12">
      <div class="card  card-shadow">
        <Loading ref="loading"></Loading>
        <div class="card-body">
          <div id="manage_configurations_backup">
            <Table ref="table_configurations_backup" id="table_configurations_backup"
                               :key="table_config.columns" :columns="table_config.columns"
                               :get_rows="(active_page, per_page, columns_wrap, first_get_rows) => table_config.get_rows(active_page, per_page, columns_wrap, first_get_rows)"
                               :get_column_id="(col) => table_config.get_column_id(col)"
                               :print_column_name="(col) => table_config.print_column_name(col)"
			       :print_html_row="(col, row) => table_config.print_html_row(col, row)"
			       :f_is_column_sortable="is_column_sortable"
			       :enable_search="true"
			       :paging="true">
                        </Table>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { default as Table } from "./table.vue";
import { default as Loading } from "./loading.vue";

const _i18n = (t) => i18n(t);
const table_manage_configurations_backup = ref(null);
const url = `${http_prefix}/lua/rest/v2/get/system/configurations/all_backups.lua`
const table_config = ref({})

function load_table() {
    table_config.value = {
        columns: get_table_columns_config(),
        get_rows: get_rows,
        get_column_id: get_column_id,
        print_column_name: print_column_name,
        print_html_row: print_html_row,
        paging: true,
    };
}

const props = defineProps({
    page: Number,
    sort: String,
    order: String,
    start: Number,
    length: Number
});

const format_flows_icon = function (data) {
  const date = new Date(data * 1000);
  return `${date}`;
}

const is_column_sortable = (col) => {
    return col.data != "epoch" && col.data != "actions";
};

function print_html_row(col, row) {
    // console.log(`counter: ${counter}; col: ${col.data}; row:${row[col.data]}`);
    counter += 1;
    let data = row[col.data];
    if (col.render != null) {
        return col.render(data, null, row);
    }
    return data;
}

function print_column_name(col) {
    if (col.columnName == null || col.columnName == "") {
        return "";
    }
    return col.columnName;
}

function get_column_id(col) {
    return col.data;
}

function get_url_params(active_page, per_page, columns_wrap, map_search, first_get_rows) {
    let sort_column = columns_wrap.find((c) => c.sort != 0);

    let actual_params = {
        page: ntopng_url_manager.get_url_entry("page") || props.page,
        sort: ntopng_url_manager.get_url_entry("sort") || props.sort,
        order: ntopng_url_manager.get_url_entry("order") || props.order,
        start: (active_page * per_page),
        length: per_page,
	map_search,
    };
    if (first_get_rows == false) {
        if (sort_column != null) {
            actual_params.sort = sort_column.data.data;
            actual_params.order = sort_column.sort == 1 ? "asc" : "desc";
        }
        // actual_params.start = (active_page * per_page);
        // actual_params.length = per_page;
    }

    return actual_params;
}

const get_rows = async (active_page, per_page, columns_wrap, map_search, first_get_rows) => {
    // loading.value.show_loading();

    let params = get_url_params(active_page, per_page, columns_wrap, map_search, first_get_rows);
    const url_params = ntopng_url_manager.obj_to_url_params(params);
    const url_ = `${url}?${url_params}`;
    // debugger;

    let res = await ntopng_utility.http_request(url_, null, null, true);
    // if (res.rsp.length > 0) { res.rsp[0].server_name.alerted = true };
    return { total_rows: res.recordsTotal, rows: res.rsp };

    // loading.value.hide_loading();
};

const reload_table = () => {
  table_manage_configurations_backup.value.reload();
}

onBeforeMount(async () => {
  await set_datatable_config();
});

onMounted(async () => {
    load_table();
});

const load_selected_field = async function(row) {
    return await `${http_prefix}/lua/rest/v2/get/system/configurations/backup.lua?epoch=${row.data}&download=true`;
}

const add_action_column = function (rowData) {
  

  let dowload_backup_handler = {
    handlerId: "dowload_backup_handler",
    onClick: () => {
      load_selected_field(rowData);
    },
  }
  
  return DataTableUtils.createActionButtons([
    { class: `pointer`, handler: dowload_backup_handler, icon: 'fa-arrow-down', title: i18n('download') },
	]);
}

function get_table_columns_config() {
  let columns = [];

  columns.push(
    {
      columnName: _i18n("backup_date"), orderable: false, targets: 0, name: 'epoch', data: 'epoch', className: 'text-left', responsivePriority: 1, render: (data, _, rowData) => {
        return format_flows_icon(data, rowData)
      }
      }, {
      columnName: _i18n("actions"), width: '5%', name: 'actions', className: 'text-center', orderable: false, responsivePriority: 0, render: function (_, type, rowData) { return add_action_column(rowData) } }
        ,
    );
  
  return columns;
}

async function set_datatable_config() {
  const datatableButton = [];


  /* Manage the buttons close to the search box */
  datatableButton.push({
    text: '<i class="fas fa-sync"></i>',
    className: 'btn-link',
    action: function (e, dt, node, config) {
      reload_table();
    }
  });


  let defaultDatatableConfig = {
    table_buttons: datatableButton,
    data_url: `${url}`,
    enable_search: true,
    id: "manage_configurations_backup",
    table_config: {
      serverSide: false,
      responsive: false,
      scrollX: true,
      columnDefs: [
        { type: "file-size", targets: 0 },
      ]
    }
  };

  let columns = [];

  columns.push(
    {
      columnName: _i18n("backup_date"), orderable: false, targets: 0, name: 'epoch', data: 'epoch', className: 'text-center', responsivePriority: 1, render: (data, _, rowData) => {
        return format_flows_icon(data, rowData)
      }
    });



  defaultDatatableConfig.columns_config = columns;
  table_config.value = defaultDatatableConfig;
}

</script>
