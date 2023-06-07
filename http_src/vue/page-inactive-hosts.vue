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
              :f_map_columns="map_table_def_columns" :get_extra_params_obj="get_extra_params_obj">
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
});
const title = ref(_i18n('local_hosts_only'))

const get_extra_params_obj = () => {
  let extra_params = ntopng_url_manager.get_url_object();
  return extra_params;
};

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
  });

  return columns;
};

</script>
