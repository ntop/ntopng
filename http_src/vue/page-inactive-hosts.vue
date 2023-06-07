<!--
  (C) 2013-22 - ntop.org
-->

<template>
  <div class="row">
    <div class="col-md-12 col-lg-12">
      <h2 class="ms-3">{{ title }}</h2>
      <div class="card  card-shadow">
        <div class="card-body">
          <div id="inactive_hosts">
            <TableWithConfig ref="table_inactive_hosts" :table_id="table_id" :csrf="csrf"
              :f_map_columns="map_table_def_columns" :get_extra_params_obj="get_extra_params_obj"
              @custom_event="on_table_custom_event">
            </TableWithConfig>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";

const _i18n = (t) => i18n(t);

const table_id = ref('inactive_hosts');
const props = defineProps({
  ifid: Number,
  csrf: String,
  show_historical: Boolean,
});
const title = ref(_i18n('local_hosts_only'))

const get_extra_params_obj = () => {
  let extra_params = ntopng_url_manager.get_url_object();
  return extra_params;
};

function on_table_custom_event(event) {
  let events_managed = {
    "click_button_historical_flows": click_button_historical_flows,
  };
  if (events_managed[event.event_id] == null) {
    return;
  }
  events_managed[event.event_id](event);
}

function click_button_historical_flows(event) {
  const row = event.row;
  window.location.href = `${http_prefix}/lua/pro/db_search.lua?epoch_begin=${row.epoch_begin}&epoch_end=${row.epoch_end}&ip=${row.ip_address.value || row.ip_address};eq&mac=${row.mac_address.value || row.mac_address};eq`;
}

const map_table_def_columns = (columns) => {
  let map_columns = {
    "mac_address": (mac, row) => {
      let result = mac;
      if (mac.url != null &&
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
    "vlan": (vlan, row) => {
      let result = vlan;
      if (vlan.url != null &&
        vlan.name != null &&
        vlan.value != null) {
        result = `<a href='${http_prefix}${vlan.url}' title='${vlan.value}'>${vlan.name}</a>`
      }

      return result;
    },
    "ip_address": (ip_address, row) => {
      let result = ip_address;
      if (ip_address.url != null &&
        ip_address.name != null &&
        ip_address.value != null) {
        result = `<a href='${http_prefix}${ip_address.url}' title='${ip_address.value}'>${ip_address.name}</a>`
      }

      return result;
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

</script>
