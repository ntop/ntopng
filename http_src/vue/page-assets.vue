<!-- (C) 2024 - ntop.org     -->
<template>
  <div class="m-2 mb-3">
    <template v-if="(!props.context.is_assets_collection_enabled)">
      <div class="alert alert-warning" role="alert" id='error-alert' v-html:="error_message">
      </div>
    </template>
    <div :class="[(!props.context.is_assets_collection_enabled) ? 'ntopng-gray-out' : '']">
      <TableWithConfig ref="table_assets" :table_id="table_id" :csrf="context.csrf" :f_map_columns="map_table_def_columns"
        :get_extra_params_obj="get_extra_params_obj" @custom_event="on_table_custom_event">
        <template v-slot:custom_header>
          <div class="dropdown me-3 d-inline-block" v-for="item in filter_table_array">
            <span class="no-wrap d-flex align-items-center my-auto me-2 filters-label"><b>{{ item["basic_label"]
                }}</b></span>
            <!-- :key="host_filters_key" -->
            <SelectSearch v-model:selected_option="item['current_option']" theme="bootstrap-5" dropdown_size="small"
              :options="item['options']" @select_option="add_table_filter">
            </SelectSearch>
          </div>
        </template> <!-- Dropdown filters -->
      </TableWithConfig>
      <div class="card-footer mt-3">
        <button v-if="props.context.is_admin" type="button" @click="delete_assets()" class="btn btn-danger ms-1">
          <i class="fas fa fa-trash"></i>
          {{ _i18n("delete_all_entries") }}
        </button>
        <button v-if="props.context.is_admin" type="button" @click="delete_assets_epoch" class="btn btn-danger ms-1">
          <i class="fas fa fa-trash"></i>
          {{ _i18n("asset_details.delete_asset_older_title") }}
        </button>
      </div>
    </div>
  </div>
  <ModalDeleteAssets ref="modal_delete_assets" :context="context" @delete="refresh_table">
  </ModalDeleteAssets>
  <ModalDeleteAssetsEpoch ref="modal_delete_assets_epoch" :context="context" @delete="refresh_table">
  </ModalDeleteAssetsEpoch>
</template>

<script setup>
import { ref, nextTick, onMounted } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as dataUtils } from "../utilities/data-utils.js";
import { default as osUtils } from "../utilities/map/os-utils.js";
import { default as ModalDeleteAssets } from "./modal-delete-assets.vue";
import { default as ModalDeleteAssetsEpoch } from "./modal-delete-assets-epoch.vue";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";

const _i18n = (t) => i18n(t);

const host_filters_key = ref(0);
const table_id = ref('assets');
const filter_table_array = ref([]);
const table_assets = ref();
const modal_delete_assets = ref();
const modal_delete_assets_epoch = ref();
const error_message = i18n('asset_details.preference_disabled')
const child_safe_icon = "<font color='#5cb85c'><i class='fas fa-lg fa-child' aria-hidden='true' title='" + i18n("host_pools.children_safe") + "'></i></font>"
const system_host_icon = "<i class='fas fa-flag' title='" + i18n("system_host") + "'></i>"
const hidden_from_top_icon = "<i class='fas fa-eye-slash' title='" + i18n("hidden_from_top_talkers") + "'></i>"
const dhcp_host_icon = '<i class="fa-solid fa-bolt" title="DHCP Host"></i>'
const blacklisted_icon = "<i class='fas fa-ban fa-sm' title='" + i18n("hosts_stats.blacklisted") + "'></i>"
const crawler_bot_scanner_host_icon = "<i class='fas fa-spider fa-sm' title='" + i18n("hosts_stats.crawler_bot_scanner") + "'></i>"
const multicast_icon = "<abbr title='" + i18n("multicast") + "'><span class='badge bg-primary'>" + i18n("short_multicast") + "</span></abbr>"
const localhost_icon = "<abbr data-bs-toggle='tooltip' data-bs-placement='top' data-bs-original-title='" + i18n("details.label_local_host") + "'><span class='badge bg-success'>" + i18n("details.label_short_local_host") + "</span></abbr>"
const remotehost_icon = "<abbr title='" + i18n("details.label_remote") + "'><span class='badge bg-secondary'>" + i18n("details.label_short_remote") + "</span></abbr>"
const blackhole_icon = "<abbr title='" + i18n("details.label_blackhole") + "'><span class='badge bg-info'>" + i18n("details.label_short_blackhole") + "</span></abbr>"
const blocking_quota_icon = "<i class='fas fa-hourglass' title='" + i18n("hosts_stats.blocking_traffic_policy_popup_msg") + "'></i>"

