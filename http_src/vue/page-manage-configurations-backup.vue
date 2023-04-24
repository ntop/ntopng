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
            <Datatable ref="table_manage_configurations_backup" :id="table_config.id" :key="table_config.data_url"
              :table_buttons="table_config.table_buttons" :columns_config="table_config.columns_config"
              :data_url="table_config.data_url" :table_config="table_config.table_config">

              <template v-slot:menu>
                <div class="d-flex align-items-center">
                </div>
              </template>
            </Datatable>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onBeforeMount } from "vue";
import { default as Datatable } from "./datatable.vue";
import { default as Loading } from "./loading.vue";

const _i18n = (t) => i18n(t);
const table_manage_configurations_backup = ref(null);
const url = `${http_prefix}/lua/rest/v2/get/system/configurations/list_available_backups.lua`
const table_config = ref({})



const format_flows_icon = function (data) {
  const date = new Date(data * 1000);
  return `${date}`;
}


const reload_table = () => {
  table_manage_configurations_backup.value.reload();
}

onBeforeMount(async () => {
  await set_datatable_config();
});

const trigger_download = function(row) {
  window.open(`${http_prefix}/lua/rest/v2/get/system/configurations/download_backup.lua?epoch=${row.epoch}&download=true`);
}

const add_action_column = function (rowData) {
  
  let download_backup_handler = {
    handlerId: "download_backup_handler",
    onClick: () => {
      trigger_download(rowData);
    },
  }

  return DataTableUtils.createActionButtons([
    { class: `pointer`, handler: download_backup_handler, icon: 'fas fa-download fa-lg', title: i18n('download') },
	]);
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
      columnName: _i18n("backup_date"), orderable: false, targets: 0, name: 'epoch', data: 'epoch', className: 'text-left', responsivePriority: 1, render: (data, _, rowData) => {
        return format_flows_icon(data, rowData)
      }
      }, {
      columnName: _i18n("actions"), width: '5%', name: 'actions', className: 'text-center', orderable: false, responsivePriority: 0, render: function (_, type, rowData) { return add_action_column(rowData) } }
        ,
    );



  defaultDatatableConfig.columns_config = columns;
  table_config.value = defaultDatatableConfig;
}

</script>
