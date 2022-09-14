{#
  (C) 2022 - ntop.org
  This template is used by the `Periodicity Map` page inside the `Hosts` menu.    
#}

<template>

<div class="row">
  <div class="col-md-12 col-lg-12">
    <div class="alert alert-danger d-none" id='alert-row-buttons' role="alert">
    </div>
    <div class="card">
      <div class="overlay justify-content-center align-items-center position-absolute h-100 w-100">
        <div class="text-center">
          <div class="spinner-border text-primary mt-5" role="status">
            <span class="sr-only position-absolute">Loading...</span>
          </div>
        </div>
      </div>
      <div class="card-body">
      	<div id="periodicity-table">
          <modal-delete-confirm ref="modal_delete_all"
            :title="title_delete"
            :body="body_delete"
            @delete="delete_all">
          </modal-delete-confirm>

          <datatable ref="table_periodicity"
            :table_buttons="config_devices_standard.table_buttons"
            :columns_config="config_devices_standard.columns_config"
            :data_url="config_devices_standard.data_url"
            :enable_search="config_devices_standard.enable_search"
            :filter_buttons="config_devices_standard.table_filters"
            :table_config="config_devices_standard.table_config"
            :base_url="base_url"
            :base_params="url_params">
          </datatable>
        </div>
      </div>
      <div class="card-footer">
        <button v-if="is_admin" type="button" id='btn-delete-all' class="btn btn-danger me-1"><i class='fas fa-trash'></i> {{ i18n("map_page.delete_services") }}</button>
        <a v-bind:href="get_url" class="btn btn-primary" role="button" aria-disabled="true"  download="periodicity_map.json" target="_blank"><i class="fas fa-download"></i></a>
      </div>
    </div>
  </div>
</div>
</template>

<script>
import { default as Datatable } from "./datatable.vue";
import { default as ModalDeleteConfirm } from "./modal-delete-confirm.vue";
import { ntopng_url_manager } from '../services/context/ntopng_globals_services';

export default {
  components: {	  
    'datatable': Datatable,
    'modal-delete-confirm': ModalDeleteConfirm,
  },
  props: {
    page_csrf: String,
    url_params: Object,
    view: String,
    table_filters: Array,
    is_admin: Boolean,
  },
  /**
   * First method called when the component is created.
   */
  created() {
    start_datatable(this);
  },
  mounted() {  
    $("#btn-delete-all").click(() => this.show_delete_all_dialog());
  },    
  data() {
    return {
      i18n: (t) => i18n(t),
      base_url: `${http_prefix}/lua/pro/enterprise/get_map.lua`,
      config_devices_standard: null,
      config_devices_centrality: null,
      title_delete: i18n('map_page.delete_services'),
      body_delete: i18n('map_page.delete_services_message'),
      title_download: i18n('map_page.download'),
      body_download: i18n('map_page.download_message'),
      get_url: null,
    };
  },
  methods: { 
    delete_all: async function() {
      let url = `${http_prefix}/lua/pro/enterprise/network_maps.lua`;
      let params = {
        ifid: this.url_params.ifid,
        action: 'reset',
        page: this.url_params.page,
        csrf: this.$props.page_csrf,
        map: this.url_params.map
      };
      try {
        let headers = {
          'Content-Type': 'application/json'
        };
        await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(params) });
        this.reload_table();
      } catch(err) {
        this.reload_table();  
      }      
    },
    reload_table: function() {
      let table = this.get_active_table();
      NtopUtils.showOverlays();
      table.reload();
      NtopUtils.hideOverlays();
    },
    destroy: function() {
      let table = this.get_active_table();
      table.destroy_table();
    },
    get_active_table: function() {
      return this.$refs[`table_periodicity`];
    },
    show_delete_all_dialog: function() {
      this.$refs["modal_delete_all"].show();
    },  
  },
}  

function start_datatable(DatatableVue) {
  const datatableButton = [];
  let columns = [];
  let default_sorting_columns = 0;
  DatatableVue.get_url = NtopUtils.buildURL(`${http_prefix}/lua/pro/enterprise/get_map.lua`, url_params)
  
  /* Manage the buttons close to the search box */
  datatableButton.push({
    text: '<i class="fas fa-sync"></i>',
    className: 'btn-link',
    action: function (e, dt, node, config) {
      DatatableVue.reload_table();
    }
  });
  
  let tmp_params = ntopng_utility.clone(url_params)
  tmp_params['view'] = null
  let defaultDatatableConfig = {
    table_buttons: datatableButton,
    columns_config: [],
    data_url: NtopUtils.buildURL(`${http_prefix}/lua/pro/enterprise/get_map.lua`, tmp_params),
    enable_search: true,
  };

  let table_filters = []
  for (let filter of (DatatableVue.$props.table_filters || [])) {
    filter.callbackFunction = (table, value) => {
      tmp_params[filter.filterMenuKey] = value.id;
      ntopng_url_manager.set_key_to_url(filter.filterMenuKey, value.id);
      table.ajax.url(NtopUtils.buildURL(`${http_prefix}/lua/pro/enterprise/get_map.lua`, tmp_params));
      NtopUtils.showOverlays();
      table.ajax.reload();
      NtopUtils.hideOverlays();
    },
    table_filters.push(filter);
  }
  
  /* Standard table configuration */  

  columns = [
    { columnName: i18n('map_page.last_seen'), name: 'last_seen', data: 'last_seen', className: 'text-center text-nowrap', render: (data, type) => { return data.value }, responsivePriority: 2 },
    { columnName: i18n('map_page.client'), name: 'client', data: 'client', className: 'text-nowrap', responsivePriority: 2 },
    { columnName: i18n('map_page.server'), name: 'server', data: 'server', className: 'text-nowrap', responsivePriority: 2 },
    { columnName: i18n('map_page.port'), name: 'port', data: 'port',  className: 'text-center', responsivePriority: 4 },
    { columnName: i18n('map_page.protocol'), name: 'l7proto', data: 'protocol', className: 'text-nowrap', responsivePriority: 3 },
    { columnName: i18n('map_page.first_seen'), name: 'first_seen', data: 'first_seen', visible: false, responsivePriority: 3 },
    { columnName: i18n('map_page.observations'), name: 'observations', data: 'observations', className: 'text-center', responsivePriority: 4 },
    { columnName: i18n('map_page.frequency'), name: 'frequency', data: 'frequency', className: 'text-center', orderable: true, responsivePriority: 4, render: ( data, type, row ) => {
        return (type == "sort" || type == 'type') ? data : data + " sec"; 
      }
    },
  ];

  default_sorting_columns = 6 /* Observation column */

  /* Extra table configuration */
  let table_config = {
    serverSide: true,
    order: [[ default_sorting_columns, 'desc' ]]
  }
  
  let configDevices = ntopng_utility.clone(defaultDatatableConfig);
  configDevices.table_buttons = defaultDatatableConfig.table_buttons;
  configDevices.data_url = `${configDevices.data_url}`;
  configDevices.columns_config = columns;
  configDevices.table_filters = table_filters;
  configDevices.table_config = ntopng_utility.clone(table_config);
  DatatableVue.config_devices_standard = configDevices;
}
</script>






