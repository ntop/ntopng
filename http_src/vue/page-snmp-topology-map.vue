<!--
  (C) 2013-23 - ntop.org
-->

<template>
  <div class="row">
    <div class="col-md-12 col-lg-12">
      <div class="card card-shadow">
        <div class="card-body">
          <NetworkMap ref="service_map" :empty_message="no_services_message" :event_listeners="event_listeners"
            :page_csrf="context.csrf" :url="topology_url" :url_params="url_params" :map_id="map_id">
          </NetworkMap>
        </div>
        <div class="card-footer">
          <NoteList :note_list="note_list"> </NoteList>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
/* Imports */
import { ref } from "vue";
import { default as NoteList } from "./note-list.vue";
import { default as NetworkMap } from "./network-map.vue";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";

/* ******************************************************************** */

/* Consts */
const _i18n = (t) => i18n(t);

const no_services_message = _i18n('map_page.no_services')
const note_list = [
  _i18n("snmp.snmp_lldp_cdp_descr"),
  _i18n("snmp.snmp_lldp_cdp_zoom_descr"),
  _i18n("snmp.snmp_lldp_cdp_node_color"),
]
const map_id = ref('topology-map')
const url_params = ntopng_url_manager.get_url_object()
const topology_url = `${http_prefix}/lua/pro/rest/v2/get/snmp/topology_map.lua`
const snmp_device_url = `${http_prefix}/lua/pro/enterprise/snmp_device_details.lua?ip=%ip`

const click_device = function(item) {
  ntopng_url_manager.go_to_url(snmp_device_url.replace('%ip', item.nodes[0]));
}

const event_listeners = {
  'doubleClick': click_device
}

const props = defineProps({
  context: Object,
});

const context = ref({
  csrf: props.context.csrf,
  ifid: props.context.ifid,
});

</script>