/* ************************************** */

const props = defineProps({
  context: Object,
});

/* ************************************** */

const map_table_def_columns = (columns) => {
  let map_columns = {
    "ip_address": (value, row) => {
      const host = row.host
      let ip_address = host.ip
      let icons = ''

      if (!dataUtils.isEmptyOrNull(host.vlan.name)) {
        ip_address = `${ip_address}@${host.vlan.name}`
      }
      if (!dataUtils.isEmptyOrNull(host.system_host)) {
        icons = `${icons} ${system_host_icon}`
      }
      if (!dataUtils.isEmptyOrNull(host.os)) {
        const os_icon = osUtils.getOS(host.os);
        icons = `${icons} ${os_icon.icon}`
      }
      if (!dataUtils.isEmptyOrNull(host.device_type)) {
        icons = `${icons} ${osUtils.getAssetIcon(host.device_type) || ''}`
      }
      if (!dataUtils.isEmptyOrNull(host.hidden_from_top)) {
        icons = `${icons} ${hidden_from_top_icon}`
      }
      if (!dataUtils.isEmptyOrNull(host.child_safe)) {
        icons = `${icons} ${child_safe_icon}`
      }
      if (!dataUtils.isEmptyOrNull(host.dhcp_host)) {
        icons = `${icons} ${dhcp_host_icon}`
      }
      if (!dataUtils.isEmptyOrNull(host.blocking_traffic_policy)) {
        icons = `${icons} ${blocking_quota_icon}`
      }
      if (!dataUtils.isEmptyOrNull(host.country)) {
        icons = `${icons} <a href='${http_prefix}/lua/hosts_stats.lua?country=${host.country}'><img src='${http_prefix}/dist/images/blank.gif' class='flag flag-${host.country.toLowerCase()}'></a>`
      }
      if (!dataUtils.isEmptyOrNull(host.is_blacklisted)) {
        icons = `${icons} ${blacklisted_icon}`
      }
      if (!dataUtils.isEmptyOrNull(host.crawler_bot_scanner_host)) {
        icons = `${icons} ${crawler_bot_scanner_host_icon}`
      }
      if (!dataUtils.isEmptyOrNull(host.is_multicast)) {
        icons = `${icons} ${multicast_icon}`
      }
      if (!dataUtils.isEmptyOrNull(host.localhost)) {
        icons = `${icons} ${localhost_icon}`
      }
      if (!dataUtils.isEmptyOrNull(host.remotehost)) {
        icons = `${icons} ${remotehost_icon}`
      }
      if (!dataUtils.isEmptyOrNull(host.is_blackhole)) {
        icons = `${icons} ${blackhole_icon}`
      }
      const host_url = create_button_host_details(row);
      return `<a href="${host_url}">${ip_address}</a> ${icons}`
    },
    "host_name": (value, row) => {
      let name = value.name
      if (!dataUtils.isEmptyOrNull(value.alt_name)) {
        name = value.alt_name
        if (value.alt_name != value.name && !dataUtils.isEmptyOrNull(value.name)) {
          name = `${name} [${value.name}]`
        }
      }

      return name
    },
    "mac": (value, row) => {
      let result = value.value
      if (!dataUtils.isEmptyOrNull(value.name)) {
        result = `<span data-bs-toggle="tooltip" data-bs-placement="top" data-bs-original-title='${value.value}'>${value.name}</span>`
      }
      if (value.is_in_memory) {
        result = `<a href='${http_prefix}/lua/mac_details.lua?host=${value.value}'>${result}</a>`
      }

      return result;
    },
    "manufacturer": (value, row) => {
      return value;
    },
    "status": (value, row) => {
      let badge = `<span class="badge bg-secondary">${i18n('inactive')}</span>`
      if (row.last_seen.timestamp == 0) {
        badge = `<span class="badge bg-success">${i18n('active')}</span>`
      }
      return badge
    },
    "first_seen": (value, row) => {
      return value.date
    },
    "last_seen": (value, row) => {
      return value.date
    }
  };

  columns.forEach((c) => {
    c.render_func = map_columns[c.data_field];
    if (c.id == "actions") {
      const visible_dict = {
        historical_flows: props.context.historical_available,
        details: true,
        delete: props.context.is_admin
      };
      c.button_def_array.forEach((b) => {
        if (!visible_dict[b.id]) {
          b.class.push("link-disabled");
        }
      });
    }
  });

  return columns;
};

