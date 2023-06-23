<!--
  (C) 2013-22 - ntop.org
-->

<template>
  <div class="row">
    <div class="col-md-12 col-lg-12">
      <h2 class="ms-3">{{ title }}</h2>
      <div class="card  card-shadow">
        <div class="card-body">
          <div>
            <TableWithConfig ref="table_inactive_hosts" :table_id="table_id" :csrf="csrf"
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
            <button type="button" ref="download" @click="download" class="btn btn-primary me-1"><i
                class='fas fa-download'></i></button>
          </div>
        </div>
      </div>
    </div>
  </div>
  <ModalDeleteInactiveHost ref="modal_delete" :context="context" @delete_host="refresh_table"></ModalDeleteInactiveHost>
  <ModalDownloadInactiveHost ref="modal_download" :context="context"></ModalDownloadInactiveHost>
</template>

<script setup>
import { ref, nextTick, onMounted } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as Dropdown } from "./dropdown.vue";
import { default as Spinner } from "./spinner.vue";
import { default as ModalDeleteInactiveHost } from "./modal-delete-inactive-host.vue";
import { default as ModalDownloadInactiveHost } from "./modal-download-inactive-host.vue";

const _i18n = (t) => i18n(t);

const table_id = ref('inactive_hosts');
const title = ref(_i18n('local_hosts_only'));
const filter_table_array = ref([]);
const filter_table_dropdown_array = ref([]);
const table_inactive_hosts = ref();
const modal_download = ref();
const modal_delete = ref();
const props = defineProps({
  ifid: Number,
  csrf: String,
  show_historical: Boolean,
});
const context = ref({
  csrf: props.csrf,
  ifid: props.ifid
})

/* ************************************** */

onMounted(async () => {
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
}

/* ************************************** */

function refresh_table() {
  table_inactive_hosts.value.refresh_table();
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

function download() {
  modal_download.value.show();
}

/* ************************************** */

function click_button_historical_flows(event) {
  const row = event.row;
  window.location.href = `${http_prefix}/lua/pro/db_search.lua?epoch_begin=${row.epoch_begin - 100}&epoch_end=${row.epoch_end + 100}&ip=${row.ip_address.value || row.ip_address};eq&mac=${row.mac_address.value || row.mac_address};eq`;
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
