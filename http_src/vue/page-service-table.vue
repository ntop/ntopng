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
      	<div id="table_service">
          <modal-delete-confirm ref="modal_delete_all"
            :title="title_delete"
            :body="body_delete"
            @delete="delete_all">
          </modal-delete-confirm>
  
          <tab-list ref="tab_list"
            id="tab_list"
            :tab_list="tab_list"
            @click_item="click_item">
          </tab-list>

          <datatable v-if="service_table_tab == 'standard'" ref="table_service_standard"
            :table_buttons="config_devices_standard.table_buttons"
            :columns_config="config_devices_standard.columns_config"
            :data_url="config_devices_standard.data_url"
            :enable_search="config_devices_standard.enable_search"
            :filter_buttons="config_devices_standard.table_filters"
            :table_config="config_devices_standard.table_config">
          </datatable>
          <datatable v-if="service_table_tab == 'centrality'" ref="table_service_centrality"
            :table_buttons="config_devices_centrality.table_buttons"
            :columns_config="config_devices_centrality.columns_config"
            :data_url="config_devices_centrality.data_url"
            :enable_search="config_devices_centrality.enable_search"
            :filter_buttons="config_devices_centrality.table_filters"
            :table_config="config_devices_centrality.table_config">
          </datatable>
        </div>
      </div>
      <div class="card-footer">