/* ************************************** */

function delete_assets_epoch() {
  modal_delete_assets_epoch.value.show();
}

/* ************************************** */

function delete_assets(row) {
  modal_delete_assets.value.show(row);
}

/* ************************************** */

function set_filter_array_label() {
  filter_table_array.value.forEach((el, index) => {
    /* Setting the basic label */
    if (el.basic_label == null) {
      el.basic_label = el.label;
    }

    /* Getting the currently selected filter */
    const url_entry = ntopng_url_manager.get_url_entry(el.id)
    el.options.forEach((option) => {
      if (option.value.toString() === url_entry) {
        el.current_option = option;
      }
    })
  })
}

/* ************************************** */

function change_filter_labels() {
  set_filter_array_label()
}

/* ************************************** */

async function add_table_filter(opt) {
  ntopng_url_manager.set_key_to_url(opt.key, `${opt.value}`);
  set_filter_array_label();
  table_assets.value.refresh_table();
  //  filter_table_array.value = await load_table_filters_array()
}

/* ************************************** */

async function load_table_filters_array() {
  let extra_params = get_extra_params_obj();
  let url_params = ntopng_url_manager.obj_to_url_params(extra_params);
  const url = `${http_prefix}/lua/rest/v2/get/host/assets_filters.lua?${url_params}`;
  let res = await ntopng_utility.http_request(url);
  host_filters_key.value = host_filters_key.value + 1

  return res.map((t) => {
    const key_in_url = ntopng_url_manager.get_url_entry(t.name);
    if (dataUtils.isEmptyOrNull(key_in_url)) {
      ntopng_url_manager.set_key_to_url(t.name, ``);
    }
    return {
      id: t.name,
      label: t.label,
      title: t.tooltip,
      options: t.value,
      hidden: (t.value.length == 1)
    };
  });
}

/* ************************************** */

const get_extra_params_obj = () => {
  let extra_params = ntopng_url_manager.get_url_object();
  return extra_params;
};

/* ************************************** */

function create_historical_flows_url_link(row) {
  return `${http_prefix}/lua/pro/db_search.lua?ip=${row.host.ip};eq&vlan_id=${row.host.vlan.id};eq&epoch_begin=${row.first_seen.timestamp}&epoch_end=${row.last_seen.timestamp}`
}

/* ************************************** */

function create_button_host_details(row) {
  let url = `/lua/asset_details.lua?ifid=${props.context.ifid}&serial_key=${row.key}`
  if (row.last_seen.timestamp == 0) {
    url = `/lua/host_details?ifid=${props.context.ifid}&host=${row.host.ip}`
    if (row.host.vlan && row.host.vlan.id) {
      url = `${url}&vlan=${row.host.vlan.id}`
    }
  }
  return `${http_prefix}${url}`
}

/* ************************************** */

function click_button_delete(event) {
  const row = event.row;
  delete_assets(row);
}

/* ************************************** */

function click_button_historical_flows(event) {
  const row = event.row;
  window.open(create_historical_flows_url_link(row));
}

/* ************************************** */

function click_button_host_details(event) {
  const row = event.row;
  window.open(create_button_host_details(row));
}

/* ************************************** */

function on_table_custom_event(event) {
  let events_managed = {
    "click_button_historical_flows": click_button_historical_flows,
    "click_button_host_details": click_button_host_details,
    "click_button_delete": click_button_delete,
  };
  if (events_managed[event.event_id] == null) {
    return;
  }
  events_managed[event.event_id](event);
}

/* ************************************** */

function refresh_table() {
  table_assets.value.refresh_table();
}

/* ************************************** */

onMounted(async () => {
  filter_table_array.value = await load_table_filters_array();
  set_filter_array_label()
});

/* ************************************** */

</script>
