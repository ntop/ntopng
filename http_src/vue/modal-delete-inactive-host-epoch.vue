<!-- (C) 2022 - ntop.org     -->
<template>
  <modal ref="modal_id">
    <template v-slot:title>
      {{ _i18n("delete") }}
    </template>
    <template v-slot:body>
      {{ _i18n("delete_since") }}
      <div class="mt-3" style="max-width: 8rem;">
        <SelectSearch v-model:selected_option="selected_epoch" :options="epoch_list" @select_option="update_option">
        </SelectSearch>
      </div>
      <div v-if="show_return_msg" class="text-left">
        <p class="text-sm-start fs-6 fw-medium pt-3 m-0" :class="(err) ? 'text-danger' : 'text-success'"><small>{{ return_message }}</small></p>
      </div>
    </template><!-- modal-body -->

    <template v-slot:footer>
      <button type="button" @click="delete_host" class="btn btn-primary">{{ _i18n("delete") }}</button>
    </template>
  </modal>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as modal } from "./modal.vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services";
import { default as SelectSearch } from "./select-search.vue";

const _i18n = (t) => i18n(t);
const format = ref('csv');
const selected_epoch = ref();
const return_message = ref('')
const show_return_msg = ref(false)
const err = ref(false);
const epoch_list = [
  { label: _i18n("show_alerts.presets.5_min"), value: 300 },
  { label: _i18n("show_alerts.presets.30_min"), value: 1800 },
  { label: _i18n("show_alerts.presets.hour"), value: 3600 },
  { label: _i18n("show_alerts.presets.2_hours"), value: 7200 },
  { label: _i18n("show_alerts.presets.6_hours"), value: 21600 },
  { label: _i18n("show_alerts.presets.12_hours"), value: 43200 },
  { label: _i18n("show_alerts.presets.day"), value: 86400 },
  { label: _i18n("show_alerts.presets.week"), value: 604800 },
];

const emit = defineEmits(["delete_host"]);
const modal_id = ref();

const props = defineProps({
  context: Object,
});

onMounted(() => { 
  selected_epoch.value = epoch_list[0];
});

function update_option(selected_value) {
  selected_epoch.value = selected_value;
}

async function delete_host() {
  const url = `${http_prefix}/lua/rest/v2/delete/host/inactive_host.lua`;
  const params = {
    csrf: props.context.csrf,
    ifid: props.context.ifid,
    serial_key: selected_epoch.value.value,
  };

  let headers = {
    'Content-Type': 'application/json'
  };
  const res = await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(params) });
  if(res) {
    err.value = false;
    show_return_msg.value = true;
    let num_hosts_msg = ''
    if(res.deleted_hosts > 1) {
      num_hosts_msg = '. Number hosts deleted: ' + res.deleted_hosts
    }
    return_message.value = i18n('succ_del_inactive_hosts') + num_hosts_msg
    emit("delete_host");
    close();
  } else {
    err.value = true;
    show_return_msg.value = true;
    return_message.value = i18n('err_del_inactive_hosts')
  }
}

const show = () => {
  modal_id.value.show();
};

const close = () => {
  setTimeout(() => {
    modal_id.value.close();
  }, 3000 /* 3 seconds */)
};

defineExpose({ show, close });

</script>
