{#
  (C) 2022 - ntop.org
  This template is used by the `SSH host details` page inside the `Hosts`.    
#}

<template>

<div class="row">
  <div class="col-md-12 col-lg-12">
    <div class="alert alert-danger d-none" id='alert-row-buttons' role="alert">
    </div>
    <div class="card">
      <div class="card-body">
      	<div id="table_host_ssh">
          <datatable ref="table_hassh"
            :table_buttons="config_devices_standard.table_buttons"
            :columns_config="config_devices_standard.columns_config"
            :data_url="config_devices_standard.data_url"
            :enable_search="config_devices_standard.enable_search"
            :table_config="config_devices_standard.table_config">
          </datatable>
        </div>
      </div>
    </div>
  </div>
</div>
</template>

<script>
import { default as Datatable } from "./datatable.vue";

export default {
  components: {	  
    'datatable': Datatable,
  },
  props: {
    page_csrf: String,
    url_params: Object,
  },
  /**
   * First method called when the component is created.
   */
  created() {
    start_datatable(this);
  },
  mounted() {},    
  data() {
    return {
      i18n: (t) => i18n(t),
      config_devices_standard: null,
      config_devices_centrality: null,
    };
  },
  methods: { 
    /* Method used to switch active table tab */
    reload_table: function() {
      let table = this.get_active_table();
      table.reload();
    },
    get_active_table: function() {
      return this.$refs[`table_hassh`];
    },
  },
}  

function start_datatable(DatatableVue) {
  const datatableButton = [];
  let columns = [];
  let default_sorting_columns = 3 /* Contacts column */;
  
  /* Manage the buttons close to the search box */
  datatableButton.push({
    text: '<i class="fas fa-sync"></i>',
    className: 'btn-link',
    action: function (e, dt, node, config) {
      DatatableVue.reload_table();
    }
  });
  
  let defaultDatatableConfig = {
    table_buttons: datatableButton,
    columns_config: [],
    data_url: NtopUtils.buildURL(`${http_prefix}/lua/rest/v2/get/host/fingerprint/data.lua`, url_params),
    enable_search: true,
  };

  /* Standard table configuration */  

  columns = [
    { columnName: i18n("hassh_fingerprint"), name: 'ja3', data: 'ja3', className: 'text-nowrap', render: (data, type) => {
        return `<a class="ntopng-external-link" href="https://sslbl.abuse.ch/ja3-fingerprints/${data}">${data} <i class="fas fa-external-link-alt"></i></a>`;
      }, responsivePriority: 0, createdCell: DataTableRenders.applyCellStyle },
    { columnName: i18n("status"), name: 'is_malicious', data: 'is_malicious', className: 'text-nowrap text-center', responsivePriority: 0, render: (data, type) => {
        return (data ? `<i class="fa-solid fa-face-frown text-danger" title="${i18n('malicious')}"></i>` : `<i class="fa-solid fa-face-smile text-success" title="${i18n('ok')}"></i>`);
      }
    },
    { columnName: i18n("app_name"), name: 'app_name', data: 'app_name', className: 'text-nowrap text-right', responsivePriority: 1 },
    { columnName: i18n("num_uses"), name: 'num_uses', data: 'num_uses', className: 'text-nowrap text-right', responsivePriority: 1, render: (data) => { return NtopUtils.formatValue(data); } },
  ];

  /* Extra table configuration */
  let table_config = {
    serverSide: false,
    order: [[ default_sorting_columns, 'desc' ]]
  }
  
  let configDevices = ntopng_utility.clone(defaultDatatableConfig);
  configDevices.table_buttons = defaultDatatableConfig.table_buttons;
  configDevices.data_url = `${configDevices.data_url}`;
  configDevices.columns_config = columns;
  configDevices.table_config = ntopng_utility.clone(table_config);
  DatatableVue.config_devices_standard = configDevices;
}
</script>






