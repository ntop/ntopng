<!--
  (C) 2013-22 - ntop.org
-->

<template>
  <div class="row">
    <div class="col-md-12 col-lg-12">
      <div class="card  card-shadow">
        <div class="card-body">
          <TabList ref="inactive_hosts_tab_list" id="inactive_hosts_tab_list" :tab_list="tab_list"
            @click_item="change_show_charts">
          </TabList>
          <!--
          <div class="card card-shadow">
            <div class="card-body p-1">
              <transition name="component-fade" mode="out-in">
                <div key="1" v-if="show_charts == true" class="row mb-4 mt-4" id="host_details_traffic">
                  
                </div>
              </transition>
            </div>
          </div>
          <div class="text-center" style="cursor: pointer;" @click="change_show_charts">
            <i v-if="show_charts == false" class="fa-solid fa-angles-down"></i>
            <i v-else class="fa-solid fa-angles-up"></i>
          </div>
          -->
          <div>
            <div key="1" v-if="show_charts == true" class="row mb-4 mt-4" id="host_details_traffic">
              <template v-if="show_charts == true" v-for="chart_option in chart_options">
                <div class="col-4">
                  <h3 class="widget-name">{{ chart_option.title }}</h3>
                  <Chart :ref="chart_option.ref" :id="chart_option.id" :chart_type="chart_option.type"
                    :base_url_request="chart_option.url" :register_on_status_change="true">
                  </Chart>
                </div>
              </template>
            </div>

            <TableWithConfig v-else ref="table_inactive_hosts" :table_id="table_id" :csrf="csrf"
              :f_map_columns="map_table_def_columns" :get_extra_params_obj="get_extra_params_obj"
              @custom_event="on_table_custom_event">
              <template v-slot:custom_header>
                <Dropdown v-for="(t, t_index) in filter_table_array"
                  :f_on_open="get_open_filter_table_dropdown(t, t_index)"
                  :ref="el => { filter_table_dropdown_array[t_index] = el }" :hidden="t.hidden"> <!-- Dropdown columns -->
                  <template v-slot:title>
                    <Spinner :show="t.show_spinner" size="1rem" class="me-1"></Spinner>
                    <a class="ntopng-truncate" :title="t.title">{{ t.label }}</a>
                  </template>
                  <template v-slot:menu>
                    <a v-for="opt in t.options" style="cursor:pointer;" @click="add_table_filter(opt, $event)"
                      class="ntopng-truncate tag-filter" :title="opt.value">{{ opt.label }}</a>
                  </template>
                </Dropdown> <!-- Dropdown filters -->
              </template>
            </TableWithConfig>
          </div>
          <div class="card-footer mt-3">
            <button type="button" ref="delete_all" @click="delete_all_entries" class="btn btn-danger me-1"><i
                class='fas fa-trash'></i> {{ _i18n("delete_all_entries") }}</button>
            <button type="button" ref="delete_older" @click="delete_entries_since" class="btn btn-danger me-1"><i
                class='fas fa-trash'></i> {{ _i18n("delete_older") }}</button>
            <button type="button" ref="download" @click="download" class="btn btn-primary me-1"><i
                class='fas fa-download'></i></button>
          </div>
        </div>
      </div>
    </div>
  </div>
  <ModalDeleteInactiveHost ref="modal_delete" :context="context" @delete_host="refresh_table"></ModalDeleteInactiveHost>
  <ModalDeleteInactiveHostEpoch ref="modal_delete_older" :context="context" @delete_host="refresh_table">
  </ModalDeleteInactiveHostEpoch>
  <ModalDownloadInactiveHost ref="modal_download" :context="context"></ModalDownloadInactiveHost>
</template>

<script setup>
import { ref, nextTick, onMounted } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as Dropdown } from "./dropdown.vue";
import { default as Spinner } from "./spinner.vue";
import { default as Chart } from "./chart.vue";
import { default as TabList } from "./tab-list.vue";
import { default as ModalDeleteInactiveHost } from "./modal-delete-inactive-host.vue";
import { default as ModalDeleteInactiveHostEpoch } from "./modal-delete-inactive-host-epoch.vue";
import { default as ModalDownloadInactiveHost } from "./modal-download-inactive-host.vue";

