{#
  (C) 2022 - ntop.org
  This template is used by the `Service Map` page inside the `Hosts` menu.    
#}

<template>

<div class="row">
  <div class="col-md-12 col-lg-12">
    <div class="alert alert-danger d-none" id='alert-row-buttons' role="alert">
    </div>
    <div class="card">
      <div class="card-body">
      	<div id="table_asset">
          <modal-delete-confirm ref="modal_delete_all"
            :title="title_delete"
            :body="body_delete"
            @delete="delete_all">
          </modal-delete-confirm>
  -->        
          <div class="card-header mb-2">
            <ul class="nav nav-tabs card-header-tabs" role="tablist">
              <li class="nav-item">
                <a class="nav-link" href="#" v-bind:class="(view === 'main' ) ? 'active' : '' " @click="switch_to_standard">{{ i18n('map_page.standard_view') }}</a>
              </li>
              <li class="nav-item">
                <a class="nav-link" href="#" v-bind:class="(view === 'centrality' ) ? 'active' : '' " @click="switch_to_centrality">{{ i18n('map_page.centrality_view') }}</a>
              </li>
            </ul>
          </div>

          <datatable ref="table_asset"
            :table_buttons="config_devices.table_buttons"
            :columns_config="config_devices.columns_config"
            :data_url="config_devices.data_url"
            :enable_search="config_devices.enable_search">
          </datatable>
        </div>
      </div>
      <div class="card-footer">
        <button type="button" id='btn-delete-all' class="btn btn-danger">
          <i class='fas fa-trash'></i> {{ i18n("map_page.flush") }}
        </button>
        <a :href="full_url" class="btn btn-primary" role="button" aria-disabled="true"  download="asset_map.json" target="_blank"><i class="fas fa-download"></i></a>
      </div>
    </div>
  </div>
</div>
</template>

<script>
import { default as Datatable } from "./datatable.vue";
import { default as ModalDeleteConfirm } from "./modal-delete-confirm.vue";

export default {
  components: {	  
    'datatable': Datatable,
    'modal-delete-confirm': ModalDeleteConfirm,
  },
  props: {
    page_csrf: String,
    url_params: Object,
    full_url: String,
    view: Boolean,
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
      config_devices: null,
      title_delete: i18n('map_page.delete'),
      body_delete: i18n('map_page.delete_message'),
      title_download: i18n('map_page.download'),
      body_download: i18n('map_page.download_message'),
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
        table.reload();
      },
      get_active_table: function() {
        return this.$refs[`table_asset`];
      },
      switch_to_standard: function() {
        let new_url = this.url_params
        new_url['view'] = 'main'
        document.location.href = NtopUtils.buildURL(`${http_prefix}/lua/pro/enterprise/network_maps.lua`, url_params)
      },
      switch_to_centrality: function() {
        let new_url = this.url_params
        new_url['view'] = 'centrality'
        document.location.href = NtopUtils.buildURL(`${http_prefix}/lua/pro/enterprise/network_maps.lua`, url_params)
      },
      show_delete_all_dialog: function() {
        this.$refs["modal_delete_all"].show();
      },
    },
  }  

  function start_datatable(DatatableVue) {
    const datatableButton = [];
    let columns = [];

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
      data_url: NtopUtils.buildURL(`${http_prefix}/lua/pro/enterprise/get_map.lua`, url_params),
      enable_search: true,
    };
    
    /* Define the columns */
      
    if(view && view == 'centrality') {
      columns = [
        { columnName: i18n("map_page.host"), name: 'host', data: 'host', className: 'text-nowrap', render: (data, type) => { return data.label }, responsivePriority: 1 },
        { columnName: i18n("map_page.total_edges"), name: 'total_edges', data: 'total_edges', className: 'text-nowrap', responsivePriority: 1 },
        { columnName: i18n("map_page.in_edges"), name: 'in_edges', data: 'in_edges', className: 'text-nowrap', responsivePriority: 2 },
        { columnName: i18n("map_page.out_edges"), name: 'out_edges', data: 'out_edges',  className: 'text-center', responsivePriority: 2 },
      ];
    } else {
      columns = [
        { columnName: i18n("map_page.host"), name: 'host', data: 'host', className: 'text-nowrap', render: (data, type) => { return data.label }, responsivePriority: 1 },
        { columnName: i18n("map_page.total_edges"), name: 'total_edges', data: 'total_edges', className: 'text-nowrap', responsivePriority: 1 },
        { columnName: i18n("map_page.in_edges"), name: 'in_edges', data: 'in_edges', className: 'text-nowrap', responsivePriority: 2 },
        { columnName: i18n("map_page.out_edges"), name: 'out_edges', data: 'out_edges',  className: 'text-center', responsivePriority: 2 },
      ];
    }
    
    let configDevices = ntopng_utility.clone(defaultDatatableConfig);
    configDevices.table_buttons = defaultDatatableConfig.table_buttons;
    configDevices.data_url = `${configDevices.data_url}`;
    configDevices.columns_config = columns;
    DatatableVue.config_devices = configDevices;
/*
    const vlanFilters = {* json.encode(map.filters.vlan_filters) *};
    const assetFamilyFilters = {* json.encode(map.filters.asset_family_filters) *};

  {% if interface.hasVLANs() then %}
    const vlanMenuFilters = new DataTableFiltersMenu({
      filterTitle: "{{ i18n('vlan') }}",
      tableAPI: $mapTable,
      filters: vlanFilters,
      filterMenuKey: 'vlan_id',
      columnIndex: 0,
      url: url
    }).init();
  {% end %}

  const networkMenuFilters = new DataTableFiltersMenu({
    filterTitle: "{{ i18n('map_page.asset_family') }}",
    removeAllEntry: true,
    tableAPI: $mapTable,
    filters: assetFamilyFilters,
    filterMenuKey: 'asset_family',
    columnIndex: 0,
    url: url
  }).init();

*/
  }
</script>