<!--
        {% if is_admin then %}
          <form class="d-inline" id='switch-state-form'>
            <div class="form-group mb-3 d-inline">
              <label>{* i18n("map_page.set_state", {label = "<span class='count'></span>"}) *}</label>
              <select name="new_state" class="form-select d-inline" style="width: 16rem" {{ ternary(map.services_num == 0, "disabled='disabled'", "") }}>
              {% for _, status in pairsByField(map.filters.service_status_filters, label, asc_insensitive) do %}
                <option value="{{ status.id }}">{* status.label *}</option>
              {% end %}
              </select>
              <button class="btn btn-secondary d-inline" class="btn-switch-state" {{ ternary(map.services_num == 0, "disabled='disabled'", "") }}>
                <i class="fas fa-random"></i> {{ i18n("set") }}
              </button>
            </div>
          </form>
        {% end %}
    --> 
        <button type="button" id='btn-delete-all' class="btn btn-danger me-1"><i class='fas fa-trash'></i> {{ i18n("map_page.delete_services") }}</button>
        <a v-bind:href="get_url" class="btn btn-primary" role="button" aria-disabled="true"  download="service_map.json" target="_blank"><i class="fas fa-download"></i></a>
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
import { ntopng_map_manager } from '../utilities/map/ntopng_vis_network_utils';
const change_table_tab_event = "change_table_tab_event";

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
    is_admin: Boolean,
    service_acceptance: Array,
  },
  /**
   * First method called when the component is created.
   */
  created() {
    start_datatable(this);
  },
  mounted() {
    ntopng_events_manager.on_custom_event("change_service_table_tab", change_table_tab_event, (tab) => {
	    let table = this.get_active_table();
      ntopng_url_manager.set_key_to_url('view', tab);
      table.delete_button_handlers(this.service_table_tab);
      table.destroy_table();
      this.service_table_tab = tab;
    });
    $("#btn-delete-all").click(() => this.show_delete_all_dialog());
  },    
  data() {
    return {
      i18n: (t) => i18n(t),
      config_devices_standard: null,
      config_devices_centrality: null,
      title_delete: i18n('map_page.delete_services'),
      body_delete: i18n('map_page.delete_services_message'),
      get_url: null,
      service_table_tab: 'standard',
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
    /* Method used to switch active table tab */
    click_item: function(item) {
      this.tab_list.forEach((i) => i.active = false);
      item.active = true;
      ntopng_events_manager.emit_custom_event(change_table_tab_event, item.id);
    },
    create_action_buttons: function(data, type, service) {
      const reload = this.reload_table
      const csrf = this.$props.page_csrf
      const toggle_allowed_state = {
        onClick: () => {
          ntopng_map_manager.toggle_state(service.hash_id, this.$props.service_acceptance[0].id, reload, csrf)
        }
      };
      const toggle_denied_state = {
        onClick: () => {
          ntopng_map_manager.toggle_state(service.hash_id, this.$props.service_acceptance[1].id, reload, csrf)
        }
      };
      const toggle_undecided_state = {
        onClick: () => {
          ntopng_map_manager.toggle_state(service.hash_id, this.$props.service_acceptance[2].id, reload, csrf)
        }
      };

      if (type !== "display") return data;
      const currentStatus = service.acceptance
      const allowedButton = { class: 'dropdown-item', href: '#', title: this.$props.service_acceptance[0].label, handler: toggle_allowed_state };
      const deniedButton = { class: 'dropdown-item', href: '#', title: this.$props.service_acceptance[1].label, handler: toggle_denied_state };
      const undecidedButton = { class: 'dropdown-item disabled', href: '#', title: this.$props.service_acceptance[2].label, handler: toggle_undecided_state };
      
      switch (currentStatus) {
        case 0: /* Allowed */   { allowedButton.class = 'dropdown-item active'; break; }
        case 1: /* Denied */    { deniedButton.class = 'dropdown-item active'; break; }
        case 2: /* Undecided */ { undecidedButton.class = 'dropdown-item active disabled'; break; }
      }
      return DataTableUtils.createActionButtons([undecidedButton, allowedButton, deniedButton]);
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
    reload_table: function() {
      let table = this.get_active_table();
      table.reload();
    },
    get_active_table: function() {
      return this.$refs[`table_service_${this.service_table_tab}`];
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
      tmp_params['view'] = DatatableVue.service_table_tab;
      tmp_params[filter.filterMenuKey] = value.id;
      ntopng_url_manager.set_key_to_url(filter.filterMenuKey, value.id);
      table.ajax.url(NtopUtils.buildURL(`${http_prefix}/lua/pro/enterprise/get_map.lua`, tmp_params));
      table.ajax.reload();
    },
    table_filters.push(filter);
  }
  
  /* Standard table configuration */  

  columns = [
    { columnName: i18n("map_page.last_seen"), name: 'last_seen', data: 'last_seen', className: 'text-center text-nowrap', render: (data, type) => { return data.value }, responsivePriority: 2, createdCell: DataTableRenders.applyCellStyle },
    { columnName: i18n("map_page.client"), name: 'client', data: 'client', className: 'text-nowrap', responsivePriority: 2 },
    { columnName: i18n("map_page.server"), name: 'server', data: 'server', className: 'text-nowrap', responsivePriority: 2 },
    { columnName: i18n("map_page.port"), name: 'port', data: 'port',  className: 'text-center', responsivePriority: 4 },
    { columnName: i18n("map_page.protocol"), name: 'l7proto', data: 'protocol', className: 'text-nowrap', responsivePriority: 3 },
    { columnName: i18n("map_page.first_seen"), name: 'first_seen', data: 'first_seen', visible: false, responsivePriority: 3 },
    { columnName: i18n("map_page.num_uses"), name: 'num_uses', data: 'num_uses',  className: 'text-center text-nowrap', responsivePriority: 4 },
    { columnName: i18n("map_page.info"), name: 'info', data: 'info', responsivePriority: 5 },
  ];

  default_sorting_columns = 6 /* Num Uses */

  if(DatatableVue.is_admin) {
    columns.push({ columnName: i18n("map_page.status"), name: 'service_acceptance', data: 'service_acceptance', className: 'text-center', orderable: false, responsivePriority: 1, render: (data, type, service) => {
        return DatatableVue.create_action_buttons(data, type, service);
      }
    });
  }
  
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

  /* Centrality table configuration */

  tmp_params['view'] = 'centrality'  
  defaultDatatableConfig.data_url = NtopUtils.buildURL(`${http_prefix}/lua/pro/enterprise/get_map.lua`, tmp_params)

  columns = [
    { columnName: i18n("map_page.host"), name: 'host', data: 'host', className: 'text-nowrap', responsivePriority: 1 },
    { columnName: i18n("map_page.total_edges"), name: 'total_edges', data: 'total_edges', className: 'text-nowrap', responsivePriority: 1 },
    { columnName: i18n("map_page.rank"), name: 'rank', data: 'rank', className: 'text-center', responsivePriority: 2 },
    { columnName: i18n("map_page.in_edges"), name: 'in_edges', data: 'in_edges', className: 'text-nowrap', responsivePriority: 2 },
    { columnName: i18n("map_page.out_edges"), name: 'out_edges', data: 'out_edges',  className: 'text-center', responsivePriority: 2 },
  ];
  
  default_sorting_columns = 2 /* Rank */
  table_config.order = [[ default_sorting_columns, 'desc' ]]
  configDevices = ntopng_utility.clone(defaultDatatableConfig);
  configDevices.table_buttons = defaultDatatableConfig.table_buttons;
  configDevices.data_url = `${configDevices.data_url}`;
  configDevices.columns_config = columns;
  configDevices.table_filters = table_filters;
  configDevices.table_config = ntopng_utility.clone(table_config);
  DatatableVue.config_devices_centrality = configDevices;
}
</script>






