<!--
  (C) 2013-22 - ntop.org
-->

<template>
<div class="row">
  <div class="col-md-12 col-lg-12">
    <div class="card">
      <div class="overlay justify-content-center align-items-center position-absolute h-100 w-100">
        <div class="text-center">
          <div class="spinner-border text-primary mt-5" role="status">
            <span class="sr-only position-absolute">Loading...</span>
          </div>
        </div>
      </div>
      <div class="card-body">
      	<div id="host_details_applications">
          <tab-list ref="host_details_applications_tab_list"
            id="host_details_applications_tab_list"
            :tab_list="tab_list"
            @click_item="click_item">
          </tab-list>

          <div class="row" id="host_details_applications">
            <template v-for="chart_option in chart_options">
              <div class="col-6">
                <chart v-if="chart_option.tab == applications_tab"
                  :id="chart_option.id"
                  :chart_type="chart_option.type"
                  :base_url_request="chart_option.url"
                  :register_on_status_change="false">
                </chart>
              </div>
            </template>
          </div>
          
          <datatable v-if="applications_tab == 'applications'" ref="table_host_applications"
            :table_buttons="config_devices_applications.table_buttons"
            :columns_config="config_devices_applications.columns_config"
            :data_url="config_devices_applications.data_url"
            :enable_search="config_devices_applications.enable_search"
            :table_config="config_devices_applications.table_config">
          </datatable>
          <datatable v-if="applications_tab == 'categories'" ref="table_host_categories"
            :table_buttons="config_devices_categories.table_buttons"
            :columns_config="config_devices_categories.columns_config"
            :data_url="config_devices_categories.data_url"
            :enable_search="config_devices_categories.enable_search"
            :table_config="config_devices_categories.table_config">
          </datatable>
        </div>
      </div>
      <div class="card-footer">
      </div>
    </div>
  </div>
</div>
</template>

<script>
import { default as Chart } from "./chart.vue";
import { default as Datatable } from "./datatable.vue";
import { default as TabList } from "./tab-list.vue";
import { default as ModalDeleteConfirm } from "./modal-delete-confirm.vue";
import { ntopng_events_manager, ntopng_url_manager } from '../services/context/ntopng_globals_services';
const change_applications_tab_event = "change_applications_tab_event";

