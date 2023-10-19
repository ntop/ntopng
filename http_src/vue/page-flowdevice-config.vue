<!-- (C) 2022-23 - ntop.org     -->
<template>
  <table class="table table-bordered table-striped">
    <tr>
    <th> {{ _i18n("flowdev_alias") }} </th>
      <td>
        <input type="text" ref="custom_name" class="form-control" @input="checkDisabled">
      </td>
    </tr>
  </table>
  <button class="btn btn-primary" :class="[disabled ? 'disabled' : '']" @click="updateFlowDevAlias" id="save"> {{ _i18n("save_settings") }} </button>
</template>

<script setup>
import { ref, onMounted } from "vue";

const _i18n = (t) => i18n(t);
const custom_name = ref(null);
const prev_name = ref('');
const disabled = ref(true);
const props = defineProps({
  ifid: Number,
  csrf: String,
  flowdev_ip: String,
});
const get_flowdev_alias_url = `${http_prefix}/lua/pro/rest/v2/get/flowdevice/alias.lua?flowdev_ip=${props.flowdev_ip}&ifid=${props.ifid}`
const update_flowdev_alias_url = `${http_prefix}/lua/pro/rest/v2/set/flowdevice/alias.lua`

onMounted(async () => {
  getFlowDevAlias();
});

async function getFlowDevAlias() {
  const rsp = await ntopng_utility.http_request(`${get_flowdev_alias_url}`, { method: 'get' });
  custom_name.value.value = rsp || props.flowdev_ip;
  prev_name.value = custom_name.value.value;
}

const updateFlowDevAlias = async function() {
  const params = {
    csrf: props.csrf,
    flowdev_ip: props.flowdev_ip,
    alias: custom_name.value.value,
    ifid: props.ifid
  };
  let headers = {
    'Content-Type': 'application/json'
  };
  await ntopng_utility.http_request(update_flowdev_alias_url, { method: 'post', headers, body: JSON.stringify(params) });
  getFlowDevAlias();
  disabled.value = true;
}

const checkDisabled = function() {
  if (prev_name.value == custom_name.value.value) {
    disabled.value = true;
  } else {
    disabled.value = false;
  }
}
</script>