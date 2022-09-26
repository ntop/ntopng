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
      <div class="overlay justify-content-center align-items-center position-absolute h-100 w-100">
        <div class="text-center">
          <div class="spinner-border text-primary mt-5" role="status">
            <span class="sr-only position-absolute">Loading...</span>
          </div>
        </div>
      </div>
      <div class="card-body">
      	<div id="table_asset">
          <modal-delete-confirm ref="modal_delete_all"
            :title="title_delete"
            :body="body_delete"
            @delete="delete_all">
          </modal-delete-confirm>
  
          <tab-list ref="asset_tab_list"
            id="asset_tab_list"
            :tab_list="tab_list"
            @click_item="click_item">
          </tab-list>

          <datatable v-if="asset_table_tab == 'standard'" ref="table_asset_standard"
            :table_buttons="config_devices_standard.table_buttons"
            :columns_config="config_devices_standard.columns_config"
            :data_url="config_devices_standard.data_url"
            :enable_search="config_devices_standard.enable_search"
            :filter_buttons="config_devices_standard.table_filters">
            :table_config="config_devices_standard.table_config">
          </datatable>
          <datatable v-if="asset_table_tab == 'centrality'" ref="table_asset_centrality"
            :table_buttons="config_devices_centrality.table_buttons"
            :columns_config="config_devices_centrality.columns_config"
            :data_url="config_devices_centrality.data_url"
            :enable_search="config_devices_centrality.enable_search"
            :filter_buttons="config_devices_centrality.table_filters">
            :table_config="config_devices_centrality.table_config">
          </datatable>
        </div>
      </div>
      <div class="card-footer">
        <button type="button" id='btn-delete-all' class="btn btn-danger me-1"><i class='fas fa-trash'></i> {{ i18n("map_page.delete_assets") }}</button>
        <a v-bind:href="get_url" class="btn btn-primary" role="button" aria-disabled="true"  download="asset_map.json" target="_blank"><i class="fas fa-download"></i></a>
      </div>
    </div>
  </div>
</div>
</template>

<script>
import { default as Datatable } from "./datatable.vue";
import { default as TabList } from "./tab-list.vue";
import { default as ModalDeleteConfirm } from "./modal-delete-confirm.vue";
import { ntopng_events_manager, ntopng_url_manager } from '../services/context/ntopng_globals_services';
const change_asset_table_tab_event = "change_asset_table_tab_event";

