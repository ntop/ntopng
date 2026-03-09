<!--
  (C) 2013-26 - ntop.org
-->

<template>
  <div class="row">
    <div class="col-md-12 col-lg-12">
      <div class="card">
        <div class="card-body">
          <div id="host_details_applications">
            <TabList ref="host_details_applications_tab_list" id="host_details_applications_tab_list"
              :tab_list="tab_list" @click_item="click_item">
            </TabList>

            <div class="row mb-4 mt-4">
              <MultiPieChart :context="pie_charts_context" />
            </div>

            <Datatable v-if="applications_tab == 'applications'" ref="table_host_applications"
              :table_buttons="config_devices_applications.table_buttons"
              :columns_config="config_devices_applications.columns_config"
              :data_url="config_devices_applications.data_url"
              :enable_search="config_devices_applications.enable_search"
              :table_config="config_devices_applications.table_config">
            </Datatable>
            <Datatable v-if="applications_tab == 'categories'" ref="table_host_categories"
              :table_buttons="config_devices_categories.table_buttons"
              :columns_config="config_devices_categories.columns_config" :data_url="config_devices_categories.data_url"
              :enable_search="config_devices_categories.enable_search"
              :table_config="config_devices_categories.table_config">
            </Datatable>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted, onBeforeMount } from "vue";
import MultiPieChart from "./charts/multi-pie-chart.vue";
import { default as Datatable } from "./datatable.vue";
import { default as TabList } from "./tab-list.vue";
import { ntopng_events_manager, ntopng_url_manager } from '../services/context/ntopng_globals_services';

const change_applications_tab_event = "change_applications_tab_event";

const props = defineProps({
  context: Object,
});

const applications_tab = ref(ntopng_url_manager.get_url_entry("view") || props.context.view);
const config_devices_applications = ref({});
const config_devices_categories = ref({});

const url_params = {
  host: props.context.url_params.host,
  vlan: props.context.url_params.vlan,
  ifid: props.context.url_params.ifid,
};

const tab_list = ref([
  {
    title: i18n('host_details.applications_tab'),
    active: props.context.view === 'applications',
    id: 'applications',
  },
  {
    title: i18n('host_details.categories_tab'),
    active: props.context.view === 'categories',
    id: 'categories',
  },
]);

/* Pie chart config */

const applications_charts = [
  {
    name: 'top_applications',
    title: i18n('graphs.top_10_ndpi_protocols'),
    update_url: `${http_prefix}/lua/rest/v2/get/host/l7/proto_data.lua`,
    url_params,
    unit: 'number'
  },
  {
    name: 'top_breed',
    title: i18n('graphs.top_breed'),
    update_url: `${http_prefix}/lua/rest/v2/get/host/l7/breed_data.lua`,
    url_params,
    unit: 'number'
  },
];

const categories_charts = [
  {
    name: 'top_categories',
    title: i18n('graphs.top_10_ndpi_categories'),
    update_url: `${http_prefix}/lua/rest/v2/get/host/l7/cat_data.lua`,
    url_params,
    unit: 'number'
  },
  {
    name: 'top_breed_cat',
    title: i18n('graphs.top_breed'),
    update_url: `${http_prefix}/lua/rest/v2/get/host/l7/breed_data.lua`,
    url_params,
    unit: 'number'
  },
];

const pie_charts_context = computed(() => ({
  charts_per_row: 2,
  charts: applications_tab.value === 'applications' ? applications_charts : categories_charts,
}));

/* Data Table */

const table_host_applications = ref(null);
const table_host_categories = ref(null);

const get_active_table = () => {
  return applications_tab.value === 'applications'
    ? table_host_applications.value
    : table_host_categories.value;
};

const reload_table = () => {
  get_active_table()?.reload();
};

const click_item = (item) => {
  tab_list.value.forEach(i => i.active = false);
  item.active = true;
  ntopng_url_manager.set_key_to_url('view', item.id);
  get_active_table()?.destroy_table();
  applications_tab.value = item.id;
  ntopng_events_manager.emit_custom_event(change_applications_tab_event, item);
};

const add_action_column = (columns, name, value) => {
  const { host, vlan, ifid } = url_params;
  const handlerId = "page-stats-action-jump-historical";
  columns.push({
    columnName: i18n("actions"), width: '5%', name: 'actions',
    className: 'text-center', orderable: false, responsivePriority: 0,
    handlerId,
    render: (data, type, service) => {
      const jump_to_historical = {
        handlerId,
        onClick: () => {
          let url = `${http_prefix}/lua/pro/db_search.lua?ifid=${ifid}&${name}=${service[value].id};eq&ip=${host};eq`;
          if (vlan != 0) url += `&vlan_id=${vlan};eq`;
          window.open(url);
        }
      };
      return DataTableUtils.createActionButtons([{
        class: 'dropdown-item', href: '#',
        title: i18n('db_explorer.historical_data'),
        handler: jump_to_historical,
      }]);
    }
  });
};