const _i18n = (t) => i18n(t);

const table_id = ref('inactive_hosts');
const title = ref(_i18n('local_hosts_only'));
const filter_table_array = ref([]);
const filter_table_dropdown_array = ref([]);
const table_inactive_hosts = ref();
const modal_download = ref();
const modal_delete = ref();
const modal_delete_older = ref();
const chart_1 = ref();
const chart_2 = ref();
const chart_3 = ref();
const show_charts = ref(false);
const inactive_hosts_tab_list = ref();
const applications_tab = ref();
const change_applications_tab_event = "change_applications_tab_event";
const props = defineProps({
  ifid: Number,
  csrf: String,
  show_historical: Boolean,
});
const context = ref({
  csrf: props.csrf,
  ifid: props.ifid
})
const chart_options = [
  {
    ref: chart_1,
    title: i18n('active_inactive'),
    type: ntopChartApex.typeChart.DONUT,
    url: `${http_prefix}/lua/rest/v2/get/host/inactive/active_inactive.lua`,
    id: `active_inactive_distro`,
  },
  {
    ref: chart_2,
    title: i18n('inactivity_period'),
    type: ntopChartApex.typeChart.DONUT,
    url: `${http_prefix}/lua/rest/v2/get/host/inactive/inactivity_period.lua`,
    id: `inactivity_period`,
  },
  {
    ref: chart_3,
    title: i18n('manufacturer'),
    type: ntopChartApex.typeChart.DONUT,
    url: `${http_prefix}/lua/rest/v2/get/host/inactive/inactive_manufacturer.lua`,
    id: `inactive_manufacturer`,
  },
]

const tab_list = ref([
  {
    title: i18n('table_view'),
    active: (show_charts.value == false),
    id: "table"
  },
  {
    title: i18n('chart_view'),
    active: (show_charts.value == true),
    id: "chart"
  },
])

/* ************************************** */

onMounted(async () => {
  ntopng_events_manager.on_custom_event("change_applications_tab_event", change_applications_tab_event, (tab) => {
    ntopng_url_manager.set_key_to_url('view', tab.id);
  });
  load_table_filters_overview();
});

/* ************************************** */

const get_open_filter_table_dropdown = (filter, filter_index) => {
  return (_) => {
    load_table_filters(filter, filter_index);
  };
};

/* ************************************** */

async function load_table_filters_overview(action) {
  filter_table_array.value = await load_table_filters_array("overview");
  set_filter_array_label();
}

/* ************************************** */

function set_filter_array_label() {
  filter_table_array.value.forEach((el, index) => {
    if (el.basic_label == null) {
      el.basic_label = el.label;
    }

    const url_entry = ntopng_url_manager.get_url_entry(el.id)
    if (url_entry != null) {
      el.options.forEach((option) => {
        if (option.value.toString() === url_entry) {
          el.label = `${el.basic_label}: ${option.label || option.value}`
        }
      })
    } else {
      el.label = `${el.basic_label}: ${el.options[0].label || el.options[0].value}`
    }
  })
}

/* ************************************** */

async function load_table_filters(filter, filter_index) {
  await nextTick();
  if (filter.data_loaded == false) {
    let new_filter_array = await load_table_filters_array(filter.id, filter);
    filter.options = new_filter_array.find((t) => t.id == filter.id).options;
    await nextTick();
    let dropdown = filter_table_dropdown_array.value[filter_index];
    dropdown.load_menu();
  }
}

/* ************************************** */

async function load_table_filters_array(action, filter) {
  const url = `${http_prefix}/lua/rest/v2/get/host/inactive_filters.lua?action=${action}`;
  let res = await ntopng_utility.http_request(url);
  return res.map((t) => {
    return {
      id: t.action || t.name,
      label: t.label,
      title: t.tooltip,
      data_loaded: action != 'overview',
      options: t.value,
      hidden: (t.value.length == 1)
    };
  });
}