export default {
  components: {	  
    'datatable': Datatable,
    'modal-delete-confirm': ModalDeleteConfirm,
    'tab-list': TabList,
  },
  props: {
    page_csrf: String,
    url_params: Object,
    view: String,
    table_filters: Array,
  },
  /**
   * First method called when the component is created.
   */
  created() {
    ntopng_url_manager.set_key_to_url('asset_family', this.$props.url_params.asset_family);
    start_datatable(this);
  },
  mounted() {
    this.asset_table_tab = ntopng_url_manager.get_url_entry("view") || 'standard'
    this.tab_list.forEach((i) => {
      this.asset_table_tab == i.id ? i.active = true : i.active = false
    });
    ntopng_events_manager.on_custom_event("page_asset_table", ntopng_custom_events.DATATABLE_LOADED, () => {
      if(ntopng_url_manager.get_url_entry('host'))
        this.hide_dropdowns();
    });
    ntopng_events_manager.on_custom_event("change_asset_table_tab", change_asset_table_tab_event, (tab) => {
	    let table = this.get_active_table();
      ntopng_url_manager.set_key_to_url('view', tab);
      table.destroy_table();
      this.asset_table_tab = tab;
    });

    $("#btn-delete-all").click(() => this.show_delete_all_dialog());
  },    
  data() {
    return {
      i18n: (t) => i18n(t),
      config_devices_standard: null,
      config_devices_centrality: null,
      title_delete: i18n('map_page.delete_assets'),
      body_delete: i18n('map_page.delete_assets_message'),
      title_download: i18n('map_page.download'),
      body_download: i18n('map_page.download_message'),
      get_url: null,
      asset_table_tab: null,
      tab_list: [
        { 
          title: i18n('map_page.standard_view'),
          active: (view == 'standard'),
          id: 'standard'
        },
        { 
          title: i18n('map_page.centrality_view'),
          active: (view == 'centrality'),
          id: 'centrality'
        },
      ]
    };
  },
  methods: {
    destroy: function() {
      let table = this.get_active_table();
      table.destroy_table();
    },
    /* Method used to switch active table tab */
    click_item: function(item) {
      this.tab_list.forEach((i) => i.active = false);
      item.active = true;
      ntopng_events_manager.emit_custom_event(change_asset_table_tab_event, item.id);
    },
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
    hide_dropdowns: function() {      
      $(`#network_dropdown`).removeClass('d-inline')
      $(`#vlan_id_dropdown`).removeClass('d-inline')
      $(`#network_dropdown`).attr('hidden', 'hidden')
      $(`#vlan_id_dropdown`).attr('hidden', 'hidden')
    }, 
    reload_table: function() {
      let table = this.get_active_table();
      NtopUtils.showOverlays();
      table.reload();
      NtopUtils.hideOverlays();
    },
    get_active_table: function() {
      return this.$refs[`table_asset_${this.asset_table_tab}`];
    },
    switch_to_standard: function() {
      let new_url = this.url_params
      new_url['view'] = 'standard'
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
  
  DatatableVue.get_url = NtopUtils.buildURL(`${http_prefix}/lua/pro/enterprise/get_map.lua`, url_params)
  
  /* Manage the buttons close to the search box */
  datatableButton.push({
    text: '<i class="fas fa-sync"></i>',
    className: 'btn-link',
    action: function (e, dt, node, config) {
      DatatableVue.reload_table();
    }
  });
  
  let tmp_params = url_params;
  tmp_params['view'] = 'standard'
  
  let defaultDatatableConfig = {
    table_buttons: datatableButton,
    columns_config: [],
    data_url: NtopUtils.buildURL(`${http_prefix}/lua/pro/enterprise/get_map.lua`, tmp_params),
    enable_search: true,
  };

  let table_filters = []
  for (let filter of (DatatableVue.$props.table_filters || [])) {
    filter.callbackFunction = (table, value) => {
      tmp_params['view'] = DatatableVue.asset_table_tab;
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
    { columnName: i18n("map_page.client"), name: 'client', data: 'client', className: 'text-nowrap', responsivePriority: 1 },
    { columnName: i18n("map_page.server"), name: 'server', data: 'server', className: 'text-nowrap', responsivePriority: 1 },
    { columnName: i18n("map_page.asset_family"), name: 'family', data: 'family', className: 'text-nowrap', responsivePriority: 2 },
    { columnName: i18n("map_page.last_seen"), name: 'last_seen', data: 'last_seen',  className: 'text-center', responsivePriority: 2 },
  ];
  
  let configDevices = ntopng_utility.clone(defaultDatatableConfig);
  configDevices.table_config = { serverSide: false, order: [[ 3 /* Last Seen */, 'desc' ]] }
  configDevices.columns_config = columns;
  configDevices.table_filters = table_filters;
  DatatableVue.config_devices_standard = configDevices;


  /* Centrality table configuration */

  tmp_params['view'] = 'centrality'  
  defaultDatatableConfig.data_url = NtopUtils.buildURL(`${http_prefix}/lua/pro/enterprise/get_map.lua`, tmp_params)

  columns = [
    { columnName: i18n("map_page.host"), name: 'host', data: 'host', className: 'text-nowrap', render: (data, type) => { return data.label }, responsivePriority: 1 },
    { columnName: i18n("map_page.asset_total_edges"), name: 'total_edges', data: 'total_edges', className: 'text-nowrap', responsivePriority: 1 },
    { columnName: i18n("map_page.asset_in_edges"), name: 'in_edges', data: 'in_edges', className: 'text-nowrap', responsivePriority: 2 },
    { columnName: i18n("map_page.asset_out_edges"), name: 'out_edges', data: 'out_edges',  className: 'text-center', responsivePriority: 2 },
  ];
  
  let centralityConfigDevices = ntopng_utility.clone(defaultDatatableConfig);
  centralityConfigDevices.table_config = { serverSide: false, order: [[ 1 /* Total Edges */, 'desc' ]] }
  centralityConfigDevices.columns_config = columns;
  centralityConfigDevices.table_filters = table_filters;

  console.log(configDevices)
  console.log(centralityConfigDevices)
  
  DatatableVue.config_devices_centrality = centralityConfigDevices;
}
</script>






