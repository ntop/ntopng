<!-- (C) 2022 - ntop.org     -->
<template>
  <modal ref="modal_id">
    <template v-slot:title>
      {{ title }}
    </template>
    <template v-slot:body>
      {{ message }}
      <div v-if="show_return_msg" class="text-left">
      </div>
    </template><!-- modal-body -->
    <template v-slot:footer>
      <button type="button" @click="delete_asset" class="btn btn-danger">{{ _i18n("delete") }}</button>
    </template>
  </modal>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as modal } from "./modal.vue";
import { default as dataUtils } from "../utilities/data-utils.js";
import { ntopng_utility } from "../services/context/ntopng_globals_services";

const _i18n = (t) => i18n(t);
const modal_id = ref(null);
const message = ref('')
const return_message = ref('')
const show_return_msg = ref(false)
const title = ref('')
const err = ref(false);
const row = ref(null);

const emit = defineEmits(["delete"]);

const props = defineProps({
  context: Object,
});

onMounted(() => { });

/* ****************************************** */

/* This function simply reset the modal to factory values */
async function resetModal() {
  row.value = null;
  message.value = '';
  return_message.value = '';
  show_return_msg.value = false;
  err.value = false;
  title.value = '';
}

/* ****************************************** */

/* This function formats the delete message */
async function formatMessage(_row) {
  title.value = i18n("asset_details.delete_asset_title")
  if (_row) {
    const host = _row.host;
    let ip_address = host.ip;
    if (!dataUtils.isEmptyOrNull(host.vlan.name)) {
      ip_address = `${ip_address}@${host.vlan.name}`;
    }
    title.value = title.value + ": " + ip_address;
    message.value = i18n('asset_details.delete_asset');
  } else {
    title.value = title.value + ": " + i18n('all');
    message.value = i18n('asset_details.delete_all_assets');
  }
}

/* ****************************************** */

/* This function runs the delete code, called when apply is clicked */
async function delete_asset() {
  const url = `${http_prefix}/lua/rest/v2/delete/host/asset.lua`;
  let serial_key = 'all';
  if (row.value && row.value.key) {
    serial_key = row.value.key;
  }
  let params = {
    csrf: props.context.csrf,
    ifid: props.context.ifid,
    serial_key: serial_key,
  };

  const res = await ntopng_utility.http_post_request(url, params);
  if (res) {
    close();
  }
}

const show = (_row) => {
  resetModal();
  row.value = _row;
  formatMessage(_row);
  modal_id.value.show();
};

const close = () => {
  setTimeout(() => {
    modal_id.value.close();
    emit("delete");
  }, 500 /* 0.5 seconds */)
};

defineExpose({ show, close });

</script>