/* ************************************** */

function add_table_filter(opt, event) {
  event.stopPropagation();
  ntopng_url_manager.set_key_to_url(opt.key, `${opt.value}`);
  set_filter_array_label();
  table_inactive_hosts.value.refresh_table();
  if (show_charts.value == true) {
    chart_options.forEach((el) => {
      el.ref.value[0].update_chart()
    })
  }
}

/* ************************************** */

function refresh_table() {
  table_inactive_hosts.value.refresh_table();
}

/* ************************************** */

function change_show_charts(item) {
  show_charts.value = !show_charts.value;
  tab_list.value.forEach((i) => {
    i.active = false;
    if(i.id == "table" && show_charts.value == false)
      i.active = true;
    else if(i.id == "chart" && show_charts.value == true)
      i.active = true;
  });
  ntopng_events_manager.emit_custom_event(change_applications_tab_event, item);
}

/* ************************************** */

const get_extra_params_obj = () => {
  let extra_params = ntopng_url_manager.get_url_object();
  return extra_params;
};

/* ************************************** */

function on_table_custom_event(event) {
  let events_managed = {
    "click_button_historical_flows": click_button_historical_flows,
    "click_button_delete": click_button_delete,
  };
  if (events_managed[event.event_id] == null) {
    return;
  }
  events_managed[event.event_id](event);
}

/* ************************************** */

function click_button_delete(event) {
  const row = event.row.serial_key;
  modal_delete.value.show(row, i18n('delete_inactive_host', { host: event.row.host.ip_address.value }));
}

/* ************************************** */

function delete_all_entries() {
  modal_delete.value.show('all', i18n('delete_all_inactive_hosts'));
}

/* ************************************** */

function delete_entries_since() {
  modal_delete_older.value.show();
}

/* ************************************** */

function download() {
  modal_download.value.show();
}

/* ************************************** */

function click_button_historical_flows(event) {
  const row = event.row;
  let vlan = ''
  if(row.vlan != 0)
    vlan = `@${row.vlan}`
  window.location.href = `${http_prefix}/lua/pro/db_search.lua?epoch_begin=${row.epoch_begin - 100}&epoch_end=${row.epoch_end + 100}&ip=${row.ip_address.value || row.ip_address}${vlan};eq&mac=${row.mac_address.value || row.mac_address};eq`;
}

/* ************************************** */

const map_table_def_columns = (columns) => {
  let map_columns = {
    "mac_address": (mac, row) => {
      let result = mac;
      if (mac != null &&
        mac.url != null &&
        mac.name != null &&
        mac.value != null) {
        result = `<a href='${http_prefix}${mac.url}' title='${mac.value}'>${mac.name}</a>`
      }

      return result;
    },
    "network": (network, row) => {
      let result = network;
      if (network.url != null &&
        network.name != null &&
        network.value != null) {
        result = `<a href='${http_prefix}${network.url}' title='${network.value}'>${network.name}</a>`
      }

      return result;
    },
    "host": (host, row) => {
      let result = '';
      const ip_address = host.ip_address;
      result = `<a href='${http_prefix}${ip_address.url}' title='${ip_address.value}'>${ip_address.name}</a>`

      if (host.vlan != null && host.vlan.name != "") {
        const vlan = host.vlan;
        if (vlan.url != null) {
          result = `${result}@<a href='${http_prefix}${vlan.url || '#'}' title='${vlan.value}'>${vlan.name}</a>`
        } else {
          result = `${result}@${vlan.name}`
        }
      }
      return `${result} ${host.device_type}`;
    },
  };

  columns.forEach((c) => {
    c.render_func = map_columns[c.data_field];
    if (c.id == "actions") {
      const visible_dict = {
        historical_data: props.show_historical,
      };
      c.button_def_array.forEach((b) => {
        if (!visible_dict[b.id]) {
          b.class.push("disabled");
        }
      });
    }
  });

  return columns;
};

/* ************************************** */

</script>