export default {
  components: {	  
    'chart': Chart,
    'datatable': Datatable,
    'modal-delete-confirm': ModalDeleteConfirm,
    'tab-list': TabList,
  },
  props: {
    page_csrf: String,
    url_params: Object,
    view: String,
    is_ch_enabled: Boolean,
  },
  /**
   * First method called when the component is created.
   */
  created() {
    this.applications_tab = ntopng_url_manager.get_url_entry("view") || this.$props.view
    this.tab_list.forEach((i) => {
      this.applications_tab == i.id ? i.active = true : i.active = false
    });
    start_datatable(this);
  },
  mounted() {
    ntopng_events_manager.on_custom_event("change_applications_tab_event", change_applications_tab_event, (tab) => {
	    let table = this.get_active_table();
      ntopng_url_manager.set_key_to_url('view', tab.id);
      table.destroy_table();
      this.applications_tab = tab.id;
    });
  },    
  data() {
    return {
      i18n: (t) => i18n(t),
      applications_tab: null,
      config_devices_applications: null,
      config_devices_categories: null,
      chart_options: [
        {
          type: ntopChartApex.typeChart.PIE,
          url: `${http_prefix}/lua/rest/v2/get/host/l7/proto_data.lua`,
          tab: `applications`,
          id: `top_applications`,
        },
        {
          type: ntopChartApex.typeChart.PIE,
          url: `${http_prefix}/lua/rest/v2/get/host/l7/breed_data.lua`,
          tab: `applications`,
          id: `top_breed`,
        },
        {
          type: ntopChartApex.typeChart.PIE,
          url: `${http_prefix}/lua/rest/v2/get/host/l7/cat_data.lua`,
          tab: `categories`,
          id: `top_categories`,
        },
        {
          type: ntopChartApex.typeChart.PIE,
          url: `${http_prefix}/lua/rest/v2/get/host/l7/breed_data.lua`,
          tab: `categories`,
          id: `top_breed`,
        },
      ],
      tab_list: [
        { 
          title: i18n('host_details.applications_tab'),
          active: (this.$props.view == 'applications'),
          id: 'applications'
        },
        { 
          title: i18n('host_details.categories_tab'),
          active: (this.$props.view == 'categories'),
          id: 'categories'
        },
      ]
    };
  },
  methods: {
    add_action_column: function(columns, name, value) {
      const host = `${this.$props.url_params.host}`
      const vlan = `${this.$props.url_params.vlan}`
      const ifid = `${this.$props.url_params.ifid}`
      let handlerId = "page-stats-action-jump-historical";
      columns.push({ columnName: i18n("actions"), width: '5%', name: 'actions', className: 'text-center', orderable: false, responsivePriority: 0, handlerId, render: (data, type, service) => {
        const jump_to_historical = {
          handlerId,
          onClick: () => {
            let url = `${http_prefix}/lua/pro/db_search.lua?ifid=${ifid}&${name}=${service[value].id};eq&ip=${host};eq`
            if(vlan != 0)
              url = `${url}&vlan_id=${vlan};eq`
            window.open(url)
          }
        };
        return DataTableUtils.createActionButtons([{ class: 'dropdown-item', href: '#', title: i18n('db_explorer.historical_data'), handler: jump_to_historical }])
      }})
    },
    destroy: function() {
      let table = this.get_active_table();
      table.destroy_table();
    },
    /* Method used to switch active table tab */
    click_item: function(item) {
      this.tab_list.forEach((i) => i.active = false);
      item.active = true;
      ntopng_events_manager.emit_custom_event(change_applications_tab_event, item);
    }, 
    reload_table: function() {
      let table = this.get_active_table();
      NtopUtils.showOverlays();
      table.reload();
      NtopUtils.hideOverlays();
    },
    get_active_table: function() {
      return this.$refs[`table_host_${this.applications_tab}`];
    },
    get_f_get_custom_chart_options() {
      console.log("get_f_");
      return async (url) => {
        return charts_options_items.value[chart_index].chart_options;
      }
    }
  },
}  

