<!-- (C) 2022-23 - ntop.org     -->
<template>
  <div class="m-3">
    <h5>{{ _i18n('modify_flowdev_alias') }}</h5>
    <hr>
    <div class="m-4 card card-shadow">
      <div class="card-body">
        <div class="table-responsive">
          <table class="table table-striped table-bordered">
            <tbody class="table_length">
              <tr>
                <td>
                  <div class="d-flex align-items-center">
                    <div class="col-8">
                      <b>{{ _i18n('flowdev_alias') }}</b><br>
                    </div>
                    <div class="col-4">
                      <input type="text" ref="custom_name" class="form-control border" @input="checkDisabled">
                    </div>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <div class="d-flex justify-content-end me-1">
          <button class="btn btn-primary" :class="[disabled ? 'disabled' : '']" @click="updateFlowDevAlias" id="save">
            {{ _i18n("save_settings") }} </button>

        </div>
      </div>
    </div>
  </div>

</template>

<script setup>
import { ref, onMounted, defineProps } from "vue";

const _i18n = (t) => i18n(t);
const custom_name = ref(null);
const prev_name = ref('');
const disabled = ref(true);
const props = defineProps({
  context: Object
});

const get_flowdev_alias_url = `${http_prefix}/lua/pro/rest/v2/get/flowdevice/alias.lua?flowdev_ip=${get_ip_from_url()}&ifid=${props.context.ifid}`
const update_flowdev_alias_url = `${http_prefix}/lua/pro/rest/v2/set/flowdevice/alias.lua`

onMounted(async () => {
  getFlowDevAlias();
});

function get_ip_from_url() {
  return ntopng_url_manager.get_url_entry('ip')
}

async function getFlowDevAlias() {
  const rsp = await ntopng_utility.http_request(`${get_flowdev_alias_url}`, { method: 'get' });
  custom_name.value.value = rsp || props.ip;
  prev_name.value = custom_name.value.value;
}

const updateFlowDevAlias = async function () {
  const params = {
    csrf: props.csrf,
    ip: props.ip,
    alias: custom_name.value.value,
    ifid: props.ifid
  };
  let headers = {
    'Content-Type': 'application/json'
  };
  await ntopng_utility.http_request(update_flowdev_alias_url, { method: 'post', headers, body: JSON.stringify(params) });
  disabled.value = true;
}

const checkDisabled = function () {
  if (prev_name.value == custom_name.value.value) {
    disabled.value = true;
  } else {
    disabled.value = false;
  }
}
</script>