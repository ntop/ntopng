<!-- (C) 2022-23 - ntop.org     -->
<template>
  <table class="table table-striped table-bordered col-sm-12">
    <tbody>
      <tr>
        <th class="col-3"> {{ _i18n("interface_alias") }} </th>
        <td class="col-9">
          <div class="d-flex ps-0">
            <input type="text" ref="custom_name" class="form-control" style="width: 16rem;" @input="checkDisabled">
          </div>
        </td>
      </tr>
      <tr>
        <th class="col-3"> {{ _i18n("interface_uplink_speed") }} </th>
        <td class="col-9">
          <div class="d-flex ps-0">
            <label class="d-flex align-items-center me-2">{{ _i18n("gbit") }}</label>
            <input ref="uplink_speed" class="form-control text-end" type="number" min="0" step="0.01" style="width: 8rem;"
              @input="checkDisabled" />
          </div>
        </td>
      </tr>
      <tr>
        <th class="col-3"> {{ _i18n("interface_downlink_speed") }} </th>
        <td class="col-9">
          <div class="d-flex ps-0">
            <label class="d-flex align-items-center me-2">{{ _i18n("gbit") }}</label>
            <input ref="downlink_speed" class="form-control text-end" type="number" min="0" step="0.001"
              style="width: 8rem;" @input="checkDisabled" />
          </div>
        </td>
      </tr>
    </tbody>
  </table>
  <button class="btn btn-primary d-flex ms-auto" :class="[disabled ? 'disabled' : '']" @click="updateInterfaceConfig"
    id="save"> {{
      _i18n("save_settings") }} </button>
</template>

<script setup>
import { ref, onMounted } from "vue";

const BIT_VALUE = 1000000000;
const _i18n = (t) => i18n(t);
const custom_name = ref(null);
const prev_name = ref('');
const uplink_speed = ref(null);
const prev_uplink_speed = ref('');
const downlink_speed = ref(null);
const prev_downlink_speed = ref('');
const disabled = ref(true);
const props = defineProps({
  ifid: String,
  csrf: String,
  device_ip: String,
  port_index: String,
});

const get_interface_config_url = `${http_prefix}/lua/pro/rest/v2/get/flowdevice/interface/config.lua?device_ip=${props.device_ip}&port_index=${props.port_index}&ifid=${props.ifid}`
const update_interface_config_url = `${http_prefix}/lua/pro/rest/v2/set/flowdevice/interface/config.lua`

onMounted(async () => {
  getFlowDeviceInterfaceConfig();
});

async function getFlowDeviceInterfaceConfig() {
  const rsp = await ntopng_utility.http_request(`${get_interface_config_url}`, { method: 'get' });
  custom_name.value.value = rsp.alias;
  prev_name.value = custom_name.value.value;
  uplink_speed.value.value = rsp.uplink_speed / BIT_VALUE;
  prev_uplink_speed.value = uplink_speed.value.value;
  downlink_speed.value.value = rsp.downlink_speed / BIT_VALUE;
  prev_downlink_speed.value = downlink_speed.value.value;
}

const updateInterfaceConfig = async function () {
  const params = {
    ifid: props.ifid,
    csrf: props.csrf,
    device_ip: props.device_ip,
    port_index: props.port_index,
    alias: custom_name.value.value,
    uplink_speed: Number(uplink_speed.value.value) * BIT_VALUE,
    downlink_speed: Number(downlink_speed.value.value) * BIT_VALUE,
  };
  let headers = {
    'Content-Type': 'application/json'
  };
  await ntopng_utility.http_request(update_interface_config_url, { method: 'post', headers, body: JSON.stringify(params) });
  getFlowDeviceInterfaceConfig();
  disabled.value = true;
}

const checkDisabled = function () {
  if (prev_name.value == custom_name.value.value
    && prev_uplink_speed.value == uplink_speed.value.value
    && prev_downlink_speed.value == downlink_speed.value.value) {
    disabled.value = true;
  } else {
    disabled.value = false;
  }
}
</script>