function start_datatable(PageVue) {
  const datatableButton = [];

  /* Manage the buttons close to the search box */
  datatableButton.push({
    text: '<i class="fas fa-sync"></i>',
    className: 'btn-link',
    action: function (e, dt, node, config) {
      PageVue.reload_table();
    }
  });
  
  let tmp_params = url_params;
  tmp_params['view'] = 'applications'
  
  let defaultDatatableConfig = {
    table_buttons: datatableButton,
    data_url: NtopUtils.buildURL(`${http_prefix}/lua/rest/v2/get/host/l7/data.lua`, tmp_params),
    enable_search: true,
    table_config: { 
      serverSide: false, 
      order: [[ 6 /* percentage column */, 'desc' ]],
      columnDefs: [
        { type: "time-uni", targets: 1 },
        { type: "file-size", targets: 2 },
        { type: "file-size", targets: 3 },
        { type: "file-size", targets: 5 },
      ]
    }
  };
  
  /* Applications table configuration */  

  let columns = [
    { columnName: i18n("host_details.application"), name: 'application', data: 'application', className: 'text-nowrap', responsivePriority: 1, render: (data) => {
        return `<a href="${http_prefix}/lua/host_details.lua?host=${PageVue.$props.url_params.host}@${PageVue.$props.url_params.vlan}&ts_schema=host:ndpi&page=historical&protocol=${data.label}" target="_blank">${data.label}</a>`
      } 
    },
    { columnName: i18n("host_details.duration"), name: 'duration', data: 'duration', className: 'text-nowrap', responsivePriority: 1, render: (data) => {
        return NtopUtils.secondsToTime(data);
      }  
    },
    { columnName: i18n("host_details.sent"), name: 'sent', data: 'bytes_sent', className: 'text-nowrap', responsivePriority: 2, render: (data) => {
        return NtopUtils.bytesToSize(data);
      }  
    },
    { columnName: i18n("host_details.rcvd"), name: 'rcvd', data: 'bytes_rcvd',  className: 'text-center text-nowrap', responsivePriority: 2, render: (data) => {
        return NtopUtils.bytesToSize(data);
      }  
    },
    { columnName: i18n("host_details.breakdown"), name: 'breakdown', data: 'breakdown', orderable: false, className: 'text-center text-nowrap', responsivePriority: 2, render: (data, type, row) => {
        const percentage_sent = (row.bytes_sent * 100) / row.tot_bytes;
        const percentage_rcvd = (row.bytes_rcvd * 100) / row.tot_bytes;
        return NtopUtils.createBreakdown(percentage_sent, percentage_rcvd, i18n('host_details.sent'), i18n('host_details.rcvd'));
      }  
    },
    { columnName: i18n("host_details.tot_bytes"), name: 'tot_bytes', data: 'tot_bytes', className: 'text-center text-nowrap', responsivePriority: 2, render: (data) => {
        return NtopUtils.bytesToSize(data);
      }   
    },
    { columnName: i18n("host_details.tot_percentage"), name: 'percentage', data: 'percentage',  className: 'text-center text-nowrap', responsivePriority: 2, render: (data) => {
        const percentage = data.toFixed(1);
        return NtopUtils.createProgressBar(percentage);
      }  
    },
  ];

  if(is_ch_enabled)
    PageVue.add_action_column(columns, 'l7proto', 'application');
  
  let applicationsConfig = ntopng_utility.clone(defaultDatatableConfig);
  applicationsConfig.columns_config = columns;
  PageVue.config_devices_applications = applicationsConfig;


  /* Categories table configuration */

  tmp_params['view'] = 'categories'  
  defaultDatatableConfig.data_url = NtopUtils.buildURL(`${http_prefix}/lua/rest/v2/get/host/l7/data.lua`, tmp_params)


  columns = [
    { columnName: i18n("host_details.category"), name: 'category', data: 'category', className: 'text-nowrap', responsivePriority: 1, render: (data) => {
        return `<a href="${http_prefix}/lua/host_details.lua?host=${PageVue.$props.url_params.host}@${PageVue.$props.url_params.vlan}&ts_schema=host:ndpi_categories&page=historical&category=${data.label}" target="_blank">${data.label}</a>`
      } 
    },
    { columnName: i18n("host_details.applications"), name: 'applications', data: 'applications', orderable: false, className: 'text-nowrap', responsivePriority: 1, render: (data) => {
        return `${data.label || ''} <a href="${http_prefix}/${data.href}${data.category_id}">${data.more_protos || ''}</a>`
      } 
    },
    { columnName: i18n("host_details.duration"), name: 'duration', data: 'duration', className: 'text-nowrap', responsivePriority: 1, render: (data) => {
        return NtopUtils.secondsToTime(data);
      }  
    },
    { columnName: i18n("host_details.tot_bytes"), name: 'tot_bytes', data: 'tot_bytes', className: 'text-center text-nowrap', responsivePriority: 2, render: (data) => {
        return NtopUtils.bytesToSize(data);
      }  
    },
    { columnName: i18n("host_details.tot_percentage"), name: 'percentage', data: 'percentage', width: '20%', className: 'text-center text-nowrap', responsivePriority: 2, render: (data) => {
        const percentage = data.toFixed(1);
        return NtopUtils.createProgressBar(percentage);
      }  
    },
  ];

  if(is_ch_enabled)
    PageVue.add_action_column(columns, 'l7cat', 'category');
  
  let categoriesConfig = ntopng_utility.clone(defaultDatatableConfig);
  categoriesConfig.columns_config = columns;
  categoriesConfig.table_config.order = [[ 4 /* percentage column */, 'desc' ]]
  categoriesConfig.table_config.columnDefs = [
    { type: "time-uni", targets: 2 },
    { type: "file-size", targets: 3 },
  ]
  
  PageVue.config_devices_categories = categoriesConfig;
}
</script>