const start_datatable = () => {
  const datatableButton = [{
    text: '<i class="fas fa-sync"></i>',
    className: 'btn-link',
    action: () => reload_table(),
  }];

  const base_config = {
    table_buttons: datatableButton,
    enable_search: true,
    table_config: {
      serverSide: false,
      order: [[6, 'desc']],
      columnDefs: [
        { type: "time-uni", targets: 1 },
        { type: "file-size", targets: 2 },
        { type: "file-size", targets: 3 },
        { type: "file-size", targets: 5 },
      ]
    }
  };

  /* Applications */
  const app_columns = [
    {
      columnName: i18n("host_details.application"), targets: 0, width: '20', name: 'application', data: 'application', className: 'text-nowrap', responsivePriority: 1,
      render: (data) => {
        if (props.context.is_locale == "1" && props.context.ts_l7_enabled === true)
          return `<a href="${http_prefix}/lua/host_details.lua?host=${url_params.host}@${url_params.vlan}&page=historical&ifid=${url_params.ifid}&protocol=${data.label}&ts_schema=host:ndpi" target="_blank">${data.label}</a>`;
        return `${data.label}`;
      }
    },
    { columnName: i18n("host_details.duration"), targets: 1, width: '10', name: 'duration', data: 'duration', className: 'text-nowrap', responsivePriority: 1, render: (data) => NtopUtils.secondsToTime(data) },
    { columnName: i18n("host_details.sent"), targets: 2, width: '10', name: 'sent', data: 'bytes_sent', className: 'text-nowrap', responsivePriority: 2, render: (data) => NtopUtils.bytesToSize(data) },
    { columnName: i18n("host_details.rcvd"), targets: 3, width: '10', name: 'rcvd', data: 'bytes_rcvd', className: 'text-center text-nowrap', responsivePriority: 2, render: (data) => NtopUtils.bytesToSize(data) },
    {
      columnName: i18n("host_details.breakdown"), targets: 4, width: '10', name: 'breakdown', data: 'breakdown', className: 'text-center text-nowrap', orderable: false, responsivePriority: 2,
      render: (data, type, row) => {
        const pct_sent = (row.bytes_sent * 100) / row.tot_bytes;
        const pct_rcvd = (row.bytes_rcvd * 100) / row.tot_bytes;
        return NtopUtils.createBreakdown(pct_sent, pct_rcvd, i18n('host_details.sent'), i18n('host_details.rcvd'));
      }
    },
    { columnName: i18n("host_details.tot_bytes"), targets: 5, width: '20', name: 'tot_bytes', data: 'tot_bytes', className: 'text-center text-nowrap', responsivePriority: 2, render: (data) => NtopUtils.bytesToSize(data) },
    {
      columnName: i18n("host_details.tot_percentage"), targets: 6, width: '20', name: 'percentage', data: 'percentage', className: 'text-center text-nowrap', responsivePriority: 2,
      render: (data) => NtopUtils.createProgressBar(data.toFixed(1))
    },
  ];

  if (props.context.is_ch_enabled) add_action_column(app_columns, 'l7proto', 'application');

  const applicationsConfig = ntopng_utility.clone(base_config);
  applicationsConfig.columns_config = app_columns;
  applicationsConfig.data_url = NtopUtils.buildURL(`${http_prefix}/lua/rest/v2/get/host/l7/data.lua`, { ...url_params, view: 'applications' });
  config_devices_applications.value = applicationsConfig;

  /* Categories */
  const cat_columns = [
    {
      columnName: i18n("host_details.category"), targets: 0, name: 'category', data: 'category', className: 'text-nowrap', responsivePriority: 1,
      render: (data) => {
        if (props.context.is_locale == "1" && props.context.ts_cat_enabled === true)
          return `<a href="${http_prefix}/lua/host_details.lua?host=${url_params.host}@${url_params.vlan}&ts_schema=host:ndpi_categories&page=historical&category=${data.label}" target="_blank">${data.label}</a>`;
        return `${data.label}`;
      }
    },
    {
      columnName: i18n("host_details.applications"), targets: 0, name: 'applications', data: 'applications', className: 'text-nowrap', orderable: false, responsivePriority: 1,
      render: (data) => {
        if (props.context.is_locale == "1")
          return `${data.label || ''} <a href="${http_prefix}/${data.href}${data.category_id}">${data.more_protos || ''}</a>`;
        return `${data.label || ''}`;
      }
    },
    { columnName: i18n("host_details.duration"), targets: 0, name: 'duration', data: 'duration', className: 'text-nowrap', responsivePriority: 1, render: (data) => NtopUtils.secondsToTime(data) },
    { columnName: i18n("host_details.tot_bytes"), targets: 0, name: 'tot_bytes', data: 'tot_bytes', className: 'text-center text-nowrap', responsivePriority: 2, render: (data) => NtopUtils.bytesToSize(data) },
    {
      columnName: i18n("host_details.tot_percentage"), targets: 0, name: 'percentage', data: 'percentage', className: 'text-center text-nowrap', responsivePriority: 2,
      render: (data) => NtopUtils.createProgressBar(data.toFixed(1))
    },
  ];

  if (props.context.is_ch_enabled) add_action_column(cat_columns, 'l7cat', 'category');

  const categoriesConfig = ntopng_utility.clone(base_config);
  categoriesConfig.columns_config = cat_columns;
  categoriesConfig.data_url = NtopUtils.buildURL(`${http_prefix}/lua/rest/v2/get/host/l7/data.lua`, { ...url_params, view: 'categories' });
  categoriesConfig.table_config = {
    ...ntopng_utility.clone(base_config.table_config),
    order: [[4, 'desc']],
    columnDefs: [
      { type: "time-uni", targets: 2 },
      { type: "file-size", targets: 3 },
    ]
  };
  config_devices_categories.value = categoriesConfig;
};

onBeforeMount(() => {
  start_datatable();
});

onUnmounted(() => {
  get_active_table()?.destroy_table();
});
</script>